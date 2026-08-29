defmodule Fitparser.Decoder do
  @moduledoc "Pure Elixir Garmin FIT decoder."
  use Fitparser.Profile
  import Bitwise
  alias Fitparser.{FitDataCrc, FitDataDefinition, FitDataField, FitDataHeader, FitDataRecord}
  @epoch 631_065_600
  @semicircles_to_degrees 180 / 2_147_483_648
  @fit_header_size 12
  @crc_size 2
  @timestamp_field 253
  @definition_message_header 0x40
  @compressed_timestamp_header 0x80
  @developer_fields_header 0x20
  @local_message_mask 0x0F
  @compressed_local_message_mask 0x03
  @compressed_local_message_shift 5
  @compressed_timestamp_mask 0x1F
  @compressed_timestamp_base_mask 0xFFFFFFE0
  @compressed_timestamp_wrap 32
  @header_size_offset 0
  @protocol_version_offset 1
  @profile_version_offset 2
  @profile_version_size 2
  @data_size_offset 4
  @data_size_size 4
  @little_endian_arch 0
  @big_endian_arch 1
  @base_type_enum 0
  @base_type_sint8 1
  @base_type_uint8 2
  @base_type_sint16 3
  @base_type_uint16 4
  @base_type_sint32 5
  @base_type_uint32 6
  @base_type_string 7
  @base_type_float32 8
  @base_type_float64 9
  @base_type_uint8z 10
  @base_type_uint16z 11
  @base_type_uint32z 12
  @base_type_byte 13
  @base_type_sint64 14
  @base_type_uint64 15
  @base_type_mask 0x1F
  @base_type_big_endian_flag 0x80
  @local_definition_count 16
  @empty_definitions Tuple.duplicate(nil, @local_definition_count)

  def from_fit(path, opts \\ []) do
    case File.read(path) do
      {:ok, data} -> load_fit(data, opts)
      {:error, _} -> {:error, "Error opening file"}
    end
  end

  def from_fit!(path, opts \\ []), do: unwrap(from_fit(path, opts))

  @doc "Decodes FIT bytes. Alias for `load_fit/2`."
  def decode(data, opts \\ []), do: load_fit(data, opts)

  def decode!(data, opts \\ []), do: load_fit!(data, opts)

  def load_fit(data, opts \\ []) when is_binary(data) do
    opts = normalize_options(opts)

    with :ok <- validate_options(data, opts),
         {:ok, value} <- decode_fit(data, opts) do
      {:ok, apply_processors(value, opts)}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, Fitparser.Crc.parse_error(data)}
    end
  end

  def load_fit!(data, opts \\ []), do: unwrap(load_fit(data, opts))
  defp unwrap({:ok, value}), do: value
  defp unwrap({:error, message}), do: raise(message)

  defp normalize_options(opts) do
    %{
      validate_crc: Keyword.get(opts, :validate_crc, false),
      processors: Keyword.get(opts, :processors, []),
      expand_components: Keyword.get(opts, :expand_components, true),
      standard_units: Keyword.get(opts, :standard_units, false),
      include_metadata: Keyword.get(opts, :include_metadata, false),
      processor_opts: opts
    }
  end

  defp validate_options(data, opts) do
    with :ok <- Fitparser.Crc.validate_structure(data) do
      validate_crc(data, opts.validate_crc)
    end
  end

  defp validate_crc(_data, false), do: :ok

  defp validate_crc(data, true) do
    case Fitparser.Crc.valid_sections?(data) do
      true -> :ok
      false -> {:error, "Invalid FIT CRC"}
    end
  end

  defp decode_fit(
         <<header_size, _protocol, _profile::little-16, data_size::little-32, ".FIT",
           rest::binary>> = data,
         opts
       )
       when header_size >= @fit_header_size and byte_size(rest) >= data_size + @crc_size do
    header_extra = header_size - @fit_header_size
    header = binary_part(data, 0, header_size)

    <<_extra::binary-size(^header_extra), body::binary-size(^data_size), _crc::little-16,
      tail::binary>> = rest

    case records(body, @empty_definitions, nil, %{}, opts, %{}) do
      {:ok, result} ->
        result =
          add_metadata_from_options(
            result,
            header,
            body,
            Fitparser.Crc.file_crc(data, header_size, data_size),
            opts
          )

        decode_tail(tail, result, opts)

      error ->
        error
    end
  end

  defp decode_fit(_, _opts), do: :error

  defp decode_fit(
         <<header_size, _protocol, _profile::little-16, data_size::little-32, ".FIT",
           rest::binary>> = data,
         acc,
         opts
       )
       when header_size >= @fit_header_size and byte_size(rest) >= data_size + @crc_size do
    header_extra = header_size - @fit_header_size
    header = binary_part(data, 0, header_size)

    <<_extra::binary-size(^header_extra), body::binary-size(^data_size), _crc::little-16,
      tail::binary>> = rest

    case records(body, @empty_definitions, nil, %{}, opts, %{}) do
      {:ok, result} ->
        result =
          add_metadata_from_options(
            result,
            header,
            body,
            Fitparser.Crc.file_crc(data, header_size, data_size),
            opts
          )

        result = merge_groups(acc, result)

        decode_tail(tail, result, opts)

      error ->
        error
    end
  end

  defp decode_fit(_, _acc, _opts), do: :error

  defp decode_tail(<<>>, result, _opts), do: {:ok, result}
  defp decode_tail(tail, result, opts), do: decode_fit(tail, result, opts)

  defp merge_groups(left, right) do
    Map.merge(left, right, fn _key, a, b -> a ++ b end)
  end

  defp apply_processors(result, opts) do
    Enum.reduce(opts.processors, result, fn processor, records ->
      Map.new(records, fn {kind, messages} ->
        {kind, Enum.map(messages, &Fitparser.Processor.apply(&1, processor, opts.processor_opts))}
      end)
    end)
  end

  defp records(<<>>, _defs, _last, acc, _opts, _component_state),
    do: {:ok, resolve_developer_fields(finalize_groups(acc))}

  defp records(<<header, rest::binary>>, defs, last, acc, opts, component_state)
       when (header &&& @compressed_timestamp_header) != 0 do
    local = compressed_local_message(header)
    timestamp = compressed_timestamp(last, compressed_timestamp_offset(header))

    record_data_for_local(rest, defs, local, timestamp, acc, opts, component_state)
  end

  defp records(<<header, rest::binary>>, defs, last, acc, opts, component_state)
       when (header &&& @definition_message_header) != 0 do
    case definition(rest, header) do
      {definition, tail} ->
        local = header &&& @local_message_mask

        records(
          tail,
          put_elem(defs, local, definition),
          last,
          put_definition(acc, local, definition, opts),
          opts,
          component_state
        )

      :error ->
        :error
    end
  end

  defp records(
         <<_header_flags::4, local::4, rest::binary>>,
         defs,
         last,
         acc,
         opts,
         component_state
       ) do
    record_data_for_local(rest, defs, local, last, acc, opts, component_state)
  end

  defp compressed_local_message(header),
    do: header >>> @compressed_local_message_shift &&& @compressed_local_message_mask

  defp compressed_timestamp_offset(header), do: header &&& @compressed_timestamp_mask

  defp record_data_for_local(rest, defs, local, last, acc, opts, component_state) do
    case definition_for(defs, local) do
      nil -> :error
      definition -> record_data(rest, definition, defs, last, acc, opts, component_state)
    end
  end

  defp record_data(rest, definition, defs, last, acc, opts, component_state) do
    case data(rest, definition, last, opts, component_state) do
      {:ok, fields, tail, timestamp, component_state} ->
        records(
          tail,
          defs,
          timestamp,
          put_record(acc, definition_global(definition), fields),
          opts,
          component_state
        )

      _ ->
        :error
    end
  end

  defp definition_for(defs, local), do: elem(defs, local) || missing_definition(local)

  defp compressed_timestamp(nil, _offset), do: nil

  defp compressed_timestamp(previous, offset) do
    low = previous &&& @compressed_timestamp_mask
    base = previous &&& @compressed_timestamp_base_mask
    compressed_timestamp(base, low, offset)
  end

  defp compressed_timestamp(base, low, offset) when offset < low,
    do: base + offset + @compressed_timestamp_wrap

  defp compressed_timestamp(base, _low, offset), do: base + offset

  # A few scale exports omit the local definition header for their
  # weight_scale records. The profile layout is fixed for this message.
  defp missing_definition(2),
    do: missing_definition(30, :big, [{0, 2, 132}, {1, 2, 132}, {253, 4, 140}], 8)

  defp missing_definition(7),
    do:
      missing_definition(
        23,
        :big,
        [
          {0, 1, 2},
          {1, 1, 2},
          {2, 2, 132},
          {3, 4, 140},
          {4, 2, 132},
          {5, 2, 132},
          {253, 4, 140}
        ],
        16
      )

  defp missing_definition(_), do: nil

  defp missing_definition(global, endian, fields, size),
    do: definition_data(global, endian, fields, [], size)

  defp definition(
         <<_reserved, @little_endian_arch, global::little-16, count, rest::binary>>,
         header
       ),
       do: definition(global, :little, count, rest, header)

  defp definition(<<_reserved, @big_endian_arch, global::big-16, count, rest::binary>>, header),
    do: definition(global, :big, count, rest, header)

  defp definition(_rest, _header), do: :error

  defp definition(global, endian, count, rest, header) do
    normal_definition(global, endian, count, rest, header)
  end

  defp normal_definition(global, endian, count, rest, header) do
    with {fields, rest} <- field_definitions(rest, count, []),
         {dev_fields, rest} <- developer_definitions(rest, header) do
      size =
        Enum.reduce(fields, 0, fn {_number, field_size, _type}, total -> total + field_size end)

      {definition_data(global, endian, fields, dev_fields, size), rest}
    else
      :error -> :error
    end
  end

  # FIT field definitions are fixed-width three-byte records. Keeping their
  # parser recursive makes the binary layout visible and lets malformed
  # definitions fail by pattern matching instead of leaking partial state.
  defp field_definitions(rest, 0, fields), do: {Enum.reverse(fields), rest}

  defp field_definitions(<<number, size, type, rest::binary>>, count, fields) do
    field_definitions(rest, count - 1, [{number, size, type} | fields])
  end

  defp field_definitions(_rest, _count, _fields), do: :error

  defp developer_definitions(rest, header) when (header &&& @developer_fields_header) == 0,
    do: {[], rest}

  defp developer_definitions(<<count, rest::binary>>, _header),
    do: developer_field_definitions(rest, count, [])

  defp developer_definitions(_rest, _header), do: :error

  defp developer_field_definitions(rest, 0, fields), do: {Enum.reverse(fields), rest}

  defp developer_field_definitions(<<number, size, type, rest::binary>>, count, fields),
    do: developer_field_definitions(rest, count - 1, [{number, size, type} | fields])

  defp developer_field_definitions(_, _, _), do: :error

  defp definition_data(global, endian, fields, dev_fields, size) do
    profile_fields = profile_fields(global, fields)
    reference_fields? = reference_fields_required?(profile_fields)

    {:definition, global, endian, fields, dev_fields, size, profile_fields, reference_fields?}
  end

  defp profile_fields(global, fields) do
    Map.new(fields, fn {number, _size, _type} ->
      {number, cache_field_metadata(global, field(global, number))}
    end)
  end

  defp cache_field_metadata(_global, nil), do: nil

  defp cache_field_metadata(global, definition) do
    subfields = Enum.map(definition.subfields || [], &cache_field_metadata(global, &1))

    definition
    |> Map.put(:subfields, subfields)
    |> Map.put(:normalized_units, empty_to_nil(definition.units))
    |> Map.put(:normalized_type, normalize_type(definition.type))
    |> Map.put(:scale_offset, scale_and_offset(definition.scale, definition.offset))
    |> Map.put(:component_specs, component_specs(global, definition))
  end

  defp component_specs(_global, %{components: [], bits: _bits}), do: []
  defp component_specs(_global, %{bits: nil}), do: []

  defp component_specs(global, %{components: components, bits: bits, accumulate: accumulate}) do
    component_specs(
      global,
      components,
      component_widths(bits, length(components)),
      String.split(to_string(accumulate), ","),
      []
    )
  end

  defp component_specs(_global, [], _widths, _accumulate, specs), do: Enum.reverse(specs)
  defp component_specs(_global, _components, [], _accumulate, specs), do: Enum.reverse(specs)

  defp component_specs(global, [name | components], [width | widths], accumulate, specs) do
    {accumulate?, accumulate} = next_accumulate(accumulate)
    spec = {name, width, accumulate?, field_by_name(global, name)}

    component_specs(global, components, widths, accumulate, [spec | specs])
  end

  defp next_accumulate([accumulate | rest]), do: {accumulate, rest}
  defp next_accumulate([]), do: {"0", []}

  defp definition_global(
         {:definition, global, _endian, _fields, _dev_fields, _size, _profile, _references}
       ),
       do: global

  defp data(
         binary,
         {:definition, global, endian, defs, dev_defs, size, profile_fields, reference_fields?},
         last,
         opts,
         component_state
       ) do
    decode_data(
      binary,
      size,
      global,
      endian,
      defs,
      dev_defs,
      profile_fields,
      reference_fields?,
      last,
      opts,
      component_state
    )
  end

  defp decode_data(
         binary,
         size,
         _global,
         _endian,
         _defs,
         _dev_defs,
         _profile_fields,
         _reference_fields?,
         _last,
         _opts,
         _state
       )
       when byte_size(binary) < size,
       do: :error

  defp decode_data(
         binary,
         _size,
         global,
         endian,
         defs,
         dev_defs,
         profile_fields,
         reference_fields?,
         last,
         opts,
         component_state
       ) do
    {pairs, rest} = Enum.map_reduce(defs, binary, &decode_field(&1, &2, profile_fields, endian))
    {dev_pairs, rest} = Enum.map_reduce(dev_defs, rest, &decode_developer_field/2)

    timestamp = Enum.find_value(pairs, last, &timestamp_pair/1)

    field_opts =
      Map.put(opts, :reference_fields, reference_fields(profile_fields, pairs, reference_fields?))

    {fields, component_state} =
      decode_fields(
        pairs,
        global,
        profile_fields,
        field_opts,
        opts,
        component_state,
        []
      )

    fields = Enum.reduce(dev_pairs, fields, &[make_developer_field(&1) | &2])
    {:ok, sort_fields(fields), rest, timestamp, component_state}
  end

  defp decode_fields([], _global, _profile_fields, _field_opts, _opts, state, fields),
    do: {fields, state}

  defp decode_fields(
         [pair | pairs],
         global,
         profile_fields,
         field_opts,
         opts,
         state,
         fields
       ) do
    {number, _value} = pair
    definition = Map.get(profile_fields, number)

    {components, state} =
      component_fields(global, pair, definition, state, opts, opts.expand_components)

    fields = [make_field(definition, pair, field_opts) | Enum.reverse(components, fields)]
    decode_fields(pairs, global, profile_fields, field_opts, opts, state, fields)
  end

  defp decode_field({number, field_size, type}, input, profile_fields, endian) do
    <<raw::binary-size(^field_size), tail::binary>> = input

    {{number, decode_value(raw, type, endian, number, array_field?(profile_fields, number))},
     tail}
  end

  defp decode_developer_field({number, field_size, developer_index}, input) do
    <<raw::binary-size(^field_size), tail::binary>> = input
    {{number, developer_index, raw}, tail}
  end

  defp timestamp_pair({@timestamp_field, value}), do: value
  defp timestamp_pair(_pair), do: nil

  defp make_developer_field({number, developer_index, value}) do
    %FitDataField{
      name: "developer_field_#{number}",
      value: value,
      units: nil,
      number: number,
      developer_data_index: developer_index
    }
  end

  defp sort_fields(fields) do
    case ordered_fields?(fields) do
      true -> fields
      false -> Enum.sort_by(fields, & &1.number)
    end
  end

  defp ordered_fields?([]), do: true
  defp ordered_fields?([_field]), do: true

  defp ordered_fields?([left, right | rest]) when left.number <= right.number,
    do: ordered_fields?([right | rest])

  defp ordered_fields?(_fields), do: false

  defp reference_fields(_profile_fields, _pairs, false), do: %{}

  defp reference_fields(profile_fields, pairs, true) do
    Map.new(pairs, fn {number, value} ->
      definition = Map.get(profile_fields, number)
      name = field_name(definition, number)
      value = enum_value(definition, value)

      {name, value}
    end)
  end

  defp reference_fields_required?(profile_fields) do
    Enum.any?(profile_fields, fn
      {_number, %{subfields: [_ | _]}} -> true
      _field -> false
    end)
  end

  defp field_name(%{name: name}, _number), do: name
  defp field_name(_definition, number), do: "field_#{number}"

  defp enum_value(%{enum: enum}, value), do: enum_value(enum, value)
  defp enum_value(enum, value) when is_map(enum), do: Map.get(enum, value, value)
  defp enum_value(_enum, value), do: value

  defp resolve_developer_fields(groups) do
    descriptions =
      groups
      |> Map.get(:field_description, [])
      |> Enum.reduce(%{}, fn record, acc ->
        values = Map.new(record.fields, &{&1.name, &1.value})
        index = Map.get(values, "developer_data_index")
        number = Map.get(values, "field_definition_number")

        put_description(acc, index, number, values)
      end)

    resolve_developer_groups(groups, descriptions)
  end

  defp resolve_developer_groups(groups, descriptions) when map_size(descriptions) == 0,
    do: groups

  defp resolve_developer_groups(groups, descriptions) do
    Map.new(groups, fn {name, records} ->
      {name, Enum.map(records, &resolve_developer_record(&1, descriptions))}
    end)
  end

  defp put_description(acc, index, number, values)
       when is_integer(index) and is_integer(number),
       do: Map.put(acc, {index, number}, values)

  defp put_description(acc, _index, _number, _values), do: acc

  defp resolve_developer_record(record, descriptions) do
    fields =
      Enum.map(record.fields, fn
        %FitDataField{developer_data_index: index, number: number, value: raw} = field
        when is_integer(index) and is_binary(raw) ->
          case Map.get(descriptions, {index, number}) do
            nil -> field
            description -> resolve_developer_field(field, raw, description)
          end

        field ->
          field
      end)

    %{record | fields: fields}
  end

  defp resolve_developer_field(field, raw, description) do
    type = developer_type(Map.get(description, "fit_base_type_id"))
    value = decode_developer_value(raw, type, field.number)
    scale = Map.get(description, "scale")
    offset = Map.get(description, "offset") || 0
    value = scale_value(value, scale, offset)
    name = Map.get(description, "field_name") || field.name
    units = Map.get(description, "units") || field.units

    %{field | name: text_value(name), units: text_value(units), value: value}
  end

  defp decode_developer_value(raw, nil, _number), do: raw

  defp decode_developer_value(raw, type, number),
    do: decode_value(raw, type, :little, number, false)

  defp scale_value(value, scale, offset)
       when is_number(scale) and scale != 0 and is_number(value),
       do: value / scale - offset

  defp scale_value(value, _scale, _offset), do: value

  defp text_value(value) when is_binary(value), do: value
  defp text_value(value) when is_list(value), do: Enum.map_join(value, &to_string/1)
  defp text_value(value), do: value

  defp decode_value(raw, type, endian, _number, array) do
    base = type &&& @base_type_mask
    decode_value(raw, base, effective_endian(type, endian), array)
  end

  defp decode_value(raw, base, endian, true), do: decode_array(raw, base, endian)
  defp decode_value(raw, base, endian, false), do: decode_scalar(raw, base, endian)

  defp effective_endian(type, _endian) when (type &&& @base_type_big_endian_flag) != 0, do: :big
  defp effective_endian(_type, endian), do: endian

  defp array_field?(profile_fields, number) do
    case Map.get(profile_fields, number) do
      %{array: true} -> true
      _ -> false
    end
  end

  defp decode_array(raw, base, endian) do
    case element_size(base) do
      1 when base == @base_type_byte ->
        :binary.bin_to_list(raw)

      1 ->
        for <<byte <- raw>>, do: decode_scalar(<<byte>>, base, endian)

      size ->
        for <<part::binary-size(^size) <- raw>>, do: decode_scalar(part, base, endian)
    end
  end

  defp decode_scalar(raw, base, endian) do
    case invalid_value?(raw, base, endian) do
      true -> nil
      false -> decode_base(raw, base, endian)
    end
  end

  defp decode_base(raw, @base_type_string, _endian),
    do: raw |> String.trim_trailing(<<0>>) |> to_string()

  defp decode_base(<<value::little-float-32>>, @base_type_float32, :little), do: value
  defp decode_base(<<value::big-float-32>>, @base_type_float32, :big), do: value
  defp decode_base(<<value::little-float-64>>, @base_type_float64, :little), do: value
  defp decode_base(<<value::big-float-64>>, @base_type_float64, :big), do: value
  defp decode_base(raw, @base_type_byte, _endian), do: raw
  defp decode_base(<<value::little-signed-8>>, @base_type_sint8, :little), do: value
  defp decode_base(<<value::big-signed-8>>, @base_type_sint8, :big), do: value
  defp decode_base(<<value::little-signed-16>>, @base_type_sint16, :little), do: value
  defp decode_base(<<value::big-signed-16>>, @base_type_sint16, :big), do: value
  defp decode_base(<<value::little-signed-32>>, @base_type_sint32, :little), do: value
  defp decode_base(<<value::big-signed-32>>, @base_type_sint32, :big), do: value
  defp decode_base(<<value::little-signed-64>>, @base_type_sint64, :little), do: value
  defp decode_base(<<value::big-signed-64>>, @base_type_sint64, :big), do: value
  defp decode_base(raw, _base, endian), do: :binary.decode_unsigned(raw, endian)

  defp element_size(base)
       when base in [
              @base_type_enum,
              @base_type_sint8,
              @base_type_uint8,
              @base_type_string,
              @base_type_uint8z,
              @base_type_byte
            ],
       do: 1

  defp element_size(base) when base in [@base_type_sint16, @base_type_uint16, @base_type_uint16z],
    do: 2

  defp element_size(base)
       when base in [@base_type_sint32, @base_type_uint32, @base_type_float32, @base_type_uint32z],
       do: 4

  defp element_size(base) when base in [@base_type_float64, @base_type_sint64, @base_type_uint64],
    do: 8

  defp invalid_value?(<<>>, _base, _endian), do: true
  defp invalid_value?(raw, @base_type_string, _endian), do: sentinel_bytes?(raw, 0)

  defp invalid_value?(raw, base, _endian)
       when base in [@base_type_uint8z, @base_type_uint16z, @base_type_uint32z],
       do: sentinel_bytes?(raw, 0)

  defp invalid_value?(<<0x7F>>, @base_type_sint8, _endian), do: true
  defp invalid_value?(<<0xFF, 0x7F>>, @base_type_sint16, :little), do: true
  defp invalid_value?(<<0x7F, 0xFF>>, @base_type_sint16, :big), do: true
  defp invalid_value?(<<0xFF, 0xFF, 0xFF, 0x7F>>, @base_type_sint32, :little), do: true
  defp invalid_value?(<<0x7F, 0xFF, 0xFF, 0xFF>>, @base_type_sint32, :big), do: true

  defp invalid_value?(
         <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F>>,
         @base_type_sint64,
         :little
       ),
       do: true

  defp invalid_value?(
         <<0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>,
         @base_type_sint64,
         :big
       ),
       do: true

  defp invalid_value?(raw, _base, _endian), do: sentinel_bytes?(raw, 255)

  defp sentinel_bytes?(<<>>, _sentinel), do: true
  defp sentinel_bytes?(<<sentinel>>, sentinel), do: true
  defp sentinel_bytes?(<<sentinel, sentinel>>, sentinel), do: true
  defp sentinel_bytes?(<<sentinel, sentinel, sentinel, sentinel>>, sentinel), do: true

  defp sentinel_bytes?(
         <<sentinel, sentinel, sentinel, sentinel, sentinel, sentinel, sentinel, sentinel>>,
         sentinel
       ),
       do: true

  defp sentinel_bytes?(<<sentinel, rest::binary>>, sentinel),
    do: sentinel_bytes?(rest, sentinel)

  defp sentinel_bytes?(_raw, _sentinel), do: false

  defp make_field(definition, {number, value}, %{reference_fields: references} = opts) do
    definition = effective_field(definition, references)

    {name, units, type, enum, scale, components, array} =
      case definition do
        %{
          name: name,
          normalized_units: units,
          normalized_type: type,
          enum: enum,
          scale_offset: scale,
          components: components,
          array: array
        } ->
          {name, units, type, enum, scale, components, array}

        nil ->
          {"field_#{number}", nil, nil, nil, nil, [], false}
      end

    value = enum_value(enum, value)
    value = maybe_array_value(value, array, components)

    value = timestamp_value(value, type)

    value =
      case scale do
        nil ->
          value

        {factor, offset} when is_number(value) ->
          value / factor - offset

        {factor, offset} when is_list(value) ->
          Enum.map(value, fn
            item when is_number(item) -> item / factor - offset
            item -> item
          end)

        {_factor, _offset} ->
          value
      end

    value = normalize_value(value, type, units, opts)

    %FitDataField{name: name, value: value, units: units, number: number}
  end

  defp maybe_array_value(value, array, components)
       when (array or components != []) and is_binary(value),
       do: :binary.bin_to_list(value)

  defp maybe_array_value(value, _array, _components), do: value

  defp normalize_type(type) when is_binary(type), do: String.to_atom(type)
  defp normalize_type(type), do: type

  defp effective_field(base, references) do
    case base do
      %{subfields: subfields} when subfields != [] ->
        Enum.find(subfields, base, &subfield_matches?(&1, references))

      _ ->
        base
    end
  end

  defp subfield_matches?(
         %{ref_field_name: names, ref_field_value: values},
         references
       )
       when is_binary(names) and is_binary(values) do
    names = String.split(names, ",", trim: true)
    values = String.split(values, ",", trim: true)

    names != [] and length(names) == length(values) and
      Enum.zip(names, values)
      |> Enum.any?(fn {name, value} -> Map.get(references, name) |> to_string() == value end)
  end

  defp subfield_matches?(_subfield, _references), do: false

  defp component_fields(_global, _pair, _definition, state, _opts, false), do: {[], state}

  defp component_fields(global, pair, definition, state, opts, true),
    do: expand_component_fields(global, pair, definition, state, opts)

  defp expand_component_fields(
         global,
         {number, value},
         %{component_specs: [_ | _] = specs},
         state,
         opts
       ) do
    raw = component_integer(value)

    expand_component_specs(specs, global, number, raw, 0, state, opts, [])
  end

  defp expand_component_fields(_global, _pair, _definition, state, _opts), do: {[], state}

  defp expand_component_specs([], _global, _number, _raw, _offset, state, _opts, fields),
    do: {Enum.reverse(fields), state}

  defp expand_component_specs(
         [{name, width, accumulate?, definition} | specs],
         global,
         number,
         raw,
         offset,
         state,
         opts,
         fields
       ) do
    component_raw = raw >>> offset &&& (1 <<< width) - 1
    key = {global, number, name}

    {component_raw, state} = accumulate_component(accumulate?, state, key, component_raw, width)
    field = component_field(name, definition, component_raw, width, number, opts)

    expand_component_specs(
      specs,
      global,
      number,
      raw,
      offset + width,
      state,
      opts,
      [field | fields]
    )
  end

  defp component_widths(bits, _count) when is_list(bits), do: bits
  defp component_widths(bits, count), do: List.duplicate(bits, count)

  defp accumulate_component("1", state, key, raw, width) do
    value = rem(Map.get(state, key, 0) + raw, 1 <<< width)
    {value, Map.put(state, key, value)}
  end

  defp accumulate_component(_flag, state, _key, raw, _width), do: {raw, state}

  defp component_integer(value) when is_integer(value), do: value
  defp component_integer(value) when is_binary(value), do: :binary.decode_unsigned(value, :little)

  defp component_integer(value) when is_list(value), do: component_integer(value, 0, 0)

  defp component_integer(_value), do: 0

  defp component_integer([], _shift, result), do: result

  defp component_integer([<<byte>> | rest], shift, result),
    do: component_integer(rest, shift + 8, result ||| byte <<< shift)

  defp component_integer([byte | rest], shift, result) when is_integer(byte),
    do: component_integer(rest, shift + 8, result ||| byte <<< shift)

  defp component_integer([_value | rest], shift, result),
    do: component_integer(rest, shift + 8, result)

  defp component_field(name, nil, value, _width, number, _opts),
    do: %FitDataField{name: name, value: value, units: nil, number: number}

  defp component_field(name, definition, value, width, number, opts) do
    type = type_to_base(definition.type)
    decoded = decode_component(value, width, type)

    decoded = enum_value(definition, decoded)

    scaled =
      case {definition.scale, definition.offset, decoded} do
        {scale, offset, value} when is_number(scale) and is_number(value) ->
          value / scale - (offset || 0)

        _ ->
          decoded
      end

    %FitDataField{
      name: name,
      value: normalize_value(scaled, definition.type, definition.units, opts),
      units: empty_to_nil(definition.units),
      number: number
    }
  end

  defp decode_component(value, width, type)
       when type in [@base_type_sint8, @base_type_sint16, @base_type_sint32, @base_type_sint64] and
              width > 0 do
    sign_bit = 1 <<< (width - 1)
    signed_component(value, sign_bit, width)
  end

  defp decode_component(value, _width, _type), do: value

  defp signed_component(value, sign_bit, width) when (value &&& sign_bit) != 0,
    do: value - (1 <<< width)

  defp signed_component(value, _sign_bit, _width), do: value

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value
  defp scale_and_offset(nil, _offset), do: nil
  defp scale_and_offset(scale, offset), do: {scale, offset || 0}

  defp normalize_value(value, type, units, opts) do
    normalize_value_by_units(value, type, units, opts.standard_units)
  end

  defp normalize_value_by_units(value, type, units, true),
    do: normalize_profile_value(value, type, units)

  defp normalize_value_by_units(value, _type, _units, false), do: value

  defp normalize_profile_value(value, _type, "semicircles") when is_number(value),
    do: value * @semicircles_to_degrees

  defp normalize_profile_value(value, _type, "semicircles") when is_list(value),
    do: Enum.map(value, &normalize_profile_value(&1, nil, "semicircles"))

  defp normalize_profile_value(value, :bool, _units) when value in [0, 1], do: value == 1
  defp normalize_profile_value("true", :bool, _units), do: true
  defp normalize_profile_value("false", :bool, _units), do: false
  defp normalize_profile_value(value, _type, _units), do: value

  defp timestamp_value(value, type)
       when type in [:date_time, :local_date_time] and is_integer(value) do
    @epoch + value
  end

  defp timestamp_value(value, _type), do: value

  defp put_definition(acc, local, definition, %{include_metadata: true}) do
    {:definition, global, endian, fields, developer_fields, _size, _profile_fields, _references} =
      definition

    definition = %FitDataDefinition{
      local: local,
      global: global,
      endian: endian,
      fields: fields,
      developer_fields: developer_fields
    }

    Map.update(acc, "__definitions__", [definition], &[definition | &1])
  end

  defp put_definition(acc, _local, _definition, _opts), do: acc

  defp put_record(acc, global, fields) do
    name = message(global) || String.to_atom("message_#{global}")
    record = %FitDataRecord{kind: name, fields: fields}
    Map.update(acc, name, [record], &[record | &1])
  end

  defp finalize_groups(groups),
    do: Map.new(groups, fn {name, records} -> {name, Enum.reverse(records)} end)

  defp add_metadata_from_options(result, header, body, crc, opts) do
    add_metadata(result, header, body, crc, opts.include_metadata)
  end

  defp add_metadata(result, _header, _body, _crc, false), do: result

  defp add_metadata(result, header, body, crc, true) do
    header_record = %FitDataHeader{
      header_size: :binary.at(header, @header_size_offset),
      protocol_version: :binary.at(header, @protocol_version_offset),
      profile_version:
        :binary.decode_unsigned(
          binary_part(header, @profile_version_offset, @profile_version_size),
          :little
        ),
      data_size:
        :binary.decode_unsigned(binary_part(header, @data_size_offset, @data_size_size), :little)
    }

    crc_record = %FitDataCrc{value: crc, valid: Fitparser.Crc.body_valid?(body, crc)}
    Map.merge(result, %{"__headers__" => [header_record], "__crcs__" => [crc_record]})
  end
end

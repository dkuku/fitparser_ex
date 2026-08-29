defmodule Mix.Tasks.Fitparser.Profile do
  import SweetXml
  @shortdoc "Generates Fitparser.Profile from messages.csv and types.csv"
  @moduledoc """
  Generates the compile-time FIT profile module from Garmin CSV profile files.

      mix fitparser.profile
      mix fitparser.profile path/to/messages.csv path/to/types.csv
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {messages_path, types_path} = paths(args)

    {messages, {types, enums}} =
      if Path.extname(messages_path) == ".xlsx" do
        {xlsx_rows(messages_path, "sheet2.xml") |> message_rows(),
         xlsx_rows(messages_path, "sheet1.xml") |> type_rows()}
      else
        {messages_path |> File.read!() |> csv() |> message_rows(),
         types_path |> File.read!() |> csv() |> type_rows()}
      end

    output = render(messages, types, enums)
    File.mkdir_p!("lib/fitparser")
    File.write!("lib/fitparser/profile.ex", output)

    if function_exported?(Mix, :shell, 0),
      do: Mix.shell().info("Generated lib/fitparser/profile.ex")
  end

  defp paths([]), do: {"messages.csv", "types.csv"}
  defp paths([messages]), do: {messages, "types.csv"}
  defp paths([messages, types]), do: {messages, types}
  defp paths(_), do: Mix.raise("usage: mix fitparser.profile [messages.csv] [types.csv]")

  defp message_rows(rows) do
    {rows, _message} =
      Enum.map_reduce(rows, nil, fn row, message ->
        case Enum.at(row, 0) do
          "" -> {{message, row}, message}
          nil -> {{message, row}, message}
          name -> {{name, row}, name}
        end
      end)

    rows
    |> Enum.filter(fn {message, row} ->
      message != nil and
        (match?({_, ""}, Integer.parse(Enum.at(row, 1) || "")) or
           (Enum.at(row, 1) in [nil, ""] and Enum.at(row, 2) not in [nil, ""]))
    end)
    |> Enum.map(fn {message, row} ->
      {message, parse_integer_or_nil(Enum.at(row, 1)), Enum.at(row, 2), Enum.at(row, 3),
       Enum.at(row, 6), Enum.at(row, 7), Enum.at(row, 8), Enum.at(row, 4), Enum.at(row, 5),
       Enum.at(row, 9), Enum.at(row, 10), Enum.at(row, 11), Enum.at(row, 12), Enum.at(row, 13)}
    end)
  end

  defp type_rows(rows) do
    message_rows =
      case Enum.find_index(rows, &(Enum.at(&1, 0) == "mesg_num")) do
        nil -> rows
        index -> Enum.drop(rows, index + 1)
      end

    enums =
      rows
      |> Enum.reduce({nil, nil, %{}}, fn row, {type, base, acc} ->
        type = if Enum.at(row, 0) not in [nil, ""], do: Enum.at(row, 0), else: type
        base = if Enum.at(row, 1) not in [nil, ""], do: Enum.at(row, 1), else: base

        if type not in [nil, ""] and base not in [nil, ""] and
             Enum.at(row, 2) not in [nil, ""] and
             numeric?(Enum.at(row, 3)) do
          {type, base,
           Map.update(
             acc,
             type,
             %{parse_number(Enum.at(row, 3)) => Enum.at(row, 2)},
             &Map.put(&1, parse_number(Enum.at(row, 3)), Enum.at(row, 2))
           )}
        else
          {type, base, acc}
        end
      end)
      |> elem(2)

    messages =
      message_rows
      |> Enum.take_while(&(Enum.at(&1, 0) == "" and Enum.at(&1, 2) not in [nil, ""]))
      |> Enum.filter(fn row ->
        Enum.at(row, 2) not in [nil, ""] and
          case Enum.at(row, 3) do
            "0x" <> value -> match?({_, ""}, Integer.parse(value, 16))
            value when is_binary(value) -> match?({_, ""}, Integer.parse(value))
            _ -> false
          end
      end)
      |> Enum.map(fn row -> {Enum.at(row, 2), parse_number(Enum.at(row, 3))} end)

    {messages, enums}
  end

  defp render(fields, types, enums) do
    messages = Enum.reduce(types, %{}, fn {name, number}, acc -> Map.put(acc, number, name) end)
    fields = collect_subfields(fields)

    field_map =
      Enum.reduce(fields, %{}, fn {message, number, name, type, scale, offset, units, array,
                                   components, bits, accumulate, ref_field_name, ref_field_value,
                                   comment, subfields},
                                  acc ->
        case Enum.find(messages, fn {_number, message_name} -> message_name == message end) do
          {message_number, _} ->
            Map.put(acc, {message_number, number}, %{
              name: name,
              type: type,
              scale: number_or_nil(scale),
              offset: number_or_nil(offset),
              units: empty_to_nil(units),
              enum: Map.get(enums, type),
              array: parse_array(array),
              components: parse_list(components),
              bits: parse_bits(bits),
              accumulate: empty_to_nil(accumulate),
              ref_field_name: empty_to_nil(ref_field_name),
              ref_field_value: empty_to_nil(ref_field_value),
              comment: empty_to_nil(comment),
              subfields: Enum.map(subfields, &field_metadata(&1, enums))
            })

          nil ->
            acc
        end
      end)

    fields =
      Enum.map(field_map, fn {{message, number}, metadata} ->
        {message, number, metadata.name, atom_literal(type_atom(metadata.type)), metadata.scale,
         metadata.offset, metadata.units, metadata.enum, metadata.array, metadata.components,
         metadata.bits, metadata.accumulate, metadata.ref_field_name, metadata.ref_field_value,
         metadata.comment, metadata.subfields}
      end)

    EEx.eval_file(Path.join(__DIR__, "profile.ex.eex"),
      assigns: [
        messages: messages,
        fields: fields,
        types: types
      ]
    )
  end

  defp collect_subfields(fields) do
    fields
    |> Enum.reduce([], fn
      {_, nil, _, _, _, _, _, _, _, _, _, _, _, _} = subfield, [base | rest] ->
        [put_elem(base, 14, [subfield | elem(base, 14)]) | rest]

      {_, nil, _, _, _, _, _, _, _, _, _, _, _, _}, [] ->
        []

      {message, number, name, type, scale, offset, units, array, components, bits, accumulate,
       ref_field_name, ref_field_value, comment},
      acc ->
        [
          {message, number, name, type, scale, offset, units, array, components, bits, accumulate,
           ref_field_name, ref_field_value, comment, []}
          | acc
        ]
    end)
    |> Enum.reverse()
    |> Enum.map(fn {message, number, name, type, scale, offset, units, array, components, bits,
                    accumulate, ref_field_name, ref_field_value, comment, subfields} ->
      {message, number, name, type, scale, offset, units, array, components, bits, accumulate,
       ref_field_name, ref_field_value, comment, Enum.reverse(subfields)}
    end)
  end

  defp field_metadata(
         {_, _, name, type, scale, offset, units, array, components, bits, accumulate,
          ref_field_name, ref_field_value, comment},
         enums
       ) do
    %{
      name: name,
      type: type,
      scale: number_or_nil(scale),
      offset: number_or_nil(offset),
      units: empty_to_nil(units),
      enum: Map.get(enums, type),
      array: parse_array(array),
      components: parse_list(components),
      bits: parse_bits(bits),
      accumulate: empty_to_nil(accumulate),
      ref_field_name: empty_to_nil(ref_field_name),
      ref_field_value: empty_to_nil(ref_field_value),
      comment: empty_to_nil(comment),
      subfields: []
    }
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value
  defp number_or_nil(nil), do: nil
  defp number_or_nil(""), do: nil
  defp number_or_nil(value), do: parse_number(value)

  defp parse_integer_or_nil(nil), do: nil
  defp parse_integer_or_nil(""), do: nil
  defp parse_integer_or_nil(value), do: String.to_integer(value)

  defp parse_bits(nil), do: nil
  defp parse_bits(""), do: nil

  defp parse_bits(value) do
    values = value |> String.split(",") |> Enum.map(&parse_number/1)
    if length(values) == 1, do: hd(values), else: values
  end

  defp parse_array(nil), do: false
  defp parse_array(""), do: false
  defp parse_array(value), do: value in [true, "true", "1", 1, "[N]"]

  defp parse_list(nil), do: []
  defp parse_list(""), do: []

  defp parse_list(value),
    do: value |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

  defp type_atom(nil), do: nil
  defp type_atom(value), do: String.to_atom(value)

  defp atom_literal(nil), do: "nil"
  defp atom_literal(value), do: ":" <> Atom.to_string(value)

  defp parse_number(nil), do: nil
  defp parse_number("0x" <> value), do: String.to_integer(value, 16)

  defp parse_number(value) do
    value = value |> String.split(",") |> List.first() |> String.trim()

    case Integer.parse(value) do
      {number, ""} ->
        number

      _ ->
        {number, ""} = Float.parse(value)
        number
    end
  end

  defp numeric?("0x" <> value), do: match?({_, ""}, Integer.parse(value, 16))

  defp numeric?(value) when is_binary(value) do
    match?({_, ""}, Integer.parse(value)) or match?({_, ""}, Float.parse(value))
  end

  defp numeric?(_value), do: false

  # Small RFC-4180 reader sufficient for the Garmin profile files.
  defp csv(text), do: text |> String.split(["\r\n", "\n"], trim: true) |> Enum.map(&csv_line/1)
  defp csv_line(line), do: csv_line(String.to_charlist(line), [], [], false)

  defp csv_line([], field, row, _quoted),
    do: Enum.reverse([field |> Enum.reverse() |> to_string() | row])

  defp csv_line([?\" | rest], field, row, false), do: csv_line(rest, field, row, true)
  defp csv_line([?\", ?\" | rest], field, row, true), do: csv_line(rest, [?\" | field], row, true)
  defp csv_line([?\" | rest], field, row, true), do: csv_line(rest, field, row, false)

  defp csv_line([?, | rest], field, row, false),
    do: csv_line(rest, [], [field |> Enum.reverse() |> to_string() | row], false)

  defp csv_line([char | rest], field, row, quoted),
    do: csv_line(rest, [char | field], row, quoted)

  defp xlsx_rows(path, sheet) do
    {:ok, files} = :zip.extract(String.to_charlist(path), [:memory])

    shared =
      files
      |> Enum.find_value(fn {name, data} -> if name == ~c"xl/sharedStrings.xml", do: data end)
      |> shared_strings()

    {_, xml} =
      Enum.find(files, fn {name, _data} ->
        name == String.to_charlist("xl/worksheets/" <> sheet)
      end)

    doc = SweetXml.parse(xml)

    rows =
      xpath(
        doc,
        ~x"//x:row"l
        |> add_namespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
      )

    rows
    |> Enum.map(fn row ->
      row
      |> xpath(
        ~x".//x:c"l
        |> add_namespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
      )
      |> Enum.reduce([], fn cell, values ->
        reference = xpath(cell, ~x"./@r"s) |> to_string()

        raw =
          xpath(
            cell,
            ~x".//x:v/text()"s
            |> add_namespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
          )
          |> to_string()

        value =
          if xpath(cell, ~x"./@t"s) |> to_string() == "s",
            do: Enum.at(shared, String.to_integer(raw)),
            else: raw

        put_cell(
          values,
          column_number(String.replace(reference, ~r/\d+$/, "")),
          xml_unescape(value || "")
        )
      end)
    end)
  end

  defp shared_strings(nil), do: []

  defp shared_strings(xml) do
    doc = SweetXml.parse(xml)

    xpath(
      doc,
      ~x"//x:si"l
      |> add_namespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
    )
    |> Enum.map(
      &(xpath(
          &1,
          ~x".//x:t/text()"s
          |> add_namespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
        )
        |> to_string())
    )
  end

  defp column_number(column),
    do: column |> String.to_charlist() |> Enum.reduce(0, fn char, acc -> acc * 26 + char - ?A end)

  defp put_cell(values, column, value) do
    values =
      if length(values) > column,
        do: values,
        else: values ++ List.duplicate(nil, column + 1 - length(values))

    List.replace_at(values, column, value)
  end

  defp xml_unescape(value),
    do:
      value
      |> String.replace("&amp;", "&")
      |> String.replace("&lt;", "<")
      |> String.replace("&gt;", ">")
      |> String.replace("&quot;", "\"")
      |> String.replace("&apos;", "'")
end

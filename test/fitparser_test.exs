defmodule DecoderTest do
  use ExUnit.Case

  alias Fitparser.FitDataRecord
  alias Fitparser.FitDataField

  describe "from_fit/1" do
    test "fails" do
      assert (Application.app_dir(:fitparser) <> "non existent")
             |> Fitparser.Decoder.from_fit() ==
               {:error, "Error opening file"}
    end

    test "success" do
      actual =
        (Application.app_dir(:fitparser) <> "/priv/examples/WeightScaleSingleUser.fit")
        |> Fitparser.Decoder.from_fit!()

      assert normalize_field_order(decoded_term()) == normalize_field_order(actual)
    end
  end

  describe "load_fit/1" do
    test "invalid content" do
      assert Fitparser.Decoder.load_fit("sratatata") ==
               {:error, "Invalid FIT header"}
    end

    test "reports truncated FIT files" do
      data = File.read!("priv/examples/WeightScaleSingleUser.fit")
      assert {:error, "Truncated FIT file"} = Fitparser.Decoder.load_fit(binary_part(data, 0, 20))
    end

    test "success from bytes" do
      actual =
        (Application.app_dir(:fitparser) <> "/priv/examples/WeightScaleSingleUser.fit")
        |> File.read!()
        |> Fitparser.Decoder.load_fit!()

      assert normalize_field_order(decoded_term()) == normalize_field_order(actual)
    end

    test "validates the FIT CRC when requested" do
      path = Application.app_dir(:fitparser) <> "/priv/examples/WeightScaleSingleUser.fit"
      data = File.read!(path)

      assert {:ok, _decoded} = Fitparser.Decoder.load_fit(data, validate_crc: true)

      <<prefix::binary-size(20), byte, suffix::binary>> = data
      tampered = <<prefix::binary, Bitwise.bxor(byte, 1), suffix::binary>>

      assert {:error, "Invalid FIT CRC"} =
               Fitparser.Decoder.load_fit(tampered, validate_crc: true)
    end

    test "validates an extended header CRC at its protocol-defined offset" do
      header_without_crc = <<16, 16, 0::little-16, 0::little-32, ".FIT">>
      header_crc = CRC.crc(:crc_16, header_without_crc)
      data = <<header_without_crc::binary, header_crc::little-16, 0xAA, 0xBB, 0::little-16>>

      assert Fitparser.Crc.valid_sections?(data)
      assert {:ok, %{}} = Fitparser.Decoder.load_fit(data, validate_crc: true)
    end

    test "resolves developer field descriptions" do
      path = Application.app_dir(:fitparser) <> "/priv/examples/DeveloperData.fit"
      [record | _] = Fitparser.Decoder.from_fit!(path)[:record]
      field = Enum.find(record.fields, &(&1.name == "doughnuts_earned"))

      assert field.name == "doughnuts_earned"
      assert field.units == "doughnuts"
      assert field.value == 1
      assert field.developer_data_index == 0
    end

    test "preserves FIT definition field order" do
      [record | _] =
        (Application.app_dir(:fitparser) <> "/priv/examples/WeightScaleSingleUser.fit")
        |> Fitparser.Decoder.from_fit!()
        |> Map.fetch!(:device_info)

      assert Enum.map(record.fields, & &1.name) == [
               "timestamp",
               "battery_voltage",
               "cum_operating_time"
             ]
    end

    test "expands component fields" do
      record =
        "priv/examples/activity_poolswim_with_hr.fit"
        |> Fitparser.Decoder.from_fit!()
        |> Map.fetch!(:record)
        |> Enum.find(fn record -> Enum.any?(record.fields, &(&1.name == "speed")) end)

      refute Enum.any?(record.fields, &(&1.name == "enhanced_speed"))

      expanded =
        "priv/examples/activity_poolswim_with_hr.fit"
        |> Fitparser.Decoder.from_fit!(expand_components: true)
        |> Map.fetch!(:record)
        |> Enum.find(fn record -> Enum.any?(record.fields, &(&1.name == "speed")) end)

      assert Enum.any?(expanded.fields, &(&1.name == "enhanced_speed"))
    end

    test "can disable component expansion" do
      data = File.read!("priv/examples/activity_poolswim_with_hr.fit")

      records = Fitparser.Decoder.load_fit!(data)[:record]

      refute Enum.any?(records, fn record ->
               Enum.any?(record.fields, &(&1.name == "enhanced_speed"))
             end)
    end

    test "normalizes HR component timestamps against their FIT timestamp base" do
      records =
        "priv/examples/activity_poolswim_with_hr.fit"
        |> Fitparser.Decoder.from_fit!(expand_components: true)
        |> Map.fetch!(:hr)

      record =
        Enum.find(
          records,
          &Enum.any?(&1.fields, fn field -> field.name == "event_timestamp_12" end)
        )

      assert Enum.any?(record.fields, fn
               %{name: "event_timestamp", value: value} when value > 1_000_000_000 -> true
               _ -> false
             end)
    end

    test "can return FIT timestamps as Unix seconds" do
      data = File.read!("priv/examples/WeightScaleSingleUser.fit")
      [record | _] = Fitparser.Decoder.load_fit!(data)[:weight_scale]
      timestamp = Enum.find(record.fields, &(&1.name == "timestamp"))

      assert timestamp.value == 1_252_532_280
    end
  end

  test "decode aliases load_fit" do
    data = File.read!("priv/examples/WeightScaleSingleUser.fit")

    assert Fitparser.Decoder.decode(data) ==
             {:ok, Fitparser.Decoder.load_fit!(data)}

    assert Fitparser.Decoder.decode!(data) == Fitparser.Decoder.load_fit!(data)
  end

  test "applies processors in order" do
    data = File.read!("priv/examples/WeightScaleSingleUser.fit")

    result =
      Fitparser.Decoder.load_fit!(data,
        processors: [
          fn record -> %{record | kind: String.to_atom("processed_#{record.kind}")} end,
          fn record, _opts ->
            %{record | fields: Enum.map(record.fields, &%{&1 | units: :processed})}
          end
        ]
      )

    assert [%FitDataRecord{kind: :processed_weight_scale, fields: fields} | _] =
             result[:weight_scale]

    assert Enum.all?(fields, &(&1.units == :processed))
  end

  test "supports module processors with processor options" do
    data = File.read!("priv/examples/WeightScaleSingleUser.fit")

    result =
      Fitparser.Decoder.load_fit!(data,
        processors: [{__MODULE__.TestProcessor, [suffix: "_custom"]}]
      )

    assert [%FitDataRecord{kind: :weight_scale_custom} | _] = result[:weight_scale]
  end

  test "can include FIT structural metadata" do
    data = File.read!("priv/examples/WeightScaleSingleUser.fit")

    result = Fitparser.Decoder.decode!(data, include_metadata: true)

    assert [%Fitparser.FitDataHeader{header_size: 14, data_size: 134} | _] = result["__headers__"]
    assert [%Fitparser.FitDataDefinition{} | _] = result["__definitions__"]
    assert [%Fitparser.FitDataCrc{valid: true} | _] = result["__crcs__"]
  end

  test "preserves unknown messages and fields" do
    body = <<0x40, 0, 0, 999::little-16, 1, 0, 1, 2, 0, 42>>

    data =
      <<14, 16, 0::little-16, byte_size(body)::little-32, ".FIT", 0::little-16, body::binary,
        0::little-16>>

    result = Fitparser.Decoder.decode!(data)
    assert %{"message_999" => [%FitDataRecord{fields: [field]}]} = result

    assert field == %FitDataField{name: "field_0", value: 42, units: nil, number: 0}
  end

  test "decodes byte arrays as byte lists" do
    body = <<0x40, 0, 0, 174::little-16, 1, 3, 3, 13, 0, 1, 2, 255>>

    data =
      <<14, 16, 0::little-16, byte_size(body)::little-32, ".FIT", 0::little-16, body::binary,
        0::little-16>>

    assert %{obdii_data: [%FitDataRecord{fields: [field]}]} =
             Fitparser.Decoder.decode!(data)

    assert field.name == "raw_data"
    assert field.value == [1, 2, 255]
  end

  test "decodes signed FIT invalid sentinels as nil" do
    body = <<0x40, 0, 0, 314::little-16, 1, 3, 2, 3, 0, 255, 127>>

    data =
      <<14, 16, 0::little-16, byte_size(body)::little-32, ".FIT", 0::little-16, body::binary,
        0::little-16>>

    assert %{hsa_body_battery_data: [%FitDataRecord{fields: [field]}]} =
             Fitparser.Decoder.decode!(data)

    assert field.name == "uncharged"
    assert field.value == [nil]
  end

  test "decodes IEEE floats with bit syntax" do
    body = <<0x40, 0, 0, 999::little-16, 1, 0, 4, 8, 0, 0, 0, 72, 65>>

    data =
      <<14, 16, 0::little-16, byte_size(body)::little-32, ".FIT", 0::little-16, body::binary,
        0::little-16>>

    assert %{"message_999" => records} = Fitparser.Decoder.decode!(data)
    assert hd(hd(records).fields).value == 12.5
  end

  test "uses the definition architecture for endian-capable base types" do
    body = <<0x40, 0, 0, 132::little-16, 1, 253, 4, 0x86, 0, 840_026_841::little-32>>

    data =
      <<14, 16, 0::little-16, byte_size(body)::little-32, ".FIT", 0::little-16, body::binary,
        0::little-16>>

    assert %{hr: [%FitDataRecord{fields: [field]}]} = Fitparser.Decoder.decode!(data)
    assert field.name == "timestamp"
    assert field.value == 1_471_092_441
  end

  defmodule TestProcessor do
    @behaviour Fitparser.Processor

    @impl true
    def process(record, opts),
      do: %{record | kind: String.to_atom(Atom.to_string(record.kind) <> opts[:suffix])}
  end

  def decoded_term do
    %{
      :device_info => [
        %FitDataRecord{
          fields: [
            %FitDataField{
              name: "cum_operating_time",
              number: 7,
              units: "s",
              value: 45126
            },
            %FitDataField{name: "battery_voltage", number: 10, units: "V", value: 1.5},
            %FitDataField{
              name: "timestamp",
              number: 253,
              units: "s",
              value: 1_252_532_280
            }
          ],
          kind: :device_info
        },
        %FitDataRecord{
          fields: [
            %FitDataField{
              name: "cum_operating_time",
              number: 7,
              units: "s",
              value: 45158
            },
            %FitDataField{name: "battery_voltage", number: 10, units: "V", value: 1.5},
            %FitDataField{
              name: "timestamp",
              number: 253,
              units: "s",
              value: 1_252_535_880
            }
          ],
          kind: :device_info
        }
      ],
      :file_id => [
        %FitDataRecord{
          fields: [
            %FitDataField{name: "type", number: 0, units: nil, value: "weight"},
            %FitDataField{
              name: "manufacturer",
              number: 1,
              units: nil,
              value: "dynastream"
            },
            %FitDataField{
              name: "garmin_product",
              number: 2,
              units: nil,
              value: "hrm_fit_single_byte_product_id"
            },
            %FitDataField{name: "serial_number", number: 3, units: nil, value: 1234},
            %FitDataField{
              name: "time_created",
              number: 4,
              units: nil,
              value: 1_252_528_680
            }
          ],
          kind: :file_id
        }
      ],
      :user_profile => [
        %FitDataRecord{
          fields: [
            %FitDataField{name: "gender", number: 1, units: nil, value: "male"},
            %FitDataField{name: "age", number: 2, units: "years", value: 47},
            %FitDataField{name: "height", number: 3, units: "m", value: 1.79},
            %FitDataField{name: "weight", number: 4, units: "kg", value: 71.0},
            %FitDataField{name: "message_index", number: 254, units: nil, value: 0}
          ],
          kind: :user_profile
        }
      ],
      :weight_scale => [
        %FitDataRecord{
          fields: [
            %FitDataField{name: "weight", number: 0, units: "kg", value: 75.8},
            %FitDataField{name: "percent_fat", number: 1, units: "%", value: 22.3},
            %FitDataField{
              name: "timestamp",
              number: 253,
              units: "s",
              value: 1_252_532_280
            }
          ],
          kind: :weight_scale
        },
        %FitDataRecord{
          fields: [
            %FitDataField{name: "weight", number: 0, units: "kg", value: 76.09},
            %FitDataField{name: "percent_fat", number: 1, units: "%", value: 25.1},
            %FitDataField{
              name: "timestamp",
              number: 253,
              units: "s",
              value: 1_252_535_880
            }
          ],
          kind: :weight_scale
        }
      ]
    }
  end

  defp normalize_field_order(records_by_kind) do
    Map.new(records_by_kind, fn {kind, records} ->
      {kind,
       Enum.map(records, fn record ->
         %{record | fields: Enum.sort_by(record.fields, & &1.number)}
       end)}
    end)
  end
end

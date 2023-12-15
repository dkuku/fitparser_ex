defmodule FitparserTest do
  use ExUnit.Case

  describe "from_fit/1" do
    test "fails" do
      assert (Application.app_dir(:fitparser) <> "non existent")
             |> Fitparser.Native.from_fit() ==
               {:error, "Error opening file"}
    end

    test "success" do
      assert (Application.app_dir(:fitparser) <> "/priv/examples/WeightScaleSingleUser.fit")
             |> Fitparser.Native.from_fit!() == decoded_term()
    end
  end

  describe "load_fit/1" do
    test "invalid content" do
      assert Fitparser.Native.load_fit("sratatata") == {:error, "Error parsing file"}
    end

    test "success from bytes" do
      assert (Application.app_dir(:fitparser) <> "/priv/examples/WeightScaleSingleUser.fit")
             |> File.read!()
             |> Fitparser.Native.load_fit!() == decoded_term()
    end
  end

  def decoded_term do
    %{
      "device_info" => [
        %{
          fields: [
            %{
              name: "cum_operating_time",
              value: 45126,
              number: 7,
              __struct__: :FitDataField,
              units: "s"
            },
            %{
              name: "battery_voltage",
              value: 1.5,
              number: 10,
              __struct__: :FitDataField,
              units: "V"
            },
            %{
              name: "timestamp",
              value: "2009-09-09T22:38:00+01:00",
              number: 253,
              __struct__: :FitDataField,
              units: "s"
            }
          ],
          __struct__: :FitDataRecord,
          kind: "device_info"
        },
        %{
          fields: [
            %{
              name: "cum_operating_time",
              value: 45158,
              number: 7,
              __struct__: :FitDataField,
              units: "s"
            },
            %{
              name: "battery_voltage",
              value: 1.5,
              number: 10,
              __struct__: :FitDataField,
              units: "V"
            },
            %{
              name: "timestamp",
              value: "2009-09-09T23:38:00+01:00",
              number: 253,
              __struct__: :FitDataField,
              units: "s"
            }
          ],
          __struct__: :FitDataRecord,
          kind: "device_info"
        }
      ],
      "file_id" => [
        %{
          fields: [
            %{name: "type", value: "weight", number: 0, __struct__: :FitDataField, units: ""},
            %{
              name: "manufacturer",
              value: "dynastream",
              number: 1,
              __struct__: :FitDataField,
              units: ""
            },
            %{name: "garmin_product", value: 22, number: 2, __struct__: :FitDataField, units: ""},
            %{
              name: "serial_number",
              value: 1234,
              number: 3,
              __struct__: :FitDataField,
              units: ""
            },
            %{
              name: "time_created",
              value: "2009-09-09T21:38:00+01:00",
              number: 4,
              __struct__: :FitDataField,
              units: ""
            }
          ],
          __struct__: :FitDataRecord,
          kind: "file_id"
        }
      ],
      "user_profile" => [
        %{
          fields: [
            %{name: "gender", value: "male", number: 1, __struct__: :FitDataField, units: ""},
            %{name: "age", value: 47, number: 2, __struct__: :FitDataField, units: "years"},
            %{name: "height", value: 1.79, number: 3, __struct__: :FitDataField, units: "m"},
            %{name: "weight", value: 71.0, number: 4, __struct__: :FitDataField, units: "kg"},
            %{name: "message_index", value: 0, number: 254, __struct__: :FitDataField, units: ""}
          ],
          __struct__: :FitDataRecord,
          kind: "user_profile"
        }
      ],
      "weight_scale" => [
        %{
          fields: [
            %{name: "weight", value: 7580, number: 0, __struct__: :FitDataField, units: "kg"},
            %{name: "percent_fat", value: 22.3, number: 1, __struct__: :FitDataField, units: "%"},
            %{
              name: "timestamp",
              value: "2009-09-09T22:38:00+01:00",
              number: 253,
              __struct__: :FitDataField,
              units: "s"
            }
          ],
          __struct__: :FitDataRecord,
          kind: "weight_scale"
        },
        %{
          fields: [
            %{name: "weight", value: 7609, number: 0, __struct__: :FitDataField, units: "kg"},
            %{name: "percent_fat", value: 25.1, number: 1, __struct__: :FitDataField, units: "%"},
            %{
              name: "timestamp",
              value: "2009-09-09T23:38:00+01:00",
              number: 253,
              __struct__: :FitDataField,
              units: "s"
            }
          ],
          __struct__: :FitDataRecord,
          kind: "weight_scale"
        }
      ]
    }
  end
end

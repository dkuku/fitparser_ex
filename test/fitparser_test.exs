defmodule Fitparser.NativeTest do
  use ExUnit.Case

  alias Fitparser.FitDataRecord
  alias Fitparser.FitDataField

  describe "from_fit/1" do
    test "fails" do
      assert (Application.app_dir(:fitparser) <> "non existent")
             |> Fitparser.Native.from_fit() ==
               {:error, "Error opening file"}
    end

    test "success" do
      assert decoded_term() ==
               (Application.app_dir(:fitparser) <> "/priv/examples/WeightScaleSingleUser.fit")
               |> Fitparser.Native.from_fit!()
    end
  end

  describe "load_fit/1" do
    test "invalid content" do
      assert Fitparser.Native.load_fit("sratatata") ==
               {:error, "Error parsing file"}
    end

    test "success from bytes" do
      assert decoded_term() ==
               (Application.app_dir(:fitparser) <> "/priv/examples/WeightScaleSingleUser.fit")
               |> File.read!()
               |> Fitparser.Native.load_fit!()
    end
  end

  def decoded_term do
    %{
      "device_info" => [
        %FitDataRecord{
          fields: [
            %FitDataField{
              name: "cum_operating_time",
              number: 7,
              units: "s",
              value: "45126"
            },
            %FitDataField{
              name: "battery_voltage",
              number: 10,
              units: "V",
              value: "1.5"
            },
            %FitDataField{
              name: "timestamp",
              number: 253,
              units: "s",
              value: "2009-09-09 22:38:00 +01:00"
            }
          ],
          kind: "device_info"
        },
        %FitDataRecord{
          fields: [
            %FitDataField{
              name: "cum_operating_time",
              number: 7,
              units: "s",
              value: "45158"
            },
            %FitDataField{
              name: "battery_voltage",
              number: 10,
              units: "V",
              value: "1.5"
            },
            %FitDataField{
              name: "timestamp",
              number: 253,
              units: "s",
              value: "2009-09-09 23:38:00 +01:00"
            }
          ],
          kind: "device_info"
        }
      ],
      "file_id" => [
        %FitDataRecord{
          fields: [
            %FitDataField{
              name: "type",
              number: 0,
              units: "",
              value: "weight"
            },
            %FitDataField{
              name: "manufacturer",
              number: 1,
              units: "",
              value: "dynastream"
            },
            %FitDataField{
              name: "garmin_product",
              number: 2,
              units: "",
              value: "22"
            },
            %FitDataField{
              name: "serial_number",
              number: 3,
              units: "",
              value: "1234"
            },
            %FitDataField{
              name: "time_created",
              number: 4,
              units: "",
              value: "2009-09-09 21:38:00 +01:00"
            }
          ],
          kind: "file_id"
        }
      ],
      "user_profile" => [
        %FitDataRecord{
          fields: [
            %FitDataField{
              name: "gender",
              number: 1,
              units: "",
              value: "male"
            },
            %FitDataField{
              name: "age",
              number: 2,
              units: "years",
              value: "47"
            },
            %FitDataField{
              name: "height",
              number: 3,
              units: "m",
              value: "1.79"
            },
            %FitDataField{
              name: "weight",
              number: 4,
              units: "kg",
              value: "71"
            },
            %FitDataField{
              name: "message_index",
              number: 254,
              units: "",
              value: "0"
            }
          ],
          kind: "user_profile"
        }
      ],
      "weight_scale" => [
        %FitDataRecord{
          fields: [
            %FitDataField{
              name: "weight",
              number: 0,
              units: "kg",
              value: "7580"
            },
            %FitDataField{
              name: "percent_fat",
              number: 1,
              units: "%",
              value: "22.3"
            },
            %FitDataField{
              name: "timestamp",
              number: 253,
              units: "s",
              value: "2009-09-09 22:38:00 +01:00"
            }
          ],
          kind: "weight_scale"
        },
        %FitDataRecord{
          fields: [
            %FitDataField{
              name: "weight",
              number: 0,
              units: "kg",
              value: "7609"
            },
            %FitDataField{
              name: "percent_fat",
              number: 1,
              units: "%",
              value: "25.1"
            },
            %FitDataField{
              name: "timestamp",
              number: 253,
              units: "s",
              value: "2009-09-09 23:38:00 +01:00"
            }
          ],
          kind: "weight_scale"
        }
      ]
    }
  end
end

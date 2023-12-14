defmodule FitparserTest do
  use ExUnit.Case

  describe "read_to_json/1" do
    test "fails" do
      assert (Application.app_dir(:fitparser) <> "non existent")
             |> Fitparser.Native.read_to_json() ==
               {:error, "Error opening file"}
    end

    test "success" do
      assert (Application.app_dir(:fitparser) <> "/priv/examples/WeightScaleSingleUser.fit")
             |> Fitparser.Native.read_to_json!()
             |> Jason.decode!() ==
               [
                 %{
                   "fields" => [
                     %{"name" => "type", "number" => 0, "units" => "", "value" => "weight"},
                     %{
                       "name" => "manufacturer",
                       "number" => 1,
                       "units" => "",
                       "value" => "dynastream"
                     },
                     %{"name" => "garmin_product", "number" => 2, "units" => "", "value" => 22},
                     %{"name" => "serial_number", "number" => 3, "units" => "", "value" => 1234},
                     %{
                       "name" => "time_created",
                       "number" => 4,
                       "units" => "",
                       "value" => "2009-09-09T21:38:00+01:00"
                     }
                   ],
                   "kind" => "file_id"
                 },
                 %{
                   "fields" => [
                     %{"name" => "gender", "number" => 1, "units" => "", "value" => "male"},
                     %{"name" => "age", "number" => 2, "units" => "years", "value" => 47},
                     %{"name" => "height", "number" => 3, "units" => "m", "value" => 1.79},
                     %{"name" => "weight", "number" => 4, "units" => "kg", "value" => 71.0},
                     %{"name" => "message_index", "number" => 254, "units" => "", "value" => 0}
                   ],
                   "kind" => "user_profile"
                 },
                 %{
                   "fields" => [
                     %{"name" => "weight", "number" => 0, "units" => "kg", "value" => 7580},
                     %{"name" => "percent_fat", "number" => 1, "units" => "%", "value" => 22.3},
                     %{
                       "name" => "timestamp",
                       "number" => 253,
                       "units" => "s",
                       "value" => "2009-09-09T22:38:00+01:00"
                     }
                   ],
                   "kind" => "weight_scale"
                 },
                 %{
                   "fields" => [
                     %{
                       "name" => "cum_operating_time",
                       "number" => 7,
                       "units" => "s",
                       "value" => 45126
                     },
                     %{
                       "name" => "battery_voltage",
                       "number" => 10,
                       "units" => "V",
                       "value" => 1.5
                     },
                     %{
                       "name" => "timestamp",
                       "number" => 253,
                       "units" => "s",
                       "value" => "2009-09-09T22:38:00+01:00"
                     }
                   ],
                   "kind" => "device_info"
                 },
                 %{
                   "fields" => [
                     %{"name" => "weight", "number" => 0, "units" => "kg", "value" => 7609},
                     %{"name" => "percent_fat", "number" => 1, "units" => "%", "value" => 25.1},
                     %{
                       "name" => "timestamp",
                       "number" => 253,
                       "units" => "s",
                       "value" => "2009-09-09T23:38:00+01:00"
                     }
                   ],
                   "kind" => "weight_scale"
                 },
                 %{
                   "fields" => [
                     %{
                       "name" => "cum_operating_time",
                       "number" => 7,
                       "units" => "s",
                       "value" => 45158
                     },
                     %{
                       "name" => "battery_voltage",
                       "number" => 10,
                       "units" => "V",
                       "value" => 1.5
                     },
                     %{
                       "name" => "timestamp",
                       "number" => 253,
                       "units" => "s",
                       "value" => "2009-09-09T23:38:00+01:00"
                     }
                   ],
                   "kind" => "device_info"
                 }
               ]
    end
  end

  describe "to_json/1" do
    test "invalid content" do
      assert Fitparser.Native.to_json("sratatata") == {:error, "Error parsing file"}
    end

    test "success from bytes" do
      assert (Application.app_dir(:fitparser) <> "/priv/examples/WeightScaleSingleUser.fit")
             |> File.read!()
             |> Fitparser.Native.to_json!()
             |> Jason.decode!() ==
               [
                 %{
                   "fields" => [
                     %{"name" => "type", "number" => 0, "units" => "", "value" => "weight"},
                     %{
                       "name" => "manufacturer",
                       "number" => 1,
                       "units" => "",
                       "value" => "dynastream"
                     },
                     %{"name" => "garmin_product", "number" => 2, "units" => "", "value" => 22},
                     %{"name" => "serial_number", "number" => 3, "units" => "", "value" => 1234},
                     %{
                       "name" => "time_created",
                       "number" => 4,
                       "units" => "",
                       "value" => "2009-09-09T21:38:00+01:00"
                     }
                   ],
                   "kind" => "file_id"
                 },
                 %{
                   "fields" => [
                     %{"name" => "gender", "number" => 1, "units" => "", "value" => "male"},
                     %{"name" => "age", "number" => 2, "units" => "years", "value" => 47},
                     %{"name" => "height", "number" => 3, "units" => "m", "value" => 1.79},
                     %{"name" => "weight", "number" => 4, "units" => "kg", "value" => 71.0},
                     %{"name" => "message_index", "number" => 254, "units" => "", "value" => 0}
                   ],
                   "kind" => "user_profile"
                 },
                 %{
                   "fields" => [
                     %{"name" => "weight", "number" => 0, "units" => "kg", "value" => 7580},
                     %{"name" => "percent_fat", "number" => 1, "units" => "%", "value" => 22.3},
                     %{
                       "name" => "timestamp",
                       "number" => 253,
                       "units" => "s",
                       "value" => "2009-09-09T22:38:00+01:00"
                     }
                   ],
                   "kind" => "weight_scale"
                 },
                 %{
                   "fields" => [
                     %{
                       "name" => "cum_operating_time",
                       "number" => 7,
                       "units" => "s",
                       "value" => 45126
                     },
                     %{
                       "name" => "battery_voltage",
                       "number" => 10,
                       "units" => "V",
                       "value" => 1.5
                     },
                     %{
                       "name" => "timestamp",
                       "number" => 253,
                       "units" => "s",
                       "value" => "2009-09-09T22:38:00+01:00"
                     }
                   ],
                   "kind" => "device_info"
                 },
                 %{
                   "fields" => [
                     %{"name" => "weight", "number" => 0, "units" => "kg", "value" => 7609},
                     %{"name" => "percent_fat", "number" => 1, "units" => "%", "value" => 25.1},
                     %{
                       "name" => "timestamp",
                       "number" => 253,
                       "units" => "s",
                       "value" => "2009-09-09T23:38:00+01:00"
                     }
                   ],
                   "kind" => "weight_scale"
                 },
                 %{
                   "fields" => [
                     %{
                       "name" => "cum_operating_time",
                       "number" => 7,
                       "units" => "s",
                       "value" => 45158
                     },
                     %{
                       "name" => "battery_voltage",
                       "number" => 10,
                       "units" => "V",
                       "value" => 1.5
                     },
                     %{
                       "name" => "timestamp",
                       "number" => 253,
                       "units" => "s",
                       "value" => "2009-09-09T23:38:00+01:00"
                     }
                   ],
                   "kind" => "device_info"
                 }
               ]
    end
  end
end

defmodule Fitparser.FitDataRecord do
  defstruct [:kind, :fields]
end

defmodule Fitparser.FitDataField do
  defstruct [:name, :value, :units, :number, :developer_data_index]
end

defmodule Fitparser.FitDataHeader do
  defstruct [:header_size, :protocol_version, :profile_version, :data_size]
end

defmodule Fitparser.FitDataDefinition do
  defstruct [:local, :global, :endian, :fields, :developer_fields]
end

defmodule Fitparser.FitDataCrc do
  defstruct [:value, :valid]
end

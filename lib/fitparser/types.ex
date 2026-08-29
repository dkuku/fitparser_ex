defmodule Fitparser.FitDataRecord do
  @moduledoc false
  defstruct [:kind, :fields]
end

defmodule Fitparser.FitDataField do
  @moduledoc false
  defstruct [:name, :value, :units, :number, :developer_data_index]
end

defmodule Fitparser.FitDataHeader do
  @moduledoc false
  defstruct [:header_size, :protocol_version, :profile_version, :data_size]
end

defmodule Fitparser.FitDataDefinition do
  @moduledoc false
  defstruct [:local, :global, :endian, :fields, :developer_fields]
end

defmodule Fitparser.FitDataCrc do
  @moduledoc false
  defstruct [:value, :valid]
end

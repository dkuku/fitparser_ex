defmodule Fitparser.FieldDefinition do
  @moduledoc "Metadata for a field in the Garmin FIT profile."

  @enforce_keys [:name, :type]
  defstruct [
    :name,
    :type,
    :scale,
    :offset,
    :units,
    :enum,
    :array,
    :components,
    :bits,
    :accumulate,
    :ref_field_name,
    :ref_field_value,
    :comment,
    :subfields
  ]
end

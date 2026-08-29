defmodule Fitparser.Processor do
  @moduledoc """
  Behaviour for post-processing decoded FIT records.

  A processor receives one `%Fitparser.FitDataRecord{}` and must return the
  record to keep. Processors run in the order supplied to the decoder.
  """

  alias Fitparser.FitDataRecord

  @callback process(FitDataRecord.t(), keyword()) :: FitDataRecord.t()

  @doc false
  def apply(record, processor, opts) when is_atom(processor), do: processor.process(record, opts)

  def apply(record, {processor, processor_opts}, opts) when is_atom(processor),
    do: processor.process(record, Keyword.merge(opts, processor_opts))

  def apply(record, processor, _opts) when is_function(processor, 1), do: processor.(record)
  def apply(record, processor, opts) when is_function(processor, 2), do: processor.(record, opts)

  def apply(_record, processor, _opts), do: raise(ArgumentError, "invalid FIT processor: #{inspect(processor)}")
end

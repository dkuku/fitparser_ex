defmodule Fitparser.Native do
  use Rustler, otp_app: :fitparser, crate: "fitparser_native"

  # When your NIF is loaded, it will override this function.
  def to_json(_a), do: :erlang.nif_error(:nif_not_loaded)

  def to_json!(a) do
    case to_json(a) do
      {:ok, result} -> result
      {:error, err} -> raise err
    end
  end
end

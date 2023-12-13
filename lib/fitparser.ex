defmodule Fitparser.Native do
  use Rustler, otp_app: :fitparser, crate: "fitparser_native"

  # When your NIF is loaded, it will override this function.
  def read(_a), do: :erlang.nif_error(:nif_not_loaded)
end

defmodule Fitparser.FitDataRecord do
  @moduledoc """
  The same struct is returned by the rust crate.
  """
  defstruct [
    :kind,
    :fields
  ]
end

defmodule Fitparser.FitDataField do
  @moduledoc """
  The same struct is returned by the rust crate.
  """
  defstruct [
    :name,
    :value,
    :units,
    :number
  ]
end

defmodule Fitparser.Native do
  @moduledoc """
  Fitparser allows to parse fit files generated by sport trackers.
  It is a rustler wrapper for [fitparser rust crate](https://docs.rs/fitparser/latest/fitparser/)
  """

  version = Mix.Project.config()[:version]

  unsupported = [
    "aarch64-unknown-linux-musl",
    "riscv64gc-unknown-linux-gnu",
    "x86_64-unknown-linux-musl"
  ]

  use RustlerPrecompiled,
    otp_app: :fitparser,
    crate: "fitparser_native",
    version: version,
    base_url: "https://github.com/dkuku/fitparser_ex/releases/download/v#{version}",
    force_build: System.get_env("RUSTLER_PRECOMPILATION_EXAMPLE_BUILD") in ["1", "true"],
    targets: Enum.uniq(RustlerPrecompiled.Config.default_targets()) -- unsupported

  @doc """
  this function accepts binary fit file and returns the file converted to term
  """
  def from_fit(_a), do: :erlang.nif_error(:nif_not_loaded)

  def from_fit!(a) do
    case from_fit(a) do
      {:ok, result} -> result
      {:error, err} -> raise err
    end
  end

  @doc """
  this function accepts a path to a file and returns the file converted to term
  """
  def load_fit(_a), do: :erlang.nif_error(:nif_not_loaded)

  def load_fit!(a) do
    case load_fit(a) do
      {:ok, result} -> result
      {:error, err} -> raise err
    end
  end
end

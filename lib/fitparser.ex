defmodule Fitparser.Native do
  @moduledoc """
  Fitparser allows to parse fit files generated by sport trackers.
  It is a rustler wrapper for [fitparser rust crate](https://docs.rs/fitparser/latest/fitparser/)
  """
  use Rustler, otp_app: :fitparser, crate: "fitparser_native"

  @doc """
  this function accepts binary fit file and returns the file converted to term
  """
  def to_term(_a), do: :erlang.nif_error(:nif_not_loaded)

  def to_term!(a) do
    case to_term(a) do
      {:ok, result} -> result
      {:error, err} -> raise err
    end
  end

  @doc """
  this function accepts a path to a file and returns the file converted to term
  """
  def read_to_term(_a), do: :erlang.nif_error(:nif_not_loaded)

  def read_to_term!(a) do
    case read_to_term(a) do
      {:ok, result} -> result
      {:error, err} -> raise err
    end
  end

  @doc """
  this function accepts binary fit file and returns the file converted to json
  """
  def to_json(_a), do: :erlang.nif_error(:nif_not_loaded)

  def to_json!(a) do
    case to_json(a) do
      {:ok, result} -> result
      {:error, err} -> raise err
    end
  end

  @doc """
  this function accepts a path to a file and returns the file converted to json
  """
  def read_to_json(_a), do: :erlang.nif_error(:nif_not_loaded)

  def read_to_json!(a) do
    case read_to_json(a) do
      {:ok, result} -> result
      {:error, err} -> raise err
    end
  end
end

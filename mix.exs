defmodule Fitparser.MixProject do
  use Mix.Project

  @version "0.3.0"
  def project do
    [
      app: :fitparser,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description()
    ]
  end

  defp description() do
    "Decode garmin fit files using rustler and fitparser crate"
  end

  defp package() do
    [
      files: [
        "lib",
        "mix.exs",
        "native/fitparser_native/.cargo",
        "native/fitparser_native/src",
        "native/fitparser_native/Cargo*",
        "checksum-*.exs",
        "README*"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/dkuku/fitparser_ex/",
        "Fitparser on Cargo" => "https://docs.rs/fitparser/latest/fitparser/",
        "Garmin FitSDK" => "https://developer.garmin.com/fit/overview/"
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rustler_precompiled, "~> 0.7"},
      {:decimal, "~> 2.1"},
      {:rustler, ">= 0.0.0", optional: true},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end

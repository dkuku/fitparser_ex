defmodule Fitparser.MixProject do
  use Mix.Project

  def project do
    [
      app: :fitparser,
      version: "0.1.5",
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
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README*),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/dkuku/fitparser_ex/",
        "Fitparser on Cargo" => "https://docs.rs/fitparser/latest/fitparser/",
        "Garmin FitSDK" => "https://developer.garmin.com/fit/overview/"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler_precompiled, "~> 0.7"},
      {:rustler, ">= 0.0.0", optional: true},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end

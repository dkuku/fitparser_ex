defmodule Fitparser.MixProject do
  use Mix.Project

  @version "0.5.0"
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

  defp description do
    "Decode Garmin FIT files using pure Elixir"
  end

  defp package do
    [
      files: [
        "lib",
        "Profile.xlsx",
        "mix.exs",
        "README*"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/dkuku/fitparser_ex/",
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
      {:decimal, "~> 2.1"},
      {:crc, "~> 0.10"},
      {:sweet_xml, "~> 0.7"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:styler, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end

defmodule Iodata.MixProject do
  use Mix.Project

  def project do
    [
      app: :iodata,
      version: "0.6.0",
      description:
        "A protocol for efficiently working with binaries, iolists, files etc. with minimal copying and I/O.",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: [
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/jallum/iodata"}
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:stream_data, "~> 1.0", only: :test},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end
end

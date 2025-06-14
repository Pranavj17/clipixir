defmodule Clipixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :clipixir,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: CLI],

      # Hex package metadata
      description: "A clean, minimal DSL for building dynamic forms in Elixir.",
      package: [
        licenses: ["MIT"],
        maintainers: ["Pranav J"],
        links: %{
          "GitHub" => "https://github.com/Pranavj17/form_builder_dsl",
          "Docs" => "https://hexdocs.pm/form_builder_dsl"
        }
      ],
      source_url: "https://github.com/Pranavj17/form_builder_dsl",
      homepage_url: "https://github.com/Pranavj17/form_builder_dsl"
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
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end
end

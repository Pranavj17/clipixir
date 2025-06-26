defmodule Clipixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :clipixir,
      version: "0.1.1",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: CLI],

      # Hex package metadata
      description: "A friendly and powerful command-line clipboard manager",
      package: [
        licenses: ["MIT"],
        maintainers: ["Pranav J"],
        links: %{
          "GitHub" => "https://github.com/Pranavj17/clipixir",
          "Docs" => "https://hexdocs.pm/clipixir"
        }
      ],
      source_url: "https://github.com/Pranavj17/clipixir",
      homepage_url: "https://github.com/Pranavj17/clipixir"
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

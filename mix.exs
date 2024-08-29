defmodule Instructor.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/martosaur/instructor_ex"

  def project do
    [
      app: :instructor,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      docs: docs(),
      package: package()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      description: "Structured prompting for LLMs",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "README",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.12"},
      {:jason, "~> 1.4.0"},
      {:req, "~> 0.5 or ~> 1.0"},
      {:nimble_options, "~> 1.1"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:mox, "~> 1.2", only: :test}
    ]
  end
end

defmodule InstructorLite.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/martosaur/instructor_lite"

  def project do
    [
      app: :instructor_lite,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      docs: docs(),
      package: package(),
      aliases: aliases()
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
        "CHANGELOG.md",
        "pages/philosophy.md",
        "pages/cookbooks/text-classification.livemd",
        "pages/cookbooks/vision.livemd",
        "pages/cookbooks/text-to-dataframes.livemd"
      ],
      nest_modules_by_prefix: [InstructorLite.Adapters],
      groups_for_modules: [
        Utilities: [InstructorLite.JSONSchema],
        Behaviours: [InstructorLite.Instruction, InstructorLite.Adapter],
        Adapters: [
          InstructorLite.Adapters.Anthropic,
          InstructorLite.Adapters.OpenAI,
          InstructorLite.Adapters.Llamacpp
        ]
      ],
      groups_for_extras: [
        Changelog: ["CHANGELOG.md"],
        Cookbooks: Path.wildcard("pages/cookbooks/*.livemd")
      ]
    ]
  end

  defp aliases do
    [docs: ["docs", &copy_images/1]]
  end

  defp copy_images(_) do
    File.mkdir_p("doc/files/")
    File.cp!("pages/cookbooks/files/shopify-screenshot.png", "doc/files/shopify-screenshot.png")
  end

  defp deps do
    [
      {:ecto, "~> 3.12"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5 or ~> 1.0", optional: true},
      {:nimble_options, "~> 1.1"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:mox, "~> 1.2", only: :test}
    ]
  end
end

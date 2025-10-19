defmodule InstructorLite.MixProject do
  use Mix.Project

  @version "1.1.1"
  @source_url "https://github.com/martosaur/instructor_lite"

  def project do
    [
      app: :instructor_lite,
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
        "Changelog" => "https://hexdocs.pm/instructor_lite/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "pages/migrating_from_instructor.md",
        "pages/local_development_guide.md",
        "pages/cookbooks/text-classification.livemd",
        "pages/cookbooks/vision.livemd",
        "pages/cookbooks/text-to-dataframes.livemd",
        "pages/cookbooks/batch-api.livemd",
        "pages/cookbooks/custom-ollama-adapter.livemd",
        "pages/cookbooks/openai-advanced-features.livemd"
      ],
      nest_modules_by_prefix: [InstructorLite.Adapters],
      groups_for_modules: [
        Utilities: [InstructorLite.JSONSchema],
        Behaviours: [InstructorLite.Instruction, InstructorLite.Adapter],
        Adapters: [
          InstructorLite.Adapters.Anthropic,
          InstructorLite.Adapters.OpenAI,
          InstructorLite.Adapters.Llamacpp,
          InstructorLite.Adapters.Gemini,
          InstructorLite.Adapters.ChatCompletionsCompatible
        ]
      ],
      groups_for_extras: [
        Changelog: ["CHANGELOG.md"],
        Cookbooks: Path.wildcard("pages/cookbooks/*.livemd")
      ],
      assets: %{
        "pages/cookbooks/files" => "files"
      }
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.12"},
      {:jason, "~> 1.4", optional: true},
      {:req, "~> 0.5 or ~> 1.0", optional: true},
      {:nimble_options, "~> 1.1"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:mox, "~> 1.2", only: :test},
      {:makeup_diff, "~> 0.1", only: :dev, runtime: false}
    ]
  end
end

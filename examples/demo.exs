defmodule UserInfo do
  use Ecto.Schema
  use InstructorLite.Instruction

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:age, :integer)
  end
end

defmodule Demo do
  def adapter(:openai), do: InstructorLite.Adapters.OpenAI
  def adapter(:anthropic), do: InstructorLite.Adapters.Anthropic
  def adapter(:gemini), do: InstructorLite.Adapters.Gemini

  def messages(:openai, prompt), do: %{ input: [  %{role: "user", content: prompt} ] }
  def messages(:anthropic, prompt), do: %{ messages: [  %{role: "user", content: prompt} ] }
  def messages(:gemini, prompt), do: %{ contents: [  %{role: "user", parts: [%{text: prompt}]} ] }

  def run_test(provider, model, config) do
    prompt = "John Doe is forty-two years old"
    expected = %UserInfo{name: "John Doe", age: 42}

    start_time = System.monotonic_time(:millisecond)

    result =
        InstructorLite.instruct(
          messages(provider, prompt) |> Map.put(:model, model),
          response_model: UserInfo,
          adapter: adapter(provider),
          adapter_context: config
        )

    elapsed_ms = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, ^expected} ->
        IO.puts("✓ #{provider} #{model}: Correct (#{elapsed_ms}ms)")
        {:correct, provider}

      {:ok, other} ->
        IO.puts("✗ #{provider} #{model}: Incorrect - Got #{inspect(other)} (#{elapsed_ms}ms)")
        {:incorrect, other}

      {:error, err} ->
        IO.puts("✗ #{provider} #{model}: Error - #{inspect(err)} (#{elapsed_ms}ms)")
        {:error, err}
    end
  end

  def provider_configs do
    [
      %{
        provider: :openai,
        models: ["gpt-5", "gpt-5-mini", "gpt-5-nano", "gpt-4o-mini", "gpt-4o", "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano"],
        env_key: "OPENAI_API_KEY"
      },
      %{
        provider: :anthropic,
        models: ["claude-opus-4-1", "claude-opus-4-0", "claude-sonnet-4-0", "claude-3-7-sonnet-latest", "claude-3-5-haiku-20241022"],
        env_key: "ANTHROPIC_API_KEY"
      },
      %{
        provider: :gemini,
        models: ["gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.5-flash-image-preview", "gemini-live-2.5-flash-preview", "gemini-2.5-flash-preview-native-audio-dialog", "gemini-2.0-flash-exp", "gemini-1.5-flash", "gemini-1.5-pro"],
        env_key: "GEMINI_API_KEY"
      }
    ]
  end

  def run_all_tests do
    IO.puts("\nRunning InstructorLite Tests\n" <> String.duplicate("=", 30))

    results = Enum.flat_map(provider_configs(), fn config ->
      case System.get_env(config.env_key) do
        nil ->
          IO.puts("⚠ #{config.provider}: Skipped (#{config.env_key} not set)")
          [{:skip, config.provider}]

        api_key ->
          IO.puts("\nTesting #{config.provider} models:")
          Enum.map(config.models, fn model ->
            run_test(config.provider, model, [api_key: api_key])
          end)
      end
    end)

    IO.puts("\n" <> String.duplicate("=", 30))
    IO.puts("Results Summary:")

    passed = Enum.count(results, fn {status, _} -> status == :correct end)
    failed = Enum.count(results, fn {status, _} -> status in [:incorrect, :error] end)
    skipped = Enum.count(results, fn {status, _} -> status == :skip end)

    IO.puts("  Passed: #{passed}")
    IO.puts("  Failed: #{failed}")
    IO.puts("  Skipped: #{skipped}")

    results
  end
end

# Run all tests
Demo.run_all_tests()


# parts: [%{text: prompt}]

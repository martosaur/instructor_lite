defmodule InstructorLite.Integration.LlamacppTest do
  use ExUnit.Case, async: false

  alias InstructorLite.TestSchemas
  alias InstructorLite.Adapters.Llamacpp

  @moduletag :integration

  describe "Llamacpp" do
    test "schemaless" do
      result =
        InstructorLite.instruct(
          %{prompt: "Who was the first president of the USA?"},
          response_model: %{name: :string, number_of_terms: :integer},
          adapter: Llamacpp,
          adapter_context: [
            http_client: Req,
            url: Application.fetch_env!(:instructor_lite, :llamacpp_url)
          ]
        )

      assert {:ok, %{name: name, number_of_terms: n}} = result
      assert is_binary(name)
      assert is_integer(n)
    end

    test "basic ecto schema" do
      result =
        InstructorLite.instruct(
          %{
            prompt:
              "Classify the following text: Hello, I am a Nigerian prince and I would like to give you $1,000,000."
          },
          response_model: TestSchemas.SpamPrediction,
          adapter: Llamacpp,
          adapter_context: [
            http_client: Req,
            url: Application.fetch_env!(:instructor_lite, :llamacpp_url)
          ]
        )

      assert {:ok, %{class: :spam, score: score}} = result
      assert is_float(score)
    end
  end
end

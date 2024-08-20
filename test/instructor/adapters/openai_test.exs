defmodule Instructor.Adapters.OpenAITest do
  use ExUnit.Case, async: true

  import Mox

  alias Instructor.Adapters.OpenAI
  alias Instructor.HTTPClient

  setup :verify_on_exit!

  describe "prompt/1" do
    test "removes instructor-specific parameters" do
      params = [
        response_model: "gpt-3.5",
        validation_context: "foo",
        max_retries: 99,
        mode: :json,
        foo: "bar"
      ]

      assert OpenAI.prompt(params) == %{foo: "bar"}
    end
  end

  describe "chat_completion/3" do
    test "default config" do
      prompt = %{hello: "prompt"}
      params = %{}

      config = [
        http_client: HTTPClient.Mock,
        api_key: "api-key"
      ]

      expect(HTTPClient.Mock, :post, fn url, options ->
        assert url == "https://api.openai.com/v1/chat/completions"

        assert options == [
                 receive_timeout: 60000,
                 json: %{hello: "prompt"},
                 auth: {:bearer, "api-key"}
               ]

        {:ok, %{status: 200, body: %{foo: "bar"}}}
      end)

      assert {:ok, %{foo: "bar"}} = OpenAI.chat_completion(prompt, params, config)
    end

    test "overridable config" do
      prompt = %{hello: "prompt"}
      params = %{}

      config = [
        http_client: HTTPClient.Mock,
        api_key: "api-key",
        url: "https://example.com",
        http_options: [foo: "bar"]
      ]

      expect(HTTPClient.Mock, :post, fn url, options ->
        assert url == "https://example.com"
        assert options == [foo: "bar", json: %{hello: "prompt"}, auth: {:bearer, "api-key"}]

        {:ok, %{status: 200, body: %{foo: "bar"}}}
      end)

      assert {:ok, %{foo: "bar"}} = OpenAI.chat_completion(prompt, params, config)
    end
  end
end

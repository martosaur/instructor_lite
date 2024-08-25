defmodule Instructor.Adapters.OpenAITest do
  use ExUnit.Case, async: true

  import Mox

  alias Instructor.Adapters.OpenAI
  alias Instructor.HTTPClient

  setup :verify_on_exit!

  describe "initial_prompt/2" do
    test "adds structured response parameters" do
      params = %{}

      assert OpenAI.initial_prompt(:json_schema, params) == %{
               messages: [
                 %{
                   role: "system",
                   content:
                     "As a genius expert, your task is to understand the content and provide the parsed objects in json that match json_schema\n"
                 }
               ],
               model: "gpt-4o-mini",
               response_format: %{type: "json_schema", json_schema: :json_schema}
             }
    end
  end

  describe "retry_prompt/3" do
    test "adds new chat entries" do
      params = %{messages: [], model: "gpt-4o-mini"}

      assert OpenAI.retry_prompt(params, %{foo: "bar"}, "list of errors") == %{
               messages: [
                 %{content: "{\"foo\":\"bar\"}", role: "assistant"},
                 %{
                   role: "system",
                   content:
                     "The response did not pass validation. Please try again and fix the following validation errors:\n\n\nlist of errors\n"
                 }
               ],
               model: "gpt-4o-mini"
             }
    end
  end

  describe "from_response/1" do
    test "decodes json from expected output" do
      response = %{
        "choices" => [
          %{
            "finish_reason" => "stop",
            "index" => 0,
            "logprobs" => nil,
            "message" => %{
              "content" => "{\"name\":\"George Washington\",\"birth_date\":\"1732-02-22\"}",
              "refusal" => nil,
              "role" => "assistant"
            }
          }
        ],
        "id" => "chatcmpl-9ztRV28j73RenwUce6D43rOcB6mQF",
        "model" => "gpt-4o-mini-2024-07-18",
        "object" => "chat.completion"
      }

      assert {:ok, %{"birth_date" => "1732-02-22", "name" => "George Washington"}} =
               OpenAI.from_response(response)
    end

    test "invalid json" do
      response = %{
        "choices" => [
          %{
            "finish_reason" => "stop",
            "index" => 0,
            "logprobs" => nil,
            "message" => %{
              "content" => "{{",
              "refusal" => nil,
              "role" => "assistant"
            }
          }
        ],
        "id" => "chatcmpl-9ztRV28j73RenwUce6D43rOcB6mQF",
        "model" => "gpt-4o-mini-2024-07-18",
        "object" => "chat.completion"
      }

      assert {:error, %Jason.DecodeError{}} = OpenAI.from_response(response)
    end

    test "returns refusal" do
      response = %{
        "choices" => [
          %{
            "finish_reason" => "stop",
            "index" => 0,
            "logprobs" => nil,
            "message" => %{
              "refusal" => "I'm sorry, I cannot assist with that request.",
              "role" => "assistant"
            }
          }
        ],
        "id" => "chatcmpl-9ztRV28j73RenwUce6D43rOcB6mQF",
        "model" => "gpt-4o-mini-2024-07-18",
        "object" => "chat.completion"
      }

      assert {:error, :refusal, "I'm sorry, I cannot assist with that request."} =
               OpenAI.from_response(response)
    end

    test "unexpected content" do
      response = "Internal Server Error"

      assert {:error, :unexpected_response, "Internal Server Error"} =
               OpenAI.from_response(response)
    end
  end

  describe "chat_completion/2" do
    test "overridable options" do
      params = %{hello: "world"}

      opts = [
        http_client: HTTPClient.Mock,
        api_key: "api-key",
        http_options: [foo: "bar"],
        url: "https://openai.compatible/v42/chat/compl"
      ]

      expect(HTTPClient.Mock, :post, fn url, options ->
        assert url == "https://openai.compatible/v42/chat/compl"

        assert options == [
                 foo: "bar",
                 json: %{hello: "world"},
                 auth: {:bearer, "api-key"}
               ]

        {:ok, %{status: 200, body: "response"}}
      end)

      assert {:ok, "response"} = OpenAI.chat_completion(params, opts)
    end

    test "non-200 response" do
      opts = [
        http_client: HTTPClient.Mock,
        api_key: "api-key"
      ]

      expect(HTTPClient.Mock, :post, fn _url, _options ->
        {:ok, %{status: 400, body: "response"}}
      end)

      assert {:error, %{status: 400, body: "response"}} = OpenAI.chat_completion(%{}, opts)
    end

    test "request error" do
      opts = [
        http_client: HTTPClient.Mock,
        api_key: "api-key"
      ]

      expect(HTTPClient.Mock, :post, fn _url, _options -> {:error, :timeout} end)

      assert {:error, :timeout} = OpenAI.chat_completion(%{}, opts)
    end
  end
end

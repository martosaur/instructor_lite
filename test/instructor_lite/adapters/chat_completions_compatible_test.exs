defmodule InstructorLite.Adapters.ChatCompletionsCompatibleTest do
  use ExUnit.Case, async: true

  import Mox

  alias InstructorLite.Adapters.ChatCompletionsCompatible
  alias InstructorLite.HTTPClient

  setup :verify_on_exit!

  describe "initial_prompt/2" do
    test "adds structured response parameters" do
      params = %{}

      assert ChatCompletionsCompatible.initial_prompt(params,
               json_schema: :json_schema,
               notes: "Explanation"
             ) == %{
               messages: [
                 %{
                   role: "system",
                   content: """
                   You're called by an Elixir application through the InstructorLite library. \
                   Your task is to understand what the application wants you to do and respond with JSON output that matches the schema. \
                   The output will be validated by the application against an Ecto schema and potentially some custom rules. \
                   You may be asked to adjust your response if it doesn't pass validation. \
                   Additional notes on the schema:
                   Explanation
                   """
                 }
               ],
               model: "gpt-4o-mini",
               response_format: %{
                 type: "json_schema",
                 json_schema: %{
                   name: "schema",
                   strict: true,
                   schema: :json_schema
                 }
               }
             }
    end
  end

  describe "retry_prompt/5" do
    test "adds new chat entries" do
      params = %{messages: [], model: "gpt-4o-mini"}

      assert ChatCompletionsCompatible.retry_prompt(
               params,
               %{foo: "bar"},
               "list of errors",
               nil,
               []
             ) == %{
               messages: [
                 %{content: "{\"foo\":\"bar\"}", role: "assistant"},
                 %{
                   role: "system",
                   content:
                     "The response did not pass validation. Please try again and fix the following validation errors:\n\nlist of errors\n"
                 }
               ],
               model: "gpt-4o-mini"
             }
    end
  end

  describe "parse_response/2" do
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
               ChatCompletionsCompatible.parse_response(response, [])
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

      assert {:error, _} =
               ChatCompletionsCompatible.parse_response(response, [])
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
               ChatCompletionsCompatible.parse_response(response, [])
    end

    test "unexpected content" do
      response = "Internal Server Error"

      assert {:error, :unexpected_response, "Internal Server Error"} =
               ChatCompletionsCompatible.parse_response(response, [])
    end
  end

  describe "send_request/2" do
    test "overridable options" do
      params = %{hello: "world"}

      opts = [
        adapter_context: [
          http_client: HTTPClient.Mock,
          api_key: "api-key",
          http_options: [foo: "bar"],
          url: "https://openai.compatible/v42/chat/compl"
        ]
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

      assert {:ok, "response"} = ChatCompletionsCompatible.send_request(params, opts)
    end

    test "non-200 response" do
      opts = [
        adapter_context: [
          http_client: HTTPClient.Mock,
          api_key: "api-key"
        ]
      ]

      expect(HTTPClient.Mock, :post, fn _url, _options ->
        {:ok, %{status: 400, body: "response"}}
      end)

      assert {:error, %{status: 400, body: "response"}} =
               ChatCompletionsCompatible.send_request(%{}, opts)
    end

    test "request error" do
      opts = [
        adapter_context: [
          http_client: HTTPClient.Mock,
          api_key: "api-key"
        ]
      ]

      expect(HTTPClient.Mock, :post, fn _url, _options -> {:error, :timeout} end)

      assert {:error, :timeout} = ChatCompletionsCompatible.send_request(%{}, opts)
    end
  end
end

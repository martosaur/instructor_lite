defmodule InstructorLite.Adapters.AnthropicTest do
  use ExUnit.Case, async: true

  import Mox

  alias InstructorLite.Adapters.Anthropic
  alias InstructorLite.HTTPClient

  setup :verify_on_exit!

  describe "initial_prompt/2" do
    test "forces tool choice" do
      params = %{}

      assert Anthropic.initial_prompt(params, json_schema: :json_schema, notes: "Explanation") ==
               %{
                 model: "claude-3-5-sonnet-20240620",
                 max_tokens: 1024,
                 system: """
                 You're called by an Elixir application through the InstructorLite library. \
                 Your task is to understand what the application wants you to do and respond with JSON output that matches the schema. \
                 The output will be validated by the application against an Ecto schema and potentially some custom rules. \
                 You may be asked to adjust your response if it doesn't pass validation. \
                 Additional notes on the schema:
                 Explanation
                 """,
                 tool_choice: %{name: "Schema", type: "tool"},
                 tools: [
                   %{
                     name: "Schema",
                     description:
                       "Correctly extracted `Schema` with all the required parameters with correct types",
                     input_schema: :json_schema
                   }
                 ]
               }
    end
  end

  describe "retry_prompt/5" do
    test "adds assistant reply and tool call error" do
      params = %{messages: []}

      response = %{
        "content" => [
          %{
            "id" => "toolu_01BjqsjAhY8W4PRFXWRMWbnm",
            "input" => %{"birth_date" => "1732-02-22", "name" => "George Washington"},
            "name" => "Schema",
            "type" => "tool_use"
          }
        ],
        "role" => "assistant"
      }

      assert Anthropic.retry_prompt(params, nil, "list of errors", response, []) == %{
               messages: [
                 %{
                   "content" => [
                     %{
                       "id" => "toolu_01BjqsjAhY8W4PRFXWRMWbnm",
                       "input" => %{"birth_date" => "1732-02-22", "name" => "George Washington"},
                       "name" => "Schema",
                       "type" => "tool_use"
                     }
                   ],
                   "role" => "assistant"
                 },
                 %{
                   content: [
                     %{
                       type: "tool_result",
                       is_error: true,
                       tool_use_id: "toolu_01BjqsjAhY8W4PRFXWRMWbnm",
                       content: """
                       The response did not pass validation. Please try again and fix the following validation errors:

                       list of errors
                       """
                     }
                   ],
                   role: "user"
                 }
               ]
             }
    end
  end

  describe "parse_response/2" do
    test "decodes json from expected output" do
      response = %{
        "content" => [
          %{
            "id" => "toolu_01BjqsjAhY8W4PRFXWRMWbnm",
            "input" => %{"birth_date" => "1732-02-22", "name" => "George Washington"},
            "name" => "Schema",
            "type" => "tool_use"
          }
        ],
        "id" => "msg_01Mpxg4KEpGoV55LT6ReTt4j",
        "model" => "claude-3-5-sonnet-20240620",
        "role" => "assistant",
        "stop_reason" => "tool_use",
        "stop_sequence" => nil,
        "type" => "message",
        "usage" => %{"input_tokens" => 409, "output_tokens" => 58}
      }

      assert {:ok, %{"birth_date" => "1732-02-22", "name" => "George Washington"}} =
               Anthropic.parse_response(response, [])
    end

    test "unexpected content" do
      response = "Internal Server Error"

      assert {:error, :unexpected_response, "Internal Server Error"} =
               Anthropic.parse_response(response, [])
    end
  end

  describe "send_request/2" do
    test "overridable options" do
      params = %{hello: "world"}

      opts = [
        adapter_context: [
          http_client: HTTPClient.Mock,
          api_key: "api-key",
          http_options: [
            foo: "bar",
            headers: [
              {"anthropic-beta", "beta1"},
              {"anthropic-version", "2024-01-01"}
            ]
          ],
          url: "https://anthropic.compatible/v42/message"
        ]
      ]

      expect(HTTPClient.Mock, :post, fn url, options ->
        assert url == "https://anthropic.compatible/v42/message"

        assert options == [
                 foo: "bar",
                 headers: [
                   {"anthropic-beta", "beta1"},
                   {"anthropic-version", "2024-01-01"},
                   {"x-api-key", "api-key"}
                 ],
                 json: %{hello: "world"}
               ]

        {:ok, %{status: 200, body: "response"}}
      end)

      assert {:ok, "response"} = Anthropic.send_request(params, opts)
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

      assert {:error, %{status: 400, body: "response"}} = Anthropic.send_request(%{}, opts)
    end

    test "request error" do
      opts = [
        adapter_context: [
          http_client: HTTPClient.Mock,
          api_key: "api-key"
        ]
      ]

      expect(HTTPClient.Mock, :post, fn _url, _options -> {:error, :timeout} end)

      assert {:error, :timeout} = Anthropic.send_request(%{}, opts)
    end
  end
end

defmodule InstructorLite.Adapters.OpenAITest do
  use ExUnit.Case, async: true

  import Mox

  alias InstructorLite.Adapters.OpenAI
  alias InstructorLite.HTTPClient

  setup :verify_on_exit!

  describe "initial_prompt/2" do
    test "adds structured response parameters" do
      params = %{}

      assert OpenAI.initial_prompt(params, json_schema: :json_schema, notes: "Explanation") == %{
               instructions: """
               As a genius expert, your task is to understand the content and provide the parsed objects in json that match json schema
               Additional notes on the schema:

               Explanation
               """,
               model: "gpt-4o-mini",
               text: %{
                 format: %{
                   name: "schema",
                   type: "json_schema",
                   strict: true,
                   schema: :json_schema
                 }
               }
             }
    end
  end

  describe "retry_prompt/5" do
    test "adds new chat entries if coversation state is disabled" do
      params = %{input: [], model: "gpt-4o-mini", instructions: "previous_instructions"}

      assert OpenAI.retry_prompt(params, %{foo: "bar"}, "list of errors", %{"store" => false}, []) ==
               %{
                 input: [
                   %{content: "{\"foo\":\"bar\"}", role: "assistant"},
                   %{
                     role: "system",
                     content:
                       "The response did not pass validation. Please try again and fix the following validation errors:\n\n\nlist of errors\n"
                   }
                 ],
                 model: "gpt-4o-mini",
                 instructions: "previous_instructions"
               }
    end

    test "supports flat text input for some reason" do
      params = %{
        input: "user calling adapter directly",
        model: "gpt-4o-mini",
        instructions: "previous_instructions"
      }

      assert OpenAI.retry_prompt(params, %{foo: "bar"}, "list of errors", %{"store" => false}, []) ==
               %{
                 input: [
                   %{content: "user calling adapter directly", role: "user"},
                   %{content: "{\"foo\":\"bar\"}", role: "assistant"},
                   %{
                     role: "system",
                     content:
                       "The response did not pass validation. Please try again and fix the following validation errors:\n\n\nlist of errors\n"
                   }
                 ],
                 model: "gpt-4o-mini",
                 instructions: "previous_instructions"
               }
    end

    test "uses conversation state if its enabled" do
      params = %{input: [], model: "gpt-4o-mini", instructions: "previous_instructions"}

      assert OpenAI.retry_prompt(
               params,
               %{foo: "bar"},
               "list of errors",
               %{"store" => true, "id" => "id123"},
               []
             ) == %{
               input: [
                 %{
                   role: "system",
                   content:
                     "The response did not pass validation. Please try again and fix the following validation errors:\n\n\nlist of errors\n"
                 }
               ],
               previous_response_id: "id123",
               model: "gpt-4o-mini"
             }
    end
  end

  describe "parse_response/2" do
    test "decodes json from expected output" do
      response = %{
        "output" => [
          %{
            "content" => [
              %{
                "annotations" => [],
                "text" => "{\"name\":\"John\",\"age\":22}",
                "type" => "output_text"
              }
            ],
            "id" => "msg_684a1c5678788192962d8d367cef6b5b02f3c7b30c409e39",
            "role" => "assistant",
            "status" => "completed",
            "type" => "message"
          }
        ],
        "error" => nil,
        "id" => "resp_684a1c55cf988192a31a297c41e8bdc802f3c7b30c409e39",
        "model" => "gpt-4o-mini-2024-07-18",
        "object" => "response",
        "store" => true
      }

      assert {:ok, %{"name" => "John", "age" => 22}} =
               OpenAI.parse_response(response, [])
    end

    test "isn't confused by reasoning" do
      response = %{
        "output" => [
          %{
            "id" => "rs_684b319d730c81a2946702c6a53a28260508fa8edf1ace4c",
            "summary" => [],
            "type" => "reasoning"
          },
          %{
            "content" => [
              %{
                "annotations" => [],
                "text" => "{\"name\":\"John\",\"age\":22}",
                "type" => "output_text"
              }
            ],
            "id" => "msg_684a1c5678788192962d8d367cef6b5b02f3c7b30c409e39",
            "role" => "assistant",
            "status" => "completed",
            "type" => "message"
          }
        ],
        "error" => nil,
        "id" => "resp_684a1c55cf988192a31a297c41e8bdc802f3c7b30c409e39",
        "model" => "gpt-4o-mini-2024-07-18",
        "object" => "response",
        "store" => true
      }

      assert {:ok, %{"name" => "John", "age" => 22}} =
               OpenAI.parse_response(response, [])
    end

    test "invalid json" do
      response = %{
        "output" => [
          %{
            "content" => [
              %{
                "annotations" => [],
                "text" => "{{",
                "type" => "output_text"
              }
            ],
            "id" => "msg_684a1c5678788192962d8d367cef6b5b02f3c7b30c409e39",
            "role" => "assistant",
            "status" => "completed",
            "type" => "message"
          }
        ],
        "error" => nil,
        "id" => "resp_684a1c55cf988192a31a297c41e8bdc802f3c7b30c409e39",
        "model" => "gpt-4o-mini-2024-07-18",
        "object" => "response",
        "store" => true
      }

      assert {:error, _} = OpenAI.parse_response(response, [])
    end

    test "returns refusal" do
      response = %{
        "output" => [
          %{
            "content" => [
              %{
                "refusal" => "I'm sorry, I cannot assist with that request.",
                "type" => "refusal"
              }
            ],
            "id" => "msg_684a1c5678788192962d8d367cef6b5b02f3c7b30c409e39",
            "role" => "assistant",
            "type" => "message"
          }
        ],
        "error" => nil,
        "id" => "resp_684a1c55cf988192a31a297c41e8bdc802f3c7b30c409e39",
        "model" => "gpt-4o-mini-2024-07-18",
        "object" => "response",
        "store" => true
      }

      assert {:error, :refusal, "I'm sorry, I cannot assist with that request."} =
               OpenAI.parse_response(response, [])
    end

    test "unexpected content" do
      response = "Internal Server Error"

      assert {:error, :unexpected_response, "Internal Server Error"} =
               OpenAI.parse_response(response, [])
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

      assert {:ok, "response"} = OpenAI.send_request(params, opts)
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

      assert {:error, %{status: 400, body: "response"}} = OpenAI.send_request(%{}, opts)
    end

    test "request error" do
      opts = [
        adapter_context: [
          http_client: HTTPClient.Mock,
          api_key: "api-key"
        ]
      ]

      expect(HTTPClient.Mock, :post, fn _url, _options -> {:error, :timeout} end)

      assert {:error, :timeout} = OpenAI.send_request(%{}, opts)
    end
  end
end

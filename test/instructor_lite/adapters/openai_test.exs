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
               You're called by an Elixir application through the InstructorLite library. \
               Your task is to understand what the application wants you to do and respond with JSON output that matches the schema. \
               The output will be validated by the application against an Ecto schema and potentially some custom rules. \
               You may be asked to adjust your response if it doesn't pass validation. \
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
                       "The response did not pass validation. Please try again and fix the following validation errors:\n\nlist of errors\n"
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
                       "The response did not pass validation. Please try again and fix the following validation errors:\n\nlist of errors\n"
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
                     "The response did not pass validation. Please try again and fix the following validation errors:\n\nlist of errors\n"
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

  describe "find_output/2" do
    test "finds output text in the response" do
      response = %{
        "background" => false,
        "created_at" => 1_755_478_833,
        "error" => nil,
        "id" => "resp_68a27b31e07c81a2953dcec99d53cd0b039a917c08fd5671",
        "incomplete_details" => nil,
        "instructions" => nil,
        "max_output_tokens" => nil,
        "max_tool_calls" => nil,
        "metadata" => %{},
        "model" => "gpt-4o-mini-2024-07-18",
        "object" => "response",
        "output" => [
          %{
            "content" => [
              %{
                "annotations" => [],
                "logprobs" => [],
                "text" => "Washington",
                "type" => "output_text"
              }
            ],
            "id" => "msg_68a27b327fd481a2ba29054f85dcb97d039a917c08fd5671",
            "role" => "assistant",
            "status" => "completed",
            "type" => "message"
          }
        ],
        "parallel_tool_calls" => true,
        "previous_response_id" => nil,
        "prompt_cache_key" => nil,
        "reasoning" => %{"effort" => nil, "summary" => nil},
        "safety_identifier" => nil,
        "service_tier" => "default",
        "status" => "completed",
        "store" => true,
        "temperature" => 1.0,
        "text" => %{"format" => %{"type" => "text"}, "verbosity" => "medium"},
        "tool_choice" => "auto",
        "tools" => [],
        "top_logprobs" => 0,
        "top_p" => 1.0,
        "truncation" => "disabled",
        "usage" => %{
          "input_tokens" => 23,
          "input_tokens_details" => %{"cached_tokens" => 0},
          "output_tokens" => 2,
          "output_tokens_details" => %{"reasoning_tokens" => 0},
          "total_tokens" => 25
        },
        "user" => nil
      }

      assert {:ok, "Washington"} =
               OpenAI.find_output(response, [])
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

      assert {:ok, "{\"name\":\"John\",\"age\":22}"} =
               OpenAI.find_output(response, [])
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
               OpenAI.find_output(response, [])
    end

    test "unexpected content" do
      response = "Internal Server Error"

      assert {:error, :unexpected_response, "Internal Server Error"} =
               OpenAI.find_output(response, [])
    end
  end
end

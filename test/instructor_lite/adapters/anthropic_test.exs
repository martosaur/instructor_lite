defmodule InstructorLite.Adapters.AnthropicTest do
  use ExUnit.Case, async: true

  import Mox

  alias InstructorLite.Adapters.Anthropic
  alias InstructorLite.HTTPClient

  setup :verify_on_exit!

  describe "initial_prompt/2" do
    test "uses structured output" do
      params = %{}

      assert Anthropic.initial_prompt(params, json_schema: :json_schema, notes: "Explanation") ==
               %{
                 model: "claude-haiku-4-5",
                 max_tokens: 1024,
                 system: """
                 You're called by an Elixir application through the InstructorLite library. \
                 Your task is to understand what the application wants you to do and respond with JSON output that matches the schema. \
                 The output will be validated by the application against an Ecto schema and potentially some custom rules. \
                 You may be asked to adjust your response if it doesn't pass validation. \
                 Additional notes on the schema:
                 Explanation
                 """,
                 output_config: %{format: %{schema: :json_schema, type: "json_schema"}}
               }
    end

    test "forces tool choice for legacy model" do
      params = %{model: "claude-opus-4-1-20250805"}

      assert Anthropic.initial_prompt(params, json_schema: :json_schema, notes: "Explanation") ==
               %{
                 model: "claude-opus-4-1-20250805",
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
    test "adds new chat entries" do
      params = %{messages: []}

      response = %{
        "content" => [
          %{
            "text" => "{\"name\":\"George Washington\",\"birth_date\":\"1732-02-22\"}",
            "type" => "text"
          }
        ],
        "id" => "msg_01EM4vMBchniYpub5C5MVJs4",
        "model" => "claude-haiku-4-5-20251001",
        "role" => "assistant",
        "stop_reason" => "end_turn",
        "stop_sequence" => nil,
        "type" => "message",
        "usage" => %{
          "cache_creation" => %{
            "ephemeral_1h_input_tokens" => 0,
            "ephemeral_5m_input_tokens" => 0
          },
          "cache_creation_input_tokens" => 0,
          "cache_read_input_tokens" => 0,
          "input_tokens" => 269,
          "output_tokens" => 20,
          "service_tier" => "standard"
        }
      }

      assert Anthropic.retry_prompt(params, nil, "list of errors", response, []) == %{
               messages: [
                 %{
                   "content" => [
                     %{
                       "type" => "text",
                       "text" => "{\"name\":\"George Washington\",\"birth_date\":\"1732-02-22\"}"
                     }
                   ],
                   "role" => "assistant"
                 },
                 %{
                   content:
                     "The response did not pass validation. Please try again and fix the following validation errors:\n\nlist of errors\n",
                   role: "user"
                 }
               ]
             }
    end

    test "adds assistant reply and tool call error for legacy model" do
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
        "model" => "claude-3-opus-latest",
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
            "text" => "{\"name\":\"George Washington\",\"birth_date\":\"1732-02-22\"}",
            "type" => "text"
          }
        ],
        "id" => "msg_01EM4vMBchniYpub5C5MVJs4",
        "model" => "claude-haiku-4-5-20251001",
        "role" => "assistant",
        "stop_reason" => "end_turn",
        "stop_sequence" => nil,
        "type" => "message",
        "usage" => %{
          "cache_creation" => %{
            "ephemeral_1h_input_tokens" => 0,
            "ephemeral_5m_input_tokens" => 0
          },
          "cache_creation_input_tokens" => 0,
          "cache_read_input_tokens" => 0,
          "input_tokens" => 269,
          "output_tokens" => 20,
          "service_tier" => "standard"
        }
      }

      assert {:ok, %{"birth_date" => "1732-02-22", "name" => "George Washington"}} =
               Anthropic.parse_response(response, [])
    end

    test "decodes json from expected output of legacy model" do
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

  describe "find_output/2" do
    test "finds text output" do
      response = %{
        "content" => [%{"text" => "Washington", "type" => "text"}],
        "id" => "msg_016zrCzBqd9Hvi4PHWNptfM6",
        "model" => "claude-sonnet-4-20250514",
        "role" => "assistant",
        "stop_reason" => "end_turn",
        "stop_sequence" => nil,
        "type" => "message",
        "usage" => %{
          "cache_creation" => %{
            "ephemeral_1h_input_tokens" => 0,
            "ephemeral_5m_input_tokens" => 0
          },
          "cache_creation_input_tokens" => 0,
          "cache_read_input_tokens" => 0,
          "input_tokens" => 23,
          "output_tokens" => 4,
          "service_tier" => "standard"
        }
      }

      assert {:ok, "Washington"} = Anthropic.find_output(response, [])
    end

    test "isn't confused by reasoning" do
      response = %{
        "content" => [
          %{
            "signature" =>
              "Eq4FCkYICxgCKkB+mj99JVauMoUANQo241mSCrKKu9XPY7od/8/Cyh0vQ1iBkLsRAgBIWVWli6lftjbLGL1f1/QruQf/Ie7Rfkc+Egx+tZHbX0/f+h19u5saDOeks8WduO1NHf9rdCIwWkRBBYrn9nP5acwWCvxaQ5KdwRhIaoL8qcP8C95mxDqnYX2/06+tkpQlcgVeMS+yKpUEHWWmO876ZLxRdBhoMhzO14eptlawVEJeXnMLFMJrZ4ngQAOzq+Rb2zItFIqWFzj3nrJVBvCDQlhpDvuUl4T09yNkO0OpaAWmYmSA8BmMoa6V4wfnoLX2olsF7g3kWL986E5PtV5HKejnJmmF1o5z/EHXZ+QnlQ8EEY1IG1FSf7lDemrY6HRb45cJydNWQXrUKRDnwNQtwBwWZVN3hjVmlGiNlA/r9UfCjWe3RqG5bRnz2cwfCa8cpVq68pzpB1FO92Jq5U4FI7x5ryktXgTyn9azSdII62LFVUtseHiI+NX1CIz9P/8Jwd+L0BOpYDmXqzJtCVlkY2tABrXpG4mvqSZgeUSq1G6Ga8QNK9h7w0GR6HumEkZMiSL8l6H4nLfW9QSMWrSqnlIRKljczK7jLaVIxPlSQaavMsD7OE1O5gKjZXioBl3yeKJ1fl6IvgkAhvjITGToBq7hgQ3aYYFCUvUYTjAbZyxU2lB/avYouhTowovBbJR5EyvERw6L/M/eWULFFu/kTIng9KUvfQw+kb2oJDFSCVXop3SOOpQjxwl0RryNeXxldZgeGRxNwKrBgrghe4YA/+74LGb+6E6WCUUKrpiNme7u3z6VhewmJeBSKlLlT8/f0P5oZ7i+WtlotIKwucA3aCToykwilkzv80oC6mGNTRPvPjn6Rf6bpkwQk0F7BJlaV6Ke1msYqJHPcGTy/GAYAQ==",
            "thinking" =>
              "The user is asking \"Who was the first president of the USA?\" which is George Washington. However, they want me to respond with JSON that matches the schema provided, which requires:\n- name (string)\n- birth_date (string)\n\nThe schema requires both \"name\" and \"birth_date\" fields.\n\nGeorge Washington was born on February 22, 1732.\n\nI need to return valid JSON matching the schema exactly:\n{\"name\": \"George Washington\", \"birth_date\": \"1732-02-22\"}\n\nLet me format this as a single line without pretty printing or markdown.",
            "type" => "thinking"
          },
          %{"text" => "George Washington", "type" => "text"}
        ],
        "id" => "msg_01GAXALFWbpbfHch4YeisbtA",
        "model" => "claude-haiku-4-5-20251001",
        "role" => "assistant",
        "stop_reason" => "end_turn",
        "stop_sequence" => nil,
        "type" => "message",
        "usage" => %{
          "cache_creation" => %{
            "ephemeral_1h_input_tokens" => 0,
            "ephemeral_5m_input_tokens" => 0
          },
          "cache_creation_input_tokens" => 0,
          "cache_read_input_tokens" => 0,
          "input_tokens" => 299,
          "output_tokens" => 157,
          "service_tier" => "standard"
        }
      }

      assert {:ok, "George Washington"} = Anthropic.find_output(response, [])
    end

    test "unexpected content" do
      response = "Internal Server Error"

      assert {:error, :unexpected_response, "Internal Server Error"} =
               Anthropic.find_output(response, [])
    end
  end

  describe "legacy_model?" do
    test "identifies all models" do
      # Claude 4.5 Opus models (not legacy)
      refute Anthropic.legacy_model?("claude-opus-4-5-20251101")
      refute Anthropic.legacy_model?("claude-opus-4-5")

      # Claude 4.5 Sonnet models (not legacy)
      refute Anthropic.legacy_model?("claude-sonnet-4-5")
      refute Anthropic.legacy_model?("claude-sonnet-4-5-20250929")

      # Claude 4.5 Haiku models (not legacy)
      refute Anthropic.legacy_model?("claude-haiku-4-5")
      refute Anthropic.legacy_model?("claude-haiku-4-5-20251001")

      # Claude 3.7 Sonnet models (legacy)
      assert Anthropic.legacy_model?("claude-3-7-sonnet-latest")
      assert Anthropic.legacy_model?("claude-3-7-sonnet-20250219")
      assert Anthropic.legacy_model?("anthropic.claude-3-7-sonnet-20250219-v1:0")
      assert Anthropic.legacy_model?("claude-3-7-sonnet@20250219")

      # Claude 3.5 Haiku models (legacy)
      assert Anthropic.legacy_model?("claude-3-5-haiku-latest")
      assert Anthropic.legacy_model?("claude-3-5-haiku-20241022")

      # Claude 4 Sonnet models (legacy)
      assert Anthropic.legacy_model?("claude-sonnet-4-20250514")
      assert Anthropic.legacy_model?("claude-sonnet-4-0")
      assert Anthropic.legacy_model?("claude-4-sonnet-20250514")
      assert Anthropic.legacy_model?("anthropic.claude-sonnet-4-20250514-v1:0")
      assert Anthropic.legacy_model?("claude-sonnet-4@20250514")

      # Claude 4 Opus models (legacy)
      assert Anthropic.legacy_model?("claude-opus-4-0")
      assert Anthropic.legacy_model?("claude-opus-4-20250514")
      assert Anthropic.legacy_model?("claude-4-opus-20250514")
      assert Anthropic.legacy_model?("anthropic.claude-opus-4-20250514-v1:0")
      assert Anthropic.legacy_model?("claude-opus-4@20250514")

      # Claude 4.1 Opus models (legacy)
      assert Anthropic.legacy_model?("claude-opus-4-1-20250805")
      assert Anthropic.legacy_model?("anthropic.claude-opus-4-1-20250805-v1:0")
      assert Anthropic.legacy_model?("claude-opus-4-1@20250805")

      # Claude 3 Opus models (legacy)
      assert Anthropic.legacy_model?("claude-3-opus-latest")
      assert Anthropic.legacy_model?("claude-3-opus-20240229")

      # Claude 3 Haiku models (legacy)
      assert Anthropic.legacy_model?("claude-3-haiku-20240307")
      assert Anthropic.legacy_model?("anthropic.claude-3-haiku-20240307-v1:0")
      assert Anthropic.legacy_model?("claude-3-haiku@20240307")

      # Claude 5 Models (future)
      refute Anthropic.legacy_model?("claude-5-sonnet")
    end
  end
end

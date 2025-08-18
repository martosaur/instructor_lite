defmodule InstructorLite.Adapters.GeminiTest do
  use ExUnit.Case, async: true

  import Mox

  alias InstructorLite.Adapters.Gemini
  alias InstructorLite.HTTPClient

  setup :verify_on_exit!

  describe "initial_prompt/2" do
    test "adds structured response parameters" do
      params = %{}

      assert Gemini.initial_prompt(params, json_schema: :json_schema, notes: "Explanation") == %{
               generationConfig: %{
                 responseMimeType: "application/json",
                 responseSchema: :json_schema
               },
               systemInstruction: %{
                 parts: [
                   %{
                     text: """
                     You're called by an Elixir application through the InstructorLite library. \
                     Your task is to understand what the application wants you to do and respond with JSON output that matches the schema. \
                     The output will be validated by the application against an Ecto schema and potentially some custom rules. \
                     You may be asked to adjust your response if it doesn't pass validation. \
                     Additional notes on the schema:
                     Explanation
                     """
                   }
                 ]
               }
             }
    end

    test "merges into users generation config" do
      params = %{generationConfig: %{seed: 42}}

      assert Gemini.initial_prompt(params, json_schema: :json_schema, notes: "Explanation") == %{
               generationConfig: %{
                 responseMimeType: "application/json",
                 responseSchema: :json_schema,
                 seed: 42
               },
               systemInstruction: %{
                 parts: [
                   %{
                     text: """
                     You're called by an Elixir application through the InstructorLite library. \
                     Your task is to understand what the application wants you to do and respond with JSON output that matches the schema. \
                     The output will be validated by the application against an Ecto schema and potentially some custom rules. \
                     You may be asked to adjust your response if it doesn't pass validation. \
                     Additional notes on the schema:
                     Explanation
                     """
                   }
                 ]
               }
             }
    end
  end

  describe "retry_prompt/5" do
    test "adds new content entries" do
      params = %{contents: []}

      assert Gemini.retry_prompt(params, %{foo: "bar"}, "list of errors", nil, []) == %{
               contents: [
                 %{parts: [%{text: "{\"foo\":\"bar\"}"}], role: "model"},
                 %{
                   parts: [
                     %{
                       text: """
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
        "candidates" => [
          %{
            "avgLogprobs" => -0.0510383415222168,
            "content" => %{
              "parts" => [
                %{
                  "text" => "{\"birth_date\": \"1732-02-22\", \"name\": \"George Washington\"}\n"
                }
              ],
              "role" => "model"
            },
            "finishReason" => "STOP",
            "safetyRatings" => [
              %{
                "category" => "HARM_CATEGORY_HATE_SPEECH",
                "probability" => "NEGLIGIBLE"
              },
              %{
                "category" => "HARM_CATEGORY_DANGEROUS_CONTENT",
                "probability" => "NEGLIGIBLE"
              },
              %{
                "category" => "HARM_CATEGORY_HARASSMENT",
                "probability" => "NEGLIGIBLE"
              },
              %{
                "category" => "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                "probability" => "NEGLIGIBLE"
              }
            ]
          }
        ],
        "usageMetadata" => %{
          "candidatesTokenCount" => 25,
          "promptTokenCount" => 34,
          "totalTokenCount" => 59
        }
      }

      assert {:ok, %{"birth_date" => "1732-02-22", "name" => "George Washington"}} =
               Gemini.parse_response(response, [])
    end

    test "invalid json" do
      response = %{
        "candidates" => [
          %{
            "avgLogprobs" => -0.0510383415222168,
            "content" => %{
              "parts" => [
                %{
                  "text" => "{{"
                }
              ],
              "role" => "model"
            },
            "finishReason" => "STOP",
            "safetyRatings" => [
              %{
                "category" => "HARM_CATEGORY_HATE_SPEECH",
                "probability" => "NEGLIGIBLE"
              },
              %{
                "category" => "HARM_CATEGORY_DANGEROUS_CONTENT",
                "probability" => "NEGLIGIBLE"
              },
              %{
                "category" => "HARM_CATEGORY_HARASSMENT",
                "probability" => "NEGLIGIBLE"
              },
              %{
                "category" => "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                "probability" => "NEGLIGIBLE"
              }
            ]
          }
        ],
        "usageMetadata" => %{
          "candidatesTokenCount" => 25,
          "promptTokenCount" => 34,
          "totalTokenCount" => 59
        }
      }

      assert {:error, _} = Gemini.parse_response(response, [])
    end

    test "returns refusal" do
      response = %{
        "promptFeedback" => %{
          "blockReason" => "OTHER"
        },
        "usageMetadata" => %{
          "candidatesTokenCount" => 25,
          "promptTokenCount" => 34,
          "totalTokenCount" => 59
        }
      }

      assert {:error, :refusal, %{"blockReason" => "OTHER"}} =
               Gemini.parse_response(response, [])
    end

    test "unexpected content" do
      response = "Internal Server Error"

      assert {:error, :unexpected_response, "Internal Server Error"} =
               Gemini.parse_response(response, [])
    end

    test "with reasoning summary" do
      response = %{
        "candidates" => [
          %{
            "avgLogprobs" => -0.0510383415222168,
            "content" => %{
              "parts" => [
                %{
                  "text" =>
                    "**Crafting the Response**\n\nOkay, so the user has a straightforward factual question. They want to know the name and birthdate of the first US president, and they expect a JSON object as the answer. That's no problem. I need to deliver on this.\n\nFirst, I need to make sure I understand the requirements fully. The schema dictates the properties: `birth_date` and `name`, both strings.  Easy enough.  Now, the user's question is essentially, \"What's the right JSON for the first US President?\"\n\nThe answer to the question is George Washington. That part's locked in.  Now, I need to get the `birth_date`. I remember that he was born on February 22, 1732.  \n\nPutting that all together, I can construct the following JSON object, which should satisfy the requirements:\n\n```json\n{\n  \"birth_date\": \"1732-02-22\",\n  \"name\": \"George Washington\"\n}\n```\n\nThis should be a perfectly correct and adequate response. I'm ready to send it.\n",
                  "thought" => true
                },
                %{
                  "text" => "{\"birth_date\": \"1732-02-22\", \"name\": \"George Washington\"}"
                }
              ],
              "role" => "model"
            },
            "finishReason" => "STOP",
            "safetyRatings" => [
              %{
                "category" => "HARM_CATEGORY_HATE_SPEECH",
                "probability" => "NEGLIGIBLE"
              },
              %{
                "category" => "HARM_CATEGORY_DANGEROUS_CONTENT",
                "probability" => "NEGLIGIBLE"
              },
              %{
                "category" => "HARM_CATEGORY_HARASSMENT",
                "probability" => "NEGLIGIBLE"
              },
              %{
                "category" => "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                "probability" => "NEGLIGIBLE"
              }
            ]
          }
        ],
        "usageMetadata" => %{
          "candidatesTokenCount" => 25,
          "promptTokenCount" => 34,
          "totalTokenCount" => 59
        }
      }

      assert {:ok, %{"birth_date" => "1732-02-22", "name" => "George Washington"}} =
               Gemini.parse_response(response, [])
    end
  end

  describe "send_request/2" do
    test "overridable options" do
      params = %{hello: "world"}

      opts = [
        adapter_context: [
          http_client: HTTPClient.Mock,
          api_key: "api-key",
          http_options: [foo: "bar", path_params: [model: "new-model"], path_params_style: :colon],
          url: "https://generativelanguage.googleapis.com/v2alpha/models/:model/foo",
          model: "gemini-1.5-flash"
        ]
      ]

      expect(HTTPClient.Mock, :post, fn url, options ->
        assert url == "https://generativelanguage.googleapis.com/v2alpha/models/:model/foo"

        assert options == [
                 foo: "bar",
                 path_params: [model: "new-model"],
                 path_params_style: :colon,
                 json: %{hello: "world"},
                 params: [key: "api-key"]
               ]

        {:ok, %{status: 200, body: "response"}}
      end)

      assert {:ok, "response"} = Gemini.send_request(params, opts)
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

      assert {:error, %{status: 400, body: "response"}} = Gemini.send_request(%{}, opts)
    end

    test "request error" do
      opts = [
        adapter_context: [
          http_client: HTTPClient.Mock,
          api_key: "api-key"
        ]
      ]

      expect(HTTPClient.Mock, :post, fn _url, _options -> {:error, :timeout} end)

      assert {:error, :timeout} = Gemini.send_request(%{}, opts)
    end
  end

  describe "find_output/2" do
    test "finds output in response" do
      response = %{
        "candidates" => [
          %{
            "avgLogprobs" => -1.1562569852685556e-5,
            "content" => %{
              "parts" => [%{"text" => "Washington\n"}],
              "role" => "model"
            },
            "finishReason" => "STOP",
            "safetyRatings" => [
              %{
                "category" => "HARM_CATEGORY_HATE_SPEECH",
                "probability" => "NEGLIGIBLE"
              },
              %{
                "category" => "HARM_CATEGORY_DANGEROUS_CONTENT",
                "probability" => "NEGLIGIBLE"
              },
              %{
                "category" => "HARM_CATEGORY_HARASSMENT",
                "probability" => "NEGLIGIBLE"
              },
              %{
                "category" => "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                "probability" => "NEGLIGIBLE"
              }
            ]
          }
        ],
        "modelVersion" => "gemini-1.5-flash-8b-001",
        "responseId" => "fn-iaJfqHqit698PxprM8AQ",
        "usageMetadata" => %{
          "candidatesTokenCount" => 2,
          "candidatesTokensDetails" => [%{"modality" => "TEXT", "tokenCount" => 2}],
          "promptTokenCount" => 16,
          "promptTokensDetails" => [%{"modality" => "TEXT", "tokenCount" => 16}],
          "totalTokenCount" => 18
        }
      }

      assert {:ok, "Washington\n"} =
               Gemini.find_output(response, [])
    end

    test "returns refusal" do
      response = %{
        "promptFeedback" => %{
          "blockReason" => "OTHER"
        },
        "usageMetadata" => %{
          "candidatesTokenCount" => 25,
          "promptTokenCount" => 34,
          "totalTokenCount" => 59
        }
      }

      assert {:error, :refusal, %{"blockReason" => "OTHER"}} =
               Gemini.find_output(response, [])
    end

    test "unexpected content" do
      response = "Internal Server Error"

      assert {:error, :unexpected_response, "Internal Server Error"} =
               Gemini.find_output(response, [])
    end

    test "with reasoning summary" do
      response = %{
        "candidates" => [
          %{
            "content" => %{
              "parts" => [
                %{
                  "text" =>
                    "**Process for Providing a Concise Response**\n\nOkay, the user needs the last name of the first U.S. president. Simple enough. First, I quickly parsed the constraints: they want *only* the surname, as a *single word*.  My long-term memory immediately pulled up the answer: George Washington. Easy. Now, let's extract the surname, which is obviously \"Washington\". Next, I have to ensure the response meets all the parameters. Is \"Washington\" a valid surname? Yes, of course. Is it just a single word? Absolutely.  Therefore, \"Washington\" is the correct response.\n",
                  "thought" => true
                },
                %{"text" => "Washington"}
              ],
              "role" => "model"
            },
            "finishReason" => "STOP",
            "index" => 0
          }
        ],
        "modelVersion" => "models/gemini-2.5-flash-preview-05-20",
        "responseId" => "93-iaOXAG477qtsP0tvIuAY",
        "usageMetadata" => %{
          "candidatesTokenCount" => 1,
          "promptTokenCount" => 17,
          "promptTokensDetails" => [%{"modality" => "TEXT", "tokenCount" => 17}],
          "thoughtsTokenCount" => 134,
          "totalTokenCount" => 152
        }
      }

      assert {:ok, "Washington"} =
               Gemini.find_output(response, [])
    end
  end
end

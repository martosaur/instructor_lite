defmodule InstructorTest do
  use ExUnit.Case, async: true

  alias Instructor.TestSchemas

  import Mox

  setup :verify_on_exit!

  describe "prepare_prompt/2" do
    test "schemaless ecto" do
      expect(MockAdapter, :prompt, fn params ->
        assert params == [
                 tool_choice: %{function: %{name: "Schema"}, type: "function"},
                 tools: [
                   %{
                     function: %{
                       "description" =>
                         "Correctly extracted `Schema` with all the required parameters with correct types",
                       "name" => "Schema",
                       "parameters" => %{
                         "properties" => %{
                           "birth_date" => %{"format" => "date", "type" => "string"},
                           "name" => %{"type" => "string"}
                         },
                         "required" => ["birth_date", "name"],
                         "title" => "root",
                         "type" => "object"
                       }
                     },
                     type: "function"
                   }
                 ],
                 model: "gpt-3.5-turbo",
                 response_model: %{name: :string, birth_date: :date},
                 messages: [%{role: "user", content: "Who was the first president of the USA"}]
               ]

        %{hello: "prompt"}
      end)

      Instructor.prepare_prompt(
        [
          model: "gpt-3.5-turbo",
          response_model: %{name: :string, birth_date: :date},
          messages: [
            %{role: "user", content: "Who was the first president of the USA"}
          ]
        ],
        %{adapter: MockAdapter}
      )
    end

    test "basic ecto model" do
      expect(MockAdapter, :prompt, fn params ->
        assert params == [
                 tool_choice: %{function: %{name: "Schema"}, type: "function"},
                 tools: [
                   %{
                     function: %{
                       "description" =>
                         "Correctly extracted `Schema` with all the required parameters with correct types",
                       "name" => "Schema",
                       "parameters" => %{
                         "description" => "",
                         "properties" => %{
                           "class" => %{
                             "enum" => ["spam", "not_spam"],
                             "title" => "class",
                             "type" => "string"
                           },
                           "score" => %{
                             "format" => "float",
                             "title" => "score",
                             "type" => "number"
                           }
                         },
                         "required" => ["class", "score"],
                         "title" => "Instructor.TestSchemas.SpamPrediction",
                         "type" => "object"
                       }
                     },
                     type: "function"
                   }
                 ],
                 model: "gpt-3.5-turbo",
                 response_model: TestSchemas.SpamPrediction,
                 messages: [%{role: "user", content: "Classify"}]
               ]

        %{hello: "prompt"}
      end)

      Instructor.prepare_prompt(
        [
          model: "gpt-3.5-turbo",
          response_model: TestSchemas.SpamPrediction,
          messages: [
            %{role: "user", content: "Classify"}
          ]
        ],
        %{adapter: MockAdapter}
      )
    end

    test "all ecto types" do
      expect(MockAdapter, :prompt, fn params ->
        assert params == [
                 tool_choice: %{function: %{name: "Schema"}, type: "function"},
                 tools: [
                   %{
                     function: %{
                       "description" =>
                         "Correctly extracted `Schema` with all the required parameters with correct types",
                       "name" => "Schema",
                       "parameters" => %{
                         "description" => "",
                         "properties" => %{
                           "array" => %{
                             "items" => %{"type" => "string"},
                             "title" => "array",
                             "type" => "array"
                           },
                           "binary_id" => %{"title" => "binary_id", "type" => "string"},
                           "boolean" => %{"title" => "boolean", "type" => "boolean"},
                           "date" => %{"format" => "date", "title" => "date", "type" => "string"},
                           "decimal" => %{
                             "format" => "float",
                             "title" => "decimal",
                             "type" => "number"
                           },
                           "float" => %{
                             "format" => "float",
                             "title" => "float",
                             "type" => "number"
                           },
                           "integer" => %{"title" => "integer", "type" => "integer"},
                           "map" => %{
                             "additionalProperties" => %{},
                             "title" => "map",
                             "type" => "object"
                           },
                           "map_two" => %{
                             "additionalProperties" => %{"type" => "string"},
                             "title" => "map_two",
                             "type" => "object"
                           },
                           "naive_datetime" => %{
                             "format" => "date-time",
                             "title" => "naive_datetime",
                             "type" => "string"
                           },
                           "naive_datetime_usec" => %{
                             "format" => "date-time",
                             "title" => "naive_datetime_usec",
                             "type" => "string"
                           },
                           "string" => %{"title" => "string", "type" => "string"},
                           "time" => %{
                             "pattern" => "^[0-9]{2}:?[0-9]{2}:?[0-9]{2}$",
                             "title" => "time",
                             "type" => "string"
                           },
                           "time_usec" => %{
                             "pattern" => "^[0-9]{2}:?[0-9]{2}:?[0-9]{2}.[0-9]{6}$",
                             "title" => "time_usec",
                             "type" => "string"
                           },
                           "utc_datetime" => %{
                             "format" => "date-time",
                             "title" => "utc_datetime",
                             "type" => "string"
                           },
                           "utc_datetime_usec" => %{
                             "format" => "date-time",
                             "title" => "utc_datetime_usec",
                             "type" => "string"
                           }
                         },
                         "required" => [
                           "array",
                           "binary_id",
                           "boolean",
                           "date",
                           "decimal",
                           "float",
                           "integer",
                           "map",
                           "map_two",
                           "naive_datetime",
                           "naive_datetime_usec",
                           "string",
                           "time",
                           "time_usec",
                           "utc_datetime",
                           "utc_datetime_usec"
                         ],
                         "title" => "Instructor.TestSchemas.AllEctoTypes",
                         "type" => "object"
                       }
                     },
                     type: "function"
                   }
                 ],
                 model: "gpt-3.5-turbo",
                 response_model: TestSchemas.AllEctoTypes,
                 messages: [
                   %{
                     role: "user",
                     content:
                       "What are the types of the following fields: binary_id, integer, float, boolean, string, array, map, map_two, decimal, date, time, time_usec, naive_datetime, naive_datetime_usec, utc_datetime, utc_datetime_usec?"
                   }
                 ]
               ]

        %{hello: "prompt"}
      end)

      Instructor.prepare_prompt(
        [
          model: "gpt-3.5-turbo",
          response_model: TestSchemas.AllEctoTypes,
          messages: [
            %{
              role: "user",
              content:
                "What are the types of the following fields: binary_id, integer, float, boolean, string, array, map, map_two, decimal, date, time, time_usec, naive_datetime, naive_datetime_usec, utc_datetime, utc_datetime_usec?"
            }
          ]
        ],
        %{adapter: MockAdapter}
      )
    end
  end

  describe "chat_completion/2" do
    test "prepares prompt and calls api" do
      MockAdapter
      |> expect(:prompt, fn _params -> %{hello: "prompt"} end)
      |> expect(:chat_completion, fn prompt, params, config ->
        assert prompt == %{hello: "prompt"}

        assert params == [
                 mode: :tools,
                 max_retries: 0,
                 model: "gpt-3.5-turbo",
                 response_model: %{name: :string, birth_date: :date},
                 messages: [%{role: "user", content: "Who was the first president of the USA"}]
               ]

        assert config == %{adapter: MockAdapter}

        {:ok, %{body: body}} = Instructor.HTTPClient.Stub.OpenAI.post(nil, nil)
        {:ok, body}
      end)

      assert Instructor.chat_completion(
               [
                 model: "gpt-3.5-turbo",
                 response_model: %{name: :string, birth_date: :date},
                 messages: [
                   %{role: "user", content: "Who was the first president of the USA"}
                 ]
               ],
               %{adapter: MockAdapter}
             )
    end

    test "retries" do
      MockAdapter
      |> expect(:prompt, fn params ->
        assert params == [
                 tool_choice: %{function: %{name: "Schema"}, type: "function"},
                 tools: [
                   %{
                     function: %{
                       "description" =>
                         "Correctly extracted `Schema` with all the required parameters with correct types",
                       "name" => "Schema",
                       "parameters" => %{
                         "properties" => %{"field" => %{"type" => "string"}},
                         "required" => ["field"],
                         "title" => "root",
                         "type" => "object"
                       }
                     },
                     type: "function"
                   }
                 ],
                 mode: :tools,
                 model: "gpt-3.5-turbo",
                 max_retries: 1,
                 response_model: %{field: :string},
                 messages: [%{role: "user", content: "What is the field?"}]
               ]
      end)
      |> expect(:chat_completion, fn _prompt, params, _config ->
        assert params == [
                 mode: :tools,
                 model: "gpt-3.5-turbo",
                 max_retries: 1,
                 response_model: %{field: :string},
                 messages: [%{role: "user", content: "What is the field?"}]
               ]

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "tool_calls" => [
                   %{
                     "id" => "call_DT9fBvVCHWGSf9IeFZnlarIY",
                     "function" => %{
                       "name" => "schema",
                       "arguments" => Jason.encode!(%{wrong_field: "foobar"})
                     }
                   }
                 ]
               }
             }
           ]
         }}
      end)
      |> expect(:prompt, fn params ->
        assert params == [
                 tool_choice: %{function: %{name: "Schema"}, type: "function"},
                 tools: [
                   %{
                     function: %{
                       "description" =>
                         "Correctly extracted `Schema` with all the required parameters with correct types",
                       "name" => "Schema",
                       "parameters" => %{
                         "properties" => %{"field" => %{"type" => "string"}},
                         "required" => ["field"],
                         "title" => "root",
                         "type" => "object"
                       }
                     },
                     type: "function"
                   }
                 ],
                 max_retries: 0,
                 mode: :tools,
                 model: "gpt-3.5-turbo",
                 response_model: %{field: :string},
                 messages: [
                   %{role: "user", content: "What is the field?"},
                   %{
                     content:
                       "{\"function\":{\"arguments\":\"{\\\"wrong_field\\\":\\\"foobar\\\"}\",\"name\":\"schema\"},\"id\":\"call_DT9fBvVCHWGSf9IeFZnlarIY\"}",
                     tool_calls: [
                       %{
                         "function" => %{
                           "arguments" => "{\"wrong_field\":\"foobar\"}",
                           "name" => "schema"
                         },
                         "id" => "call_DT9fBvVCHWGSf9IeFZnlarIY"
                       }
                     ]
                   },
                   %{
                     name: "schema",
                     role: "tool",
                     content: "{\"wrong_field\":\"foobar\"}",
                     tool_call_id: "call_DT9fBvVCHWGSf9IeFZnlarIY"
                   },
                   %{
                     role: "system",
                     content:
                       "The response did not pass validation. Please try again and fix the following validation errors:\n\n\nfield - can't be blank\n"
                   }
                 ]
               ]
      end)
      |> expect(:chat_completion, fn _prompt, params, _config ->
        assert params == [
                 max_retries: 0,
                 mode: :tools,
                 model: "gpt-3.5-turbo",
                 response_model: %{field: :string},
                 messages: [
                   %{content: "What is the field?", role: "user"},
                   %{
                     content:
                       "{\"function\":{\"arguments\":\"{\\\"wrong_field\\\":\\\"foobar\\\"}\",\"name\":\"schema\"},\"id\":\"call_DT9fBvVCHWGSf9IeFZnlarIY\"}",
                     tool_calls: [
                       %{
                         "function" => %{
                           "arguments" => "{\"wrong_field\":\"foobar\"}",
                           "name" => "schema"
                         },
                         "id" => "call_DT9fBvVCHWGSf9IeFZnlarIY"
                       }
                     ]
                   },
                   %{
                     name: "schema",
                     role: "tool",
                     content: "{\"wrong_field\":\"foobar\"}",
                     tool_call_id: "call_DT9fBvVCHWGSf9IeFZnlarIY"
                   },
                   %{
                     role: "system",
                     content:
                       "The response did not pass validation. Please try again and fix the following validation errors:\n\n\nfield - can't be blank\n"
                   }
                 ]
               ]

        {:ok,
         %{
           "choices" => [
             %{
               "message" => %{
                 "tool_calls" => [
                   %{
                     "id" => "call_DT9fBvVCHWGSf9IeFZnlarIY",
                     "function" => %{
                       "name" => "schema",
                       "arguments" => Jason.encode!(%{field: 123})
                     }
                   }
                 ]
               }
             }
           ]
         }}
      end)

      result =
        Instructor.chat_completion(
          [
            model: "gpt-3.5-turbo",
            max_retries: 1,
            response_model: %{field: :string},
            messages: [
              %{role: "user", content: "What is the field?"}
            ]
          ],
          %{adapter: MockAdapter}
        )

      assert {:error,
              %Ecto.Changeset{
                valid?: false,
                errors: [field: {"is invalid", [type: :string, validation: :cast]}]
              }} = result
    end
  end

  describe "consume_response" do
    test "tools" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "tool_calls" => [
                %{
                  "id" => "call_DT9fBvVCHWGSf9IeFZnlarIY",
                  "type" => "function",
                  "function" => %{
                    "arguments" =>
                      Jason.encode!(%{
                        name: "George Washington",
                        birth_date: ~D[1732-02-22]
                      }),
                    "name" => "schema"
                  }
                }
              ]
            }
          }
        ]
      }

      assert {:ok, %{name: "George Washington", birth_date: ~D[1732-02-22]}} =
               Instructor.consume_response(response,
                 mode: :tools,
                 response_model: %{name: :string, birth_date: :date}
               )
    end

    test "json" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" =>
                Jason.encode!(%{
                  name: "George Washington",
                  birth_date: ~D[1732-02-22]
                })
            }
          }
        ]
      }

      assert {:ok, %{name: "George Washington", birth_date: ~D[1732-02-22]}} =
               Instructor.consume_response(response,
                 mode: :json,
                 response_model: %{name: :string, birth_date: :date}
               )
    end

    test "md_json" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" =>
                Jason.encode!(%{
                  name: "George Washington",
                  birth_date: ~D[1732-02-22]
                })
            }
          }
        ]
      }

      assert {:ok, %{name: "George Washington", birth_date: ~D[1732-02-22]}} =
               Instructor.consume_response(response,
                 mode: :json,
                 response_model: %{name: :string, birth_date: :date}
               )
    end

    test "errors on invalid json" do
      assert {:error,
              "Invalid JSON returned from LLM: %Jason.DecodeError{position: 0, token: nil, data: \"I'm sorry Dave, I'm afraid I can't do this\"}"} =
               Instructor.consume_response(
                 %{
                   "choices" => [
                     %{
                       "message" => %{
                         "tool_calls" => [
                           %{
                             "function" => %{
                               "arguments" => "I'm sorry Dave, I'm afraid I can't do this"
                             }
                           }
                         ]
                       }
                     }
                   ]
                 },
                 response_model: %{name: :string, birth_date: :date}
               )
    end

    test "returns new params on failed cast" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "tool_calls" => [
                %{
                  "id" => "call_DT9fBvVCHWGSf9IeFZnlarIY",
                  "type" => "function",
                  "function" => %{
                    "arguments" =>
                      Jason.encode!(%{
                        name: 123,
                        birth_date: false
                      }),
                    "name" => "schema"
                  }
                }
              ]
            }
          }
        ]
      }

      assert {:error,
              %Ecto.Changeset{errors: [name: {"is invalid", _}, birth_date: {"is invalid", _}]},
              [
                response_model: %{name: :string, birth_date: :date},
                messages: [
                  %{
                    role: "assistant",
                    content:
                      "{\"function\":{\"arguments\":\"{\\\"name\\\":123,\\\"birth_date\\\":false}\",\"name\":\"schema\"},\"id\":\"call_DT9fBvVCHWGSf9IeFZnlarIY\",\"type\":\"function\"}",
                    tool_calls: [
                      %{
                        "function" => %{
                          "arguments" => "{\"name\":123,\"birth_date\":false}",
                          "name" => "schema"
                        },
                        "id" => "call_DT9fBvVCHWGSf9IeFZnlarIY",
                        "type" => "function"
                      }
                    ]
                  },
                  %{
                    name: "schema",
                    role: "tool",
                    content: "{\"name\":123,\"birth_date\":false}",
                    tool_call_id: "call_DT9fBvVCHWGSf9IeFZnlarIY"
                  },
                  %{
                    role: "system",
                    content:
                      "The response did not pass validation. Please try again and fix the following validation errors:\n\n\nname - is invalid\nbirth_date - is invalid\n"
                  }
                ]
              ]} =
               Instructor.consume_response(response,
                 response_model: %{name: :string, birth_date: :date},
                 messages: []
               )
    end
  end
end

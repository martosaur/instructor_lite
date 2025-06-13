defmodule InstructorLite.Integration.OpenAITest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias InstructorLite.TestSchemas
  alias InstructorLite.Adapters.{OpenAI, ChatCompletionsCompatible}

  describe "OpenAI adapter" do
    test "schemaless" do
      result =
        InstructorLite.instruct(
          %{
            model: "gpt-4o-mini",
            input: [
              %{role: "user", content: "Who was the first president of the USA?"}
            ]
          },
          response_model: %{name: :string, birth_date: :date},
          adapter: OpenAI,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ]
        )

      assert {:ok, %{name: name, birth_date: birth_date}} = result
      assert is_binary(name)
      assert %Date{} = birth_date
    end

    test "basic ecto schema" do
      result =
        InstructorLite.instruct(
          %{
            model: "gpt-4o-mini",
            input: [
              %{
                role: "user",
                content:
                  "Classify the following text: Hello, I am a Nigerian prince and I would like to give you $1,000,000."
              }
            ]
          },
          response_model: TestSchemas.SpamPrediction,
          adapter: OpenAI,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ]
        )

      assert {:ok, %{class: :spam, score: score}} = result
      assert is_float(score)
    end

    test "with embedded" do
      result =
        InstructorLite.instruct(
          %{
            model: "gpt-4o-mini",
            input: [
              %{
                role: "user",
                content: "Please fill in test data"
              }
            ]
          },
          response_model: TestSchemas.WithEmbedded,
          adapter: OpenAI,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ]
        )

      assert {:ok, %{embedded: %{name: name}}} = result
      assert is_binary(name)
    end

    test "all ecto types" do
      result =
        InstructorLite.instruct(
          %{
            model: "gpt-4o-mini",
            input: [
              %{
                role: "user",
                content: "Please fill test data"
              }
            ]
          },
          response_model: TestSchemas.AllEctoTypes,
          adapter: OpenAI,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ]
        )

      assert {:ok,
              %{
                binary_id: binary_id,
                integer: integer,
                float: float,
                boolean: boolean,
                string: string,
                array: array,
                # map: _map,
                # map_two: _map_two,
                decimal: decimal,
                date: date,
                time: time,
                time_usec: time_usec,
                naive_datetime: naive_datetime,
                naive_datetime_usec: naive_datetime_usec,
                utc_datetime: utc_datetime,
                utc_datetime_usec: utc_datetime_usec
              }} = result

      assert is_binary(binary_id)
      assert is_integer(integer)
      assert is_float(float)
      assert is_boolean(boolean)
      assert is_binary(string)
      assert is_list(array)
      # Doesn't work?
      # assert is_map(map)
      # assert is_map(map_two)
      assert %Decimal{} = decimal
      assert %Date{} = date
      assert %Time{} = time
      assert %Time{} = time_usec
      assert %NaiveDateTime{} = naive_datetime
      assert %NaiveDateTime{} = naive_datetime_usec
      assert %DateTime{} = utc_datetime
      assert %DateTime{} = utc_datetime_usec
    end

    test "with validate_changeset" do
      result =
        InstructorLite.instruct(
          %{
            model: "gpt-4o-mini",
            input: [
              %{
                role: "user",
                content: "Guess the result!"
              }
            ]
          },
          response_model: TestSchemas.CoinGuess,
          max_retries: 1,
          adapter: OpenAI,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ],
          extra: :tails
        )

      assert {:ok, %{guess: :tails}} = result
    end

    test "linked list" do
      result =
        InstructorLite.instruct(
          %{
            model: "gpt-4o-mini",
            input: [
              %{
                role: "user",
                content: "Make a linked list of 3 elements"
              }
            ],
            text: %{
              format: %{
                type: "json_schema",
                name: "linked_list",
                strict: false,
                schema: TestSchemas.LinkedList.json_schema()
              }
            }
          },
          response_model: TestSchemas.LinkedList,
          max_retries: 1,
          adapter: OpenAI,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ],
          extra: 3
        )

      assert {:ok, %{next: %{next: %{next: nil}}}} = result
    end

    test "reasoning model" do
      result =
        InstructorLite.instruct(
          %{
            model: "o4-mini",
            reasoning: %{effort: "high", summary: "auto"},
            input: [
              %{role: "user", content: "Who was the first president of the USA?"}
            ]
          },
          response_model: %{name: :string, birth_date: :date},
          adapter: OpenAI,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ]
        )

      assert {:ok, %{name: name, birth_date: birth_date}} = result
      assert is_binary(name)
      assert %Date{} = birth_date
    end
  end

  describe "ChatCompletionsCompatible adapter" do
    test "schemaless" do
      result =
        InstructorLite.instruct(
          %{
            model: "gpt-4o-mini",
            messages: [
              %{role: "user", content: "Who was the first president of the USA?"}
            ]
          },
          response_model: %{name: :string, birth_date: :date},
          adapter: ChatCompletionsCompatible,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ]
        )

      assert {:ok, %{name: name, birth_date: birth_date}} = result
      assert is_binary(name)
      assert %Date{} = birth_date
    end

    test "basic ecto schema" do
      result =
        InstructorLite.instruct(
          %{
            model: "gpt-4o-mini",
            messages: [
              %{
                role: "user",
                content:
                  "Classify the following text: Hello, I am a Nigerian prince and I would like to give you $1,000,000."
              }
            ]
          },
          response_model: TestSchemas.SpamPrediction,
          adapter: ChatCompletionsCompatible,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ]
        )

      assert {:ok, %{class: :spam, score: score}} = result
      assert is_float(score)
    end

    test "with embedded" do
      result =
        InstructorLite.instruct(
          %{
            model: "gpt-4o-mini",
            messages: [
              %{
                role: "user",
                content: "Please fill in test data"
              }
            ]
          },
          response_model: TestSchemas.WithEmbedded,
          adapter: ChatCompletionsCompatible,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ]
        )

      assert {:ok, %{embedded: %{name: name}}} = result
      assert is_binary(name)
    end

    test "all ecto types" do
      result =
        InstructorLite.instruct(
          %{
            model: "gpt-4o-mini",
            messages: [
              %{
                role: "user",
                content: "Please fill test data"
              }
            ]
          },
          response_model: TestSchemas.AllEctoTypes,
          adapter: ChatCompletionsCompatible,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ]
        )

      assert {:ok,
              %{
                binary_id: binary_id,
                integer: integer,
                float: float,
                boolean: boolean,
                string: string,
                array: array,
                # map: _map,
                # map_two: _map_two,
                decimal: decimal,
                date: date,
                time: time,
                time_usec: time_usec,
                naive_datetime: naive_datetime,
                naive_datetime_usec: naive_datetime_usec,
                utc_datetime: utc_datetime,
                utc_datetime_usec: utc_datetime_usec
              }} = result

      assert is_binary(binary_id)
      assert is_integer(integer)
      assert is_float(float)
      assert is_boolean(boolean)
      assert is_binary(string)
      assert is_list(array)
      # Doesn't work?
      # assert is_map(map)
      # assert is_map(map_two)
      assert %Decimal{} = decimal
      assert %Date{} = date
      assert %Time{} = time
      assert %Time{} = time_usec
      assert %NaiveDateTime{} = naive_datetime
      assert %NaiveDateTime{} = naive_datetime_usec
      assert %DateTime{} = utc_datetime
      assert %DateTime{} = utc_datetime_usec
    end

    test "with validate_changeset" do
      result =
        InstructorLite.instruct(
          %{
            model: "gpt-4o-mini",
            messages: [
              %{
                role: "user",
                content: "Guess the result!"
              }
            ]
          },
          response_model: TestSchemas.CoinGuess,
          max_retries: 1,
          adapter: ChatCompletionsCompatible,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ],
          extra: :tails
        )

      assert {:ok, %{guess: :tails}} = result
    end

    test "linked list" do
      result =
        InstructorLite.instruct(
          %{
            model: "gpt-4o-mini",
            messages: [
              %{
                role: "user",
                content: "Make a linked list of 3 elements"
              }
            ],
            response_format: %{
              type: "json_schema",
              json_schema: %{
                name: "schema",
                strict: false,
                schema: TestSchemas.LinkedList.json_schema()
              }
            }
          },
          response_model: TestSchemas.LinkedList,
          max_retries: 1,
          adapter: ChatCompletionsCompatible,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ],
          extra: 3
        )

      assert {:ok, %{next: %{next: %{next: nil}}}} = result
    end

    test "reasoning model" do
      result =
        InstructorLite.instruct(
          %{
            model: "o4-mini",
            reasoning_effort: "medium",
            messages: [
              %{role: "user", content: "Who was the first president of the USA?"}
            ]
          },
          response_model: %{name: :string, birth_date: :date},
          adapter: ChatCompletionsCompatible,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :openai_key)
          ]
        )

      assert {:ok, %{name: name, birth_date: birth_date}} = result
      assert is_binary(name)
      assert %Date{} = birth_date
    end
  end
end

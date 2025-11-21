defmodule InstructorLite.Integration.GeminiTest do
  use ExUnit.Case, async: false

  alias InstructorLite.TestSchemas
  alias InstructorLite.Adapters.Gemini
  alias InstructorLite.Adapters.ChatCompletionsCompatible

  @moduletag :integration

  describe "Gemini generateContent" do
    def to_gemini_schema(json_schema), do: Map.drop(json_schema, [:title, :additionalProperties])

    test "schemaless" do
      response_model = %{name: :string, birth_date: :date}

      json_schema =
        response_model |> InstructorLite.JSONSchema.from_ecto_schema() |> to_gemini_schema()

      result =
        InstructorLite.instruct(
          %{
            contents: [
              %{role: "user", parts: [%{text: "Who was the first president of the USA?"}]}
            ]
          },
          response_model: response_model,
          json_schema: json_schema,
          adapter: Gemini,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :gemini_key)
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
            contents: [
              %{
                role: "user",
                parts: [
                  %{
                    text:
                      "Classify the following text: Hello, I am a Nigerian prince and I would like to give you $1,000,000."
                  }
                ]
              }
            ]
          },
          response_model: TestSchemas.SpamPrediction,
          json_schema: TestSchemas.SpamPrediction.json_schema() |> to_gemini_schema(),
          adapter: Gemini,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :gemini_key)
          ]
        )

      assert {:ok, %{class: :spam, score: score}} = result
      assert is_float(score)
    end

    test "all ecto types" do
      result =
        InstructorLite.instruct(
          %{
            contents: [
              %{
                role: "user",
                parts: [%{text: "Please fill test data"}]
              }
            ]
          },
          response_model: TestSchemas.AllEctoTypes,
          json_schema: TestSchemas.AllEctoTypes.json_schema() |> to_gemini_schema(),
          adapter: Gemini,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :gemini_key)
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
            contents: [
              %{
                role: "user",
                parts: [%{text: "Guess the result!"}]
              }
            ]
          },
          response_model: TestSchemas.CoinGuess,
          json_schema: TestSchemas.CoinGuess.json_schema() |> to_gemini_schema(),
          max_retries: 1,
          adapter: Gemini,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :gemini_key),
            model: "gemini-2.5-flash"
          ],
          extra: :tails
        )

      assert {:ok, %{guess: :tails}} = result
    end

    test "reasoning model" do
      response_model = %{name: :string, birth_date: :date}

      json_schema =
        response_model |> InstructorLite.JSONSchema.from_ecto_schema() |> to_gemini_schema()

      result =
        InstructorLite.instruct(
          %{
            contents: [
              %{role: "user", parts: [%{text: "Who was the first president of the USA?"}]}
            ],
            generationConfig: %{
              thinkingConfig: %{
                includeThoughts: true,
                thinkingBudget: 1024
              }
            }
          },
          response_model: response_model,
          json_schema: json_schema,
          adapter: Gemini,
          adapter_context: [
            model: "gemini-2.5-pro",
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :gemini_key)
          ]
        )

      assert {:ok, %{name: name, birth_date: birth_date}} = result
      assert is_binary(name)
      assert %Date{} = birth_date
    end

    test "simple call" do
      result =
        InstructorLite.ask(
          %{
            contents: [
              %{
                role: "user",
                parts: [
                  %{
                    text:
                      "Who was the first president of the USA? Answer with surname, single word."
                  }
                ]
              }
            ]
          },
          adapter: Gemini,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :gemini_key)
          ]
        )

      assert {:ok, "Washington" <> _} = result
    end
  end

  describe "Gemini chat completions" do
    test "schemaless" do
      result =
        InstructorLite.instruct(
          %{
            model: "gemini-2.5-flash-lite",
            messages: [
              %{role: "user", content: "Who was the first president of the USA?"}
            ]
          },
          response_model: %{name: :string, birth_date: :date},
          max_retries: 1,
          adapter: ChatCompletionsCompatible,
          adapter_context: [
            url: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
            http_client: Req,
            api_key: Application.fetch_env!(:instructor_lite, :gemini_key)
          ]
        )

      assert {:ok, %{name: name, birth_date: birth_date}} = result
      assert is_binary(name)
      assert %Date{} = birth_date
    end
  end
end

defmodule Instructor.IntegrationTest do
  use ExUnit.Case, async: true

  alias Instructor.TestSchemas
  alias Instructor.Adapters.{Anthropic, OpenAI, Llamacpp}

  @moduletag :integration

  describe "OpenAI" do
    test "schemaless" do
      result =
        Instructor.chat_completion(
          %{
            model: "gpt-4o-mini",
            messages: [
              %{role: "user", content: "Who was the first president of the USA?"}
            ]
          },
          response_model: %{name: :string, birth_date: :date},
          adapter: OpenAI,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor, :openai_key)
          ]
        )

      assert {:ok, %{name: name, birth_date: birth_date}} = result
      assert is_binary(name)
      assert %Date{} = birth_date
    end

    test "basic ecto schema" do
      result =
        Instructor.chat_completion(
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
          adapter: OpenAI,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor, :openai_key)
          ]
        )

      assert {:ok, %{class: :spam, score: score}} = result
      assert is_float(score)
    end

    test "with embedded" do
      result =
        Instructor.chat_completion(
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
          adapter: OpenAI,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor, :openai_key)
          ]
        )

      assert {:ok, %{embedded: %{name: name}}} = result
      assert is_binary(name)
    end

    test "all ecto types" do
      result =
        Instructor.chat_completion(
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
          adapter: OpenAI,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor, :openai_key)
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
        Instructor.chat_completion(
          %{
            model: "gpt-4o-mini",
            messages: [
              %{
                role: "user",
                content: "Guess the result!"
              }
            ]
          },
          response_model: TestSchemas.SecondGuess,
          max_retries: 1,
          adapter: OpenAI,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor, :openai_key)
          ],
          extra: :tails
        )

      assert {:ok, %{guess: :tails}} = result
    end
  end

  describe "Anthropic" do
    test "schemaless" do
      schema = %{name: :string, birth_date: :date}

      result =
        Instructor.chat_completion(
          %{
            messages: [
              %{role: "user", content: "Who was the first president of the USA?"}
            ]
          },
          response_model: schema,
          adapter: Anthropic,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor, :anthropic_key)
          ]
        )

      assert {:ok, %{name: name, birth_date: birth_date}} = result
      assert is_binary(name)
      assert %Date{} = birth_date
    end

    test "basic ecto schema" do
      result =
        Instructor.chat_completion(
          %{
            messages: [
              %{
                role: "user",
                content:
                  "Classify the following text: Hello, I am a Nigerian prince and I would like to give you $1,000,000."
              }
            ]
          },
          response_model: TestSchemas.SpamPrediction,
          adapter: Anthropic,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor, :anthropic_key)
          ]
        )

      assert {:ok, %{class: :spam, score: score}} = result
      assert is_float(score)
    end

    test "with embedded" do
      result =
        Instructor.chat_completion(
          %{
            messages: [
              %{
                role: "user",
                content: "Please fill in test data"
              }
            ]
          },
          response_model: TestSchemas.WithEmbedded,
          adapter: Anthropic,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor, :anthropic_key)
          ]
        )

      assert {:ok, %{embedded: %{name: name}}} = result
      assert is_binary(name)
    end

    test "all ecto types" do
      result =
        Instructor.chat_completion(
          %{
            messages: [
              %{
                role: "user",
                content: "Please fill test data"
              }
            ]
          },
          response_model: TestSchemas.AllEctoTypes,
          adapter: Anthropic,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor, :anthropic_key)
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
        Instructor.chat_completion(
          %{
            messages: [
              %{
                role: "user",
                content: "Guess the result!"
              }
            ]
          },
          response_model: TestSchemas.SecondGuess,
          max_retries: 1,
          adapter: Anthropic,
          adapter_context: [
            http_client: Req,
            api_key: Application.fetch_env!(:instructor, :anthropic_key)
          ],
          extra: :tails
        )

      assert {:ok, %{guess: :tails}} = result
    end
  end

  describe "Llamacpp" do
    test "schemaless" do
      result =
        Instructor.chat_completion(
          %{prompt: "Who was the first president of the USA?"},
          response_model: %{name: :string, number_of_terms: :integer},
          adapter: Llamacpp,
          adapter_context: [
            http_client: Req,
            url: Application.fetch_env!(:instructor, :llamacpp_url)
          ]
        )

      assert {:ok, %{name: name, number_of_terms: n}} = result
      assert is_binary(name)
      assert is_integer(n)
    end

    test "basic ecto schema" do
      result =
        Instructor.chat_completion(
          %{
            prompt:
              "Classify the following text: Hello, I am a Nigerian prince and I would like to give you $1,000,000."
          },
          response_model: TestSchemas.SpamPrediction,
          adapter: Llamacpp,
          adapter_context: [
            http_client: Req,
            url: Application.fetch_env!(:instructor, :llamacpp_url)
          ]
        )

      assert {:ok, %{class: :spam, score: score}} = result
      assert is_float(score)
    end
  end
end

defmodule Instructor.IntegrationTest do
  use ExUnit.Case, async: true

  alias Instructor.TestSchemas

  @moduletag :integration

  describe "OpenAI" do
    test "schemaless" do
      result =
        Instructor.chat_completion(
          [
            model: "gpt-4o",
            response_model: %{name: :string, birth_date: :date},
            messages: [
              %{role: "user", content: "Who was the first president of the USA?"}
            ]
          ],
          http_client: Req,
          http_options: [receive_timeout: 60_000],
          api_key: Application.fetch_env!(:instructor, :openai_key)
        )

      assert {:ok, %{name: name, birth_date: birth_date}} = result
      assert is_binary(name)
      assert %Date{} = birth_date
    end

    test "basic ecto schema" do
      result =
        Instructor.chat_completion(
          [
            model: "gpt-4o",
            response_model: TestSchemas.SpamPrediction,
            messages: [
              %{
                role: "user",
                content:
                  "Classify the following text: Hello, I am a Nigerian prince and I would like to give you $1,000,000."
              }
            ]
          ],
          http_client: Req,
          http_options: [receive_timeout: 60_000],
          api_key: Application.fetch_env!(:instructor, :openai_key)
        )

      assert {:ok, %{class: :spam, score: score}} = result
      assert is_float(score)
    end

    test "all ecto types" do
      result =
        Instructor.chat_completion(
          [
            model: "gpt-4o",
            response_model: TestSchemas.AllEctoTypes,
            messages: [
              %{
                role: "user",
                content: "Please fill test data"
              }
            ]
          ],
          http_client: Req,
          http_options: [receive_timeout: 60_000],
          api_key: Application.fetch_env!(:instructor, :openai_key)
        )

      assert {:ok,
              %{
                binary_id: binary_id,
                integer: integer,
                float: float,
                boolean: boolean,
                string: string,
                array: array,
                map: _map,
                map_two: _map_two,
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
  end
end

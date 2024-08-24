defmodule InstructorTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  describe "prepare_prompt/2" do
    test "calls adapter callback with json_schema" do
      params = %{messages: [%{role: "user", content: "Who was the first president of the USA"}]}

      expect(MockAdapter, :prompt, fn json_schema, p ->
        assert %{name: _, schema: _} = json_schema
        assert params == p

        :ok
      end)

      assert :ok =
               Instructor.prepare_prompt(params,
                 model: "gpt-3.5-turbo",
                 response_model: %{name: :string, birth_date: :date},
                 adapter: MockAdapter
               )
    end
  end

  describe "consume_response/3" do
    test "response matches schema" do
      expect(MockAdapter, :from_response, fn response ->
        assert response == :foo

        params = %{
          name: "George Washington",
          birth_date: ~D[1732-02-22]
        }

        {:ok, params}
      end)

      assert {:ok, %{name: "George Washington", birth_date: ~D[1732-02-22]}} =
               Instructor.consume_response(:foo, %{},
                 adapter: MockAdapter,
                 response_model: %{name: :string, birth_date: :date}
               )
    end

    test "error from adapter" do
      expect(MockAdapter, :from_response, fn _response ->
        {:error, :foobar}
      end)

      assert {:error, :foobar} =
               Instructor.consume_response(:foo, %{},
                 adapter: MockAdapter,
                 response_model: %{name: :string, birth_date: :date}
               )
    end

    test "returns new params on changeset mismatch" do
      expect(MockAdapter, :from_response, fn _response ->
        {:ok, %{name: "George Washington", birth_date: 17_320_222}}
      end)

      assert {:error, %Ecto.Changeset{valid?: false}, new_params} =
               Instructor.consume_response(:foo, %{messages: []},
                 adapter: MockAdapter,
                 response_model: %{name: :string, birth_date: :date}
               )

      assert new_params == %{
               messages: [
                 %{
                   role: "assistant",
                   content: "{\"name\":\"George Washington\",\"birth_date\":17320222}"
                 },
                 %{
                   role: "system",
                   content: """
                   The response did not pass validation. Please try again and fix the following validation errors:


                   birth_date - is invalid
                   """
                 }
               ]
             }
    end
  end

  describe "chat_completion/2" do
    test "happy path" do
      params = %{
        messages: [%{role: "system", content: "prompt"}]
      }

      options = [
        model: "gpt-3.5-turbo",
        adapter: MockAdapter,
        response_model: %{name: :string, birth_date: :date}
      ]

      MockAdapter
      |> expect(:prompt, fn _json_schema, _params -> params end)
      |> expect(:chat_completion, fn p, opts ->
        assert params == p
        assert opts == [{:max_retries, 0} | options]

        {:ok, :response_body}
      end)
      |> expect(:from_response, fn :response_body ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: ~D[1732-02-22]
         }}
      end)

      assert {:ok, %{name: "George Washington", birth_date: ~D[1732-02-22]}} =
               Instructor.chat_completion(%{}, options)
    end

    test "retries on unmatched schema" do
      params = %{
        messages: [%{role: "system", content: "prompt"}]
      }

      options = [
        max_retries: 1,
        model: "gpt-3.5-turbo",
        adapter: MockAdapter,
        response_model: %{name: :string, birth_date: :date}
      ]

      MockAdapter
      |> expect(:prompt, fn _json_schema, _params -> params end)
      |> expect(:chat_completion, fn _p, _opts -> {:ok, :response_body} end)
      |> expect(:from_response, fn :response_body ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: 17_320_222
         }}
      end)
      |> expect(:chat_completion, fn _p, _opts -> {:ok, :response_body} end)
      |> expect(:from_response, fn :response_body ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: ~D[1732-02-22]
         }}
      end)

      assert {:ok, %{name: "George Washington", birth_date: ~D[1732-02-22]}} =
               Instructor.chat_completion(%{}, options)
    end

    test "out of retries" do
      params = %{
        messages: [%{role: "system", content: "prompt"}]
      }

      options = [
        max_retries: 1,
        model: "gpt-3.5-turbo",
        adapter: MockAdapter,
        response_model: %{name: :string, birth_date: :date}
      ]

      MockAdapter
      |> expect(:prompt, fn _json_schema, _params -> params end)
      |> expect(:chat_completion, fn _p, _opts -> {:ok, :response_body} end)
      |> expect(:from_response, fn :response_body ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: 17_320_222
         }}
      end)
      |> expect(:chat_completion, fn _p, _opts -> {:ok, :response_body} end)
      |> expect(:from_response, fn :response_body ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: 17_320_222
         }}
      end)

      assert {:error, %Ecto.Changeset{valid?: false}} = Instructor.chat_completion(%{}, options)
    end

    test "no retries on request error" do
      options = [
        max_retries: 1,
        model: "gpt-3.5-turbo",
        adapter: MockAdapter,
        response_model: %{name: :string, birth_date: :date}
      ]

      MockAdapter
      |> expect(:prompt, fn _json_schema, _params -> :params end)
      |> expect(:chat_completion, fn :params, _opts -> {:error, :timeout} end)

      assert {:error, :timeout} = Instructor.chat_completion(%{}, options)
    end

    test "no retries on consume error" do
      options = [
        max_retries: 1,
        model: "gpt-3.5-turbo",
        adapter: MockAdapter,
        response_model: %{name: :string, birth_date: :date}
      ]

      MockAdapter
      |> expect(:prompt, fn _json_schema, _params -> :params end)
      |> expect(:chat_completion, fn :params, _opts -> {:ok, :response_body} end)
      |> expect(:from_response, fn :response_body -> {:error, :unexpected_response} end)

      assert {:error, :unexpected_response} = Instructor.chat_completion(%{}, options)
    end
  end
end

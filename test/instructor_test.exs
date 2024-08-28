defmodule InstructorTest do
  use ExUnit.Case, async: true

  alias Instructor.TestSchemas

  import Mox

  setup :verify_on_exit!

  describe "prepare_prompt/2" do
    test "calls adapter callback with json_schema" do
      params = %{messages: [%{role: "user", content: "Who was the first president of the USA"}]}

      expect(MockAdapter, :initial_prompt, fn p, opts ->
        assert params == p
        assert opts[:json_schema]

        :ok
      end)

      assert :ok =
               Instructor.prepare_prompt(params,
                 model: "gpt-3.5-turbo",
                 response_model: %{name: :string, birth_date: :date},
                 adapter: MockAdapter
               )
    end

    test "json_schema is overridable in opts" do
      params = %{messages: [%{role: "user", content: "Who was the first president of the USA"}]}

      expect(MockAdapter, :initial_prompt, fn p, opts ->
        assert params == p
        assert opts[:json_schema] == :json_schema

        :ok
      end)

      assert :ok =
               Instructor.prepare_prompt(params,
                 model: "gpt-3.5-turbo",
                 response_model: %{name: :string, birth_date: :date},
                 adapter: MockAdapter,
                 json_schema: :json_schema
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
      params = %{messages: []}
      resp_params = %{name: "George Washington", birth_date: 17_320_222}

      MockAdapter
      |> expect(:from_response, fn _response -> {:ok, resp_params} end)
      |> expect(:retry_prompt, fn p, r, errors, response ->
        assert params == p
        assert resp_params == r
        assert errors == "birth_date - is invalid"
        assert response == :foo

        "new_params"
      end)

      assert {:error, %Ecto.Changeset{valid?: false}, "new_params"} =
               Instructor.consume_response(:foo, params,
                 adapter: MockAdapter,
                 response_model: %{name: :string, birth_date: :date}
               )
    end

    test "calls validate_changeset from opts if present" do
      expect(MockAdapter, :from_response, fn _ -> {:ok, %{"name" => "foo"}} end)

      validate = fn %Ecto.Changeset{} = cs, opts ->
        assert [adapter: MockAdapter, response_model: %{name: :string}, validate_changeset: _] =
                 opts

        cs
      end

      assert {:ok, %{name: "foo"}} =
               Instructor.consume_response(:foo, %{},
                 adapter: MockAdapter,
                 response_model: %{name: :string},
                 validate_changeset: validate
               )
    end

    test "calls validate_changeset/2 callback of exported" do
      defmodule ImpossibleGuess do
        use Ecto.Schema
        use Instructor.Instruction

        @primary_key false
        embedded_schema do
          field(:guess, :string)
        end

        @impl true
        def validate_changeset(cs, opts) do
          Ecto.Changeset.add_error(cs, :name, opts[:always_error])
        end
      end

      MockAdapter
      |> expect(:from_response, fn _ -> {:ok, %{"guess" => "Banana"}} end)
      |> expect(:retry_prompt, fn _, _, _, _ -> "new_params" end)

      assert {:error, %Ecto.Changeset{errors: [name: {"Wrong!", []}]}, "new_params"} =
               Instructor.consume_response(:foo, %{},
                 adapter: MockAdapter,
                 response_model: ImpossibleGuess,
                 always_error: "Wrong!"
               )
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
      |> expect(:initial_prompt, fn _json_schema, _params -> params end)
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
      |> expect(:initial_prompt, fn _json_schema, _params -> params end)
      |> expect(:chat_completion, fn _p, _opts -> {:ok, :response_body} end)
      |> expect(:from_response, fn :response_body ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: 17_320_222
         }}
      end)
      |> expect(:retry_prompt, fn _params, _resp_params, _errors, _response -> :new_prompt end)
      |> expect(:chat_completion, fn :new_prompt, _opts -> {:ok, :response_body} end)
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
      |> expect(:initial_prompt, fn _json_schema, _params -> params end)
      |> expect(:chat_completion, fn _p, _opts -> {:ok, :response_body} end)
      |> expect(:from_response, fn :response_body ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: 17_320_222
         }}
      end)
      |> expect(:retry_prompt, fn _params, _resp_params, _errors, _response -> :new_prompt end)
      |> expect(:chat_completion, fn :new_prompt, _opts -> {:ok, :response_body} end)
      |> expect(:from_response, fn :response_body ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: 17_320_222
         }}
      end)
      |> expect(:retry_prompt, fn :new_prompt, _resp_params, _errors, _response -> :foo end)

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
      |> expect(:initial_prompt, fn _json_schema, _params -> :params end)
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
      |> expect(:initial_prompt, fn _json_schema, _params -> :params end)
      |> expect(:chat_completion, fn :params, _opts -> {:ok, :response_body} end)
      |> expect(:from_response, fn :response_body -> {:error, :unexpected_response} end)

      assert {:error, :unexpected_response} = Instructor.chat_completion(%{}, options)
    end
  end

  describe "cast/2" do
    test "adhoc schema" do
      model = {%{}, %{name: :string}}
      params = %{"name" => "foo"}

      assert %Ecto.Changeset{changes: %{name: "foo"}} = Instructor.cast(model, params)
    end

    test "actual schema" do
      model = %TestSchemas.SpamPrediction{}
      params = %{"class" => "spam"}

      assert %Ecto.Changeset{changes: %{class: :spam}, valid?: true} =
               Instructor.cast(model, params)
    end

    test "embeds" do
      model = %TestSchemas.WithEmbedded{}
      params = %{"embedded" => %{"name" => "Foobar"}}

      assert %Ecto.Changeset{
               changes: %{embedded: %Ecto.Changeset{changes: %{name: "Foobar"}}},
               valid?: true
             } =
               Instructor.cast(model, params)
    end

    test "associations" do
      model = %TestSchemas.WithChildren{}
      params = %{"children" => [%{"name" => "Foo"}, %{"name" => "Bar"}]}

      assert %Ecto.Changeset{
               changes: %{
                 children: [
                   %Ecto.Changeset{changes: %{name: "Foo"}},
                   %Ecto.Changeset{changes: %{name: "Bar"}}
                 ]
               },
               valid?: true
             } =
               Instructor.cast(model, params)
    end

    test "recursive" do
      model = %TestSchemas.LinkedList{}
      params = %{"value" => 0, "next" => %{"value" => 1, "next" => %{"value" => 2}}}

      assert %Ecto.Changeset{
               changes: %{
                 value: 0,
                 next: %Ecto.Changeset{
                   changes: %{value: 1, next: %Ecto.Changeset{changes: %{value: 2}}}
                 }
               },
               valid?: true
             } =
               Instructor.cast(model, params)
    end
  end
end

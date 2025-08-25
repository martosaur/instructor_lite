defmodule InstructorLiteTest do
  use ExUnit.Case, async: true

  alias InstructorLite.TestSchemas

  import Mox

  setup :verify_on_exit!

  describe "prepare_prompt/2" do
    test "calls adapter callback with json_schema" do
      params = %{
        messages: [%{role: "user", content: "Who was the first president of the USA"}],
        model: "gpt-4o"
      }

      expect(MockAdapter, :initial_prompt, fn p, opts ->
        assert params == p
        assert opts[:json_schema]

        :ok
      end)

      assert :ok =
               InstructorLite.prepare_prompt(params,
                 response_model: %{name: :string, birth_date: :date},
                 adapter: MockAdapter
               )
    end

    test "json_schema is overridable in opts" do
      params = %{messages: [%{role: "user", content: "Who was the first president of the USA"}]}

      expect(MockAdapter, :initial_prompt, fn p, opts ->
        assert params == p
        assert opts[:json_schema] == %{json: :schema}

        :ok
      end)

      assert :ok =
               InstructorLite.prepare_prompt(params,
                 response_model: %{name: :string, birth_date: :date},
                 adapter: MockAdapter,
                 json_schema: %{json: :schema}
               )
    end
  end

  describe "consume_response/3" do
    test "response matches schema" do
      expect(MockAdapter, :parse_response, fn response, _opts ->
        assert response == :foo

        params = %{
          name: "George Washington",
          birth_date: ~D[1732-02-22]
        }

        {:ok, params}
      end)

      assert {:ok, %{name: "George Washington", birth_date: ~D[1732-02-22]}} =
               InstructorLite.consume_response(:foo, %{},
                 adapter: MockAdapter,
                 response_model: %{name: :string, birth_date: :date}
               )
    end

    test "error from adapter" do
      expect(MockAdapter, :parse_response, fn _response, _opts ->
        {:error, :foobar}
      end)

      assert {:error, :foobar} =
               InstructorLite.consume_response(:foo, %{},
                 adapter: MockAdapter,
                 response_model: %{name: :string, birth_date: :date}
               )
    end

    test "returns new params on changeset mismatch" do
      params = %{messages: []}
      resp_params = %{name: "George Washington", birth_date: 17_320_222}

      MockAdapter
      |> expect(:parse_response, fn _response, _opts -> {:ok, resp_params} end)
      |> expect(:retry_prompt, fn p, r, errors, response, _opts ->
        assert params == p
        assert resp_params == r
        assert errors == "birth_date - is invalid"
        assert response == :foo

        "new_params"
      end)

      assert {:error, %Ecto.Changeset{valid?: false}, "new_params"} =
               InstructorLite.consume_response(:foo, params,
                 adapter: MockAdapter,
                 response_model: %{name: :string, birth_date: :date}
               )
    end

    test "calls validate_changeset from opts if present" do
      expect(MockAdapter, :parse_response, fn _, _opts -> {:ok, %{"name" => "foo"}} end)

      validate = fn %Ecto.Changeset{} = cs, opts ->
        assert [
                 max_retries: 0,
                 adapter: MockAdapter,
                 response_model: %{name: :string},
                 validate_changeset: _
               ] =
                 opts

        cs
      end

      assert {:ok, %{name: "foo"}} =
               InstructorLite.consume_response(:foo, %{},
                 adapter: MockAdapter,
                 response_model: %{name: :string},
                 validate_changeset: validate
               )
    end

    test "calls validate_changeset/2 callback of exported" do
      defmodule ImpossibleGuess do
        use Ecto.Schema
        use InstructorLite.Instruction

        @primary_key false
        embedded_schema do
          field(:guess, :string)
        end

        @impl true
        def validate_changeset(cs, opts) do
          Ecto.Changeset.add_error(cs, :name, opts[:extra])
        end
      end

      MockAdapter
      |> expect(:parse_response, fn _, _opts -> {:ok, %{"guess" => "Banana"}} end)
      |> expect(:retry_prompt, fn _, _, _, _, _ -> "new_params" end)

      assert {:error, %Ecto.Changeset{errors: [name: {"Wrong!", []}]}, "new_params"} =
               InstructorLite.consume_response(:foo, %{},
                 adapter: MockAdapter,
                 response_model: ImpossibleGuess,
                 extra: "Wrong!"
               )
    end
  end

  describe "instruct/2" do
    test "happy path" do
      params = %{
        messages: [%{role: "system", content: "prompt"}]
      }

      options = [
        adapter: MockAdapter,
        response_model: %{name: :string, birth_date: :date}
      ]

      MockAdapter
      |> expect(:initial_prompt, fn _json_schema, _params -> params end)
      |> expect(:send_request, fn p, opts ->
        assert params == p
        assert opts == [{:max_retries, 0} | options]

        {:ok, :response_body}
      end)
      |> expect(:parse_response, fn :response_body, _opts ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: ~D[1732-02-22]
         }}
      end)

      assert {:ok, %{name: "George Washington", birth_date: ~D[1732-02-22]}} =
               InstructorLite.instruct(%{}, options)
    end

    test "retries on unmatched schema" do
      params = %{
        messages: [%{role: "system", content: "prompt"}]
      }

      options = [
        max_retries: 1,
        adapter: MockAdapter,
        response_model: %{name: :string, birth_date: :date}
      ]

      MockAdapter
      |> expect(:initial_prompt, fn _json_schema, _params -> params end)
      |> expect(:send_request, fn _p, _opts -> {:ok, :response_body} end)
      |> expect(:parse_response, fn :response_body, _opts ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: 17_320_222
         }}
      end)
      |> expect(:retry_prompt, fn _params, _resp_params, _errors, _response, _opts ->
        :new_prompt
      end)
      |> expect(:send_request, fn :new_prompt, _opts -> {:ok, :response_body} end)
      |> expect(:parse_response, fn :response_body, _opts ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: ~D[1732-02-22]
         }}
      end)

      assert {:ok, %{name: "George Washington", birth_date: ~D[1732-02-22]}} =
               InstructorLite.instruct(%{}, options)
    end

    test "out of retries" do
      params = %{
        messages: [%{role: "system", content: "prompt"}]
      }

      options = [
        max_retries: 1,
        adapter: MockAdapter,
        response_model: %{name: :string, birth_date: :date}
      ]

      MockAdapter
      |> expect(:initial_prompt, fn _json_schema, _params -> params end)
      |> expect(:send_request, fn _p, _opts -> {:ok, :response_body} end)
      |> expect(:parse_response, fn :response_body, _opts ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: 17_320_222
         }}
      end)
      |> expect(:retry_prompt, fn _params, _resp_params, _errors, _response, _opts ->
        :new_prompt
      end)
      |> expect(:send_request, fn :new_prompt, _opts -> {:ok, :response_body} end)
      |> expect(:parse_response, fn :response_body, _opts ->
        {:ok,
         %{
           name: "George Washington",
           birth_date: 17_320_222
         }}
      end)
      |> expect(:retry_prompt, fn :new_prompt, _resp_params, _errors, _response, _opts -> :foo end)

      assert {:error, %Ecto.Changeset{valid?: false}} = InstructorLite.instruct(%{}, options)
    end

    test "no retries on request error" do
      options = [
        max_retries: 1,
        adapter: MockAdapter,
        response_model: %{name: :string, birth_date: :date}
      ]

      MockAdapter
      |> expect(:initial_prompt, fn _json_schema, _params -> :params end)
      |> expect(:send_request, fn :params, _opts -> {:error, :timeout} end)

      assert {:error, :timeout} = InstructorLite.instruct(%{}, options)
    end

    test "no retries on consume error" do
      options = [
        max_retries: 1,
        adapter: MockAdapter,
        response_model: %{name: :string, birth_date: :date}
      ]

      MockAdapter
      |> expect(:initial_prompt, fn _json_schema, _params -> :params end)
      |> expect(:send_request, fn :params, _opts -> {:ok, :response_body} end)
      |> expect(:parse_response, fn :response_body, _opts -> {:error, :unexpected_response} end)

      assert {:error, :unexpected_response} = InstructorLite.instruct(%{}, options)
    end
  end

  describe "cast/2" do
    test "adhoc schema" do
      model = {%{}, %{name: :string, age: :integer}}
      params = %{"name" => "foo"}

      assert %Ecto.Changeset{changes: %{name: "foo"}, valid?: true} =
               InstructorLite.cast(model, params)
    end

    test "actual schema" do
      model = %TestSchemas.SpamPrediction{}
      params = %{"class" => "spam"}

      assert %Ecto.Changeset{changes: %{class: :spam}, valid?: true} =
               InstructorLite.cast(model, params)
    end

    test "embeds" do
      model = %TestSchemas.WithEmbedded{}
      params = %{"embedded" => %{"name" => "Foobar"}}

      assert %Ecto.Changeset{
               changes: %{embedded: %Ecto.Changeset{changes: %{name: "Foobar"}}},
               valid?: true
             } =
               InstructorLite.cast(model, params)
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
               InstructorLite.cast(model, params)
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
               InstructorLite.cast(model, params)
    end
  end

  describe "ask/2" do
    test "does not alter prompt in any way" do
      params = %{
        messages: [%{role: "system", content: "prompt"}]
      }

      options = [
        adapter: MockAdapter
      ]

      MockAdapter
      |> expect(:send_request, fn p, opts ->
        assert p == params
        assert opts == options

        {:ok, :response_body}
      end)
      |> expect(:find_output, fn :response_body, _opts ->
        {:ok, "George Washington"}
      end)

      assert {:ok, "George Washington"} = InstructorLite.ask(params, options)
    end

    test "no retries on request error" do
      options = [adapter: MockAdapter]

      expect(MockAdapter, :send_request, fn _params, _opts -> {:error, :timeout} end)

      assert {:error, :timeout} = InstructorLite.ask(%{}, options)
    end

    test "tolerant to redundant options but doesn't pass them downstream" do
      params = %{
        messages: [%{role: "system", content: "prompt"}]
      }

      options = [
        response_model: :foo,
        adapter: MockAdapter
      ]

      MockAdapter
      |> expect(:send_request, fn _p, opts ->
        assert opts == [adapter: MockAdapter]

        {:ok, :response_body}
      end)
      |> expect(:find_output, fn :response_body, opts ->
        assert opts == [adapter: MockAdapter]

        {:ok, "George Washington"}
      end)

      assert {:ok, "George Washington"} = InstructorLite.ask(params, options)
    end

    test "raises if adapter doesn't implement find_output/2" do
      assert_raise(
        RuntimeError,
        "Can't use InstructorLite.ask/2 because IncompleteAdapter.find_output/2 is not implemented",
        fn ->
          InstructorLite.ask(%{}, adapter: IncompleteAdapter)
        end
      )
    end
  end

  test "pre-1.1.0 adapters don't throw warnings" do
    refute ExUnit.CaptureIO.capture_io(:stderr, fn ->
             Code.compile_file("test/support/incomplete_adapter.ex")
           end) =~ "required by behaviour InstructorLite.Adapter is not implemented"
  end
end

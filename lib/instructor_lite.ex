defmodule InstructorLite do
  alias InstructorLite.JSONSchema
  alias InstructorLite.Adapters.OpenAI
  alias InstructorLite.Adapter

  @options_schema NimbleOptions.new!(
                    response_model: [
                      type: {:or, [:atom, :map]},
                      required: true,
                      doc:
                        "A module implementing `InstructorLite.Instruction` behaviour, Ecto schema or [schemaless Ecto definition](https://hexdocs.pm/ecto/Ecto.Changeset.html#module-schemaless-changesets)",
                      type_spec: quote(do: atom() | Ecto.Changeset.types())
                    ],
                    adapter: [
                      type: :atom,
                      default: OpenAI,
                      doc: "A module implementing `InstructorLite.Adapter` behaviour."
                    ],
                    max_retries: [
                      type: :non_neg_integer,
                      default: 0,
                      doc: "How many additional attempts to make if changeset validation fails."
                    ],
                    validate_changeset: [
                      type: {:fun, 2},
                      doc:
                        "Override function to be called instead of `response_model.validate_changeset/2` callback",
                      type_spec: quote(do: (Ecto.Changeset.t(), opts() -> Ecto.Changeset.t()))
                    ],
                    notes: [
                      type: :string,
                      doc: "Additional notes about the schema that might be used by an adapter",
                      type_spec: quote(do: String.t())
                    ],
                    json_schema: [
                      type: :map,
                      doc:
                        "JSON schema to use instead of calling response_model.json_schema/0 callback or generating it at runtime using `InstructorLite.JSONSchema` module"
                    ],
                    adapter_context: [
                      type: :any,
                      doc: "Options used by adapter callbacks. See adapter docs for schema."
                    ],
                    extra: [
                      type: :any,
                      doc:
                        "Any arbitrary term for ad-hoc usage. For example, in `c:InstructorLite.Instruction.validate_changeset/2` callback"
                    ]
                  )

  @moduledoc """
  Main building blocks of InstructorLite Lite

  ## Key Concepts

  Structured prompting can be quite different depending on the LLM and InstructorLite Lite does only the bare minimum to abstract this complexity. This means the usage can be quite different depending on the adapter you're using, so make sure to consult adapter documentation to learn the details.

  There are two key arguments used throughout this module. Understanding what they are will make your life a lot easier.

  * `params` - is an adapter-specific map, that contain values eventually sent to the LLM. More simply, this is the body that will be posted to the API endpoint. You prompt, model name, optional parameters like temperature all likely belong here.
  * `opts` - is a list of options that shape behavior of InstructorLite itself. Options may include things like which schema to cast response to, http client to use, api key, optional headers, http timeout, etc.

  ## Shared options

  Most functions in this module accept a list of options.
  #{NimbleOptions.docs(@options_schema)}
  """

  @typedoc """
  Options passed to instructor functions.
  """
  @type opts :: [unquote(NimbleOptions.option_typespec(@options_schema))]

  @doc """
  Perform instruction session from start to finish.

  This function glues together all other functions and adds retries on top.

  ## Examples

  ### Basic Example

  <!-- tabs-open -->

  ### OpenAI

  ```
  iex> InstructorLite.instruct(%{
      messages: [
        %{role: "user", content: "John Doe is fourty two years old"}
      ]
    },
    response_model: %{name: :string, age: :integer},
    adapter: InstructorLite.Adapters.OpenAI,
    adapter_context: [api_key: Application.fetch_env!(:instructor_lite, :openai_key)]
  )
  {:ok, %{name: "John Doe", age: 42}}
  ```

  ### Anthropic

  ```
  iex> InstructorLite.instruct(%{
      messages: [
        %{role: "user", content: "John Doe is fourty two years old"}
      ]
    },
    response_model: %{name: :string, age: :integer},
    adapter: InstructorLite.Adapters.Anthropic,
    adapter_context: [api_key: Application.fetch_env!(:instructor_lite, :anthropic_key)]
  )
  {:ok, %{name: "John Doe", age: 42}}
  ```

  ### Llamacpp

  ```
  iex> InstructorLite.instruct(%{
      prompt: "John Doe is fourty two years old"
    },
    response_model: %{name: :string, age: :integer},
    adapter: InstructorLite.Adapters.Llamacpp,
    adapter_context: [url: Application.fetch_env!(:instructor_lite, :llamacpp_url)]
  )
  {:ok, %{name: "John Doe", age: 42}}
  ```

  <!-- tabs-close -->

  ### Using `max_retries`

  ```
  defmodule Rhymes do
    use Ecto.Schema
    use InstructorLite.Instruction
    
    @primary_key false
    embedded_schema do
      field(:word, :string)
      field(:rhymes, {:array, :string})
    end
    
    @impl true
    def validate_changeset(changeset, _opts) do
      Ecto.Changeset.validate_length(changeset, :rhymes, is: 3)
    end
  end

  InstructorLite.instruct(%{
      messages: [
        %{role: "user", content: "Take the last word from the following line and add some rhymes to it\nEven though you broke my heart"}
      ]
    },
    response_model: Rhymes,
    max_retries: 1,
    adapter_context: [api_key: Application.fetch_env!(:instructor_lite, :openai_key)]
  )
  {:ok, %Rhymes{word: "heart", rhymes: ["part", "start", "dart"]}}
  ```
  """
  @spec instruct(Adapter.params(), opts()) ::
          {:ok, Ecto.Schema.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, any()}
          | {:error, atom(), any()}
  def instruct(params, opts) do
    opts = NimbleOptions.validate!(opts, @options_schema)
    params = prepare_prompt(params, opts)
    do_instruct(params, opts)
  end

  defp do_instruct(params, opts) do
    with {:ok, response} <- opts[:adapter].send_request(params, opts) do
      case consume_response(response, params, opts) do
        {:error, %Ecto.Changeset{} = cs, new_params} ->
          if opts[:max_retries] > 0 do
            do_instruct(new_params, Keyword.update!(opts, :max_retries, &(&1 - 1)))
          else
            {:error, cs}
          end

        {:ok, result} ->
          {:ok, result}

        error ->
          error
      end
    end
  end

  @doc false
  @spec cast(
          Ecto.Schema.t() | {Ecto.Changeset.data(), Ecto.Changeset.types()},
          Adapter.parsed_response()
        ) ::
          Ecto.Changeset.t()
  def cast({data, types}, params) do
    fields = Map.keys(types)

    {data, types}
    |> Ecto.Changeset.cast(params, fields)
    |> Ecto.Changeset.validate_required(fields)
  end

  def cast(%response_model{} = data, params) do
    fields = response_model.__schema__(:fields) |> MapSet.new()
    embedded_fields = response_model.__schema__(:embeds) |> MapSet.new()
    associated_fields = response_model.__schema__(:associations) |> MapSet.new()

    fields =
      fields
      |> MapSet.difference(embedded_fields)
      |> MapSet.difference(associated_fields)

    data
    |> Ecto.Changeset.cast(params, MapSet.to_list(fields))
    |> then(fn cs ->
      Enum.reduce(embedded_fields, cs, fn field, cs ->
        Ecto.Changeset.cast_embed(cs, field, with: &cast/2)
      end)
    end)
    |> then(fn cs ->
      Enum.reduce(associated_fields, cs, fn field, cs ->
        Ecto.Changeset.cast_assoc(cs, field, with: &cast/2)
      end)
    end)
  end

  @doc """
  Prepare prompt that can be later sent to LLM

  The prompt is added to `params`, so you need to cooperate with the adapter to know what you can provide there.

  The function will call `c:InstructorLite.Instruction.notes/0` and `c:InstructorLite.Instruction.json_schema/0` callbacks for `response_model`. Both can be overriden with corresponding options in `opts`.
  """
  @spec prepare_prompt(Adapter.params(), opts()) :: Adapter.params()
  def prepare_prompt(params, opts) do
    opts =
      opts
      |> NimbleOptions.validate!(@options_schema)
      |> Keyword.put_new_lazy(:notes, fn ->
        model = opts[:response_model]
        if is_atom(model) and function_exported?(model, :notes, 0), do: model.notes()
      end)
      |> Keyword.put_new_lazy(:json_schema, fn ->
        model = opts[:response_model]

        if is_atom(model) and function_exported?(model, :json_schema, 0) do
          model.json_schema()
        else
          JSONSchema.from_ecto_schema(model)
        end
      end)

    opts[:adapter].initial_prompt(params, opts)
  end

  @doc """
  Triage raw LLM response

  Attempts to cast raw response from `c:InstructorLite.Adapter.send_request/2` and either returns an object or an invalid changeset with new prompt that can be used for a retry.

  This function will call `c:InstructorLite.Instruction.validate_changeset/2` callback, unless `validate_changeset` option is overridden in `opts`.
  """
  @spec consume_response(Adapter.response(), Adapter.params(), opts()) ::
          {:ok, Ecto.Schema.t()}
          | {:error, Ecto.Changeset.t(), Adapter.params()}
          | {:error, any()}
          | {:error, reason :: atom(), any()}
  def consume_response(response, params, opts) do
    opts = NimbleOptions.validate!(opts, @options_schema)
    response_model = opts[:response_model]
    adapter = opts[:adapter]

    blank =
      if is_atom(response_model) do
        response_model.__struct__()
      else
        {%{}, response_model}
      end

    with {:ok, resp_params} <- adapter.parse_response(response, opts) do
      blank
      |> cast(resp_params)
      |> call_validate(response_model, opts)
      |> case do
        %Ecto.Changeset{valid?: true} = cs ->
          {:ok, Ecto.Changeset.apply_changes(cs)}

        changeset ->
          errors = InstructorLite.ErrorFormatter.format_errors(changeset)
          new_params = adapter.retry_prompt(params, resp_params, errors, response, opts)

          {:error, changeset, new_params}
      end
    end
  end

  defp call_validate(changeset, response_model, opts) do
    callback = opts[:validate_changeset]

    cond do
      is_function(callback, 2) ->
        callback.(changeset, opts)

      not is_atom(response_model) ->
        changeset

      function_exported?(response_model, :validate_changeset, 2) ->
        response_model.validate_changeset(changeset, opts)

      true ->
        changeset
    end
  end
end

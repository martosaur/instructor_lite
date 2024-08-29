defmodule Instructor do
  alias Instructor.JSONSchema
  alias Instructor.Adapters.OpenAI

  @options_schema NimbleOptions.new!(
                    response_model: [
                      type: {:or, [:atom, :map]},
                      required: true,
                      doc:
                        "A module implementing `Instructor.Instuction`, Ecto schema or Ecto schemaless type map"
                    ],
                    adapter: [
                      type: :atom,
                      default: OpenAI,
                      doc: "A module implementing `Instructor.Adapter` behaviour"
                    ],
                    max_retries: [
                      type: :non_neg_integer,
                      default: 0,
                      doc:
                        "How many additional attempts LLM can take if changeset validation fails"
                    ],
                    validate_changeset: [
                      type: {:fun, 2},
                      doc:
                        "Override function to be called instead of response_model.validate_changeset/2 callback"
                    ],
                    notes: [
                      type: :string,
                      doc: "Additional notes about the schema that might be used by an adapter"
                    ],
                    json_schema: [
                      type: :map,
                      doc:
                        "JSON schema to use instead of calling response_model.json_schema/0 callback or generating it at runtime using `Instructor.JSONSchema` module"
                    ],
                    adapter_context: [
                      type: :any,
                      doc: "Options used by adapter callbacks. See adapter docs for schema."
                    ],
                    extra: [
                      type: :any,
                      doc:
                        "Any arbitrary term for ad-hoc usage. For example, in `Instruction.validate_changeset/2 callback"
                    ]
                  )

  def chat_completion(params, opts) do
    opts = NimbleOptions.validate!(opts, @options_schema)
    params = prepare_prompt(params, opts)
    do_chat_completion(params, opts)
  end

  defp do_chat_completion(params, opts) do
    with {:ok, response} <- opts[:adapter].send_request(params, opts) do
      case consume_response(response, params, opts) do
        {:error, %Ecto.Changeset{} = cs, new_params} ->
          if opts[:max_retries] > 0 do
            do_chat_completion(new_params, Keyword.update!(opts, :max_retries, &(&1 - 1)))
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
          errors = Instructor.ErrorFormatter.format_errors(changeset)
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

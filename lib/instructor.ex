defmodule Instructor do
  require Logger

  alias Instructor.JSONSchema
  alias Instructor.Adapters.OpenAI

  @external_resource "README.md"

  [_, readme_docs, _] =
    "README.md"
    |> File.read!()
    |> String.split("<!-- Docs -->")

  @moduledoc """
  #{readme_docs}
  """

  defguardp is_ecto_schema(mod) when is_atom(mod)

  @doc """
  Create a new chat completion for the provided messages and parameters.

  The parameters are passed directly to the LLM adapter.
  By default they shadow the OpenAI API parameters.
  For more information on the parameters, see the [OpenAI API docs](https://platform.openai.com/docs/api-reference/chat-completions/create).

  Additionally, the following parameters are supported:

    * `:adapter` - The adapter to use for chat completion. (defaults to the configured adapter, which defaults to `Instructor.Adapters.OpenAI`)
    * `:response_model` - The Ecto schema to validate the response against, or a valid map of Ecto types (see [Schemaless Ecto](https://hexdocs.pm/ecto/Ecto.Changeset.html#module-schemaless-changesets)).
    * `:validation_context` - The validation context to use when validating the response. (defaults to `%{}`)
    * `:mode` - The mode to use when parsing the response, :tools, :json, :md_json (defaults to `:tools`), generally speaking you don't need to change this unless you are not using OpenAI.
    * `:max_retries` - The maximum number of times to retry the LLM call if it fails, or does not pass validations.
                       (defaults to `0`)

  ## Examples

      iex> Instructor.chat_completion(
      ...>   model: "gpt-3.5-turbo",
      ...>   response_model: Instructor.Demos.SpamPrediction,
      ...>   messages: [
      ...>     %{
      ...>       role: "user",
      ...>       content: "Classify the following text: Hello, I am a Nigerian prince and I would like to give you $1,000,000."
      ...>     }
      ...>   ])
      {:ok,
          %Instructor.Demos.SpamPrediction{
              class: :spam
              score: 0.999
          }}


  If there's a validation error, it will return an error tuple with the change set describing the errors.

      iex> Instructor.chat_completion(
      ...>   model: "gpt-3.5-turbo",
      ...>   response_model: Instructor.Demos.SpamPrediction,
      ...>   messages: [
      ...>     %{
      ...>       role: "user",
      ...>       content: "Classify the following text: Hello, I am a Nigerian prince and I would like to give you $1,000,000."
      ...>     }
      ...>   ])
      {:error,
          %Ecto.Changeset{
              changes: %{
                  class: "foobar",
                  score: -10.999
              },
              errors: [
                  class: {"is invalid", [type: :string, validation: :cast]}
              ],
              valid?: false
          }}
  """
  def chat_completion(params, opts) do
    opts = Keyword.put_new(opts, :max_retries, 0)

    params = prepare_prompt(params, opts)

    do_chat_completion(params, opts)
  end

  defp do_chat_completion(params, opts) do
    with {:ok, response} <- opts[:adapter].chat_completion(params, opts) do
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

  @doc """
  Casts all the parameters in the params map to the types defined in the types map.
  This works both with Ecto Schemas and maps of Ecto types (see [Schemaless Ecto](https://hexdocs.pm/ecto/Ecto.Changeset.html#module-schemaless-changesets)).

  ## Examples

  When using a full Ecto Schema

      iex> Instructor.cast_all(%{
      ...>   data: %Instructor.Demos.SpamPrediction{},
      ...>   types: %{
      ...>     class: :string,
      ...>     score: :float
      ...>   }
      ...> }, %{
      ...>   class: "spam",
      ...>   score: 0.999
      ...> })
      %Ecto.Changeset{
        action: nil,
        changes: %{
          class: "spam",
          score: 0.999
        },
        errors: [],
        data: %Instructor.Demos.SpamPrediction{
          class: :spam,
          score: 0.999
        },
        valid?: true
      }

  When using a map of Ecto types

      iex> Instructor.cast_all(%Instructor.Demo.SpamPrediction{}, %{
      ...>   class: "spam",
      ...>   score: 0.999
      ...> })
      %Ecto.Changeset{
        action: nil,
        changes: %{
          class: "spam",
          score: 0.999
        },
        errors: [],
        data: %{
          class: :spam,
          score: 0.999
        },
        valid?: true
      }

  and when using raw Ecto types,

      iex> Instructor.cast_all({%{},%{name: :string}, %{
      ...>   name: "George Washington"
      ...> })
      %Ecto.Changeset{
        action: nil,
        changes: %{
          name: "George Washington",
        },
        errors: [],
        data: %{
          name: "George Washington",
        },
        valid?: true
      }

  """
  def cast_all({data, types}, params) do
    fields = Map.keys(types)

    {data, types}
    |> Ecto.Changeset.cast(params, fields)
    |> Ecto.Changeset.validate_required(fields)
  end

  def cast_all(schema, params) do
    response_model = schema.__struct__
    fields = response_model.__schema__(:fields) |> MapSet.new()
    embedded_fields = response_model.__schema__(:embeds) |> MapSet.new()
    associated_fields = response_model.__schema__(:associations) |> MapSet.new()

    fields =
      fields
      |> MapSet.difference(embedded_fields)
      |> MapSet.difference(associated_fields)

    changeset =
      schema
      |> Ecto.Changeset.cast(params, fields |> MapSet.to_list())

    changeset =
      for field <- embedded_fields, reduce: changeset do
        changeset ->
          changeset
          |> Ecto.Changeset.cast_embed(field, with: &cast_all/2)
      end

    changeset =
      for field <- associated_fields, reduce: changeset do
        changeset ->
          changeset
          |> Ecto.Changeset.cast_assoc(field, with: &cast_all/2)
      end

    changeset
  end

  def prepare_prompt(params, opts) do
    opts = Keyword.put_new(opts, :adapter, OpenAI)
    json_schema = JSONSchema.from_ecto_schema(opts[:response_model])

    opts[:adapter].initial_prompt(json_schema, params)
  end

  def consume_response(response, params, opts) do
    response_model = opts[:response_model]
    adapter = opts[:adapter]

    model =
      if is_ecto_schema(response_model) do
        response_model.__struct__()
      else
        {%{}, response_model}
      end

    with {:ok, resp_params} <- adapter.from_response(response) do
      case cast_all(model, resp_params) do
        %Ecto.Changeset{valid?: true} = cs ->
          {:ok, Ecto.Changeset.apply_changes(cs)}

        changeset ->
          errors = Instructor.ErrorFormatter.format_errors(changeset)
          new_params = adapter.retry_prompt(params, resp_params, errors)

          {:error, changeset, new_params}
      end
    end
  end

  defp call_validate(response_model, changeset, context) do
    cond do
      not is_ecto_schema(response_model) ->
        changeset

      function_exported?(response_model, :validate_changeset, 1) ->
        response_model.validate_changeset(changeset)

      function_exported?(response_model, :validate_changeset, 2) ->
        response_model.validate_changeset(changeset, context)

      true ->
        changeset
    end
  end
end

defmodule InstructorLite.Adapters.ChatCompletionsCompatible do
  @moduledoc """
  Adapter for Chat Completions-compatible API endpoints, such as
  [OpenAI](https://platform.openai.com/docs/api-reference/chat),
  [Grok](https://docs.x.ai/docs/api-reference#chat-completions) or
  [Gemini](https://ai.google.dev/gemini-api/docs/openai).

  This adapter uses [structured
  outputs](https://platform.openai.com/docs/guides/structured-outputs/structured-outputs).

  ## Params
  `params` argument should be shaped as a [Create chat completion request body](https://platform.openai.com/docs/api-reference/chat/create).
   
  ## Example

  ```
  InstructorLite.instruct(%{
      messages: [%{role: "user", content: "John is 25yo"}],
      model: "gpt-4o-mini",
      service_tier: "default"
    },
    response_model: %{name: :string, age: :integer},
    adapter: InstructorLite.Adapters.ChatCompletionsCompatible,
    adapter_context: [
      api_key: Application.fetch_env!(:instructor_lite, :openai_key),
      url: "https://api.openai.com/v1/chat/completions"
    ]
  )
  {:ok, %{name: "John", age: 25}}
  ```
  """
  @behaviour InstructorLite.Adapter

  @default_model "gpt-4o-mini"

  @send_request_schema NimbleOptions.new!(
                         api_key: [
                           type: :string,
                           required: true,
                           doc: "API key"
                         ],
                         http_client: [
                           type: :atom,
                           default: Req,
                           doc: "Any module that follows `Req.post/2` interface"
                         ],
                         http_options: [
                           type: :keyword_list,
                           default: [receive_timeout: 60_000],
                           doc: "Options passed to `http_client.post/2`"
                         ],
                         url: [
                           type: :string,
                           default: "https://api.openai.com/v1/chat/completions",
                           doc: "API endpoint to use for sending requests"
                         ]
                       )

  @doc """
  Make request to API.
    
  ## Options

  #{NimbleOptions.docs(@send_request_schema)}
  """
  @impl InstructorLite.Adapter
  def send_request(params, opts) do
    context =
      opts
      |> Keyword.get(:adapter_context, [])
      |> NimbleOptions.validate!(@send_request_schema)

    options =
      Keyword.merge(context[:http_options], json: params, auth: {:bearer, context[:api_key]})

    case context[:http_client].post(context[:url], options) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, response} -> {:error, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates `params` with prompt based on `json_schema` and `notes`.

  Also specifies default `#{@default_model}` model if not provided by a user. 
  """
  @impl InstructorLite.Adapter
  def initial_prompt(params, opts) do
    sys_message = [
      %{
        role: "system",
        content: InstructorLite.Prompt.prompt(opts)
      }
    ]

    params
    |> Map.put_new(:model, @default_model)
    |> Map.put_new(:response_format, %{
      type: "json_schema",
      json_schema: %{
        name: "schema",
        strict: true,
        schema: Keyword.fetch!(opts, :json_schema)
      }
    })
    |> Map.update(:messages, sys_message, fn msgs -> sys_message ++ msgs end)
  end

  @doc """
  Updates `params` with prompt for retrying a request.
  """
  @impl InstructorLite.Adapter
  def retry_prompt(params, resp_params, errors, _response, _opts) do
    do_better = [
      %{role: "assistant", content: InstructorLite.JSON.encode!(resp_params)},
      %{
        role: "system",
        content: InstructorLite.Prompt.validation_failed(errors)
      }
    ]

    Map.update(params, :messages, do_better, fn msgs -> msgs ++ do_better end)
  end

  @doc """
  Parse chat completion endpoint response.

  Can return:
    * `{:ok, parsed_json}` on success.
    * `{:error, :refusal, reason}` on [refusal](https://platform.openai.com/docs/guides/structured-outputs/refusals).
    * `{:error, :unexpected_response, response}` if response is of unexpected shape.
  """
  @impl InstructorLite.Adapter
  def parse_response(response, opts) do
    with {:ok, json} <- find_output(response, opts) do
      InstructorLite.JSON.decode(json)
    end
  end

  @doc """
  Parse chat completion endpoint response in search of plain text output.

  Can return:
    * `{:ok, text_output}` on success.
    * `{:error, :refusal, reason}` on [refusal](https://platform.openai.com/docs/guides/structured-outputs/refusals).
    * `{:error, :unexpected_response, response}` if response is of unexpected shape.
  """
  @impl InstructorLite.Adapter
  def find_output(response, _opts) do
    case response do
      %{"choices" => [%{"message" => %{"refusal" => refusal}}]} when not is_nil(refusal) ->
        {:error, :refusal, refusal}

      %{"choices" => [%{"message" => %{"content" => output}}]} ->
        {:ok, output}

      other ->
        {:error, :unexpected_response, other}
    end
  end
end

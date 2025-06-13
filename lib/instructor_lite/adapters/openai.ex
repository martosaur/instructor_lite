defmodule InstructorLite.Adapters.OpenAI do
  @moduledoc """
  [OpenAI](https://platform.openai.com/docs/overview) adapter. 

  This adapter is implemented using
  [responses](https://platform.openai.com/docs/api-reference/responses) endpoint
  and [structured
  outputs](https://platform.openai.com/docs/guides/structured-outputs/structured-outputs).

  ## Params
  `params` argument should be shaped as a [Create model response request
  body](https://platform.openai.com/docs/api-reference/responses/create).
   
  ## Example

  ```
  InstructorLite.instruct(%{
      input: [%{role: "user", content: "John is 25yo"}],
      model: "gpt-4o-mini",
      service_tier: "default"
    },
    response_model: %{name: :string, age: :integer},
    adapter: InstructorLite.Adapters.OpenAI,
    adapter_context: [api_key: Application.fetch_env!(:instructor_lite, :openai_key)]
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
                           doc: "OpenAI API key"
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
                           default: "https://api.openai.com/v1/responses",
                           doc: "API endpoint to use for sending requests"
                         ]
                       )

  @doc """
  Make request to OpenAI API.
    
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

  It uses `instructions` parameter for system prompt.

  Also specifies default `#{@default_model}` model if not provided by a user. 
  """
  @impl InstructorLite.Adapter
  def initial_prompt(params, opts) do
    mandatory_part = """
    As a genius expert, your task is to understand the content and provide the parsed objects in json that match json schema
    """

    optional_notes =
      if notes = opts[:notes] do
        """
        Additional notes on the schema:\n
        #{notes}
        """
      else
        ""
      end

    params
    |> Map.put_new(:model, @default_model)
    |> Map.put_new(:text, %{
      format: %{
        type: "json_schema",
        name: "schema",
        strict: true,
        schema: Keyword.fetch!(opts, :json_schema)
      }
    })
    |> Map.put(:instructions, mandatory_part <> optional_notes)
  end

  @doc """
  Updates `params` with prompt for retrying a request.

  If the initial request was made with conversation state (enabled by
  default), it will drop previous chat messages from the request and specify
  `previous_response_id` instead. If conversation state is disabled, it will
  append new messages to the previous `input` the same way chat completions-based
  adapters do.
  """
  @impl InstructorLite.Adapter
  def retry_prompt(params, resp_params, errors, response, _opts) do
    do_better = [
      %{
        role: "system",
        content: """
        The response did not pass validation. Please try again and fix the following validation errors:\n

        #{errors}
        """
      }
    ]

    case response do
      %{"store" => true, "id" => response_id} ->
        params
        |> Map.put(:input, do_better)
        |> Map.put(:previous_response_id, response_id)
        |> Map.delete(:instructions)

      _ ->
        Map.update!(params, :input, fn input ->
          assistant_response = %{
            role: "assistant",
            content: InstructorLite.JSON.encode!(resp_params)
          }

          if is_binary(input) do
            [%{role: "user", content: input}, assistant_response | do_better]
          else
            input ++ [assistant_response | do_better]
          end
        end)
    end
  end

  @doc """
  Parse chat completion endpoint response.

  Can return:
    * `{:ok, parsed_json}` on success.
    * `{:error, :refusal, reason}` on [refusal](https://platform.openai.com/docs/guides/structured-outputs/refusals).
    * `{:error, :unexpected_response, response}` if response is of unexpected shape.
  """
  @impl InstructorLite.Adapter
  def parse_response(response, _opts) do
    case response do
      %{"output" => output} ->
        Enum.find_value(output, {:error, :unexpected_response, response}, fn
          %{"role" => "assistant", "content" => [%{"text" => text}]} ->
            InstructorLite.JSON.decode(text)

          %{"role" => "assistant", "content" => [%{"refusal" => reason}]} ->
            {:error, :refusal, reason}

          _ ->
            false
        end)

      other ->
        {:error, :unexpected_response, other}
    end
  end
end

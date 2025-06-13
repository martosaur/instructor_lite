defmodule InstructorLite.Adapters.Anthropic do
  @moduledoc """
  [Anthropic](https://docs.anthropic.com/en/home) adapter.

  This adapter is implemented using the [Messages API](https://docs.anthropic.com/en/api/messages) and [function calling](https://docs.anthropic.com/en/docs/build-with-claude/tool-use).

  ## Params
  `params` argument should be shaped as a [Create message request body](https://docs.anthropic.com/en/api/messages).

  ## Example

  ```
  InstructorLite.instruct(%{
      messages: [%{role: "user", content: "John is 25yo"}],
      model: "claude-3-5-sonnet-20240620",
      metadata: %{user_id: "3125"}
    },
    response_model: %{name: :string, age: :integer},
    adapter: InstructorLite.Adapters.Anthropic,
    adapter_context: [api_key: Application.fetch_env!(:instructor_lite, :anthropic_key)]
  )
  {:ok, %{name: "John", age: 25}}
  ```
  """
  @behaviour InstructorLite.Adapter

  @default_model "claude-3-5-sonnet-20240620"
  @default_max_tokens 1024

  @send_request_schema NimbleOptions.new!(
                         api_key: [
                           type: :string,
                           required: true,
                           doc: "Anthropic API key"
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
                           default: "https://api.anthropic.com/v1/messages",
                           doc: "API endpoint to use for sending requests"
                         ],
                         version: [
                           type: :string,
                           default: "2023-06-01",
                           doc:
                             "Anthropic [API version](https://docs.anthropic.com/en/api/versioning)"
                         ]
                       )

  @doc """
  Make request to Anthropic API

  ## Options

  #{NimbleOptions.docs(@send_request_schema)}
  """
  @impl InstructorLite.Adapter
  def send_request(params, opts) do
    context =
      opts
      |> Keyword.get(:adapter_context, [])
      |> NimbleOptions.validate!(@send_request_schema)

    headers = [
      {"x-api-key", context[:api_key]},
      {"anthropic-version", context[:version]}
    ]

    options =
      context[:http_options]
      |> Keyword.merge(json: params)
      |> Keyword.update(:headers, headers, fn client_side ->
        Enum.uniq_by(client_side ++ headers, &elem(&1, 0))
      end)

    case context[:http_client].post(context[:url], options) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, response} -> {:error, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates `params` with prompt based on `json_schema` and `notes`.

  Also specifies default `#{@default_model}` model and #{@default_max_tokens} `max_tokens` if not provided by a user.
  """
  @impl InstructorLite.Adapter
  def initial_prompt(params, opts) do
    params
    |> Map.put_new(:model, @default_model)
    |> Map.put_new(:max_tokens, @default_max_tokens)
    |> Map.put_new(:system, InstructorLite.Prompt.prompt(opts))
    |> Map.put_new(:tool_choice, %{type: "tool", name: "Schema"})
    |> Map.put_new(:tools, [
      %{
        name: "Schema",
        description:
          "Correctly extracted `Schema` with all the required parameters with correct types",
        input_schema: Keyword.fetch!(opts, :json_schema)
      }
    ])
  end

  @doc """
  Updates `params` with prompt for retrying a request.

  The error is represented as an erroneous `tool_result`.
  """
  @impl InstructorLite.Adapter
  def retry_prompt(params, _resp_params, errors, response, _opts) do
    %{"content" => [%{"id" => tool_use_id}]} =
      assistant_reply = Map.take(response, ["content", "role"])

    do_better = [
      assistant_reply,
      %{
        role: "user",
        content: [
          %{
            type: "tool_result",
            tool_use_id: tool_use_id,
            is_error: true,
            content: InstructorLite.Prompt.validation_failed(errors)
          }
        ]
      }
    ]

    Map.update(params, :messages, do_better, fn msgs -> msgs ++ do_better end)
  end

  @doc """
  Parse API response.

  Can return:
    * `{:ok, parsed_object}` on success.
    * `{:error, :unexpected_response, response}` if response is of unexpected shape.
  """
  @impl InstructorLite.Adapter
  def parse_response(response, _opts) do
    case response do
      %{"stop_reason" => "tool_use", "content" => [%{"input" => decoded}]} ->
        {:ok, decoded}

      other ->
        {:error, :unexpected_response, other}
    end
  end
end

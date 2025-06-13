defmodule InstructorLite.Adapters.Llamacpp do
  @moduledoc """
  [LLaMA.cpp HTTP Server](https://github.com/ggerganov/llama.cpp/tree/master/examples/server) adapter.

  This adapter is implemented using llama-specific [completion](https://github.com/ggerganov/llama.cpp/tree/master/examples/server#post-completion-given-a-prompt-it-returns-the-predicted-completion) endpoint.

  ## Params
  `params` argument should be shaped as a [completion request body](https://github.com/ggerganov/llama.cpp/tree/master/examples/server#post-completion-given-a-prompt-it-returns-the-predicted-completion)

  ## Example

  ```
  InstructorLite.instruct(%{
      prompt: "John is 25yo",
      temperature: 0.8
    },
    response_model: %{name: :string, age: :integer},
    adapter: InstructorLite.Adapters.Llamacpp,
    adapter_context: [url: "http://localhost:8000/completion"]
  )
  {:ok, %{name: "John", age: 25}}
  ```
  """

  @behaviour InstructorLite.Adapter

  @send_request_schema NimbleOptions.new!(
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
                           required: true,
                           doc:
                             "API endpoint to use, for example `http://localhost:8000/completion`"
                         ]
                       )

  @doc """
  Make request to llamacpp HTTP server.

  ## Options

  #{NimbleOptions.docs(@send_request_schema)}
  """
  @impl InstructorLite.Adapter
  def send_request(params, opts) do
    context =
      opts
      |> Keyword.get(:adapter_context, [])
      |> NimbleOptions.validate!(@send_request_schema)

    options = Keyword.merge(context[:http_options], json: params)

    case context[:http_client].post(context[:url], options) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, response} -> {:error, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates `params` with prompt based on `json_schema` and `notes`.

  It uses `json_schema` and `system_prompt` request parameters.
  """
  @impl InstructorLite.Adapter
  def initial_prompt(params, opts) do
    params
    |> Map.put_new(:json_schema, Keyword.fetch!(opts, :json_schema))
    |> Map.put_new(:system_prompt, InstructorLite.Prompt.prompt(opts))
  end

  @doc """
  Updates `params` with prompt for retrying a request.
  """
  @impl InstructorLite.Adapter
  def retry_prompt(params, resp_params, errors, _response, _opts) do
    do_better = """
    Your previous response:

    #{InstructorLite.JSON.encode!(resp_params)}

    did not pass validation. Please try again and fix following validation errors:\n
    #{errors}
    """

    params
    |> Map.update(:prompt, do_better, fn prompt ->
      prompt <> "\n" <> do_better
    end)
  end

  @doc """
  Parse API response.

  Can return:
    * `{:ok, parsed_json}` on success.
    * `{:error, :unexpected_response, response}` if response is of unexpected shape.
  """
  @impl InstructorLite.Adapter
  def parse_response(response, _opts) do
    case response do
      %{"content" => json} ->
        InstructorLite.JSON.decode(json)

      other ->
        {:error, :unexpected_response, other}
    end
  end
end

defmodule Instructor.Adapters.Llamacpp do
  @moduledoc """
  Runs against the llama.cpp server. To be clear this calls the llamacpp specific
  endpoints, not the open-ai compliant ones.

  You can read more about it here:
    https://github.com/ggerganov/llama.cpp/tree/master/examples/server
  """

  @behaviour Instructor.Adapter

  @send_request_schema NimbleOptions.new!(
                         http_client: [
                           type: :atom,
                           default: Req,
                           doc: "Any module that follows `Req.post/2` interface"
                         ],
                         http_options: [
                           type: :keyword_list,
                           default: [receive_timeout: 60_000]
                         ],
                         url: [
                           type: :string,
                           required: true,
                           doc:
                             "API endpoint to use, for example `http://localhost:8000/completion`"
                         ]
                       )

  @impl Instructor.Adapter
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

  @impl Instructor.Adapter
  def initial_prompt(params, opts) do
    mandatory_part = """
    As a genius expert, your task is to understand the content and provide the parsed objects in json that match json schema\n
    """

    optional_notes =
      if notes = opts[:notes] do
        """
        Additional notes on the schema:

        #{notes}
        """
      else
        ""
      end

    params
    |> Map.put_new(:json_schema, Keyword.fetch!(opts, :json_schema))
    |> Map.put_new(:system_prompt, mandatory_part <> optional_notes)
  end

  @impl Instructor.Adapter
  def retry_prompt(params, resp_params, errors, _response, _opts) do
    do_better = """
    Your previous response:

    #{Jason.encode!(resp_params)}

    did not pass validation. Please try again and fix following validation errors:\n
    #{errors}
    """

    params
    |> Map.update(:prompt, do_better, fn prompt ->
      prompt <> "\n" <> do_better
    end)
  end

  @impl Instructor.Adapter
  def parse_response(response, _opts) do
    case response do
      %{"content" => json} ->
        Jason.decode(json)

      other ->
        {:error, :unexpected_response, other}
    end
  end
end

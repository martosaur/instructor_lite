defmodule Instructor.Adapters.OpenAI do
  @moduledoc """
  Documentation for `Instructor.Adapters.OpenAI`.
  """
  @behaviour Instructor.Adapter

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
                           default: [receive_timeout: 60_000]
                         ],
                         url: [
                           type: :string,
                           default: "https://api.openai.com/v1/chat/completions",
                           doc: "API endpoint to use for sending requests"
                         ]
                       )

  @impl Instructor.Adapter
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

  @impl Instructor.Adapter
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

    sys_message = [
      %{
        role: "system",
        content: mandatory_part
      }
    ]

    params
    |> Map.put_new(:model, @default_model)
    |> Map.put(:response_format, %{
      type: "json_schema",
      json_schema: %{
        name: "schema",
        description: optional_notes,
        strict: true,
        schema: Keyword.fetch!(opts, :json_schema)
      }
    })
    |> Map.update(:messages, sys_message, fn msgs -> sys_message ++ msgs end)
  end

  @impl Instructor.Adapter
  def retry_prompt(params, resp_params, errors, _response, _opts) do
    do_better = [
      %{role: "assistant", content: Jason.encode!(resp_params)},
      %{
        role: "system",
        content: """
        The response did not pass validation. Please try again and fix the following validation errors:\n

        #{errors}
        """
      }
    ]

    Map.update(params, :messages, do_better, fn msgs -> msgs ++ do_better end)
  end

  @impl Instructor.Adapter
  def parse_response(response, _opts) do
    case response do
      %{"choices" => [%{"message" => %{"content" => json, "refusal" => nil}}]} ->
        Jason.decode(json)

      %{"choices" => [%{"message" => %{"refusal" => refusal}}]} ->
        {:error, :refusal, refusal}

      other ->
        {:error, :unexpected_response, other}
    end
  end
end

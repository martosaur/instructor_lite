defmodule Instructor.Adapters.OpenAI do
  @moduledoc """
  Documentation for `Instructor.Adapters.OpenAI`.
  """
  @behaviour Instructor.Adapter

  @default_config [
    url: "https://api.openai.com/v1/chat/completions",
    http_options: [receive_timeout: 60_000]
  ]

  @default_model "gpt-4o-mini"

  @impl Instructor.Adapter
  def send_request(params, opts) do
    opts = Keyword.merge(@default_config, opts)
    http_client = Keyword.fetch!(opts, :http_client)
    api_key = Keyword.fetch!(opts, :api_key)

    options = Keyword.merge(opts[:http_options], json: params, auth: {:bearer, api_key})

    case http_client.post(opts[:url], options) do
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
        schema: opts[:json_schema]
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

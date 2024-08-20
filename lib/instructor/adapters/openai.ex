defmodule Instructor.Adapters.OpenAI do
  @moduledoc """
  Documentation for `Instructor.Adapters.OpenAI`.
  """
  @behaviour Instructor.Adapter

  @default_config [
    url: "https://api.openai.com/v1/chat/completions",
    http_options: [receive_timeout: 60_000]
  ]

  @impl true
  def chat_completion(prompt, _params, config) do
    config = Keyword.merge(@default_config, config)
    http_client = Keyword.fetch!(config, :http_client)
    api_key = Keyword.fetch!(config, :api_key)

    options = Keyword.merge(config[:http_options], json: prompt, auth: {:bearer, api_key})

    case http_client.post(config[:url], options) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "Unexpected HTTP response code: #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def prompt(params) do
    params
    |> Keyword.drop([:response_model, :validation_context, :max_retries, :mode])
    |> Map.new()
  end
end

defmodule Instructor.Adapters.OpenAI do
  @moduledoc """
  Documentation for `Instructor.Adapters.OpenAI`.
  """
  @behaviour Instructor.Adapter

  @impl true
  def chat_completion(prompt, _params, config) do
    config = if config, do: config, else: config()

    do_chat_completion(prompt, config)
  end

  @impl true
  def prompt(params) do
    # Peel off instructor only parameters
    {_, params} = Keyword.pop(params, :response_model)
    {_, params} = Keyword.pop(params, :validation_context)
    {_, params} = Keyword.pop(params, :max_retries)
    {_, params} = Keyword.pop(params, :mode)

    Enum.into(params, %{})
  end

  defp do_chat_completion(prompt, config) do
    options = Keyword.merge(http_options(config), json: prompt, auth: {:bearer, api_key(config)})

    case Req.post(url(config), options) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "Unexpected HTTP response code: #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp url(config), do: api_url(config) <> "/v1/chat/completions"
  defp api_url(config), do: Keyword.fetch!(config, :api_url)
  defp api_key(config), do: Keyword.fetch!(config, :api_key)
  defp http_options(config), do: Keyword.fetch!(config, :http_options)

  defp config() do
    base_config = Application.get_env(:instructor, :openai, [])

    default_config = [
      api_url: "https://api.openai.com",
      http_options: [receive_timeout: 60_000]
    ]

    Keyword.merge(default_config, base_config)
  end
end

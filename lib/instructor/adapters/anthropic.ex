defmodule Instructor.Adapters.Anthropic do
  @moduledoc """
  Documentation for `Instructor.Adapters.Anthropic`
  """
  @behaviour Instructor.Adapter

  @default_config [
    url: "https://api.anthropic.com/v1/messages",
    http_options: [receive_timeout: 60_000]
  ]

  @default_version "2023-06-01"
  @default_model "claude-3-5-sonnet-20240620"
  @default_max_tokens 1024

  @impl true
  def chat_completion(params, opts) do
    opts = Keyword.merge(@default_config, opts)
    http_client = Keyword.fetch!(opts, :http_client)
    api_key = Keyword.fetch!(opts, :api_key)

    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", @default_version}
    ]

    options =
      opts[:http_options]
      |> Keyword.merge(json: params)
      |> Keyword.update(:headers, headers, fn client_side ->
        Enum.uniq_by(client_side ++ headers, &elem(&1, 0))
      end)

    case http_client.post(opts[:url], options) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, response} -> {:error, response}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def initial_prompt(params, opts) do
    mandatory_part = """
    As a genius expert, your task is to understand the content and provide the parsed objects in json that match json schema\n
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
    |> Map.put_new(:max_tokens, @default_max_tokens)
    |> Map.put_new(:system, mandatory_part <> optional_notes)
    |> Map.put_new(:tool_choice, %{type: "tool", name: "Schema"})
    |> Map.put_new(:tools, [
      %{
        name: "Schema",
        description:
          "Correctly extracted `Schema` with all the required parameters with correct types",
        input_schema: opts[:json_schema]
      }
    ])
  end

  @impl true
  def retry_prompt(params, _resp_params, errors, response) do
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
            content: """
            Validation failed. Please try again and fix following validation errors

            #{errors}
            """
          }
        ]
      }
    ]

    Map.update(params, :messages, do_better, fn msgs -> msgs ++ do_better end)
  end

  @impl true
  def from_response(response) do
    case response do
      %{"stop_reason" => "tool_use", "content" => [%{"input" => decoded}]} ->
        {:ok, decoded}

      other ->
        {:error, :unexpected_response, other}
    end
  end
end

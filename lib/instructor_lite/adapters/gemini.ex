defmodule InstructorLite.Adapters.Gemini do
  @moduledoc """

  """
  @behaviour InstructorLite.Adapter

  @send_request_schema NimbleOptions.new!(
                         api_key: [
                           type: :string,
                           required: true,
                           doc: "Gemini API key"
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
                           default:
                             "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
                           doc: "API endpoint to use for sending requests"
                         ],
                         model: [
                           type: :string,
                           default: "gemini-1.5-flash-8b",
                           doc:
                             "Gemini [model](https://ai.google.dev/gemini-api/docs/models/gemini)"
                         ]
                       )

  @impl InstructorLite.Adapter
  def send_request(params, opts) do
    context =
      opts
      |> Keyword.get(:adapter_context, [])
      |> NimbleOptions.validate!(@send_request_schema)

    options =
      [
        path_params: [model: context[:model]],
        path_params_style: :curly
      ]
      |> Keyword.merge(context[:http_options])
      |> Keyword.merge(
        json: params,
        params: [key: context[:api_key]]
      )

    case context[:http_client].post(context[:url], options) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, response} -> {:error, response}
      {:error, reason} -> {:error, reason}
    end
  end

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

    sys_instruction = %{
      parts: [
        %{text: mandatory_part <> optional_notes}
      ]
    }

    generation_config = %{
      responseMimeType: "application/json",
      responseSchema: Keyword.fetch!(opts, :json_schema)
    }

    params
    |> Map.put_new(:systemInstruction, sys_instruction)
    |> Map.update(:generationConfig, generation_config, fn user_config ->
      Map.merge(generation_config, user_config)
    end)
  end

  @impl InstructorLite.Adapter
  def retry_prompt(params, resp_params, errors, _response, _opts) do
    do_better = [
      %{role: "model", parts: [%{text: Jason.encode!(resp_params)}]},
      %{
        role: "user",
        parts: [
          %{
            text: """
            The response did not pass validation. Please try again and fix the following validation errors:\n

            #{errors}
            """
          }
        ]
      }
    ]

    Map.update(params, :contents, do_better, fn contents -> contents ++ do_better end)
  end

  @impl InstructorLite.Adapter
  def parse_response(response, _opts) do
    case response do
      %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}}]} ->
        Jason.decode(text)

      %{"promptFeedback" => %{"blockReason" => reason}} ->
        {:error, :refusal, reason}

      other ->
        {:error, :unexpected_response, other}
    end
  end
end

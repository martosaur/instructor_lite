defmodule InstructorLite.Adapters.Gemini do
  @moduledoc """
  [Gemini](https://ai.google.dev/gemini-api) adapter.

  This adapter is implemented using [Text generation](https://ai.google.dev/gemini-api/docs/text-generation) endpoint configured for [structured output](https://ai.google.dev/gemini-api/docs/structured-output?lang=rest#supply-schema-in-config)

  ## Params
  `params` argument should be shaped as a [`models.GenerateBody` request body](https://ai.google.dev/api/generate-content#request-body)

  ## Example

  ```
  InstructorLite.instruct(
    %{contents: [%{role: "user", parts: [%{text: "John is 25yo"}]}]},
    response_model: %{name: :string, age: :integer},
    json_schema: %{
      type: "object",
      required: [:age, :name],
      properties: %{name: %{type: "string"}, age: %{type: "integer"}}
    },
    adapter: InstructorLite.Adapters.Gemini,
    adapter_context: [
      model: "gemini-1.5-flash-8b",
      api_key: Application.fetch_env!(:instructor_lite, :gemini_key)
    ]
  )
  {:ok, %{name: "John", age: 25}}
  ```

  > #### Specifying model {: .tip}
  >
  > Note how, unlike other adapters, the Gemini adapter expects `model` under `adapter_context`. 

  > #### JSON Schema {: .warning}
  >
  > Gemini's idea of JSON Schema is [quite different](https://ai.google.dev/api/generate-content#generationconfig) from other major models, so `InstructorLite.JSONSchema` won't help you even for simple cases. Luckily, the Gemini API provides detailed errors for invalid schemas.

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

  @doc """
  Make request to Gemini API

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

  @doc """
  Puts `systemInstruction` and updates `generationConfig` in `params` with prompt based on `json_schema` and `notes`.
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

  @doc """
  Updates `params` with prompt for retrying a request.
  """
  @impl InstructorLite.Adapter
  def retry_prompt(params, resp_params, errors, _response, _opts) do
    do_better = [
      %{role: "model", parts: [%{text: InstructorLite.JSON.encode!(resp_params)}]},
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

  @doc """
  Parse text generation endpoint response.

  Can return:
    * `{:ok, parsed_json}` on success.
    * `{:error, :refusal, prompt_feedback}` if [request was blocked](https://ai.google.dev/api/generate-content#generatecontentresponse).
    * `{:error, :unexpected_response, response}` if response is of unexpected shape.
  """
  @impl InstructorLite.Adapter
  def parse_response(response, _opts) do
    case response do
      %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}}]} ->
        InstructorLite.JSON.decode(text)

      %{"promptFeedback" => %{"blockReason" => _} = reason} ->
        {:error, :refusal, reason}

      other ->
        {:error, :unexpected_response, other}
    end
  end
end

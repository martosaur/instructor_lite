defmodule InstructorLite.Adapters.OpenAI do
  @moduledoc """
  [OpenAI](https://platform.openai.com/docs/overview) adapter. 

  This adapter is implemented using
  [responses](https://platform.openai.com/docs/api-reference/responses) endpoint
  and [structured
  outputs](https://platform.openai.com/docs/guides/structured-outputs/structured-outputs).

  ## Params
  `params` argument should be shaped as a [Create model response request
  body](https://platform.openai.com/docs/api-reference/responses/create).
   
  ## Example

  ```
  InstructorLite.instruct(%{
      input: [%{role: "user", content: "John is 25yo"}],
      model: "gpt-4o-mini",
      service_tier: "default"
    },
    response_model: %{name: :string, age: :integer},
    adapter: InstructorLite.Adapters.OpenAI,
    adapter_context: [api_key: Application.fetch_env!(:instructor_lite, :openai_key)]
  )
  {:ok, %{name: "John", age: 25}}
  ```
  """
  @behaviour InstructorLite.Adapter

  alias InstructorLite.Adapters.ResponsesCompatible

  @doc """
  Make request to OpenAI API.
    
  ## Options

  #{NimbleOptions.docs(ResponsesCompatible.send_request_schema())}
  """
  @impl InstructorLite.Adapter
  defdelegate send_request(params, opts), to: InstructorLite.Adapters.ResponsesCompatible

  @doc """
  Updates `params` with prompt based on `json_schema` and `notes`.

  It uses `instructions` parameter for system prompt.

  Also specifies default `#{ResponsesCompatible.default_model()}` model if not provided by a user. 
  """
  @impl InstructorLite.Adapter
  defdelegate initial_prompt(params, opts), to: InstructorLite.Adapters.ResponsesCompatible

  @doc """
  Updates `params` with prompt for retrying a request.

  If the initial request was made with conversation state (enabled by
  default), it will drop previous chat messages from the request and specify
  `previous_response_id` instead. If conversation state is disabled, it will
  append new messages to the previous `input` the same way chat completions-based
  adapters do.
  """
  @impl InstructorLite.Adapter
  defdelegate retry_prompt(params, resp_params, errors, response, opts),
    to: InstructorLite.Adapters.ResponsesCompatible

  @doc """
  Parse chat completion endpoint response.

  Can return:
    * `{:ok, parsed_json}` on success.
    * `{:error, :refusal, reason}` on [refusal](https://platform.openai.com/docs/guides/structured-outputs/refusals).
    * `{:error, :unexpected_response, response}` if response is of unexpected shape.
  """
  @impl InstructorLite.Adapter
  defdelegate parse_response(response, opts), to: InstructorLite.Adapters.ResponsesCompatible

  @doc """
  Parse API response in search of plain text output.

  Can return:
    * `{:ok, text_output}` on success.
    * `{:error, :refusal, reason}` on [refusal](https://platform.openai.com/docs/guides/structured-outputs/refusals).
    * `{:error, :unexpected_response, response}` if response is of unexpected shape.
  """
  @impl InstructorLite.Adapter
  defdelegate find_output(response, opts), to: InstructorLite.Adapters.ResponsesCompatible
end

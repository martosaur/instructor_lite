defmodule InstructorLite.Adapter do
  @moduledoc """
  Behaviour for implementing adapter modules.

  The role of an adapter module is to encapsulate all logic about a particular LLM, which can be quite specific. As a result, most of the details live in adapter modules and main InstructorLite interface is very broad.
    
  > #### Do it! {: .tip}
  >
  > While built-in adapters are fairly flexible, users are encouraged to write their own adapters to establish a better control over prompt building, http clients, etc.
  """
  alias InstructorLite

  @typedoc """
  Map of adapter-specific values, such as messages, prompt, model name, or temperature, that are typically sent to the LLM in request body.
  """
  @type params :: map()

  @typedoc """
  Raw content of a successful response.
  """
  @type response :: any()

  @typedoc """
  Parsed response content that can be cast to a changeset.
  """
  @type parsed_response :: map()

  @callback send_request(params(), InstructorLite.opts()) :: {:ok, response()} | {:error, any()}
  @callback initial_prompt(params(), InstructorLite.opts()) :: params()
  @callback retry_prompt(
              params(),
              parsed_response(),
              errors :: String.t(),
              response(),
              InstructorLite.opts()
            ) ::
              params()
  @callback parse_response(response(), InstructorLite.opts()) ::
              {:ok, parsed_response()} | {:error, any()} | {:error, reason :: atom(), any()}
end

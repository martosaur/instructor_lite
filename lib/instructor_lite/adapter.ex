defmodule InstructorLite.Adapter do
  @moduledoc """
  Behaviour for implementing adapter modules.

  The role of an adapter module is to encapsulate all logic for a particular LLM, which can be quite specific. As a result, most of the details live in adapter modules and main InstructorLite interface is very broad.
    
  > #### Implement your own! {: .tip}
  >
  > While built-in adapters are fairly flexible, users are encouraged to write their own adapters to establish a better control over prompt building, http clients, etc.
  """
  alias InstructorLite

  @typedoc """
  Map of adapter-specific values, such as messages, prompt, model name, or temperature. These parameters are typically sent to the LLM in request body.
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

  @doc """
  Make request to model API.
  """
  @callback send_request(params(), InstructorLite.opts()) :: {:ok, response()} | {:error, any()}

  @doc """
  Update `params` with model-specific prompt.
  """
  @callback initial_prompt(params(), InstructorLite.opts()) :: params()

  @doc """
  Update `params` with model-specific prompt for a retry. This usually involves appending errors from a changeset.
  """
  @callback retry_prompt(
              params(),
              parsed_response(),
              errors :: String.t(),
              response(),
              InstructorLite.opts()
            ) ::
              params()

  @doc """
  Parse API response.

  On success, it returns an ok tuple with parsed json object ready to be cast to a changeset.

  On error, it may return a 3-element error tuple with error reason. In the worst-case scenario, it returns the original input wrapped in an error tuple. 
  """
  @callback parse_response(response(), InstructorLite.opts()) ::
              {:ok, parsed_response()} | {:error, any()} | {:error, reason :: atom(), any()}

  @doc """
  Find text output in the response.

  Similar to `parse_response/2`, but this callback assumes a simple plain text
  response. Used in `InstructorLite.ask/2` function. 
  """
  @doc since: "1.1.0"
  @callback find_output(response(), InstructorLite.opts()) ::
              {:ok, String.t()} | {:error, any()} | {:error, reason :: atom(), any()}
end

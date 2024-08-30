defmodule Instructor.Adapter do
  @moduledoc """
  Behaviour for `Instructor.Adapter`.
  """
  alias Instructor

  @typedoc """
  Map of adapter-specific values, such as messages, prompt, model name, or temperature that are eventually sent to the LLM.
  """
  @type params :: map()

  @typedoc """
  Content of a successful response.
  """
  @type response :: any()

  @typedoc """
  Parsed response content that can be cast to a changeset.
  """
  @type parsed_response :: map()

  @callback send_request(params(), Instructor.opts()) :: {:ok, response()} | {:error, any()}
  @callback initial_prompt(params(), Instructor.opts()) :: params()
  @callback retry_prompt(
              params(),
              parsed_response(),
              errors :: String.t(),
              response(),
              Instructor.opts()
            ) ::
              params()
  @callback parse_response(response(), Instructor.opts()) ::
              {:ok, parsed_response()} | {:error, any()} | {:error, reason :: atom(), any()}
end

defmodule Instructor.Adapter do
  @moduledoc """
  Behaviour for `Instructor.Adapter`.
  """
  @type opts :: Keyword.t()
  @type params :: map()
  @type response :: any()
  @type parsed_response :: map()

  @callback send_request(params(), opts()) :: {:ok, response()} | {:error, any()}
  @callback initial_prompt(params(), opts()) :: params()
  @callback retry_prompt(params(), parsed_response(), errors :: String.t(), response(), opts()) ::
              params()
  @callback parse_response(response(), opts()) ::
              {:ok, parsed_response()} | {:error, any()} | {:error, reason :: atom(), any()}
end

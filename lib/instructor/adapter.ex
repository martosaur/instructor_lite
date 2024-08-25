defmodule Instructor.Adapter do
  @moduledoc """
  Behavior for `Instructor.Adapter`.
  """
  @callback chat_completion(map(), Keyword.t()) :: any()
  @callback initial_prompt(map(), map()) :: map()
  @callback retry_prompt(map(), map(), String.t()) :: map()
  @callback from_response(any()) :: any()
end

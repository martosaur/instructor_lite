defmodule Instructor.Adapter do
  @moduledoc """
  Behavior for `Instructor.Adapter`.
  """
  @callback chat_completion(map(), Keyword.t()) :: any()
  @callback prompt(map(), map()) :: map()
  @callback from_response(any()) :: any()
end

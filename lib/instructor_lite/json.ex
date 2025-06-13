defmodule InstructorLite.JSON do
  @moduledoc false

  # Inspired by Oban https://github.com/oban-bg/oban/blob/c1f996ec948f0e9a21f50954b47be2bff91b0d3d/lib/oban/json.ex

  cond do
    Code.ensure_loaded?(JSON) ->
      defdelegate encode!(data), to: JSON
      defdelegate decode(data), to: JSON

    Code.ensure_loaded?(Jason) ->
      defdelegate encode!(data), to: Jason
      defdelegate decode(data), to: Jason

    true ->
      message = "Missing a compatible JSON library, add `:jason` to your deps."
      IO.warn(message, Macro.Env.stacktrace(__ENV__))
  end
end

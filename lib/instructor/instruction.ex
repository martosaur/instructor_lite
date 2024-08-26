defmodule Instructor.Instruction do
  @callback notes() :: String.t() | nil
  @callback json_schema() :: map()

  defmacro __before_compile__(env) do
    unless Module.defines?(env.module, {:notes, 0}) do
      quote do
        def notes(), do: @notes
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Instructor.Instruction
      @before_compile Instructor.Instruction
      @notes nil

      def json_schema(), do: Instructor.JSONSchema.from_ecto_schema(__MODULE__)

      defoverridable json_schema: 0
    end
  end
end

defmodule Instructor.Instruction do
  @callback notes() :: String.t() | nil
  @callback json_schema() :: map()
  @callback validate_changeset(Ecto.Changeset.t(), Keyword.t()) :: Ecto.Changeset.t()

  @optional_callbacks validate_changeset: 2

  defmacro __before_compile__(env) do
    unless Module.defines?(env.module, {:notes, 0}) do
      quote do
        @impl Instructor.Instruction
        def notes(), do: @notes
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Instructor.Instruction
      @before_compile Instructor.Instruction
      @notes nil

      @impl Instructor.Instruction
      def json_schema(), do: Instructor.JSONSchema.from_ecto_schema(__MODULE__)

      defoverridable json_schema: 0
    end
  end
end

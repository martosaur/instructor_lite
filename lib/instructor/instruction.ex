defmodule Instructor.Instruction do
  @callback notes() :: String.t() | nil

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
    end
  end
end

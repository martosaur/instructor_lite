defmodule InstructorLite.Instruction do
  @moduledoc """
  `use InstructorLite.Instruction` is a way to make your Ecto schema into an Instruction, which provides additional callbacks used by InstructorLite.
    
  ## Example

  ```
  defmodule SpamPrediction do
    use Ecto.Schema
    use InstructorLite.Instruction

    @notes \"""
    Field Descriptions:
    - class: Whether or not the email is spam.
    - reason: A short, less than 10-word rationalization for the classification.
    - score: A confidence score between 0.0 and 1.0 for the classification.
    \"""
    @primary_key false
    embedded_schema do
      field(:class, Ecto.Enum, values: [:spam, :not_spam])
      field(:reason, :string)
      field(:score, :float)
    end

    @impl InstructorLite.Instruction
    def validate_changeset(changeset, _opts) do
      Ecto.Changeset.validate_number(changeset, :score,
        greater_than_or_equal_to: 0.0,
        less_than_or_equal_to: 1.0
      )
    end
  end
  ```
    
  > #### `use InstructorLite.Instruction` {: .info}
  >
  > When you `use InstructorLite.Instruction`, the Instruction module will set `@behaviour InstructorLite.Instruction`, and define default implementations of `c:notes/0` and `c:json_schema/0` callbacks.
  """

  @doc """
  Defines an optional free-form description of the schema.
    
  You can define a `@notes` attribute or `c:notes/0` callback to provide an additional free-form description to the schema. This description will be passed to the LLM together with the schema definition.
  """
  @callback notes() :: String.t() | nil

  @doc """
  Defines JSON schema for the instruction.
    
  By default, `InstructorLite.JSONSchema.from_ecto_schema/1` is called at runtime every time InstructorLite needs to convert an Ecto schema to JSON schema. However, you can bake your own JSON schema into the `c:json_schema/0` callback to eliminate the need to do it on every call.

  > #### Tip {: .tip}
  > 
  > Take advantage of this callback! Most JSON schemas are known ahead of time, so there is no need to constantly build them at runtime. In addition, `InstructorLite.JSONSchema` module aims to generate one-size-fits-all schema, so it's very unlikely to take full advantage of JSON capabilities of your LLM of choice.   
  """
  @callback json_schema() :: map()

  @doc """
  Called by `InstructorLite.consume_response/3` as part of changeset validation.

  It has full access to all `opts`. If you need to pass an arbitrary term to this callback, use the `extra` key.

  ## Example

  ```
  # Let's play a guessing game!
  defmodule CoinGuess do
    use Ecto.Schema
    use InstructorLite.Instruction

    @primary_key false
    embedded_schema do
      field(:guess, Ecto.Enum, values: [:heads, :tails])
    end

    @impl InstructorLite.Instruction
    def validate_changeset(cs, opts) do
      target = Keyword.fetch!(opts, :extra)

      case Ecto.Changeset.fetch_field!(cs, :guess) do
        ^target -> cs
        _ -> Ecto.Changeset.add_error(cs, :guess, "Wrong! Try again")
      end
    end
  end
  ```
  """
  @callback validate_changeset(Ecto.Changeset.t(), InstructorLite.opts()) :: Ecto.Changeset.t()

  @optional_callbacks validate_changeset: 2

  defmacro __before_compile__(env) do
    unless Module.defines?(env.module, {:notes, 0}) do
      quote do
        @impl InstructorLite.Instruction
        def notes(), do: @notes
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour InstructorLite.Instruction
      @before_compile InstructorLite.Instruction
      @notes nil

      @impl InstructorLite.Instruction
      def json_schema(), do: InstructorLite.JSONSchema.from_ecto_schema(__MODULE__)

      defoverridable json_schema: 0
    end
  end
end

defmodule InstructorLite.InstructionTest do
  use ExUnit.Case, async: true

  describe "notes/0" do
    defmodule ShapeFactory do
      use Ecto.Schema
      use InstructorLite.Instruction

      @notes """
      I guess we doin circles now
      """
      embedded_schema do
        field(:shape, Ecto.Enum, values: [:triangle, :circle])
      end
    end

    test "returns module attribute value" do
      assert ShapeFactory.notes() == "I guess we doin circles now\n"
    end

    test "nil by default" do
      defmodule NoNotes do
        use InstructorLite.Instruction
      end

      assert NoNotes.notes() == nil
    end

    test "overridable" do
      defmodule Foo do
        use InstructorLite.Instruction

        @impl InstructorLite.Instruction
        def notes(), do: "Overriden!"
      end

      assert Foo.notes() == "Overriden!"
    end
  end

  describe "json_schema/0" do
    alias InstructorLite.JSONSchema

    test "defines by default" do
      defmodule Demo do
        use Ecto.Schema
        use InstructorLite.Instruction

        @primary_key false
        schema "demo" do
          field(:string, :string)
        end
      end

      assert JSONSchema.from_ecto_schema(Demo) == Demo.json_schema()
    end

    test "overridable" do
      defmodule OverridableJsonSchema do
        use Ecto.Schema
        use InstructorLite.Instruction

        def json_schema(), do: "I know better"
      end

      assert OverridableJsonSchema.json_schema() == "I know better"
    end

    test "can use super" do
      defmodule CallSuper do
        use Ecto.Schema
        use InstructorLite.Instruction

        @primary_key false
        schema "demo" do
          field(:string, :string)
        end

        def json_schema(), do: super()[:type]
      end

      assert "object" = CallSuper.json_schema()
    end
  end
end

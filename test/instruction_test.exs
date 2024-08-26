defmodule Instructor.InstructionTest do
  use ExUnit.Case, async: true

  describe "notes/0" do
    defmodule ShapeFactory do
      use Ecto.Schema
      use Instructor.Instruction

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
      defmodule Foo do
        use Instructor.Instruction
      end

      assert Foo.notes() == nil
    end

    test "overridable" do
      defmodule Foo do
        use Instructor.Instruction

        def notes(), do: "Overriden!"
      end

      assert Foo.notes() == "Overriden!"
    end
  end
end

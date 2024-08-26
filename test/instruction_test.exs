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

  describe "json_schema/0" do
    alias Instructor.JSONSchema

    test "defines by default" do
      defmodule Demo do
        use Ecto.Schema
        use Instructor.Instruction

        @primary_key false
        schema "demo" do
          field(:string, :string)
        end
      end

      assert JSONSchema.from_ecto_schema(Demo) == Demo.json_schema()
    end

    test "overridable" do
      defmodule Demo do
        use Ecto.Schema
        use Instructor.Instruction

        def json_schema(), do: "I know better"
      end

      assert Demo.json_schema() == "I know better"
    end

    test "can use super" do
      defmodule Demo do
        use Ecto.Schema
        use Instructor.Instruction

        @primary_key false
        schema "demo" do
          field(:string, :string)
        end

        def json_schema(), do: super()[:schema]
      end

      assert %{type: "object"} = Demo.json_schema()
    end
  end
end

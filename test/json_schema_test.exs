Code.compiler_options(ignore_module_conflict: true, docs: true, debug_info: true)

defmodule JSONSchemaTest do
  use ExUnit.Case, async: true

  alias Instructor.JSONSchema

  test "schema" do
    defmodule Demo do
      use Ecto.Schema

      @primary_key false
      schema "demo" do
        field(:string, :string)
      end
    end

    json_schema = JSONSchema.from_ecto_schema(JSONSchemaTest.Demo)

    expected_json_schema = %{
      name: "Demo",
      strict: true,
      schema: %{
        type: "object",
        description: "",
        title: "Demo",
        required: [:string],
        additionalProperties: false,
        properties: %{string: %{type: "string", title: "string"}}
      }
    }

    assert json_schema == expected_json_schema
  end

  test "embedded_schema" do
    defmodule Demo do
      use Ecto.Schema

      @primary_key false
      embedded_schema do
        field(:string, :string)
      end
    end

    json_schema = JSONSchema.from_ecto_schema(Demo)

    expected_json_schema = %{
      name: "Demo",
      strict: true,
      schema: %{
        description: "",
        required: [:string],
        title: "Demo",
        type: "object",
        additionalProperties: false,
        properties: %{string: %{type: "string", title: "string"}}
      }
    }

    assert json_schema == expected_json_schema
  end

  @tag skip: true
  test "includes documentation" do
    json_schema = JSONSchema.from_ecto_schema(InstructorTest.DemoWithDocumentation)

    expected_json_schema = %{
      name: "DemoWithDocumentation",
      strict: true,
      schema: %{
        description: "Hello World\n",
        required: [:string],
        title: "DemoWithDocumentation",
        type: "object",
        additionalProperties: false,
        properties: %{string: %{type: "string", title: "string"}}
      }
    }

    assert json_schema == expected_json_schema
  end

  test "basic types" do
    defmodule Demo do
      use Ecto.Schema

      # Be explicit about all fields in this test
      @primary_key false
      embedded_schema do
        # field(:binary_id, :binary_id)
        field(:integer, :integer)
        field(:float, :float)
        field(:boolean, :boolean)
        field(:string, :string)
        # field(:binary, :binary)
        field(:array, {:array, :string})
        # field(:map, :map)
        # field(:map_two, {:map, :string})
        field(:decimal, :decimal)
        field(:date, :date)
        field(:time, :time)
        field(:time_usec, :time_usec)
        field(:naive_datetime, :naive_datetime)
        field(:naive_datetime_usec, :naive_datetime_usec)
        field(:utc_datetime, :utc_datetime)
        field(:utc_datetime_usec, :utc_datetime_usec)
      end
    end

    json_schema = JSONSchema.from_ecto_schema(Demo)

    expected_json_schema = %{
      name: "Demo",
      schema: %{
        type: "object",
        description: "",
        title: "Demo",
        required: [
          :array,
          :boolean,
          :date,
          :decimal,
          :float,
          :integer,
          :naive_datetime,
          :naive_datetime_usec,
          :string,
          :time,
          :time_usec,
          :utc_datetime,
          :utc_datetime_usec
        ],
        additionalProperties: false,
        properties: %{
          integer: %{type: "integer", title: "integer"},
          date: %{type: "string", title: "date"},
          float: %{type: "number", title: "float"},
          time: %{type: "string", title: "time"},
          string: %{type: "string", title: "string"},
          # map: %{type: "object", title: "map", additionalProperties: %{}},
          boolean: %{type: "boolean", title: "boolean"},
          array: %{type: "array", title: "array", items: %{type: "string"}},
          decimal: %{type: "number", title: "decimal"},
          # map_two: %{type: "object", title: "map_two", additionalProperties: %{type: "string"}},
          time_usec: %{type: "string", title: "time_usec"},
          naive_datetime: %{type: "string", title: "naive_datetime"},
          naive_datetime_usec: %{type: "string", title: "naive_datetime_usec"},
          utc_datetime: %{type: "string", title: "utc_datetime"},
          utc_datetime_usec: %{type: "string", title: "utc_datetime_usec"}
        }
      },
      strict: true
    }

    assert json_schema == expected_json_schema
  end

  test "embedded schemas" do
    defmodule Embedded do
      use Ecto.Schema

      @primary_key false
      embedded_schema do
        field(:string, :string)
      end
    end

    defmodule Demo do
      use Ecto.Schema

      @primary_key false
      embedded_schema do
        embeds_one(:embedded, Embedded)
      end
    end

    json_schema = JSONSchema.from_ecto_schema(Demo)

    expected_json_schema = %{
      name: "Demo",
      schema: %{
        additionalProperties: false,
        description: "",
        properties: %{embedded: %{title: "embedded", "$ref": "#/$defs/Embedded"}},
        required: [:embedded],
        title: "Demo",
        type: "object"
      },
      strict: true,
      "$defs": %{
        "Embedded" => %{
          type: "object",
          description: "",
          title: "Embedded",
          required: [:string],
          additionalProperties: false,
          properties: %{string: %{type: "string", title: "string"}}
        }
      }
    }

    assert json_schema == expected_json_schema
  end

  test "has_one" do
    defmodule Child do
      use Ecto.Schema

      schema "child" do
        field(:string, :string)
      end
    end

    defmodule Demo do
      use Ecto.Schema

      schema "demo" do
        has_one(:child, Child)
      end
    end

    json_schema = JSONSchema.from_ecto_schema(Demo)

    expected_json_schema = %{
      "$defs": %{
        "Child" => %{
          type: "object",
          description: "",
          title: "Child",
          required: [:id, :string],
          additionalProperties: false,
          properties: %{
            id: %{type: "integer", title: "id"},
            string: %{type: "string", title: "string"}
          }
        }
      },
      name: "Demo",
      schema: %{
        type: "object",
        description: "",
        title: "Demo",
        required: [:child, :id],
        additionalProperties: false,
        properties: %{id: %{type: "integer", title: "id"}, child: %{"$ref": "#/$defs/Child"}}
      },
      strict: true
    }

    assert json_schema == expected_json_schema
  end

  test "has_many" do
    defmodule Child do
      use Ecto.Schema

      schema "child" do
        field(:string, :string)
      end
    end

    defmodule Demo do
      use Ecto.Schema

      schema "demo" do
        has_many(:children, Child)
      end
    end

    json_schema = JSONSchema.from_ecto_schema(Demo)

    expected_json_schema = %{
      "$defs": %{
        "Child" => %{
          type: "object",
          description: "",
          title: "Child",
          required: [:id, :string],
          additionalProperties: false,
          properties: %{
            id: %{type: "integer", title: "id"},
            string: %{type: "string", title: "string"}
          }
        }
      },
      name: "Demo",
      schema: %{
        type: "object",
        description: "",
        title: "Demo",
        required: [:children, :id],
        additionalProperties: false,
        properties: %{
          id: %{type: "integer", title: "id"},
          children: %{type: "array", title: "Child", items: %{"$ref": "#/$defs/Child"}}
        }
      },
      strict: true
    }

    assert json_schema == expected_json_schema
  end

  test "handles ecto types with embeds recursively" do
    schema = %{
      value:
        Ecto.ParameterizedType.init(Ecto.Embedded,
          cardinality: :one,
          related: %{
            name: :string,
            children:
              Ecto.ParameterizedType.init(Ecto.Embedded,
                cardinality: :many,
                related: %{name: :string}
              )
          }
        )
    }

    json_schema = JSONSchema.from_ecto_schema(schema)

    expected_json_schema = %{
      name: "root",
      schema: %{
        type: "object",
        title: "root",
        required: [:value],
        additionalProperties: false,
        properties: %{
          value: %{
            type: "object",
            required: [:children, :name],
            properties: %{
              name: %{type: "string"},
              children: %{
                type: "array",
                items: %{
                  type: "object",
                  required: [:name],
                  properties: %{name: %{type: "string"}}
                }
              }
            }
          }
        }
      },
      strict: true
    }

    assert json_schema == expected_json_schema
  end
end

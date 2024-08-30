defmodule JSONSchemaTest do
  use ExUnit.Case, async: true

  alias InstructorLite.JSONSchema
  alias InstructorLite.TestSchemas

  test "schema" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.Child)

    expected_json_schema = %{
      type: "object",
      description: "",
      title: "Child",
      required: [:id, :name],
      additionalProperties: false,
      properties: %{
        name: %{type: "string"},
        id: %{type: "integer"}
      }
    }

    assert json_schema == expected_json_schema
  end

  test "embedded_schema" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.Embedded)

    expected_json_schema = %{
      description: "",
      required: [:name],
      title: "Embedded",
      type: "object",
      additionalProperties: false,
      properties: %{name: %{type: "string"}}
    }

    assert json_schema == expected_json_schema
  end

  test "basic types" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.AllEctoTypes)

    expected_json_schema = %{
      type: "object",
      description: "",
      title: "AllEctoTypes",
      required: [
        :array,
        :binary_id,
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
        binary_id: %{type: "string"},
        integer: %{type: "integer"},
        date: %{type: "string"},
        float: %{type: "number"},
        time: %{type: "string"},
        string: %{type: "string"},
        # map: %{type: "object", additionalProperties: %{}},
        boolean: %{type: "boolean"},
        array: %{type: "array", items: %{type: "string"}},
        decimal: %{type: "number"},
        # map_two: %{type: "object", additionalProperties: %{type: "string"}},
        time_usec: %{type: "string"},
        naive_datetime: %{type: "string"},
        naive_datetime_usec: %{type: "string"},
        utc_datetime: %{type: "string"},
        utc_datetime_usec: %{type: "string"}
      }
    }

    assert json_schema == expected_json_schema
  end

  test "embedded schemas" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.WithEmbedded)

    expected_json_schema = %{
      additionalProperties: false,
      description: "",
      properties: %{embedded: %{"$ref": "#/$defs/Embedded"}},
      required: [:embedded],
      title: "WithEmbedded",
      type: "object",
      "$defs": %{
        "Embedded" => %{
          type: "object",
          description: "",
          title: "Embedded",
          required: [:name],
          additionalProperties: false,
          properties: %{
            name: %{type: "string"}
          }
        }
      }
    }

    assert json_schema == expected_json_schema
  end

  test "has_one" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.WithChild)

    expected_json_schema = %{
      "$defs": %{
        "Child" => %{
          type: "object",
          description: "",
          title: "Child",
          required: [:id, :name],
          additionalProperties: false,
          properties: %{
            id: %{type: "integer"},
            name: %{type: "string"}
          }
        }
      },
      type: "object",
      description: "",
      title: "WithChild",
      required: [:child, :id],
      additionalProperties: false,
      properties: %{id: %{type: "integer"}, child: %{"$ref": "#/$defs/Child"}}
    }

    assert json_schema == expected_json_schema
  end

  test "has_many" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.WithChildren)

    expected_json_schema = %{
      "$defs": %{
        "Child" => %{
          type: "object",
          description: "",
          title: "Child",
          required: [:id, :name],
          additionalProperties: false,
          properties: %{
            id: %{type: "integer"},
            name: %{type: "string"}
          }
        }
      },
      type: "object",
      description: "",
      title: "WithChildren",
      required: [:children, :id],
      additionalProperties: false,
      properties: %{
        id: %{type: "integer"},
        children: %{type: "array", items: %{"$ref": "#/$defs/Child"}}
      }
    }

    assert json_schema == expected_json_schema
  end

  test "enum" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.SpamPrediction)

    expected_json_schema = %{
      type: "object",
      description: "",
      title: "SpamPrediction",
      required: [:class, :score],
      additionalProperties: false,
      properties: %{
        class: %{type: "string", enum: [:spam, :not_spam]},
        score: %{type: "number"}
      }
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
    }

    assert json_schema == expected_json_schema
  end

  test "recursive schema" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.LinkedList)

    expected_json_schema = %{
      type: "object",
      title: "LinkedList",
      required: [:next, :value],
      description: "",
      additionalProperties: false,
      properties: %{
        value: %{type: "integer"},
        next: %{"$ref": "#/$defs/LinkedList"}
      },
      "$defs": %{
        "LinkedList" => %{
          type: "object",
          description: "",
          title: "LinkedList",
          required: [:next, :value],
          additionalProperties: false,
          properties: %{
            value: %{type: "integer"},
            next: %{"$ref": "#/$defs/LinkedList"}
          }
        }
      }
    }

    assert json_schema == expected_json_schema
  end
end

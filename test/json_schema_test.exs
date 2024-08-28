defmodule JSONSchemaTest do
  use ExUnit.Case, async: true

  alias Instructor.JSONSchema
  alias Instructor.TestSchemas

  test "schema" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.Child)

    expected_json_schema = %{
      name: "Child",
      strict: true,
      schema: %{
        type: "object",
        description: "",
        title: "Child",
        required: [:id, :name],
        additionalProperties: false,
        properties: %{
          name: %{type: "string", title: "name"},
          id: %{type: "integer", title: "id"}
        }
      }
    }

    assert json_schema == expected_json_schema
  end

  test "embedded_schema" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.Embedded)

    expected_json_schema = %{
      name: "Embedded",
      strict: true,
      schema: %{
        description: "",
        required: [:name],
        title: "Embedded",
        type: "object",
        additionalProperties: false,
        properties: %{name: %{type: "string", title: "name"}}
      }
    }

    assert json_schema == expected_json_schema
  end

  test "basic types" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.AllEctoTypes)

    expected_json_schema = %{
      name: "AllEctoTypes",
      schema: %{
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
          binary_id: %{type: "string", title: "binary_id"},
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
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.WithEmbedded)

    expected_json_schema = %{
      name: "WithEmbedded",
      schema: %{
        additionalProperties: false,
        description: "",
        properties: %{embedded: %{title: "embedded", "$ref": "#/$defs/Embedded"}},
        required: [:embedded],
        title: "WithEmbedded",
        type: "object"
      },
      strict: true,
      "$defs": %{
        "Embedded" => %{
          type: "object",
          description: "",
          title: "Embedded",
          required: [:name],
          additionalProperties: false,
          properties: %{
            name: %{type: "string", title: "name"}
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
            id: %{type: "integer", title: "id"},
            name: %{type: "string", title: "name"}
          }
        }
      },
      name: "WithChild",
      schema: %{
        type: "object",
        description: "",
        title: "WithChild",
        required: [:child, :id],
        additionalProperties: false,
        properties: %{id: %{type: "integer", title: "id"}, child: %{"$ref": "#/$defs/Child"}}
      },
      strict: true
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
            id: %{type: "integer", title: "id"},
            name: %{type: "string", title: "name"}
          }
        }
      },
      name: "WithChildren",
      schema: %{
        type: "object",
        description: "",
        title: "WithChildren",
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

  test "enum" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.SpamPrediction)

    expected_json_schema = %{
      name: "SpamPrediction",
      strict: true,
      schema: %{
        type: "object",
        description: "",
        title: "SpamPrediction",
        required: [:class, :score],
        additionalProperties: false,
        properties: %{
          class: %{type: "string", enum: [:spam, :not_spam], title: "class"},
          score: %{type: "number", title: "score"}
        }
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

  test "recursive schema" do
    json_schema = JSONSchema.from_ecto_schema(TestSchemas.LinkedList)

    expected_json_schema = %{
      name: "LinkedList",
      schema: %{
        type: "object",
        title: "LinkedList",
        required: [:next, :value],
        description: "",
        additionalProperties: false,
        properties: %{
          value: %{type: "integer", title: "value"},
          next: %{title: "next", "$ref": "#/$defs/LinkedList"}
        }
      },
      strict: true,
      "$defs": %{
        "LinkedList" => %{
          type: "object",
          description: "",
          title: "LinkedList",
          required: [:next, :value],
          additionalProperties: false,
          properties: %{
            value: %{type: "integer", title: "value"},
            next: %{title: "next", "$ref": "#/$defs/LinkedList"}
          }
        }
      }
    }

    assert json_schema == expected_json_schema
  end
end

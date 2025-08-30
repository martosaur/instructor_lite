defmodule InstructorLite.GeminiJSON do
  @moduledoc """
  Helper module to convert Ecto schemas to Gemini-compatible JSON schemas.
  
  Gemini's JSON schema format differs from standard JSON Schema in several ways:
  - Based on OpenAPI 3.0 schema subset
  - All fields in 'required' array must exist in properties
  - No support for union types or conditionals
  - Limited support for nested schemas
  
  ## Example
  
      iex> GeminiJSON.from_ecto_schema(UserInfo)
      %{
        type: "object",
        required: [:name, :age],
        properties: %{
          name: %{type: "string"},
          age: %{type: "integer"}
        }
      }
  """

  @doc """
  Converts an Ecto schema module to a Gemini-compatible JSON schema.
  
  Raises an error if the schema contains unsupported field types.
  """
  def from_ecto_schema(ecto_schema) when is_atom(ecto_schema) do
    unless function_exported?(ecto_schema, :__schema__, 1) do
      raise ArgumentError, """
      #{inspect(ecto_schema)} is not an Ecto schema module.
      Expected a module that uses Ecto.Schema.
      """
    end
    
    fields = ecto_schema.__schema__(:fields)
    
    properties = 
      Enum.reduce(fields, %{}, fn field, acc ->
        type = ecto_schema.__schema__(:type, field)
        Map.put(acc, field, convert_type(type, field))
      end)
    
    # Check for embeds (not yet supported)
    embeds = ecto_schema.__schema__(:embeds)
    if embeds != [] do
      raise ArgumentError, """
      Embedded schemas are not yet supported by GeminiJSON.
      Schema #{inspect(ecto_schema)} has embedded fields: #{inspect(embeds)}
      Please use flat schemas or implement custom json_schema/0 callback.
      """
    end
    
    # Check for associations (not supported)
    associations = ecto_schema.__schema__(:associations)
    if associations != [] do
      raise ArgumentError, """
      Associations are not supported by GeminiJSON.
      Schema #{inspect(ecto_schema)} has associations: #{inspect(associations)}
      Please use embedded schemas or implement custom json_schema/0 callback.
      """
    end
    
    %{
      type: "object",
      required: fields,
      properties: properties
    }
  end

  defp convert_type(type, field) do
    case type do
      :string -> 
        %{type: "string"}
        
      :integer -> 
        %{type: "integer"}
        
      :float -> 
        %{type: "number"}
        
      :boolean -> 
        %{type: "boolean"}
        
      :decimal -> 
        %{type: "number"}
        
      :date -> 
        %{type: "string"}
        
      :time -> 
        %{type: "string"}
        
      :time_usec -> 
        %{type: "string"}
        
      :naive_datetime -> 
        %{type: "string"}
        
      :naive_datetime_usec -> 
        %{type: "string"}
        
      :utc_datetime -> 
        %{type: "string"}
        
      :utc_datetime_usec -> 
        %{type: "string"}
        
      {:array, inner_type} ->
        %{
          type: "array",
          items: convert_type(inner_type, field)
        }
        
      :map ->
        %{
          type: "object",
          additionalProperties: %{}
        }
        
      {:map, value_type} ->
        %{
          type: "object",
          additionalProperties: convert_type(value_type, field)
        }
        
      {:parameterized, {Ecto.Enum, %{mappings: mappings}}} ->
        %{
          type: "string",
          enum: Keyword.keys(mappings)
        }
        
      {:parameterized, {Ecto.Embedded, _}} ->
        raise ArgumentError, """
        Embedded field '#{field}' is not yet supported by GeminiJSON.
        Gemini requires flat schemas or you need to implement custom json_schema/0 callback.
        
        Consider using a flat structure or manually defining the schema.
        """
        
      :id ->
        %{type: "integer"}
        
      :binary_id ->
        %{type: "string"}
        
      :binary ->
        %{type: "string"}
        
      other ->
        raise ArgumentError, """
        Unsupported field type for '#{field}': #{inspect(other)}
        
        GeminiJSON currently supports:
        - Basic types: :string, :integer, :float, :boolean
        - Date/time types: :date, :time, :naive_datetime, :utc_datetime
        - Other types: :decimal, :map, {:array, type}, Ecto.Enum
        
        For custom types, implement the json_schema/0 callback in your schema module.
        """
    end
  end
  
  @doc """
  Convenience function to be used inline in the demo or other code.
  
  ## Example
  
      InstructorLite.instruct(
        params,
        response_model: UserInfo,
        json_schema: GeminiJSON.schema(UserInfo),
        adapter: InstructorLite.Adapters.Gemini,
        adapter_context: config
      )
  """
  def schema(ecto_schema) do
    from_ecto_schema(ecto_schema)
  end
end
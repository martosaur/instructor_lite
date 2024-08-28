defmodule Instructor.TestSchemas do
  defmodule SpamPrediction do
    use Ecto.Schema
    use Instructor.Instruction

    @primary_key false
    embedded_schema do
      field(:class, Ecto.Enum, values: [:spam, :not_spam])
      field(:score, :float)
    end
  end

  defmodule AllEctoTypes do
    use Ecto.Schema
    use Instructor.Instruction

    @primary_key false
    embedded_schema do
      field(:binary_id, :binary_id)
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

  defmodule Embedded do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field(:name, :string)
    end
  end

  defmodule WithEmbedded do
    use Ecto.Schema
    use Instructor.Instruction

    @primary_key false
    embedded_schema do
      embeds_one(:embedded, Embedded)
    end
  end

  defmodule Child do
    use Ecto.Schema

    schema "child" do
      field(:name, :string)
    end
  end

  defmodule WithChild do
    use Ecto.Schema
    use Instructor.Instruction

    schema "with_child" do
      has_one(:child, Child)
    end
  end

  defmodule WithChildren do
    use Ecto.Schema
    use Instructor.Instruction

    schema "with_children" do
      has_many(:children, Child)
    end
  end

  defmodule LinkedList do
    use Ecto.Schema
    use Instructor.Instruction

    @primary_key false
    embedded_schema do
      field(:value, :integer)
      embeds_one(:next, LinkedList)
    end
  end
end

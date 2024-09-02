# Migrating from Instructor

`InstructorLite` is not meant as a drop-in replacement for `Instructor`, so there are a number of things to consider when making a decision to switch.

✅ You might want to switch if:
* You need more customization (e.g. using `Tesla` instead of `Req`)
* You want to have fine-grained control over side-effects (e.g. delay executing requests to use [Batch API](https://platform.openai.com/docs/guides/batch))
* You plan to tinker with the library's source code or write your own adapters

❌ You might not want to switch if:
* Instructor already works for you and you want things to continue to "just work"
* You need streaming capabilities

## Migrating Schemas

Instructor works with any Ecto schema and optionally allows you to use `Instructor.Validator` behaviour for the `Instructor.Validator.validate_changeset/2` callback.

InstructorLite can also work with any Ecto schema, but it doesn't use the `@doc` attribute for semantic description. Instead, you can `use InstructorLite.Instruction` and define the `@notes` attribute. The `c:InstructorLite.Instruction.validate_changeset/2` callback is still here, but it's always of 2 arity.

As a result, you don't have to add a docstring in your release.

<!-- tabs-open -->

### Instructor

```elixir
defmodule SpamPrediction do
  use Ecto.Schema
  use Instructor.Validator

  @doc """
  ## Field Descriptions:
  - class: Whether or not the email is spam.
  - reason: A short, less than 10 word rationalization for the classification.
  - score: A confidence score between 0.0 and 1.0 for the classification.
  """
  @primary_key false
  embedded_schema do
    field(:class, Ecto.Enum, values: [:spam, :not_spam])
    field(:reason, :string)
    field(:score, :float)
  end

  @impl true
  def validate_changeset(changeset) do
    changeset
    |> Ecto.Changeset.validate_number(:score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
  end
end
```

```elixir
# mix.exs
def project do
  # ...
  releases: [
    myapp: [
      strip_beams: [keep: ["Docs"]]
    ]
  ]
end
```

### InstructorLite

```elixir
defmodule SpamPrediction do
  use Ecto.Schema
  use InstructorLite.Instruction

  @notes """
  ## Field Descriptions:
  - class: Whether or not the email is spam.
  - reason: A short, less than 10 word rationalization for the classification.
  - score: A confidence score between 0.0 and 1.0 for the classification.
  """
  @primary_key false
  embedded_schema do
    field(:class, Ecto.Enum, values: [:spam, :not_spam])
    field(:reason, :string)
    field(:score, :float)
  end

  @impl InstructorLite.Instruction
  def validate_changeset(changeset, _opts) do
    changeset
    |> Ecto.Changeset.validate_number(:score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
  end
end
```

<!-- tabs-close -->

## Migrating `Instructor.chat_completions/2`

`Instructor.chat_completion/2` works primarily with `params`, but also accepts an optional `config` as the second argument. Some parameters are passed to the LLM and some control Instructor's own behaviour.

The InstructorLite equivalent function is `InstructorLite.instruct/2`. It also accepts `params` as the first argument, but many params were moved to the second `opts` argument. Read more about this in [Key Concepts](`m:InstructorLite#key-concepts`). 

In addition, InstructorLite does not access application configuration, so API keys are typically passed through `opts`.


<!-- tabs-open -->

### Instructor

```elixir
Instructor.chat_completion(%{
  model: "gpt-3.5-turbo",
  response_model: SpamPrediction,
  messages: [
    %{
      role: "user",
      content: "Classify the following text: Hello, I am a Nigerian prince and I would like to give you $1,000,000."
    }
  ]
})
{:ok, %SpamPrediction{class: :spam, score: 0.999}}
```

```elixir
# config.exs
config :instructor, 
  adapter: Instructor.Adapters.OpenAI,
  openai: [api_key: "my_secret_key"]
```

### InstructorLite

```elixir
InstructorLite.instruct(%{
    messages: [
      %{
        role: "user",
        content: "Classify the following text: Hello, I am a Nigerian prince and I would like to give you $1,000,000."
      }
    ],
    model: "gpt-3.5-turbo"
  },
  response_model: Instructor.Demos.SpamPrediction,
  adapter: InstructorLite.Adapters.OpenAI,
  adapter_context: [api_key: "my_secret_key"]
})
{:ok, %SpamPrediction{class: :spam, score: 0.999}}
```

<!-- tabs-close -->

## Migrating Custom Ecto Types

`Instructor.EctoType` allows you to define a way to dump a custom Ecto type to JSON schema using the `Instructor.EctoType.to_json_schema/0` callback.

InstructorLite lowers the bar for the built-in Ecto-to-JSON-schema converter. It only works for basic Ecto types and may not be compatible with all LLMs. As soon as basic JSON schema is not enough for you, you should define the schema manually using the `c:InstructorLite.Instruction.json_schema/0` callback.


<!-- tabs-open -->

### Instructor

```elixir
defmodule Ecto.CSVDataFrame do
  use Ecto.Type
  use Instructor.EctoType

  def type, do: :string

  def cast(csv_str) when is_binary(csv_str) do
    df = Explorer.DataFrame.load_csv!(csv_str)
    {:ok, df}
  end

  def cast(%Explorer.DataFrame{} = df), do: {:ok, df}
  def cast(_), do: :error

  def to_json_schema(),
    do: %{
      type: "string",
      description: "A CSV representation of a data table"
    }

  def dump(x), do: {:ok, x}
  def load(x), do: {:ok, x}
end
```

```elixir
defmodule Database do
  use Ecto.Schema
  use Instructor.Validator

  @doc """
  The extracted database will contain one or more tables with data as csv formatted with ',' delimiters
  """
  @primary_key false
  embedded_schema do
    embeds_many :tables, DataFrame, primary_key: false do
      field(:name, :string)
      field(:data, Ecto.CSVDataFrame)
    end
  end
end
```

### InstructorLite

```elixir
defmodule Ecto.CSVDataFrame do
  use Ecto.Type

  def type, do: :string

  def cast(csv_str) when is_binary(csv_str) do
    df = Explorer.DataFrame.load_csv!(csv_str)
    {:ok, df}
  end

  def cast(%Explorer.DataFrame{} = df), do: {:ok, df}
  def cast(_), do: :error

  def dump(x), do: {:ok, x}
  def load(x), do: {:ok, x}
end
```

```elixir
defmodule Database do
  use Ecto.Schema
  use InstructorLite.Instruction

  @notes """
  The extracted database will contain one or more tables with data as csv formatted with ',' delimiters
  """
  @primary_key false
  embedded_schema do
    embeds_many :tables, DataFrame, primary_key: false do
      field(:name, :string)
      field(:data, Ecto.CSVDataFrame)
    end
  end
  
  @impl InstructorLite.Instruction
  def json_schema do
    %{
      type: "object",
      description: "",
      title: "Database",
      required: [:tables],
      "$defs": %{
        "DataFrame" => %{
          type: "object",
          description: "",
          title: "DataFrame",
          required: [:data, :name],
          properties: %{data: %{type: "string"}, name: %{type: "string"}},
          additionalProperties: false
        }
      },
      properties: %{tables: %{type: "array", items: %{"$ref": "#/$defs/DataFrame"}}},
      additionalProperties: false
    }
  end
end
```

<!-- tabs-close -->

## Migrating `Instructor.validate_with_llm/2`

`Instructor.Validator.validate_with_llm/2` is a nifty function that allows you to use LLM to validate your changeset.

InstructorLite doesn't have this function. Instead, you can write your own thin helper function.

<!-- tabs-open -->

### Instructor

```elixir
defmodule QuestionAnswer do
  use Ecto.Schema
  use Instructor.Validator

  @primary_key false
  embedded_schema do
    field(:question, :string)
    field(:answer, :string)
  end

  @impl true
  def validate_changeset(changeset) do
    changeset
    |> validate_with_llm(:answer, "Do not say anything objectionable")
  end
end
```

```elixir
%QuestionAnswer{}
|> Instructor.cast_all(%{
  question: "What is the meaning of life?",
  answer: "Sex, drugs, and rock'n roll"
})
|> QuestionAnswer.validate_changeset()

#Ecto.Changeset<
  action: nil,
  changes: %{question: "What is the meaning of life?", answer: "Sex, drugs, and rock'n roll"},
  errors: [answer: {"is invalid, Do not say anything objectionable", []}],
  data: #QuestionAnswer<>,
  valid?: false
>
```

### InstructorLite

```elixir
defmodule QuestionAnswer do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :question, :string
    field :answer, :string
  end

  def changeset(data, params) do
    data
    |> Ecto.Changeset.cast(params, [:answer])
    |> validate_with_llm(:answer, "do not say anything objectionable")
  end

  def validate_with_llm(changeset, field, rule) do
    Ecto.Changeset.validate_change(changeset, field, fn ^field, value ->
      %{
        messages: [
          %{
            role: "system",
            content: """
            You are a world-class validation model. Capable of determining if the following value is valid for the statement, if it is not, explain why.
            """
          },
          %{
            role: "user",
            content: "Does `#{value}` follow the rule: #{rule}"
          }
        ]
      }
      |> InstructorLite.instruct(
        response_model: %{valid?: :boolean, reason: :string},
        adapter_context: [api_key: "my_api_token"]
      )
      |> case do
        {:ok, %{valid?: false, reason: reason}} ->
          [{field, reason}]

        _ -> []
      end
    end)
  end
end
```

```elixir
%QuestionAnswer{question: "What is the meaning of life?"}
|> QuestionAnswer.changeset(%{answer: "Sex, drugs, and rock'n roll"})

#Ecto.Changeset<
  action: nil,
  changes: %{answer: "Sex, drugs, and rock'n roll"},
  errors: [
    answer: {"The phrase 'Sex, drugs, and rock'n roll' contains references to explicit content, substance use, and a lifestyle that may be considered objectionable or inappropriate by many standards.",
     []}
  ],
  data: #QuestionAnswer<>,
  valid?: false,
  ...
>
```

<!-- tabs-close -->

## Migrating Llamacpp Usage

Instructor's Llamacpp was implemented through converting JSON schema to GBNF grammar.

InstructorLite offers a very basic LLamacpp adapter which passes JSON schema to the Llamacpp server. If you want to use Llamacpp with InstructorLite, you will likely need to learn how your model of choice works and write your own adapter. InstructorLite can offer you a flexible enough chassis to build upon, but doesn't have much expertise to share 🫡.

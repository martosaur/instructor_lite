# InstructorLite

[![Instructor version](https://img.shields.io/hexpm/v/instructor_lite.svg)](https://hex.pm/packages/instructor_lite)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/instructor_lite/)
[![Hex Downloads](https://img.shields.io/hexpm/dt/instructor_lite)](https://hex.pm/packages/instructor_lite)
[![GitHub stars](https://img.shields.io/github/stars/martosaur/instructor_lite.svg)](https://github.com/martosaur/instructor_lite/stargazers)
[![CI](https://github.com/martosaur/instructor_lite/actions/workflows/ci.yml/badge.svg)](https://github.com/martosaur/instructor_lite/actions/workflows/ci.yml)

Structured prompting for LLMs. InstructorLite is a fork and spiritual successor to [instructor_ex](https://github.com/thmsmlr/instructor_ex) library, which is the Elixir member of the great [Instructor](https://useinstructor.com/) family.
 
The Instructor is useful for coaxing an LLM to return JSON that maps to an Ecto schema that you provide, rather than the default unstructured text output. If you define your own validation logic, Instructor can automatically retry prompts when validation fails (returning natural language error messages to the LLM, to guide it when making corrections).


## Why Lite

InstructorLite is designed to be:
1. **Lean**. It does so little it makes you question if you should just write your own version!
2. **Composable**. Almost everything it does can be overridden or extended.
3. **Magic-free**. It doesn't hide complexity behind one line function calls, but does its best to provide you with enough information to understand what's going on.

InstructorLite is tested to be compatible with the following providers:
[OpenAI](https://openai.com/api/), [Anthropic](https://www.anthropic.com/),
[Gemini](https://ai.google.dev/), [Grok](https://x.ai/) and
[Llamacpp](https://github.com/ggerganov/llama.cpp). 

## Features

InstructorLite can be boiled down to these features:
1. It provides a very simple function for generating JSON-schema from Ecto schema.
2. It facilitates generating prompts, calling LLMs, casting and validating responses, including retrying prompts when validation fails.
3. It holds knowledge of major LLM providers' API interfaces with adapters.

Any of the features above can be used independently.

## Usage

Define an instruction, which is a normal Ecto schema with an extra `use Instructor.Instruction` call.

```elixir
defmodule UserInfo do
  use Ecto.Schema
  use InstructorLite.Instruction
  
  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:age, :integer)
  end
end
```

Now let's use `InstructorLite.instruct/2` to fill the schema from unstructured text:

<!-- tabs-open -->

### OpenAI

```elixir
iex> InstructorLite.instruct(%{
    input: [
      %{role: "user", content: "John Doe is fourty two years old"}
    ]
  },
  response_model: UserInfo,
  adapter_context: [api_key: Application.fetch_env!(:instructor_lite, :openai_key)]
)
{:ok, %UserInfo{name: "John Doe", age: 42}}
```

### Anthropic

```elixir
iex> InstructorLite.instruct(%{
    messages: [
      %{role: "user", content: "John Doe is fourty two years old"}
    ]
  },
  response_model: UserInfo,
  adapter: InstructorLite.Adapters.Anthropic,
  adapter_context: [api_key: Application.fetch_env!(:instructor_lite, :anthropic_key)]
)
{:ok, %UserInfo{name: "John Doe", age: 42}}
```

### Llamacpp

```elixir
iex> InstructorLite.instruct(%{
    prompt: "John Doe is fourty two years old"
  },
  response_model: UserInfo,
  adapter: InstructorLite.Adapters.Llamacpp,
  adapter_context: [url: Application.fetch_env!(:instructor_lite, :llamacpp_url)]
)
{:ok, %UserInfo{name: "John Doe", age: 42}}
```

### Gemini

```elixir
iex> InstructorLite.instruct(%{
    contents: [
      %{
        role: "user",
        parts: [%{text: "John Doe is fourty two years old"}]
      }
    ]
  },
  response_model: UserInfo,
  json_schema: %{
    type: "object",
    required: [:age, :name],
    properties: %{name: %{type: "string"}, age: %{type: "integer"}},
  },
  adapter: InstructorLite.Adapters.Gemini,
  adapter_context: [
    api_key: Application.fetch_env!(:instructor_lite, :gemini_key)
  ]
)
{:ok, %UserInfo{name: "John Doe", age: 42}}
```

### Grok

Grok API is compatible with OpenAI Chat Completions endpoint, so all we can use
`ChatCompletionsCompatible` adapter with grok's `url` and `model_name`

```elixir
iex> InstructorLite.instruct(%{
    model: "grok-3-latest",
    messages: [
      %{role: "user", content: "John Doe is fourty two years old"}
    ]
  },
  response_model: UserInfo,
  adapter: InstructorLite.Adapters.ChatCompletionsCompatible,
  adapter_context: [
    url: "https://api.x.ai/v1/chat/completions",
    api_key: Application.fetch_env!(:instructor_lite, :grok_key)
  ]
)
{:ok, %UserInfo{name: "John Doe", age: 42}}
```

<!-- tabs-close -->

## Configuration

InstructorLite _does not_ access the application environment for configuration options like adapter or api key. Instead, they're passed as options when needed. Note that different adapters may require different options, so make sure to check their documentation. 


## Installation

In your mix.exs, add `:instructor_lite` to your list of dependencies:

```elixir
def deps do
  [
    {:instructor_lite, "~> 0.3.0"}
  ]
end
```

Optionally, include `Req` HTTP client (used by default) and Jason (for Elixir older than 1.18):

```elixir
def deps do
  [
    {:req, "~> 0.5 or ~> 1.0"},
    {:jason, "~> 1.4"}
  ]
end
```


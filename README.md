# Instructor Lite

_Structured, Ecto outputs with LLMs_

---

[![Instructor version](https://img.shields.io/hexpm/v/instructor.svg)](https://hex.pm/packages/instructor)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/instructor/)
[![Hex Downloads](https://img.shields.io/hexpm/dt/instructor)](https://hex.pm/packages/instructor)
[![GitHub stars](https://img.shields.io/github/stars/martosaur/instructor_ex.svg)](https://github.com/martosaur/instructor_ex/stargazers)
[![Twitter Follow](https://img.shields.io/twitter/follow/distantprovince?style=social)](https://twitter.com/distantprovince)

<!-- Docs -->

Structured prompting for LLMs. Instructor Lite is a fork and spiritual successor to [instructor_ex](https://github.com/thmsmlr/instructor_ex) library, which is the Elixir member of the great [Instructor](https://useinstructor.com/) family.
 
The Instructor is useful for coaxing an LLM to return JSON that maps to an Ecto schema that you provide, rather than the default unstructured text output. If you define your own validation logic, Instructor can automatically retry prompts when validation fails (returning natural language error messages to the LLM, to guide it when making corrections).


## Why Lite

Instructor Lite is designed to be:
1. **Lean**. It does so little it makes you question if you should just write your own version.
2. **Composable**. Almost everything it does can be overridden or extended.
3. **Magic-free**. It doesn't hide complexity behind one line function calls, but does its best to provide you with enough information to understand what's going on.

Instructor Lite comes with 3 adapters: [OpenAI](https://openai.com/api/), [Anthropic](https://www.anthropic.com/) and [Llamacpp](https://github.com/ggerganov/llama.cpp). 

## Features

Instructor Lite can be boiled down to these features:
1. It provides a very simple function for generating JSON-schema from Ecto schema.
2. It facilitates generating prompts, calling LLMs, casting and validating responses, including retrying prompts when validation fails.
3. It holds knowledge of major LLM providers' API interfaces with adapters.

Any of the features above can be used independently.

## Usage

Define an instruction, which is a normal Ecto schema with an extra `use Instructor.Instruction` call.

```elixir
defmodule UserInfo do
  use Ecto.Schema
  use Instructor.Instruction
  
  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:age, :integer)
  end
end
```

Now let's use `Instructor.completion/2` to fill the schema from unstructured text (with typos!):

<!-- tabs-open -->

### OpenAI

```elixir
iex> Instructor.chat_completion(%{
    messages: [
      %{role: "user", content: "John Doe is fourty two years old"}
    ]
  },
  response_model: UserInfo,
  adapter_context: [api_key: Application.fetch_env!(:instructor, :openai_key)]
)
{:ok, %UserInfo{name: "John Doe", age: 42}}
```

### Anthropic

```elixir
iex> Instructor.chat_completion(%{
    messages: [
      %{role: "user", content: "John Doe is fourty two years old"}
    ]
  },
  response_model: UserInfo,
  adapter: Instructor.Adapters.Anthropic,
  adapter_context: [api_key: Application.fetch_env!(:instructor, :anthropic_key)]
)
{:ok, %UserInfo{name: "John Doe", age: 42}}
```

### Llamacpp

```elixir
iex> Instructor.chat_completion(%{
    prompt: "John Doe is fourty two years old"
  },
  response_model: UserInfo,
  adapter: Instructor.Adapters.Llamacpp,
  adapter_context: [url: Application.fetch_env!(:instructor, :llamacpp_url)]
)
{:ok, %UserInfo{name: "John Doe", age: 42}}
```

<!-- tabs-close -->

## Configuration

Instructor Lite _does not_ access the application environment for configuration options like adapter or api key. Instead, they're passed as options when needed. Note that different adapters may require different options, so make sure to check their documentation. 


## Installation

In your mix.exs,

```elixir
def deps do
  [
    {:instructor, "~> 0.1.0"}
  ]
end
```

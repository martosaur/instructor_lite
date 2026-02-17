# InstructorLite

[![Instructor version](https://img.shields.io/hexpm/v/instructor_lite.svg)](https://hex.pm/packages/instructor_lite)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/instructor_lite/)
[![Hex Downloads](https://img.shields.io/hexpm/dt/instructor_lite)](https://hex.pm/packages/instructor_lite)
[![GitHub stars](https://img.shields.io/github/stars/martosaur/instructor_lite.svg)](https://github.com/martosaur/instructor_lite/stargazers)
[![CI](https://github.com/martosaur/instructor_lite/actions/workflows/ci.yml/badge.svg)](https://github.com/martosaur/instructor_lite/actions/workflows/ci.yml)
[![Discord](https://img.shields.io/discord/1471320781890785385?label=discord)](https://discord.gg/Kb9nszqzEy)

Structured prompting for LLMs. InstructorLite is a fork, spiritual successor and almost an entire rewrite of [instructor_ex](https://github.com/thmsmlr/instructor_ex) library.
 
InstructorLite provides basic building blocks to embed LLMs into your
application. It uses Ecto schemas to make sure LLM output has a predictable
shape and can play nicely with deterministic application logic. For an example
of what can be built with InstructorLite, check out
[Handwave](https://github.com/martosaur/handwave)


## Why Lite

InstructorLite is designed to be:
1. **Lean**. It does so little it makes you question if you should just write your own version!
2. **Composable**. Almost everything it does can be overridden or extended.
3. **Magic-free**. It doesn't hide complexity behind one line function calls, but does its best to provide you with enough information to understand what's going on.

InstructorLite is tested to be compatible with the following providers:
[OpenAI](https://openai.com/api/), [Anthropic](https://www.anthropic.com/),
[Gemini](https://ai.google.dev/) and any Chat Completions-compatible APIs, such as [Grok](https://x.ai/).

## Features

InstructorLite can be boiled down to these features:
1. It provides a very simple function for generating JSON schema from Ecto schema.
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
      %{role: "user", content: "John Doe is forty-two years old"}
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
      %{role: "user", content: "John Doe is forty-two years old"}
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
    prompt: "John Doe is forty-two years old"
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
        parts: [%{text: "John Doe is forty-two years old"}]
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

Grok API is compatible with OpenAI Chat Completions endpoint, so we can use
the `ChatCompletionsCompatible` adapter with Grok's `url` and `model_name`

```elixir
iex> InstructorLite.instruct(%{
    model: "grok-3-latest",
    messages: [
      %{role: "user", content: "John Doe is forty-two years old"}
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

InstructorLite _does not_ access the application environment for configuration options like adapter or API key. Instead, they're passed as options when needed. Note that different adapters may require different options, so make sure to check their documentation.

## Approach to development

InstructorLite is hand-written by a human and all external contributions are
vetted by a human. And said human is committed to keep it this way for
foreseeable future. This comes with both advantages and drawbacks. The library
may be prone to silly human errors and poor judgement, but at the same time it
is likely won't explode in complexity overnight or undergo a full rewrite every
couple of months. Tune your expectations accordingly! 

## Non-goals

InstructorLite very explicitly doesn't pursue the following goals:
1. Response streaming. Streaming is good UX for cases when LLM output is relayed
   to users, but doesn't make much sense for application environment, where
   structured outputs are usually used.
2. Unified interface. We acknowledge that LLM providers can be very different
   and trying to fit them under the same roof brings a ton of unnecessary
   complexity. Instead, InstructorLite aims to make it simple for developers to
   understand these differences and grapple with them.


## Installation

In your mix.exs, add `:instructor_lite` to your list of dependencies:

```elixir
def deps do
  [
    {:instructor_lite, "~> 1.2.0"}
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


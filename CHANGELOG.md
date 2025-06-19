# Changelog

## Unreleased

  * Require Elixir 1.15+

## v1.0.0
  * OpenAI adapter is changed to use the
  [Responses](https://platform.openai.com/docs/api-reference/responses) API.
  The chat completions-based adapter is still available as
  `InstructorLite.Adapters.ChatCompletionsCompatible`
  * `Jason` dependency is now optional
  * All adapters have been tested and verified for compatibility with reasoning models
  * Default prompts have been refined and standardized across adapters
  
### Migrating to 1.0.0
  1. If you use the `OpenAI` adapter and want to continue using the chat completions endpoint, switch to the `ChatCompletionsCompatible` adapter:
  ```diff
  InstructorLite.instruct(%{
      messages: [
        %{role: "user", content: "John Doe is fourty two years old"}
      ]
    },
    response_model: %{name: :string, age: :integer},
  -   adapter: InstructorLite.Adapters.OpenAI,
  +   adapter: InstructorLite.Adapters.ChatCompletionsCompatible,
    adapter_context: [api_key: Application.fetch_env!(:instructor_lite, :openai_key)]
  )
  ```
  2. If you use the `OpenAI` adapter and want to switch to the responses endpoint, update `params` to comply with the [`POST /v1/responses`](https://platform.openai.com/docs/api-reference/responses/create) interface. Most notably, the `messages` key should be `input`:
  ```diff
  InstructorLite.instruct(%{
  -    messages: [
  +    input: [
        %{role: "user", content: "John Doe is fourty two years old"}
      ]
    },
    response_model: %{name: :string, age: :integer},
    adapter: InstructorLite.Adapters.OpenAI,
    adapter_context: [api_key: Application.fetch_env!(:instructor_lite, :openai_key)]
  )
  ```

## v0.3.0

  * Add Gemini adapter

## v0.2.0
  
  * [OpenAI] Do not overwrite `response_format` params key if provided by the user
  * Fix `consume_response/3` enforcing all keys to present for ad-hoc Ecto schemas
  * Add Local Development Guide

## v0.1.0

  * Initial release
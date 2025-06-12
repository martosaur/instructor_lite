# Changelog

## Unreleased
  * OpenAI adapter is changed to use
  [Responses](https://platform.openai.com/docs/api-reference/responses) API.
  Chat completions-based adapter is still available as
  `InstructorLite.Adapters.ChatCompletionsCompatible`
  
### Migrating to Unreleased
  1. If you use `OpenAI` adapter and want to continue using chat completions endpoint, switch to `ChatCompletionsCompatible` adapter:
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
  1. If you use `OpenAI` adapter and want to switch to responses endpoint, update `params` to comply with [`POST /v1/responses`](https://platform.openai.com/docs/api-reference/responses/create) interface. Most notably, `messages` key should be `input`:
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
  
  * [OpenAI] Do not overwrite `response_format` params key if provided by user
  * Fix `consume_response/3` enforcing all keys to present for ad-hoc Ecto schemas
  * Add Local Development Guide

## v0.1.0

  * Initial release
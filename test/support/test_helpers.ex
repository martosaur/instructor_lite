defmodule Instructor.TestHelpers do
  import Mox

  def example_openai_response(:tools, result) do
    %{
      "id" => "chatcmpl-8e9AVo9NHfvBG5cdtAEiJMm7q4Htz",
      "usage" => %{
        "completion_tokens" => 23,
        "prompt_tokens" => 136,
        "total_tokens" => 159
      },
      "choices" => [
        %{
          "finish_reason" => "stop",
          "index" => 0,
          "logprobs" => nil,
          "message" => %{
            "content" => nil,
            "role" => "assistant",
            "tool_calls" => [
              %{
                "function" => %{
                  "arguments" => Jason.encode!(result),
                  "name" => "schema"
                },
                "id" => "call_DT9fBvVCHWGSf9IeFZnlarIY",
                "type" => "function"
              }
            ]
          }
        }
      ],
      "model" => "gpt-3.5-turbo-0613",
      "object" => "chat.completion",
      "created" => 1_704_579_055,
      "system_fingerprint" => nil
    }
  end

  def example_openai_response(mode, result) when mode in [:json, :md_json] do
    %{
      "id" => "chatcmpl-8e9AVo9NHfvBG5cdtAEiJMm7q4Htz",
      "usage" => %{
        "completion_tokens" => 23,
        "prompt_tokens" => 136,
        "total_tokens" => 159
      },
      "choices" => [
        %{
          "finish_reason" => "stop",
          "index" => 0,
          "logprobs" => nil,
          "message" => %{
            "content" => Jason.encode!(result),
            "role" => "assistant"
          }
        }
      ],
      "model" => "gpt-3.5-turbo-0613",
      "object" => "chat.completion",
      "created" => 1_704_579_055,
      "system_fingerprint" => nil
    }
  end

  def mock_openai_response(mode, result) do
    InstructorTest.MockOpenAI
    |> expect(:prompt, &Instructor.Adapters.OpenAI.prompt/1)
    |> expect(:chat_completion, fn _prompt, _params, _config ->
      {:ok, example_openai_response(mode, result)}
    end)
  end
end

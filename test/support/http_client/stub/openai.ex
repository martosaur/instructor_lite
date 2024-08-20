defmodule Instructor.HTTPClient.Stub.OpenAI do
  def post(_, _) do
    {:ok,
     %{
       status: 200,
       headers: %{
         "x-ratelimit-limit-requests" => ["5000"],
         "x-ratelimit-limit-tokens" => ["450000"],
         "x-ratelimit-remaining-requests" => ["4999"],
         "x-ratelimit-remaining-tokens" => ["449972"],
         "x-ratelimit-reset-requests" => ["12ms"],
         "x-ratelimit-reset-tokens" => ["3ms"],
         "x-request-id" => ["req_f8abce001380ace1a7728e823137552b"]
       },
       body: %{
         "choices" => [
           %{
             "finish_reason" => "stop",
             "index" => 0,
             "logprobs" => nil,
             "message" => %{
               "content" => nil,
               "refusal" => nil,
               "role" => "assistant",
               "tool_calls" => [
                 %{
                   "function" => %{
                     "arguments" =>
                       "{\"birth_date\":\"1732-02-22\",\"name\":\"George Washington\"}",
                     "name" => "Schema"
                   },
                   "id" => "call_KbTTBFKxnrrQEf4f65KNgG1W",
                   "type" => "function"
                 }
               ]
             }
           }
         ],
         "created" => 1_724_043_064,
         "id" => "chatcmpl-9xoe8grSYfxhkRjOmOgX8az3SG79a",
         "model" => "gpt-4o-2024-05-13",
         "object" => "chat.completion",
         "system_fingerprint" => "fp_3aa7262c27",
         "usage" => %{
           "completion_tokens" => 16,
           "prompt_tokens" => 83,
           "total_tokens" => 99
         }
       }
     }}
  end
end

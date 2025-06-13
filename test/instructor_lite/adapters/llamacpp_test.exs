defmodule InstructorLite.Adapters.LlamacppTest do
  use ExUnit.Case, async: true

  import Mox

  alias InstructorLite.Adapters.Llamacpp
  alias InstructorLite.HTTPClient

  setup :verify_on_exit!

  describe "initial_prompt/2" do
    test "adds structured response parameters" do
      assert Llamacpp.initial_prompt(%{}, json_schema: :json_schema, notes: "Explanation") == %{
               json_schema: :json_schema,
               system_prompt: """
               You're called by an Elixir application through the InstructorLite library. \
               Your task is to understand what the application wants you to do and respond with JSON output that matches the schema. \
               The output will be validated by the application against an Ecto schema and potentially some custom rules. \
               You may be asked to adjust your response if it doesn't pass validation. \
               Additional notes on the schema:
               Explanation
               """
             }
    end
  end

  describe "retry_prompt/5" do
    test "appends to prompt string" do
      params = %{prompt: "Please give me test data"}

      assert Llamacpp.retry_prompt(params, %{foo: "bar"}, "list of errors", nil, []) == %{
               prompt: """
               Please give me test data
               Your previous response:

               {\"foo\":\"bar\"}

               did not pass validation. Please try again and fix following validation errors:

               list of errors
               """
             }
    end
  end

  describe "parse_response/2" do
    test "decodes json from expected output" do
      response = %{
        "content" => "{\"name\": \"George Washington\", \"birth_date\": \"1732-02-22\" }\n"
      }

      assert {:ok, %{"birth_date" => "1732-02-22", "name" => "George Washington"}} =
               Llamacpp.parse_response(response, [])
    end

    test "invalid json" do
      response = %{"content" => "{{"}

      assert {:error, _} = Llamacpp.parse_response(response, [])
    end

    test "unexpected content" do
      response = "Internal Server Error"

      assert {:error, :unexpected_response, "Internal Server Error"} =
               Llamacpp.parse_response(response, [])
    end
  end

  describe "send_request/2" do
    test "overridable options" do
      params = %{hello: "world"}

      opts = [
        adapter_context: [
          http_client: HTTPClient.Mock,
          http_options: [foo: "bar"],
          url: "https://localhost:8001/completion"
        ]
      ]

      expect(HTTPClient.Mock, :post, fn url, options ->
        assert url == "https://localhost:8001/completion"

        assert options == [
                 foo: "bar",
                 json: %{hello: "world"}
               ]

        {:ok, %{status: 200, body: "response"}}
      end)

      assert {:ok, "response"} = Llamacpp.send_request(params, opts)
    end

    test "non-200 response" do
      opts = [
        adapter_context: [
          http_client: HTTPClient.Mock,
          url: "https://example.com"
        ]
      ]

      expect(HTTPClient.Mock, :post, fn _url, _options ->
        {:ok, %{status: 400, body: "response"}}
      end)

      assert {:error, %{status: 400, body: "response"}} = Llamacpp.send_request(%{}, opts)
    end

    test "request error" do
      opts = [
        adapter_context: [
          http_client: HTTPClient.Mock,
          url: "https://example.com"
        ]
      ]

      expect(HTTPClient.Mock, :post, fn _url, _options -> {:error, :timeout} end)

      assert {:error, :timeout} = Llamacpp.send_request(%{}, opts)
    end
  end
end

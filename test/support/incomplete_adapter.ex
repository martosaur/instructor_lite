defmodule IncompleteAdapter do
  @behaviour InstructorLite.Adapter

  @impl true
  def send_request(_params, _opts), do: {:error, :not_implemented}

  @impl true
  def initial_prompt(params, _opts), do: params

  @impl true
  def retry_prompt(params, _parsed_response, _errors, _response, _opts), do: params

  @impl true
  def parse_response(_response, _opts), do: {:error, :not_implemented}
end

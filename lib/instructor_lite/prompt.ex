defmodule InstructorLite.Prompt do
  @moduledoc false

  @doc "Returns default prompt used by InstructorLite"
  @spec default() :: String.t()
  def default() do
    """
    You're called by an Elixir application through the InstructorLite library. \
    Your task is to understand what the application wants you to do and respond with JSON output that matches the schema. \
    The output will be validated by the application against an Ecto schema and potentially some custom rules. \
    You may be asked to adjust your response if it doesn't pass validation. \
    """
  end

  @spec prompt(InstructorLite.opts()) :: String.t()
  def prompt(opts) do
    if notes = opts[:notes] do
      default() <>
        """
        Additional notes on the schema:
        #{notes}
        """
    else
      default()
    end
  end

  @spec validation_failed(String.t()) :: String.t()
  def validation_failed(errors) do
    """
    The response did not pass validation. Please try again and fix the following validation errors:

    #{errors}
    """
  end
end

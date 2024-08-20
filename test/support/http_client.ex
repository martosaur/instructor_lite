defmodule Instructor.HTTPClient do
  @callback post(request :: any(), options :: keyword()) :: {:ok, any()} | {:error, any()}
end

defmodule Concerto.MatchError do
  defexception []

  def message(_) do
    "No match found"
  end

  defimpl Plug.Exception do
    def status(_) do
      404
    end
  end
end

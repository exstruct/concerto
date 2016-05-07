defmodule Concerto.InvalidMethodException do
  defexception [:method, :allowed]

  def message(%{method: method, allowed: allowed}) do
    "Invalid method #{inspect(method)}. Allowed methods include #{inspect(allowed)}"
  end
end

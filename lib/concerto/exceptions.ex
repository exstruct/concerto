defmodule Concerto.InvalidMethodException do
  defexception [:method, :allowed]

  def message(%{method: method, allowed: allowed}) do
    "Invalid method #{inspect(method)}. Allowed methods include #{inspect(allowed)}"
  end
end

defmodule Concerto.PathConflictException do
  defexception [:a, :b]

  def message(%{a: a, b: b}) do
    "Path conflict with #{inspect(a)} and #{inspect(b)}"
  end
end

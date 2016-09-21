defmodule Concerto.Utils do
  @moduledoc false

  def format_locations(files, root, ext, allowed_methods, filters) do
    files
    |> Stream.filter(fn(file) ->
      !Enum.any?(filters, &Regex.match?(&1, file))
    end)
    |> Stream.map(fn(file) ->
      path = path_to_list(file, root)

      method = Path.basename(file, ext)
      mapped_method = if allowed_methods, do: allowed_methods[method], else: method

      if !mapped_method do
        raise Concerto.InvalidMethodException, method: method, allowed: Map.keys(allowed_methods)
      end

      {Path.absname(file, root), method, mapped_method, path}
    end)
    |> Enum.sort(fn({a_file, _, _, a}, {b_file, _, _, b}) ->
      try do
        sort_path(a, b)
      catch
        :path_conflict ->
          raise Concerto.PathConflictException, [
            a: Path.relative_to(a_file, root),
            b: Path.relative_to(b_file, root)
          ]
      end
    end)
  end

  defp sort_path([], _), do: true
  defp sort_path(_, []), do: false
  defp sort_path([a | a_r], [a | b_r]), do: sort_path(a_r, b_r)
  defp sort_path(["@" <> _ | _], ["@" <> _ | _]), do: throw :path_conflict
  defp sort_path(["@" <> _ | _], [_ | _]), do: false
  defp sort_path([_ | _], ["@" <> _ | _]), do: true
  defp sort_path([a | _], [b | _]), do: a < b

  defp path_to_list(path, root) do
    case Path.dirname(Path.relative_to(path, root)) do
      "." -> []
      l -> Path.split(l)
    end
  end

  def format_module(prefix, path, method) do
    Module.concat([prefix | Enum.map(path, &camelize/1) ++ [method]])
  end

  defp camelize("@" <> name) do
    camelize(name) <> "_"
  end
  defp camelize(name) do
    name
    |> String.replace("-", "_")
    |> camelize_ex()
  end

  if function_exported?(Macro, :camelize, 1) do
    def camelize_ex(str), do: Macro.camelize(str)
  else
    def camelize_ex(str), do: apply(Mix.Utils, :camelize, [str])
  end

  def format_parts(path) do
    Enum.map_reduce(path, [], fn
      ("@" <> name, acc) ->
        var = Macro.var(:"#{name}", nil)
        {var, [{name, var} | acc]}
      (name, acc) ->
        {name, acc}
    end)
  end
end

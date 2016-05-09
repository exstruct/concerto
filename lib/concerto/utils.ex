defmodule Concerto.Utils do
  @moduledoc false

  def format_locations(files, root, ext, allowed_methods, filters) do
    files
    |> Enum.filter(fn(file) ->
      !Enum.any?(filters, &Regex.match?(&1, file))
    end)
    |> Enum.map(fn(file) ->
      path = path_to_list(file, root)

      method = Path.basename(file, ext)
      mapped_method = if allowed_methods, do: allowed_methods[method], else: method

      if !mapped_method do
        raise Concerto.InvalidMethodException, method: method, allowed: Map.keys(allowed_methods)
      end

      {Path.absname(file, root), method, mapped_method, path}
    end)
  end

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
    |> Mix.Utils.camelize()
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

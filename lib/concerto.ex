defmodule Concerto do
  defmacro __using__(opts) do
    quote bind_quoted: binding do
      @before_compile Concerto

      root = Path.expand(opts[:root] || "web", __DIR__)
      ext = opts[:ext] || ".exs"

      resources = root
      |> Path.join("**/*#{ext}")
      |> Path.wildcard()

      if length(resources) == 0 do
        require Logger
        Logger.warn "No routes found in #{inspect(root)}"
      end

      methods = (opts[:methods] || ["GET", "POST", "PUT", "DELETE", "PATCH"])
      |> Enum.reduce(%{}, fn
        ({key, value}, acc) ->
          Map.put(acc, to_string(key), value)
        (key, acc) ->
          key = to_string(key)
          Map.put(acc, key, key)
      end)
      default_method = opts[:default_method] || "GET"

      prefix = opts[:module_prefix] || __MODULE__
      filters = opts[:filters] || [~r/__[^_]+__/, ~r/_test.exs$/, ~r/\/test_helper.exs$/]

      locations = Concerto.Utils.format_locations(resources, root, ext, methods, filters)

      @doc """
      Lookup the module for the provided method and parts

          iex> #{inspect(__MODULE__)}.match("GET", [])
          {#{inspect(prefix)}.GET, %{}}

          iex> #{inspect(__MODULE__)}.match("POST", ["users", "123"])
          {#{inspect(prefix)}.Users.User_.POST, %{"user" => "123"}}
      """

      def match(method, parts)

      @doc """
      Resolve the method and path given the route name and params

          iex> #{inspect(__MODULE__)}.resolve("GET /")
          {"GET", []}

          iex> #{inspect(__MODULE__)}.resolve("POST /users/@user", %{"user" => "123"})
          {"POST", ["users", "123"]}
      """

      def resolve(name, params \\ %{})

      @doc """
      Lookup the module for the given name

          iex> #{inspect(__MODULE__)}.resolve_module("GET /")
          #{inspect(prefix)}.GET

          iex> #{inspect(__MODULE__)}.resolve_module("POST /users/@user")
          #{inspect(prefix)}.Users.User_.POST
      """

      def resolve_module(name)

      for {file, method, mapped_method, path_info} <- locations do
        path = "/" <> Enum.join(path_info, "/")
        name = method <> " " <> path
        module = Concerto.Utils.format_module(prefix, path_info, method)
        relative = Path.relative_to(file, root)
        {parts, params} = Concerto.Utils.format_parts(path_info)

        def match(unquote(mapped_method), unquote(parts)) do
          {unquote(module), %{unquote_splicing(params)}}
        end

        def resolve(unquote(file), %{unquote_splicing(params)}) do
          {unquote(mapped_method), unquote(parts)}
        end
        def resolve(unquote(relative), %{unquote_splicing(params)}) do
          {unquote(mapped_method), unquote(parts)}
        end
        def resolve(unquote(name), %{unquote_splicing(params)}) do
          {unquote(mapped_method), unquote(parts)}
        end
        def resolve(unquote(module), %{unquote_splicing(params)}) do
          {unquote(mapped_method), unquote(parts)}
        end

        def resolve_module(unquote(file)) do
          unquote(module)
        end
        def resolve_module(unquote(relative)) do
          unquote(module)
        end
        def resolve_module(unquote(name)) do
          unquote(module)
        end
        def resolve_module(unquote(module)) do
          unquote(module)
        end

        if default_method && method == default_method do
          def resolve(unquote(path), %{unquote_splicing(params)}) do
            {unquote(mapped_method), unquote(parts)}
          end

          def resolve_module(unquote(path)) do
            unquote(module)
          end
        end
      end
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def match(_, _) do
        nil
      end

      def resolve(name, _) do
        if resolve_module(name) do
          :error
        end
      end

      def resolve_module(_) do
        nil
      end
    end
  end
end

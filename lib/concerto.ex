defmodule Concerto do
  defmacro __using__(opts) do
    quote bind_quoted: binding() do
      @before_compile Concerto
      import Concerto
      Module.register_attribute(__MODULE__, :concerto_forwards, accumulate: true)

      root = Path.expand(opts[:root] || "web", __DIR__)
      ext = opts[:ext] || ".exs"

      all_files = root
      |> Path.join("**")
      |> Path.wildcard()

      resources = all_files
      |> Enum.filter(fn(file) ->
        Path.extname(file) == ext
      end)

      [root | all_files]
      |> Enum.each(fn(file) ->
        case File.stat(file) do
          {:ok, %{type: :directory, mtime: _m}} ->
            @external_resource file
          _ ->
            :ok
        end
      end)

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
      @concerto_methods methods

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
        {parts, params} = Concerto.Utils.format_parts(path_info)

        def match(unquote(mapped_method), unquote(parts)) do
          {unquote(module), %{unquote_splicing(params)}}
        end

        def resolve(unquote("file://" <> file), %{unquote_splicing(params)}) do
          {unquote(mapped_method), unquote(parts)}
        end
        def resolve(unquote(name), %{unquote_splicing(params)}) do
          {unquote(mapped_method), unquote(parts)}
        end
        def resolve(unquote(module), %{unquote_splicing(params)}) do
          {unquote(mapped_method), unquote(parts)}
        end

        def resolve_module(unquote("file://" <> file)) do
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

  defmacro forward(path, opts) do
    to = opts[:to]
    quote bind_quoted: binding() do
      ["" | parts] = String.split(path, "/")

      @concerto_forwards {to, parts}

      def match(method, [unquote_splicing(parts) | rest] = path_info) do
        unquote(to).match(method, rest)
      end
    end
  end

  defmacro __before_compile__(_) do
    quote unquote: false do
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

      for {to, parts} <- @concerto_forwards do
        path = "/" <> Enum.join(parts, "/")
        defoverridable resolve: 2, resolve_module: 1

        defp resolve_forward(unquote(to), name, params) do
          case unquote(to).resolve(name, params) do
            {method, path_info} ->
              {method, [unquote_splicing(parts) | path_info]}
            other ->
              other
          end
        end

        for {method, _} <- Enum.into(@concerto_methods, [nil: nil]) do
          method = method && method <> " " || ""
          match = method <> path

          def resolve(unquote(match), params) do
            resolve_forward(unquote(to), unquote(method <> "/"), params)
          end
          def resolve(unquote(match) <> path, params) do
            resolve_forward(unquote(to), unquote(method) <> path, params)
          end

          def resolve_module(unquote(match)) do
            unquote(to).resolve_module(unquote(method <> "/"))
          end
          def resolve_module(unquote(match) <> path) do
            unquote(to).resolve_module(unquote(method) <> path)
          end
        end

        def resolve(name, params) do
          case super(name, params) do
            error when error in [:error, nil] ->
              resolve_forward(unquote(to), name, params)
            match ->
              match
          end
        end

        def resolve_module(name) do
          case super(name) do
            nil ->
              unquote(to).resolve_module(name)
            match ->
              match
          end
        end
      end
    end
  end
end

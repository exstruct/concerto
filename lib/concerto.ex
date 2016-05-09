defmodule Concerto do
  defmacro __using__(opts) do
    quote bind_quoted: binding do
      root = opts[:root] || "web"
      ext = opts[:ext] || ".exs"

      resources = root
      |> Path.join("**/*#{ext}")
      |> Path.wildcard()

      methods = (opts[:methods] || ["GET", "POST", "PUT", "DELETE", "PATCH"])
      |> Enum.map(fn
        ({key, value}) when is_binary(key) ->
          {key, value}
        (key) when is_binary(key) ->
          {key, key}
      end)
      |> Enum.into(%{})

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

      for {file, method, mapped_method, path} <- locations do
        name = method <> " /" <> Enum.join(path, "/")
        module = Concerto.Utils.format_module(prefix, path, method)
        {parts, params} = Concerto.Utils.format_parts(path)

        def match(unquote(method), unquote(parts)) do
          {unquote(module), %{unquote_splicing(params)}}
        end

        def resolve(unquote(file), %{unquote_splicing(params)}) do
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
        def resolve_module(unquote(name)) do
          unquote(module)
        end
      end

      def match(_, _), do: nil
      def resolve(_, _), do: nil
      def resolve_module(_), do: nil

      def reload do
        Code.load_file(__ENV__.file)
      end
    end
  end
end

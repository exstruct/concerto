defmodule Concerto do
  defmacro __using__(opts) do
    quote location: :keep do
      use Plug.Builder, unquote(opts)

      @doc false
      def match(%{method: method, path_info: path_info, host: host} = conn, _opts) do
        __match__(
          conn,
          method,
          host |> String.split(".") |> :lists.reverse(),
          path_info |> Enum.map(&URI.decode/1)
        )
      end

      @doc false
      def __match__(conn, _, _, _) do
        conn
      end

      @doc false
      def dispatch(%Plug.Conn{private: %{plug_route: {_path, fun}}} = conn, _opts) do
        fun.(conn)
      end

      def dispatch(_conn, _opts) do
        raise Concerto.MatchError
      end

      defoverridable match: 2, dispatch: 2
    end
  end

  @doc false
  def __put_route__(conn, path, fun) do
    Plug.Conn.put_private(conn, :plug_route, {append_match_path(conn, path), fun})
  end

  defp append_match_path(%Plug.Conn{private: %{plug_route: {base_path, _}}}, path) do
    base_path <> path
  end

  defp append_match_path(%Plug.Conn{}, path) do
    path
  end
end

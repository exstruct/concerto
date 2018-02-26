defmodule Concerto.Route do
  require Logger

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use Multix

      route =
        Concerto.Route.__validate__(opts, %{
          router: nil,
          to: __MODULE__,
          function: :call,
          opts: [],
          methods: :_,
          host: :_,
          path: nil,
          name: nil
        })

      {method, guard} = Concerto.Route.__build_method_match__(route.methods)

      {path_match, path_rest, path_params} =
        Concerto.Route.__build_list_match__(route.path, :rest_path)

      {host_match, host_rest, host_params} =
        Concerto.Route.__build_list_match__(route.host, :rest_host)

      params = Stream.concat(path_params, host_params)

      defmulti unquote(route.router).__match__(
                 %Plug.Conn{} = conn,
                 unquote(method),
                 unquote(host_match),
                 unquote(path_match)
               )
               when unquote(guard) do
        fun = unquote(Concerto.Route.__build_plug_route__(route, params))
        Concerto.__put_route__(conn, unquote(opts[:path] || "/"), fun)
      end
    end
  end

  def __build_plug_route__(route, params) do
    quote do
      fn %Plug.Conn{
           path_info: path_info,
           path_params: path_params,
           script_name: script_name
         } = conn ->
        # {base, split_path} = Enum.split(path, length(path) - length(new_path))

        conn =
          unquote({:., [], [route.to, route.function]})(
            # %{conn | path_info: split_path, script_name: script ++ base},
            unquote(
              case build_params(params) do
                [] ->
                  quote(do: conn)

                fields ->
                  quote(do: %{conn | unquote_splicing(fields)})
              end
            ),
            unquote(route.opts)
          )

        %{conn | path_info: path_info, script_name: script_name}
      end
    end
  end

  defp build_params(params) do
    params
    |> Enum.uniq()
    |> case do
      [] ->
        []

      params ->
        [{:path_params, quote(do: Map.merge(path_params, %{unquote_splicing(params)}))}]
    end
  end

  def __build_method_match__(:_) do
    {Macro.var(:_, nil), true}
  end

  def __build_method_match__([method]) do
    {method, true}
  end

  def __build_method_match__(methods) do
    var = Macro.var(:methods, __MODULE__)

    {var,
     quote do
       unquote(var) in unquote(methods)
     end}
  end

  def __build_list_match__(:_, _) do
    rest = Macro.var(:_, nil)
    {rest, rest, []}
  end

  def __build_list_match__(list, rest_name) do
    list
    |> :lists.reverse()
    |> Enum.reduce({[], [], []}, fn
      :*, {_, _, params} ->
        rest = Macro.var(rest_name, __MODULE__)
        {rest, rest, params}

      name, {acc, rest, params} when is_atom(name) ->
        var = Macro.var(name, nil)
        {prepend_component(acc, var), rest, [{name, var} | params]}

      component, {acc, rest, params} ->
        {prepend_component(acc, component), rest, params}
    end)
  end

  defp prepend_component(acc, component) when is_tuple(acc) do
    [{:|, [], [component, acc]}]
  end

  defp prepend_component(acc, component) when is_list(acc) do
    [component | acc]
  end

  def __build_path_params__(params) do
    {
      :%{},
      [],
      params
      |> Stream.filter(&is_tuple/1)
      |> Stream.uniq()
      |> Enum.map(fn {name, _} = var ->
        {name, var}
      end)
    }
  end

  def __validate__([], acc) do
    acc
    |> assert_key(:router)
    |> assert_key(:path)
  end

  def __validate__([{:router, router} | opts], acc) do
    __validate__(opts, %{acc | router: router})
  end

  def __validate__([{:path, path} | opts], acc) do
    path =
      path
      |> String.split("/")
      |> parse_components()
      |> assert_valid_format!("path", path)

    __validate__(opts, %{acc | path: path})
  end

  def __validate__([{key, methods} | opts], acc) when key === :method or key === :methods do
    methods =
      methods
      |> case do
        m when is_binary(m) -> String.split(m, "|")
        m when is_list(m) -> m
      end
      |> Stream.map(&String.trim/1)
      |> Stream.map(&String.upcase/1)
      |> Enum.to_list()
      |> case do
        ["*"] ->
          :_

        methods ->
          methods
      end

    __validate__(opts, %{acc | methods: methods})
  end

  def __validate__([{:host, host} | opts], acc) do
    host =
      host
      |> String.split(".")
      |> Enum.reverse()
      |> parse_components()
      |> assert_valid_format!("host", host)

    __validate__(opts, %{acc | host: host})
  end

  def __validate__([{:name, name} | opts], acc) do
    __validate__(opts, %{acc | name: name})
  end

  def __validate__([{:to, to} | opts], acc) do
    __validate__(opts, %{acc | to: to})
  end

  def __validate__([{:function, function} | opts], acc) do
    __validate__(opts, %{acc | function: function})
  end

  def __validate__([{:opts, plug_opts} | opts], acc) do
    __validate__(opts, %{acc | opts: plug_opts})
  end

  def __validate__([{key, _} | opts], acc) do
    Logger.warn("Invalid option #{inspect(key)}")
    __validate__(opts, acc)
  end

  defp parse_components(components) do
    components
    |> Stream.map(fn
      ":_" -> :_
      "*" -> :*
      ":" <> param -> String.to_atom(param)
      "@" <> param -> String.to_atom(param)
      component -> component
    end)
    |> Stream.filter(&(&1 !== ""))
    |> Enum.to_list()
    |> case do
      [:*] ->
        :_

      components ->
        components
    end
  end

  defp assert_valid_format!(components, type, bin) do
    try do
      assert_valid_format!(components)
      components
    catch
      :invalid ->
        raise CompileError, "Invalid #{type} pattern: #{inspect(bin)}"
    end
  end

  defp assert_valid_format!(:_) do
    true
  end

  defp assert_valid_format!([]) do
    true
  end

  defp assert_valid_format!([:*, _ | _]) do
    throw(:invalid)
  end

  defp assert_valid_format!([_ | rest]) do
    assert_valid_format!(rest)
  end

  defp assert_key(acc, key) do
    case acc do
      %{^key => value} when value !== nil ->
        acc

      _ ->
        raise CompileError, "Route missing #{inspect(key)} config"
    end
  end

  defimpl String.Chars do
    def to_string(route) do
      # TODO
      inspect(route)
    end
  end
end

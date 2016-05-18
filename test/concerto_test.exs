defmodule ConcertoTest do
  use ExUnit.Case, async: true

  setup context do
    hash = :erlang.phash2(context.test)
    module = Module.concat(__MODULE__, "Test#{hash}")
    dir = Path.join([__DIR__, "fixtures", to_string(hash)])

    for path <- context[:paths] || [] do
      path = Path.join(dir, path)
      path |> Path.dirname() |> File.mkdir_p!()
      path |> File.touch!()
    end

    on_exit fn ->
      File.rm_rf!(dir)
    end

    {:ok, [dir: dir, target: module]}
  end

  @tag paths: [
    "/GET.exs",
    "/posts/@post/GET.exs",
    "/users/GET.exs",
    "/users/POST.exs",
    "/users/foo/GET.exs",
    "/users/@user/GET.exs",
    "/users/@user/POST.exs",
    "/users/__test__/GET.exs",
  ]
  test "defaults", context do
    module = create_router(context)

    module |> assert_route("GET", [], m(module, GET))
    module |> assert_route("GET", ["posts", "@post"], m(module, Posts.Post_.GET), %{"post" => "789"})
    module |> assert_route("GET", ["users"], m(module, Users.GET))
    module |> assert_route("POST", ["users"], m(module, Users.POST))
    module |> assert_route("GET", ["users", "foo"], m(module, Users.Foo.GET))
    module |> assert_route("GET", ["users", "@user"], m(module, Users.User_.GET), %{"user" => "123"})
    module |> assert_route("POST", ["users", "@user"], m(module, Users.User_.POST), %{"user" => "456"})

    module.resolve("/") |> assert_eql({"GET", []})
    module.resolve("/users") |> assert_eql({"GET", ["users"]})
    module.resolve("/users/foo") |> assert_eql({"GET", ["users", "foo"]})
    module.resolve("/users/@user", %{"user" => "345"}) |> assert_eql({"GET", ["users", "345"]})

    module.resolve("GET.exs") |> assert_eql({"GET", []})
    module.resolve("users/GET.exs") |> assert_eql({"GET", ["users"]})
    module.resolve("users/POST.exs") |> assert_eql({"POST", ["users"]})
    module.resolve("users/foo/GET.exs") |> assert_eql({"GET", ["users", "foo"]})
    module.resolve("users/@user/GET.exs", %{"user" => "678"}) |> assert_eql({"GET", ["users", "678"]})
    module.resolve("users/@user/POST.exs", %{"user" => "789"}) |> assert_eql({"POST", ["users", "789"]})

    module.resolve("GET /users/@user") |> assert_eql(:error)
    module.resolve("POST /users/@user", %{"foo" => "123"}) |> assert_eql(:error)

    module.resolve("GET /users/__test__") |> assert_eql(nil)
  end

  @tag paths: [
    "/GET.md",
    "/foo/GET.md"
  ]
  test "extension change", context do
    module = create_router(context, [ext: ".md"])

    module |> assert_route("GET", [], m(module, GET))
    module |> assert_route("GET", ["foo"], m(module, Foo.GET))
  end

  @tag paths: [
    "/foo.exs",
    "/foo/bar.exs",
    "/foo/baz.exs"
  ]
  test "method change", context do
    module = create_router(context, [methods: ["foo", "bar", {"baz", "bang"}], default_method: "foo"])

    module.match("bang", ["foo"]) |> assert_eql({m(module, "Foo.baz"), %{}})
    module.resolve("baz /foo") |> assert_eql({"bang", ["foo"]})

    module |> assert_route("foo", [], m(module, :foo))
    module |> assert_route("bar", ["foo"], m(module, "Foo.bar"))
  end

  @tag paths: [
    "/foo/GET.exs",
    "/bar/GET.exs"
  ]
  test "filter", context do
    module = create_router(context, [filters: [~r/foo/]])

    module.resolve("GET /foo") |> assert_eql(nil)
    module |> assert_route("GET", ["bar"], m(module, Bar.GET))
  end

  @tag paths: [
    "/GET.exs",
    "/bar/POST.exs"
  ]
  test "module prefix", context do
    module = create_router(context, [module_prefix: Foo])

    module |> assert_route("GET", [], Foo.GET)
    module |> assert_route("POST", ["bar"], Foo.Bar.POST)
  end

  @tag paths: [
    "/users/@user/GET.exs",
    "/users/@other/GET.exs"
  ]
  test "path conflict", context do
    assert_raise Concerto.PathConflictException, fn ->
      create_router(context)
    end
  end

  defp create_router(context, opts \\ []) do
    target = context.target

    defmodule target do
      use Concerto, [{:root, context.dir} | opts]
    end

    target
  end

  defp assert_route(router, method, path_info, module, params \\ %{}) do
    name = method <> " /" <> Enum.join(path_info, "/")

    interpolated = path_info |> Enum.map(fn
      "@" <> name ->
        Map.get(params, name)
      name ->
        name
    end)

    router.match(method, interpolated) |> assert_eql({module, params})

    router.resolve(module, params) |> assert_eql({method, interpolated})
    router.resolve(name, params) |> assert_eql({method, interpolated})

    router.resolve_module(module) |> assert_eql(module)
    router.resolve_module(name) |> assert_eql(module)
  end

  defp m(root, name) do
    Module.concat(root, name)
  end

  defp assert_eql(actual, expected) do
    assert actual == expected
  end
end

# concerto [![Build Status](https://travis-ci.org/exstruct/concerto.svg?branch=master)](https://travis-ci.org/exstruct/concerto) [![Hex.pm](https://img.shields.io/hexpm/v/concerto.svg?style=flat-square)](https://hex.pm/packages/concerto) [![Hex.pm](https://img.shields.io/hexpm/dt/concerto.svg?style=flat-square)](https://hex.pm/packages/concerto)

file-based routing library for elixir

## Installation

`Concerto` is [available in Hex](https://hex.pm/docs/publish) and can be installed as:

  1. Add concerto your list of dependencies in `mix.exs`:

        def deps do
          [{:concerto, "~> 0.1.0"}]
        end

## Usage

Given the following directory structure

```sh
.
├── lib
│   └── my_router.ex
└── web
    ├── GET.exs
    └── users
        └── @user
            ├── GET.exs
            └── POST.exs
```

a router can be contstructed with the following:

```elixir
defmodule MyRouter do
  use Concerto, root: "web",
                ext: ".exs",
                methods: ["GET", "POST", "PUT", "DELETE", "PATCH"],
                module_prefix: MyApp.Web
end
```

## API

### `match(method, path)`

### `resolve(name, params)`

### `resolve_module(name)`

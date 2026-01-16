<p align="center">
  <img src="assets/logo.svg" alt="GreenFairy Logo" width="200">
</p>

<h1 align="center">GreenFairy</h1>

<p align="center">
  <a href="https://hex.pm/packages/green_fairy"><img src="https://img.shields.io/hexpm/v/green_fairy.svg" alt="Hex.pm"></a>
  <a href="https://hexdocs.pm/green_fairy"><img src="https://img.shields.io/badge/docs-hexdocs-blue.svg" alt="Documentation"></a>
  <a href="https://github.com/GreenFairy-GraphQL/greenfairy/actions"><img src="https://github.com/GreenFairy-GraphQL/greenfairy/workflows/CI/badge.svg" alt="CI"></a>
</p>

<p align="center">
  A cleaner DSL for GraphQL schema definitions built on <a href="https://github.com/absinthe-graphql/absinthe">Absinthe</a>.
</p>

---

> **⚠️ Experimental:** GreenFairy is in early development. The API may change between versions.

## Features

- **One module = one type** — SOLID principles with auto-discovery
- **CQL filtering** — Hasura-style `where` and `orderBy` on every connection
- **Multi-database** — PostgreSQL, MySQL, SQLite, MSSQL, ClickHouse, Elasticsearch
- **DataLoader** — Batched association resolution built-in
- **Relay** — Cursor pagination, global IDs, Node interface
- **Authorization** — Type-owned field visibility

## Installation

```elixir
def deps do
  [{:green_fairy, "~> 0.1.0"}]
end
```

## Quick Example

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    field :id, non_null(:id)
    field :name, :string
    field :email, non_null(:string)

    connection :posts, MyApp.GraphQL.Types.Post
  end
end
```

```graphql
query {
  users(where: { email: { _ilike: "%@example.com" } }, first: 10) {
    nodes { id name email }
    pageInfo { hasNextPage endCursor }
  }
}
```

## Documentation

- [HexDocs](https://hexdocs.pm/green_fairy) — Full API documentation
- [Getting Started](https://hexdocs.pm/green_fairy/getting-started.html) — Installation and first schema
- [CQL Guide](https://hexdocs.pm/green_fairy/cql.html) — Filtering, sorting, multi-database

## Links

- [GitHub](https://github.com/GreenFairy-GraphQL/greenfairy)
- [Hex.pm](https://hex.pm/packages/green_fairy)
- [Changelog](https://github.com/GreenFairy-GraphQL/greenfairy/blob/main/CHANGELOG.md)

## License

MIT — see [LICENSE](https://github.com/GreenFairy-GraphQL/greenfairy/blob/main/LICENSE)

## Contributing

See [CONTRIBUTING.md](https://github.com/GreenFairy-GraphQL/greenfairy/blob/main/CONTRIBUTING.md) for guidelines.

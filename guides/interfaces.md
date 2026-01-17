# Interfaces

Interfaces define a set of fields that multiple types can implement. They enable
polymorphic queries where a field can return different types that share common fields.

## Basic Usage

```elixir
defmodule MyApp.GraphQL.Interfaces.Node do
  use GreenFairy.Interface

  interface "Node" do
    @desc "A globally unique identifier"
    field :id, non_null(:id)
  end
end
```

This generates:

```graphql
interface Node {
  id: ID!
}
```

That's it! No `resolve_type` callback needed - GreenFairy automatically resolves types.

## Implementing Interfaces

Types implement interfaces using the `implements` macro:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    implements MyApp.GraphQL.Interfaces.Node

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string
  end
end

defmodule MyApp.GraphQL.Types.Post do
  use GreenFairy.Type

  type "Post", struct: MyApp.Post do
    implements MyApp.GraphQL.Interfaces.Node

    field :id, non_null(:id)
    field :title, non_null(:string)
    field :body, :string
  end
end
```

Implementing types must include all fields defined by the interface.

## Automatic Type Resolution

GreenFairy automatically resolves interface types based on the struct of the returned value. When a type declares `implements` with a `struct:` option, it registers itself in the type registry.

**How it works:**

1. Type declares `type "User", struct: MyApp.User do implements Node end`
2. GreenFairy registers: `MyApp.User` → `:user` for the `Node` interface
3. At runtime, when a `%MyApp.User{}` is returned for a Node field, GreenFairy looks up the struct in the registry and returns `:user`

This means you never need to write manual `resolve_type` callbacks for interfaces - just ensure your types have the `struct:` option and use `implements`.

## Multiple Interfaces

Types can implement multiple interfaces:

```elixir
defmodule MyApp.GraphQL.Interfaces.Timestamped do
  use GreenFairy.Interface

  interface "Timestamped" do
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)
  end
end

defmodule MyApp.GraphQL.Types.Post do
  use GreenFairy.Type

  type "Post", struct: MyApp.Post do
    implements MyApp.GraphQL.Interfaces.Node
    implements MyApp.GraphQL.Interfaces.Timestamped

    field :id, non_null(:id)
    field :title, non_null(:string)
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)
  end
end
```

## Interface Fields

Interfaces can have complex fields with arguments:

```elixir
defmodule MyApp.GraphQL.Interfaces.Searchable do
  use GreenFairy.Interface

  interface "Searchable" do
    @desc "Search relevance score"
    field :relevance_score, :float

    @desc "Highlighted search matches"
    field :highlights, list_of(:string) do
      arg :max_length, :integer, default_value: 100
    end
  end
end
```

## Querying Interfaces

Use inline fragments to access type-specific fields:

```graphql
query {
  node(id: "VXNlcjoxMjM=") {
    id
    ... on User {
      email
      name
    }
    ... on Post {
      title
      body
    }
  }
}

# Or with fragment spreads
query {
  search(query: "elixir") {
    relevanceScore
    ... on User {
      email
    }
    ... on Post {
      title
    }
  }
}
```

## Common Patterns

### Node Interface (Relay)

The Node interface is fundamental to Relay-compatible schemas:

```elixir
defmodule MyApp.GraphQL.Interfaces.Node do
  use GreenFairy.Interface

  interface "Node" do
    @desc "Globally unique identifier"
    field :id, non_null(:id)
  end
end
```

Use with the `node_field()` macro in your queries:

```elixir
defmodule MyApp.GraphQL.RootQuery do
  use GreenFairy.Query

  queries do
    node_field()  # Auto-resolves any Node type by GlobalId
  end
end
```

### Actor Interface

For systems with multiple actor types:

```elixir
defmodule MyApp.GraphQL.Interfaces.Actor do
  use GreenFairy.Interface

  interface "Actor" do
    field :id, non_null(:id)
    field :display_name, non_null(:string)
    field :avatar_url, :string
  end
end
```

Then implement in your types:

```elixir
type "User", struct: MyApp.User do
  implements MyApp.GraphQL.Interfaces.Actor
  # fields...
end

type "Organization", struct: MyApp.Organization do
  implements MyApp.GraphQL.Interfaces.Actor
  # fields...
end

type "Bot", struct: MyApp.Bot do
  implements MyApp.GraphQL.Interfaces.Actor
  # fields...
end
```

### Auditable Interface

For tracking changes:

```elixir
defmodule MyApp.GraphQL.Interfaces.Auditable do
  use GreenFairy.Interface

  interface "Auditable" do
    field :created_by, :user
    field :updated_by, :user
    field :created_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)
  end
end
```

## Advanced: Custom Type Resolution

In rare cases where automatic resolution isn't sufficient (e.g., returning plain maps instead of structs), you can provide a custom `resolve_type` callback:

```elixir
interface "SearchResult" do
  field :score, :float

  # Only needed for non-struct returns
  resolve_type fn
    %{type: "user"}, _ -> :user
    %{type: "post"}, _ -> :post
    _, _ -> nil
  end
end
```

This is an escape hatch - prefer using structs with automatic resolution.

## Module Functions

Every interface module exports:

| Function | Description |
|----------|-------------|
| `__green_fairy_kind__/0` | Returns `:interface` |
| `__green_fairy_identifier__/0` | Returns the type identifier (e.g., `:node`) |
| `__green_fairy_definition__/0` | Returns the full definition map |

## Naming Conventions

| GraphQL Name | Elixir Identifier | Module Suggestion |
|--------------|-------------------|-------------------|
| `Node` | `:node` | `MyApp.GraphQL.Interfaces.Node` |
| `Timestamped` | `:timestamped` | `MyApp.GraphQL.Interfaces.Timestamped` |
| `Searchable` | `:searchable` | `MyApp.GraphQL.Interfaces.Searchable` |

## Next Steps

- [Object Types](object-types.md) - Types that implement interfaces
- [Unions](unions.md) - Alternative to interfaces for polymorphism
- [Relay](relay.md) - Relay-compliant Node interface
- [Expose](expose.md) - Auto-generate query fields from types

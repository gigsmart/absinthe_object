# Expose - Automatic Query Field Generation

GreenFairy's `expose` macro automatically generates query fields for fetching types by their fields. This eliminates boilerplate and provides a consistent pattern for object fetching.

## Quick Start

Add `expose :id` to your type to auto-generate a query field:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.Accounts.User do
    # Auto-generates: query { user(id: ID!): User }
    expose :id

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string
  end
end
```

That's it! The schema will automatically include a `user(id: ID!)` query field that:
1. Decodes the GlobalId
2. Fetches the record from your configured repo
3. Returns the user or an error

## How It Works

When you add `expose :id` to a type:

1. **Field Type Detection**: GreenFairy looks up the field type from your struct's adapter (Ecto schema, etc.)
2. **Query Field Generation**: A query field is auto-generated with the appropriate argument type
3. **GlobalId Handling**: For `:id` fields, the GlobalId is automatically decoded
4. **Database Fetching**: Records are fetched using your schema's configured repo

## Configuration

### Schema Setup

Configure your repo in the schema:

```elixir
defmodule MyApp.GraphQL.Schema do
  use GreenFairy.Schema,
    query: MyApp.GraphQL.RootQuery,
    repo: MyApp.Repo
end
```

### Exposing Multiple Fields

You can expose multiple fields on a type:

```elixir
type "User", struct: MyApp.Accounts.User do
  expose :id           # Generates: user(id: ID!): User
  expose :email        # Generates: userByEmail(email: String!): User
  expose :username     # Generates: userByUsername(username: String!): User

  field :id, non_null(:id)
  field :email, non_null(:string)
  field :username, non_null(:string)
end
```

### Custom Field Names

Override the generated query field name with `:as`:

```elixir
type "User", struct: MyApp.Accounts.User do
  expose :id, as: :get_user           # Generates: getUser(id: ID!): User
  expose :email, as: :find_by_email   # Generates: findByEmail(email: String!): User

  field :id, non_null(:id)
  field :email, non_null(:string)
end
```

## Field Type Inference

The argument type is automatically inferred from your Ecto schema:

| Ecto Type | GraphQL Arg Type |
|-----------|------------------|
| `:id` | `:id` |
| `:integer` | `:integer` |
| `:string` | `:string` |
| `:boolean` | `:boolean` |
| `Ecto.UUID` | `:id` |
| Other | `:string` |

## Generated Query Behavior

### For `:id` Fields

When exposing `:id`, the generated resolver:
1. Decodes the GlobalId to extract the local ID
2. Calls `Repo.get(StructModule, local_id)`
3. Returns `{:ok, record}` or `{:error, "TypeName not found"}`

```graphql
query {
  user(id: "VXNlcjoxMjM=") {  # GlobalId for User:123
    id
    email
    name
  }
}
```

### For Other Fields

When exposing non-id fields, the generated resolver:
1. Uses the raw argument value
2. Calls `Repo.get_by(StructModule, field: value)`
3. Returns `{:ok, record}` or `{:error, "TypeName not found"}`

```graphql
query {
  userByEmail(email: "jane@example.com") {
    id
    email
    name
  }
}
```

## Combining with Query Modules

Exposed fields work alongside custom query fields:

```elixir
# Types expose themselves
type "User", struct: MyApp.Accounts.User do
  expose :id   # Auto-generates user(id:)
  # ...
end

# Query module handles complex queries
defmodule MyApp.GraphQL.RootQuery do
  use GreenFairy.Query

  alias MyApp.GraphQL.Types
  alias MyApp.GraphQL.Inputs

  queries do
    # Relay node field
    node_field()

    # List queries with filters (not auto-generated)
    field :users, list_of(Types.User) do
      arg :filter, Inputs.UserFilter
      resolve &MyApp.Resolvers.User.list/3
    end

    # Complex search queries
    field :search_users, list_of(Types.User) do
      arg :query, non_null(:string)
      resolve &MyApp.Resolvers.User.search/3
    end
  end
end
```

## Memory Adapter Support

For types backed by plain structs (not Ecto schemas), the Memory adapter provides basic field type inference:

```elixir
defmodule MyApp.Config do
  defstruct [:id, :name, :value]
end

type "Config", struct: MyApp.Config do
  expose :id   # Works with Memory adapter
  expose :name

  field :id, non_null(:id)
  field :name, non_null(:string)
  field :value, :string
end
```

Note: Memory adapter types require custom resolvers since there's no database to fetch from.

## Best Practices

1. **Use `expose :id` for primary lookups** - Every type that can be fetched should expose its ID
2. **Expose unique fields only** - Only expose fields that uniquely identify a record
3. **Use Query modules for lists** - List queries with filters should be in your Query module
4. **Combine with Node interface** - Types with `expose :id` should also implement the Node interface

## Example: Complete Type

```elixir
defmodule MyApp.GraphQL.Types.Post do
  use GreenFairy.Type

  alias MyApp.GraphQL.Interfaces
  alias MyApp.GraphQL.Types

  type "Post", struct: MyApp.Content.Post do
    implements Interfaces.Node

    # Expose for fetching
    expose :id
    expose :slug, as: :post_by_slug

    # Fields - all auto-resolved from struct
    field :id, non_null(:id)
    field :title, non_null(:string)
    field :slug, non_null(:string)
    field :body, non_null(:string)
    field :published, non_null(:boolean)
    field :inserted_at, non_null(:naive_datetime)

    # Associations - auto batch-loaded
    field :author, Types.User
    field :comments, list_of(Types.Comment)
  end
end
```

This generates:
- `post(id: ID!): Post` - Fetch by GlobalId
- `postBySlug(slug: String!): Post` - Fetch by slug

## See Also

- [Operations Guide](operations.md) - `node_field()` macro for Relay Node resolution
- [Relay Guide](relay.md) - Full Relay specification support
- [Global ID Guide](global-id.md) - Custom GlobalId implementations

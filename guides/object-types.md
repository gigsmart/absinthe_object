# Object Types

Object types are the fundamental building blocks of a GraphQL schema. They represent
entities in your domain with fields that can be queried.

## Basic Usage

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    @desc "A user in the system"

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string
    field :bio, :string
  end
end
```

This generates:

```graphql
"""
A user in the system
"""
type User {
  id: ID!
  email: String!
  name: String
  bio: String
}
```

## Options

The `type` macro accepts these options:

| Option | Description |
|--------|-------------|
| `:struct` | Backing Elixir struct (enables CQL and auto resolve_type) |
| `:description` | Type description (can also use `@desc`) |
| `:on_unauthorized` | Default behavior for unauthorized fields (`:error` or `:return_nil`) |

```elixir
type "User", struct: MyApp.User, on_unauthorized: :return_nil do
  # fields...
end
```

## Fields

### Simple Fields

Fields map directly to struct/map keys. Use atoms for built-in scalars:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)
  field :email, non_null(:string)
  field :name, :string
  field :age, :integer
  field :is_active, :boolean
  field :joined_at, :datetime
end
```

### Field Descriptions

```elixir
type "User", struct: MyApp.User do
  @desc "Unique identifier"
  field :id, non_null(:id)

  @desc "Primary email address"
  field :email, non_null(:string)

  field :name, :string, description: "Display name"
end
```

### Computed Fields

Use `resolve` for fields not directly on the struct:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)
  field :first_name, :string
  field :last_name, :string

  field :full_name, :string do
    resolve fn user, _, _ ->
      {:ok, "#{user.first_name} #{user.last_name}"}
    end
  end

  field :initials, :string do
    resolve fn user, _, _ ->
      initials = "#{String.first(user.first_name)}#{String.first(user.last_name)}"
      {:ok, String.upcase(initials)}
    end
  end
end
```

### Fields with Arguments

For fields returning other types, use module references:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  alias MyApp.GraphQL.Types
  alias MyApp.GraphQL.Enums

  type "User", struct: MyApp.User do
    field :avatar_url, :string do
      arg :size, :integer, default_value: 100

      resolve fn user, %{size: size}, _ ->
        {:ok, "#{user.avatar_base_url}?s=#{size}"}
      end
    end

    field :posts, list_of(Types.Post) do
      arg :limit, :integer, default_value: 10
      arg :status, Enums.PostStatus

      resolve fn user, args, _ ->
        {:ok, MyApp.Posts.list_for_user(user.id, args)}
      end
    end
  end
end
```

## Associations

Associations are automatically batch-loaded using DataLoader:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  alias MyApp.GraphQL.Types

  type "User", struct: MyApp.User do
    field :id, non_null(:id)

    # Automatically batch-loaded
    field :organization, Types.Organization
    field :posts, list_of(Types.Post)
  end
end
```

No custom loaders needed - GreenFairy detects associations from your Ecto schema and uses DataLoader automatically.

See the [Relationships Guide](relationships.md) for advanced patterns.

## Connections (Pagination)

Use `connection` for Relay-style pagination:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  alias MyApp.GraphQL.Types
  alias MyApp.GraphQL.Enums

  type "User", struct: MyApp.User do
    field :id, non_null(:id)

    connection :posts, Types.Post do
      arg :status, Enums.PostStatus

      resolve fn user, args, _ ->
        MyApp.Posts.paginate_for_user(user.id, args)
      end
    end
  end
end
```

See the [Connections Guide](connections.md) for details.

## Implementing Interfaces

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  alias MyApp.GraphQL.Interfaces

  type "User", struct: MyApp.User do
    implements Interfaces.Node
    implements Interfaces.Timestamped

    field :id, non_null(:id)
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)
    # ... other fields
  end
end
```

## Authorization

Control field visibility with the `authorize` callback:

```elixir
type "User", struct: MyApp.User do
  authorize fn user, ctx ->
    if ctx[:current_user]?.admin, do: :all, else: [:id, :name]
  end

  field :id, non_null(:id)
  field :name, :string
  field :email, :string  # Hidden from non-admins
end
```

See the [Authorization Guide](authorization.md) for details.

## CQL Filtering

Types with a `:struct` option automatically get CQL filter and order inputs:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)
  field :name, :string
  field :age, :integer
end
# Generates: CqlFilterUserInput, CqlOrderUserInput
```

See the [CQL Guide](cql.md) for details.

## Complete Example

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  alias MyApp.GraphQL.Interfaces
  alias MyApp.GraphQL.Types
  alias MyApp.GraphQL.Enums

  type "User", struct: MyApp.User do
    @desc "A user account in the system"

    implements Interfaces.Node

    # Basic fields - auto-resolved from struct
    field :id, non_null(:id)
    field :name, :string
    field :email, non_null(:string)
    field :status, Enums.UserStatus
    field :inserted_at, non_null(:datetime)

    # Association - auto batch-loaded
    field :organization, Types.Organization
    field :posts, list_of(Types.Post)

    # Computed field (only when you need custom logic)
    field :display_name, non_null(:string) do
      resolve fn user, _, _ ->
        {:ok, user.name || user.email}
      end
    end

    # Connection with pagination
    connection :friends, Types.User
  end
end
```

## Module Functions

Every type module exports:

| Function | Description |
|----------|-------------|
| `__green_fairy_kind__/0` | Returns `:object` |
| `__green_fairy_identifier__/0` | Returns the type identifier (e.g., `:user`) |
| `__green_fairy_struct__/0` | Returns the backing struct module |
| `__green_fairy_definition__/0` | Returns the full definition map |
| `__authorize__/3` | Authorization callback |
| `__cql_filter_input_identifier__/0` | CQL filter input type |
| `__cql_order_input_identifier__/0` | CQL order input type |

## Naming Conventions

| GraphQL Name | Elixir Identifier | Module Suggestion |
|--------------|-------------------|-------------------|
| `User` | `:user` | `MyApp.GraphQL.Types.User` |
| `BlogPost` | `:blog_post` | `MyApp.GraphQL.Types.BlogPost` |
| `APIKey` | `:api_key` | `MyApp.GraphQL.Types.APIKey` |

## Next Steps

- [Relationships](relationships.md) - Associations and DataLoader
- [Connections](connections.md) - Relay-style pagination
- [Authorization](authorization.md) - Field-level access control
- [CQL](cql.md) - Automatic filtering and sorting

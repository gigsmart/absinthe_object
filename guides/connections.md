# Connections (Pagination)

This guide covers Relay-style cursor-based pagination using connections.

## Overview

Connections provide a standardized way to paginate lists in GraphQL, following the [Relay Connection specification](https://relay.dev/graphql/connections.htm).

A connection includes:
- `edges` - List of edge objects, each containing a `node` and `cursor`
- `pageInfo` - Pagination metadata (hasNextPage, hasPreviousPage, cursors)

## Defining a Connection

Use the `connection` macro inside a type:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  alias MyApp.GraphQL.Types

  type "User", struct: MyApp.User do
    field :id, non_null(:id)
    field :name, :string

    # Paginated list of friends
    connection :friends, Types.User do
      # Custom edge fields (optional)
      edge do
        field :friendship_date, :datetime
        field :friendship_status, :string
      end

      # Custom connection fields (optional)
      field :total_count, :integer
    end
  end
end
```

This generates:
- `:friends_connection` type with `edges`, `pageInfo`, and custom fields
- `:friends_edge` type with `node`, `cursor`, and custom edge fields
- `:friends` field with standard pagination arguments

## Connection Arguments

Connections automatically receive these arguments:

- `first: Int` - Return the first N items
- `after: String` - Return items after this cursor
- `last: Int` - Return the last N items
- `before: String` - Return items before this cursor

## Resolving Connections

### From a List

Use `GreenFairy.Field.Connection.from_list/3`:

```elixir
field :friends, :friends_connection do
  arg :first, :integer
  arg :after, :string
  arg :last, :integer
  arg :before, :string

  resolve fn user, args, _ ->
    friends = MyApp.Accounts.list_friends(user)
    GreenFairy.Field.Connection.from_list(friends, args)
  end
end
```

### From an Ecto Query

Use `GreenFairy.Field.Connection.from_query/4`:

```elixir
field :friends, :friends_connection do
  resolve fn user, args, _ ->
    query = MyApp.Accounts.friends_query(user)
    GreenFairy.Field.Connection.from_query(query, MyApp.Repo, args)
  end
end
```

### Custom Cursor

By default, cursors are Base64-encoded indices. You can provide a custom cursor function:

```elixir
GreenFairy.Field.Connection.from_list(items, args,
  cursor_fn: fn item, _index -> Base.encode64("item:#{item.id}") end
)
```

## PageInfo

The `PageInfo` type is automatically available and includes:

```graphql
type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

## Example Query

```graphql
{
  user(id: "1") {
    friends(first: 10, after: "Y3Vyc29yOjU=") {
      edges {
        cursor
        friendshipDate
        node {
          id
          name
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
      totalCount
    }
  }
}
```

## Query Connections

You can also define connections at the query level:

```elixir
defmodule MyApp.GraphQL.Queries.UserQueries do
  use GreenFairy.Query

  alias MyApp.GraphQL.Types
  alias MyApp.GraphQL.Inputs

  queries do
    connection :users, Types.User do
      arg :filter, Inputs.UserFilter

      resolve fn _, args, _ ->
        users = MyApp.Accounts.list_users(args[:filter])
        GreenFairy.Field.Connection.from_list(users, args)
      end
    end
  end
end
```

## Connection Enhancements

All connections include these additional fields:

- **`nodes: [T!]`** - Direct access to nodes without edges (GitHub-style)
- **`totalCount: Int!`** - Total matching items (ignoring pagination)
- **`exists: Boolean!`** - Whether any items match the query

```graphql
query {
  users(first: 10) {
    nodes { id name }    # Simpler than edges
    totalCount           # 1523 total users
    exists               # true if any match
    pageInfo { hasNextPage endCursor }
  }
}
```

`totalCount` and `exists` use deferred loading - the COUNT query only runs if these fields are requested.

## Next Steps

- [CQL](cql.md) - Add filtering and sorting to connections
- [Relay](relay.md) - Full Relay specification support
- [Relationships](relationships.md) - DataLoader for efficient loading
- [Operations](operations.md) - Query, mutation, and subscription modules
- [Expose](expose.md) - Auto-generate query fields from types

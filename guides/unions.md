# Unions

Unions allow a field to return one of several distinct types. Unlike interfaces,
union member types don't need to share any common fields.

## Basic Usage

```elixir
defmodule MyApp.GraphQL.Unions.SearchResult do
  use GreenFairy.Union

  alias MyApp.GraphQL.Types

  union "SearchResult" do
    types [Types.User, Types.Post, Types.Comment, Types.Organization]
  end
end
```

This generates:

```graphql
union SearchResult = User | Post | Comment | Organization
```

That's it! No `resolve_type` callback needed - GreenFairy automatically resolves types based on the struct of the returned value.

## Automatic Type Resolution

GreenFairy automatically resolves union types based on the struct of the returned value. When you reference type modules directly, GreenFairy extracts the struct information from those types.

**How it works:**

1. Union declares `types [Types.User, Types.Post]`
2. Each type module has a `struct:` option that maps to a backing module
3. At runtime, when a `%MyApp.User{}` is returned, GreenFairy looks up the struct in the registry and returns `:user`

This means you never need to write manual `resolve_type` callbacks for unions.

## Querying Unions

Use inline fragments to access type-specific fields:

```graphql
query {
  search(query: "elixir") {
    ... on User {
      id
      name
      email
    }
    ... on Post {
      id
      title
      body
    }
    ... on Comment {
      id
      body
      author {
        name
      }
    }
  }
}
```

Or use named fragments:

```graphql
query {
  search(query: "elixir") {
    ...UserFields
    ...PostFields
    ...CommentFields
  }
}

fragment UserFields on User {
  id
  name
  email
}

fragment PostFields on Post {
  id
  title
  body
}

fragment CommentFields on Comment {
  id
  body
}
```

## Using `__typename`

Request the concrete type name:

```graphql
query {
  search(query: "elixir") {
    __typename
    ... on User {
      name
    }
    ... on Post {
      title
    }
  }
}
```

Response:

```json
{
  "data": {
    "search": [
      { "__typename": "User", "name": "John" },
      { "__typename": "Post", "title": "Learning Elixir" }
    ]
  }
}
```

## Common Patterns

### Activity Feed

```elixir
defmodule MyApp.GraphQL.Unions.FeedItem do
  use GreenFairy.Union

  alias MyApp.GraphQL.Types

  union "FeedItem" do
    @desc "An item in the activity feed"
    types [Types.Post, Types.Comment, Types.Like, Types.Follow, Types.Share]
  end
end
```

Query:

```elixir
field :feed, list_of(:feed_item) do
  arg :limit, :integer, default_value: 20

  resolve fn _, args, ctx ->
    {:ok, MyApp.Feed.get_items(ctx[:current_user], args)}
  end
end
```

### Mutation Results

For mutations that can return different result types:

```elixir
defmodule MyApp.GraphQL.Unions.AuthResult do
  use GreenFairy.Union

  alias MyApp.GraphQL.Types

  union "AuthResult" do
    types [Types.AuthSuccess, Types.AuthError, Types.MfaRequired]
  end
end
```

Usage:

```elixir
field :login, :auth_result do
  arg :email, non_null(:string)
  arg :password, non_null(:string)

  resolve fn _, args, _ ->
    case MyApp.Auth.login(args) do
      {:ok, session} -> {:ok, %AuthSuccess{token: session.token, user: session.user}}
      {:mfa_required, token} -> {:ok, %MfaRequired{mfa_token: token}}
      {:error, reason} -> {:ok, %AuthError{error: reason}}
    end
  end
end
```

Query:

```graphql
mutation {
  login(email: "user@example.com", password: "secret") {
    ... on AuthSuccess {
      token
      user {
        id
        name
      }
    }
    ... on AuthError {
      error
    }
    ... on MfaRequired {
      mfaToken
    }
  }
}
```

### Media Types

```elixir
defmodule MyApp.GraphQL.Unions.Media do
  use GreenFairy.Union

  alias MyApp.GraphQL.Types

  union "Media" do
    types [Types.Image, Types.Video, Types.Audio, Types.Document]
  end
end
```

### Notification Payload

```elixir
defmodule MyApp.GraphQL.Unions.NotificationPayload do
  use GreenFairy.Union

  alias MyApp.GraphQL.Types

  union "NotificationPayload" do
    types [Types.User, Types.Post, Types.Comment, Types.Order, Types.Message]
  end
end
```

## Advanced: Custom Type Resolution

In rare cases where automatic resolution isn't sufficient (e.g., returning plain maps instead of structs), you can provide a custom `resolve_type` callback:

```elixir
union "SearchResult" do
  types [Types.User, Types.Post, Types.Comment]

  # Only needed for non-struct returns (e.g., plain maps from external APIs)
  resolve_type fn
    %{type: "user"}, _ -> :user
    %{type: "post"}, _ -> :post
    %{type: "comment"}, _ -> :comment
    _, _ -> nil
  end
end
```

Or for pattern matching on field values:

```elixir
union "Media" do
  types [Types.Image, Types.Video, Types.Audio, Types.Document]

  # Resolve based on mime_type field instead of struct
  resolve_type fn
    %{mime_type: "image/" <> _}, _ -> :image
    %{mime_type: "video/" <> _}, _ -> :video
    %{mime_type: "audio/" <> _}, _ -> :audio
    _, _ -> :document
  end
end
```

This is an escape hatch - prefer using structs with automatic resolution.

## Unions vs Interfaces

| Feature | Unions | Interfaces |
|---------|--------|------------|
| Shared fields | No | Yes (required) |
| Type resolution | Automatic | Automatic |
| Member types | Explicit list | Types opt-in via `implements` |
| Best for | Unrelated types | Related types with common fields |

### When to Use Unions

- Search results returning different entity types
- Activity feeds with varied item types
- Mutation results with different outcomes
- Media attachments of different kinds

### When to Use Interfaces

- Entities sharing common fields (id, timestamps)
- Node interface for Relay
- Polymorphic relationships where common fields are queried

## Module Functions

Every union module exports:

| Function | Description |
|----------|-------------|
| `__green_fairy_kind__/0` | Returns `:union` |
| `__green_fairy_identifier__/0` | Returns the type identifier |
| `__green_fairy_definition__/0` | Returns the full definition map |

## Naming Conventions

| GraphQL Name | Elixir Identifier | Module Suggestion |
|--------------|-------------------|-------------------|
| `SearchResult` | `:search_result` | `MyApp.GraphQL.Unions.SearchResult` |
| `FeedItem` | `:feed_item` | `MyApp.GraphQL.Unions.FeedItem` |
| `MediaType` | `:media_type` | `MyApp.GraphQL.Unions.MediaType` |

## Next Steps

- [Interfaces](interfaces.md) - Alternative for types with shared fields
- [Object Types](object-types.md) - Defining union member types
- [Operations](operations.md) - Using unions in queries and mutations

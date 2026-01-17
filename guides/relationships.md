# Relationships and DataLoader

This guide covers how to define relationships between types.

## Automatic Association Loading

GreenFairy automatically batch-loads associations using DataLoader. Just define fields with the appropriate type:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  alias MyApp.GraphQL.Types

  type "User", struct: MyApp.User do
    field :id, non_null(:id)
    field :name, :string

    # Associations - automatically batch-loaded
    field :posts, list_of(Types.Post)
    field :profile, Types.Profile
    field :organization, Types.Organization
  end
end
```

No explicit loaders or resolvers needed. GreenFairy detects associations from your Ecto schema and uses DataLoader automatically.

## Custom Loaders

For advanced cases where you need custom batch loading logic:

```elixir
alias MyApp.GraphQL.Types

type "User", struct: MyApp.User do
  field :id, non_null(:id)

  # Custom loader for computed/aggregated data
  field :recent_activity, list_of(Types.Activity) do
    loader fn users, _args, _ctx ->
      user_ids = Enum.map(users, & &1.id)
      activities = MyApp.Activity.recent_for_users(user_ids)

      Enum.group_by(activities, & &1.user_id)
      |> Map.new(fn {user_id, acts} ->
        user = Enum.find(users, & &1.id == user_id)
        {user, acts}
      end)
    end
  end
end
```

Use `loader` only when you need custom logic. Most associations work automatically.

## Computed Fields

For non-batched computed fields, use `resolve`:

```elixir
field :display_name, :string do
  resolve fn user, _, _ ->
    {:ok, user.name || user.email}
  end
end
```

## N+1 Prevention

GreenFairy automatically prevents N+1 queries. When you query:

```graphql
{
  users {
    id
    posts { title }
  }
}
```

DataLoader batches all post queries into a single `WHERE user_id IN (...)` query.

## Next Steps

- [Connections](connections.md) - Relay-style pagination
- [CQL](cql.md) - Add filtering to association queries
- [Authorization](authorization.md) - Control access to related data

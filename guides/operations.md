# Operations (Query, Mutation, Subscription)

This guide covers how to define Query, Mutation, and Subscription fields.

## Query Module

Query modules group related query fields. Use module references for non-builtin types:

```elixir
defmodule MyApp.GraphQL.Queries.UserQueries do
  use GreenFairy.Query

  alias MyApp.GraphQL.Types

  queries do
    # Relay Node field - automatically resolves any type by GlobalId
    node_field()

    @desc "Get a user by ID"
    field :user, Types.User do
      arg :id, non_null(:id)
      resolve &MyApp.Resolvers.User.get/3
    end

    @desc "List all users"
    field :users, list_of(Types.User) do
      arg :limit, :integer
      arg :offset, :integer
      resolve &MyApp.Resolvers.User.list/3
    end

    @desc "Search users by name"
    field :search_users, list_of(Types.User) do
      arg :query, non_null(:string)
      resolve &MyApp.Resolvers.User.search/3
    end
  end
end
```

## Relay Node Field

The `node_field()` macro generates a Relay-compliant `node(id: ID!)` query field that can resolve any type by its GlobalId:

```elixir
defmodule MyApp.GraphQL.RootQuery do
  use GreenFairy.Query

  queries do
    # Adds: node(id: ID!): Node
    node_field()

    # Your other query fields...
  end
end
```

This enables queries like:

```graphql
query {
  node(id: "VXNlcjoxMjM=") {
    id
    ... on User {
      email
      name
    }
  }
}
```

The `node_field` macro:
1. Decodes the GlobalId to extract the type name and local ID
2. Looks up the corresponding type module
3. Uses the schema's configured repo to fetch the record
4. Returns the record or an error

### Node Resolution Flow

When a `node` query is executed:

1. **GlobalId Decoding**: The ID is decoded using the schema's configured `global_id` implementation (defaults to Base64)
2. **Type Lookup**: The type name is used to find the corresponding GreenFairy type module
3. **Record Fetching**: The record is fetched using `Repo.get(StructModule, local_id)`

### Custom Node Resolver

Types can define custom node resolution by implementing `node_resolver` in the type:

```elixir
type "User", struct: MyApp.User do
  implements GreenFairy.BuiltIns.Node

  node_resolver fn id, ctx ->
    MyApp.Accounts.get_user_with_permissions(id, ctx[:current_user])
  end

  field :id, non_null(:id)
  field :email, :string
end
```

## Mutation Module

Mutation modules group related mutation fields:

```elixir
defmodule MyApp.GraphQL.Mutations.UserMutations do
  use GreenFairy.Mutation

  alias MyApp.GraphQL.Types
  alias MyApp.GraphQL.Inputs

  mutations do
    @desc "Create a new user"
    field :create_user, Types.User do
      arg :input, non_null(Inputs.CreateUserInput)

      middleware MyApp.Middleware.Authenticate
      resolve &MyApp.Resolvers.User.create/3
    end

    @desc "Update an existing user"
    field :update_user, Types.User do
      arg :id, non_null(:id)
      arg :input, non_null(Inputs.UpdateUserInput)

      middleware MyApp.Middleware.Authenticate
      middleware MyApp.Middleware.Authorize, :owner
      resolve &MyApp.Resolvers.User.update/3
    end

    @desc "Delete a user"
    field :delete_user, :boolean do
      arg :id, non_null(:id)

      middleware MyApp.Middleware.Authenticate
      middleware MyApp.Middleware.Authorize, :admin
      resolve &MyApp.Resolvers.User.delete/3
    end
  end
end
```

## Subscription Module

Subscription modules define real-time event streams:

```elixir
defmodule MyApp.GraphQL.Subscriptions.UserSubscriptions do
  use GreenFairy.Subscription

  alias MyApp.GraphQL.Types

  subscriptions do
    @desc "Subscribe to user updates"
    field :user_updated, Types.User do
      arg :user_id, :id

      config fn args, _info ->
        {:ok, topic: args[:user_id] || "*"}
      end

      trigger :update_user, topic: fn user ->
        ["user_updated:#{user.id}", "user_updated:*"]
      end
    end

    @desc "Subscribe to new users"
    field :user_created, Types.User do
      config fn _args, _info ->
        {:ok, topic: "new_users"}
      end

      trigger :create_user, topic: fn _user ->
        "new_users"
      end
    end
  end
end
```

## Assembling in the Schema

With GreenFairy's auto-discovery, you typically don't need manual imports:

```elixir
defmodule MyApp.GraphQL.Schema do
  use GreenFairy.Schema,
    discover: [MyApp.GraphQL],
    repo: MyApp.Repo
end
```

For manual assembly:

```elixir
defmodule MyApp.GraphQL.Schema do
  use Absinthe.Schema

  # Import type modules
  import_types MyApp.GraphQL.Types.User
  import_types MyApp.GraphQL.Inputs.CreateUserInput
  import_types MyApp.GraphQL.Inputs.UpdateUserInput

  # Import operation modules
  import_types MyApp.GraphQL.Queries.UserQueries
  import_types MyApp.GraphQL.Mutations.UserMutations
  import_types MyApp.GraphQL.Subscriptions.UserSubscriptions

  query do
    import_fields :__green_fairy_queries__
  end

  mutation do
    import_fields :__green_fairy_mutations__
  end

  subscription do
    import_fields :__green_fairy_subscriptions__
  end
end
```

## Middleware

Middleware can be applied at the field level:

```elixir
field :protected_data, :string do
  middleware MyApp.Middleware.Authenticate
  middleware MyApp.Middleware.RateLimit, limit: 100
  resolve fn _, _, _ -> {:ok, "secret"} end
end
```

### Built-in Middleware

GreenFairy provides some helper middleware:

```elixir
# Require a specific capability
middleware GreenFairy.Field.Middleware.require_capability(:admin)

# Cache the result (placeholder - implement your own caching)
middleware GreenFairy.Field.Middleware.cache(ttl: 300)
```

## Publishing Subscription Events

To trigger subscriptions from mutations:

```elixir
defmodule MyApp.Resolvers.User do
  def update(%{id: id, input: input}, _, _) do
    with {:ok, user} <- MyApp.Accounts.update_user(id, input) do
      # Publish to subscribers
      Absinthe.Subscription.publish(
        MyApp.Endpoint,
        user,
        user_updated: "user_updated:#{user.id}"
      )

      {:ok, user}
    end
  end
end
```

## Multiple Operation Modules

You can have multiple query/mutation/subscription modules. Just import them all:

```elixir
import_types MyApp.GraphQL.Queries.UserQueries
import_types MyApp.GraphQL.Queries.PostQueries
import_types MyApp.GraphQL.Queries.CommentQueries

query do
  # Fields from all query modules are imported
  import_fields :__green_fairy_queries__
end
```

Note: If using multiple modules, each will define its own `:__green_fairy_queries__` object. You may need to rename them or manually import fields.

## Next Steps

- [Expose Guide](expose.md) - Auto-generate query fields from types
- [Connections Guide](connections.md) - Query-level pagination
- [Authorization](authorization.md) - Protect mutations
- [CQL](cql.md) - Add filtering to queries
- [Relay](relay.md) - Relay-compliant mutations

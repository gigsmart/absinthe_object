# Global Configuration

GreenFairy supports global configuration for authorization and node resolution that applies across all types in your schema.

## Global Authorization

Define a global authorization function that runs before type-specific authorization:

```elixir
defmodule MyApp.GraphQL.Schema do
  use GreenFairy.Schema, discover: [MyApp.GraphQL]
  use GreenFairy.Relay, repo: MyApp.Repo

  use GreenFairy.Config,
    authorize: fn object, ctx ->
      # This runs before type-specific authorization
      if ctx[:current_user] do
        :all  # Allow all fields, let type-level auth refine
      else
        :none  # Block everything for unauthenticated users
      end
    end
end
```

### Authorization with Path Info

For more complex authorization that needs access path information:

```elixir
use GreenFairy.Config,
  authorize_with_info: fn object, ctx, info ->
    # info contains: path, field, parent, parents
    current_user = ctx[:current_user]

    cond do
      is_nil(current_user) -> :none
      current_user.admin -> :all
      info.field == :password_hash -> :none
      true -> :all
    end
  end
```

### Authorization Composition

When both global and type-level authorization are defined:

1. Global authorization runs first
2. If global returns `:none`, the object is hidden entirely
3. If global returns `:all` or a field list, type-level authorization runs
4. The final visible fields are the intersection of both results

```elixir
# Schema-level
use GreenFairy.Config,
  authorize: fn _object, ctx ->
    if ctx[:current_user], do: :all, else: [:id, :name]
  end

# Type-level
type "User", struct: MyApp.User do
  authorize fn user, ctx ->
    current_user = ctx[:current_user]

    if current_user && current_user.id == user.id do
      :all
    else
      [:id, :name, :avatar]
    end
  end

  field :id, non_null(:id)
  field :name, :string
  field :email, :string      # Only visible to self
  field :avatar, :string     # Public
  field :phone, :string      # Only visible to self
end
```

For an unauthenticated user: intersection of `[:id, :name]` and any type result = `[:id, :name]`
For viewing someone else: intersection of `:all` and `[:id, :name, :avatar]` = `[:id, :name, :avatar]`
For viewing self: intersection of `:all` and `:all` = `:all`

## Default Node Resolution

Configure how nodes are fetched by default:

```elixir
use GreenFairy.Relay,
  node_resolver: fn type_module, id, ctx ->
    struct = type_module.__green_fairy_struct__()
    repo = ctx[:repo] || MyApp.Repo
    repo.get(struct, id)
  end
```

The resolver receives:
- `type_module` - The GraphQL type module (e.g., `MyApp.GraphQL.Types.User`)
- `id` - The local ID (already parsed to integer if numeric)
- `ctx` - The Absinthe context

Individual types can still override with `node_resolver`:

```elixir
type "User", struct: MyApp.User do
  implements GreenFairy.BuiltIns.Node

  node_resolver fn id, ctx ->
    # Custom resolution for this type only
    MyApp.Accounts.get_user_with_permissions(id, ctx[:current_user])
  end

  global_id :id
  field :email, :string
end
```

## Configuration Options

### GreenFairy.Config Options

| Option | Description |
|--------|-------------|
| `:authorize` | Global auth function `fn object, ctx -> :all \| :none \| [fields] end` |
| `:authorize_with_info` | Auth with path info `fn object, ctx, info -> ... end` |

### GreenFairy.Relay Options

| Option | Description |
|--------|-------------|
| `:repo` | Default Ecto repo for node resolution |
| `:node_resolver` | Default resolver `fn type_module, id, ctx -> result end` |

## Helper Functions

The `GreenFairy.Config` module provides helper functions:

```elixir
alias GreenFairy.Config

# Check if global auth is configured
Config.has_global_auth?(MyApp.GraphQL.Schema)

# Run global auth manually
Config.run_global_auth(schema, object, ctx)
Config.run_global_auth(schema, object, ctx, info)

# Compose two auth results (intersection)
Config.compose_auth(:all, [:id, :name])     #=> [:id, :name]
Config.compose_auth([:id, :name], [:id])    #=> [:id]
Config.compose_auth(:none, :all)            #=> :none
```

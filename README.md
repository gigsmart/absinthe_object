# Absinthe.Object

[![Hex.pm](https://img.shields.io/hexpm/v/absinthe_object.svg)](https://hex.pm/packages/absinthe_object)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/absinthe_object)

A cleaner DSL for GraphQL schema definitions built on [Absinthe](https://github.com/absinthe-graphql/absinthe).

## Overview

Absinthe.Object provides a streamlined way to define GraphQL schemas following SOLID principles:

- **One module = one type** - Each GraphQL type lives in its own file
- **Convention over configuration** - Smart defaults reduce boilerplate
- **Auto-discovery** - Types are automatically discovered and registered
- **DataLoader integration** - Relationship macros generate efficient batched queries
- **Relay connections** - Built-in support for cursor-based pagination
- **Authorization** - Simple, type-owned field visibility control
- **CQL (Filterable Queries)** - Automatic filter input generation for Ecto schemas
- **Extensible** - Build custom DSL extensions on top

## Installation

Add `absinthe_object` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:absinthe_object, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Define a Type

```elixir
defmodule MyApp.GraphQL.Types.User do
  use Absinthe.Object.Type

  type "User", struct: MyApp.User do
    implements MyApp.GraphQL.Interfaces.Node

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string

    # Computed field with resolver
    field :display_name, :string do
      resolve fn user, _, _ ->
        {:ok, user.name || user.email}
      end
    end

    # Association fields - adapter provides DataLoader resolution
    field :organization, :organization
    field :posts, list_of(:post)

    # Relay-style pagination
    connection :friends, MyApp.GraphQL.Types.User do
      edge do
        field :friendship_date, :datetime
      end
    end
  end
end
```

### Define an Interface

```elixir
defmodule MyApp.GraphQL.Interfaces.Node do
  use Absinthe.Object.Interface

  interface "Node" do
    @desc "A globally unique identifier"
    field :id, non_null(:id)
    # resolve_type is auto-generated from types that implement this interface!
  end
end
```

The `resolve_type` is automatically generated based on types that call `implements` with a `struct:` option. You can still provide a manual `resolve_type` if you need custom logic.

### Define Input Types

```elixir
defmodule MyApp.GraphQL.Inputs.CreateUserInput do
  use Absinthe.Object.Input

  input "CreateUserInput" do
    field :email, non_null(:string)
    field :name, :string
  end
end
```

### Define Enums

```elixir
defmodule MyApp.GraphQL.Enums.UserRole do
  use Absinthe.Object.Enum

  enum "UserRole" do
    value :admin
    value :moderator
    value :user
    value :guest, as: "GUEST_USER"
  end
end
```

### Define Queries

```elixir
defmodule MyApp.GraphQL.Queries.UserQueries do
  use Absinthe.Object.Query

  queries do
    field :user, :user do
      arg :id, non_null(:id)
      resolve &MyApp.Resolvers.User.get/3
    end

    field :users, list_of(:user) do
      resolve &MyApp.Resolvers.User.list/3
    end
  end
end
```

### Define Mutations

```elixir
defmodule MyApp.GraphQL.Mutations.UserMutations do
  use Absinthe.Object.Mutation

  mutations do
    field :create_user, :user do
      arg :input, non_null(:create_user_input)

      middleware MyApp.Middleware.Authenticate
      resolve &MyApp.Resolvers.User.create/3
    end
  end
end
```

### Assemble the Schema

```elixir
defmodule MyApp.GraphQL.Schema do
  use Absinthe.Object.Schema,
    discover: [MyApp.GraphQL]
end
```

That's it! The schema automatically:
- Discovers all types, interfaces, inputs, enums, scalars under `MyApp.GraphQL`
- Imports them all
- Generates root query/mutation/subscription types from your operation modules
- No `import_types` or `import_fields` needed!

## Authorization

Absinthe.Object provides simple, type-owned authorization. Each type controls which fields are visible based on the object data and context.

### Basic Authorization

```elixir
defmodule MyApp.GraphQL.Types.User do
  use Absinthe.Object.Type

  type "User", struct: MyApp.User do
    # Define which fields are visible based on object and context
    authorize fn user, ctx ->
      cond do
        ctx[:current_user]?.admin -> :all
        ctx[:current_user]?.id == user.id -> [:id, :name, :email]
        true -> [:id, :name]  # Public fields only
      end
    end

    field :id, non_null(:id)
    field :name, :string
    field :email, :string         # Only visible to self or admin
    field :ssn, :string           # Only visible to admin
    field :password_hash, :string # Only visible to admin
  end
end
```

The authorize callback receives `(object, context)` and returns:
- `:all` - All fields are visible
- `:none` - Object is hidden entirely
- `[:field1, :field2]` - Only listed fields are visible

### Authorization with Path Info

For complex authorization that depends on how the object was accessed:

```elixir
type "Post", struct: MyApp.Post do
  authorize fn post, ctx, info ->
    # info contains: path, field, parent, parents
    parent_is_author = info.parent && info.parent.id == post.author_id

    cond do
      ctx[:current_user]?.admin -> :all
      parent_is_author -> :all  # Accessing through author's profile
      ctx[:current_user]?.id == post.author_id -> [:id, :title, :content]
      true -> [:id, :title]
    end
  end

  # ...fields
end
```

### Input Authorization

Control which input fields users can submit:

```elixir
defmodule MyApp.GraphQL.Inputs.UpdateUserInput do
  use Absinthe.Object.Input

  input "UpdateUserInput" do
    authorize fn input, ctx ->
      if ctx[:current_user]?.admin do
        :all
      else
        [:name, :email]  # Regular users can only update these
      end
    end

    field :name, :string
    field :email, :string
    field :role, :user_role       # Admin only
    field :verified, :boolean     # Admin only
  end
end
```

Use `__filter_input__/2` in your resolver to validate:

```elixir
def update_user(_, %{input: input}, %{context: ctx}) do
  case UpdateUserInput.__filter_input__(input, ctx) do
    {:ok, filtered_input} -> # proceed with filtered_input
    {:error, {:unauthorized_fields, fields}} -> # handle error
  end
end
```

## Field Resolution

All fields use the `field` macro with resolution determined by:

- **`resolve`** - Single-item resolver (receives one parent)
- **`loader`** - Batch loader (receives list of parents, returns map)
- **Default** - Adapter provides default (Map.get for scalars, DataLoader for associations)

A field cannot have both `resolve` and `loader` - they are mutually exclusive.

### Resolvers

Use `resolve` for computed fields that need per-item logic:

```elixir
field :display_name, :string do
  resolve fn user, _, _ ->
    {:ok, user.name || user.email}
  end
end
```

### Batch Loaders

Use `loader` for efficient batch loading:

```elixir
type "Worker", struct: MyApp.Worker do
  field :nearby_gigs, list_of(:gig) do
    arg :location, non_null(:geo_point)
    arg :radius, :integer, default_value: 10

    # Batch loader receives all parents at once
    loader fn workers, args, ctx ->
      worker_ids = Enum.map(workers, & &1.id)
      gigs = MyApp.Gigs.find_nearby(worker_ids, args.location, args.radius)

      # Return a map of parent -> result
      Enum.group_by(gigs, & &1.worker_id)
      |> Map.new(fn {worker_id, worker_gigs} ->
        worker = Enum.find(workers, & &1.id == worker_id)
        {worker, worker_gigs}
      end)
    end
  end

  field :analytics, :analytics do
    loader fn workers, _args, _ctx ->
      MyApp.Analytics.batch_load(Enum.map(workers, & &1.id))
      |> Map.new(fn a ->
        worker = Enum.find(workers, & &1.id == a.worker_id)
        {worker, a}
      end)
    end
  end
end
```

## Custom Scalars with CQL Operators

Define custom scalar types with their own filtering operators:

```elixir
defmodule MyApp.GraphQL.Scalars.GeoPoint do
  use Absinthe.Object.Scalar

  scalar "GeoPoint" do
    parse fn
      %Absinthe.Blueprint.Input.Object{fields: fields}, _ ->
        lat = Enum.find_value(fields, fn %{name: n, input_value: %{value: v}} ->
          if n == "lat", do: v
        end)
        lng = Enum.find_value(fields, fn %{name: n, input_value: %{value: v}} ->
          if n == "lng", do: v
        end)
        {:ok, %{lat: lat, lng: lng}}
      _, _ -> :error
    end

    serialize fn point ->
      %{lat: point.lat, lng: point.lng}
    end

    # Define available CQL operators
    operators [:eq, :near, :within_radius, :within_bounds]

    # Define how each operator applies filters
    filter :near, fn field, value, opts ->
      distance = opts[:distance] || 10_000
      {:geo, :st_dwithin, field, value, distance}
    end

    filter :within_radius, fn field, %{center: center, radius: radius} ->
      {:geo, :st_dwithin, field, center, radius}
    end

    filter :within_bounds, fn field, bounds ->
      {:geo, :st_within, field, bounds}
    end
  end
end
```

## CQL (Filterable Queries)

The CQL extension automatically generates filter inputs for Ecto schemas:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use Absinthe.Object.Type
  alias Absinthe.Object.Extensions.CQL

  type "User", struct: MyApp.User do
    use CQL  # Enable CQL for this type

    # Authorization integrates with CQL
    authorize fn user, ctx ->
      if ctx[:current_user]?.admin, do: :all, else: [:id, :name]
    end

    field :id, non_null(:id)
    field :name, :string
    field :email, :string
    field :age, :integer

    # Custom filter for computed fields
    custom_filter :full_name, [:eq, :contains], fn query, op, value ->
      case op do
        :eq -> from u in query, where: fragment("concat(?, ' ', ?)", u.first_name, u.last_name) == ^value
        :contains -> from u in query, where: ilike(fragment("concat(?, ' ', ?)", u.first_name, u.last_name), ^"%#{value}%")
      end
    end
  end
end
```

This generates a `UserFilter` input type automatically with operators appropriate for each field type.

## Directory Structure

We recommend organizing your GraphQL modules like this:

```
lib/my_app/graphql/
├── schema.ex                    # Main schema module
├── types/                       # Object types
│   ├── user.ex
│   └── post.ex
├── interfaces/                  # Interface definitions
│   └── node.ex
├── inputs/                      # Input types
│   └── create_user_input.ex
├── enums/                       # Enum definitions
│   └── user_role.ex
├── unions/                      # Union types
│   └── search_result.ex
├── scalars/                     # Custom scalars
│   └── datetime.ex
├── queries/                     # Query modules
│   └── user_queries.ex
├── mutations/                   # Mutation modules
│   └── user_mutations.ex
├── subscriptions/               # Subscription modules
│   └── user_subscriptions.ex
└── resolvers/                   # Resolver logic
    └── user_resolver.ex
```

## Available Modules

### Core DSL
- `Absinthe.Object.Type` - Define object types
- `Absinthe.Object.Interface` - Define interfaces
- `Absinthe.Object.Input` - Define input types
- `Absinthe.Object.Enum` - Define enums
- `Absinthe.Object.Union` - Define unions
- `Absinthe.Object.Scalar` - Define custom scalars

### Operations
- `Absinthe.Object.Query` - Define query fields
- `Absinthe.Object.Mutation` - Define mutation fields
- `Absinthe.Object.Subscription` - Define subscription fields

### Schema & Discovery
- `Absinthe.Object.Schema` - Schema with auto-discovery
- `Absinthe.Object.Discovery` - Type discovery utilities

### Field Helpers
- `Absinthe.Object.Field.Connection` - Relay-style pagination
- `Absinthe.Object.Field.Dataloader` - DataLoader integration
- `Absinthe.Object.Field.Loader` - Custom batch loaders
- `Absinthe.Object.Field.Middleware` - Middleware helpers

### Extensions
- `Absinthe.Object.Extensions.CQL` - Automatic filter input generation
- `Absinthe.Object.Extensions.Auth` - Authentication middleware helpers

### Built-ins
- `Absinthe.Object.BuiltIns.Node` - Relay Node interface
- `Absinthe.Object.BuiltIns.PageInfo` - Connection PageInfo type
- `Absinthe.Object.BuiltIns.Timestampable` - Timestamp interface

## Documentation

Full documentation is available at [HexDocs](https://hexdocs.pm/absinthe_object).

### Guides

- [Getting Started](https://hexdocs.pm/absinthe_object/getting-started.html)
- [Types](https://hexdocs.pm/absinthe_object/types.html)
- [Authorization](https://hexdocs.pm/absinthe_object/authorization.html)
- [Relationships and DataLoader](https://hexdocs.pm/absinthe_object/relationships.html)
- [CQL (Filterable Queries)](https://hexdocs.pm/absinthe_object/cql.html)
- [Connections (Pagination)](https://hexdocs.pm/absinthe_object/connections.html)
- [Operations](https://hexdocs.pm/absinthe_object/operations.html)

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create new Pull Request

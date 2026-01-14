<p align="center">
  <img src="assets/logo.svg" alt="GreenFairy Logo" width="200">
</p>

<h1 align="center">GreenFairy</h1>

<p align="center">
  <a href="https://hex.pm/packages/green_fairy"><img src="https://img.shields.io/hexpm/v/green_fairy.svg" alt="Hex.pm"></a>
  <a href="https://hexdocs.pm/green_fairy"><img src="https://img.shields.io/badge/docs-hexdocs-blue.svg" alt="Documentation"></a>
</p>

<p align="center">
  A cleaner DSL for GraphQL schema definitions built on <a href="https://github.com/absinthe-graphql/absinthe">Absinthe</a>.
</p>

## Overview

GreenFairy provides a streamlined way to define GraphQL schemas following SOLID principles:

- **One module = one type** - Each GraphQL type lives in its own file
- **Convention over configuration** - Smart defaults reduce boilerplate
- **Auto-discovery** - Types are automatically discovered and registered
- **DataLoader integration** - Relationship macros generate efficient batched queries
- **Relay connections** - Built-in support for cursor-based pagination
- **Authorization** - Simple, type-owned field visibility control
- **CQL (Filterable Queries)** - Automatic filter input generation for Ecto schemas
- **Extensible** - Build custom DSL extensions on top

## Installation

Add `green_fairy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:green_fairy, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Define a Type

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

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
  use GreenFairy.Interface

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
  use GreenFairy.Input

  input "CreateUserInput" do
    field :email, non_null(:string)
    field :name, :string
  end
end
```

### Define Enums

```elixir
defmodule MyApp.GraphQL.Enums.UserRole do
  use GreenFairy.Enum

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
  use GreenFairy.Query

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
  use GreenFairy.Mutation

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
  use GreenFairy.Schema,
    discover: [MyApp.GraphQL]
end
```

That's it! The schema automatically:
- Discovers all types, interfaces, inputs, enums, scalars under `MyApp.GraphQL`
- Imports them all
- Generates root query/mutation/subscription types from your operation modules
- No `import_types` or `import_fields` needed!

## Authorization

GreenFairy provides simple, type-owned authorization. Each type controls which fields are visible based on the object data and context.

### Basic Authorization

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    # Define which fields are visible based on object and context
    authorize fn user, ctx ->
      current_user = ctx[:current_user]

      cond do
        current_user && current_user.admin -> :all
        current_user && current_user.id == user.id -> [:id, :name, :email]
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
    current_user = ctx[:current_user]
    parent_is_author = info.parent && info.parent.id == post.author_id

    cond do
      current_user && current_user.admin -> :all
      parent_is_author -> :all  # Accessing through author's profile
      current_user && current_user.id == post.author_id -> [:id, :title, :content]
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
  use GreenFairy.Input

  input "UpdateUserInput" do
    authorize fn input, ctx ->
      current_user = ctx[:current_user]

      if current_user && current_user.admin do
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
    arg :location, non_null(:point)  # Uses Geo.Point scalar
    arg :radius_meters, :integer, default_value: 1000

    # Batch loader receives all parents at once
    loader fn workers, args, _ctx ->
      # Pre-build a map for O(1) lookups instead of O(n) Enum.find
      workers_by_id = Map.new(workers, &{&1.id, &1})
      worker_ids = Map.keys(workers_by_id)

      gigs = MyApp.Gigs.find_nearby(worker_ids, args.location, args.radius_meters)

      # Return a map of parent -> result
      Enum.group_by(gigs, & &1.worker_id)
      |> Map.new(fn {worker_id, worker_gigs} ->
        {workers_by_id[worker_id], worker_gigs}
      end)
    end
  end

  field :analytics, :analytics do
    loader fn workers, _args, _ctx ->
      workers_by_id = Map.new(workers, &{&1.id, &1})

      MyApp.Analytics.batch_load(Map.keys(workers_by_id))
      |> Map.new(fn a ->
        {workers_by_id[a.worker_id], a}
      end)
    end
  end
end
```

## Custom Scalars with CQL Operators

Define custom scalar types with their own filtering operators. This example uses
the [`geo`](https://hex.pm/packages/geo) library for geographic data:

```elixir
defmodule MyApp.GraphQL.Scalars.Point do
  use GreenFairy.Scalar

  @moduledoc "GraphQL scalar for Geo.Point from the geo library"

  scalar "Point" do
    description "A geographic point (longitude, latitude)"

    parse fn
      %Absinthe.Blueprint.Input.Object{fields: fields}, _ ->
        lng = get_field(fields, "lng") || get_field(fields, "longitude")
        lat = get_field(fields, "lat") || get_field(fields, "latitude")
        {:ok, %Geo.Point{coordinates: {lng, lat}, srid: 4326}}
      _, _ ->
        :error
    end

    serialize fn %Geo.Point{coordinates: {lng, lat}} ->
      %{lng: lng, lat: lat}
    end

    # Define available CQL operators
    operators [:eq, :near, :within_distance]

    # PostGIS-compatible filter using ST_DWithin
    filter :near, fn field, %Geo.Point{} = point, opts ->
      distance_meters = opts[:distance] || 1000
      {:fragment, "ST_DWithin(?::geography, ?::geography, ?)", field, point, distance_meters}
    end

    filter :within_distance, fn field, %{point: point, distance: distance} ->
      {:fragment, "ST_DWithin(?::geography, ?::geography, ?)", field, point, distance}
    end
  end

  defp get_field(fields, name) do
    Enum.find_value(fields, fn %{name: n, input_value: %{value: v}} ->
      if n == name, do: v
    end)
  end
end
```

## CQL (Filterable Queries)

The CQL extension automatically generates filter inputs for Ecto schemas:

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type
  alias GreenFairy.Extensions.CQL

  type "User", struct: MyApp.User do
    use CQL  # Enable CQL for this type

    # Authorization integrates with CQL
    authorize fn user, ctx ->
      current_user = ctx[:current_user]
      if current_user && current_user.admin, do: :all, else: [:id, :name]
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

## Relay Support

GreenFairy provides built-in Relay specification support, eliminating the need for `absinthe_relay`:

```elixir
defmodule MyApp.GraphQL.Schema do
  use GreenFairy.Schema, discover: [MyApp.GraphQL]
  use GreenFairy.Relay, repo: MyApp.Repo
end
```

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type
  import GreenFairy.Relay.Field

  type "User", struct: MyApp.User do
    implements GreenFairy.BuiltIns.Node

    global_id :id  # Generates globally unique ID
    field :email, :string

    connection :friends, MyApp.GraphQL.Types.User
  end
end
```

Features included:
- **Global IDs** - `global_id` macro for Relay-compliant object identification
- **Node Query** - `node(id: ID!)` and `nodes(ids: [ID!]!)` query fields
- **Connections** - Built-in cursor-based pagination
- **Relay Mutations** - `relay_mutation` macro with `clientMutationId` support

See the [Relay Guide](https://hexdocs.pm/green_fairy/relay.html) for full documentation.

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
- `GreenFairy.Type` - Define object types
- `GreenFairy.Interface` - Define interfaces
- `GreenFairy.Input` - Define input types
- `GreenFairy.Enum` - Define enums
- `GreenFairy.Union` - Define unions
- `GreenFairy.Scalar` - Define custom scalars

### Operations
- `GreenFairy.Query` - Define query fields
- `GreenFairy.Mutation` - Define mutation fields
- `GreenFairy.Subscription` - Define subscription fields

### Schema & Discovery
- `GreenFairy.Schema` - Schema with auto-discovery
- `GreenFairy.Discovery` - Type discovery utilities

### Field Helpers
- `GreenFairy.Field.Connection` - Relay-style pagination
- `GreenFairy.Field.Dataloader` - DataLoader integration
- `GreenFairy.Field.Loader` - Custom batch loaders
- `GreenFairy.Field.Middleware` - Middleware helpers

### Extensions
- `GreenFairy.Extensions.CQL` - Automatic filter input generation
- `GreenFairy.Extensions.Auth` - Authentication middleware helpers

### Relay Support
- `GreenFairy.Relay` - Full Relay specification support
- `GreenFairy.Relay.GlobalId` - Global ID encoding/decoding
- `GreenFairy.Relay.Node` - Node query field
- `GreenFairy.Relay.Field` - Field helpers (global_id, node_resolver)
- `GreenFairy.Relay.Mutation` - Relay mutation helpers

### Built-ins
- `GreenFairy.BuiltIns.Node` - Relay Node interface
- `GreenFairy.BuiltIns.PageInfo` - Connection PageInfo type
- `GreenFairy.BuiltIns.Timestampable` - Timestamp interface

## Documentation

Full documentation is available at [HexDocs](https://hexdocs.pm/green_fairy).

### Guides

- [Getting Started](https://hexdocs.pm/green_fairy/getting-started.html)
- [Types](https://hexdocs.pm/green_fairy/types.html)
- [Authorization](https://hexdocs.pm/green_fairy/authorization.html)
- [Relationships and DataLoader](https://hexdocs.pm/green_fairy/relationships.html)
- [CQL (Filterable Queries)](https://hexdocs.pm/green_fairy/cql.html)
- [Connections (Pagination)](https://hexdocs.pm/green_fairy/connections.html)
- [Relay Support](https://hexdocs.pm/green_fairy/relay.html)
- [Global Configuration](https://hexdocs.pm/green_fairy/global-config.html)
- [Operations](https://hexdocs.pm/green_fairy/operations.html)

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create new Pull Request

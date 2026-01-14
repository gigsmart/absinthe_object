# Types

This guide covers all the type modules available in GreenFairy.

## Object Types

Object types are the most common type in GraphQL. They represent entities in your domain.

```elixir
defmodule MyApp.GraphQL.Types.User do
  use GreenFairy.Type

  type "User", struct: MyApp.User do
    @desc "A user in the system"

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, :string

    # Computed field
    field :display_name, :string do
      resolve fn user, _, _ ->
        {:ok, user.name || user.email}
      end
    end
  end
end
```

### Options

- `:struct` - The backing Elixir struct (used for resolve_type in interfaces)
- `:description` - Description of the type

### Authorization

Types can control field visibility with the `authorize` callback:

```elixir
type "User", struct: MyApp.User do
  authorize fn user, ctx ->
    cond do
      ctx[:current_user]?.admin -> :all
      ctx[:current_user]?.id == user.id -> [:id, :name, :email]
      true -> [:id, :name]
    end
  end

  field :id, non_null(:id)
  field :name, :string
  field :email, :string
  field :ssn, :string  # Only visible to admin
end
```

See the [Authorization Guide](authorization.html) for details.

### Field Resolution

All fields use the `field` macro. Resolution is determined by:

- **`resolve`** - Single-item resolver (receives one parent)
- **`loader`** - Batch loader (receives list of parents, returns map)
- **Default** - Adapter provides default (Map.get for scalars, DataLoader for associations)

A field cannot have both `resolve` and `loader` - they are mutually exclusive.

```elixir
type "Worker", struct: MyApp.Worker do
  # Association fields - adapter handles loading
  field :organization, :organization
  field :projects, list_of(:project)

  # Computed field with resolver
  field :display_name, :string do
    resolve fn worker, _, _ ->
      {:ok, worker.name || worker.email}
    end
  end

  # Custom batch loader
  field :nearby_gigs, list_of(:gig) do
    arg :location, non_null(:point)  # Uses Geo.Point scalar
    arg :radius_meters, :integer, default_value: 1000

    loader fn workers, args, ctx ->
      worker_ids = Enum.map(workers, & &1.id)
      gigs = MyApp.Gigs.find_nearby(worker_ids, args.location, args.radius_meters)

      Enum.group_by(gigs, & &1.worker_id)
      |> Map.new(fn {worker_id, worker_gigs} ->
        worker = Enum.find(workers, & &1.id == worker_id)
        {worker, worker_gigs}
      end)
    end
  end
end
```

## Interfaces

Interfaces define a common set of fields that types can implement.

```elixir
defmodule MyApp.GraphQL.Interfaces.Node do
  use GreenFairy.Interface

  interface "Node" do
    @desc "A globally unique identifier"
    field :id, non_null(:id)

    resolve_type fn
      %MyApp.User{}, _ -> :user
      %MyApp.Post{}, _ -> :post
      _, _ -> nil
    end
  end
end
```

Types implement interfaces using the `implements` macro:

```elixir
type "User", struct: MyApp.User do
  implements MyApp.GraphQL.Interfaces.Node

  field :id, non_null(:id)
  # ... other fields
end
```

## Input Types

Input types are used for complex arguments, typically in mutations.

```elixir
defmodule MyApp.GraphQL.Inputs.CreateUserInput do
  use GreenFairy.Input

  input "CreateUserInput" do
    field :email, non_null(:string)
    field :first_name, :string
    field :last_name, :string
    field :role, :user_role  # Reference to an enum
  end
end
```

### Input Authorization

Control which fields different users can submit:

```elixir
defmodule MyApp.GraphQL.Inputs.UpdateUserInput do
  use GreenFairy.Input

  input "UpdateUserInput" do
    authorize fn _input, ctx ->
      if ctx[:current_user]?.admin do
        :all
      else
        [:name, :email]  # Regular users can only update these
      end
    end

    field :name, :string
    field :email, :string
    field :role, :user_role    # Admin only
    field :verified, :boolean  # Admin only
  end
end
```

Validate in your resolver:

```elixir
case UpdateUserInput.__filter_input__(input, ctx) do
  {:ok, validated} -> # proceed
  {:error, {:unauthorized_fields, fields}} -> # handle error
end
```

## Enums

Enums define a set of allowed values.

```elixir
defmodule MyApp.GraphQL.Enums.UserRole do
  use GreenFairy.Enum

  enum "UserRole" do
    value :admin
    value :moderator
    value :user
    value :guest, as: "GUEST_USER"  # Custom GraphQL name
  end
end
```

## Unions

Unions allow a field to return one of several types.

```elixir
defmodule MyApp.GraphQL.Unions.SearchResult do
  use GreenFairy.Union

  union "SearchResult" do
    types [:user, :post, :comment]

    resolve_type fn
      %MyApp.User{}, _ -> :user
      %MyApp.Post{}, _ -> :post
      %MyApp.Comment{}, _ -> :comment
      _, _ -> nil
    end
  end
end
```

## Scalars

Custom scalars define how values are parsed and serialized.

```elixir
defmodule MyApp.GraphQL.Scalars.DateTime do
  use GreenFairy.Scalar

  scalar "DateTime" do
    parse fn
      %Absinthe.Blueprint.Input.String{value: value} ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _} -> {:ok, datetime}
          _ -> :error
        end
      _ -> :error
    end

    serialize fn datetime ->
      DateTime.to_iso8601(datetime)
    end
  end
end
```

### Scalars with CQL Operators

Define custom filtering operators for your scalar types. This example uses
the [`geo`](https://hex.pm/packages/geo) library for geographic data:

```elixir
defmodule MyApp.GraphQL.Scalars.Point do
  use GreenFairy.Scalar

  @moduledoc "GraphQL scalar for Geo.Point from the geo library"

  scalar "Point" do
    description "A geographic point (longitude, latitude)"

    parse fn
      %Absinthe.Blueprint.Input.Object{fields: fields}, _ ->
        lng = get_field(fields, "lng")
        lat = get_field(fields, "lat")
        {:ok, %Geo.Point{coordinates: {lng, lat}, srid: 4326}}
      _, _ ->
        :error
    end

    serialize fn %Geo.Point{coordinates: {lng, lat}} ->
      %{lng: lng, lat: lat}
    end

    # Define available operators
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

See the [CQL Guide](cql.html) for details on filtering.

## Type Naming Conventions

| Kind | Module Example | GraphQL Name |
|------|----------------|--------------|
| Type | `MyApp.GraphQL.Types.User` | `User` |
| Interface | `MyApp.GraphQL.Interfaces.Node` | `Node` |
| Input | `MyApp.GraphQL.Inputs.CreateUserInput` | `CreateUserInput` |
| Enum | `MyApp.GraphQL.Enums.UserRole` | `UserRole` |
| Union | `MyApp.GraphQL.Unions.SearchResult` | `SearchResult` |
| Scalar | `MyApp.GraphQL.Scalars.DateTime` | `DateTime` |

The GraphQL identifier is automatically derived from the type name using snake_case:
- `"User"` becomes `:user`
- `"CreateUserInput"` becomes `:create_user_input`
- `"DateTime"` becomes `:date_time`

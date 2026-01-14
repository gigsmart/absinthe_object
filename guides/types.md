# Types

This guide covers all the type modules available in Absinthe.Object.

## Object Types

Object types are the most common type in GraphQL. They represent entities in your domain.

```elixir
defmodule MyApp.GraphQL.Types.User do
  use Absinthe.Object.Type

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
    arg :location, non_null(:geo_point)

    loader fn workers, args, ctx ->
      worker_ids = Enum.map(workers, & &1.id)
      gigs = MyApp.Gigs.find_nearby(worker_ids, args.location)

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
  use Absinthe.Object.Interface

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
  use Absinthe.Object.Input

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
  use Absinthe.Object.Input

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
  use Absinthe.Object.Enum

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
  use Absinthe.Object.Union

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
  use Absinthe.Object.Scalar

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

Define custom filtering operators for your scalar types:

```elixir
defmodule MyApp.GraphQL.Scalars.GeoPoint do
  use Absinthe.Object.Scalar

  scalar "GeoPoint" do
    parse &parse_point/2
    serialize &serialize_point/1

    # Define available operators
    operators [:eq, :near, :within_radius]

    # Define how each operator works
    filter :near, fn field, value, opts ->
      distance = opts[:distance] || 10_000
      {:geo, :st_dwithin, field, value, distance}
    end

    filter :within_radius, fn field, %{center: center, radius: radius} ->
      {:geo, :st_dwithin, field, center, radius}
    end
  end

  # ...
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

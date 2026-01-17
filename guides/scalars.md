# Scalars

Scalars are the leaf values of a GraphQL schema - primitive types that resolve to
concrete values. GreenFairy supports both built-in scalars and custom scalars with
full CQL filter integration.

## Built-in Scalars

GraphQL and Absinthe provide these built-in scalars:

| Scalar | Description | Example |
|--------|-------------|---------|
| `ID` | Unique identifier | `"user_123"` |
| `String` | UTF-8 text | `"Hello world"` |
| `Int` | 32-bit signed integer | `42` |
| `Float` | Double-precision float | `3.14` |
| `Boolean` | True or false | `true` |

Absinthe adds these additional scalars:

| Scalar | Description | Example |
|--------|-------------|---------|
| `DateTime` | ISO 8601 datetime | `"2024-01-15T10:30:00Z"` |
| `Date` | ISO 8601 date | `"2024-01-15"` |
| `Time` | ISO 8601 time | `"10:30:00"` |
| `NaiveDateTime` | DateTime without timezone | `"2024-01-15T10:30:00"` |
| `Decimal` | Arbitrary precision number | `"123.456"` |

## Custom Scalars

Define custom scalars for domain-specific value types:

```elixir
defmodule MyApp.GraphQL.Scalars.Email do
  use GreenFairy.Scalar

  scalar "Email" do
    description "A valid email address"

    parse fn
      %Absinthe.Blueprint.Input.String{value: value}, _ ->
        if valid_email?(value), do: {:ok, value}, else: :error
      _, _ ->
        :error
    end

    serialize fn email -> email end
  end

  defp valid_email?(email) do
    String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
  end
end
```

### Parse and Serialize

Every scalar must define two functions:

**`parse`** - Converts input from GraphQL to Elixir:
```elixir
parse fn
  %Absinthe.Blueprint.Input.String{value: value}, _context ->
    case MyApp.parse_value(value) do
      {:ok, result} -> {:ok, result}
      :error -> :error
    end
  _, _ ->
    :error
end
```

**`serialize`** - Converts Elixir values to GraphQL output:
```elixir
serialize fn value ->
  MyApp.format_value(value)
end
```

## Common Custom Scalars

### JSON Scalar

```elixir
defmodule MyApp.GraphQL.Scalars.JSON do
  use GreenFairy.Scalar

  scalar "JSON" do
    description "Arbitrary JSON value"

    parse fn
      %Absinthe.Blueprint.Input.String{value: value}, _ ->
        case Jason.decode(value) do
          {:ok, json} -> {:ok, json}
          _ -> :error
        end
      %Absinthe.Blueprint.Input.Object{} = input, _ ->
        {:ok, decode_object(input)}
      %Absinthe.Blueprint.Input.List{items: items}, _ ->
        {:ok, Enum.map(items, &decode_value/1)}
      %Absinthe.Blueprint.Input.Null{}, _ ->
        {:ok, nil}
      _, _ ->
        :error
    end

    serialize fn value -> value end
  end

  defp decode_object(%{fields: fields}) do
    Map.new(fields, fn %{name: name, input_value: %{value: value}} ->
      {name, decode_value(value)}
    end)
  end

  defp decode_value(%Absinthe.Blueprint.Input.String{value: v}), do: v
  defp decode_value(%Absinthe.Blueprint.Input.Integer{value: v}), do: v
  defp decode_value(%Absinthe.Blueprint.Input.Float{value: v}), do: v
  defp decode_value(%Absinthe.Blueprint.Input.Boolean{value: v}), do: v
  defp decode_value(%Absinthe.Blueprint.Input.Null{}), do: nil
  defp decode_value(%Absinthe.Blueprint.Input.Object{} = obj), do: decode_object(obj)
  defp decode_value(%Absinthe.Blueprint.Input.List{items: items}), do: Enum.map(items, &decode_value/1)
  defp decode_value(other), do: other
end
```

### URL Scalar

```elixir
defmodule MyApp.GraphQL.Scalars.URL do
  use GreenFairy.Scalar

  scalar "URL" do
    description "A valid URL"

    parse fn
      %Absinthe.Blueprint.Input.String{value: value}, _ ->
        case URI.parse(value) do
          %URI{scheme: scheme} when scheme in ["http", "https"] ->
            {:ok, value}
          _ ->
            :error
        end
      _, _ ->
        :error
    end

    serialize fn url -> url end
  end
end
```

### UUID Scalar

```elixir
defmodule MyApp.GraphQL.Scalars.UUID do
  use GreenFairy.Scalar

  scalar "UUID" do
    description "A UUID string"

    parse fn
      %Absinthe.Blueprint.Input.String{value: value}, _ ->
        case Ecto.UUID.cast(value) do
          {:ok, uuid} -> {:ok, uuid}
          :error -> :error
        end
      _, _ ->
        :error
    end

    serialize fn uuid -> uuid end
  end
end
```

## CQL Integration

Custom scalars can define their own CQL filter operators for advanced filtering.

### Basic CQL Operators

CQL operator input types are **automatically generated** based on the scalar's underlying type. You don't need to define them manually.

```elixir
defmodule MyApp.GraphQL.Scalars.Money do
  use GreenFairy.Scalar

  scalar "Money" do
    description "Monetary amount in cents"

    parse fn
      %Absinthe.Blueprint.Input.Integer{value: value}, _ ->
        {:ok, value}
      %Absinthe.Blueprint.Input.String{value: value}, _ ->
        case Integer.parse(value) do
          {int, ""} -> {:ok, int}
          _ -> :error
        end
      _, _ ->
        :error
    end

    serialize fn cents -> cents end
  end
end
```

Since Money parses to an integer, it will automatically use the integer operators (`_eq`, `_neq`, `_gt`, `_gte`, `_lt`, `_lte`, `_in`, `_nin`, `_is_null`).

### Geospatial Scalar

For scalars that need custom database-specific operators (like PostGIS spatial functions), implement the `GreenFairy.CQL.Scalar` behaviour. See the [Custom Scalars Guide](custom-scalars.md) for details.

```elixir
defmodule MyApp.GraphQL.Scalars.Point do
  use GreenFairy.Scalar

  @moduledoc "GraphQL scalar for geographic points"

  scalar "Point" do
    description "A geographic point (longitude, latitude)"

    parse fn
      %Absinthe.Blueprint.Input.Object{fields: fields}, _ ->
        lng = get_field(fields, "lng") || get_field(fields, "longitude")
        lat = get_field(fields, "lat") || get_field(fields, "latitude")

        if lng && lat do
          {:ok, %Geo.Point{coordinates: {lng, lat}, srid: 4326}}
        else
          :error
        end
      _, _ ->
        :error
    end

    serialize fn %Geo.Point{coordinates: {lng, lat}} ->
      %{lng: lng, lat: lat}
    end
  end

  defp get_field(fields, name) do
    Enum.find_value(fields, fn
      %{name: ^name, input_value: %{value: %{value: v}}} -> v
      _ -> nil
    end)
  end
end
```

For database-specific spatial operators, implement the `GreenFairy.CQL.Scalar` behaviour in a separate module. See the [Custom Scalars Guide](custom-scalars.md) for the full pattern.

### Supporting Input Types

When using custom operators, you may need supporting input types:

```elixir
defmodule MyApp.GraphQL.Inputs.PointNearInput do
  use GreenFairy.Input

  input "PointNearInput" do
    field :point, non_null(:point)
    field :distance, :integer, default_value: 1000
  end
end

defmodule MyApp.GraphQL.Inputs.PointDistanceInput do
  use GreenFairy.Input

  input "PointDistanceInput" do
    field :point, non_null(:point)
    field :distance, non_null(:integer)
  end
end

defmodule MyApp.GraphQL.Inputs.BoundingBoxInput do
  use GreenFairy.Input

  input "BoundingBoxInput" do
    @desc "Southwest corner of the bounding box"
    field :sw, non_null(:point)

    @desc "Northeast corner of the bounding box"
    field :ne, non_null(:point)
  end
end
```

### Query Example

```graphql
query NearbyLocations {
  locations(filter: {
    coordinates: {
      _within_distance: {
        point: { lng: -122.4194, lat: 37.7749 }
        distance: 5000
      }
    }
  }) {
    id
    name
    coordinates
  }
}
```

## Using Scalars in Types

Reference scalars by their identifier:

```elixir
type "User", struct: MyApp.User do
  field :id, non_null(:id)
  field :email, non_null(:email)      # Custom Email scalar
  field :website, :url                 # Custom URL scalar
  field :metadata, :json               # Custom JSON scalar
  field :location, :point              # Custom Point scalar
end

input "CreateLocationInput" do
  field :name, non_null(:string)
  field :coordinates, non_null(:point)
  field :metadata, :json
end
```

## Module Functions

Every scalar module exports:

| Function | Description |
|----------|-------------|
| `__green_fairy_kind__/0` | Returns `:scalar` |
| `__green_fairy_identifier__/0` | Returns the type identifier |
| `__green_fairy_definition__/0` | Returns the full definition map |
| `__cql_operators__/0` | Returns list of CQL operators |
| `__has_cql_operators__/0` | Returns true if custom operators defined |
| `__cql_input_identifier__/0` | Returns CQL input type identifier |
| `__has_cql_input__/0` | Returns true if custom CQL input defined |
| `__apply_filter__/4` | Applies a custom filter operator |

## Naming Conventions

| GraphQL Name | Elixir Identifier | Module Suggestion |
|--------------|-------------------|-------------------|
| `Email` | `:email` | `MyApp.GraphQL.Scalars.Email` |
| `JSON` | `:json` | `MyApp.GraphQL.Scalars.JSON` |
| `Point` | `:point` | `MyApp.GraphQL.Scalars.Point` |
| `UUID` | `:uuid` | `MyApp.GraphQL.Scalars.UUID` |

## Best Practices

1. **Validate thoroughly in parse** - Return `:error` for invalid input
2. **Handle all input types** - Match against different Blueprint input types
3. **Keep serialize simple** - Convert to JSON-compatible formats
4. **Document constraints** - Use descriptions to explain valid formats
5. **Use meaningful names** - `Email` instead of `EmailString`

## Next Steps

- [Object Types](object-types.md) - Using scalars in object fields
- [Input Types](input-types.md) - Using scalars in inputs
- [CQL](cql.md) - Advanced filtering with custom operators

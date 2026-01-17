defmodule GreenFairy.CQL.Adapters.Memory do
  @moduledoc """
  Memory/Enum-based CQL adapter for plain structs.

  This is the fallback adapter when no other adapter (Ecto, Elasticsearch, etc.)
  matches the struct backing a type. It provides basic CQL operations using
  Elixir's `Enum` module functions.

  ## Supported Operations

  **Filter Operators:**
  - `_eq` - Equality check (`==`)
  - `_neq` - Not equal (`!=`)
  - `_gt`, `_gte`, `_lt`, `_lte` - Comparisons (`>`, `>=`, `<`, `<=`)
  - `_in` - Value in list
  - `_nin` - Value not in list
  - `_is_null` - Null check

  **Sort:**
  - `asc` - Sort ascending
  - `desc` - Sort descending

  ## How It Works

  Unlike database adapters, the Memory adapter works on in-memory lists:

      users = [%User{id: 1, name: "Alice"}, %User{id: 2, name: "Bob"}]

      # Filter: name == "Alice"
      Memory.filter(users, :name, :_eq, "Alice")
      #=> [%User{id: 1, name: "Alice"}]

      # Sort by name ascending
      Memory.sort(users, :name, :asc)
      #=> [%User{id: 1, name: "Alice"}, %User{id: 2, name: "Bob"}]

  ## Usage with GreenFairy

  This adapter is automatically selected for types that:
  - Use plain structs (not Ecto schemas)
  - Don't have a repo configured
  - Don't match any other adapter

  Users must provide their own data source (typically via resolver):

      type "User", struct: MyApp.User do
        # CQL operators are available for filtering/sorting
        # but you provide the data in your resolver
        field :id, non_null(:id)
        field :name, :string
      end

      # In your resolver:
      def list_users(_parent, args, _ctx) do
        users = MyApp.get_all_users()
        filtered = GreenFairy.CQL.Adapters.Memory.apply_filters(users, args.filter)
        sorted = GreenFairy.CQL.Adapters.Memory.apply_order(filtered, args.order)
        {:ok, sorted}
      end

  """

  @behaviour GreenFairy.CQL.Adapter

  @impl true
  def sort_directions, do: [:asc, :desc]

  @impl true
  def sort_direction_enum(nil), do: :cql_sort_direction
  def sort_direction_enum(namespace), do: :"cql_#{namespace}_sort_direction"

  @impl true
  def supports_geo_ordering?, do: false

  @impl true
  def supports_priority_ordering?, do: false

  @impl true
  def capabilities do
    %{
      in_memory: true,
      array_operators_require_type_cast: false,
      native_arrays: true,
      supports_json_operators: false,
      supports_full_text_search: false,
      max_in_clause_items: nil
    }
  end

  @impl true
  def operator_type_for(_ecto_type) do
    # Memory adapter uses generic operator types
    :cql_op_any_input
  end

  @impl true
  def supported_operators(:scalar, _field_type) do
    [:_eq, :_neq, :_gt, :_gte, :_lt, :_lte, :_in, :_nin, :_is_null]
  end

  def supported_operators(:array, _field_type) do
    [:_includes, :_excludes, :_is_empty, :_is_null]
  end

  def supported_operators(_, _), do: []

  @impl true
  def operator_inputs do
    # Memory adapter provides a generic input type that works for any value
    %{
      cql_op_any_input: {
        [:_eq, :_neq, :_gt, :_gte, :_lt, :_lte, :_in, :_nin, :_is_null],
        :string,
        "Generic operators for in-memory filtering"
      }
    }
  end

  @impl true
  def apply_operator(query, _field, _operator, _value, _opts) do
    # Memory adapter doesn't modify Ecto queries
    # It's meant to be used with apply_filters/2 on lists
    query
  end

  # ==========================================================================
  # In-Memory List Operations
  # ==========================================================================

  @doc """
  Applies filter operations to a list of items.

  ## Parameters

  - `items` - List of structs/maps to filter
  - `filter` - Map of field => operator map (e.g., `%{name: %{_eq: "Alice"}}`)

  ## Returns

  Filtered list of items.

  ## Examples

      users = [%User{name: "Alice"}, %User{name: "Bob"}]

      apply_filters(users, %{name: %{_eq: "Alice"}})
      #=> [%User{name: "Alice"}]

      apply_filters(users, %{name: %{_in: ["Alice", "Bob"]}})
      #=> [%User{name: "Alice"}, %User{name: "Bob"}]

  """
  def apply_filters(items, nil), do: items
  def apply_filters(items, filter) when filter == %{}, do: items

  def apply_filters(items, filter) when is_map(filter) do
    Enum.filter(items, fn item ->
      Enum.all?(filter, fn {field, operators} ->
        apply_field_filter(item, field, operators)
      end)
    end)
  end

  defp apply_field_filter(item, field, operators) when is_map(operators) do
    value = get_field_value(item, field)

    Enum.all?(operators, fn {operator, expected} ->
      apply_operator_check(value, operator, expected)
    end)
  end

  defp apply_field_filter(_item, _field, _other), do: true

  defp get_field_value(%{} = item, field) when is_atom(field) do
    Map.get(item, field)
  end

  defp get_field_value(%{} = item, field) when is_binary(field) do
    Map.get(item, field) || Map.get(item, String.to_existing_atom(field))
  rescue
    ArgumentError -> nil
  end

  defp get_field_value(_, _), do: nil

  # Operator implementations
  defp apply_operator_check(value, :_eq, expected), do: value == expected
  defp apply_operator_check(value, :_neq, expected), do: value != expected
  defp apply_operator_check(value, :_ne, expected), do: value != expected
  defp apply_operator_check(value, :_gt, expected), do: value > expected
  defp apply_operator_check(value, :_gte, expected), do: value >= expected
  defp apply_operator_check(value, :_lt, expected), do: value < expected
  defp apply_operator_check(value, :_lte, expected), do: value <= expected
  defp apply_operator_check(value, :_in, expected) when is_list(expected), do: value in expected
  defp apply_operator_check(value, :_nin, expected) when is_list(expected), do: value not in expected
  defp apply_operator_check(value, :_is_null, true), do: is_nil(value)
  defp apply_operator_check(value, :_is_null, false), do: not is_nil(value)

  # Array operators
  defp apply_operator_check(value, :_includes, expected) when is_list(value) do
    expected in value
  end

  defp apply_operator_check(value, :_excludes, expected) when is_list(value) do
    expected not in value
  end

  defp apply_operator_check(value, :_is_empty, true) when is_list(value), do: value == []
  defp apply_operator_check(value, :_is_empty, false) when is_list(value), do: value != []
  defp apply_operator_check(_, :_is_empty, _), do: false

  # Unknown operator - pass through
  defp apply_operator_check(_, _, _), do: true

  @doc """
  Applies ordering to a list of items.

  ## Parameters

  - `items` - List of structs/maps to sort
  - `order` - List of `%{field: atom, direction: :asc | :desc}` maps

  ## Returns

  Sorted list of items.

  ## Examples

      users = [%User{name: "Bob"}, %User{name: "Alice"}]

      apply_order(users, [%{field: :name, direction: :asc}])
      #=> [%User{name: "Alice"}, %User{name: "Bob"}]

      apply_order(users, [%{field: :name, direction: :desc}])
      #=> [%User{name: "Bob"}, %User{name: "Alice"}]

  """
  def apply_order(items, nil), do: items
  def apply_order(items, []), do: items

  def apply_order(items, order) when is_list(order) do
    # Build a comparator from the order list
    Enum.sort(items, fn a, b ->
      compare_by_order(a, b, order)
    end)
  end

  defp compare_by_order(_a, _b, []), do: true

  defp compare_by_order(a, b, [%{field: field, direction: direction} | rest]) do
    value_a = get_field_value(a, field)
    value_b = get_field_value(b, field)

    case compare_values(value_a, value_b, direction) do
      :eq -> compare_by_order(a, b, rest)
      :lt -> true
      :gt -> false
    end
  end

  defp compare_values(a, b, _direction) when a == b, do: :eq

  defp compare_values(a, b, :asc) do
    cond do
      is_nil(a) -> :gt
      is_nil(b) -> :lt
      a < b -> :lt
      true -> :gt
    end
  end

  defp compare_values(a, b, :desc) do
    cond do
      is_nil(a) -> :gt
      is_nil(b) -> :lt
      a > b -> :lt
      true -> :gt
    end
  end

  @doc """
  Applies both filtering and ordering to a list of items.

  ## Parameters

  - `items` - List of structs/maps
  - `filter` - Filter map (optional)
  - `order` - Order list (optional)

  ## Returns

  Filtered and sorted list of items.
  """
  def apply_query(items, filter \\ nil, order \\ nil) do
    items
    |> apply_filters(filter)
    |> apply_order(order)
  end
end

defmodule GreenFairy.CQL.Schema.OrderInput do
  @moduledoc """
  Generates CQL order input types for GraphQL types.

  Creates `CqlOrder{Type}Input` types with fields that map to sortable columns,
  each accepting an order direction.

  ## Order Types

  Three order input types are generated:

  - `cql_order_standard_input` - Basic direction-based sorting
  - `cql_order_geo_input` - Geo-distance based sorting with center point
  - `cql_order_priority_{enum}_input` - Priority-based enum sorting

  ## Sort Direction

  The `cql_sort_direction` enum supports:

  - `:asc` - Ascending order
  - `:desc` - Descending order
  - `:asc_nulls_first` - Ascending with nulls first
  - `:asc_nulls_last` - Ascending with nulls last
  - `:desc_nulls_first` - Descending with nulls first
  - `:desc_nulls_last` - Descending with nulls last

  ## Example

  For a User type with name (string) and created_at (datetime) fields:

      input CqlOrderUserInput {
        name: CqlOrderStandardInput
        createdAt: CqlOrderStandardInput
      }

  Which can be used in queries:

      query {
        users(orderBy: [{name: {direction: ASC}}]) {
          edges { node { name } }
        }
      }
  """

  @doc """
  Generates the order input type identifier for a type name.

  Note: This creates atoms at compile time during schema compilation,
  not at runtime, so the credo warning is a false positive.
  """
  def order_type_identifier(type_name) when is_binary(type_name) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    String.to_atom("cql_order_#{Macro.underscore(type_name)}_input")
  end

  def order_type_identifier(type_name) when is_atom(type_name) do
    order_type_identifier(Atom.to_string(type_name))
  end

  @doc """
  Returns the order input type for a field type.
  """
  def type_for(:geo_point), do: :cql_order_geo_input
  def type_for(:location), do: :cql_order_geo_input
  def type_for(_), do: :cql_order_standard_input

  @doc """
  Generates AST for a CqlOrder{Type}Input type.

  ## Parameters

  - `type_name` - The GraphQL type name (e.g., "User")
  - `fields` - List of `{field_name, field_type}` tuples for orderable fields
  - `associations` - List of `{assoc_name, related_type_name}` tuples for nested ordering

  ## Example

      fields = [
        {:id, :id},
        {:name, :string},
        {:created_at, :datetime}
      ]

      associations = [
        {:author, "User"},
        {:posts, "Post"}
      ]

      OrderInput.generate("User", fields, associations)
  """
  def generate(type_name, fields, associations \\ []) do
    identifier = order_type_identifier(type_name)
    description = "Order input for #{type_name} type"

    field_defs = build_field_definitions(fields)
    assoc_defs = build_association_definitions(associations)

    all_fields = field_defs ++ assoc_defs

    # Absinthe doesn't allow empty input objects, but we need to generate
    # order inputs for all CQL-enabled types because other types may reference them
    # via associations. If there are no orderable fields, add a placeholder.
    all_fields =
      if all_fields == [] do
        # Add a placeholder field so the input object is valid
        [
          quote do
            Absinthe.Schema.Notation.field(:_, :cql_order_standard_input,
              description: "Placeholder for types with no orderable fields"
            )
          end
        ]
      else
        all_fields
      end

    # Use fully qualified macro call to ensure proper expansion
    quote do
      Absinthe.Schema.Notation.input_object unquote(identifier) do
        @desc unquote(description)
        unquote_splicing(all_fields)
      end
    end
  end

  defp build_field_definitions(fields) do
    fields
    |> Enum.map(fn {field_name, field_type} ->
      order_type = type_for(field_type)

      quote do
        Absinthe.Schema.Notation.field(unquote(field_name), unquote(order_type))
      end
    end)
  end

  # Build association field definitions for nested ordering
  # Each association gets a field that references its related type's order input
  defp build_association_definitions(associations) do
    associations
    |> Enum.map(fn {assoc_name, related_type_name} ->
      # Generate the order type identifier for the related type
      related_order_id = order_type_identifier(related_type_name)

      quote do
        Absinthe.Schema.Notation.field(unquote(assoc_name), unquote(related_order_id))
      end
    end)
  end

  @doc """
  Generates AST for the sort direction enum.
  """
  def generate_sort_direction_enum do
    # Use quote with fully qualified macro calls to ensure proper expansion
    quote do
      Absinthe.Schema.Notation.enum :cql_sort_direction do
        @desc "Sort direction for ordering results"
        Absinthe.Schema.Notation.value(:asc, description: "Ascending order")
        Absinthe.Schema.Notation.value(:desc, description: "Descending order")
        Absinthe.Schema.Notation.value(:asc_nulls_first, description: "Ascending order with null values listed first")
        Absinthe.Schema.Notation.value(:asc_nulls_last, description: "Ascending order with null values listed last")
        Absinthe.Schema.Notation.value(:desc_nulls_first, description: "Descending order with null values listed first")
        Absinthe.Schema.Notation.value(:desc_nulls_last, description: "Descending order with null values listed last")
      end
    end
  end

  @doc """
  Generates AST for the standard order input type.
  """
  def generate_standard_order_input do
    # Use quote with fully qualified macro calls to ensure proper expansion
    quote do
      Absinthe.Schema.Notation.input_object :cql_order_standard_input do
        @desc "Standard order input with direction"
        Absinthe.Schema.Notation.field(:direction, non_null(:cql_sort_direction),
          description: "The direction of the sort"
        )
      end
    end
  end

  @doc """
  Generates AST for the geo order input type.
  """
  def generate_geo_order_input do
    # Use quote with fully qualified macro calls to ensure proper expansion
    quote do
      Absinthe.Schema.Notation.input_object :cql_order_geo_input do
        @desc "Geo-distance based order input"
        Absinthe.Schema.Notation.field(:direction, non_null(:cql_sort_direction),
          description: "The direction of the sort"
        )

        Absinthe.Schema.Notation.field(:center, :coordinates,
          description: "The center coordinates to calculate distance from"
        )
      end
    end
  end

  @doc """
  Generates AST for a priority order input type for an enum.

  Priority ordering allows specifying the order of enum values
  for sorting purposes.

  ## Example

      generate_priority_order_input(:status, [:active, :pending, :closed])

  Generates:

      input CqlOrderPriorityStatusInput {
        direction: CqlSortDirection!
        priority: [Status]
      }
  """
  def generate_priority_order_input(enum_name, _values) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    identifier = String.to_atom("cql_order_priority_#{enum_name}_input")
    description = "Priority-based order input for #{enum_name} enum"

    # Use quote with fully qualified macro calls to ensure proper expansion
    quote do
      Absinthe.Schema.Notation.input_object unquote(identifier) do
        @desc unquote(description)
        Absinthe.Schema.Notation.field(:direction, non_null(:cql_sort_direction),
          description: "The direction of the sort"
        )

        Absinthe.Schema.Notation.field(:priority, list_of(unquote(enum_name)),
          description: "The priority order of enum values"
        )
      end
    end
  end

  @doc """
  Generates all base order input types (sort direction, standard).

  Geo order input is excluded by default since it requires a :coordinates type.
  Use `generate_base_types_with_geo/0` if you have :coordinates defined.

  This should be called once in the schema to define all CQL order types.
  """
  def generate_base_types do
    [
      generate_sort_direction_enum(),
      generate_standard_order_input()
      # Note: Geo order input is excluded because it requires :coordinates type
      # which isn't a built-in type. Use generate_geo_order_input() separately
      # if your schema defines a :coordinates type.
    ]
  end

  @doc """
  Generates all base order input types including geo ordering.

  Only use this if your schema defines a :coordinates type for geo points.
  """
  def generate_base_types_with_geo do
    [
      generate_sort_direction_enum(),
      generate_standard_order_input(),
      generate_geo_order_input()
    ]
  end
end

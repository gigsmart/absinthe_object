defmodule Absinthe.Object.Filter do
  @moduledoc """
  Multi-dispatch protocol for applying semantic filters across different adapters.

  This module uses `protocol_ex` to dispatch filter operations based on the
  combination of adapter type and filter type. This allows scalars to define
  semantic filter intent while adapters provide the implementation.

  ## Design

  1. **Scalars** return semantic filter structs (e.g., `%Geo.Near{}`)
  2. **Protocol** dispatches on `{adapter, filter}` tuple
  3. **Implementations** translate semantic intent to adapter-specific queries

  ## Example

      # Scalar returns semantic intent
      filter :near, fn point, opts ->
        %Absinthe.Object.Filters.Geo.Near{
          point: point,
          distance: opts[:distance] || 1000
        }
      end

      # Implementation handles the specifics
      defmodule MyApp.Filters.Postgres do
        use Absinthe.Object.Filter.Impl,
          adapter: Absinthe.Object.Adapters.Ecto.Postgres

        filter_impl Geo.Near do
          def apply(_adapter, %{point: point, distance: dist}, field, query) do
            import Ecto.Query
            {:ok, from(q in query,
              where: fragment("ST_DWithin(?::geography, ?::geography, ?)",
                field(q, ^field), ^point, ^dist))}
          end
        end
      end

  """

  use ProtocolEx

  defprotocol_ex do
    @doc """
    Applies a semantic filter to a query.

    ## Arguments

    - `adapter` - The adapter struct (e.g., `%Ecto.Postgres{}`)
    - `filter` - The semantic filter struct (e.g., `%Geo.Near{}`)
    - `field` - The field name being filtered
    - `query` - The query being built

    ## Returns

    - `{:ok, updated_query}` - Filter applied successfully
    - `{:error, reason}` - Filter could not be applied

    """
    def apply(adapter, filter, field, query)
  end

  # Default fallback for unimplemented combinations
  defimpl_ex Default, for: {Any, Any} do
    def apply(_adapter, filter, _field, _query) do
      {:error, {:no_filter_implementation, filter.__struct__}}
    end
  end

  @doc """
  Convenience function to apply a filter with error handling.
  """
  def apply!(adapter, filter, field, query) do
    case apply(adapter, filter, field, query) do
      {:ok, result} -> result
      {:error, reason} -> raise "Filter error: #{inspect(reason)}"
    end
  end
end

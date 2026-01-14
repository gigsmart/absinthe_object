defmodule Absinthe.Object.Filter.Impl do
  @moduledoc """
  Use hook for defining filter implementations.

  This module hides the `protocol_ex` implementation details and provides
  a clean DSL for defining adapter-specific filter implementations.

  ## Usage

      defmodule MyApp.Filters.Postgres do
        use Absinthe.Object.Filter.Impl,
          adapter: Absinthe.Object.Adapters.Ecto.Postgres

        alias Absinthe.Object.Filters.Geo
        import Ecto.Query

        filter_impl Geo.Near do
          def apply(adapter, %{point: point, distance: dist}, field, query) do
            {:ok, from(q in query,
              where: fragment("ST_DWithin(?::geography, ?::geography, ?)",
                field(q, ^field), ^point, ^dist))}
          end
        end

        filter_impl Geo.WithinBounds do
          def apply(_adapter, %{bounds: bounds}, field, query) do
            {:ok, from(q in query,
              where: fragment("ST_Within(?, ?)", field(q, ^field), ^bounds))}
          end
        end
      end

  ## Options

  - `:adapter` - The adapter struct module this implementation targets

  ## The `filter_impl` Macro

  The `filter_impl/2` macro defines a filter implementation for a specific
  filter struct type. Inside the block, define an `apply/4` function:

      filter_impl FilterModule do
        def apply(adapter, filter, field, query) do
          # adapter - The adapter struct
          # filter  - The filter struct (pattern match to destructure)
          # field   - The field name being filtered
          # query   - The query being built
          {:ok, updated_query}
        end
      end

  """

  @doc false
  defmacro __using__(opts) do
    adapter = Keyword.fetch!(opts, :adapter)

    quote do
      use ProtocolEx
      import Absinthe.Object.Filter.Impl, only: [filter_impl: 2]

      @__filter_impl_adapter__ unquote(adapter)

      # Track implementations for documentation
      Module.register_attribute(__MODULE__, :__filter_impls__, accumulate: true)

      @before_compile Absinthe.Object.Filter.Impl
    end
  end

  @doc """
  Defines a filter implementation for a specific filter struct.

  ## Example

      filter_impl Geo.Near do
        def apply(adapter, %{point: point, distance: dist}, field, query) do
          {:ok, build_geo_query(query, field, point, dist)}
        end
      end

  """
  defmacro filter_impl(filter_module, do: block) do
    quote do
      @__filter_impls__ unquote(filter_module)

      defimpl_ex unquote(impl_name(filter_module)),
        for: {@__filter_impl_adapter__, unquote(filter_module)},
        to: Absinthe.Object.Filter do
        unquote(block)
      end
    end
  end

  # Generate a unique implementation name
  defp impl_name(filter_module) do
    filter_name =
      filter_module
      |> Macro.expand(__ENV__)
      |> Module.split()
      |> List.last()

    String.to_atom("Impl_#{filter_name}")
  end

  @doc false
  defmacro __before_compile__(env) do
    adapter = Module.get_attribute(env.module, :__filter_impl_adapter__)
    impls = Module.get_attribute(env.module, :__filter_impls__) || []

    quote do
      @doc """
      Returns the adapter this module provides implementations for.
      """
      def __adapter__, do: unquote(adapter)

      @doc """
      Returns the list of filter types this module implements.
      """
      def __filter_impls__, do: unquote(impls)
    end
  end
end

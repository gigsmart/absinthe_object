defmodule GreenFairy.Scalar do
  @moduledoc """
  Defines a custom GraphQL scalar type with a clean DSL.

  ## Usage

      defmodule MyApp.GraphQL.Scalars.DateTime do
        use GreenFairy.Scalar

        scalar "DateTime" do
          parse fn
            %Absinthe.Blueprint.Input.String{value: value}, _ ->
              case DateTime.from_iso8601(value) do
                {:ok, datetime, _} -> {:ok, datetime}
                _ -> :error
              end
            _, _ -> :error
          end

          serialize fn datetime ->
            DateTime.to_iso8601(datetime)
          end
        end
      end

  ## CQL Operators

  Define custom operators for filtering on this scalar type. This example uses
  the `geo` library from Hex (https://hex.pm/packages/geo):

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

          # Define available operators for CQL
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

  ## Options

  - `:description` - Description of the scalar type (can also use @desc)

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation
      import Absinthe.Schema.Notation, except: [scalar: 2, scalar: 3]

      import GreenFairy.Scalar, only: [scalar: 2, scalar: 3, operators: 1, filter: 2, filter: 3]

      Module.register_attribute(__MODULE__, :green_fairy_scalar, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_operators, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_filters, accumulate: true)

      @before_compile GreenFairy.Scalar
    end
  end

  @doc """
  Defines the CQL operators available for this scalar type.

  ## Example

      scalar "Point" do
        operators [:eq, :near, :within_distance]
        # ...
      end

  """
  defmacro operators(ops) do
    quote do
      @green_fairy_operators unquote(ops)
    end
  end

  @doc """
  Defines how to apply a filter operator for this scalar type.

  ## Examples

      # Simple filter
      filter :near, fn field, value ->
        {:geo_near, field, value}
      end

      # Filter with options
      filter :within_radius, fn field, value, opts ->
        radius = opts[:radius] || 10
        {:geo_within, field, value, radius}
      end

  """
  defmacro filter(operator, func) do
    quote do
      @green_fairy_filters {unquote(operator), unquote(Macro.escape(func))}
    end
  end

  defmacro filter(operator, opts, func) do
    quote do
      @green_fairy_filters {unquote(operator), unquote(opts), unquote(Macro.escape(func))}
    end
  end

  @doc """
  Defines a custom GraphQL scalar type.

  ## Examples

      scalar "DateTime" do
        parse fn input, _ ->
          case DateTime.from_iso8601(input.value) do
            {:ok, datetime, _} -> {:ok, datetime}
            _ -> :error
          end
        end

        serialize fn datetime ->
          DateTime.to_iso8601(datetime)
        end
      end

  """
  defmacro scalar(name, opts \\ [], do: block) do
    identifier = GreenFairy.Naming.to_identifier(name)
    env = __CALLER__

    # Transform block to extract operators and filters
    transformed_block = transform_scalar_block(block, env)

    quote do
      @green_fairy_scalar %{
        kind: :scalar,
        name: unquote(name),
        identifier: unquote(identifier),
        description: unquote(opts[:description])
      }

      @desc unquote(opts[:description])
      Absinthe.Schema.Notation.scalar unquote(identifier) do
        unquote(transformed_block)
      end
    end
  end

  # Transform block to handle operators/filter declarations
  defp transform_scalar_block({:__block__, meta, statements}, env) do
    # Filter out our custom macros, keep only Absinthe ones
    {custom, absinthe} = Enum.split_with(statements, &custom_statement?/1)

    # Process custom statements
    custom_code = Enum.map(custom, &transform_custom_statement(&1, env))

    # Return block with custom code first, then Absinthe code
    {:__block__, meta, custom_code ++ absinthe}
  end

  defp transform_scalar_block(statement, env) do
    if custom_statement?(statement) do
      transform_custom_statement(statement, env)
    else
      statement
    end
  end

  defp custom_statement?({:operators, _, _}), do: true
  defp custom_statement?({:filter, _, _}), do: true
  defp custom_statement?(_), do: false

  defp transform_custom_statement({:operators, _meta, [ops]}, _env) do
    quote do
      @green_fairy_operators unquote(ops)
    end
  end

  defp transform_custom_statement({:filter, _meta, [operator, func]}, _env) do
    quote do
      @green_fairy_filters {unquote(operator), unquote(Macro.escape(func))}
    end
  end

  defp transform_custom_statement({:filter, _meta, [operator, opts, func]}, _env) do
    quote do
      @green_fairy_filters {unquote(operator), unquote(opts), unquote(Macro.escape(func))}
    end
  end

  defp transform_custom_statement(other, _env), do: other

  @doc false
  defmacro __before_compile__(env) do
    scalar_def = Module.get_attribute(env.module, :green_fairy_scalar)
    operators = Module.get_attribute(env.module, :green_fairy_operators) || []
    filters = Module.get_attribute(env.module, :green_fairy_filters) || []

    # Generate filter function clauses
    filter_clauses = generate_filter_clauses(filters)

    quote do
      unquote_splicing(filter_clauses)

      # Default clause - return nil for unknown operators
      def __apply_filter__(_operator, _field, _value, _opts), do: nil

      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :scalar,
          name: unquote(scalar_def[:name]),
          identifier: unquote(scalar_def[:identifier])
        }
      end

      @doc false
      def __green_fairy_identifier__ do
        unquote(scalar_def[:identifier])
      end

      @doc false
      def __green_fairy_kind__ do
        :scalar
      end

      @doc """
      Returns the CQL operators available for this scalar type.
      """
      def __cql_operators__ do
        unquote(operators)
      end

      @doc false
      def __has_cql_operators__ do
        unquote(operators != [])
      end
    end
  end

  defp generate_filter_clauses(filters) do
    Enum.map(filters, fn
      {operator, func} ->
        quote do
          def __apply_filter__(unquote(operator), field, value, opts) do
            filter_fn = unquote(func)

            case :erlang.fun_info(filter_fn, :arity) do
              {:arity, 2} -> filter_fn.(field, value)
              {:arity, 3} -> filter_fn.(field, value, opts)
              _ -> nil
            end
          end
        end

      {operator, _opts, func} ->
        quote do
          def __apply_filter__(unquote(operator), field, value, opts) do
            filter_fn = unquote(func)
            filter_fn.(field, value, opts)
          end
        end
    end)
  end
end

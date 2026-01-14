defmodule GreenFairy.Extension do
  @moduledoc """
  Behaviour for creating custom macro extensions for GreenFairy types.

  ## Creating Extensions

  Extensions allow you to add custom macros and functionality to type definitions.
  Create an extension module that uses this behaviour:

      defmodule MyApp.GraphQL.CQL do
        use GreenFairy.Extension

        @impl true
        def using(_opts) do
          quote do
            import MyApp.GraphQL.CQL.Macros
          end
        end
      end

  ## Using Extensions

  Extensions can be used inside type blocks:

      defmodule MyApp.GraphQL.Types.User do
        use GreenFairy.Type

        type "User", struct: MyApp.User do
          use MyApp.GraphQL.CQL  # Brings in custom macros

          field :id, non_null(:id)
          field :name, :string

          # Now you can use custom macros from CQL
          query_field :users
        end
      end

  ## Extension Callbacks

  Extensions can implement these callbacks:

  - `using/1` - Called when the extension is used, returns quoted code to inject
  - `transform_field/2` - Called for each field, can transform field definitions
  - `before_compile/2` - Called before compilation, can add middleware or metadata

  ## Example: Custom Query Field Extension

      defmodule MyApp.GraphQL.CQL do
        use GreenFairy.Extension

        @impl true
        def using(_opts) do
          quote do
            import MyApp.GraphQL.CQL.Macros
            Module.register_attribute(__MODULE__, :cql_queries, accumulate: true)
          end
        end
      end

      defmodule MyApp.GraphQL.CQL.Macros do
        @doc "Generates a query field with filters"
        defmacro query_field(name, opts \\\\ []) do
          quote do
            @cql_queries {unquote(name), unquote(opts)}
          end
        end
      end

  ## Field Transformation

  The `transform_field/2` callback allows extensions to modify field definitions:

      @impl true
      def transform_field(field_ast, config) do
        # Add custom middleware or transform the field
        field_ast
      end

  """

  @doc """
  Called when the extension is used in a type block.

  Returns quoted code that will be injected into the type module.
  This is where you import custom macros, register attributes, etc.

  ## Parameters

  - `opts` - Options passed to `use ExtensionModule, opts`

  ## Example

      @impl true
      def using(_opts) do
        quote do
          import MyExtension.Macros
          Module.register_attribute(__MODULE__, :my_metadata, accumulate: true)
        end
      end

  """
  @callback using(opts :: keyword()) :: Macro.t()

  @doc """
  Optional callback to transform field definitions.

  Called for each field in the type block. Can be used to add middleware,
  modify arguments, or wrap resolvers.

  ## Parameters

  - `field_ast` - The Macro AST of the field definition
  - `config` - Configuration map with `:module`, `:type_name`, etc.

  ## Returns

  The transformed field AST (or the original if no transformation needed).

  ## Example

      @impl true
      def transform_field({:field, meta, [name, type | rest]} = ast, config) do
        # Add logging middleware to all fields
        ast
      end

  """
  @callback transform_field(field_ast :: Macro.t(), config :: map()) :: Macro.t()

  @doc """
  Optional callback called during `__before_compile__`.

  Can be used to inject additional code into the compiled module,
  such as metadata functions or middleware registration.

  ## Parameters

  - `env` - The compilation environment
  - `config` - Configuration map with type metadata

  ## Returns

  Quoted code to inject, or `nil` for no injection.

  ## Example

      @impl true
      def before_compile(_env, config) do
        quote do
          def __cql_queries__, do: @cql_queries
        end
      end

  """
  @callback before_compile(env :: Macro.Env.t(), config :: map()) :: Macro.t() | nil

  @optional_callbacks transform_field: 2, before_compile: 2

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour GreenFairy.Extension

      @doc false
      def transform_field(ast, _config), do: ast

      @doc false
      def before_compile(_env, _config), do: nil

      defoverridable transform_field: 2, before_compile: 2
    end
  end
end

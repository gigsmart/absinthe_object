defmodule GreenFairy.Extensions.CQL.Schema do
  @moduledoc """
  Schema integration for CQL filter types.

  Include this module in your schema to generate all CQL operator and filter input types.

  ## Usage

      defmodule MyApp.Schema do
        use Absinthe.Schema
        use GreenFairy.Extensions.CQL.Schema

        # Import your types that use CQL
        import_types MyApp.GraphQL.Types.User
        import_types MyApp.GraphQL.Types.Post

        query do
          field :users, list_of(:user) do
            arg :filter, :cql_filter_user_input
            resolve &MyApp.Resolvers.list_users/3
          end
        end
      end

  ## What Gets Generated

  This module generates:

  1. **Operator Input Types** - Reusable types for field operators:
     - `CqlOpIdInput` - ID field operators (eq, neq, in, is_nil)
     - `CqlOpStringInput` - String field operators (eq, neq, contains, starts_with, ends_with, in, is_nil)
     - `CqlOpIntegerInput` - Integer field operators (eq, neq, gt, gte, lt, lte, in, is_nil)
     - `CqlOpFloatInput` - Float/Decimal field operators
     - `CqlOpBooleanInput` - Boolean field operators (eq, is_nil)
     - `CqlOpDatetimeInput` - DateTime field operators
     - `CqlOpDateInput` - Date field operators
     - `CqlOpTimeInput` - Time field operators
     - `CqlOpEnumInput` - Enum field operators
     - `CqlOpGenericInput` - Fallback for unknown types

  2. **Filter Input Types** - Type-specific filter inputs with combinators:
     - `CqlFilter{Type}Input` for each CQL-enabled type
     - Includes `_and`, `_or`, `_not` combinators
     - Includes field-specific operator references

  ## Dynamic Filter Generation

  For dynamically generated filter types, use the `cql_filter_input/1` macro:

      cql_filter_input MyApp.GraphQL.Types.User
      cql_filter_input MyApp.GraphQL.Types.Post

  Or use `cql_filter_inputs/1` to generate from a list:

      cql_filter_inputs [
        MyApp.GraphQL.Types.User,
        MyApp.GraphQL.Types.Post
      ]
  """

  alias GreenFairy.Extensions.CQL.OperatorInput

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation

      import GreenFairy.Extensions.CQL.Schema,
        only: [cql_operator_types: 0, cql_filter_input: 1, cql_filter_inputs: 1]

      # Include operator types by default
      cql_operator_types()
    end
  end

  @doc """
  Generates all CQL operator input types.

  These are the `CqlOp{Type}Input` types that define available operators
  for each scalar type in CQL filters.

  This macro is automatically called when you `use GreenFairy.Extensions.CQL.Schema`.
  """
  defmacro cql_operator_types do
    operator_types_ast = OperatorInput.generate_all()

    quote do
      (unquote_splicing(operator_types_ast))
    end
  end

  @doc """
  Generates a CQL filter input type for a specific type module.

  ## Example

      cql_filter_input MyApp.GraphQL.Types.User

  This generates a `CqlFilterUserInput` type with:
  - `_and`, `_or`, `_not` combinators
  - Field-specific operator inputs (e.g., `name: CqlOpStringInput`)
  """
  defmacro cql_filter_input(type_module) do
    quote do
      # The type module must export __cql_generate_filter_input__/0
      filter_ast = unquote(type_module).__cql_generate_filter_input__()
      Code.eval_quoted(filter_ast, [], __ENV__)
    end
  end

  @doc """
  Generates CQL filter input types for a list of type modules.

  ## Example

      cql_filter_inputs [
        MyApp.GraphQL.Types.User,
        MyApp.GraphQL.Types.Post,
        MyApp.GraphQL.Types.Comment
      ]
  """
  defmacro cql_filter_inputs(modules) do
    quote do
      for module <- unquote(modules) do
        if function_exported?(module, :__cql_generate_filter_input__, 0) do
          filter_ast = module.__cql_generate_filter_input__()
          Code.eval_quoted(filter_ast, [], __ENV__)
        end
      end
    end
  end

  @doc """
  Returns the filter input type identifier for a type module.

  Useful for dynamically referencing filter types in queries.

  ## Example

      field :users, list_of(:user) do
        arg :filter, cql_filter_type_for(MyApp.GraphQL.Types.User)
        resolve &MyApp.Resolvers.list_users/3
      end
  """
  def cql_filter_type_for(type_module) do
    type_module.__cql_filter_input_identifier__()
  end
end

defmodule GreenFairy.Query do
  @moduledoc """
  Defines query fields in a dedicated module.

  ## Usage

      defmodule MyApp.GraphQL.Queries.UserQueries do
        use GreenFairy.Query

        queries do
          field :user, MyApp.GraphQL.Types.User do
            arg :id, :id, null: false
            resolve &MyApp.Resolvers.User.get/3
          end

          field :users, list_of(MyApp.GraphQL.Types.User) do
            resolve &MyApp.Resolvers.User.list/3
          end
        end
      end

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation

      import GreenFairy.Query, only: [queries: 1, expose: 1, expose: 2, node_field: 0]
      import GreenFairy.Field.Connection, only: [connection: 2, connection: 3]

      Module.register_attribute(__MODULE__, :green_fairy_queries, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_referenced_types, accumulate: true)
      Module.register_attribute(__MODULE__, :green_fairy_expose_types, accumulate: true)

      @before_compile GreenFairy.Query
    end
  end

  @doc """
  Exposes a type as a root query field with automatic GlobalId resolution.

  This macro generates a field with an `:id` argument that automatically
  decodes the GlobalId and fetches the record from the database.

  ## Usage

      queries do
        # Exposes as :user field with auto-resolution
        expose Types.User

        # Custom field name
        expose Types.User, as: :get_user
      end

  ## Generated Code

  The `expose` macro generates approximately:

      field :user, Types.User do
        arg :id, non_null(:id)

        resolve fn _parent, %{id: global_id}, _ctx ->
          case GreenFairy.GlobalId.decode_id(global_id) do
            {:ok, {"User", local_id}} ->
              {:ok, MyApp.Repo.get(MyApp.User, local_id)}
            _ ->
              {:error, "Invalid ID"}
          end
        end
      end

  ## Options

  - `:as` - Custom field name (defaults to type's snake_case singular name)
  - `:repo` - Override the repo to use for fetching (auto-detected from schema config)

  """
  defmacro expose(type_module_ast, opts \\ []) do
    # We need to handle the case where the type module isn't compiled yet
    # So we'll generate code that looks up the type info at runtime in the resolver

    # Get the field name from options or derive from the module name
    field_name_opt = Keyword.get(opts, :as)

    quote do
      # Store reference for type discovery
      @green_fairy_referenced_types unquote(type_module_ast)

      # We need to get type info after the type module is compiled
      # Use unquote_splicing with a helper that defers the lookup
      unquote(
        generate_expose_field_ast(type_module_ast, field_name_opt, __CALLER__)
      )
    end
  end

  # Generate the field AST for expose, handling compile order issues
  defp generate_expose_field_ast(type_module_ast, field_name_opt, env) do
    type_module = Macro.expand(type_module_ast, env)

    # Derive names from the module path as fallback
    module_name = type_module |> Module.split() |> List.last()
    default_field_name = module_name |> Macro.underscore() |> String.to_atom()
    default_type_identifier = default_field_name

    field_name = field_name_opt || default_field_name

    # Generate the field - type info will be looked up at runtime in the resolver
    quote do
      field unquote(field_name), unquote(default_type_identifier) do
        arg(:id, non_null(:id))

        resolve(fn _parent, %{id: global_id}, ctx ->
          # Get type info at runtime when the module is definitely compiled
          type_module = unquote(type_module)

          {type_name, struct_module} =
            if function_exported?(type_module, :__green_fairy_definition__, 0) do
              type_def = type_module.__green_fairy_definition__()
              {Map.get(type_def, :type_name), Map.get(type_def, :struct)}
            else
              {unquote(module_name), nil}
            end

          case GreenFairy.GlobalId.decode_id(global_id) do
            {:ok, {^type_name, local_id}} ->
              repo = Map.get(ctx, :repo) || Application.get_env(:green_fairy, :repo)

              if struct_module && repo do
                case repo.get(struct_module, local_id) do
                  nil -> {:error, "#{type_name} not found"}
                  record -> {:ok, record}
                end
              else
                {:error, "Cannot resolve #{type_name}: no struct or repo configured"}
              end

            {:ok, {other_type, _}} ->
              {:error, "Invalid ID type: expected #{type_name}, got #{other_type}"}

            {:error, reason} ->
              {:error, "Invalid ID: #{inspect(reason)}"}
          end
        end)
      end
    end
  end

  @doc """
  Defines query fields.

  ## Examples

      queries do
        field :user, :user do
          arg :id, :id, null: false
          resolve &Resolver.get_user/3
        end
      end

  """
  defmacro queries(do: block) do
    # Extract type references from field definitions (for discovery)
    type_refs = extract_field_type_refs(block)

    # Transform the block: replace module references with type identifiers
    # Also transforms expose macros to field definitions
    transformed_block = transform_type_refs(block, __CALLER__)

    quote do
      @green_fairy_queries true

      # Track type references for graph discovery
      unquote_splicing(
        Enum.map(type_refs, fn type_ref ->
          quote do
            @green_fairy_referenced_types unquote(type_ref)
          end
        end)
      )

      # Store the block for later extraction by the schema
      def __green_fairy_query_fields__ do
        unquote(Macro.escape(block))
      end

      def __green_fairy_query_fields_identifier__ do
        :green_fairy_queries
      end

      # Define queries object that can be imported
      # Use transformed block with type identifiers instead of module references
      # Expose fields are generated separately via __green_fairy_expose_fields__
      object :green_fairy_queries do
        unquote(transformed_block)
      end
    end
  end

  @doc """
  Generates the Relay Node field with automatic type resolution.

  This creates a `node(id: ID!)` query field that:
  1. Decodes the global ID to get the type name
  2. Looks up the type module from the TypeRegistry
  3. Fetches the record using the type's struct and repo

  ## Usage

      queries do
        node_field()  # Adds `node(id: ID!): Node`

        field :user, :user do
          # ...
        end
      end

  """
  defmacro node_field do
    quote do
      field :node, :node do
        arg(:id, non_null(:id))

        resolve(fn _parent, %{id: global_id}, ctx ->
          GreenFairy.Query.resolve_node(global_id, ctx)
        end)
      end
    end
  end

  @doc """
  Resolves a Node by its global ID.

  This function:
  1. Decodes the global ID to get the type name and local ID
  2. Converts the type name to a type identifier
  3. Looks up the type module from the TypeRegistry
  4. Gets the struct and repo from the type's definition
  5. Fetches the record from the database

  ## Parameters

  - `global_id` - The encoded global ID string
  - `ctx` - The Absinthe resolution context

  ## Returns

  `{:ok, record}` or `{:error, reason}`

  """
  def resolve_node(global_id, ctx) do
    case GreenFairy.GlobalId.decode_id(global_id) do
      {:ok, {type_name, local_id}} ->
        # Convert type name to identifier (e.g., "UserProfile" -> :user_profile)
        type_identifier = type_name_to_identifier(type_name)

        # Look up the type module
        case GreenFairy.TypeRegistry.lookup_module(type_identifier) do
          nil ->
            {:error, "Unknown type: #{type_name}"}

          type_module ->
            resolve_node_from_type(type_module, type_name, local_id, ctx)
        end

      {:error, reason} ->
        {:error, "Invalid ID: #{inspect(reason)}"}
    end
  end

  defp resolve_node_from_type(type_module, type_name, local_id, ctx) do
    # Get type definition
    type_def =
      if function_exported?(type_module, :__green_fairy_definition__, 0) do
        type_module.__green_fairy_definition__()
      else
        %{}
      end

    struct_module = Map.get(type_def, :struct)

    # Get repo from context or type definition
    repo = get_repo_for_type(type_module, ctx)

    cond do
      is_nil(struct_module) ->
        {:error, "Type #{type_name} has no struct configured"}

      is_nil(repo) ->
        {:error, "No repo available for type #{type_name}"}

      true ->
        case repo.get(struct_module, local_id) do
          nil -> {:error, "#{type_name} not found"}
          record -> {:ok, record}
        end
    end
  end

  defp get_repo_for_type(_type_module, ctx) do
    # Try to get repo from context (set by schema)
    Map.get(ctx, :repo) ||
      # Or try the default configured repo
      Application.get_env(:green_fairy, :repo)
  end

  defp type_name_to_identifier(type_name) do
    type_name
    |> Macro.underscore()
    |> String.to_atom()
  end

  # Transform module references to type identifiers in the AST
  defp transform_type_refs({:__block__, meta, statements}, env) do
    {:__block__, meta, Enum.map(statements, &transform_type_refs(&1, env))}
  end

  defp transform_type_refs({:field, meta, [name, type | rest]}, env) do
    transformed_type = transform_type_ref(type, env)
    # Transform any do block contents (for args, resolvers, etc.)
    transformed_rest = Enum.map(rest, &transform_field_opts(&1, env))

    # Check if this is a list_of field with a CQL-enabled type
    # If so, inject CQL args (where, order_by) automatically
    transformed_rest = maybe_inject_cql_args(type, transformed_rest, env)

    {:field, meta, [name, transformed_type | transformed_rest]}
  end

  defp transform_type_refs(other, _env), do: other

  # Transform options within field (including do blocks with args)
  defp transform_field_opts([{:do, block}], env) do
    [{:do, transform_block_contents(block, env)}]
  end

  defp transform_field_opts(opts, _env), do: opts

  # Transform contents inside a do block (args, middleware, etc.)
  defp transform_block_contents({:__block__, meta, statements}, env) do
    {:__block__, meta, Enum.map(statements, &transform_statement(&1, env))}
  end

  defp transform_block_contents(single_statement, env) do
    transform_statement(single_statement, env)
  end

  # Transform individual statements inside field blocks
  defp transform_statement({:arg, meta, [name, type | rest]}, env) do
    transformed_type = transform_type_ref(type, env)
    {:arg, meta, [name, transformed_type | rest]}
  end

  defp transform_statement(other, _env), do: other

  # Transform a type reference from module to identifier
  defp transform_type_ref({:non_null, meta, [inner]}, env) do
    {:non_null, meta, [transform_type_ref(inner, env)]}
  end

  defp transform_type_ref({:list_of, meta, [inner]}, env) do
    {:list_of, meta, [transform_type_ref(inner, env)]}
  end

  defp transform_type_ref({:__aliases__, _, _} = module_ast, env) do
    # Expand the module alias to get the full module name
    module = Macro.expand(module_ast, env)

    # Ensure the module is compiled so we can call its functions
    case Code.ensure_compiled(module) do
      {:module, ^module} ->
        if function_exported?(module, :__green_fairy_identifier__, 0) do
          module.__green_fairy_identifier__()
        else
          # Not a GreenFairy module, return as-is
          module
        end

      _ ->
        # Module not compiled yet, return as-is (will cause an error later)
        module
    end
  end

  defp transform_type_ref(type, _env), do: type

  # Check if a list field should have CQL args injected
  # If the inner type has CQL enabled, inject where and order_by args
  defp maybe_inject_cql_args({:list_of, _, [inner_type_ast]}, rest, env) do
    inner_module = extract_type_module(inner_type_ast, env)

    if inner_module && cql_enabled?(inner_module) do
      inject_cql_args(rest, inner_module)
    else
      rest
    end
  end

  defp maybe_inject_cql_args(_type, rest, _env), do: rest

  defp extract_type_module({:__aliases__, _, _} = module_ast, env) do
    module = Macro.expand(module_ast, env)

    case Code.ensure_compiled(module) do
      {:module, ^module} -> module
      _ -> nil
    end
  end

  defp extract_type_module(_type, _env), do: nil

  defp cql_enabled?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__cql_filter_input_identifier__, 0)
  end

  # Inject CQL where and order_by args into the field's do block
  defp inject_cql_args([], type_module) do
    # No existing do block, create one with just CQL args
    [{:do, build_cql_args_block(type_module)}]
  end

  defp inject_cql_args([[{:do, existing_block}]], type_module) do
    # Has existing do block, prepend CQL args
    cql_args = build_cql_args_list(type_module)
    combined = prepend_to_block(existing_block, cql_args)
    [[{:do, combined}]]
  end

  defp inject_cql_args(rest, _type_module), do: rest

  defp build_cql_args_block(type_module) do
    filter_id = type_module.__cql_filter_input_identifier__()
    order_id = type_module.__cql_order_input_identifier__()

    {:__block__, [],
     [
       {:arg, [], [:where, filter_id]},
       {:arg, [], [:order_by, {:list_of, [], [order_id]}]}
     ]}
  end

  defp build_cql_args_list(type_module) do
    filter_id = type_module.__cql_filter_input_identifier__()
    order_id = type_module.__cql_order_input_identifier__()

    [
      {:arg, [], [:where, filter_id]},
      {:arg, [], [:order_by, {:list_of, [], [order_id]}]}
    ]
  end

  defp prepend_to_block({:__block__, meta, statements}, new_statements) do
    {:__block__, meta, new_statements ++ statements}
  end

  defp prepend_to_block(single_statement, new_statements) do
    {:__block__, [], new_statements ++ [single_statement]}
  end

  # Extract type references from field statements in the block
  defp extract_field_type_refs({:__block__, _, statements}) do
    Enum.flat_map(statements, &extract_field_type_refs/1)
  end

  defp extract_field_type_refs({:field, _, args}) do
    # Field can be: [name, type] or [name, type, do: block]
    # Extract return type
    return_type_refs = case extract_type_from_args(args) do
      nil -> []
      ref -> [ref]
    end

    # Extract arg types from do block
    arg_type_refs = extract_arg_types_from_field(args)

    return_type_refs ++ arg_type_refs
  end

  defp extract_field_type_refs(_), do: []

  # Extract arg type references from field args (looking for do block)
  defp extract_arg_types_from_field([_name, _type, [{:do, block}]]) do
    extract_arg_types_from_block(block)
  end

  defp extract_arg_types_from_field(_), do: []

  # Extract type refs from arg statements in a do block
  defp extract_arg_types_from_block({:__block__, _, statements}) do
    Enum.flat_map(statements, &extract_arg_type_ref/1)
  end

  defp extract_arg_types_from_block(single_statement) do
    extract_arg_type_ref(single_statement)
  end

  defp extract_arg_type_ref({:arg, _, [_name, type | _rest]}) do
    case unwrap_type_ref(type) do
      nil -> []
      ref -> [ref]
    end
  end

  defp extract_arg_type_ref(_), do: []

  defp extract_type_from_args([_name]), do: nil
  defp extract_type_from_args([_name, type]) when not is_list(type), do: unwrap_type_ref(type)
  defp extract_type_from_args([_name, type, _opts]) when not is_list(type), do: unwrap_type_ref(type)
  defp extract_type_from_args(_), do: nil

  defp unwrap_type_ref({:non_null, _, [inner]}), do: unwrap_type_ref(inner)
  defp unwrap_type_ref({:list_of, _, [inner]}), do: unwrap_type_ref(inner)
  defp unwrap_type_ref({:__aliases__, _, _} = module_ast), do: module_ast
  defp unwrap_type_ref(type) when is_atom(type), do: if(builtin?(type), do: nil, else: type)
  defp unwrap_type_ref(_), do: nil

  @builtins ~w(id string integer float boolean datetime date time naive_datetime decimal)a
  defp builtin?(type), do: type in @builtins

  @doc false
  defmacro __before_compile__(env) do
    has_queries = Module.get_attribute(env.module, :green_fairy_queries)

    # Get type references and expand any module aliases to actual module atoms
    type_refs = Module.get_attribute(env.module, :green_fairy_referenced_types) || []

    expanded_refs =
      Enum.map(type_refs, fn
        {:__aliases__, _, _} = ast -> Macro.expand(ast, env)
        other -> other
      end)
      |> Enum.reject(&is_nil/1)

    # Get expose types and generate fields for them
    expose_types = Module.get_attribute(env.module, :green_fairy_expose_types) || []

    expose_field_defs =
      Enum.map(expose_types, fn {type_module_ast, opts} ->
        type_module = Macro.expand(type_module_ast, env)
        generate_expose_field(type_module, opts, env)
      end)

    quote do
      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :queries,
          has_queries: unquote(has_queries || false)
        }
      end

      @doc false
      def __green_fairy_kind__ do
        :queries
      end

      @doc false
      def __green_fairy_referenced_types__ do
        unquote(expanded_refs)
      end

      @doc false
      def __green_fairy_expose_fields__ do
        unquote(Macro.escape(expose_field_defs))
      end
    end
  end

  # Generate an expose field definition
  defp generate_expose_field(type_module, opts, _env) do
    # Get type info from the module
    type_def =
      if function_exported?(type_module, :__green_fairy_definition__, 0) do
        type_module.__green_fairy_definition__()
      else
        %{}
      end

    type_name = Map.get(type_def, :type_name, type_module |> Module.split() |> List.last())
    type_identifier = Map.get(type_def, :type_identifier)
    struct_module = Map.get(type_def, :struct)

    # Determine field name
    field_name =
      Keyword.get_lazy(opts, :as, fn ->
        type_name
        |> Macro.underscore()
        |> String.to_atom()
      end)

    # Generate the expose field info
    %{
      field_name: field_name,
      type_module: type_module,
      type_name: type_name,
      type_identifier: type_identifier,
      struct_module: struct_module,
      opts: opts
    }
  end

  @doc """
  Generates the resolver function for an expose field.

  This is called at runtime to create the resolver that:
  1. Decodes the global ID
  2. Validates the type name matches
  3. Fetches the record from the database

  """
  def expose_resolver(type_name, struct_module, repo) do
    fn _parent, %{id: global_id}, _ctx ->
      case GreenFairy.GlobalId.decode_id(global_id) do
        {:ok, {^type_name, local_id}} ->
          if struct_module && repo do
            case repo.get(struct_module, local_id) do
              nil -> {:error, "#{type_name} not found"}
              record -> {:ok, record}
            end
          else
            {:error, "Cannot resolve #{type_name}: no struct or repo configured"}
          end

        {:ok, {other_type, _}} ->
          {:error, "Invalid ID type: expected #{type_name}, got #{other_type}"}

        {:error, reason} ->
          {:error, "Invalid ID: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Generates AST for expose fields to be included in the queries block.

  This is called during schema compilation to inject the expose field
  definitions into the queries object.
  """
  def generate_expose_fields_ast(expose_fields, repo) do
    Enum.map(expose_fields, fn field_def ->
      field_name = field_def.field_name
      type_identifier = field_def.type_identifier
      type_name = field_def.type_name
      struct_module = field_def.struct_module

      quote do
        field unquote(field_name), unquote(type_identifier) do
          arg(:id, non_null(:id))

          resolve(fn _parent, %{id: global_id}, _ctx ->
            case GreenFairy.GlobalId.decode_id(global_id) do
              {:ok, {unquote(type_name), local_id}} ->
                struct_module = unquote(struct_module)
                repo = unquote(repo)

                if struct_module && repo do
                  case repo.get(struct_module, local_id) do
                    nil -> {:error, "#{unquote(type_name)} not found"}
                    record -> {:ok, record}
                  end
                else
                  {:error, "Cannot resolve #{unquote(type_name)}: no struct or repo configured"}
                end

              {:ok, {other_type, _}} ->
                {:error, "Invalid ID type: expected #{unquote(type_name)}, got #{other_type}"}

              {:error, reason} ->
                {:error, "Invalid ID: #{inspect(reason)}"}
            end
          end)
        end
      end
    end)
  end
end


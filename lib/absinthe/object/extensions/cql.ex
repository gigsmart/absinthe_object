defmodule Absinthe.Object.Extensions.CQL do
  @moduledoc """
  CQL (Custom Query Language) extension for automatic filtering support.

  Uses the unified adapter system to detect and extract filter metadata from
  different data sources. Ships with an Ecto adapter, but can be extended
  for Elasticsearch, MongoDB, etc.

  ## Usage

      defmodule MyApp.GraphQL.Types.User do
        use Absinthe.Object.Type

        type "User", struct: MyApp.Accounts.User do
          use Absinthe.Object.Extensions.CQL

          field :id, non_null(:id)
          field :name, :string
          field :email, :string
          field :full_name, :string  # Computed field
        end
      end

  ## Generated Filter Types

  CQL generates filter input types following the GigSmart schema pattern:

  - `CqlFilter{Type}Input` - Main filter with `_and`, `_or`, `_not` combinators
  - `CqlOp{Type}Input` - Operator inputs for each field type (string, integer, etc.)

  For example, a User type generates:

      input CqlFilterUserInput {
        _and: [CqlFilterUserInput]
        _or: [CqlFilterUserInput]
        _not: CqlFilterUserInput
        id: CqlOpIdInput
        name: CqlOpStringInput
        email: CqlOpStringInput
      }

  ## How It Works

  1. CQL uses `Absinthe.Object.Adapter.find_adapter/2` to find an adapter for the struct
  2. The adapter extracts queryable fields and their types
  3. Operators are inferred from the adapter's type mappings
  4. Custom filters can override or extend adapter-detected fields

  ## Authorization Integration

  CQL integrates with the type's `authorize` callback to prevent users from
  filtering on fields they cannot see:

      type "User", struct: MyApp.User do
        use Absinthe.Object.Extensions.CQL

        authorize fn user, ctx ->
          if ctx[:current_user]?.admin do
            :all
          else
            [:id, :name]  # Non-admins can only filter on id and name
          end
        end

        field :id, non_null(:id)
        field :name, :string
        field :email, :string
        field :ssn, :string
      end

  Use `__cql_authorized_fields__/2` to get fields a user can filter on:

      authorized_fields = MyUserType.__cql_authorized_fields__(object, context)
      # [:id, :name]  # Only fields visible to this user

  ## Adapters

  Adapters implement the `Absinthe.Object.Adapter` behaviour. See that module
  for details on implementing custom adapters.

  Register adapters in config:

      config :absinthe_object, :adapters, [
        MyApp.ElasticsearchAdapter,
        Absinthe.Object.Adapters.Ecto
      ]

  Or per-type:

      type "User", struct: MyApp.User do
        use Absinthe.Object.Extensions.CQL, adapter: MyApp.CustomAdapter
        # ...
      end

  ## Custom Filters

  For computed fields or custom filter logic:

      custom_filter :full_name, [:eq, :contains], fn query, op, value ->
        # Your custom filter logic
      end

  Or use type shorthand:

      custom_filter :computed_score, :integer, fn query, op, value ->
        # Gets all integer operators automatically
      end

  ## Schema Integration

  Include CQL types in your schema:

      defmodule MyApp.Schema do
        use Absinthe.Schema
        use Absinthe.Object.Extensions.CQL.Schema

        # This imports all CQL operator types and generates filter types
        # for all registered CQL-enabled types
      end

  """

  use Absinthe.Object.Extension

  alias Absinthe.Object.Adapter
  alias Absinthe.Object.Extensions.CQL.FilterInput

  @impl true
  def using(opts) do
    adapter = Keyword.get(opts, :adapter)

    quote do
      import Absinthe.Object.Extensions.CQL.Macros
      Module.register_attribute(__MODULE__, :cql_custom_filters, accumulate: true)
      Module.register_attribute(__MODULE__, :cql_adapter_override, accumulate: false)

      if unquote(adapter) do
        @cql_adapter_override unquote(adapter)
      end
    end
  end

  @impl true
  def before_compile(env, config) do
    struct_module = config.struct
    type_name = config.type_name
    type_identifier = config.type_identifier
    custom_filters = Module.get_attribute(env.module, :cql_custom_filters) || []
    adapter_override = Module.get_attribute(env.module, :cql_adapter_override)
    adapter = Adapter.find_adapter(struct_module, adapter_override)

    {adapter_fields, adapter_field_types} = get_adapter_fields(adapter, struct_module)
    {custom_filter_meta, custom_filter_fields} = get_custom_filter_info(custom_filters)
    filter_function_clauses = generate_filter_clauses(custom_filters)

    generate_cql_functions(
      filter_function_clauses,
      struct_module,
      adapter,
      adapter_fields,
      adapter_field_types,
      custom_filter_meta,
      custom_filter_fields,
      type_name,
      type_identifier
    )
  end

  defp get_adapter_fields(nil, _struct_module), do: {[], %{}}
  defp get_adapter_fields(_adapter, nil), do: {[], %{}}

  defp get_adapter_fields(adapter, struct_module) do
    fields = adapter.queryable_fields(struct_module)
    types = Map.new(fields, fn f -> {f, adapter.field_type(struct_module, f)} end)
    {fields, types}
  end

  defp get_custom_filter_info(custom_filters) do
    meta =
      Map.new(custom_filters, fn cf ->
        {cf.field, %{field: cf.field, operators: cf.operators}}
      end)

    fields = Enum.map(custom_filters, & &1.field)
    {meta, fields}
  end

  defp generate_filter_clauses(custom_filters) do
    Enum.map(custom_filters, fn cf ->
      quote do
        def __cql_apply_custom_filter__(unquote(cf.field), query, op, value) do
          filter_fn = unquote(cf.filter_fn_ast)
          filter_fn.(query, op, value)
        end
      end
    end)
  end

  defp generate_cql_functions(
         filter_clauses,
         struct_module,
         adapter,
         adapter_fields,
         adapter_field_types,
         custom_filter_meta,
         custom_filter_fields,
         type_name,
         type_identifier
       ) do
    # Build field types for filter input generation
    # Include both adapter fields and custom filter fields
    adapter_filter_fields =
      adapter_fields
      |> Enum.map(fn field -> {field, Map.get(adapter_field_types, field)} end)

    custom_fields =
      custom_filter_fields
      |> Enum.map(fn field -> {field, nil} end)

    # Combine adapter and custom fields (adapter fields first, custom override if present)
    all_filter_fields = adapter_filter_fields ++ custom_fields
    filter_fields = Enum.uniq_by(all_filter_fields, fn {name, _type} -> name end)

    filter_input_identifier = FilterInput.filter_type_identifier(type_name)

    quote do
      unquote_splicing(filter_clauses)

      def __cql_apply_custom_filter__(_field, query, _op, _value), do: query

      def __cql_config__ do
        %{
          struct: unquote(struct_module),
          adapter: unquote(adapter),
          adapter_fields: unquote(adapter_fields),
          adapter_field_types: unquote(Macro.escape(adapter_field_types)),
          custom_filters: unquote(Macro.escape(custom_filter_meta)),
          custom_filter_fields: unquote(custom_filter_fields),
          type_name: unquote(type_name),
          type_identifier: unquote(type_identifier),
          filter_input_identifier: unquote(filter_input_identifier)
        }
      end

      def __cql_adapter__, do: unquote(adapter)

      def __cql_filterable_fields__ do
        Enum.uniq(unquote(adapter_fields) ++ unquote(custom_filter_fields))
      end

      @doc """
      Returns the filter input type identifier for this type.

      This is the GigSmart-style `CqlFilter{Type}Input` identifier.
      """
      def __cql_filter_input_identifier__ do
        unquote(filter_input_identifier)
      end

      @doc """
      Returns fields with their types for filter input generation.
      """
      def __cql_filter_fields__ do
        unquote(Macro.escape(filter_fields))
      end

      @doc """
      Returns fields that can be filtered, restricted by authorization.

      Uses the type's `authorize` callback to determine which fields the
      current user can see, then intersects with filterable fields.
      """
      def __cql_authorized_fields__(object, context) do
        all_filterable = __cql_filterable_fields__()

        # Call the type's authorize function to get visible fields
        info = %Absinthe.Object.AuthorizationInfo{}
        visible = __authorize__(object, context, info)

        case visible do
          :all -> all_filterable
          :none -> []
          fields when is_list(fields) -> Enum.filter(all_filterable, &(&1 in fields))
        end
      end

      @doc """
      Validates that a filter only uses authorized fields.

      Returns :ok if all filter fields are authorized, or
      {:error, {:unauthorized_fields, fields}} if any are not.
      """
      def __cql_validate_filter__(filter_fields, object, context) when is_list(filter_fields) do
        authorized = __cql_authorized_fields__(object, context)
        unauthorized = filter_fields -- authorized

        if Enum.empty?(unauthorized) do
          :ok
        else
          {:error, {:unauthorized_fields, unauthorized}}
        end
      end

      def __cql_validate_filter__(filter_map, object, context) when is_map(filter_map) do
        filter_fields = Map.keys(filter_map) -- [:_and, :_or, :_not]
        __cql_validate_filter__(filter_fields, object, context)
      end

      @doc """
      Returns operators for a field, only if the field is authorized.

      Returns empty list if the user cannot filter on this field.
      """
      def __cql_authorized_operators_for__(field, object, context) do
        authorized_fields = __cql_authorized_fields__(object, context)

        if field in authorized_fields do
          __cql_operators_for__(field)
        else
          []
        end
      end

      def __cql_operators_for__(field) do
        config = __cql_config__()

        cond do
          Map.has_key?(config.custom_filters, field) ->
            config.custom_filters[field].operators

          field in config.adapter_fields ->
            type = Map.get(config.adapter_field_types, field)
            adapter = config.adapter
            if adapter, do: adapter.operators_for_type(type), else: [:eq, :in]

          true ->
            []
        end
      end

      @doc """
      Generates the filter input AST for this type.

      This is used by the schema compiler to generate the CqlFilter{Type}Input type.
      """
      def __cql_generate_filter_input__ do
        config = __cql_config__()

        Absinthe.Object.Extensions.CQL.FilterInput.generate(
          config.type_name,
          __cql_filter_fields__(),
          config.custom_filters
        )
      end
    end
  end

  # ============================================================================
  # Macros
  # ============================================================================

  defmodule Macros do
    @moduledoc false

    defmacro custom_filter(field, operators, filter_fn) do
      operators = normalize_operators(operators)
      filter_fn_ast = Macro.escape(filter_fn)

      quote do
        @cql_custom_filters %{
          field: unquote(field),
          operators: unquote(operators),
          filter_fn_ast: unquote(filter_fn_ast)
        }
      end
    end

    defp normalize_operators(:string),
      do: [:eq, :neq, :contains, :starts_with, :ends_with, :in, :is_nil]

    defp normalize_operators(:integer), do: [:eq, :neq, :gt, :lt, :gte, :lte, :in, :is_nil]
    defp normalize_operators(:boolean), do: [:eq, :is_nil]
    defp normalize_operators(:datetime), do: [:eq, :neq, :gt, :lt, :gte, :lte, :is_nil]
    defp normalize_operators(ops) when is_list(ops), do: ops
    defp normalize_operators(_), do: [:eq, :in]
  end
end

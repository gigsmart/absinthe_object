defmodule GreenFairy.Adapter do
  @moduledoc """
  Behaviour for backing adapters that integrate data sources with GreenFairy.

  A backing adapter provides a unified interface for different data source concerns:

  - **CQL (Query Language)**: Field detection, type mapping, and operator inference
  - **DataLoader**: Batched data loading configuration
  - **Extensions**: Additional data source-specific capabilities

  ## Implementing an Adapter

      defmodule MyApp.ElasticsearchAdapter do
        @behaviour GreenFairy.Adapter

        # Core
        @impl true
        def handles?(module), do: function_exported?(module, :__es_index__, 0)

        # CQL Capabilities
        @impl true
        def queryable_fields(module), do: module.__es_mappings__() |> Map.keys()

        @impl true
        def field_type(module, field), do: module.__es_mappings__()[field][:type]

        @impl true
        def operators_for_type(type) do
          case type do
            :text -> [:eq, :contains, :in]
            :keyword -> [:eq, :neq, :in]
            :integer -> [:eq, :neq, :gt, :lt, :gte, :lte, :in]
            _ -> [:eq, :in]
          end
        end

        # DataLoader Capabilities
        @impl true
        def dataloader_source(_module), do: :elasticsearch

        @impl true
        def dataloader_batch_key(module, field, args) do
          {module, field, args}
        end

        # Extensions (optional)
        @impl true
        def capabilities, do: [:cql, :dataloader, :full_text_search]
      end

  ## Registering Adapters

  Register adapters globally in config:

      config :green_fairy, :adapters, [
        MyApp.ElasticsearchAdapter,
        GreenFairy.Adapters.Ecto
      ]

  Or per-type:

      type "User", struct: MyApp.User do
        use GreenFairy.Extensions.CQL, adapter: MyApp.CustomAdapter
      end

  ## Built-in Adapters

  - `GreenFairy.Adapters.Ecto` - For Ecto schemas
  """

  # ===========================================================================
  # Core Callbacks
  # ===========================================================================

  @doc """
  Returns true if this adapter can handle the given module.

  This is called during adapter discovery to find the appropriate adapter
  for a struct module.
  """
  @callback handles?(module :: module()) :: boolean()

  @doc """
  Returns the capabilities supported by this adapter.

  Common capabilities include:
  - `:cql` - Query language support (field filtering)
  - `:dataloader` - Batched data loading
  - `:full_text_search` - Full text search support
  - `:aggregations` - Aggregation queries

  Default implementation returns `[:cql, :dataloader]`.
  """
  @callback capabilities() :: [atom()]

  # ===========================================================================
  # CQL Callbacks
  # ===========================================================================

  @doc """
  Returns a list of queryable field atoms for the module.

  These are fields that can be filtered on using CQL.
  """
  @callback queryable_fields(module :: module()) :: [atom()]

  @doc """
  Returns the type of a field for operator inference.

  The return value should be an atom or tuple that can be matched
  in `operators_for_type/1`.
  """
  @callback field_type(module :: module(), field :: atom()) :: atom() | tuple() | nil

  @doc """
  Returns a list of operators supported for the given type.

  Common operators include:
  - `:eq` - equals
  - `:neq` - not equals
  - `:gt`, `:lt`, `:gte`, `:lte` - comparisons
  - `:in` - in list
  - `:contains`, `:starts_with`, `:ends_with` - string operations
  - `:is_nil` - null check
  """
  @callback operators_for_type(type :: atom() | tuple()) :: [atom()]

  # ===========================================================================
  # DataLoader Callbacks
  # ===========================================================================

  @doc """
  Returns the DataLoader source name for this module.

  This is used to determine which DataLoader source to use when
  loading associations. Defaults to `:repo`.
  """
  @callback dataloader_source(module :: module()) :: atom()

  @doc """
  Returns the batch key for DataLoader.

  This determines how items are batched together for loading.
  """
  @callback dataloader_batch_key(module :: module(), field :: atom(), args :: map()) :: term()

  @doc """
  Returns default args to merge into DataLoader queries for a field.

  This can be used to add default ordering, filters, or other constraints.
  """
  @callback dataloader_default_args(module :: module(), field :: atom()) :: map()

  # ===========================================================================
  # Optional Callbacks
  # ===========================================================================

  @optional_callbacks [
    capabilities: 0,
    dataloader_source: 1,
    dataloader_batch_key: 3,
    dataloader_default_args: 2
  ]

  # ===========================================================================
  # Helper Macros
  # ===========================================================================

  @doc """
  Use this module to get default implementations for optional callbacks.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour GreenFairy.Adapter

      @impl true
      def capabilities, do: [:cql, :dataloader]

      @impl true
      def dataloader_source(_module), do: :repo

      @impl true
      def dataloader_batch_key(_module, field, args) do
        {field, args}
      end

      @impl true
      def dataloader_default_args(_module, _field), do: %{}

      defoverridable capabilities: 0,
                     dataloader_source: 1,
                     dataloader_batch_key: 3,
                     dataloader_default_args: 2
    end
  end

  # ===========================================================================
  # Discovery
  # ===========================================================================

  @default_adapters [GreenFairy.Adapters.Ecto]

  @doc """
  Finds an adapter that can handle the given module.

  Checks adapters in order:
  1. Explicit adapter override
  2. Configured adapters from :green_fairy, :adapters
  3. Default adapters (Ecto)
  """
  def find_adapter(nil, _override), do: nil

  def find_adapter(module, override) when is_atom(override) and not is_nil(override) do
    if Code.ensure_loaded?(override) and override.handles?(module) do
      override
    else
      find_adapter(module, nil)
    end
  end

  def find_adapter(module, _override) do
    adapters = configured_adapters() ++ @default_adapters

    Enum.find(adapters, fn adapter ->
      Code.ensure_loaded?(adapter) and adapter.handles?(module)
    end)
  end

  @doc """
  Returns configured adapters from application environment.
  """
  def configured_adapters do
    Application.get_env(:green_fairy, :adapters, [])
  end

  @doc """
  Returns the default adapters.
  """
  def default_adapters, do: @default_adapters

  @doc """
  Checks if an adapter supports a capability.
  """
  def supports?(adapter, capability) when is_atom(adapter) and is_atom(capability) do
    if Code.ensure_loaded?(adapter) and function_exported?(adapter, :capabilities, 0) do
      capability in adapter.capabilities()
    else
      # Default capabilities for adapters that don't implement the callback
      capability in [:cql, :dataloader]
    end
  end

  # ===========================================================================
  # Filter Adapter Resolution
  # ===========================================================================

  @doc """
  Returns the filter adapter struct for the given struct module.

  This auto-detects the appropriate filter adapter based on the backing
  data source (Ecto repo, Elasticsearch, etc.).

  ## Options

  - `:repo` - Ecto repo module (auto-detected from struct if not provided)
  - `:extensions` - Database extensions (e.g., `[:postgis]`)
  - `:filter_adapter` - Explicit filter adapter struct to use

  ## Examples

      # Auto-detect from Ecto schema
      filter_adapter = Adapter.filter_adapter_for(MyApp.User)
      #=> %GreenFairy.Adapters.Ecto.Postgres{repo: MyApp.Repo}

      # With PostGIS extension
      filter_adapter = Adapter.filter_adapter_for(MyApp.User, extensions: [:postgis])
      #=> %GreenFairy.Adapters.Ecto.Postgres{repo: MyApp.Repo, extensions: [:postgis]}

      # Explicit adapter
      filter_adapter = Adapter.filter_adapter_for(MyApp.User,
        filter_adapter: %Adapters.Elasticsearch{index: "users"}
      )

  """
  def filter_adapter_for(struct_module, opts \\ []) do
    cond do
      # Explicit filter adapter provided
      opts[:filter_adapter] ->
        opts[:filter_adapter]

      # Ecto schema - auto-detect from repo
      ecto_schema?(struct_module) ->
        repo = opts[:repo] || infer_repo(struct_module)

        if repo do
          GreenFairy.Adapters.Ecto.Detector.adapter_for!(repo, opts)
        else
          # No repo found, fall back to Memory adapter
          GreenFairy.Adapters.Memory.new(struct_module, opts)
        end

      # Elasticsearch document
      elasticsearch_document?(struct_module) ->
        GreenFairy.Adapters.Elasticsearch.new(Keyword.put(opts, :model, struct_module))

      # Plain struct - use Memory adapter as fallback
      true ->
        GreenFairy.Adapters.Memory.new(struct_module, opts)
    end
  end

  defp elasticsearch_document?(module) do
    Code.ensure_loaded?(module) and
      (function_exported?(module, :__es_index__, 0) or
         function_exported?(module, :__mapping__, 0))
  end

  defp ecto_schema?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1)
  end

  defp infer_repo(struct_module) do
    # Try to find repo from module prefix
    # e.g., MyApp.Accounts.User -> MyApp.Repo
    parts = Module.split(struct_module)

    if length(parts) >= 2 do
      app_module = parts |> Enum.take(1) |> Module.concat()
      repo_module = Module.concat(app_module, Repo)

      if Code.ensure_loaded?(repo_module) and function_exported?(repo_module, :__adapter__, 0) do
        repo_module
      else
        nil
      end
    else
      nil
    end
  end
end

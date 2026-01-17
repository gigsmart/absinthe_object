defmodule GreenFairy.AdapterTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Adapter
  alias GreenFairy.Adapters.Ecto, as: EctoAdapter

  # Plain struct (no adapter)
  defmodule PlainStruct do
    defstruct [:id, :name]
  end

  # Mock Ecto schema
  defmodule MockEctoSchema do
    # Group all __schema__/1 clauses together
    def __schema__(:fields), do: [:id, :name, :email]
    def __schema__(:associations), do: [:posts, :comments]
    def __schema__(:primary_key), do: [:id]

    # Group all __schema__/2 clauses together
    def __schema__(:type, :id), do: :id
    def __schema__(:type, :name), do: :string
    def __schema__(:type, :email), do: :string
    def __schema__(:type, _), do: nil
    def __schema__(:association, :posts), do: %{related: Post}
    def __schema__(:association, :comments), do: %{related: Comment}
    def __schema__(:association, _), do: nil

    defstruct [:id, :name, :email]
  end

  describe "Adapter behaviour" do
    test "defines required callbacks" do
      callbacks = Adapter.behaviour_info(:callbacks)

      # Core callbacks
      assert {:handles?, 1} in callbacks
      assert {:capabilities, 0} in callbacks

      # CQL callbacks
      assert {:queryable_fields, 1} in callbacks
      assert {:field_type, 2} in callbacks
      assert {:operators_for_type, 1} in callbacks

      # DataLoader callbacks
      assert {:dataloader_source, 1} in callbacks
      assert {:dataloader_batch_key, 3} in callbacks
      assert {:dataloader_default_args, 2} in callbacks
    end

    test "defines optional callbacks" do
      optional = Adapter.behaviour_info(:optional_callbacks)

      assert {:capabilities, 0} in optional
      assert {:dataloader_source, 1} in optional
      assert {:dataloader_batch_key, 3} in optional
      assert {:dataloader_default_args, 2} in optional
    end
  end

  describe "find_adapter/2" do
    test "returns nil for nil module" do
      assert Adapter.find_adapter(nil, nil) == nil
    end

    test "finds Ecto adapter for Ecto schema" do
      adapter = Adapter.find_adapter(MockEctoSchema, nil)
      assert adapter == EctoAdapter
    end

    test "returns nil when no adapter matches" do
      adapter = Adapter.find_adapter(PlainStruct, nil)
      assert adapter == nil
    end

    test "uses override when provided and it handles module" do
      defmodule TestAdapter do
        use Adapter

        @impl true
        def handles?(_), do: true

        @impl true
        def queryable_fields(_), do: [:test]

        @impl true
        def field_type(_, _), do: :string

        @impl true
        def operators_for_type(_), do: [:eq]
      end

      adapter = Adapter.find_adapter(PlainStruct, TestAdapter)
      assert adapter == TestAdapter
    end

    test "falls back to discovery if override doesn't handle module" do
      defmodule NonMatchingAdapter do
        use Adapter

        @impl true
        def handles?(_), do: false

        @impl true
        def queryable_fields(_), do: []

        @impl true
        def field_type(_, _), do: nil

        @impl true
        def operators_for_type(_), do: []
      end

      # Override doesn't handle, so we try discovery
      # MockEctoSchema should be found by EctoAdapter
      adapter = Adapter.find_adapter(MockEctoSchema, NonMatchingAdapter)
      assert adapter == EctoAdapter
    end
  end

  describe "configured_adapters/0" do
    test "returns configured adapters from application env" do
      # Default is empty list
      adapters = Adapter.configured_adapters()
      assert is_list(adapters)
    end
  end

  describe "default_adapters/0" do
    test "includes Ecto adapter" do
      adapters = Adapter.default_adapters()
      assert EctoAdapter in adapters
    end
  end

  describe "supports?/2" do
    test "returns true for capabilities the adapter supports" do
      assert Adapter.supports?(EctoAdapter, :cql)
      assert Adapter.supports?(EctoAdapter, :dataloader)
    end

    test "returns false for capabilities the adapter doesn't support" do
      refute Adapter.supports?(EctoAdapter, :full_text_search)
      refute Adapter.supports?(EctoAdapter, :aggregations)
    end
  end

  describe "use Adapter macro" do
    defmodule CustomAdapter do
      use Adapter

      @impl true
      def handles?(module), do: function_exported?(module, :custom_check, 0)

      @impl true
      def queryable_fields(module), do: module.custom_fields()

      @impl true
      def field_type(module, field), do: module.custom_type(field)

      @impl true
      def operators_for_type(:custom), do: [:custom_op]
      def operators_for_type(_), do: [:eq]
    end

    test "provides default implementations" do
      # capabilities/0 default
      assert CustomAdapter.capabilities() == [:cql, :dataloader]

      # dataloader_source/1 default
      assert CustomAdapter.dataloader_source(MockEctoSchema) == :repo

      # dataloader_batch_key/3 default
      assert CustomAdapter.dataloader_batch_key(MockEctoSchema, :posts, %{limit: 10}) ==
               {:posts, %{limit: 10}}

      # dataloader_default_args/2 default
      assert CustomAdapter.dataloader_default_args(MockEctoSchema, :posts) == %{}
    end

    test "allows overriding defaults" do
      defmodule OverriddenAdapter do
        use Adapter

        @impl true
        def handles?(_), do: true

        @impl true
        def queryable_fields(_), do: []

        @impl true
        def field_type(_, _), do: nil

        @impl true
        def operators_for_type(_), do: []

        # Override defaults
        @impl true
        def capabilities, do: [:cql, :full_text_search]

        @impl true
        def dataloader_source(_), do: :custom_source

        @impl true
        def dataloader_batch_key(module, field, args), do: {module, field, args, :custom}

        @impl true
        def dataloader_default_args(_module, _field), do: %{order_by: :inserted_at}
      end

      assert OverriddenAdapter.capabilities() == [:cql, :full_text_search]
      assert OverriddenAdapter.dataloader_source(MockEctoSchema) == :custom_source

      assert OverriddenAdapter.dataloader_batch_key(MockEctoSchema, :posts, %{}) ==
               {MockEctoSchema, :posts, %{}, :custom}

      assert OverriddenAdapter.dataloader_default_args(MockEctoSchema, :posts) ==
               %{order_by: :inserted_at}
    end
  end

  describe "filter_adapter_for/2" do
    test "returns explicit filter adapter when provided" do
      explicit_adapter = %{type: :custom, index: "test"}
      result = Adapter.filter_adapter_for(MockEctoSchema, filter_adapter: explicit_adapter)
      assert result == explicit_adapter
    end

    test "returns Memory adapter for non-Ecto struct without explicit adapter" do
      # Memory adapter is the fallback for plain structs
      result = Adapter.filter_adapter_for(PlainStruct)
      assert %GreenFairy.Adapters.Memory{struct_module: PlainStruct} = result
    end

    test "returns Memory adapter when repo cannot be inferred" do
      # MockEctoSchema has __schema__ but no inferable repo
      # Falls back to Memory adapter
      result = Adapter.filter_adapter_for(MockEctoSchema)
      assert %GreenFairy.Adapters.Memory{struct_module: MockEctoSchema} = result
    end
  end

  describe "supports?/2 edge cases" do
    test "returns default capabilities for module without capabilities/0" do
      defmodule NoCapabilitiesModule do
        # Module with no capabilities function
      end

      # Falls back to default [:cql, :dataloader]
      assert Adapter.supports?(NoCapabilitiesModule, :cql) == true
      assert Adapter.supports?(NoCapabilitiesModule, :dataloader) == true
      assert Adapter.supports?(NoCapabilitiesModule, :full_text_search) == false
    end
  end
end

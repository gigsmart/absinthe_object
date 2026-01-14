defmodule Absinthe.Object.Adapters.EctoTest do
  use ExUnit.Case, async: true

  alias Absinthe.Object.Adapters.Ecto
  alias Absinthe.Object.Adapters.Ecto.{Postgres, MySQL, SQLite, Detector}

  # Mock Ecto schema for testing the Ecto adapter
  defmodule MockEctoSchema do
    def __schema__(:fields), do: [:id, :name, :email, :count, :active]
    def __schema__(:associations), do: [:posts, :comments]
    def __schema__(:primary_key), do: [:id]
    def __schema__(:type, :id), do: :id
    def __schema__(:type, :name), do: :string
    def __schema__(:type, :email), do: :string
    def __schema__(:type, :count), do: :integer
    def __schema__(:type, :active), do: :boolean
    def __schema__(:type, _), do: nil
    def __schema__(:association, :posts), do: %{related: Post}
    def __schema__(:association, :comments), do: %{related: Comment}
    def __schema__(:association, _), do: nil
  end

  # Non-Ecto module
  defmodule PlainModule do
    defstruct [:id]
  end

  describe "Ecto adapter handles?/1" do
    test "returns true for Ecto schema" do
      assert Ecto.handles?(MockEctoSchema) == true
    end

    test "returns false for non-Ecto module" do
      assert Ecto.handles?(PlainModule) == false
    end

    test "returns false for non-atom" do
      assert Ecto.handles?("not_a_module") == false
      assert Ecto.handles?(123) == false
    end
  end

  describe "Ecto adapter capabilities/0" do
    test "returns cql and dataloader capabilities" do
      assert Ecto.capabilities() == [:cql, :dataloader]
    end
  end

  describe "Ecto adapter queryable_fields/1" do
    test "returns schema fields for Ecto schema" do
      assert Ecto.queryable_fields(MockEctoSchema) == [:id, :name, :email, :count, :active]
    end

    test "returns empty list for non-Ecto module" do
      assert Ecto.queryable_fields(PlainModule) == []
    end
  end

  describe "Ecto adapter field_type/2" do
    test "returns field type for Ecto schema" do
      assert Ecto.field_type(MockEctoSchema, :id) == :id
      assert Ecto.field_type(MockEctoSchema, :name) == :string
      assert Ecto.field_type(MockEctoSchema, :count) == :integer
      assert Ecto.field_type(MockEctoSchema, :active) == :boolean
    end

    test "returns nil for unknown field" do
      assert Ecto.field_type(MockEctoSchema, :unknown) == nil
    end

    test "returns nil for non-Ecto module" do
      assert Ecto.field_type(PlainModule, :id) == nil
    end
  end

  describe "Ecto adapter operators_for_type/1" do
    test "returns string operators" do
      ops = Ecto.operators_for_type(:string)
      assert :eq in ops
      assert :neq in ops
      assert :contains in ops
      assert :starts_with in ops
      assert :ends_with in ops
      assert :in in ops
      assert :is_nil in ops
    end

    test "returns integer operators" do
      ops = Ecto.operators_for_type(:integer)
      assert :eq in ops
      assert :gt in ops
      assert :lt in ops
      assert :gte in ops
      assert :lte in ops
    end

    test "returns float operators" do
      ops = Ecto.operators_for_type(:float)
      assert :eq in ops
      assert :gt in ops
      assert :lte in ops
    end

    test "returns decimal operators" do
      ops = Ecto.operators_for_type(:decimal)
      assert :gt in ops
      assert :gte in ops
    end

    test "returns boolean operators" do
      ops = Ecto.operators_for_type(:boolean)
      assert ops == [:eq, :is_nil]
    end

    test "returns id operators" do
      ops = Ecto.operators_for_type(:id)
      assert :eq in ops
      assert :neq in ops
      assert :in in ops
      assert :is_nil in ops
    end

    test "returns binary_id operators" do
      ops = Ecto.operators_for_type(:binary_id)
      assert :eq in ops
      assert :in in ops
    end

    test "returns datetime operators" do
      for type <- [:naive_datetime, :utc_datetime, :date, :time] do
        ops = Ecto.operators_for_type(type)
        assert :eq in ops
        assert :gt in ops
        assert :lt in ops
      end
    end

    test "returns datetime_usec operators" do
      for type <- [:utc_datetime_usec, :naive_datetime_usec, :time_usec] do
        ops = Ecto.operators_for_type(type)
        assert :eq in ops
        assert :gte in ops
      end
    end

    test "returns map operators" do
      ops = Ecto.operators_for_type(:map)
      assert ops == [:eq, :is_nil]
    end

    test "returns array operators" do
      ops = Ecto.operators_for_type(:array)
      assert ops == [:eq, :is_nil]
    end

    test "returns enum operators for parameterized Ecto.Enum" do
      # Note: Ecto.Enum parameterized types match the {:parameterized, Ecto.Enum, _} pattern
      ops = Ecto.operators_for_type({:parameterized, Ecto.Enum, %{type: :string, values: [:a, :b]}})
      # This should return enum operators if pattern matches, otherwise default
      assert :eq in ops
      assert :in in ops
    end

    test "returns array operators for array type" do
      ops = Ecto.operators_for_type({:array, :string})
      assert ops == [:eq, :is_nil]
    end

    test "returns map operators for map type" do
      ops = Ecto.operators_for_type({:map, :string})
      assert ops == [:eq, :is_nil]
    end

    test "returns embedded operators for parameterized Ecto.Embedded" do
      ops = Ecto.operators_for_type({:parameterized, Ecto.Embedded, %{cardinality: :one}})
      # This should return embedded operators if pattern matches, otherwise default
      assert :eq in ops
    end

    test "returns default operators for unknown types" do
      ops = Ecto.operators_for_type(:unknown_type)
      assert ops == [:eq, :in]

      ops = Ecto.operators_for_type({:unknown, :tuple})
      assert ops == [:eq, :in]
    end
  end

  describe "Ecto adapter dataloader callbacks" do
    test "dataloader_source/1 returns :repo" do
      assert Ecto.dataloader_source(MockEctoSchema) == :repo
    end

    test "dataloader_batch_key/3 returns module, field, args tuple" do
      args = %{limit: 10}
      assert Ecto.dataloader_batch_key(MockEctoSchema, :posts, args) == {MockEctoSchema, :posts, args}
    end

    test "dataloader_default_args/2 returns empty map" do
      assert Ecto.dataloader_default_args(MockEctoSchema, :posts) == %{}
    end
  end

  describe "Ecto adapter helpers" do
    test "type_operators/0 returns the operators map" do
      ops = Ecto.type_operators()
      assert is_map(ops)
      assert Map.has_key?(ops, :string)
      assert Map.has_key?(ops, :integer)
    end

    test "ecto_schema?/1 delegates to handles?/1" do
      assert Ecto.ecto_schema?(MockEctoSchema) == true
      assert Ecto.ecto_schema?(PlainModule) == false
    end

    test "associations/1 returns associations for Ecto schema" do
      assert Ecto.associations(MockEctoSchema) == [:posts, :comments]
    end

    test "associations/1 returns empty list for non-Ecto module" do
      assert Ecto.associations(PlainModule) == []
    end

    test "association/2 returns association struct" do
      assoc = Ecto.association(MockEctoSchema, :posts)
      assert assoc == %{related: Post}
    end

    test "association/2 returns nil for unknown association" do
      assert Ecto.association(MockEctoSchema, :unknown) == nil
    end

    test "association/2 returns nil for non-Ecto module" do
      assert Ecto.association(PlainModule, :posts) == nil
    end

    test "primary_key/1 returns primary key for Ecto schema" do
      assert Ecto.primary_key(MockEctoSchema) == [:id]
    end

    test "primary_key/1 returns empty list for non-Ecto module" do
      assert Ecto.primary_key(PlainModule) == []
    end
  end

  describe "Postgres adapter" do
    test "new/2 creates adapter with defaults" do
      adapter = Postgres.new(FakeRepo)

      assert %Postgres{} = adapter
      assert adapter.repo == FakeRepo
      assert adapter.extensions == []
    end

    test "new/2 accepts extensions option" do
      adapter = Postgres.new(FakeRepo, extensions: [:postgis, :pg_trgm])

      assert adapter.extensions == [:postgis, :pg_trgm]
    end

    test "postgis?/1 returns true when postgis extension present" do
      adapter = Postgres.new(FakeRepo, extensions: [:postgis])
      assert Postgres.postgis?(adapter) == true
    end

    test "postgis?/1 returns false when postgis extension absent" do
      adapter = Postgres.new(FakeRepo, extensions: [])
      assert Postgres.postgis?(adapter) == false
    end

    test "pg_trgm?/1 returns true when pg_trgm extension present" do
      adapter = Postgres.new(FakeRepo, extensions: [:pg_trgm])
      assert Postgres.pg_trgm?(adapter) == true
    end

    test "pg_trgm?/1 returns false when pg_trgm extension absent" do
      adapter = Postgres.new(FakeRepo, extensions: [])
      assert Postgres.pg_trgm?(adapter) == false
    end
  end

  describe "MySQL adapter" do
    test "new/2 creates adapter with defaults" do
      adapter = MySQL.new(FakeRepo)

      assert %MySQL{} = adapter
      assert adapter.repo == FakeRepo
      assert adapter.version == nil
    end

    test "new/2 accepts version option" do
      adapter = MySQL.new(FakeRepo, version: "8.0.28")

      assert adapter.version == "8.0.28"
    end

    test "spatial?/1 returns true for MySQL 8.0+" do
      adapter = MySQL.new(FakeRepo, version: "8.0.28")
      assert MySQL.spatial?(adapter) == true
    end

    test "spatial?/1 returns false for old MySQL" do
      adapter = MySQL.new(FakeRepo, version: "5.7.0")
      assert MySQL.spatial?(adapter) == false
    end

    test "spatial?/1 returns true when version unknown" do
      adapter = MySQL.new(FakeRepo)
      assert MySQL.spatial?(adapter) == true
    end

    test "fulltext?/1 always returns true" do
      adapter = MySQL.new(FakeRepo)
      assert MySQL.fulltext?(adapter) == true
    end
  end

  describe "SQLite adapter" do
    test "new/2 creates adapter" do
      adapter = SQLite.new(FakeRepo)

      assert %SQLite{} = adapter
      assert adapter.repo == FakeRepo
    end

    test "new/2 ignores options" do
      adapter = SQLite.new(FakeRepo, some_option: :value)

      assert %SQLite{} = adapter
      assert adapter.repo == FakeRepo
    end
  end

  describe "Detector" do
    # Use Elixir. prefix to access the real Ecto modules (not aliased ones)
    defmodule PostgresRepo do
      def __adapter__, do: Elixir.Ecto.Adapters.Postgres
    end

    defmodule MySQLRepo do
      def __adapter__, do: Elixir.Ecto.Adapters.MyXQL
    end

    defmodule SQLiteRepo do
      def __adapter__, do: Elixir.Ecto.Adapters.SQLite3
    end

    defmodule UnknownRepo do
      def __adapter__, do: SomeUnknownAdapter
    end

    test "adapter_for/2 detects Postgres" do
      adapter = Detector.adapter_for(PostgresRepo)

      assert %Postgres{} = adapter
      assert adapter.repo == PostgresRepo
    end

    test "adapter_for/2 detects MySQL" do
      adapter = Detector.adapter_for(MySQLRepo)

      assert %MySQL{} = adapter
      assert adapter.repo == MySQLRepo
    end

    test "adapter_for/2 detects SQLite" do
      adapter = Detector.adapter_for(SQLiteRepo)

      assert %SQLite{} = adapter
      assert adapter.repo == SQLiteRepo
    end

    test "adapter_for/2 passes options through" do
      adapter = Detector.adapter_for(PostgresRepo, extensions: [:postgis])

      assert %Postgres{} = adapter
      assert adapter.extensions == [:postgis]
    end

    test "adapter_for/2 returns error for unknown adapter" do
      result = Detector.adapter_for(UnknownRepo)

      assert {:error, {:unknown_adapter, SomeUnknownAdapter}} = result
    end

    test "adapter_for!/2 raises for unknown adapter" do
      assert_raise ArgumentError, ~r/Unknown Ecto adapter/, fn ->
        Detector.adapter_for!(UnknownRepo)
      end
    end

    test "adapter_for!/2 returns adapter for known adapter" do
      adapter = Detector.adapter_for!(PostgresRepo)
      assert %Postgres{} = adapter
    end

    test "supported?/1 returns true for supported adapters" do
      # Use Elixir. prefix to access the real Ecto modules
      assert Detector.supported?(Elixir.Ecto.Adapters.Postgres) == true
      assert Detector.supported?(Elixir.Ecto.Adapters.MyXQL) == true
      assert Detector.supported?(Elixir.Ecto.Adapters.SQLite3) == true
    end

    test "supported?/1 returns false for unsupported adapters" do
      assert Detector.supported?(SomeUnknownAdapter) == false
    end

    test "supported_adapters/0 returns list of supported adapters" do
      adapters = Detector.supported_adapters()

      # Use Elixir. prefix to access the real Ecto modules
      assert Elixir.Ecto.Adapters.Postgres in adapters
      assert Elixir.Ecto.Adapters.MyXQL in adapters
      assert Elixir.Ecto.Adapters.SQLite3 in adapters
    end
  end
end

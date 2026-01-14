defmodule Absinthe.Object.Adapters.EctoTest do
  use ExUnit.Case, async: true

  alias Absinthe.Object.Adapters.Ecto.{Postgres, MySQL, SQLite, Detector}

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
    defmodule PostgresRepo do
      def __adapter__, do: Ecto.Adapters.Postgres
    end

    defmodule MySQLRepo do
      def __adapter__, do: Ecto.Adapters.MyXQL
    end

    defmodule SQLiteRepo do
      def __adapter__, do: Ecto.Adapters.SQLite3
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
      assert Detector.supported?(Ecto.Adapters.Postgres) == true
      assert Detector.supported?(Ecto.Adapters.MyXQL) == true
      assert Detector.supported?(Ecto.Adapters.SQLite3) == true
    end

    test "supported?/1 returns false for unsupported adapters" do
      assert Detector.supported?(SomeUnknownAdapter) == false
    end

    test "supported_adapters/0 returns list of supported adapters" do
      adapters = Detector.supported_adapters()

      assert Ecto.Adapters.Postgres in adapters
      assert Ecto.Adapters.MyXQL in adapters
      assert Ecto.Adapters.SQLite3 in adapters
    end
  end
end

defmodule GreenFairy.FilterTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Filter

  # Define test modules at module level
  defmodule TestAdapter do
    defstruct [:name]
  end

  defmodule TestFilter do
    defstruct [:value]
  end

  defmodule TestImpl do
    def apply(_adapter, %{value: value}, field, query) do
      {:ok, Map.put(query, field, value)}
    end
  end

  defmodule UnregisteredAdapter do
    defstruct [:name]
  end

  defmodule UnregisteredFilter do
    defstruct [:value]
  end

  defmodule TestAdapter2 do
    defstruct [:name]
  end

  defmodule TestFilter2 do
    defstruct [:value]
  end

  defmodule TestImpl2 do
    def apply(_adapter, %{value: value}, field, query) do
      {:ok, Map.put(query, field, value)}
    end
  end

  defmodule TestAdapter3 do
    defstruct [:name]
  end

  defmodule TestFilter3 do
    defstruct [:value]
  end

  defmodule RegAdapter do
    defstruct []
  end

  defmodule RegFilter do
    defstruct []
  end

  defmodule RegImpl do
    def apply(_, _, _, q), do: {:ok, q}
  end

  defmodule UnregAdapter do
    defstruct []
  end

  defmodule UnregFilter do
    defstruct []
  end

  describe "Filter.apply/4" do
    test "dispatches to registered implementation" do
      # Register the implementation
      Filter.register_implementation(TestAdapter, TestFilter, TestImpl)

      # Test dispatch
      adapter = %TestAdapter{name: "test"}
      filter = %TestFilter{value: "hello"}

      assert {:ok, %{name: "hello"}} = Filter.apply(adapter, filter, :name, %{})
    end

    test "returns error for unregistered combination" do
      adapter = %UnregisteredAdapter{name: "test"}
      filter = %UnregisteredFilter{value: "fail"}

      result = Filter.apply(adapter, filter, :field, %{})

      assert {:error, {:no_filter_implementation, UnregisteredAdapter, UnregisteredFilter}} = result
    end
  end

  describe "Filter.apply!/4" do
    test "returns result on success" do
      Filter.register_implementation(TestAdapter2, TestFilter2, TestImpl2)

      adapter = %TestAdapter2{name: "test"}
      filter = %TestFilter2{value: "world"}

      assert %{field: "world"} = Filter.apply!(adapter, filter, :field, %{})
    end

    test "raises on error" do
      # Don't register implementation - should fail
      adapter = %TestAdapter3{name: "test"}
      filter = %TestFilter3{value: "fail"}

      assert_raise RuntimeError, ~r/Filter error/, fn ->
        Filter.apply!(adapter, filter, :field, %{})
      end
    end
  end

  describe "Filter.register_implementation/3" do
    test "registers an implementation" do
      assert :ok = Filter.register_implementation(RegAdapter, RegFilter, RegImpl)
      assert RegImpl == Filter.get_implementation(RegAdapter, RegFilter)
    end
  end

  describe "Filter.get_implementation/2" do
    test "returns nil for unregistered combination" do
      assert nil == Filter.get_implementation(UnregAdapter, UnregFilter)
    end
  end

  describe "Filter.registered_implementations/0" do
    test "returns map of all registrations" do
      impls = Filter.registered_implementations()
      assert is_map(impls)
    end
  end
end

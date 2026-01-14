defmodule Absinthe.Object.Filter.ImplTest do
  use ExUnit.Case, async: true

  # Define test modules at the module level so they're accessible throughout tests
  defmodule TestAdapterForImpl do
    defstruct [:name]
  end

  defmodule TestFilterForImpl do
    defstruct [:value]
  end

  defmodule TestFilterImplementation do
    use Absinthe.Object.Filter.Impl,
      adapter: Absinthe.Object.Filter.ImplTest.TestAdapterForImpl

    filter_impl Absinthe.Object.Filter.ImplTest.TestFilterForImpl do
      def apply(_adapter, %{value: val}, field, query) do
        {:ok, Map.put(query, field, val)}
      end
    end
  end

  defmodule MultiAdapter do
    defstruct [:name]
  end

  defmodule FilterA do
    defstruct [:a]
  end

  defmodule FilterB do
    defstruct [:b]
  end

  defmodule MultiFilterImpl do
    use Absinthe.Object.Filter.Impl,
      adapter: Absinthe.Object.Filter.ImplTest.MultiAdapter

    filter_impl Absinthe.Object.Filter.ImplTest.FilterA do
      def apply(_adapter, %{a: val}, field, query) do
        {:ok, Map.put(query, field, {:a, val})}
      end
    end

    filter_impl Absinthe.Object.Filter.ImplTest.FilterB do
      def apply(_adapter, %{b: val}, field, query) do
        {:ok, Map.put(query, field, {:b, val})}
      end
    end
  end

  describe "filter_impl macro" do
    test "defines implementation module and registers it" do
      # Check that __adapter__ is defined
      assert TestFilterImplementation.__adapter__() == TestAdapterForImpl

      # Check that __filter_impls__ is defined
      assert TestFilterForImpl in TestFilterImplementation.__filter_impls__()

      # Check that the implementation works via Filter.apply
      adapter = %TestAdapterForImpl{name: "test"}
      filter = %TestFilterForImpl{value: "success"}

      assert {:ok, %{field: "success"}} =
               Absinthe.Object.Filter.apply(adapter, filter, :field, %{})
    end

    test "supports multiple filter implementations in one module" do
      # Both filters should be registered
      assert FilterA in MultiFilterImpl.__filter_impls__()
      assert FilterB in MultiFilterImpl.__filter_impls__()

      adapter = %MultiAdapter{name: "multi"}

      # Test FilterA
      assert {:ok, %{x: {:a, 1}}} =
               Absinthe.Object.Filter.apply(adapter, %FilterA{a: 1}, :x, %{})

      # Test FilterB
      assert {:ok, %{y: {:b, 2}}} =
               Absinthe.Object.Filter.apply(adapter, %FilterB{b: 2}, :y, %{})
    end
  end
end

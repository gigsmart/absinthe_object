defmodule GreenFairy.CQL.Adapters.MemoryAdapterTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Adapters.Memory

  defmodule TestUser do
    defstruct [:id, :name, :email, :age, :tags]
  end

  describe "apply_filters/2" do
    test "returns items unchanged when filter is nil" do
      items = [%TestUser{id: 1, name: "Alice"}]
      assert Memory.apply_filters(items, nil) == items
    end

    test "returns items unchanged when filter is empty map" do
      items = [%TestUser{id: 1, name: "Alice"}]
      assert Memory.apply_filters(items, %{}) == items
    end

    test "filters with _eq operator" do
      items = [
        %TestUser{id: 1, name: "Alice"},
        %TestUser{id: 2, name: "Bob"}
      ]

      result = Memory.apply_filters(items, %{name: %{_eq: "Alice"}})
      assert [%TestUser{name: "Alice"}] = result
    end

    test "filters with _neq operator" do
      items = [
        %TestUser{id: 1, name: "Alice"},
        %TestUser{id: 2, name: "Bob"}
      ]

      result = Memory.apply_filters(items, %{name: %{_neq: "Alice"}})
      assert [%TestUser{name: "Bob"}] = result
    end

    test "filters with comparison operators" do
      items = [
        %TestUser{id: 1, age: 20},
        %TestUser{id: 2, age: 30},
        %TestUser{id: 3, age: 40}
      ]

      assert length(Memory.apply_filters(items, %{age: %{_gt: 25}})) == 2
      assert length(Memory.apply_filters(items, %{age: %{_gte: 30}})) == 2
      assert length(Memory.apply_filters(items, %{age: %{_lt: 35}})) == 2
      assert length(Memory.apply_filters(items, %{age: %{_lte: 30}})) == 2
    end

    test "filters with _in operator" do
      items = [
        %TestUser{id: 1, name: "Alice"},
        %TestUser{id: 2, name: "Bob"},
        %TestUser{id: 3, name: "Charlie"}
      ]

      result = Memory.apply_filters(items, %{name: %{_in: ["Alice", "Charlie"]}})
      assert length(result) == 2
    end

    test "filters with _nin operator" do
      items = [
        %TestUser{id: 1, name: "Alice"},
        %TestUser{id: 2, name: "Bob"},
        %TestUser{id: 3, name: "Charlie"}
      ]

      result = Memory.apply_filters(items, %{name: %{_nin: ["Alice"]}})
      assert length(result) == 2
    end

    test "filters with _is_null operator" do
      items = [
        %TestUser{id: 1, name: "Alice"},
        %TestUser{id: 2, name: nil}
      ]

      result = Memory.apply_filters(items, %{name: %{_is_null: true}})
      assert [%TestUser{id: 2}] = result

      result = Memory.apply_filters(items, %{name: %{_is_null: false}})
      assert [%TestUser{id: 1}] = result
    end

    test "filters with array _includes operator" do
      items = [
        %TestUser{id: 1, tags: ["admin", "user"]},
        %TestUser{id: 2, tags: ["user"]}
      ]

      result = Memory.apply_filters(items, %{tags: %{_includes: "admin"}})
      assert [%TestUser{id: 1}] = result
    end

    test "combines multiple field filters with AND" do
      items = [
        %TestUser{id: 1, name: "Alice", age: 30},
        %TestUser{id: 2, name: "Bob", age: 30},
        %TestUser{id: 3, name: "Alice", age: 25}
      ]

      result = Memory.apply_filters(items, %{name: %{_eq: "Alice"}, age: %{_gte: 30}})
      assert [%TestUser{id: 1, name: "Alice", age: 30}] = result
    end
  end

  describe "apply_order/2" do
    test "returns items unchanged when order is nil" do
      items = [%TestUser{id: 1}, %TestUser{id: 2}]
      assert Memory.apply_order(items, nil) == items
    end

    test "returns items unchanged when order is empty list" do
      items = [%TestUser{id: 1}, %TestUser{id: 2}]
      assert Memory.apply_order(items, []) == items
    end

    test "sorts by field ascending" do
      items = [
        %TestUser{id: 2, name: "Bob"},
        %TestUser{id: 1, name: "Alice"}
      ]

      result = Memory.apply_order(items, [%{field: :name, direction: :asc}])
      assert [%{name: "Alice"}, %{name: "Bob"}] = result
    end

    test "sorts by field descending" do
      items = [
        %TestUser{id: 1, name: "Alice"},
        %TestUser{id: 2, name: "Bob"}
      ]

      result = Memory.apply_order(items, [%{field: :name, direction: :desc}])
      assert [%{name: "Bob"}, %{name: "Alice"}] = result
    end

    test "sorts by multiple fields" do
      items = [
        %TestUser{id: 1, name: "Alice", age: 30},
        %TestUser{id: 2, name: "Bob", age: 25},
        %TestUser{id: 3, name: "Alice", age: 25}
      ]

      result =
        Memory.apply_order(items, [
          %{field: :name, direction: :asc},
          %{field: :age, direction: :asc}
        ])

      assert [%{id: 3}, %{id: 1}, %{id: 2}] = result
    end

    test "handles nil values in sorting" do
      items = [
        %TestUser{id: 1, name: "Alice"},
        %TestUser{id: 2, name: nil},
        %TestUser{id: 3, name: "Bob"}
      ]

      result = Memory.apply_order(items, [%{field: :name, direction: :asc}])
      # nil values go to the end in ascending
      assert [%{name: "Alice"}, %{name: "Bob"}, %{name: nil}] = result
    end
  end

  describe "apply_query/3" do
    test "applies both filter and order" do
      items = [
        %TestUser{id: 1, name: "Alice", age: 30},
        %TestUser{id: 2, name: "Bob", age: 25},
        %TestUser{id: 3, name: "Charlie", age: 35}
      ]

      result =
        Memory.apply_query(
          items,
          %{age: %{_gte: 30}},
          [%{field: :age, direction: :desc}]
        )

      assert [%{name: "Charlie"}, %{name: "Alice"}] = result
    end
  end

  describe "adapter callbacks" do
    test "sort_directions returns asc and desc" do
      assert Memory.sort_directions() == [:asc, :desc]
    end

    test "supports_geo_ordering? returns false" do
      refute Memory.supports_geo_ordering?()
    end

    test "supports_priority_ordering? returns false" do
      refute Memory.supports_priority_ordering?()
    end

    test "capabilities includes in_memory flag" do
      caps = Memory.capabilities()
      assert caps.in_memory == true
    end

    test "supported_operators returns basic scalar operators" do
      ops = Memory.supported_operators(:scalar, :any)
      assert :_eq in ops
      assert :_neq in ops
      assert :_gt in ops
      assert :_in in ops
    end
  end
end

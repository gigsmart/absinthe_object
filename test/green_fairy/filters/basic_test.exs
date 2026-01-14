defmodule GreenFairy.Filters.BasicTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Filters.Basic

  describe "Equals" do
    test "creates equality filter" do
      filter = %Basic.Equals{value: "test"}

      assert filter.value == "test"
    end

    test "works with any value type" do
      assert %Basic.Equals{value: 42}.value == 42
      assert %Basic.Equals{value: true}.value == true
      assert %Basic.Equals{value: nil}.value == nil
    end
  end

  describe "NotEquals" do
    test "creates inequality filter" do
      filter = %Basic.NotEquals{value: "test"}

      assert filter.value == "test"
    end

    test "works with any value type" do
      assert %Basic.NotEquals{value: 42}.value == 42
    end
  end

  describe "In" do
    test "creates in-list filter" do
      filter = %Basic.In{values: [1, 2, 3]}

      assert filter.values == [1, 2, 3]
    end

    test "works with string values" do
      filter = %Basic.In{values: ["a", "b", "c"]}

      assert filter.values == ["a", "b", "c"]
    end
  end

  describe "NotIn" do
    test "creates not-in-list filter" do
      filter = %Basic.NotIn{values: [1, 2, 3]}

      assert filter.values == [1, 2, 3]
    end
  end

  describe "Range" do
    test "creates range filter with gt" do
      filter = %Basic.Range{gt: 10}

      assert filter.gt == 10
    end

    test "creates range filter with gte" do
      filter = %Basic.Range{gte: 10}

      assert filter.gte == 10
    end

    test "creates range filter with lt" do
      filter = %Basic.Range{lt: 100}

      assert filter.lt == 100
    end

    test "creates range filter with lte" do
      filter = %Basic.Range{lte: 100}

      assert filter.lte == 100
    end

    test "creates range filter with min/max aliases" do
      filter = %Basic.Range{min: 0, max: 100}

      assert filter.min == 0
      assert filter.max == 100
    end

    test "creates range filter with multiple bounds" do
      filter = %Basic.Range{gt: 0, lt: 100}

      assert filter.gt == 0
      assert filter.lt == 100
    end

    test "works with datetime values" do
      now = DateTime.utc_now()
      filter = %Basic.Range{gte: now}

      assert filter.gte == now
    end
  end

  describe "IsNil" do
    test "creates is_nil filter for true" do
      filter = %Basic.IsNil{is_nil: true}

      assert filter.is_nil == true
    end

    test "creates is_nil filter for false" do
      filter = %Basic.IsNil{is_nil: false}

      assert filter.is_nil == false
    end
  end

  describe "Contains" do
    test "creates contains filter" do
      filter = %Basic.Contains{value: "search"}

      assert filter.value == "search"
      assert filter.case_sensitive == false
    end

    test "creates case-sensitive contains filter" do
      filter = %Basic.Contains{value: "Search", case_sensitive: true}

      assert filter.value == "Search"
      assert filter.case_sensitive == true
    end
  end

  describe "StartsWith" do
    test "creates starts_with filter" do
      filter = %Basic.StartsWith{value: "prefix"}

      assert filter.value == "prefix"
      assert filter.case_sensitive == false
    end

    test "creates case-sensitive starts_with filter" do
      filter = %Basic.StartsWith{value: "Prefix", case_sensitive: true}

      assert filter.case_sensitive == true
    end
  end

  describe "EndsWith" do
    test "creates ends_with filter" do
      filter = %Basic.EndsWith{value: "suffix"}

      assert filter.value == "suffix"
      assert filter.case_sensitive == false
    end

    test "creates case-sensitive ends_with filter" do
      filter = %Basic.EndsWith{value: "Suffix", case_sensitive: true}

      assert filter.case_sensitive == true
    end
  end
end

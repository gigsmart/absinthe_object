defmodule GreenFairy.Field.LoaderTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Field.Loader

  describe "__batch_loader__/4" do
    test "calls batch function with arity 2" do
      batch_fn = fn parents, args ->
        Enum.map(parents, fn parent -> {parent, "result_#{parent.id}_#{args[:key]}"} end)
        |> Map.new()
      end

      parents = [%{id: 1}, %{id: 2}, %{id: 3}]
      args = %{key: "test"}
      context = %{}

      result = Loader.__batch_loader__(batch_fn, args, context, parents)

      assert result == %{
               %{id: 1} => "result_1_test",
               %{id: 2} => "result_2_test",
               %{id: 3} => "result_3_test"
             }
    end

    test "calls batch function with arity 3" do
      batch_fn = fn parents, args, context ->
        Enum.map(parents, fn parent ->
          {parent, "result_#{parent.id}_#{args[:key]}_#{context[:user_id]}"}
        end)
        |> Map.new()
      end

      parents = [%{id: 1}, %{id: 2}]
      args = %{key: "test"}
      context = %{user_id: 42}

      result = Loader.__batch_loader__(batch_fn, args, context, parents)

      assert result == %{
               %{id: 1} => "result_1_test_42",
               %{id: 2} => "result_2_test_42"
             }
    end

    test "converts list result to map" do
      batch_fn = fn parents, _args ->
        # Return a list instead of a map
        Enum.map(parents, fn parent -> "result_#{parent.id}" end)
      end

      parents = [%{id: 1}, %{id: 2}, %{id: 3}]
      args = %{}
      context = %{}

      result = Loader.__batch_loader__(batch_fn, args, context, parents)

      assert result == %{
               %{id: 1} => "result_1",
               %{id: 2} => "result_2",
               %{id: 3} => "result_3"
             }
    end

    test "returns map directly when batch function returns map" do
      expected = %{%{id: 1} => "a", %{id: 2} => "b"}

      batch_fn = fn _parents, _args -> expected end

      parents = [%{id: 1}, %{id: 2}]

      result = Loader.__batch_loader__(batch_fn, %{}, %{}, parents)

      assert result == expected
    end

    test "returns empty map for non-list/non-map result" do
      batch_fn = fn _parents, _args -> :unexpected end

      parents = [%{id: 1}]

      result = Loader.__batch_loader__(batch_fn, %{}, %{}, parents)

      assert result == %{}
    end

    test "raises for batch function with wrong arity" do
      batch_fn = fn -> :no_args end

      parents = [%{id: 1}]

      assert_raise ArgumentError, ~r/loader function must have arity 2 or 3/, fn ->
        Loader.__batch_loader__(batch_fn, %{}, %{}, parents)
      end
    end
  end
end

defmodule GreenFairy.MutationTest do
  use ExUnit.Case, async: true

  defmodule TestMutations do
    use GreenFairy.Mutation

    mutations do
      field :create_item, :string do
        arg :name, non_null(:string)
        resolve fn _, %{name: name}, _ -> {:ok, "Created: #{name}"} end
      end

      field :delete_item, :boolean do
        arg :id, non_null(:id)
        resolve fn _, _, _ -> {:ok, true} end
      end
    end
  end

  describe "Mutation module" do
    test "defines __green_fairy_kind__" do
      assert TestMutations.__green_fairy_kind__() == :mutations
    end

    test "defines __green_fairy_definition__" do
      definition = TestMutations.__green_fairy_definition__()

      assert definition.kind == :mutations
      assert definition.has_mutations == true
    end

    test "stores mutation fields block" do
      assert function_exported?(TestMutations, :__green_fairy_mutation_fields__, 0)
    end
  end

  describe "Mutation module without mutations block" do
    defmodule EmptyMutations do
      use GreenFairy.Mutation
    end

    test "has has_mutations as false" do
      definition = EmptyMutations.__green_fairy_definition__()
      assert definition.has_mutations == false
    end
  end

  describe "Mutation integration with schema" do
    defmodule MutationSchema do
      use Absinthe.Schema

      import_types TestMutations

      query do
        field :dummy, :string do
          resolve fn _, _, _ -> {:ok, "dummy"} end
        end
      end

      mutation do
        import_fields :green_fairy_mutations
      end
    end

    test "mutations can be executed" do
      assert {:ok, %{data: %{"createItem" => "Created: Test"}}} =
               Absinthe.run(~s|mutation { createItem(name: "Test") }|, MutationSchema)
    end

    test "mutations with boolean return work" do
      assert {:ok, %{data: %{"deleteItem" => true}}} =
               Absinthe.run(~s|mutation { deleteItem(id: "123") }|, MutationSchema)
    end
  end
end

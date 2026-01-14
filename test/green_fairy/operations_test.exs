defmodule GreenFairy.OperationsTest do
  use ExUnit.Case, async: true

  # Define modules at top level for proper compilation order
  defmodule FullOperations do
    use GreenFairy.Operations

    query_field :get_item, :string do
      arg :id, non_null(:id)
      resolve fn _, %{id: id}, _ -> {:ok, "item-#{id}"} end
    end

    query_field(:list_items, list_of(:string))

    mutation_field :create_item, :string do
      arg :name, non_null(:string)
      resolve fn _, %{name: name}, _ -> {:ok, "created-#{name}"} end
    end

    mutation_field(:delete_item, :boolean)

    subscription_field :item_changed, :string do
      config fn _, _ -> {:ok, topic: "items"} end
    end

    subscription_field(:item_deleted, :boolean)
  end

  describe "Operations module with all field types" do
    test "defines __green_fairy_kind__" do
      assert FullOperations.__green_fairy_kind__() == :operations
    end

    test "defines __green_fairy_definition__ with all flags true" do
      definition = FullOperations.__green_fairy_definition__()

      assert definition.kind == :operations
      assert definition.has_queries == true
      assert definition.has_mutations == true
      assert definition.has_subscriptions == true
    end
  end

  defmodule QueryOnlyOperations do
    use GreenFairy.Operations

    query_field :ping, :string do
      resolve fn _, _, _ -> {:ok, "pong"} end
    end
  end

  defmodule MutationOnlyOperations do
    use GreenFairy.Operations

    mutation_field :do_thing, :boolean do
      resolve fn _, _, _ -> {:ok, true} end
    end
  end

  defmodule SubscriptionOnlyOperations do
    use GreenFairy.Operations

    subscription_field :events, :string do
      config fn _, _ -> {:ok, topic: "*"} end
    end
  end

  defmodule EmptyOperations do
    use GreenFairy.Operations
  end

  defmodule OperationsSchema do
    use Absinthe.Schema

    import_types GreenFairy.OperationsTest.FullOperations

    query do
      import_fields :green_fairy_queries
    end

    mutation do
      import_fields :green_fairy_mutations
    end

    subscription do
      import_fields :green_fairy_subscriptions
    end
  end

  describe "Operations module with only queries" do
    test "has_queries is true, others false" do
      definition = QueryOnlyOperations.__green_fairy_definition__()

      assert definition.has_queries == true
      assert definition.has_mutations == false
      assert definition.has_subscriptions == false
    end
  end

  describe "Operations module with only mutations" do
    test "has_mutations is true, others false" do
      definition = MutationOnlyOperations.__green_fairy_definition__()

      assert definition.has_queries == false
      assert definition.has_mutations == true
      assert definition.has_subscriptions == false
    end
  end

  describe "Operations module with only subscriptions" do
    test "has_subscriptions is true, others false" do
      definition = SubscriptionOnlyOperations.__green_fairy_definition__()

      assert definition.has_queries == false
      assert definition.has_mutations == false
      assert definition.has_subscriptions == true
    end
  end

  describe "Empty Operations module" do
    test "all flags are false" do
      definition = EmptyOperations.__green_fairy_definition__()

      assert definition.has_queries == false
      assert definition.has_mutations == false
      assert definition.has_subscriptions == false
    end
  end

  describe "Operations integration with schema" do
    test "can execute query field with resolver" do
      assert {:ok, %{data: %{"getItem" => "item-123"}}} =
               Absinthe.run(~s|{ getItem(id: "123") }|, OperationsSchema)
    end

    test "can execute query field without resolver" do
      # Field without resolver returns nil
      assert {:ok, %{data: %{"listItems" => nil}}} =
               Absinthe.run("{ listItems }", OperationsSchema)
    end

    test "can execute mutation field with resolver" do
      assert {:ok, %{data: %{"createItem" => "created-Test"}}} =
               Absinthe.run(~s|mutation { createItem(name: "Test") }|, OperationsSchema)
    end

    test "schema has subscription fields" do
      type = Absinthe.Schema.lookup_type(OperationsSchema, :subscription)

      assert type != nil
      assert Map.has_key?(type.fields, :item_changed)
      assert Map.has_key?(type.fields, :item_deleted)
    end
  end
end

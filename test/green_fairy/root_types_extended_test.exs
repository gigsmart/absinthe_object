defmodule GreenFairy.RootTypesExtendedTest do
  use ExUnit.Case, async: true

  describe "RootQuery extended tests" do
    defmodule ExtendedRootQuery do
      use GreenFairy.RootQuery

      root_query_fields do
        field :health, :string do
          resolve fn _, _, _ -> {:ok, "healthy"} end
        end

        field :version, :string do
          resolve fn _, _, _ -> {:ok, "1.0.0"} end
        end

        field :user, :string do
          arg :id, non_null(:id)
          resolve fn _, %{id: id}, _ -> {:ok, "user-#{id}"} end
        end
      end
    end

    test "defines correct query fields identifier" do
      assert ExtendedRootQuery.__green_fairy_query_fields_identifier__() ==
               :green_fairy_root_query_fields
    end

    test "definition has correct kind" do
      assert ExtendedRootQuery.__green_fairy_definition__() == %{kind: :root_query}
    end

    test "kind function returns :root_query" do
      assert ExtendedRootQuery.__green_fairy_kind__() == :root_query
    end
  end

  describe "RootMutation extended tests" do
    defmodule ExtendedRootMutation do
      use GreenFairy.RootMutation

      root_mutation_fields do
        field :create_user, :string do
          arg :name, non_null(:string)
          resolve fn _, %{name: name}, _ -> {:ok, "created-#{name}"} end
        end

        field :delete_user, :boolean do
          arg :id, non_null(:id)
          resolve fn _, _, _ -> {:ok, true} end
        end
      end
    end

    test "defines correct mutation fields identifier" do
      assert ExtendedRootMutation.__green_fairy_mutation_fields_identifier__() ==
               :green_fairy_root_mutation_fields
    end

    test "definition has correct kind" do
      assert ExtendedRootMutation.__green_fairy_definition__() == %{kind: :root_mutation}
    end

    test "kind function returns :root_mutation" do
      assert ExtendedRootMutation.__green_fairy_kind__() == :root_mutation
    end
  end

  describe "RootSubscription extended tests" do
    defmodule ExtendedRootSubscription do
      use GreenFairy.RootSubscription

      root_subscription_fields do
        field :message_sent, :string do
          config fn _, _ -> {:ok, topic: "messages"} end
        end

        field :user_updated, :string do
          arg :user_id, :id

          config fn args, _ ->
            topic = args[:user_id] || "all_users"
            {:ok, topic: topic}
          end
        end
      end
    end

    test "defines correct subscription fields identifier" do
      assert ExtendedRootSubscription.__green_fairy_subscription_fields_identifier__() ==
               :green_fairy_root_subscription_fields
    end

    test "definition has correct kind" do
      assert ExtendedRootSubscription.__green_fairy_definition__() == %{kind: :root_subscription}
    end

    test "kind function returns :root_subscription" do
      assert ExtendedRootSubscription.__green_fairy_kind__() == :root_subscription
    end
  end

  describe "Root types schema integration" do
    defmodule RootTypesSchema do
      use Absinthe.Schema

      import_types GreenFairy.RootTypesExtendedTest.ExtendedRootQuery
      import_types GreenFairy.RootTypesExtendedTest.ExtendedRootMutation
      import_types GreenFairy.RootTypesExtendedTest.ExtendedRootSubscription

      query do
        import_fields :green_fairy_root_query_fields
      end

      mutation do
        import_fields :green_fairy_root_mutation_fields
      end

      subscription do
        import_fields :green_fairy_root_subscription_fields
      end
    end

    test "can execute query from RootQuery" do
      assert {:ok, %{data: %{"health" => "healthy"}}} =
               Absinthe.run("{ health }", RootTypesSchema)
    end

    test "can execute query with args from RootQuery" do
      assert {:ok, %{data: %{"user" => "user-123"}}} =
               Absinthe.run(~s|{ user(id: "123") }|, RootTypesSchema)
    end

    test "can execute mutation from RootMutation" do
      assert {:ok, %{data: %{"createUser" => "created-John"}}} =
               Absinthe.run(~s|mutation { createUser(name: "John") }|, RootTypesSchema)
    end

    test "schema has subscription fields from RootSubscription" do
      type = Absinthe.Schema.lookup_type(RootTypesSchema, :subscription)

      assert type != nil
      assert Map.has_key?(type.fields, :message_sent)
      assert Map.has_key?(type.fields, :user_updated)
    end
  end
end

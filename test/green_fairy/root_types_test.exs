defmodule GreenFairy.RootTypesTest do
  use ExUnit.Case, async: true

  # Define modules at top level for proper compilation order
  defmodule SimpleRootQuery do
    use GreenFairy.RootQuery

    root_query_fields do
      field :ping, :string do
        resolve fn _, _, _ -> {:ok, "pong"} end
      end
    end
  end

  defmodule SimpleRootMutation do
    use GreenFairy.RootMutation

    root_mutation_fields do
      field :do_something, :boolean do
        resolve fn _, _, _ -> {:ok, true} end
      end
    end
  end

  defmodule SimpleRootSubscription do
    use GreenFairy.RootSubscription

    root_subscription_fields do
      field :on_event, :string do
        config fn _, _ -> {:ok, topic: "*"} end
      end
    end
  end

  defmodule IntegrationSchema do
    use Absinthe.Schema

    import_types GreenFairy.RootTypesTest.SimpleRootQuery
    import_types GreenFairy.RootTypesTest.SimpleRootMutation
    import_types GreenFairy.RootTypesTest.SimpleRootSubscription

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

  describe "RootQuery" do
    test "defines __green_fairy_definition__" do
      assert SimpleRootQuery.__green_fairy_definition__() == %{kind: :root_query}
    end

    test "defines __green_fairy_kind__" do
      assert SimpleRootQuery.__green_fairy_kind__() == :root_query
    end

    test "defines __green_fairy_query_fields_identifier__" do
      assert SimpleRootQuery.__green_fairy_query_fields_identifier__() ==
               :green_fairy_root_query_fields
    end
  end

  describe "RootMutation" do
    test "defines __green_fairy_definition__" do
      assert SimpleRootMutation.__green_fairy_definition__() == %{kind: :root_mutation}
    end

    test "defines __green_fairy_kind__" do
      assert SimpleRootMutation.__green_fairy_kind__() == :root_mutation
    end

    test "defines __green_fairy_mutation_fields_identifier__" do
      assert SimpleRootMutation.__green_fairy_mutation_fields_identifier__() ==
               :green_fairy_root_mutation_fields
    end
  end

  describe "RootSubscription" do
    test "defines __green_fairy_definition__" do
      assert SimpleRootSubscription.__green_fairy_definition__() == %{kind: :root_subscription}
    end

    test "defines __green_fairy_kind__" do
      assert SimpleRootSubscription.__green_fairy_kind__() == :root_subscription
    end

    test "defines __green_fairy_subscription_fields_identifier__" do
      assert SimpleRootSubscription.__green_fairy_subscription_fields_identifier__() ==
               :green_fairy_root_subscription_fields
    end
  end

  describe "Schema integration" do
    test "query fields are available in schema" do
      type = Absinthe.Schema.lookup_type(IntegrationSchema, :query)
      assert Map.has_key?(type.fields, :ping)
    end

    test "mutation fields are available in schema" do
      type = Absinthe.Schema.lookup_type(IntegrationSchema, :mutation)
      assert Map.has_key?(type.fields, :do_something)
    end

    test "subscription fields are available in schema" do
      type = Absinthe.Schema.lookup_type(IntegrationSchema, :subscription)
      assert Map.has_key?(type.fields, :on_event)
    end

    test "can execute query" do
      assert {:ok, %{data: %{"ping" => "pong"}}} =
               Absinthe.run("{ ping }", IntegrationSchema)
    end

    test "can execute mutation" do
      assert {:ok, %{data: %{"doSomething" => true}}} =
               Absinthe.run("mutation { doSomething }", IntegrationSchema)
    end
  end

  describe "RootQuery compile error" do
    test "raises when root_query_fields not defined" do
      assert_raise CompileError, ~r/RootQuery module must define fields using root_query_fields\/1/, fn ->
        Code.compile_string("""
        defmodule InvalidRootQuery do
          use GreenFairy.RootQuery
          # Missing root_query_fields!
        end
        """)
      end
    end
  end

  describe "RootMutation compile error" do
    test "raises when root_mutation_fields not defined" do
      assert_raise CompileError, ~r/RootMutation module must define fields using root_mutation_fields\/1/, fn ->
        Code.compile_string("""
        defmodule InvalidRootMutation do
          use GreenFairy.RootMutation
          # Missing root_mutation_fields!
        end
        """)
      end
    end
  end

  describe "RootSubscription compile error" do
    test "raises when root_subscription_fields not defined" do
      assert_raise CompileError, ~r/RootSubscription module must define fields using root_subscription_fields\/1/, fn ->
        Code.compile_string("""
        defmodule InvalidRootSubscription do
          use GreenFairy.RootSubscription
          # Missing root_subscription_fields!
        end
        """)
      end
    end
  end

  # Test support module coverage
  describe "Support module functions" do
    alias GreenFairy.Test.RootMutationExample
    alias GreenFairy.Test.RootQueryExample

    test "RootQueryExample has correct definition" do
      assert RootQueryExample.__green_fairy_definition__() == %{kind: :root_query}
    end

    test "RootQueryExample has correct kind" do
      assert RootQueryExample.__green_fairy_kind__() == :root_query
    end

    test "RootQueryExample has correct identifier" do
      assert RootQueryExample.__green_fairy_query_fields_identifier__() == :green_fairy_root_query_fields
    end

    test "RootMutationExample has correct definition" do
      assert RootMutationExample.__green_fairy_definition__() == %{kind: :root_mutation}
    end

    test "RootMutationExample has correct kind" do
      assert RootMutationExample.__green_fairy_kind__() == :root_mutation
    end

    test "RootMutationExample has correct identifier" do
      assert RootMutationExample.__green_fairy_mutation_fields_identifier__() ==
               :green_fairy_root_mutation_fields
    end
  end
end

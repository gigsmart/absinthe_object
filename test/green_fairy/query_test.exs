defmodule GreenFairy.QueryTest do
  use ExUnit.Case, async: true

  defmodule TestQueries do
    use GreenFairy.Query

    queries do
      field :hello, :string do
        resolve fn _, _, _ -> {:ok, "world"} end
      end

      field :echo, :string do
        arg :message, non_null(:string)
        resolve fn _, %{message: msg}, _ -> {:ok, msg} end
      end
    end
  end

  describe "Query module" do
    test "defines __green_fairy_kind__" do
      assert TestQueries.__green_fairy_kind__() == :queries
    end

    test "defines __green_fairy_definition__" do
      definition = TestQueries.__green_fairy_definition__()

      assert definition.kind == :queries
      assert definition.has_queries == true
    end

    test "stores query fields block" do
      assert function_exported?(TestQueries, :__green_fairy_query_fields__, 0)
    end
  end

  describe "Query module without queries block" do
    defmodule EmptyQueries do
      use GreenFairy.Query
    end

    test "has has_queries as false" do
      definition = EmptyQueries.__green_fairy_definition__()
      assert definition.has_queries == false
    end
  end

  describe "Query integration with schema" do
    defmodule QuerySchema do
      use Absinthe.Schema

      import_types TestQueries

      query do
        import_fields :green_fairy_queries
      end
    end

    test "queries can be executed" do
      assert {:ok, %{data: %{"hello" => "world"}}} =
               Absinthe.run("{ hello }", QuerySchema)
    end

    test "queries with args work" do
      assert {:ok, %{data: %{"echo" => "test"}}} =
               Absinthe.run(~s|{ echo(message: "test") }|, QuerySchema)
    end
  end
end

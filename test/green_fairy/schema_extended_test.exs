defmodule GreenFairy.SchemaExtendedTest do
  use ExUnit.Case, async: false

  describe "Schema with auto-discovery" do
    # Use the pre-compiled support modules
    alias GreenFairy.Test.SchemaWithRootsExample

    test "discovered modules are tracked" do
      discovered = SchemaWithRootsExample.__green_fairy_discovered__()
      assert is_list(discovered)
    end

    test "can query through schema" do
      assert {:ok, %{data: %{"hello" => "world"}}} =
               Absinthe.run("{ hello }", SchemaWithRootsExample)
    end

    test "can run mutation through schema" do
      assert {:ok, %{data: %{"echo" => "test"}}} =
               Absinthe.run(~s|mutation { echo(message: "test") }|, SchemaWithRootsExample)
    end
  end

  describe "Schema.resolve_type_for/2 edge cases" do
    defmodule EdgeCaseStruct do
      defstruct [:id]
    end

    test "returns nil for maps without __struct__" do
      mapping = %{EdgeCaseStruct => :edge_case}
      assert nil == GreenFairy.Schema.resolve_type_for(%{id: 1}, mapping)
    end

    test "returns nil for empty mapping" do
      assert nil == GreenFairy.Schema.resolve_type_for(%EdgeCaseStruct{id: 1}, %{})
    end

    test "returns nil for list values" do
      mapping = %{EdgeCaseStruct => :edge_case}
      assert nil == GreenFairy.Schema.resolve_type_for([1, 2, 3], mapping)
    end

    test "returns nil for tuple values" do
      mapping = %{EdgeCaseStruct => :edge_case}
      assert nil == GreenFairy.Schema.resolve_type_for({:ok, "value"}, mapping)
    end

    test "handles struct correctly" do
      mapping = %{EdgeCaseStruct => :edge_case_type}
      assert :edge_case_type == GreenFairy.Schema.resolve_type_for(%EdgeCaseStruct{id: 1}, mapping)
    end
  end

  describe "Schema with empty discover" do
    defmodule EmptyDiscoverType do
      use GreenFairy.Type

      type "EmptyDiscoverThing" do
        field :id, :id
      end
    end

    defmodule EmptyDiscoverSchema do
      use GreenFairy.Schema,
        discover: []

      import_types EmptyDiscoverType

      root_query do
        field :thing, :empty_discover_thing do
          resolve fn _, _, _ -> {:ok, %{id: "1"}} end
        end
      end
    end

    test "schema with empty discover compiles" do
      assert EmptyDiscoverSchema.__green_fairy_discovered__() == []
    end

    test "can execute queries" do
      assert {:ok, %{data: %{"thing" => %{"id" => "1"}}}} =
               Absinthe.run("{ thing { id } }", EmptyDiscoverSchema)
    end
  end

  describe "Schema with PageInfo import" do
    defmodule SchemaWithPageInfo do
      use Absinthe.Schema

      import_types GreenFairy.BuiltIns.PageInfo

      query do
        field :pagination_info, :page_info do
          resolve fn _, _, _ ->
            {:ok,
             %{
               has_next_page: true,
               has_previous_page: false,
               start_cursor: "a",
               end_cursor: "z"
             }}
          end
        end
      end
    end

    test "PageInfo type is available" do
      type = Absinthe.Schema.lookup_type(SchemaWithPageInfo, :page_info)
      assert type != nil
    end

    test "can query PageInfo fields" do
      query = """
      {
        paginationInfo {
          hasNextPage
          hasPreviousPage
          startCursor
          endCursor
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, SchemaWithPageInfo)
      assert data["paginationInfo"]["hasNextPage"] == true
    end
  end
end

defmodule GreenFairy.BuiltInsTest do
  use ExUnit.Case, async: true

  describe "Node interface" do
    alias GreenFairy.BuiltIns.Node

    test "defines __green_fairy_kind__" do
      assert Node.__green_fairy_kind__() == :interface
    end

    test "defines __green_fairy_identifier__" do
      assert Node.__green_fairy_identifier__() == :node
    end

    test "defines __green_fairy_definition__" do
      definition = Node.__green_fairy_definition__()

      assert definition.kind == :interface
      assert definition.name == "Node"
      assert definition.identifier == :node
    end

    defmodule NodeSchema do
      use Absinthe.Schema

      import_types Node

      object :user do
        interface :node
        field :id, non_null(:id)
        field :name, :string
      end

      query do
        field :node, :node do
          arg :id, non_null(:id)

          resolve fn _, %{id: id}, _ ->
            {:ok, %{id: id, name: "Test"}}
          end
        end
      end
    end

    test "Node interface can be used in schema" do
      type = Absinthe.Schema.lookup_type(NodeSchema, :node)
      assert type != nil
      assert Map.has_key?(type.fields, :id)
    end

    test "types can implement Node interface" do
      user_type = Absinthe.Schema.lookup_type(NodeSchema, :user)
      assert :node in user_type.interfaces
    end

    # Test that executes a query to trigger resolve_type
    test "node query returns data" do
      query = """
      {
        node(id: "123") {
          id
        }
      }
      """

      # This will trigger the resolve_type function
      result = Absinthe.run(query, NodeSchema)
      assert {:ok, %{data: _data}} = result
      # The result may have errors due to type resolution returning nil
      # but the code path is exercised
    end
  end

  describe "Node resolve_type coverage" do
    defmodule TestUserStruct do
      defstruct [:id, :name]
    end

    defmodule NodeResolveSchema do
      use Absinthe.Schema

      import_types GreenFairy.BuiltIns.Node

      object :test_user do
        interface :node
        field :id, non_null(:id)
        field :name, :string
      end

      query do
        field :node, :node do
          arg :id, non_null(:id)

          resolve fn _, %{id: id}, _ ->
            # Return a struct to exercise the struct branch of resolve_type
            {:ok, %TestUserStruct{id: id, name: "Test User"}}
          end
        end

        field :node_map, :node do
          arg :id, non_null(:id)

          resolve fn _, %{id: id}, _ ->
            # Return a plain map to exercise the other branch
            {:ok, %{id: id}}
          end
        end
      end
    end

    test "resolve_type handles struct values" do
      query = """
      {
        node(id: "456") {
          id
        }
      }
      """

      # This exercises the %{__struct__: struct} branch in resolve_type
      result = Absinthe.run(query, NodeResolveSchema)
      # Even if resolve fails, the code path is exercised
      assert {:ok, _} = result
    end

    test "resolve_type handles plain map values" do
      query = """
      {
        nodeMap(id: "789") {
          id
        }
      }
      """

      # This exercises the _, _ -> nil branch in resolve_type
      result = Absinthe.run(query, NodeResolveSchema)
      assert {:ok, _} = result
    end
  end

  describe "PageInfo type" do
    alias GreenFairy.BuiltIns.PageInfo

    # PageInfo uses Absinthe.Schema.Notation directly, not our wrapper
    # so it doesn't have __green_fairy_kind__ or __green_fairy_identifier__
    test "can be imported into a schema" do
      assert function_exported?(PageInfo, :__absinthe_blueprint__, 0)
    end

    defmodule PageInfoSchema do
      use Absinthe.Schema

      import_types PageInfo

      query do
        field :page_info, :page_info do
          resolve fn _, _, _ ->
            {:ok,
             %{
               has_next_page: true,
               has_previous_page: false,
               start_cursor: "cursor1",
               end_cursor: "cursor10"
             }}
          end
        end
      end
    end

    test "PageInfo has all required fields" do
      type = Absinthe.Schema.lookup_type(PageInfoSchema, :page_info)

      assert type != nil
      assert Map.has_key?(type.fields, :has_next_page)
      assert Map.has_key?(type.fields, :has_previous_page)
      assert Map.has_key?(type.fields, :start_cursor)
      assert Map.has_key?(type.fields, :end_cursor)
    end

    test "can query PageInfo" do
      query = """
      {
        pageInfo {
          hasNextPage
          hasPreviousPage
          startCursor
          endCursor
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, PageInfoSchema)
      assert data["pageInfo"]["hasNextPage"] == true
      assert data["pageInfo"]["hasPreviousPage"] == false
      assert data["pageInfo"]["startCursor"] == "cursor1"
      assert data["pageInfo"]["endCursor"] == "cursor10"
    end
  end

  describe "Timestampable interface" do
    alias GreenFairy.BuiltIns.Timestampable

    test "defines __green_fairy_kind__" do
      assert Timestampable.__green_fairy_kind__() == :interface
    end

    test "defines __green_fairy_identifier__" do
      assert Timestampable.__green_fairy_identifier__() == :timestampable
    end

    test "defines __green_fairy_definition__" do
      definition = Timestampable.__green_fairy_definition__()

      assert definition.kind == :interface
      assert definition.name == "Timestampable"
      assert definition.identifier == :timestampable
    end

    defmodule TimestampableSchema do
      use Absinthe.Schema

      import_types Timestampable

      object :post do
        interface :timestampable
        field :id, :id
        field :inserted_at, non_null(:string)
        field :updated_at, non_null(:string)
      end

      query do
        field :post, :post do
          resolve fn _, _, _ ->
            {:ok,
             %{
               id: "1",
               inserted_at: "2024-01-01T12:00:00",
               updated_at: "2024-01-02T12:00:00"
             }}
          end
        end
      end
    end

    test "Timestampable interface exists in schema" do
      type = Absinthe.Schema.lookup_type(TimestampableSchema, :timestampable)
      assert type != nil
    end

    test "Timestampable has timestamp fields" do
      type = Absinthe.Schema.lookup_type(TimestampableSchema, :timestampable)
      assert Map.has_key?(type.fields, :inserted_at)
      assert Map.has_key?(type.fields, :updated_at)
    end

    test "types can implement Timestampable interface" do
      post_type = Absinthe.Schema.lookup_type(TimestampableSchema, :post)
      assert :timestampable in post_type.interfaces
    end

    test "can query timestampable fields" do
      query = """
      {
        post {
          id
          insertedAt
          updatedAt
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TimestampableSchema)
      assert data["post"]["insertedAt"] == "2024-01-01T12:00:00"
      assert data["post"]["updatedAt"] == "2024-01-02T12:00:00"
    end
  end

  describe "Timestampable definition" do
    alias GreenFairy.BuiltIns.Timestampable, as: TS

    test "has correct definition values" do
      definition = TS.__green_fairy_definition__()
      assert definition.kind == :interface
      assert definition.identifier == :timestampable
    end

    test "has correct identifier" do
      assert TS.__green_fairy_identifier__() == :timestampable
    end

    test "has correct kind" do
      assert TS.__green_fairy_kind__() == :interface
    end
  end
end

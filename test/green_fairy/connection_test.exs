defmodule GreenFairy.ConnectionTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Field.Connection

  describe "from_list/3" do
    test "creates connection from empty list" do
      assert {:ok, result} = Connection.from_list([], %{})

      assert result.edges == []
      assert result.page_info.has_next_page == false
      assert result.page_info.has_previous_page == false
      assert result.page_info.start_cursor == nil
      assert result.page_info.end_cursor == nil
    end

    test "creates connection with all items" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}]
      assert {:ok, result} = Connection.from_list(items, %{})

      assert length(result.edges) == 3
      assert Enum.map(result.edges, & &1.node) == items
    end

    test "applies first limit" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}, %{id: 5}]
      assert {:ok, result} = Connection.from_list(items, %{first: 2})

      assert length(result.edges) == 2
      assert Enum.map(result.edges, & &1.node.id) == [1, 2]
      assert result.page_info.has_next_page == true
      assert result.page_info.has_previous_page == false
    end

    test "applies last limit" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}, %{id: 5}]
      assert {:ok, result} = Connection.from_list(items, %{last: 2})

      assert length(result.edges) == 2
      assert Enum.map(result.edges, & &1.node.id) == [4, 5]
      assert result.page_info.has_next_page == false
      assert result.page_info.has_previous_page == true
    end

    test "first takes precedence over last" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}, %{id: 5}]
      assert {:ok, result} = Connection.from_list(items, %{first: 2, last: 2})

      assert length(result.edges) == 2
      assert Enum.map(result.edges, & &1.node.id) == [1, 2]
    end

    test "applies after cursor" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}]
      {:ok, %{edges: edges}} = Connection.from_list(items, %{})
      after_cursor = Enum.at(edges, 0).cursor

      assert {:ok, result} = Connection.from_list(items, %{after: after_cursor})

      assert length(result.edges) == 2
      assert Enum.map(result.edges, & &1.node.id) == [2, 3]
    end

    test "applies before cursor" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}]
      {:ok, %{edges: edges}} = Connection.from_list(items, %{})
      before_cursor = Enum.at(edges, 2).cursor

      assert {:ok, result} = Connection.from_list(items, %{before: before_cursor})

      assert length(result.edges) == 2
      assert Enum.map(result.edges, & &1.node.id) == [1, 2]
    end

    test "combines cursor and limit" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}, %{id: 5}]
      {:ok, %{edges: edges}} = Connection.from_list(items, %{})
      after_cursor = Enum.at(edges, 1).cursor

      assert {:ok, result} = Connection.from_list(items, %{after: after_cursor, first: 2})

      assert length(result.edges) == 2
      assert Enum.map(result.edges, & &1.node.id) == [3, 4]
      assert result.page_info.has_next_page == true
    end

    test "generates base64 cursors" do
      items = [%{id: 1}]
      assert {:ok, result} = Connection.from_list(items, %{})

      cursor = hd(result.edges).cursor
      assert {:ok, _} = Base.decode64(cursor)
    end

    test "supports custom cursor function" do
      items = [%{id: "a"}, %{id: "b"}, %{id: "c"}]
      cursor_fn = fn item, _idx -> "custom:#{item.id}" end

      assert {:ok, result} = Connection.from_list(items, %{}, cursor_fn: cursor_fn)

      cursors = Enum.map(result.edges, & &1.cursor)
      assert cursors == ["custom:a", "custom:b", "custom:c"]
    end

    test "sets start_cursor and end_cursor in page_info" do
      items = [%{id: 1}, %{id: 2}, %{id: 3}]
      assert {:ok, result} = Connection.from_list(items, %{})

      assert result.page_info.start_cursor == hd(result.edges).cursor
      assert result.page_info.end_cursor == List.last(result.edges).cursor
    end
  end

  describe "connection macro integration" do
    defmodule ConnectionSchema do
      use Absinthe.Schema

      import_types GreenFairy.BuiltIns.PageInfo

      object :connection_user do
        field :id, :id
        field :name, :string
      end

      # Define connection types using raw Absinthe notation for testing
      object :friends_edge do
        field :node, :connection_user
        field :cursor, non_null(:string)
        field :friendship_date, :string
      end

      object :friends_connection do
        field :edges, list_of(:friends_edge)
        field :page_info, non_null(:page_info)
        field :total_count, :integer
      end

      query do
        field :user, :connection_user do
          resolve fn _, _, _ -> {:ok, %{id: "1", name: "Test"}} end
        end

        field :friends, :friends_connection do
          arg :first, :integer
          arg :after, :string
          arg :last, :integer
          arg :before, :string

          resolve fn _, args, _ ->
            users = [
              %{id: "1", name: "Alice"},
              %{id: "2", name: "Bob"},
              %{id: "3", name: "Carol"}
            ]

            Connection.from_list(users, args)
          end
        end
      end
    end

    test "connection type exists" do
      type = Absinthe.Schema.lookup_type(ConnectionSchema, :friends_connection)
      assert type != nil
    end

    test "edge type exists" do
      type = Absinthe.Schema.lookup_type(ConnectionSchema, :friends_edge)
      assert type != nil
    end

    test "connection has edges field" do
      type = Absinthe.Schema.lookup_type(ConnectionSchema, :friends_connection)
      assert Map.has_key?(type.fields, :edges)
    end

    test "connection has page_info field" do
      type = Absinthe.Schema.lookup_type(ConnectionSchema, :friends_connection)
      assert Map.has_key?(type.fields, :page_info)
    end

    test "edge has node field" do
      type = Absinthe.Schema.lookup_type(ConnectionSchema, :friends_edge)
      assert Map.has_key?(type.fields, :node)
    end

    test "edge has cursor field" do
      type = Absinthe.Schema.lookup_type(ConnectionSchema, :friends_edge)
      assert Map.has_key?(type.fields, :cursor)
    end

    test "can query connection" do
      query = """
      {
        friends(first: 2) {
          edges {
            node {
              id
              name
            }
            cursor
          }
          pageInfo {
            hasNextPage
            hasPreviousPage
          }
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, ConnectionSchema)
      assert length(data["friends"]["edges"]) == 2
      assert data["friends"]["pageInfo"]["hasNextPage"] == true
    end
  end
end

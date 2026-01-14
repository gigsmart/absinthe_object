defmodule GreenFairy.AuthorizationInfoTest do
  use ExUnit.Case, async: true

  alias GreenFairy.AuthorizationInfo

  describe "root/1" do
    test "creates info for root query" do
      info = AuthorizationInfo.root(:users)

      assert info.path == [:users]
      assert info.field == :users
      assert info.parent == nil
      assert info.parents == []
    end

    test "creates info for root mutation" do
      info = AuthorizationInfo.root(:create_user)

      assert info.path == [:create_user]
      assert info.field == :create_user
      assert info.parent == nil
      assert info.parents == []
    end
  end

  describe "push_parent/3" do
    test "adds parent to chain" do
      info = AuthorizationInfo.root(:query)
      user = %{id: 1, name: "John"}

      result = AuthorizationInfo.push_parent(info, user, :users)

      assert result.path == [:query, :users]
      assert result.field == :users
      assert result.parent == user
      assert result.parents == [user]
    end

    test "chains multiple parents" do
      info = AuthorizationInfo.root(:query)
      user = %{id: 1, name: "John"}
      post = %{id: 10, title: "Hello"}
      comment = %{id: 100, body: "Nice post"}

      result =
        info
        |> AuthorizationInfo.push_parent(user, :user)
        |> AuthorizationInfo.push_parent(post, :posts)
        |> AuthorizationInfo.push_parent(comment, :comments)

      assert result.path == [:query, :user, :posts, :comments]
      assert result.field == :comments
      assert result.parent == comment
      assert result.parents == [user, post, comment]
    end
  end

  describe "from_resolution/1" do
    test "extracts path from resolution with name maps" do
      resolution = %Absinthe.Resolution{
        path: [%{name: "query"}, %{name: "user"}],
        source: %{id: 1},
        definition: %{schema_node: %{identifier: :name}},
        private: %{}
      }

      info = AuthorizationInfo.from_resolution(resolution)

      assert info.path == [:query, :user]
      assert info.field == :name
      assert info.parent == %{id: 1}
    end

    test "extracts path from resolution with atom names" do
      resolution = %Absinthe.Resolution{
        path: [%{name: :query}, %{name: :users}],
        source: %{id: 1},
        definition: %{schema_node: %{identifier: :email}},
        private: %{}
      }

      info = AuthorizationInfo.from_resolution(resolution)

      assert info.path == [:query, :users]
      assert info.field == :email
    end

    test "extracts path from resolution with string names" do
      resolution = %Absinthe.Resolution{
        path: ["query", "user"],
        source: %{id: 1},
        definition: %{schema_node: %{identifier: :id}},
        private: %{}
      }

      info = AuthorizationInfo.from_resolution(resolution)

      assert info.path == [:query, :user]
    end

    test "extracts path from resolution with atom entries" do
      resolution = %Absinthe.Resolution{
        path: [:query, :user],
        source: %{id: 1},
        definition: %{schema_node: %{identifier: :id}},
        private: %{}
      }

      info = AuthorizationInfo.from_resolution(resolution)

      assert info.path == [:query, :user]
    end

    test "handles nil path entries" do
      resolution = %Absinthe.Resolution{
        path: [%{name: "query"}, nil, %{name: "user"}],
        source: %{id: 1},
        definition: %{schema_node: %{identifier: :id}},
        private: %{}
      }

      info = AuthorizationInfo.from_resolution(resolution)

      assert info.path == [:query, :user]
    end

    test "extracts parents from private data" do
      user = %{id: 1, name: "John"}
      post = %{id: 10, title: "Hello"}

      resolution = %Absinthe.Resolution{
        path: [:query, :user, :posts, :comments],
        source: post,
        definition: %{schema_node: %{identifier: :comments}},
        private: %{parents: [user, post]}
      }

      info = AuthorizationInfo.from_resolution(resolution)

      assert info.parents == [user, post]
      assert info.parent == post
    end

    test "handles missing private parents" do
      resolution = %Absinthe.Resolution{
        path: [:query],
        source: nil,
        definition: %{schema_node: %{identifier: :users}},
        private: %{}
      }

      info = AuthorizationInfo.from_resolution(resolution)

      assert info.parents == []
    end

    test "handles missing path" do
      resolution = %Absinthe.Resolution{
        source: %{id: 1},
        definition: %{schema_node: %{identifier: :id}},
        private: %{}
      }

      info = AuthorizationInfo.from_resolution(resolution)

      assert info.path == []
    end
  end

  describe "struct" do
    test "has correct defaults" do
      info = %AuthorizationInfo{}

      assert info.path == []
      assert info.field == nil
      assert info.parent == nil
      assert info.parents == []
    end
  end
end

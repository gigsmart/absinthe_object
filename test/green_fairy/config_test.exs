defmodule GreenFairy.ConfigTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Config

  describe "compose_auth/2" do
    test "returns :none when first argument is :none" do
      assert :none == Config.compose_auth(:none, :all)
      assert :none == Config.compose_auth(:none, [:id, :name])
      assert :none == Config.compose_auth(:none, :none)
    end

    test "returns :none when second argument is :none" do
      assert :none == Config.compose_auth(:all, :none)
      assert :none == Config.compose_auth([:id, :name], :none)
    end

    test "returns second argument when first is :all" do
      assert :all == Config.compose_auth(:all, :all)
      assert [:id, :name] == Config.compose_auth(:all, [:id, :name])
    end

    test "returns first argument when second is :all" do
      assert [:id, :name] == Config.compose_auth([:id, :name], :all)
    end

    test "returns intersection of two field lists" do
      result = Config.compose_auth([:id, :name, :email], [:id, :name])
      assert Enum.sort(result) == [:id, :name]
    end

    test "returns empty list when no intersection" do
      result = Config.compose_auth([:email], [:name])
      assert result == []
    end

    test "handles single field lists" do
      result = Config.compose_auth([:id], [:id])
      assert result == [:id]
    end
  end

  describe "has_global_auth?/1" do
    defmodule SchemaWithAuth do
      def __global_authorize__(_object, _ctx), do: :all
    end

    defmodule SchemaWithAuthInfo do
      def __global_authorize__(_object, _ctx, _info), do: :all
    end

    defmodule SchemaWithoutAuth do
      # No __global_authorize__ function
    end

    test "returns true when schema has __global_authorize__/2" do
      assert Config.has_global_auth?(SchemaWithAuth)
    end

    test "returns true when schema has __global_authorize__/3" do
      assert Config.has_global_auth?(SchemaWithAuthInfo)
    end

    test "returns false when schema has no global auth" do
      refute Config.has_global_auth?(SchemaWithoutAuth)
    end
  end

  describe "run_global_auth/3" do
    defmodule AuthAllSchema do
      def __global_authorize__(_object, _ctx), do: :all
    end

    defmodule AuthNoneSchema do
      def __global_authorize__(_object, ctx) do
        if ctx[:current_user], do: :all, else: :none
      end
    end

    defmodule AuthFieldsSchema do
      def __global_authorize__(_object, _ctx), do: [:id, :name]
    end

    test "returns :all when no global auth configured" do
      assert :all == Config.run_global_auth(SchemaWithoutAuth, %{id: 1}, %{})
    end

    test "calls __global_authorize__/2 and returns result" do
      assert :all == Config.run_global_auth(AuthAllSchema, %{id: 1}, %{})
      assert :none == Config.run_global_auth(AuthNoneSchema, %{id: 1}, %{})
      assert :all == Config.run_global_auth(AuthNoneSchema, %{id: 1}, %{current_user: %{}})
      assert [:id, :name] == Config.run_global_auth(AuthFieldsSchema, %{id: 1}, %{})
    end
  end

  describe "run_global_auth/4 with info" do
    defmodule AuthWithInfoSchema do
      def __global_authorize__(_object, _ctx, info) do
        if info[:admin_path], do: :all, else: [:id]
      end
    end

    test "calls __global_authorize__/3 when info is provided and function exists" do
      assert :all == Config.run_global_auth(AuthWithInfoSchema, %{id: 1}, %{}, %{admin_path: true})
      assert [:id] == Config.run_global_auth(AuthWithInfoSchema, %{id: 1}, %{}, %{admin_path: false})
    end

    test "falls back to /2 when info provided but only /2 exists" do
      assert :all == Config.run_global_auth(AuthAllSchema, %{id: 1}, %{}, %{some: :info})
    end
  end
end

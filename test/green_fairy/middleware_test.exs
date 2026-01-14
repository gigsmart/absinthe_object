defmodule GreenFairy.MiddlewareTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Field.Middleware

  describe "require_capability/1" do
    test "returns middleware tuple" do
      result = Middleware.require_capability(:admin)
      assert {Middleware, {:require_capability, :admin}} = result
    end
  end

  describe "cache/1" do
    test "returns middleware tuple with default ttl" do
      result = Middleware.cache()
      assert {Middleware, {:cache, 60}} = result
    end

    test "returns middleware tuple with custom ttl" do
      result = Middleware.cache(ttl: 300)
      assert {Middleware, {:cache, 300}} = result
    end
  end

  describe "call/2 with require_capability" do
    test "allows access when user has capability" do
      resolution = %Absinthe.Resolution{
        context: %{current_user: %{capabilities: [:admin, :read]}}
      }

      result = Middleware.call(resolution, {:require_capability, :admin})

      # Resolution is returned unchanged (access allowed)
      assert result == resolution
    end

    test "denies access when user lacks capability" do
      resolution = %Absinthe.Resolution{
        context: %{current_user: %{capabilities: [:read]}},
        state: :unresolved
      }

      result = Middleware.call(resolution, {:require_capability, :admin})

      assert result.state == :resolved
      assert "Unauthorized" = result.errors |> hd()
    end

    test "denies access when no user in context" do
      resolution = %Absinthe.Resolution{
        context: %{},
        state: :unresolved
      }

      result = Middleware.call(resolution, {:require_capability, :admin})

      assert result.state == :resolved
      assert "Authentication required" = result.errors |> hd()
    end

    test "denies access when user has empty capabilities" do
      resolution = %Absinthe.Resolution{
        context: %{current_user: %{capabilities: []}},
        state: :unresolved
      }

      result = Middleware.call(resolution, {:require_capability, :admin})

      assert result.state == :resolved
      assert "Unauthorized" = result.errors |> hd()
    end

    test "denies access when user has no capabilities key" do
      resolution = %Absinthe.Resolution{
        context: %{current_user: %{}},
        state: :unresolved
      }

      result = Middleware.call(resolution, {:require_capability, :admin})

      assert result.state == :resolved
      assert "Unauthorized" = result.errors |> hd()
    end
  end

  describe "call/2 with cache" do
    test "passes through resolution for cache middleware" do
      resolution = %Absinthe.Resolution{
        context: %{},
        state: :unresolved
      }

      result = Middleware.call(resolution, {:cache, 60})

      # Cache is a placeholder, just passes through
      assert result == resolution
    end
  end

  describe "call/2 with unknown middleware" do
    test "passes through resolution for unknown middleware" do
      resolution = %Absinthe.Resolution{
        context: %{},
        state: :unresolved
      }

      result = Middleware.call(resolution, {:unknown, :stuff})

      assert result == resolution
    end
  end

  describe "middleware integration with schema" do
    defmodule MiddlewareSchema do
      use Absinthe.Schema

      query do
        field :public_data, :string do
          resolve fn _, _, _ -> {:ok, "public"} end
        end

        field :protected_data, :string do
          middleware GreenFairy.Field.Middleware, {:require_capability, :admin}
          resolve fn _, _, _ -> {:ok, "secret"} end
        end
      end
    end

    test "public field works without authentication" do
      assert {:ok, %{data: %{"publicData" => "public"}}} =
               Absinthe.run("{ publicData }", MiddlewareSchema)
    end

    test "protected field denied without user" do
      assert {:ok, %{errors: [error]}} =
               Absinthe.run("{ protectedData }", MiddlewareSchema)

      assert error.message == "Authentication required"
    end

    test "protected field denied without capability" do
      context = %{current_user: %{capabilities: [:read]}}

      assert {:ok, %{errors: [error]}} =
               Absinthe.run("{ protectedData }", MiddlewareSchema, context: context)

      assert error.message == "Unauthorized"
    end

    test "protected field allowed with capability" do
      context = %{current_user: %{capabilities: [:admin]}}

      assert {:ok, %{data: %{"protectedData" => "secret"}}} =
               Absinthe.run("{ protectedData }", MiddlewareSchema, context: context)
    end
  end
end

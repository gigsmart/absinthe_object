defmodule GreenFairy.SchemaWithRootsTest do
  use ExUnit.Case, async: false

  # Use the pre-compiled support modules
  alias GreenFairy.Test.SchemaWithRootsExample

  describe "Schema with explicit root modules" do
    test "can execute queries" do
      assert {:ok, %{data: %{"hello" => "world"}}} =
               Absinthe.run("{ hello }", SchemaWithRootsExample)
    end

    test "can execute another query field" do
      assert {:ok, %{data: %{"ping" => "pong"}}} =
               Absinthe.run("{ ping }", SchemaWithRootsExample)
    end

    test "can execute mutations" do
      assert {:ok, %{data: %{"echo" => "test message"}}} =
               Absinthe.run(~s|mutation { echo(message: "test message") }|, SchemaWithRootsExample)
    end
  end
end

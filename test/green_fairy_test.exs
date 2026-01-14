defmodule GreenFairyTest do
  use ExUnit.Case
  doctest GreenFairy

  describe "GreenFairy" do
    test "module exists" do
      assert Code.ensure_loaded?(GreenFairy)
    end
  end
end

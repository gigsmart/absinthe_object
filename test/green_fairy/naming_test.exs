defmodule GreenFairy.NamingTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Naming

  describe "to_identifier/1" do
    test "converts simple PascalCase to snake_case atom" do
      assert Naming.to_identifier("User") == :user
    end

    test "converts multi-word PascalCase to snake_case atom" do
      assert Naming.to_identifier("UserProfile") == :user_profile
    end

    test "converts longer names correctly" do
      assert Naming.to_identifier("CreateUserInput") == :create_user_input
    end

    test "handles consecutive capitals" do
      assert Naming.to_identifier("HTTPRequest") == :http_request
    end

    test "passes through atoms unchanged" do
      assert Naming.to_identifier(:already_atom) == :already_atom
    end

    test "handles single character names" do
      assert Naming.to_identifier("A") == :a
    end

    test "handles all lowercase" do
      assert Naming.to_identifier("user") == :user
    end

    test "handles names with numbers" do
      assert Naming.to_identifier("User2") == :user2
    end
  end

  describe "to_type_name/1" do
    test "converts simple atom to PascalCase string" do
      assert Naming.to_type_name(:user) == "User"
    end

    test "converts snake_case atom to PascalCase string" do
      assert Naming.to_type_name(:user_profile) == "UserProfile"
    end

    test "converts longer names correctly" do
      assert Naming.to_type_name(:create_user_input) == "CreateUserInput"
    end

    test "passes through strings unchanged" do
      assert Naming.to_type_name("AlreadyString") == "AlreadyString"
    end

    test "handles single character atoms" do
      assert Naming.to_type_name(:a) == "A"
    end
  end

  describe "round-trip conversion" do
    test "to_identifier and to_type_name are inverses for standard names" do
      original = "UserProfile"
      assert original == Naming.to_type_name(Naming.to_identifier(original))
    end

    test "atom round-trip" do
      original = :user_profile
      assert original == Naming.to_identifier(Naming.to_type_name(original))
    end
  end
end

defmodule GreenFairy.AuthorizedObjectTest do
  use ExUnit.Case, async: true

  alias GreenFairy.AuthorizedObject

  defmodule TestStruct do
    defstruct [:id, :name, :email, :ssn]
  end

  describe "new/2" do
    test "creates authorized object with :all visibility" do
      source = %TestStruct{id: 1, name: "John", email: "john@example.com", ssn: "123"}
      result = AuthorizedObject.new(source, :all)

      assert %AuthorizedObject{} = result
      assert result.source == source
      assert result.all_visible == true
      assert result.visible_fields == nil
    end

    test "returns nil for :none visibility" do
      source = %TestStruct{id: 1, name: "John"}
      result = AuthorizedObject.new(source, :none)

      assert result == nil
    end

    test "creates authorized object with specific fields" do
      source = %TestStruct{id: 1, name: "John", email: "john@example.com"}
      result = AuthorizedObject.new(source, [:id, :name])

      assert %AuthorizedObject{} = result
      assert result.source == source
      assert result.all_visible == false
      assert result.visible_fields == [:id, :name]
    end

    test "returns nil for empty field list" do
      source = %TestStruct{id: 1, name: "John"}
      result = AuthorizedObject.new(source, [])

      assert result == nil
    end
  end

  describe "field_visible?/2" do
    test "returns true for all fields when all_visible is true" do
      source = %TestStruct{id: 1, name: "John", email: "john@example.com", ssn: "123"}
      authorized = AuthorizedObject.new(source, :all)

      assert AuthorizedObject.field_visible?(authorized, :id) == true
      assert AuthorizedObject.field_visible?(authorized, :name) == true
      assert AuthorizedObject.field_visible?(authorized, :email) == true
      assert AuthorizedObject.field_visible?(authorized, :ssn) == true
      assert AuthorizedObject.field_visible?(authorized, :nonexistent) == true
    end

    test "returns true only for visible fields when restricted" do
      source = %TestStruct{id: 1, name: "John", email: "john@example.com", ssn: "123"}
      authorized = AuthorizedObject.new(source, [:id, :name])

      assert AuthorizedObject.field_visible?(authorized, :id) == true
      assert AuthorizedObject.field_visible?(authorized, :name) == true
      assert AuthorizedObject.field_visible?(authorized, :email) == false
      assert AuthorizedObject.field_visible?(authorized, :ssn) == false
    end
  end

  describe "get_field/2" do
    test "returns {:ok, value} for all visible fields when all_visible is true" do
      source = %TestStruct{id: 1, name: "John", email: "john@example.com"}
      authorized = AuthorizedObject.new(source, :all)

      assert AuthorizedObject.get_field(authorized, :id) == {:ok, 1}
      assert AuthorizedObject.get_field(authorized, :name) == {:ok, "John"}
      assert AuthorizedObject.get_field(authorized, :email) == {:ok, "john@example.com"}
    end

    test "returns {:ok, nil} for nil field values when visible" do
      source = %TestStruct{id: 1, name: nil, email: "john@example.com"}
      authorized = AuthorizedObject.new(source, :all)

      assert AuthorizedObject.get_field(authorized, :name) == {:ok, nil}
    end

    test "returns {:ok, value} for visible fields when restricted" do
      source = %TestStruct{id: 1, name: "John", email: "john@example.com", ssn: "123"}
      authorized = AuthorizedObject.new(source, [:id, :name])

      assert AuthorizedObject.get_field(authorized, :id) == {:ok, 1}
      assert AuthorizedObject.get_field(authorized, :name) == {:ok, "John"}
    end

    test "returns :hidden for hidden fields" do
      source = %TestStruct{id: 1, name: "John", email: "john@example.com", ssn: "123"}
      authorized = AuthorizedObject.new(source, [:id, :name])

      assert AuthorizedObject.get_field(authorized, :email) == :hidden
      assert AuthorizedObject.get_field(authorized, :ssn) == :hidden
    end
  end

  describe "visible_fields/1" do
    test "returns all struct keys when all_visible is true" do
      source = %TestStruct{id: 1, name: "John", email: "john@example.com", ssn: "123"}
      authorized = AuthorizedObject.new(source, :all)

      result = AuthorizedObject.visible_fields(authorized)

      assert :id in result
      assert :name in result
      assert :email in result
      assert :ssn in result
    end

    test "returns only visible fields when restricted" do
      source = %TestStruct{id: 1, name: "John", email: "john@example.com", ssn: "123"}
      authorized = AuthorizedObject.new(source, [:id, :name])

      result = AuthorizedObject.visible_fields(authorized)

      assert result == [:id, :name]
    end
  end

  describe "unwrap/1" do
    test "returns the source struct from AuthorizedObject" do
      source = %TestStruct{id: 1, name: "John", email: "john@example.com"}
      authorized = AuthorizedObject.new(source, :all)

      assert AuthorizedObject.unwrap(authorized) == source
    end

    test "returns the value unchanged if not an AuthorizedObject" do
      source = %TestStruct{id: 1, name: "John"}

      assert AuthorizedObject.unwrap(source) == source
      assert AuthorizedObject.unwrap(nil) == nil
      assert AuthorizedObject.unwrap("string") == "string"
      assert AuthorizedObject.unwrap(123) == 123
    end
  end

  describe "struct" do
    test "has correct defaults" do
      authorized = %AuthorizedObject{}

      assert authorized.source == nil
      assert authorized.visible_fields == nil
      assert authorized.all_visible == false
    end
  end
end

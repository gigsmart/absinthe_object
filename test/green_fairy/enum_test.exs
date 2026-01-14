defmodule GreenFairy.EnumTest do
  use ExUnit.Case, async: true

  defmodule UserStatus do
    use GreenFairy.Enum

    enum "UserStatus" do
      value :active
      value :inactive
      value :pending
      value :suspended, as: "SUSPENDED_BY_ADMIN"
    end
  end

  defmodule PostVisibility do
    use GreenFairy.Enum

    enum "PostVisibility", description: "Controls who can see the post" do
      @desc "Anyone can see"
      value :public

      @desc "Only friends can see"
      value :friends_only

      @desc "Only the author can see"
      value :private
    end
  end

  defmodule TestSchema do
    use Absinthe.Schema

    import_types UserStatus
    import_types PostVisibility

    query do
      field :user_status, :user_status do
        arg :status, non_null(:user_status)

        resolve fn _, %{status: status}, _ ->
          {:ok, status}
        end
      end

      field :status_name, :string do
        arg :status, non_null(:user_status)

        resolve fn _, %{status: status}, _ ->
          {:ok, Atom.to_string(status)}
        end
      end
    end
  end

  describe "enum/2 macro" do
    test "defines __green_fairy_definition__/0" do
      definition = UserStatus.__green_fairy_definition__()

      assert definition.kind == :enum
      assert definition.name == "UserStatus"
      assert definition.identifier == :user_status
    end

    test "defines __green_fairy_identifier__/0" do
      assert UserStatus.__green_fairy_identifier__() == :user_status
    end

    test "defines __green_fairy_kind__/0" do
      assert UserStatus.__green_fairy_kind__() == :enum
    end
  end

  describe "Absinthe integration" do
    test "generates valid Absinthe enum type" do
      type = Absinthe.Schema.lookup_type(TestSchema, :user_status)

      assert type != nil
      assert type.name == "UserStatus"
      assert type.identifier == :user_status
    end

    test "enum has correct values" do
      type = Absinthe.Schema.lookup_type(TestSchema, :user_status)
      value_names = Map.keys(type.values)

      assert :active in value_names
      assert :inactive in value_names
      assert :pending in value_names
      assert :suspended in value_names
    end

    test "executes query with enum argument" do
      query = """
      {
        statusName(status: ACTIVE)
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)
      assert data["statusName"] == "active"
    end

    test "returns enum value" do
      query = """
      {
        userStatus(status: PENDING)
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)
      assert data["userStatus"] == "PENDING"
    end

    test "supports custom as: value" do
      type = Absinthe.Schema.lookup_type(TestSchema, :user_status)
      suspended_value = type.values[:suspended]

      assert suspended_value.value == "SUSPENDED_BY_ADMIN"
    end
  end
end

defmodule GreenFairy.InputTest do
  use ExUnit.Case, async: true

  defmodule CreateUserInput do
    use GreenFairy.Input

    input "CreateUserInput" do
      field :email, non_null(:string)
      field :first_name, :string
      field :last_name, :string
    end
  end

  defmodule UpdateUserInput do
    use GreenFairy.Input

    input "UpdateUserInput", description: "Input for updating a user" do
      field :email, :string
      field :name, :string
    end
  end

  defmodule TestSchema do
    use Absinthe.Schema

    import_types CreateUserInput
    import_types UpdateUserInput

    query do
      field :placeholder, :string do
        resolve fn _, _, _ -> {:ok, "placeholder"} end
      end
    end

    mutation do
      field :create_user, :string do
        arg :input, non_null(:create_user_input)

        resolve fn _, %{input: input}, _ ->
          {:ok, "Created user with email: #{input.email}"}
        end
      end

      field :update_user, :string do
        arg :id, non_null(:id)
        arg :input, non_null(:update_user_input)

        resolve fn _, %{id: id, input: _input}, _ ->
          {:ok, "Updated user #{id}"}
        end
      end
    end
  end

  describe "input/2 macro" do
    test "defines __green_fairy_definition__/0" do
      definition = CreateUserInput.__green_fairy_definition__()

      assert definition.kind == :input_object
      assert definition.name == "CreateUserInput"
      assert definition.identifier == :create_user_input
    end

    test "defines __green_fairy_identifier__/0" do
      assert CreateUserInput.__green_fairy_identifier__() == :create_user_input
    end

    test "defines __green_fairy_kind__/0" do
      assert CreateUserInput.__green_fairy_kind__() == :input_object
    end
  end

  describe "Absinthe integration" do
    test "generates valid Absinthe input object type" do
      type = Absinthe.Schema.lookup_type(TestSchema, :create_user_input)

      assert type != nil
      assert type.name == "CreateUserInput"
      assert type.identifier == :create_user_input
    end

    test "input type has correct fields" do
      type = Absinthe.Schema.lookup_type(TestSchema, :create_user_input)
      field_names = Map.keys(type.fields)

      assert :email in field_names
      assert :first_name in field_names
      assert :last_name in field_names
    end

    test "executes mutation with input" do
      query = """
      mutation {
        createUser(input: {email: "test@example.com", firstName: "John"})
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TestSchema)
      assert data["createUser"] == "Created user with email: test@example.com"
    end
  end
end

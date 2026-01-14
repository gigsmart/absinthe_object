defmodule GreenFairy.RootMutationTest do
  use ExUnit.Case, async: true

  defmodule TestMutation do
    use GreenFairy.RootMutation

    root_mutation_fields do
      field :create_thing, :string do
        resolve fn _, _, _ -> {:ok, "created"} end
      end

      field :delete_thing, :boolean
    end
  end

  describe "RootMutation" do
    test "defines __green_fairy_kind__" do
      assert TestMutation.__green_fairy_kind__() == :root_mutation
    end

    test "defines __green_fairy_definition__" do
      assert TestMutation.__green_fairy_definition__() == %{kind: :root_mutation}
    end

    test "defines __green_fairy_mutation_fields_identifier__" do
      assert TestMutation.__green_fairy_mutation_fields_identifier__() == :green_fairy_root_mutation_fields
    end
  end
end

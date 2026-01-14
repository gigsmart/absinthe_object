defmodule GreenFairy.RootQueryTest do
  use ExUnit.Case, async: true

  defmodule TestQuery do
    use GreenFairy.RootQuery

    root_query_fields do
      field :health, :string do
        resolve fn _, _, _ -> {:ok, "ok"} end
      end

      field :version, :string
    end
  end

  describe "RootQuery" do
    test "defines __green_fairy_kind__" do
      assert TestQuery.__green_fairy_kind__() == :root_query
    end

    test "defines __green_fairy_definition__" do
      assert TestQuery.__green_fairy_definition__() == %{kind: :root_query}
    end

    test "defines __green_fairy_query_fields_identifier__" do
      assert TestQuery.__green_fairy_query_fields_identifier__() == :green_fairy_root_query_fields
    end
  end
end

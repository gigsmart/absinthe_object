defmodule Absinthe.Object.Extensions.CQL.SchemaTest do
  use ExUnit.Case, async: true

  alias Absinthe.Object.Extensions.CQL.Schema

  describe "cql_filter_type_for/1" do
    # Create a mock type module with CQL enabled
    defmodule MockUser do
      defstruct [:id, :name]
      def __schema__(:fields), do: [:id, :name]
      def __schema__(:type, :id), do: :id
      def __schema__(:type, :name), do: :string
      def __schema__(:type, _), do: nil
    end

    defmodule MockUserType do
      use Absinthe.Object.Type
      alias Absinthe.Object.Extensions.CQL

      type "User", struct: MockUser do
        use CQL

        field :id, non_null(:id)
        field :name, :string
      end
    end

    test "returns filter input type identifier" do
      identifier = Schema.cql_filter_type_for(MockUserType)
      assert identifier == :cql_filter_user_input
    end
  end

  describe "module macros" do
    test "cql_operator_types macro generates AST" do
      # The macro generates operator input types AST
      # We can verify it's callable without full schema compilation
      ast = Absinthe.Object.Extensions.CQL.OperatorInput.generate_all()
      assert is_list(ast)
      assert length(ast) == 10
    end
  end
end

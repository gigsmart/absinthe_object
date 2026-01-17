defmodule GreenFairy.CQL.OrderInputTest do
  use ExUnit.Case, async: true

  alias GreenFairy.CQL.Schema.OrderInput

  describe "order_type_identifier/1" do
    test "generates identifier from string type name" do
      assert OrderInput.order_type_identifier("User") == :cql_order_user_input
    end

    test "generates identifier from atom type name" do
      assert OrderInput.order_type_identifier(:User) == :cql_order_user_input
    end

    test "handles camelCase names" do
      assert OrderInput.order_type_identifier("UserProfile") == :cql_order_user_profile_input
    end

    test "handles snake_case names" do
      assert OrderInput.order_type_identifier("user_profile") == :cql_order_user_profile_input
    end
  end

  describe "type_for/1" do
    test "returns geo order for geo_point type" do
      assert OrderInput.type_for(:geo_point) == :cql_order_geo_input
    end

    test "returns geo order for location type" do
      assert OrderInput.type_for(:location) == :cql_order_geo_input
    end

    test "returns standard order for other types" do
      assert OrderInput.type_for(:string) == :cql_order_standard_input
      assert OrderInput.type_for(:integer) == :cql_order_standard_input
      assert OrderInput.type_for(:datetime) == :cql_order_standard_input
      assert OrderInput.type_for(:boolean) == :cql_order_standard_input
    end
  end

  describe "generate/2" do
    test "generates order input AST" do
      fields = [
        {:name, :string},
        {:created_at, :datetime},
        {:location, :geo_point}
      ]

      ast = OrderInput.generate("User", fields)
      ast_string = Macro.to_string(ast)

      # Should be an input_object definition with correct identifier
      assert ast_string =~ "cql_order_user_input"
      assert ast_string =~ "input_object"
    end

    test "generates fields with correct order types" do
      fields = [
        {:name, :string},
        {:location, :geo_point}
      ]

      ast = OrderInput.generate("User", fields)

      # Convert to string for easier inspection
      ast_string = Macro.to_string(ast)

      assert ast_string =~ ":name"
      assert ast_string =~ ":location"
      assert ast_string =~ "cql_order_standard_input"
      assert ast_string =~ "cql_order_geo_input"
    end
  end

  describe "generate_sort_direction_enum/0" do
    test "generates sort direction enum AST" do
      ast = OrderInput.generate_sort_direction_enum()
      ast_string = Macro.to_string(ast)

      assert ast_string =~ "cql_sort_direction"
      assert ast_string =~ "enum"
    end

    test "includes all direction values" do
      ast = OrderInput.generate_sort_direction_enum()
      ast_string = Macro.to_string(ast)

      assert ast_string =~ ":asc"
      assert ast_string =~ ":desc"
      assert ast_string =~ ":asc_nulls_first"
      assert ast_string =~ ":asc_nulls_last"
      assert ast_string =~ ":desc_nulls_first"
      assert ast_string =~ ":desc_nulls_last"
    end
  end

  describe "generate_standard_order_input/0" do
    test "generates standard order input AST" do
      ast = OrderInput.generate_standard_order_input()
      ast_string = Macro.to_string(ast)

      assert ast_string =~ "cql_order_standard_input"
      assert ast_string =~ "input_object"
    end

    test "includes direction field" do
      ast = OrderInput.generate_standard_order_input()
      ast_string = Macro.to_string(ast)

      assert ast_string =~ ":direction"
      assert ast_string =~ ":cql_sort_direction"
    end
  end

  describe "generate_geo_order_input/0" do
    test "generates geo order input AST" do
      ast = OrderInput.generate_geo_order_input()
      ast_string = Macro.to_string(ast)

      assert ast_string =~ "cql_order_geo_input"
      assert ast_string =~ "input_object"
    end

    test "includes direction and center fields" do
      ast = OrderInput.generate_geo_order_input()
      ast_string = Macro.to_string(ast)

      assert ast_string =~ ":direction"
      assert ast_string =~ ":center"
      assert ast_string =~ ":coordinates"
    end
  end

  describe "generate_base_types/0" do
    test "generates list of base type ASTs" do
      types = OrderInput.generate_base_types()

      # Returns sort direction enum + standard order input (geo excluded by default)
      assert length(types) == 2
    end
  end

  describe "generate_priority_order_input/2" do
    test "generates priority order input for enum" do
      ast = OrderInput.generate_priority_order_input(:status, [:active, :pending, :closed])
      ast_string = Macro.to_string(ast)

      assert ast_string =~ "cql_order_priority_status_input"
      assert ast_string =~ "input_object"
    end

    test "includes direction and priority fields" do
      ast = OrderInput.generate_priority_order_input(:status, [:active, :pending, :closed])
      ast_string = Macro.to_string(ast)

      assert ast_string =~ ":direction"
      assert ast_string =~ ":priority"
    end
  end
end

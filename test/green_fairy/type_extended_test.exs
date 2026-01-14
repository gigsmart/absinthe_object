defmodule GreenFairy.TypeExtendedTest do
  use ExUnit.Case, async: true

  describe "Type with various field configurations" do
    defmodule TypeTestStruct do
      defstruct [:id, :name, :email, :age]
    end

    defmodule FullFeaturedType do
      use GreenFairy.Type

      type "FullFeatured", struct: TypeTestStruct, description: "A fully featured type" do
        field :id, non_null(:id)
        field :name, :string
        field :email, non_null(:string)

        field :computed_name, :string do
          resolve fn parent, _, _ -> {:ok, "Computed: #{parent.name}"} end
        end

        field :age, :integer
      end
    end

    test "stores struct in definition" do
      definition = FullFeaturedType.__green_fairy_definition__()
      assert definition.struct == TypeTestStruct
    end

    test "stores identifier" do
      assert FullFeaturedType.__green_fairy_identifier__() == :full_featured
    end

    test "stores kind" do
      assert FullFeaturedType.__green_fairy_kind__() == :object
    end

    test "returns struct from __green_fairy_struct__" do
      assert FullFeaturedType.__green_fairy_struct__() == TypeTestStruct
    end

    test "definition includes name" do
      definition = FullFeaturedType.__green_fairy_definition__()
      assert definition.name == "FullFeatured"
    end

    test "definition includes kind" do
      definition = FullFeaturedType.__green_fairy_definition__()
      assert definition.kind == :object
    end
  end

  describe "Type without struct" do
    defmodule NoStructType do
      use GreenFairy.Type

      type "NoStruct" do
        field :id, :id
        field :data, :string
      end
    end

    test "struct is nil in definition" do
      definition = NoStructType.__green_fairy_definition__()
      assert definition.struct == nil
    end

    test "__green_fairy_struct__ returns nil" do
      assert NoStructType.__green_fairy_struct__() == nil
    end
  end

  describe "Type with interface implementation" do
    defmodule TestInterface do
      use GreenFairy.Interface

      interface "TestInterfaceForType" do
        field :id, non_null(:id)
        resolve_type fn _, _ -> nil end
      end
    end

    defmodule TestInterfaceStruct do
      defstruct [:id, :name]
    end

    defmodule TypeWithInterface do
      use GreenFairy.Type

      type "TypeWithInterface", struct: TestInterfaceStruct do
        implements(TestInterface)
        field :id, non_null(:id)
        field :name, :string
      end
    end

    test "interfaces are tracked in definition" do
      definition = TypeWithInterface.__green_fairy_definition__()
      assert TestInterface in definition.interfaces
    end
  end

  describe "Type in schema context" do
    defmodule TypeTestSchema do
      use Absinthe.Schema

      import_types GreenFairy.TypeExtendedTest.FullFeaturedType

      query do
        field :item, :full_featured do
          resolve fn _, _, _ ->
            {:ok, %{id: "1", name: "Test", email: "test@example.com", age: 25}}
          end
        end
      end
    end

    test "type is available in schema" do
      type = Absinthe.Schema.lookup_type(TypeTestSchema, :full_featured)
      assert type != nil
      assert type.name == "FullFeatured"
    end

    test "can query type fields" do
      query = """
      {
        item {
          id
          name
          email
          age
        }
      }
      """

      assert {:ok, %{data: data}} = Absinthe.run(query, TypeTestSchema)
      assert data["item"]["id"] == "1"
      assert data["item"]["name"] == "Test"
      assert data["item"]["email"] == "test@example.com"
      assert data["item"]["age"] == 25
    end

    test "computed fields work" do
      query = "{ item { computedName } }"

      assert {:ok, %{data: data}} = Absinthe.run(query, TypeTestSchema)
      assert data["item"]["computedName"] == "Computed: Test"
    end
  end

  describe "Multiple types with same interface" do
    defmodule CommonInterface do
      use GreenFairy.Interface

      interface "CommonInterface" do
        field :id, non_null(:id)
        resolve_type fn _, _ -> nil end
      end
    end

    defmodule TypeAStruct do
      defstruct [:id]
    end

    defmodule TypeBStruct do
      defstruct [:id]
    end

    defmodule TypeA do
      use GreenFairy.Type

      type "TypeAForMulti", struct: TypeAStruct do
        implements(CommonInterface)
        field :id, non_null(:id)
        field :a_field, :string
      end
    end

    defmodule TypeB do
      use GreenFairy.Type

      type "TypeBForMulti", struct: TypeBStruct do
        implements(CommonInterface)
        field :id, non_null(:id)
        field :b_field, :string
      end
    end

    test "TypeA implements CommonInterface" do
      definition = TypeA.__green_fairy_definition__()
      assert CommonInterface in definition.interfaces
    end

    test "TypeB implements CommonInterface" do
      definition = TypeB.__green_fairy_definition__()
      assert CommonInterface in definition.interfaces
    end
  end
end

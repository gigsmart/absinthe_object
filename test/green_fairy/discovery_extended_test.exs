defmodule GreenFairy.DiscoveryExtendedTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Discovery

  describe "discover/1 with multiple namespaces" do
    defmodule NamespaceA.TypeOne do
      use GreenFairy.Type

      type "DiscoveryNamespaceATypeOne" do
        field :id, :id
      end
    end

    defmodule NamespaceA.TypeTwo do
      use GreenFairy.Type

      type "DiscoveryNamespaceATypeTwo" do
        field :id, :id
      end
    end

    defmodule NamespaceB.TypeThree do
      use GreenFairy.Type

      type "DiscoveryNamespaceBTypeThree" do
        field :id, :id
      end
    end

    test "discovers from multiple namespaces" do
      modules = Discovery.discover([__MODULE__.NamespaceA, __MODULE__.NamespaceB])

      assert __MODULE__.NamespaceA.TypeOne in modules
      assert __MODULE__.NamespaceA.TypeTwo in modules
      assert __MODULE__.NamespaceB.TypeThree in modules
    end

    test "discovers from single namespace" do
      modules = Discovery.discover([__MODULE__.NamespaceA])

      assert __MODULE__.NamespaceA.TypeOne in modules
      assert __MODULE__.NamespaceA.TypeTwo in modules
      refute __MODULE__.NamespaceB.TypeThree in modules
    end
  end

  describe "group_by_kind/1 with all kinds" do
    defmodule GroupTest.ObjectType do
      use GreenFairy.Type

      type "GroupTestObject" do
        field :id, :id
      end
    end

    defmodule GroupTest.InterfaceType do
      use GreenFairy.Interface

      interface "GroupTestInterface" do
        field :id, :id
        resolve_type fn _, _ -> nil end
      end
    end

    defmodule GroupTest.InputType do
      use GreenFairy.Input

      input "GroupTestInput" do
        field :name, :string
      end
    end

    defmodule GroupTest.EnumType do
      use GreenFairy.Enum

      enum "GroupTestEnum" do
        value :one
        value :two
      end
    end

    defmodule GroupTest.UnionType do
      use GreenFairy.Union

      union "GroupTestUnion" do
        types [:group_test_object]
        resolve_type fn _, _ -> nil end
      end
    end

    defmodule GroupTest.ScalarType do
      use GreenFairy.Scalar

      scalar "GroupTestScalar" do
        parse fn _ -> {:ok, nil} end
        serialize fn val -> val end
      end
    end

    test "groups types correctly" do
      modules = Discovery.discover([__MODULE__.GroupTest])
      grouped = Discovery.group_by_kind(modules)

      assert __MODULE__.GroupTest.ObjectType in grouped[:types]
      assert __MODULE__.GroupTest.InterfaceType in grouped[:interfaces]
      assert __MODULE__.GroupTest.InputType in grouped[:inputs]
      assert __MODULE__.GroupTest.EnumType in grouped[:enums]
      assert __MODULE__.GroupTest.UnionType in grouped[:unions]
      assert __MODULE__.GroupTest.ScalarType in grouped[:scalars]
    end

    test "provides empty lists for missing kinds" do
      grouped = Discovery.group_by_kind([])

      assert grouped[:types] == []
      assert grouped[:interfaces] == []
      assert grouped[:inputs] == []
      assert grouped[:enums] == []
      assert grouped[:unions] == []
      assert grouped[:scalars] == []
      assert grouped[:queries] == []
      assert grouped[:mutations] == []
      assert grouped[:subscriptions] == []
    end
  end

  describe "build_struct_mapping/1" do
    defmodule StructMapTest.Struct1 do
      defstruct [:id]
    end

    defmodule StructMapTest.Struct2 do
      defstruct [:id]
    end

    defmodule StructMapTest.TypeWithStruct1 do
      use GreenFairy.Type

      type "StructMapType1", struct: StructMapTest.Struct1 do
        field :id, :id
      end
    end

    defmodule StructMapTest.TypeWithStruct2 do
      use GreenFairy.Type

      type "StructMapType2", struct: StructMapTest.Struct2 do
        field :id, :id
      end
    end

    defmodule StructMapTest.TypeWithoutStruct do
      use GreenFairy.Type

      type "StructMapTypeNoStruct" do
        field :id, :id
      end
    end

    test "builds mapping for multiple types with structs" do
      modules = [
        __MODULE__.StructMapTest.TypeWithStruct1,
        __MODULE__.StructMapTest.TypeWithStruct2,
        __MODULE__.StructMapTest.TypeWithoutStruct
      ]

      mapping = Discovery.build_struct_mapping(modules)

      assert mapping[__MODULE__.StructMapTest.Struct1] == :struct_map_type1
      assert mapping[__MODULE__.StructMapTest.Struct2] == :struct_map_type2
      assert map_size(mapping) == 2
    end
  end

  describe "build_interface_mapping/1" do
    defmodule InterfaceMapTest.Interface1 do
      use GreenFairy.Interface

      interface "InterfaceMapInterface1" do
        field :id, :id
        resolve_type fn _, _ -> nil end
      end
    end

    defmodule InterfaceMapTest.Interface2 do
      use GreenFairy.Interface

      interface "InterfaceMapInterface2" do
        field :name, :string
        resolve_type fn _, _ -> nil end
      end
    end

    defmodule InterfaceMapTest.Struct1 do
      defstruct [:id]
    end

    defmodule InterfaceMapTest.Implementor1 do
      use GreenFairy.Type

      type "InterfaceMapImpl1", struct: InterfaceMapTest.Struct1 do
        implements(InterfaceMapTest.Interface1)
        field :id, :id
      end
    end

    defmodule InterfaceMapTest.Struct2 do
      defstruct [:id, :name]
    end

    defmodule InterfaceMapTest.Implementor2 do
      use GreenFairy.Type

      type "InterfaceMapImpl2", struct: InterfaceMapTest.Struct2 do
        implements(InterfaceMapTest.Interface1)
        implements(InterfaceMapTest.Interface2)
        field :id, :id
        field :name, :string
      end
    end

    test "builds mapping of interfaces to implementors" do
      modules = [
        __MODULE__.InterfaceMapTest.Implementor1,
        __MODULE__.InterfaceMapTest.Implementor2
      ]

      mapping = Discovery.build_interface_mapping(modules)

      # Interface1 should have both implementors
      assert __MODULE__.InterfaceMapTest.Implementor1 in mapping[__MODULE__.InterfaceMapTest.Interface1]
      assert __MODULE__.InterfaceMapTest.Implementor2 in mapping[__MODULE__.InterfaceMapTest.Interface1]

      # Interface2 should only have Implementor2
      assert __MODULE__.InterfaceMapTest.Implementor2 in mapping[__MODULE__.InterfaceMapTest.Interface2]
      refute __MODULE__.InterfaceMapTest.Implementor1 in (mapping[__MODULE__.InterfaceMapTest.Interface2] || [])
    end
  end
end

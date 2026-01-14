defmodule GreenFairy.Deferred.RegistryTest do
  use ExUnit.Case

  alias GreenFairy.Deferred.Registry

  # Test module that simulates a type definition
  defmodule TestType do
    def __green_fairy_definition__ do
      %{name: :test_type, kind: :object}
    end
  end

  defmodule TestInterface do
    def __green_fairy_definition__ do
      %{name: :test_interface, kind: :interface}
    end
  end

  setup do
    # Clear registry before each test
    Registry.clear()
    :ok
  end

  describe "register/2" do
    test "registers a module with a kind" do
      assert :ok = Registry.register(TestType, :object)
    end

    test "can register multiple modules" do
      assert :ok = Registry.register(TestType, :object)
      assert :ok = Registry.register(TestInterface, :interface)
    end
  end

  describe "all_modules/0" do
    test "returns empty list when no modules registered" do
      assert Registry.all_modules() == []
    end

    test "returns registered modules" do
      Registry.register(TestType, :object)
      Registry.register(TestInterface, :interface)

      modules = Registry.all_modules()
      assert TestType in modules
      assert TestInterface in modules
    end
  end

  describe "modules_of_kind/1" do
    test "returns empty list when no modules of kind registered" do
      assert Registry.modules_of_kind(:object) == []
    end

    test "returns only modules of the specified kind" do
      Registry.register(TestType, :object)
      Registry.register(TestInterface, :interface)

      assert Registry.modules_of_kind(:object) == [TestType]
      assert Registry.modules_of_kind(:interface) == [TestInterface]
    end
  end

  describe "all_definitions/0" do
    test "returns empty list when no modules registered" do
      assert Registry.all_definitions() == []
    end

    test "returns definitions from all registered modules" do
      Registry.register(TestType, :object)
      Registry.register(TestInterface, :interface)

      definitions = Registry.all_definitions()
      assert length(definitions) == 2
      assert Enum.any?(definitions, &(&1.name == :test_type))
      assert Enum.any?(definitions, &(&1.name == :test_interface))
    end
  end

  describe "definitions_of_kind/1" do
    test "returns definitions only for the specified kind" do
      Registry.register(TestType, :object)
      Registry.register(TestInterface, :interface)

      object_defs = Registry.definitions_of_kind(:object)
      assert length(object_defs) == 1
      assert hd(object_defs).name == :test_type
    end
  end

  describe "clear/0" do
    test "clears all registrations" do
      Registry.register(TestType, :object)
      assert length(Registry.all_modules()) > 0

      Registry.clear()
      assert Registry.all_modules() == []
    end
  end

  describe "registered?/1" do
    test "returns false for unregistered module" do
      refute Registry.registered?(TestType)
    end
  end
end

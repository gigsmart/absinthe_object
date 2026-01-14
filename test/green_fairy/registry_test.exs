defmodule GreenFairy.RegistryTest do
  use ExUnit.Case, async: false

  alias GreenFairy.Registry

  setup do
    Registry.clear()
    :ok
  end

  defmodule TestStruct do
    defstruct [:id]
  end

  defmodule AnotherStruct do
    defstruct [:id]
  end

  defmodule TestInterface do
  end

  defmodule AnotherInterface do
  end

  describe "register/3" do
    test "registers a struct with an interface" do
      assert :ok = Registry.register(TestStruct, :test_type, TestInterface)
    end

    test "can register same struct with different interfaces" do
      :ok = Registry.register(TestStruct, :test_type, TestInterface)
      :ok = Registry.register(TestStruct, :test_type, AnotherInterface)

      assert Registry.resolve_type(%TestStruct{}, TestInterface) == :test_type
      assert Registry.resolve_type(%TestStruct{}, AnotherInterface) == :test_type
    end

    test "can register different structs with same interface" do
      :ok = Registry.register(TestStruct, :test_type, TestInterface)
      :ok = Registry.register(AnotherStruct, :another_type, TestInterface)

      assert Registry.resolve_type(%TestStruct{}, TestInterface) == :test_type
      assert Registry.resolve_type(%AnotherStruct{}, TestInterface) == :another_type
    end
  end

  describe "resolve_type/2" do
    test "returns type for registered struct" do
      Registry.register(TestStruct, :test_type, TestInterface)

      assert Registry.resolve_type(%TestStruct{id: 1}, TestInterface) == :test_type
    end

    test "returns nil for unregistered struct" do
      assert Registry.resolve_type(%TestStruct{id: 1}, TestInterface) == nil
    end

    test "returns nil for non-struct value" do
      assert Registry.resolve_type("string", TestInterface) == nil
      assert Registry.resolve_type(123, TestInterface) == nil
      assert Registry.resolve_type(nil, TestInterface) == nil
      assert Registry.resolve_type(%{}, TestInterface) == nil
    end

    test "returns nil for wrong interface" do
      Registry.register(TestStruct, :test_type, TestInterface)

      assert Registry.resolve_type(%TestStruct{id: 1}, AnotherInterface) == nil
    end
  end

  describe "implementations/1" do
    test "returns all implementations for an interface" do
      Registry.register(TestStruct, :test_type, TestInterface)
      Registry.register(AnotherStruct, :another_type, TestInterface)

      implementations = Registry.implementations(TestInterface)

      assert length(implementations) == 2
      assert {TestStruct, :test_type} in implementations
      assert {AnotherStruct, :another_type} in implementations
    end

    test "returns empty list for interface with no implementations" do
      assert Registry.implementations(TestInterface) == []
    end

    test "only returns implementations for specified interface" do
      Registry.register(TestStruct, :test_type, TestInterface)
      Registry.register(AnotherStruct, :another_type, AnotherInterface)

      implementations = Registry.implementations(TestInterface)

      assert length(implementations) == 1
      assert {TestStruct, :test_type} in implementations
      refute {AnotherStruct, :another_type} in implementations
    end
  end

  describe "all/0" do
    test "returns all registrations" do
      Registry.register(TestStruct, :test_type, TestInterface)
      Registry.register(AnotherStruct, :another_type, AnotherInterface)

      all = Registry.all()

      assert map_size(all) == 2
      assert all[{TestStruct, TestInterface}] == :test_type
      assert all[{AnotherStruct, AnotherInterface}] == :another_type
    end

    test "returns empty map when nothing registered" do
      assert Registry.all() == %{}
    end
  end

  describe "clear/0" do
    test "removes all registrations" do
      Registry.register(TestStruct, :test_type, TestInterface)
      assert Registry.all() != %{}

      Registry.clear()

      assert Registry.all() == %{}
    end
  end

  describe "concurrent registration" do
    test "handles concurrent registrations safely" do
      # Ensure lock table exists in test process before spawning tasks
      # (This prevents race conditions where the table-owning process dies)
      Registry.register(TestStruct, :warmup_type, TestInterface)

      # Register many items concurrently
      tasks =
        for i <- 1..100 do
          Task.async(fn ->
            # Create unique module names for this test
            struct_module = String.to_atom("ConcurrentStruct#{i}")
            Registry.register(struct_module, String.to_atom("type_#{i}"), TestInterface)
          end)
        end

      # Wait for all tasks
      Enum.each(tasks, &Task.await/1)

      # Verify all registrations exist (including warmup)
      implementations = Registry.implementations(TestInterface)
      assert length(implementations) == 101
    end
  end

  describe "edge cases" do
    test "register overwrites existing entry" do
      :ok = Registry.register(TestStruct, :old_type, TestInterface)
      assert Registry.resolve_type(%TestStruct{}, TestInterface) == :old_type

      :ok = Registry.register(TestStruct, :new_type, TestInterface)
      assert Registry.resolve_type(%TestStruct{}, TestInterface) == :new_type
    end

    test "implementations returns list with struct and identifier" do
      Registry.register(TestStruct, :test_type, TestInterface)

      implementations = Registry.implementations(TestInterface)
      assert is_list(implementations)

      {struct, identifier} = hd(implementations)
      assert struct == TestStruct
      assert identifier == :test_type
    end
  end
end

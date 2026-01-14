defmodule Absinthe.Object.Discovery do
  @moduledoc """
  Auto-discovery of type modules.

  This module provides compile-time discovery of modules that define
  GraphQL types using the Absinthe.Object DSL.

  ## Usage

      # Discover all types under a namespace
      types = Absinthe.Object.Discovery.discover([MyApp.GraphQL])

  """

  @doc """
  Discovers all modules under the given namespaces that define
  `__absinthe_object_definition__/0`.

  Returns a list of module atoms.
  """
  def discover(namespaces) when is_list(namespaces) do
    Enum.flat_map(namespaces, &discover_namespace/1)
  end

  @doc """
  Discovers all modules under a single namespace.
  """
  def discover_namespace(namespace) when is_atom(namespace) do
    # Get all modules loaded in the application
    :code.all_loaded()
    |> Enum.map(fn {module, _} -> module end)
    |> Enum.filter(&module_in_namespace?(&1, namespace))
    |> Enum.filter(&defines_absinthe_object?/1)
  end

  @doc """
  Groups discovered modules by their kind.

  Returns a map with keys:
  - `:types` - Object types
  - `:interfaces` - Interface types
  - `:inputs` - Input object types
  - `:enums` - Enum types
  - `:unions` - Union types
  - `:scalars` - Scalar types
  - `:queries` - Query field modules
  - `:mutations` - Mutation field modules
  - `:subscriptions` - Subscription field modules
  """
  def group_by_kind(modules) do
    modules
    |> Enum.group_by(&get_kind/1)
    |> Map.put_new(:types, [])
    |> Map.put_new(:interfaces, [])
    |> Map.put_new(:inputs, [])
    |> Map.put_new(:enums, [])
    |> Map.put_new(:unions, [])
    |> Map.put_new(:scalars, [])
    |> Map.put_new(:queries, [])
    |> Map.put_new(:mutations, [])
    |> Map.put_new(:subscriptions, [])
  end

  # Check if module is under the given namespace
  defp module_in_namespace?(module, namespace) do
    module_string = Atom.to_string(module)
    namespace_string = Atom.to_string(namespace)

    String.starts_with?(module_string, namespace_string)
  end

  # Check if module defines __absinthe_object_definition__/0
  defp defines_absinthe_object?(module) do
    function_exported?(module, :__absinthe_object_definition__, 0)
  end

  # Get the kind of a discovered module
  defp get_kind(module) do
    case module.__absinthe_object_definition__()[:kind] do
      :object -> :types
      :interface -> :interfaces
      :input_object -> :inputs
      :enum -> :enums
      :union -> :unions
      :scalar -> :scalars
      :queries -> :queries
      :mutations -> :mutations
      :subscriptions -> :subscriptions
      _ -> :unknown
    end
  end

  @doc """
  Builds a struct-to-type mapping for auto-resolve_type generation.

  Returns a map of `%{StructModule => :type_identifier}`.
  """
  def build_struct_mapping(modules) do
    modules
    |> Enum.filter(&defines_struct?/1)
    |> Enum.map(fn module ->
      definition = module.__absinthe_object_definition__()
      {definition[:struct], definition[:identifier]}
    end)
    |> Enum.reject(fn {struct, _} -> is_nil(struct) end)
    |> Map.new()
  end

  # Check if module has a struct defined
  defp defines_struct?(module) do
    function_exported?(module, :__absinthe_object_struct__, 0) and
      not is_nil(module.__absinthe_object_struct__())
  end

  @doc """
  Builds interface implementors mapping.

  Returns a map of `%{InterfaceModule => [TypeModule1, TypeModule2, ...]}`.
  """
  def build_interface_mapping(modules) do
    modules
    |> Enum.filter(&implements_interfaces?/1)
    |> Enum.flat_map(fn module ->
      definition = module.__absinthe_object_definition__()
      interfaces = definition[:interfaces] || []

      Enum.map(interfaces, fn interface ->
        {interface, module}
      end)
    end)
    |> Enum.group_by(fn {interface, _} -> interface end, fn {_, module} -> module end)
  end

  # Check if module implements interfaces
  defp implements_interfaces?(module) do
    function_exported?(module, :__absinthe_object_definition__, 0) and
      (module.__absinthe_object_definition__()[:interfaces] || []) != []
  end
end

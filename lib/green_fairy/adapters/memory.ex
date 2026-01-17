defmodule GreenFairy.Adapters.Memory do
  @moduledoc """
  Memory adapter for plain structs without database backing.

  This adapter is the fallback when no other adapter (Ecto, Elasticsearch, etc.)
  matches the struct backing a type. It provides basic field introspection
  for structs and delegates CQL operations to `GreenFairy.CQL.Adapters.Memory`.

  ## Usage

  This adapter is automatically selected for types that use plain structs:

      defstruct [:id, :name, :email]

      # Or
      defmodule MyApp.User do
        defstruct [:id, :name, :email, :created_at]
      end

  The adapter will detect struct fields via `Map.keys/1` on a struct instance.

  ## Limitations

  - Field types cannot be inferred (all fields treated as generic)
  - No database-backed operations (filtering/sorting done in memory)
  - No associations or preloading support

  """

  use GreenFairy.Adapter

  defstruct [:struct_module, :opts]

  @doc """
  Creates a new Memory adapter for the given struct module.
  """
  def new(struct_module, opts \\ []) do
    %__MODULE__{
      struct_module: struct_module,
      opts: opts
    }
  end

  @impl true
  def handles?(module) do
    # Memory adapter handles any module that defines a struct
    Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0)
  end

  @impl true
  def capabilities do
    [:cql]
  end

  @impl true
  def queryable_fields(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0) do
      module.__struct__()
      |> Map.keys()
      |> Enum.reject(&(&1 == :__struct__))
    else
      []
    end
  end

  @impl true
  def field_type(_module, _field) do
    # Memory adapter cannot infer types from plain structs
    # All fields treated as :any
    :any
  end

  @impl true
  def operators_for_type(_type) do
    # Basic operators for in-memory filtering
    [:eq, :neq, :gt, :gte, :lt, :lte, :in, :is_nil]
  end

  @impl true
  def dataloader_source(_module), do: :memory

  @impl true
  def dataloader_batch_key(_module, field, args) do
    {field, args}
  end

  @impl true
  def dataloader_default_args(_module, _field), do: %{}
end

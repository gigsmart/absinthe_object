defmodule Absinthe.Object.Extensions.CQL.OperatorInput do
  @moduledoc """
  Generates CQL operator input types for different field types.

  These are the `CqlOp{Type}Input` types that define available operators
  for each scalar type in CQL filters.

  ## Generated Types

  - `CqlOpIdInput` - Operators for ID fields
  - `CqlOpStringInput` - Operators for string fields
  - `CqlOpIntegerInput` - Operators for integer fields
  - `CqlOpFloatInput` - Operators for float fields
  - `CqlOpBooleanInput` - Operators for boolean fields
  - `CqlOpDatetimeInput` - Operators for datetime fields
  - `CqlOpDateInput` - Operators for date fields
  - `CqlOpEnumInput` - Operators for enum fields

  ## Example

  The `CqlOpStringInput` type generates:

      input CqlOpStringInput {
        eq: String
        neq: String
        contains: String
        starts_with: String
        ends_with: String
        in: [String]
        is_nil: Boolean
      }
  """

  @doc """
  Returns the operator input type identifier for a given Ecto/adapter type.
  """
  def type_for(:id), do: :cql_op_id_input
  def type_for(:binary_id), do: :cql_op_id_input
  def type_for(:string), do: :cql_op_string_input
  def type_for(:integer), do: :cql_op_integer_input
  def type_for(:float), do: :cql_op_float_input
  def type_for(:decimal), do: :cql_op_float_input
  def type_for(:boolean), do: :cql_op_boolean_input
  def type_for(:naive_datetime), do: :cql_op_datetime_input
  def type_for(:utc_datetime), do: :cql_op_datetime_input
  def type_for(:naive_datetime_usec), do: :cql_op_datetime_input
  def type_for(:utc_datetime_usec), do: :cql_op_datetime_input
  def type_for(:date), do: :cql_op_date_input
  def type_for(:time), do: :cql_op_time_input
  def type_for(:time_usec), do: :cql_op_time_input
  def type_for(:map), do: nil
  def type_for(:array), do: nil
  def type_for({:array, _}), do: nil
  def type_for({:map, _}), do: nil
  def type_for({:parameterized, Ecto.Enum, _}), do: :cql_op_enum_input
  def type_for({:parameterized, Ecto.Embedded, _}), do: nil
  def type_for(_), do: :cql_op_generic_input

  @doc """
  Returns the GraphQL scalar type for a given Ecto/adapter type.
  """
  def scalar_for(:id), do: :id
  def scalar_for(:binary_id), do: :id
  def scalar_for(:string), do: :string
  def scalar_for(:integer), do: :integer
  def scalar_for(:float), do: :float
  def scalar_for(:decimal), do: :float
  def scalar_for(:boolean), do: :boolean
  def scalar_for(:naive_datetime), do: :datetime
  def scalar_for(:utc_datetime), do: :datetime
  def scalar_for(:naive_datetime_usec), do: :datetime
  def scalar_for(:utc_datetime_usec), do: :datetime
  def scalar_for(:date), do: :date
  def scalar_for(:time), do: :time
  def scalar_for(:time_usec), do: :time
  def scalar_for({:parameterized, Ecto.Enum, _}), do: :string
  def scalar_for(_), do: :string

  @doc """
  Returns a map of operator type -> {operators, scalar_type}.

  Used to generate the operator input types.
  """
  def operator_types do
    %{
      cql_op_id_input: {
        [:eq, :neq, :in, :is_nil],
        :id,
        "Operators for ID fields"
      },
      cql_op_string_input: {
        [:eq, :neq, :contains, :starts_with, :ends_with, :in, :is_nil],
        :string,
        "Operators for string fields"
      },
      cql_op_integer_input: {
        [:eq, :neq, :gt, :gte, :lt, :lte, :in, :is_nil],
        :integer,
        "Operators for integer fields"
      },
      cql_op_float_input: {
        [:eq, :neq, :gt, :gte, :lt, :lte, :in, :is_nil],
        :float,
        "Operators for float fields"
      },
      cql_op_boolean_input: {
        [:eq, :is_nil],
        :boolean,
        "Operators for boolean fields"
      },
      cql_op_datetime_input: {
        [:eq, :neq, :gt, :gte, :lt, :lte, :is_nil],
        :datetime,
        "Operators for datetime fields"
      },
      cql_op_date_input: {
        [:eq, :neq, :gt, :gte, :lt, :lte, :is_nil],
        :date,
        "Operators for date fields"
      },
      cql_op_time_input: {
        [:eq, :neq, :gt, :gte, :lt, :lte, :is_nil],
        :time,
        "Operators for time fields"
      },
      cql_op_enum_input: {
        [:eq, :neq, :in, :is_nil],
        :string,
        "Operators for enum fields"
      },
      cql_op_generic_input: {
        [:eq, :in],
        :string,
        "Generic operators for unknown field types"
      }
    }
  end

  @doc """
  Generates AST for all operator input types.

  This should be called once in the schema to define all CQL operator types.
  """
  def generate_all do
    for {identifier, {operators, scalar, description}} <- operator_types() do
      generate_input(identifier, operators, scalar, description)
    end
  end

  @doc """
  Generates AST for a single operator input type.
  """
  def generate_input(identifier, operators, scalar_type, description) do
    fields = Enum.map(operators, &operator_field(&1, scalar_type))

    quote do
      @desc unquote(description)
      input_object unquote(identifier) do
        (unquote_splicing(fields))
      end
    end
  end

  defp operator_field(:eq, scalar), do: quote(do: field(:eq, unquote(scalar)))
  defp operator_field(:neq, scalar), do: quote(do: field(:neq, unquote(scalar)))
  defp operator_field(:gt, scalar), do: quote(do: field(:gt, unquote(scalar)))
  defp operator_field(:gte, scalar), do: quote(do: field(:gte, unquote(scalar)))
  defp operator_field(:lt, scalar), do: quote(do: field(:lt, unquote(scalar)))
  defp operator_field(:lte, scalar), do: quote(do: field(:lte, unquote(scalar)))
  defp operator_field(:in, scalar), do: quote(do: field(:in, list_of(unquote(scalar))))
  defp operator_field(:is_nil, _scalar), do: quote(do: field(:is_nil, :boolean))
  defp operator_field(:contains, _scalar), do: quote(do: field(:contains, :string))
  defp operator_field(:starts_with, _scalar), do: quote(do: field(:starts_with, :string))
  defp operator_field(:ends_with, _scalar), do: quote(do: field(:ends_with, :string))
end

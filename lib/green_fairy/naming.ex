defmodule GreenFairy.Naming do
  @moduledoc """
  Naming utilities for converting between GraphQL names and Elixir identifiers.
  """

  @doc """
  Converts a GraphQL type name to an Elixir atom identifier.

  ## Examples

      iex> GreenFairy.Naming.to_identifier("User")
      :user

      iex> GreenFairy.Naming.to_identifier("UserProfile")
      :user_profile

      iex> GreenFairy.Naming.to_identifier("CreateUserInput")
      :create_user_input

  """
  @spec to_identifier(String.t() | atom()) :: atom()
  def to_identifier(name) when is_atom(name), do: name

  def to_identifier(name) when is_binary(name) do
    name
    |> Macro.underscore()
    |> String.to_atom()
  end

  @doc """
  Converts an Elixir identifier to a GraphQL type name.

  ## Examples

      iex> GreenFairy.Naming.to_type_name(:user)
      "User"

      iex> GreenFairy.Naming.to_type_name(:user_profile)
      "UserProfile"

  """
  @spec to_type_name(atom() | String.t()) :: String.t()
  def to_type_name(identifier) when is_binary(identifier), do: identifier

  def to_type_name(identifier) when is_atom(identifier) do
    identifier
    |> Atom.to_string()
    |> Macro.camelize()
  end
end

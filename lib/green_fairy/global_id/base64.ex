defmodule GreenFairy.GlobalId.Base64 do
  @moduledoc """
  Default Base64 implementation of the GlobalId behaviour.

  This follows the Relay Object Identification specification where
  global IDs are Base64-encoded strings in the format `TypeName:localId`.

  ## Examples

      # Encoding
      Base64.encode("User", 123)
      #=> "VXNlcjoxMjM="

      Base64.encode(:user_profile, 42)
      #=> "VXNlclByb2ZpbGU6NDI="

      # Decoding
      Base64.decode("VXNlcjoxMjM=")
      #=> {:ok, {"User", "123"}}

  """

  @behaviour GreenFairy.GlobalId

  @impl true
  @doc """
  Encodes a type name and local ID into a Base64 global ID.

  The type name can be an atom or string. Atoms are converted to
  PascalCase (e.g., `:user_profile` becomes `"UserProfile"`).
  """
  @spec encode(atom() | String.t(), term()) :: String.t()
  def encode(type_name, local_id) when is_atom(type_name) do
    encode(atom_to_type_name(type_name), local_id)
  end

  def encode(type_name, local_id) when is_binary(type_name) do
    "#{type_name}:#{local_id}"
    |> Base.encode64()
  end

  @impl true
  @doc """
  Decodes a Base64 global ID into its type name and local ID.

  Returns `{:ok, {type_name, local_id}}` on success, or `{:error, reason}` on failure.
  """
  @spec decode(String.t()) :: {:ok, {String.t(), String.t()}} | {:error, atom()}
  def decode(global_id) when is_binary(global_id) do
    with {:ok, decoded} <- Base.decode64(global_id),
         [type_name, local_id] <- String.split(decoded, ":", parts: 2) do
      {:ok, {type_name, local_id}}
    else
      :error -> {:error, :invalid_global_id}
      _ -> {:error, :invalid_global_id}
    end
  end

  def decode(_), do: {:error, :invalid_global_id}

  # Converts an atom like :user_profile to "UserProfile"
  defp atom_to_type_name(atom) do
    atom
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(&String.capitalize/1)
  end
end

defmodule GreenFairy.GlobalId do
  @moduledoc """
  Behaviour for custom global ID encoding and decoding.

  GreenFairy uses global IDs to uniquely identify objects across the schema.
  By default, IDs are encoded as Base64 strings in the format `TypeName:localId`.

  ## Customizing Global IDs

  You can implement your own encoding/decoding by implementing this behaviour:

      defmodule MyApp.CustomGlobalId do
        @behaviour GreenFairy.GlobalId

        @impl true
        def encode(type_name, id) do
          # Your custom encoding
          MyApp.Hashids.encode(type_name, id)
        end

        @impl true
        def decode(global_id) do
          # Your custom decoding
          case MyApp.Hashids.decode(global_id) do
            {:ok, type_name, id} -> {:ok, {type_name, id}}
            :error -> {:error, :invalid_global_id}
          end
        end
      end

  Then configure it in your schema:

      use GreenFairy.Schema,
        global_id: MyApp.CustomGlobalId

  ## Default Implementation

  The default implementation (`GreenFairy.GlobalId.Base64`) follows the Relay
  specification with Base64 encoding:

      # Encode
      GlobalId.Base64.encode("User", 123)
      #=> "VXNlcjoxMjM="

      # Decode
      GlobalId.Base64.decode("VXNlcjoxMjM=")
      #=> {:ok, {"User", "123"}}

  """

  @doc """
  Encodes a type name and local ID into a global ID string.

  The type name can be an atom or string. If an atom is provided,
  it should be converted to a string (typically PascalCase).

  ## Parameters

  - `type_name` - The GraphQL type name (atom or string)
  - `id` - The local ID (any term, typically integer or string)

  ## Returns

  A global ID string.

  ## Examples

      encode(:user, 123)
      #=> "some_encoded_string"

      encode("User", "abc-def")
      #=> "some_other_encoded_string"

  """
  @callback encode(type_name :: atom() | String.t(), id :: any()) :: String.t()

  @doc """
  Decodes a global ID string into its type name and local ID.

  ## Parameters

  - `global_id` - The encoded global ID string

  ## Returns

  - `{:ok, {type_name, local_id}}` on success
  - `{:error, reason}` on failure

  ## Examples

      decode("VXNlcjoxMjM=")
      #=> {:ok, {"User", "123"}}

      decode("invalid")
      #=> {:error, :invalid_global_id}

  """
  @callback decode(global_id :: String.t()) :: {:ok, {String.t(), any()}} | {:error, term()}

  @doc """
  Returns the default global ID implementation.

  Returns `GreenFairy.GlobalId.Base64` unless configured otherwise
  in the application environment.
  """
  def default do
    Application.get_env(:green_fairy, :global_id, GreenFairy.GlobalId.Base64)
  end

  @doc """
  Encodes a global ID using the default or configured implementation.
  """
  def encode(type_name, id) do
    default().encode(type_name, id)
  end

  @doc """
  Decodes a global ID using the default or configured implementation.
  """
  def decode(global_id) do
    default().decode(global_id)
  end

  @doc """
  Decodes a global ID, raising on error.
  """
  def decode!(global_id) do
    case decode(global_id) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, "Invalid global ID: #{inspect(reason)}"
    end
  end

  @doc """
  Extracts just the type name from a global ID.
  """
  def type(global_id) do
    case decode(global_id) do
      {:ok, {type_name, _}} -> {:ok, type_name}
      error -> error
    end
  end

  @doc """
  Extracts just the local ID from a global ID.
  """
  def local_id(global_id) do
    case decode(global_id) do
      {:ok, {_, local_id}} -> {:ok, local_id}
      error -> error
    end
  end

  @doc """
  Decodes a global ID and attempts to parse the local ID as an integer.
  """
  def decode_id(global_id) do
    case decode(global_id) do
      {:ok, {type_name, local_id}} ->
        parsed_id =
          case Integer.parse(to_string(local_id)) do
            {int, ""} -> int
            _ -> local_id
          end

        {:ok, {type_name, parsed_id}}

      error ->
        error
    end
  end
end

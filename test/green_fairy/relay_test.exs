defmodule GreenFairy.RelayTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Relay

  describe "encode_id/2" do
    test "delegates to GlobalId.encode/2" do
      result = Relay.encode_id("User", 123)
      assert is_binary(result)

      {:ok, {"User", "123"}} = Relay.decode_id(result)
    end

    test "works with atom type names" do
      result = Relay.encode_id(:user, 456)
      assert is_binary(result)

      {:ok, {"User", "456"}} = Relay.decode_id(result)
    end
  end

  describe "decode_id/1" do
    test "delegates to GlobalId.decode/1" do
      encoded = Base.encode64("User:123")
      assert {:ok, {"User", "123"}} = Relay.decode_id(encoded)
    end

    test "returns error for invalid ID" do
      assert {:error, :invalid_global_id} = Relay.decode_id("invalid")
    end
  end

  describe "decode_id!/1" do
    test "delegates to GlobalId.decode!/1" do
      encoded = Base.encode64("User:123")
      assert {"User", "123"} = Relay.decode_id!(encoded)
    end

    test "raises for invalid ID" do
      assert_raise ArgumentError, fn ->
        Relay.decode_id!("invalid")
      end
    end
  end
end

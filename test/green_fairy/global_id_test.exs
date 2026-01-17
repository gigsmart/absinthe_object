defmodule GreenFairy.GlobalIdTest do
  use ExUnit.Case, async: true

  alias GreenFairy.GlobalId
  alias GreenFairy.GlobalId.Base64

  describe "GlobalId.Base64.encode/2" do
    test "encodes type name and id as base64" do
      encoded = Base64.encode("User", 123)
      assert is_binary(encoded)
      assert {:ok, {"User", "123"}} = Base64.decode(encoded)
    end

    test "converts atom type names to PascalCase" do
      encoded = Base64.encode(:user_profile, 42)
      assert {:ok, {"UserProfile", "42"}} = Base64.decode(encoded)
    end

    test "handles string IDs" do
      encoded = Base64.encode("Post", "abc-def")
      assert {:ok, {"Post", "abc-def"}} = Base64.decode(encoded)
    end
  end

  describe "GlobalId.Base64.decode/1" do
    test "decodes valid base64 global ID" do
      # "User:123" encoded
      encoded = Base.encode64("User:123")
      assert {:ok, {"User", "123"}} = Base64.decode(encoded)
    end

    test "returns error for invalid base64" do
      assert {:error, :invalid_global_id} = Base64.decode("not-valid-base64!!!")
    end

    test "returns error for missing colon separator" do
      encoded = Base.encode64("User123")
      assert {:error, :invalid_global_id} = Base64.decode(encoded)
    end
  end

  describe "GlobalId module functions" do
    test "encode/2 delegates to default implementation" do
      encoded = GlobalId.encode("User", 123)
      assert is_binary(encoded)
    end

    test "decode/1 delegates to default implementation" do
      encoded = GlobalId.encode("User", 123)
      assert {:ok, {"User", "123"}} = GlobalId.decode(encoded)
    end

    test "decode!/1 returns tuple on success" do
      encoded = GlobalId.encode("User", 123)
      assert {"User", "123"} = GlobalId.decode!(encoded)
    end

    test "decode!/1 raises on error" do
      assert_raise ArgumentError, fn ->
        GlobalId.decode!("invalid")
      end
    end

    test "type/1 returns only the type name" do
      encoded = GlobalId.encode("Post", 456)
      assert {:ok, "Post"} = GlobalId.type(encoded)
    end

    test "local_id/1 returns only the local ID" do
      encoded = GlobalId.encode("Comment", 789)
      assert {:ok, "789"} = GlobalId.local_id(encoded)
    end

    test "decode_id/1 parses integer IDs" do
      encoded = GlobalId.encode("User", 123)
      assert {:ok, {"User", 123}} = GlobalId.decode_id(encoded)
    end

    test "decode_id/1 keeps string IDs as strings" do
      encoded = GlobalId.encode("User", "uuid-here")
      assert {:ok, {"User", "uuid-here"}} = GlobalId.decode_id(encoded)
    end
  end
end

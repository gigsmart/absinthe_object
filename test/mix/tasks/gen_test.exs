defmodule Mix.Tasks.Gf.GenTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Gf.Gen

  describe "parse_field/1" do
    test "parses simple field" do
      assert %{name: "email", type: :string, modifier: nil, related: nil} =
               Gen.parse_field("email:string")
    end

    test "parses required field" do
      assert %{name: "email", type: :string, modifier: :required, related: nil} =
               Gen.parse_field("email:string:required")
    end

    test "parses list relationship" do
      assert %{name: "posts", type: :list, modifier: nil, related: "Post"} =
               Gen.parse_field("posts:list:Post")
    end

    test "parses ref relationship" do
      assert %{name: "org", type: :ref, modifier: nil, related: "Organization"} =
               Gen.parse_field("org:ref:Organization")
    end

    test "parses connection" do
      assert %{name: "friends", type: :connection, modifier: nil, related: "User"} =
               Gen.parse_field("friends:connection:User")
    end

    test "parses enum field" do
      assert %{name: "status", type: :enum, modifier: nil, related: "UserStatus"} =
               Gen.parse_field("status:enum:UserStatus")
    end

    test "parses field with only name as string" do
      assert %{name: "name", type: :string, modifier: nil, related: nil} =
               Gen.parse_field("name")
    end
  end

  describe "field_to_code/1" do
    test "generates simple field code" do
      field = %{name: "email", type: :string, modifier: nil, related: nil}
      assert Gen.field_to_code(field) == "field :email, :string"
    end

    test "generates required field code" do
      field = %{name: "email", type: :string, modifier: :required, related: nil}
      assert Gen.field_to_code(field) == "field :email, :string, null: false"
    end

    test "generates list relationship code" do
      field = %{name: "posts", type: :list, modifier: nil, related: "Post"}
      code = Gen.field_to_code(field)
      assert code == "field :posts, list_of(:post)"
    end

    test "generates ref relationship code" do
      field = %{name: "org", type: :ref, modifier: nil, related: "Organization"}
      code = Gen.field_to_code(field)
      assert code == "field :org, :organization"
    end

    test "generates connection code" do
      field = %{name: "friends", type: :connection, modifier: nil, related: "User"}
      code = Gen.field_to_code(field)
      assert code =~ "connection :friends"
      assert code =~ "Types.User"
    end
  end

  describe "to_file_name/1" do
    test "converts PascalCase to snake_case" do
      assert Gen.to_file_name("User") == "user"
      assert Gen.to_file_name("UserProfile") == "user_profile"
      assert Gen.to_file_name("BlogPost") == "blog_post"
    end
  end
end

defmodule GreenFairy.Relay.MutationTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Relay.Mutation

  describe "mutation_input_name/1" do
    test "converts mutation name to input type name" do
      assert :create_user_input = Mutation.mutation_input_name(:create_user)
      assert :update_post_input = Mutation.mutation_input_name(:update_post)
      assert :delete_comment_input = Mutation.mutation_input_name(:delete_comment)
    end
  end

  describe "mutation_payload_name/1" do
    test "converts mutation name to payload type name" do
      assert :create_user_payload = Mutation.mutation_payload_name(:create_user)
      assert :update_post_payload = Mutation.mutation_payload_name(:update_post)
      assert :delete_comment_payload = Mutation.mutation_payload_name(:delete_comment)
    end
  end

  describe "ClientMutationId middleware" do
    alias Mutation.ClientMutationId

    test "call extracts client_mutation_id from input and stores in private" do
      resolution = %Absinthe.Resolution{
        arguments: %{input: %{client_mutation_id: "abc-123", name: "test"}},
        private: %{}
      }

      result = ClientMutationId.call(resolution, [])

      assert result.private[:client_mutation_id] == "abc-123"
    end

    test "call handles missing client_mutation_id in input" do
      resolution = %Absinthe.Resolution{
        arguments: %{input: %{name: "test"}},
        private: %{}
      }

      result = ClientMutationId.call(resolution, [])

      assert result.private[:client_mutation_id] == nil
    end

    test "call handles missing input argument" do
      resolution = %Absinthe.Resolution{
        arguments: %{other_arg: "value"},
        private: %{}
      }

      result = ClientMutationId.call(resolution, [])

      # Should pass through unchanged
      assert result == resolution
    end

    test "add_to_result adds client_mutation_id to result map" do
      resolution = %{private: %{client_mutation_id: "abc-123"}}
      result = %{user: %{id: 1}}

      updated = ClientMutationId.add_to_result(result, resolution)

      assert updated.client_mutation_id == "abc-123"
      assert updated.user == %{id: 1}
    end

    test "add_to_result handles nil client_mutation_id" do
      resolution = %{private: %{client_mutation_id: nil}}
      result = %{user: %{id: 1}}

      updated = ClientMutationId.add_to_result(result, resolution)

      assert updated.client_mutation_id == nil
      assert updated.user == %{id: 1}
    end

    test "add_to_result returns non-map results unchanged" do
      resolution = %{private: %{client_mutation_id: "abc"}}

      assert ClientMutationId.add_to_result(:ok, resolution) == :ok
      assert ClientMutationId.add_to_result(nil, resolution) == nil
    end
  end
end

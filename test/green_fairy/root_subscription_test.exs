defmodule GreenFairy.RootSubscriptionTest do
  use ExUnit.Case, async: true

  defmodule TestSubscription do
    use GreenFairy.RootSubscription

    root_subscription_fields do
      field :thing_created, :string do
        config fn _, _ -> {:ok, topic: "things"} end
      end

      field :thing_updated, :string
    end
  end

  describe "RootSubscription" do
    test "defines __green_fairy_kind__" do
      assert TestSubscription.__green_fairy_kind__() == :root_subscription
    end

    test "defines __green_fairy_definition__" do
      assert TestSubscription.__green_fairy_definition__() == %{kind: :root_subscription}
    end

    test "defines __green_fairy_subscription_fields_identifier__" do
      assert TestSubscription.__green_fairy_subscription_fields_identifier__() ==
               :green_fairy_root_subscription_fields
    end
  end
end

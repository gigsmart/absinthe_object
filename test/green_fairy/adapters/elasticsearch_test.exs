defmodule GreenFairy.Adapters.ElasticsearchTest do
  use ExUnit.Case, async: true

  alias GreenFairy.Adapters.Elasticsearch

  describe "Elasticsearch adapter" do
    test "new/1 creates adapter with defaults" do
      adapter = Elasticsearch.new()

      assert %Elasticsearch{} = adapter
      assert adapter.index == nil
      assert adapter.client == nil
    end

    test "new/1 accepts index option" do
      adapter = Elasticsearch.new(index: "users")

      assert adapter.index == "users"
    end

    test "new/1 accepts client option" do
      adapter = Elasticsearch.new(client: MyElasticsearchClient)

      assert adapter.client == MyElasticsearchClient
    end

    test "new/1 accepts multiple options" do
      adapter = Elasticsearch.new(index: "products", client: MyClient)

      assert adapter.index == "products"
      assert adapter.client == MyClient
    end
  end
end

defmodule GreenFairy.Adapters.Elasticsearch do
  @moduledoc """
  Elasticsearch adapter struct for filter protocol dispatch.

  This struct represents an Elasticsearch connection. The `GreenFairy.Filter`
  protocol dispatches on this struct to build Elasticsearch query DSL.

  ## Options

  - `:client` - The Elasticsearch client module
  - `:index` - The index name
  - `:model` - Optional ExlasticSearch model module

  ## Example

      adapter = GreenFairy.Adapters.Elasticsearch.new(
        client: MyApp.ElasticClient,
        index: "users"
      )

  ## Query Building

  Filter implementations for this adapter should return Elasticsearch
  query DSL maps that can be merged into a bool query:

      %{
        "bool" => %{
          "filter" => [
            %{"term" => %{"status" => "active"}},
            %{"geo_distance" => %{"distance" => "10km", "location" => %{...}}}
          ]
        }
      }

  """

  defstruct [:client, :index, :model]

  @type t :: %__MODULE__{
          client: module() | nil,
          index: String.t() | nil,
          model: module() | nil
        }

  @doc "Create a new Elasticsearch adapter"
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      client: opts[:client],
      index: opts[:index],
      model: opts[:model]
    }
  end
end

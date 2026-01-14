defmodule SocialNetworkWeb.GraphQL.DataLoader do
  @moduledoc """
  DataLoader configuration for the social network GraphQL API.

  This module sets up Ecto-based data loading with batching to avoid N+1 queries.
  """

  alias SocialNetwork.Repo

  def new do
    Dataloader.new()
    |> Dataloader.add_source(:repo, ecto_source())
  end

  defp ecto_source do
    Dataloader.Ecto.new(Repo, query: &query/2)
  end

  defp query(queryable, _params) do
    queryable
  end
end

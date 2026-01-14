defmodule GreenFairy.AuthorizationInfo do
  @moduledoc """
  Information passed to authorize callbacks to help make authorization decisions.

  Contains the path through the graph, parent objects, and field being resolved.

  ## Structure

      %AuthorizationInfo{
        path: [:query, :user, :posts, :comments],
        field: :comments,
        parent: %Post{id: 1, author_id: "user-1"},
        parents: [%User{id: "user-1"}, %Post{id: 1}]
      }

  ## Usage in Authorization

      type "Comment", struct: MyApp.Comment do
        authorize fn comment, ctx, info ->
          post = info.parent

          cond do
            post.public -> :all
            ctx[:current_user]?.id == post.author_id -> :all
            true -> [:id, :body]
          end
        end

        field :id, non_null(:id)
        field :body, :string
        field :author, :user
      end

  """

  @type t :: %__MODULE__{
          path: [atom()],
          field: atom() | nil,
          parent: struct() | map() | nil,
          parents: [struct() | map()]
        }

  defstruct path: [],
            field: nil,
            parent: nil,
            parents: []

  @doc """
  Creates AuthorizationInfo from Absinthe resolution.
  """
  def from_resolution(%Absinthe.Resolution{} = resolution) do
    path = extract_path(resolution)
    parent = resolution.source

    # Build parents chain from path info if available
    parents = extract_parents(resolution)

    %__MODULE__{
      path: path,
      field: resolution.definition.schema_node.identifier,
      parent: parent,
      parents: parents
    }
  end

  @doc """
  Creates AuthorizationInfo for a root query/mutation (no parent).
  """
  def root(field_name) do
    %__MODULE__{
      path: [field_name],
      field: field_name,
      parent: nil,
      parents: []
    }
  end

  @doc """
  Adds a parent to the chain and updates the path.
  """
  def push_parent(%__MODULE__{} = info, parent, field_name) do
    %__MODULE__{
      info
      | path: info.path ++ [field_name],
        field: field_name,
        parent: parent,
        parents: info.parents ++ [parent]
    }
  end

  # Private helpers

  defp extract_path(%{path: path}) when is_list(path) do
    path
    |> Enum.map(fn
      %{name: name} when is_binary(name) -> String.to_atom(name)
      %{name: name} when is_atom(name) -> name
      name when is_binary(name) -> String.to_atom(name)
      name when is_atom(name) -> name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_path(_), do: []

  defp extract_parents(%{private: %{parents: parents}}) when is_list(parents) do
    parents
  end

  defp extract_parents(_), do: []
end

defmodule GreenFairy.Field.Middleware do
  @moduledoc """
  Middleware helpers for field-level and type-level middleware.

  Middleware can be applied at multiple levels:
  - Field level: Inside a field block
  - Type level: At the top of a type definition
  - Schema level: In the schema module

  ## Usage

  ### Field-level middleware

      type "User", struct: MyApp.User do
        field :email, :string do
          middleware MyApp.Middleware.Authenticate
          middleware MyApp.Middleware.Authorize, :admin
          resolve fn _, _, _ -> {:ok, "email"} end
        end
      end

  ### Type-level middleware (applied to all fields)

      type "SecretType", struct: MyApp.Secret do
        # This will be applied to all fields in this type
        type_middleware MyApp.Middleware.RequireAdmin

        field :data, :string
      end

  """

  @doc """
  Creates a middleware that checks if the current user has a specific capability.

  ## Usage

      field :admin_data, :string do
        middleware GreenFairy.Field.Middleware.require_capability(:admin)
        resolve fn _, _, _ -> {:ok, "secret"} end
      end

  """
  def require_capability(capability) do
    {__MODULE__, {:require_capability, capability}}
  end

  @doc false
  def call(%{context: context} = resolution, {:require_capability, capability}) do
    user = Map.get(context, :current_user)

    cond do
      is_nil(user) ->
        Absinthe.Resolution.put_result(resolution, {:error, "Authentication required"})

      has_capability?(user, capability) ->
        resolution

      true ->
        Absinthe.Resolution.put_result(resolution, {:error, "Unauthorized"})
    end
  end

  def call(resolution, {:cache, _ttl}) do
    # Placeholder - actual caching would be implemented here
    # This would typically check a cache, return cached value if present,
    # or continue and cache the result
    resolution
  end

  def call(resolution, _) do
    resolution
  end

  defp has_capability?(user, capability) do
    capabilities = Map.get(user, :capabilities, [])
    capability in capabilities
  end

  @doc """
  Creates a caching middleware.

  ## Usage

      field :expensive_data, :string do
        middleware GreenFairy.Field.Middleware.cache(ttl: 300)
        resolve fn _, _, _ -> {:ok, expensive_computation()} end
      end

  Note: This is a placeholder. Actual caching implementation depends on
  your caching strategy (ETS, Redis, etc.)
  """
  def cache(opts \\ []) do
    ttl = Keyword.get(opts, :ttl, 60)
    {__MODULE__, {:cache, ttl}}
  end
end

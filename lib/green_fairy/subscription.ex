defmodule GreenFairy.Subscription do
  @moduledoc """
  Defines subscription fields in a dedicated module.

  ## Usage

      defmodule MyApp.GraphQL.Subscriptions.UserSubscriptions do
        use GreenFairy.Subscription

        subscriptions do
          field :user_updated, MyApp.GraphQL.Types.User do
            arg :user_id, :id

            config fn args, _info ->
              {:ok, topic: args[:user_id] || "*"}
            end

            trigger :update_user, topic: fn user ->
              ["user_updated:\#{user.id}", "user_updated:*"]
            end
          end
        end
      end

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Absinthe.Schema.Notation

      import GreenFairy.Subscription, only: [subscriptions: 1]

      Module.register_attribute(__MODULE__, :green_fairy_subscriptions, accumulate: false)

      @before_compile GreenFairy.Subscription
    end
  end

  @doc """
  Defines subscription fields.

  ## Examples

      subscriptions do
        field :user_updated, :user do
          arg :user_id, :id

          config fn args, _info ->
            {:ok, topic: args[:user_id] || "*"}
          end
        end
      end

  """
  defmacro subscriptions(do: block) do
    quote do
      @green_fairy_subscriptions true

      # Store the block for later extraction by the schema
      def __green_fairy_subscription_fields__ do
        unquote(Macro.escape(block))
      end

      # Define subscriptions object that can be imported
      object :green_fairy_subscriptions do
        unquote(block)
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    has_subscriptions = Module.get_attribute(env.module, :green_fairy_subscriptions)

    quote do
      @doc false
      def __green_fairy_definition__ do
        %{
          kind: :subscriptions,
          has_subscriptions: unquote(has_subscriptions || false)
        }
      end

      @doc false
      def __green_fairy_kind__ do
        :subscriptions
      end
    end
  end
end

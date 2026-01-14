defmodule GreenFairy.Test.RootQueryExample do
  use GreenFairy.RootQuery

  root_query_fields do
    field :hello, :string do
      resolve fn _, _, _ -> {:ok, "world"} end
    end

    field :ping, :string do
      resolve fn _, _, _ -> {:ok, "pong"} end
    end
  end
end

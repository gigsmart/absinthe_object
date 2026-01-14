defmodule GreenFairy.Test.SchemaWithRootsExample do
  use GreenFairy.Schema,
    discover: [],
    query: GreenFairy.Test.RootQueryExample,
    mutation: GreenFairy.Test.RootMutationExample
end

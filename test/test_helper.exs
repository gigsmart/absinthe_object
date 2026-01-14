# Force load filter implementation modules to trigger registration
# These modules register themselves at compile time, but we need to ensure
# they're loaded before tests run to populate the persistent_term registry
filter_modules = [
  Absinthe.Object.Filter.Elasticsearch,
  Absinthe.Object.Filter.Ecto.Postgres
]

for module <- filter_modules do
  Code.ensure_loaded!(module)
end

# Explicitly trigger registration by calling module function
# This works around the persistent_term being cleared on restart
for module <- filter_modules do
  if function_exported?(module, :__filter_impls__, 0) do
    impls = module.__filter_impls__()
    adapter = module.__adapter__()

    for filter_type <- impls do
      filter_name = filter_type |> Module.split() |> List.last()
      impl_module = Module.concat([module, String.to_atom("Impl_" <> filter_name)])

      # Code.ensure_loaded/1 returns {:module, mod} or {:error, reason}
      case Code.ensure_loaded(impl_module) do
        {:module, _} ->
          Absinthe.Object.Filter.register_implementation(adapter, filter_type, impl_module)

        {:error, _reason} ->
          :skip
      end
    end
  end
end

ExUnit.start()

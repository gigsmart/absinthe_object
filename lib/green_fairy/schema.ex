defmodule GreenFairy.Schema do
  @moduledoc """
  Schema assembly with auto-discovery of types.

  Automatically discovers and imports all types, and generates
  query/mutation/subscription root types.

  ## Basic Usage (Auto-Discovery)

      defmodule MyApp.GraphQL.Schema do
        use GreenFairy.Schema,
          discover: [MyApp.GraphQL]
      end

  ## Explicit Root Types

  You can explicitly specify root type modules:

      defmodule MyApp.GraphQL.Schema do
        use GreenFairy.Schema,
          discover: [MyApp.GraphQL],
          query: MyApp.GraphQL.RootQuery,
          mutation: MyApp.GraphQL.RootMutation,
          subscription: MyApp.GraphQL.RootSubscription
      end

  ## Inline Root Definitions

  Or define roots inline:

      defmodule MyApp.GraphQL.Schema do
        use GreenFairy.Schema,
          discover: [MyApp.GraphQL]

        root_query do
          field :health, :string do
            resolve fn _, _, _ -> {:ok, "ok"} end
          end
        end

        root_mutation do
          field :noop, :boolean do
            resolve fn _, _, _ -> {:ok, true} end
          end
        end
      end

  ## Options

  - `:discover` - List of namespaces to scan for type modules
  - `:query` - Module to use as root query (or use `root_query` macro)
  - `:mutation` - Module to use as root mutation (or use `root_mutation` macro)
  - `:subscription` - Module to use as root subscription (or use `root_subscription` macro)
  - `:dataloader` - DataLoader configuration
    - `:sources` - List of `{source_name, repo_or_source}` tuples

  """

  @doc false
  defmacro __using__(opts) do
    namespaces = Keyword.get(opts, :discover, [])
    dataloader_opts = Keyword.get(opts, :dataloader, [])
    query_module_ast = Keyword.get(opts, :query)
    mutation_module_ast = Keyword.get(opts, :mutation)
    subscription_module_ast = Keyword.get(opts, :subscription)

    # Expand module aliases to actual atoms
    query_module = if query_module_ast, do: Macro.expand(query_module_ast, __CALLER__), else: nil
    mutation_module = if mutation_module_ast, do: Macro.expand(mutation_module_ast, __CALLER__), else: nil
    subscription_module = if subscription_module_ast, do: Macro.expand(subscription_module_ast, __CALLER__), else: nil

    # Generate import_types and root blocks for explicit modules NOW (in __using__)
    # This ensures they run BEFORE Absinthe.Schema's __before_compile__
    explicit_imports = generate_using_imports(query_module, mutation_module, subscription_module)
    query_block = generate_using_query_block(query_module)
    mutation_block = generate_using_mutation_block(mutation_module)
    subscription_block = generate_using_subscription_block(subscription_module)

    quote do
      # Store configuration FIRST for use in callbacks
      @green_fairy_namespaces unquote(namespaces)
      @green_fairy_dataloader unquote(Macro.escape(dataloader_opts))
      @green_fairy_query_module unquote(query_module)
      @green_fairy_mutation_module unquote(mutation_module)
      @green_fairy_subscription_module unquote(subscription_module)

      # For inline root definitions
      Module.register_attribute(__MODULE__, :green_fairy_inline_query, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_inline_mutation, accumulate: false)
      Module.register_attribute(__MODULE__, :green_fairy_inline_subscription, accumulate: false)

      # Register our before_compile FIRST so it runs before Absinthe's
      @before_compile GreenFairy.Schema

      # Now use Absinthe.Schema (which registers its own @before_compile that runs after ours)
      use Absinthe.Schema

      # Import built-in types
      import_types GreenFairy.BuiltIns.PageInfo

      # Import explicit root modules (must happen before query/mutation/subscription blocks)
      unquote_splicing(explicit_imports)

      # Generate root types for explicit modules
      unquote(query_block)
      unquote(mutation_block)
      unquote(subscription_block)

      import GreenFairy.Schema, only: [root_query: 1, root_mutation: 1, root_subscription: 1]
    end
  end

  # Helper functions for __using__ macro (run at compile time of calling code)
  defp generate_using_imports(query_module, mutation_module, subscription_module) do
    [query_module, mutation_module, subscription_module]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn module ->
      quote do
        import_types unquote(module)
      end
    end)
  end

  defp generate_using_query_block(nil), do: nil

  defp generate_using_query_block(module) do
    identifier = module.__green_fairy_query_fields_identifier__()

    quote do
      query do
        import_fields unquote(identifier)
      end
    end
  end

  defp generate_using_mutation_block(nil), do: nil

  defp generate_using_mutation_block(module) do
    identifier = module.__green_fairy_mutation_fields_identifier__()

    quote do
      mutation do
        import_fields unquote(identifier)
      end
    end
  end

  defp generate_using_subscription_block(nil), do: nil

  defp generate_using_subscription_block(module) do
    identifier = module.__green_fairy_subscription_fields_identifier__()

    quote do
      subscription do
        import_fields unquote(identifier)
      end
    end
  end

  @doc """
  Define inline query fields for this schema.

      root_query do
        field :health, :string do
          resolve fn _, _, _ -> {:ok, "ok"} end
        end
      end

  """
  defmacro root_query(do: block) do
    quote do
      @green_fairy_inline_query unquote(Macro.escape(block))
    end
  end

  @doc """
  Define inline mutation fields for this schema.

      root_mutation do
        field :noop, :boolean do
          resolve fn _, _, _ -> {:ok, true} end
        end
      end

  """
  defmacro root_mutation(do: block) do
    quote do
      @green_fairy_inline_mutation unquote(Macro.escape(block))
    end
  end

  @doc """
  Define inline subscription fields for this schema.

      root_subscription do
        field :events, :event do
          config fn _, _ -> {:ok, topic: "*"} end
        end
      end

  """
  defmacro root_subscription(do: block) do
    quote do
      @green_fairy_inline_subscription unquote(Macro.escape(block))
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    namespaces = Module.get_attribute(env.module, :green_fairy_namespaces)
    dataloader_opts = Module.get_attribute(env.module, :green_fairy_dataloader)

    # Get explicit module configurations
    query_module = Module.get_attribute(env.module, :green_fairy_query_module)
    mutation_module = Module.get_attribute(env.module, :green_fairy_mutation_module)
    subscription_module = Module.get_attribute(env.module, :green_fairy_subscription_module)

    # Get inline definitions
    inline_query = Module.get_attribute(env.module, :green_fairy_inline_query)
    inline_mutation = Module.get_attribute(env.module, :green_fairy_inline_mutation)
    inline_subscription = Module.get_attribute(env.module, :green_fairy_inline_subscription)

    # Discover all type modules at compile time
    discovered = discover_at_compile_time(namespaces)
    grouped = GreenFairy.Discovery.group_by_kind(discovered)

    # Generate import_types for all discovered modules
    import_statements = generate_imports(grouped)

    # Note: Explicit root modules are handled in __using__, not here
    # Here we only handle inline definitions and auto-discovered modules

    # Generate root operation types for inline and discovered ONLY (explicit handled in __using__)
    # Only generate if there's no explicit module (explicit modules are handled in __using__)
    query_block = generate_before_compile_root_block(:query, query_module, inline_query, grouped[:queries] || [])

    mutation_block =
      generate_before_compile_root_block(:mutation, mutation_module, inline_mutation, grouped[:mutations] || [])

    subscription_block =
      generate_before_compile_root_block(
        :subscription,
        subscription_module,
        inline_subscription,
        grouped[:subscriptions] || []
      )

    # Generate dataloader context if configured
    dataloader_context = generate_dataloader_context(dataloader_opts)

    # Build all statements as a list, filtering out nils
    statements =
      [
        import_statements,
        [query_block],
        [mutation_block],
        [subscription_block],
        if(dataloader_context, do: [dataloader_context], else: []),
        [
          quote do
            @doc false
            def __green_fairy_discovered__ do
              unquote(Macro.escape(discovered))
            end
          end
        ]
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    {:__block__, [], statements}
  end

  # Generate root block for __before_compile__ - skips if explicit module exists
  # (explicit modules are handled in __using__)
  defp generate_before_compile_root_block(_type, explicit_module, _inline_block, _discovered_modules)
       when not is_nil(explicit_module) do
    # Explicit module is handled in __using__, return nil here
    nil
  end

  defp generate_before_compile_root_block(type, _explicit_module, inline_block, discovered_modules) do
    # Only handle inline and discovered (explicit is nil at this point)
    cond do
      inline_block != nil ->
        generate_root_from_inline(type, inline_block)

      discovered_modules != [] ->
        generate_root_from_discovered(type, discovered_modules)

      true ->
        nil
    end
  end

  defp generate_root_from_inline(:query, block) do
    quote do
      query do
        unquote(block)
      end
    end
  end

  defp generate_root_from_inline(:mutation, block) do
    quote do
      mutation do
        unquote(block)
      end
    end
  end

  defp generate_root_from_inline(:subscription, block) do
    quote do
      subscription do
        unquote(block)
      end
    end
  end

  defp generate_root_from_discovered(:query, modules) do
    import_statements =
      Enum.map(modules, fn _module ->
        quote do
          import_fields :green_fairy_queries
        end
      end)

    quote do
      query do
        (unquote_splicing(import_statements))
      end
    end
  end

  defp generate_root_from_discovered(:mutation, modules) do
    import_statements =
      Enum.map(modules, fn _module ->
        quote do
          import_fields :green_fairy_mutations
        end
      end)

    quote do
      mutation do
        (unquote_splicing(import_statements))
      end
    end
  end

  defp generate_root_from_discovered(:subscription, modules) do
    import_statements =
      Enum.map(modules, fn _module ->
        quote do
          import_fields :green_fairy_subscriptions
        end
      end)

    quote do
      subscription do
        (unquote_splicing(import_statements))
      end
    end
  end

  # Discover modules at compile time by walking the namespace
  defp discover_at_compile_time(namespaces) when is_list(namespaces) do
    Enum.flat_map(namespaces, &discover_namespace_compile/1)
  end

  defp discover_namespace_compile(namespace) when is_atom(namespace) do
    # Get all compiled modules that match the namespace
    # This works because we're in a @before_compile callback
    :code.all_loaded()
    |> Enum.map(fn {module, _} -> module end)
    |> Enum.filter(fn module ->
      module_string = Atom.to_string(module)
      namespace_string = Atom.to_string(namespace)
      String.starts_with?(module_string, namespace_string)
    end)
    |> Enum.filter(fn module ->
      function_exported?(module, :__green_fairy_definition__, 0)
    end)
  end

  defp generate_imports(grouped) do
    all_modules =
      (grouped[:types] || []) ++
        (grouped[:interfaces] || []) ++
        (grouped[:inputs] || []) ++
        (grouped[:enums] || []) ++
        (grouped[:unions] || []) ++
        (grouped[:scalars] || []) ++
        (grouped[:queries] || []) ++
        (grouped[:mutations] || []) ++
        (grouped[:subscriptions] || [])

    Enum.map(all_modules, fn module ->
      quote do
        import_types unquote(module)
      end
    end)
  end

  defp generate_dataloader_context([]), do: nil

  defp generate_dataloader_context(opts) do
    sources = Keyword.get(opts, :sources, [])

    if sources == [] do
      nil
    else
      quote do
        def context(ctx) do
          loader =
            Dataloader.new()
            |> Dataloader.add_source(:repo, Dataloader.Ecto.new(unquote(hd(sources))))

          Map.put(ctx, :loader, loader)
        end

        def plugins do
          [Absinthe.Middleware.Dataloader | Absinthe.Plugin.defaults()]
        end
      end
    end
  end

  @doc """
  Generates resolve_type function for an interface based on discovered implementors.

  This can be called manually or used by the schema to auto-generate
  resolve_type functions for interfaces.

  ## Example

      def resolve_type(value, _) do
        GreenFairy.Schema.resolve_type_for(value, %{
          MyApp.User => :user,
          MyApp.Post => :post
        })
      end

  """
  def resolve_type_for(value, struct_mapping) when is_map(value) do
    case Map.get(value, :__struct__) do
      nil -> nil
      struct_module -> Map.get(struct_mapping, struct_module)
    end
  end

  def resolve_type_for(_, _), do: nil
end

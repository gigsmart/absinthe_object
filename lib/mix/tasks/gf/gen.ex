defmodule Mix.Tasks.Gf.Gen do
  @moduledoc """
  Shared utilities for GreenFairy generators.

  ## Field Syntax

  Fields are specified as `name:type[:modifier][:related_type]`:

      email:string:required          # field :email, :string, null: false
      name:string                    # field :name, :string
      posts:list:Post                # field :posts, list_of(:post)
      organization:ref:Org           # field :organization, :organization
      friends:connection:User        # connection :friends, MyApp.GraphQL.Types.User
      status:enum:UserStatus         # field :status, MyApp.GraphQL.Enums.UserStatus

  ## Configuration

  Configure generators in `config/config.exs`:

      config :green_fairy, :generators,
        graphql_namespace: MyApp.GraphQL,
        domain_namespace: MyApp,
        default_implements: [MyApp.GraphQL.Interfaces.Node],
        timestamps: true
  """

  @doc "Returns the configured GraphQL namespace"
  def graphql_namespace do
    Application.get_env(:green_fairy, :generators, [])
    |> Keyword.get(:graphql_namespace)
    |> case do
      nil -> infer_graphql_namespace()
      ns -> ns
    end
  end

  @doc "Returns the configured domain namespace"
  def domain_namespace do
    Application.get_env(:green_fairy, :generators, [])
    |> Keyword.get(:domain_namespace)
    |> case do
      nil -> infer_domain_namespace()
      ns -> ns
    end
  end

  @doc "Returns default interfaces to implement"
  def default_implements do
    Application.get_env(:green_fairy, :generators, [])
    |> Keyword.get(:default_implements, [])
  end

  @doc "Whether to add timestamp fields by default"
  def timestamps? do
    Application.get_env(:green_fairy, :generators, [])
    |> Keyword.get(:timestamps, false)
  end

  @doc "Parses field specification string into a map"
  def parse_field(field_spec) do
    parts = String.split(field_spec, ":")

    case parts do
      [name] ->
        %{name: name, type: :string, modifier: nil, related: nil}

      [name, type] ->
        %{name: name, type: parse_type(type), modifier: nil, related: nil}

      [name, type, modifier] when modifier in ~w(required list ref connection enum) ->
        case modifier do
          "required" ->
            %{name: name, type: parse_type(type), modifier: :required, related: nil}

          "list" ->
            %{name: name, type: :list, modifier: nil, related: type}

          "ref" ->
            %{name: name, type: :ref, modifier: nil, related: type}

          "connection" ->
            %{name: name, type: :connection, modifier: nil, related: type}

          "enum" ->
            %{name: name, type: :enum, modifier: nil, related: type}
        end

      [name, rel, related] when rel in ~w(list ref connection enum) ->
        %{name: name, type: String.to_atom(rel), modifier: nil, related: related}

      _ ->
        raise "Invalid field specification: #{field_spec}"
    end
  end

  @doc "Converts a field map to code string"
  def field_to_code(%{type: :list, name: name, related: related}) do
    type_identifier = related |> Macro.underscore() |> String.to_atom()
    "field :#{name}, list_of(:#{type_identifier})"
  end

  def field_to_code(%{type: :ref, name: name, related: related}) do
    type_identifier = related |> Macro.underscore() |> String.to_atom()
    "field :#{name}, :#{type_identifier}"
  end

  def field_to_code(%{type: :connection, name: name, related: related}) do
    type_module = resolve_type_module(related)
    "connection :#{name}, #{type_module}"
  end

  def field_to_code(%{type: :enum, name: name, related: related}) do
    enum_module = resolve_enum_module(related)
    "field :#{name}, #{enum_module}"
  end

  def field_to_code(%{name: name, type: type, modifier: :required}) do
    "field :#{name}, :#{type}, null: false"
  end

  def field_to_code(%{name: name, type: type}) do
    "field :#{name}, :#{type}"
  end

  @doc "Resolves a type name to its full module path"
  def resolve_type_module(type_name) do
    "#{graphql_namespace()}.Types.#{type_name}"
  end

  @doc "Resolves an interface name to its full module path"
  def resolve_interface_module(interface_name) do
    "#{graphql_namespace()}.Interfaces.#{interface_name}"
  end

  @doc "Resolves an input name to its full module path"
  def resolve_input_module(input_name) do
    "#{graphql_namespace()}.Inputs.#{input_name}"
  end

  @doc "Resolves an enum name to its full module path"
  def resolve_enum_module(enum_name) do
    "#{graphql_namespace()}.Enums.#{enum_name}"
  end

  @doc "Resolves a struct name from a type name"
  def resolve_struct_module(type_name) do
    "#{domain_namespace()}.#{type_name}"
  end

  @doc "Converts a PascalCase name to snake_case file name"
  def to_file_name(name) do
    name
    |> Macro.underscore()
    |> String.replace("/", "_")
  end

  @doc "Returns the path for a type file"
  def type_path(name) do
    base = graphql_base_path()
    file_name = to_file_name(name)
    Path.join([base, "types", "#{file_name}.ex"])
  end

  @doc "Returns the path for an interface file"
  def interface_path(name) do
    base = graphql_base_path()
    file_name = to_file_name(name)
    Path.join([base, "interfaces", "#{file_name}.ex"])
  end

  @doc "Returns the path for an input file"
  def input_path(name) do
    base = graphql_base_path()
    file_name = to_file_name(name)
    Path.join([base, "inputs", "#{file_name}.ex"])
  end

  @doc "Returns the path for an enum file"
  def enum_path(name) do
    base = graphql_base_path()
    file_name = to_file_name(name)
    Path.join([base, "enums", "#{file_name}.ex"])
  end

  @doc "Returns the path for the schema file"
  def schema_path do
    base = graphql_base_path()
    Path.join([base, "schema.ex"])
  end

  @doc "Writes a file and creates directories if needed"
  def write_file(path, content) do
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, content)
    Mix.shell().info([:green, "* creating ", :reset, path])
  end

  # Private helpers

  defp graphql_base_path do
    ns = graphql_namespace()

    ns
    |> Module.split()
    |> Enum.map(&Macro.underscore/1)
    |> then(&["lib" | &1])
    |> Path.join()
  end

  defp infer_graphql_namespace do
    case Mix.Project.config()[:app] do
      nil ->
        raise "Could not infer GraphQL namespace. Please configure :graphql_namespace"

      app ->
        app_name = app |> Atom.to_string() |> Macro.camelize()
        Module.concat([app_name, GraphQL])
    end
  end

  defp infer_domain_namespace do
    case Mix.Project.config()[:app] do
      nil ->
        raise "Could not infer domain namespace. Please configure :domain_namespace"

      app ->
        app |> Atom.to_string() |> Macro.camelize() |> List.wrap() |> Module.concat()
    end
  end

  defp parse_type("id"), do: :id
  defp parse_type("string"), do: :string
  defp parse_type("integer"), do: :integer
  defp parse_type("float"), do: :float
  defp parse_type("boolean"), do: :boolean
  defp parse_type("datetime"), do: :datetime
  defp parse_type("date"), do: :date
  defp parse_type("time"), do: :time
  defp parse_type(other), do: String.to_atom(other)
end

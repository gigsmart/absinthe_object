# Types Overview

GreenFairy provides a clean DSL for defining all GraphQL type kinds. Each type kind
has its own module and follows the "one module = one type" principle.

## Type Kinds

| Kind | Module | Guide |
|------|--------|-------|
| Object Types | `GreenFairy.Type` | [Object Types](object-types.md) |
| Interfaces | `GreenFairy.Interface` | [Interfaces](interfaces.md) |
| Input Types | `GreenFairy.Input` | [Input Types](input-types.md) |
| Enums | `GreenFairy.Enum` | [Enums](enums.md) |
| Unions | `GreenFairy.Union` | [Unions](unions.md) |
| Scalars | `GreenFairy.Scalar` | [Scalars](scalars.md) |

## Directory Structure

Organize types by kind:

```
lib/my_app/graphql/
├── schema.ex           # Main schema
├── types/              # Object types
├── interfaces/         # Interfaces
├── inputs/             # Input types
├── enums/              # Enums
├── unions/             # Unions
├── scalars/            # Custom scalars
├── queries/            # Query operations
├── mutations/          # Mutation operations
└── resolvers/          # Resolver logic
```

## Type References

Use **module references** for non-builtin types to enable auto-discovery:

```elixir
alias MyApp.GraphQL.Types
alias MyApp.GraphQL.Enums

field :posts, list_of(Types.Post)
field :status, Enums.UserStatus
```

Use **atoms** only for built-in scalars: `:id`, `:string`, `:integer`, `:float`, `:boolean`, `:datetime`.

## Common Module Functions

All GreenFairy type modules export:

| Function | Description |
|----------|-------------|
| `__green_fairy_kind__/0` | Returns the type kind (`:object`, `:interface`, etc.) |
| `__green_fairy_identifier__/0` | Returns the snake_case identifier |
| `__green_fairy_definition__/0` | Returns the full definition map |

## Naming Conventions

| GraphQL Name | Elixir Identifier |
|--------------|-------------------|
| `User` | `:user` |
| `CreateUserInput` | `:create_user_input` |
| `UserRole` | `:user_role` |

The identifier is automatically derived from the GraphQL name using snake_case.

## Detailed Guides

- [Object Types](object-types.md) - Fields, resolvers, batch loading, associations
- [Interfaces](interfaces.md) - Shared fields, automatic type resolution
- [Input Types](input-types.md) - Mutation arguments, validation
- [Enums](enums.md) - Value definitions, mappings
- [Unions](unions.md) - Polymorphic returns
- [Scalars](scalars.md) - Custom parsing/serialization

## Related Guides

- [Operations](operations.md) - Queries, mutations, subscriptions
- [Relationships](relationships.md) - Associations and DataLoader
- [Connections](connections.md) - Relay-style pagination
- [Authorization](authorization.md) - Field-level access control
- [CQL](cql.md) - Automatic filtering and sorting

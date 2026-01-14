# Claude Code Instructions for GreenFairy

## Project Overview

This is a new Elixir library that provides a cleaner DSL for GraphQL schema definitions built on top of Absinthe. The goal is to replace complex Absinthe macros with a more intuitive, Rails-like API.

**Key Design Principles:**
- One module = one GraphQL type (SOLID)
- Convention over configuration
- Auto-discovery of types
- Extensibility over features

## Implementation Plan

The complete implementation plan is in `PLAN.md`. Always reference this when implementing features.

## Project Structure

```
lib/
  absinthe/
    object.ex                     # Main entry point
    object/
      type.ex                     # use GreenFairy.Type
      interface.ex                # use GreenFairy.Interface
      input.ex                    # use GreenFairy.Input
      enum.ex                     # use GreenFairy.Enum
      union.ex                    # use GreenFairy.Union
      scalar.ex                   # use GreenFairy.Scalar
      query.ex                    # use GreenFairy.Query
      mutation.ex                 # use GreenFairy.Mutation
      subscription.ex             # use GreenFairy.Subscription
      schema.ex                   # use GreenFairy.Schema
      discovery.ex                # Auto-discovery of type modules
      field/                      # Field helpers
      built_ins/                  # Built-in types (Node, PageInfo)
      mix/tasks/                  # Mix generators
```

## Development Commands

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Run specific test file
mix test test/green_fairy/type_test.exs

# Generate docs
mix docs
```

## Implementation Order

Follow the phases in PLAN.md:
1. Phase 1: Core Foundation (Type, Interface)
2. Phase 2: Additional Types (Input, Enum, Union, Scalar)
3. Phase 3: Relationships & DataLoader
4. Phase 4: Connections
5. Phase 5: Operations (Query, Mutation, Subscription)
6. Phase 6: Schema Assembly
7. Phase 7: Middleware & Polish
8. Phase 8: Mix Generators
9. Phase 9: Authorization & Extensibility

## Key Absinthe Files to Reference

When implementing, reference these files in the Absinthe codebase:
- `lib/absinthe/schema/notation.ex` - How macros build Blueprint
- `lib/absinthe/blueprint/schema.ex` - Blueprint assembly
- `lib/absinthe/phase/schema/type_imports.ex` - Type discovery
- `lib/absinthe/resolution/helpers.ex` - DataLoader integration

## Testing Strategy

- Unit tests for each DSL macro
- Integration tests with complete schemas
- Test compile-time error messages
- Test DataLoader batching
- Test connection pagination

## Code Style

- Use `@moduledoc` and `@doc` for all public functions
- Use typespecs for public APIs
- Follow Elixir naming conventions
- Keep modules focused (single responsibility)

## Commit Messages

Use conventional commits:
- `feat:` new features
- `fix:` bug fixes
- `docs:` documentation
- `test:` adding tests
- `refactor:` code refactoring

## Notes

- This library generates Absinthe Blueprint AST, it doesn't replace Absinthe's runtime
- Types are auto-discovered via `__green_fairy_definition__/0` callback
- The `resolve_type` for interfaces is auto-generated from `implements` calls

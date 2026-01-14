# Social Network Example

A comprehensive example demonstrating GreenFairy's GraphQL DSL with a social networking domain.

## Features

- **Users** with profiles, friendships, posts, comments, and likes
- **Posts** with visibility controls (public, friends, private)
- **Comments** with nested replies
- **Likes** on posts and comments
- **Friendships** with status (pending, accepted, blocked)

## GraphQL Types

This example demonstrates:

- **Types**: User, Post, Comment, Like, Friendship
- **Enums**: FriendshipStatus, PostVisibility
- **Interfaces**: Node (for Relay global IDs)
- **DataLoader**: Batch loading for associations

## Setup

```bash
# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.create
mix ecto.migrate
```

## Project Structure

```
lib/
  social_network/
    accounts/
      user.ex           # User Ecto schema
      friendship.ex     # Friendship Ecto schema
    content/
      post.ex           # Post Ecto schema
      comment.ex        # Comment Ecto schema
      like.ex           # Like Ecto schema
    repo.ex             # Ecto repo
    application.ex      # OTP application
  social_network_web/
    graphql/
      schema.ex         # GraphQL schema
      data_loader.ex    # DataLoader configuration
      interfaces/
        node.ex         # Node interface
      enums/
        friendship_status.ex
        post_visibility.ex
      types/
        user.ex
        post.ex
        comment.ex
        like.ex
        friendship.ex
```

## GraphQL API

### Queries

```graphql
query {
  # Get current user
  viewer {
    id
    username
    posts {
      body
      comments {
        body
        author { username }
      }
    }
  }

  # Get user by ID
  user(id: "1") {
    username
    displayName
    friends { username }
  }

  # Get all public posts
  posts(visibility: PUBLIC) {
    body
    author { username }
    likes { user { username } }
  }
}
```

### Mutations

```graphql
mutation {
  # Create a new user
  createUser(email: "alice@example.com", username: "alice") {
    id
    username
  }

  # Create a post
  createPost(body: "Hello, world!", visibility: PUBLIC) {
    id
    body
  }

  # Comment on a post
  createComment(postId: "1", body: "Great post!") {
    id
    body
    author { username }
  }

  # Like a post
  likePost(postId: "1") {
    id
  }

  # Send friend request
  sendFriendRequest(friendId: "2") {
    id
    status
  }
}
```

## Type Definitions

Each GraphQL type is defined in its own module using the clean DSL:

```elixir
defmodule SocialNetworkWeb.GraphQL.Types.User do
  use GreenFairy.Type

  alias SocialNetworkWeb.GraphQL.Interfaces

  type "User", struct: SocialNetwork.Accounts.User do
    implements Interfaces.Node

    field :id, non_null(:id)
    field :email, non_null(:string)
    field :username, non_null(:string)
    field :display_name, :string
    field :bio, :string

    field :posts, list_of(:post)
    field :friends, list_of(:user)
  end
end
```

## License

MIT

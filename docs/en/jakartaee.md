# Jakarta EE Support

## Overview

The Jakarta EE Implementation is used widely among many Java Frameworks.  These include but are not limited to Quarkus and Helidon.  This support attempts to detect projects based on the appearance of jakarta.ws.rs imports and popular dependencies.

## Framework Details

- Name: jakartaee
- Language: Java, Kotlin
- File Extensions: `*.java`, `*.kt`
- Framework: JakartaEEFramework

## Detection Strategy

The framework detect Jakarta EE projects by looking for specific dependencies in build files:

**Required Dependencies (one of the following):**

- jakarta.ws.rs
- javax.ws.rs
- jax-rs
- jersey
- resteasy
- cxfr-rt-frontend-jaxrs
- quarkus-rest
- quarkus-rest-jackson
- quarkus-rest-jsonb
- helidon-webserver-jersey

**Manifest Files Searched:**

- pom.xml (Maven)
- build.gradle (Gradle, Groovy DSL)
- build.gradle.kts (Gradle, Kotlin DSL)

### Annotation-Based Parsing

The framework uses annotation-based parsing to extract endpoint information for Jakarta EE annotations.

### Supported Annotations

| Annotation | HTTP Method | Example |
| @GET | GET | @GET("/users") |
| @POST | POST | @POST("/users") |
| @PUT | PUT | @PUT("/users/{id}") |
| @DELETE | DELETE | @DELETE("/users/{id}") |
| @PATCH | PATCH | @PATCH("/users/{id}") |
| @OPTIONS | OPTIONS | @OPTIONS |

### Path Extraction Patterns

The parser extracts the path from the @Path annotation.  Path annotations are supported in both of the following formats:

- @Path("/users")
- @Path(value = "/users")

### Controller Base Path Support

The framework automatically detects and combines class-level @Path annotations with method-level mappings:

```java
@Path("/users")
public class UserResource {
    @GET
    @Path("/{id}/profile")
    public User getProvider(@PathParam("id") userId) {
        // ...
    }
}
```

> [!TIP]
> The final path for the above example would be /users/{id}/profile

## Configuration Options

### File Processing

- **Include Patterns**: `*.java`, `*.kt`
- **Exclude Patterns**:
  - `**/target` (Maven build directory)
  - `**/build` (Gradle build directory)
  - `**/.gradle` (Gradle cache)

### Search Options

- `--case-sensitive`: Preserves Java annotation case sensitivity
- `--type java`: Optimizes search for Java files
- `--type kotlin`: Optimizes search for kotlin files.

### Pattern Matching

```lua
patterns = {
  GET = { "@GET" },
  POST = { "@POST" },
  PUT = { "@PUT" },
  DELETE = { "@DELETE" },
  PATCH = { "@PATCH" },
  HEAD = { "@HEAD" },
  OPTIONS = { "@OPTIONS" },
},
```

## Metadata Enhancement

### Framework-Specific Tags

- `java` or `kotlin` (language)
- jakartaee (framework)

### Confidence Scoring

Base confidence: 0.8

**Confidence Boosts:**

- +0.1 for well-formed paths (starting with `/`)
- +0.1 for standard HTTP methods

## Example Endpoint Structures

### Basic REST Controller

```java
@Path("/users")
public class UserResource {
  @GET
@Produces(MediaType.APPLICATION_JSON)
  public List<User> getAllUsers() { }
  // Detected: GET /users

  @GET
  @Path("/{id}")
  @Produces(MediaType.APPLICATION_JSON)
  public User getUser(@PathParam("id") Long id) { }
  // Detected GET /users/{id}

  @POST
  @Consumes(MediaType.APPLICATION_JSON)
  public Response createUser(User user) { }

  @PUT
  @Path("/{id}")
  @Consumes(MediaType.APPLICATION_JSON)
  public Response updateUser(@PathParam("id") Long id, User user) { }

  @DELETE
  @Path("/{id}")
  public Response deleteUser(@PathParam("id") Long id) { }

  @PATCH
  @Path("/{id}")
  public Response updatePartial(PathParam("id") Long id, UserPartial user) { }

  @OPTIONS
  public Response getOptions() { }
}
```

## Troubleshooting

### Common Issues

> [!WARNING]
> **No Endpoints Detected**
>
> - Verify one of the supported dependencies in pom.xml or build.gradle.
> - Ensure that method or class uses a valid jakarta.ws.rs annotation.
> - Ensure files have `.java` or `.kt` extensions

### Debug Information

Enable framework debugging to see detection and parsing details:

```lua
-- In your Neovim config
vim.g.endpoint_debug = true
```

## Integration Notes

> [!INFO]
>
> - Works with javax.ws.rs and jakarta.ws.rs annotations.
> - Compatible with Helidon and Quarkus frameworks, it's a easy pull request to jakarta_ee.lua to add additional ones.
> - Supports Java and Kotlin files
> - Handles nested path structures
> - Automatically excludes build directories from search

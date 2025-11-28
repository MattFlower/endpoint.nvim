# Jakarta EE Support

## Overview

The Jakarta EE Implementation is used widely among many Java Frameworks.  These include but are not limited to Quarkus, Micronaut, and Helidon.  This implementation attempts to detect the use of JAX-RS not only by the direct presence of jakarta.ws.rs dependencies but also by popular implementations of the specification.

## Framework Details

- Name: jakartaee
- Language: Java, Kotlin
- File Extensions: `*.java`, `*.kt`
- Framework: JakartaEEFramework

## Detection Strategy

The framework detect Jakarta EE projects by looking for specific dependencies in build files:

**Required Dependencies:**

One of the following dependencies must be present in order to activate support:

- jakarta.ws.rs
- javax.ws.rs
- jax-rs
- jersey-server
- resteasy-core
- cxfr-rt-frontend-jaxrs
- quarkus-rest
- micronaut-jaxrs-server
- helidon-webserver-jersey

**Manifest Files Searched:**

- pom.xml (Maven)
- build.gradle (Gradle, Groovy DSL)
- build.gradle.kts (Gradle, Kotlin DSL)

### Annotation-Based Parsing

This framework searches for endpoints by searching for the REST endpoint annotations supported by JAX-RS, including:

| Annotation | HTTP Method | Example |
| @GET | GET | @GET("/users") |
| @POST | POST | @POST("/users") |
| @PUT | PUT | @PUT("/users/{id}") |
| @DELETE | DELETE | @DELETE("/users/{id}") |
| @PATCH | PATCH | @PATCH("/users/{id}") |
| @OPTIONS | OPTIONS | @OPTIONS |

### Identifying paths

Once a REST annotation has been identified, this framework uses the tree-sitter parser to parse the Java class.  Any of the following styles of Path annotations can be recognized: 

- @Path("/users")
- @Path(value = "/users")
- @Path(SOME_CONSTANT + "/users")
- @Path(value = SOME_CONSTANT + "/users")

Constants may be in the same class, same package, or entirely different packages.  This is one of the main reasons why tree-sitter is required.

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

### Rest Controller using Constants in the Path names

```java
import static com.somecompany.Constants.API_BASE;

@Path(API_BASE + "/users")
public class UserResource {
  @GET
  @Path("/{id}/profile")
  @Produces(MediaType.APPLICATION_JSON)
  public UserProfile getUserProfile(@PathParam("id") Long id) { }
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
> - Compatible with Quarkus, Micronaut, Helidon, and CXF frameworks
> - Supports Java and Kotlin files
> - Handles nested path structures
> - Automatically excludes build directories from search
> - Requires the java tree-sitter plugin for parsing (:TSInstall java)

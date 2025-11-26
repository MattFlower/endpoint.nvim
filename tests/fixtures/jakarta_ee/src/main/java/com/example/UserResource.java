package com.example;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@Path("/users")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class UserResource {

    @GET
    public Response listUsers() {
        return Response.ok("List of users").build();
    }

    @GET
    @Path("/{id}")
    public Response getUser(@PathParam("id") String id) {
        return Response.ok("User: " + id).build();
    }

    @GET
    @Path("/{id}/profile")
    public Response getUserProfile(@PathParam("id") String id) {
        return Response.ok("User profile: " + id).build();
    }

    @GET
    @Path("/search")
    public Response searchUsers(@QueryParam("query") String query) {
        return Response.ok("Search results for: " + query).build();
    }

    @POST
    public Response createUser(String user) {
        return Response.status(Response.Status.CREATED).entity("User created").build();
    }

    @POST
    @Path("/register")
    public Response registerUser(String user) {
        return Response.status(Response.Status.CREATED).entity("User registered").build();
    }

    @PUT
    @Path("/{id}")
    public Response updateUser(@PathParam("id") String id, String user) {
        return Response.ok("User updated: " + id).build();
    }

    @PATCH
    @Path("/{id}/status")
    public Response updateUserStatus(@PathParam("id") String id) {
        return Response.ok("Status updated: " + id).build();
    }

    @DELETE
    @Path("/{id}")
    public Response deleteUser(@PathParam("id") String id) {
        return Response.ok("User deleted: " + id).build();
    }
}

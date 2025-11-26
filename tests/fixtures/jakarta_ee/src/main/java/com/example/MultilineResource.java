package com.example;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@Path("/multiline")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class MultilineResource {

    @GET
    @Path("/items/{id}")
    public Response getItem(
            @PathParam("id") Long id) {
        return Response.ok("Item: " + id).build();
    }

    @POST
    @Path("/items")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response createItem(
            String item) {
        return Response.status(Response.Status.CREATED).entity("Item created").build();
    }

    @PUT
    @Path("/items/{id}")
    public Response updateItem(
            @PathParam("id") Long id,
            String item) {
        return Response.ok("Item updated: " + id).build();
    }
}

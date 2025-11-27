package com.example;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@Path(ApiResource.API_BASE)
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ApiResource {

    public static final String API_BASE = "/api/v1";

    @GET
    @Path("/items")
    public Response listItems() {
        return Response.ok("List of items").build();
    }

    @GET
    @Path(API_BASE + "/orders")
    public Response listOrders() {
        return Response.ok("List of orders").build();
    }

    @POST
    @Path("/items" + "/{id}")
    public Response createItem(@PathParam("id") String id) {
        return Response.status(Response.Status.CREATED).entity("Item created").build();
    }

    @PUT
    @Path(value = API_BASE + "/products")
    public Response updateProducts() {
        return Response.ok("Products updated").build();
    }

    @DELETE
    @Path(value = "/categories" + "/" + "all")
    public Response deleteAllCategories() {
        return Response.ok("All categories deleted").build();
    }
}

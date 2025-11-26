package com.example;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@Path("/products")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ProductResource {

    @GET
    public Response listProducts() {
        return Response.ok("List of products").build();
    }

    @GET
    @Path("/{id}")
    public Response getProduct(@PathParam("id") Long id) {
        return Response.ok("Product: " + id).build();
    }

    @GET
    @Path("/category/{category}")
    public Response getProductsByCategory(@PathParam("category") String category) {
        return Response.ok("Products in category: " + category).build();
    }

    @POST
    public Response createProduct(String product) {
        return Response.status(Response.Status.CREATED).entity("Product created").build();
    }

    @PUT
    @Path("/{id}")
    public Response updateProduct(@PathParam("id") Long id, String product) {
        return Response.ok("Product updated: " + id).build();
    }

    @DELETE
    @Path("/{id}")
    public Response deleteProduct(@PathParam("id") Long id) {
        return Response.ok("Product deleted: " + id).build();
    }
}

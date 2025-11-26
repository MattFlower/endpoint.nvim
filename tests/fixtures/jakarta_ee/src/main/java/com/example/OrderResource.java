package com.example;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@Path("/orders")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class OrderResource {

    @GET
    public Response listOrders() {
        return Response.ok("List of orders").build();
    }

    @GET
    @Path("/{id}")
    public Response getOrder(@PathParam("id") Long id) {
        return Response.ok("Order: " + id).build();
    }

    @GET
    @Path("/user/{userId}")
    public Response getOrdersByUser(@PathParam("userId") String userId) {
        return Response.ok("Orders for user: " + userId).build();
    }

    @POST
    public Response createOrder(String order) {
        return Response.status(Response.Status.CREATED).entity("Order created").build();
    }

    @PUT
    @Path("/{id}")
    public Response updateOrder(@PathParam("id") Long id, String order) {
        return Response.ok("Order updated: " + id).build();
    }

    @PATCH
    @Path("/{id}/status")
    public Response updateOrderStatus(@PathParam("id") Long id, String status) {
        return Response.ok("Order status updated: " + id).build();
    }

    @DELETE
    @Path("/{id}")
    public Response cancelOrder(@PathParam("id") Long id) {
        return Response.ok("Order cancelled: " + id).build();
    }

    @HEAD
    @Path("/{id}")
    public Response checkOrderExists(@PathParam("id") Long id) {
        return Response.ok().build();
    }

    @OPTIONS
    public Response getOptions() {
        return Response.ok()
            .header("Allow", "GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS")
            .build();
    }
}

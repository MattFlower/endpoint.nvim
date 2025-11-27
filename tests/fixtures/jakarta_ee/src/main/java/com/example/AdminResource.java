package com.example;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.Response;

@Path(Constants.ADMIN_BASE)
public class AdminResource {

    @GET
    @Path(Constants.API_VERSION + "/users")
    public Response listAdminUsers() {
        return Response.ok("Admin users").build();
    }

    @POST
    @Path(Constants.API_VERSION + "/users" + "/create")
    public Response createAdminUser() {
        return Response.ok("Created").build();
    }

    @DELETE
    @Path("/users/" + "all")
    public Response deleteAllUsers() {
        return Response.ok("Deleted").build();
    }
}

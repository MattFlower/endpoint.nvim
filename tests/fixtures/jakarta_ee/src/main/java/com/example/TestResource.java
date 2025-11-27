package com.example;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.Response;

@Path("/test")
public class TestResource {

    @GET
    public Response getTest() {
        return Response.ok().build();
    }

    @GET
    @Path("/users")
    public Response getUsers() {
        return Response.ok().build();
    }

    @POST
    public Response postTest() {
        return Response.ok().build();
    }

    @PUT
    public Response putTest() {
        return Response.ok().build();
    }

    @DELETE
    public Response deleteTest() {
        return Response.ok().build();
    }

    @PATCH
    public Response patchTest() {
        return Response.ok().build();
    }

    @HEAD
    public Response headTest() {
        return Response.ok().build();
    }

    @OPTIONS
    public Response optionsTest() {
        return Response.ok().build();
    }

    @GET
    @Path("noleadingslash")
    public Response noLeadingSlash() {
        return Response.ok().build();
    }

    @GET
    @Path("/withslash")
    public Response withSlash() {
        return Response.ok().build();
    }
}

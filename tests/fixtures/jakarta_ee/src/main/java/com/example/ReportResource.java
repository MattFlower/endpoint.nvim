package com.example;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.Response;
import com.example.config.ApiConfig;

@Path(ApiConfig.REPORTING_PATH)
public class ReportResource {

    @GET
    @Path(ApiConfig.BASE_PATH + "/summary")
    public Response getSummary() {
        return Response.ok("Summary").build();
    }

    @GET
    @Path(ApiConfig.BASE_PATH + "/details" + "/full")
    public Response getFullDetails() {
        return Response.ok("Full details").build();
    }

    @POST
    @Path("/generate" + ApiConfig.REPORTING_PATH)
    public Response generateReport() {
        return Response.ok("Generated").build();
    }
}

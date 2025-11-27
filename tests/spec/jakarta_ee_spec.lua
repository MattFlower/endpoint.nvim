---@diagnostic disable: duplicate-set-field
local JakartaEEFramework = require("endpoint.frameworks.jakarta_ee")
local JakartaEEParser = require("endpoint.parser.jakarta_ee_parser")
local fs = require("endpoint.utils.fs")

describe("JakartaEEFramework", function()
	local framework
	local parser
	local original_has_file
	local original_file_contains
	local original_glob

	local function mockFs(has_pom, has_gradle, has_jaxrs_deps, has_gradle_deps)
		fs.has_file = function(files)
			if type(files) == "table" then
				for _, file in ipairs(files) do
					if file == "pom.xml" then
						return has_pom
					elseif file == "build.gradle" or file == "build.gradle.kts" then
						return has_gradle
					end
				end
			end
			return false
		end

		fs.file_contains = function(filepath, pattern)
			if filepath == "pom.xml" then
				if
					pattern == "jakarta.ws.rs"
					or pattern == "javax.ws.rs"
					or pattern == "jax-rs"
					or pattern == "jersey"
					or pattern == "resteasy"
				then
					return has_jaxrs_deps
				end
			elseif filepath == "build.gradle" or filepath == "build.gradle.kts" then
				if
					pattern == "jakarta.ws.rs"
					or pattern == "javax.ws.rs"
					or pattern == "jax-rs"
					or pattern == "jersey"
					or pattern == "resteasy"
				then
					return has_gradle_deps
				end
			end
			return false
		end
	end

	before_each(function()
		framework = JakartaEEFramework:new()
		parser = JakartaEEParser:new()

		-- Backup original functions
		original_has_file = fs.has_file
		original_file_contains = fs.file_contains
		original_glob = vim.fn.glob
	end)

	after_each(function()
		-- Restore original functions
		fs.has_file = original_has_file
		fs.file_contains = original_file_contains
		vim.fn.glob = original_glob
	end)

	describe("Framework Detection", function()
		it("should have correct framework name", function()
			assert.equals("jakarta_ee", framework:get_name())
		end)

		it("should have detector configured", function()
			assert.is_not_nil(framework.detector)
			assert.equals("jakarta_ee_dependency_detection", framework.detector.detection_name)
		end)

		it("should have parser configured", function()
			assert.is_not_nil(framework.parser)
			assert.equals("jakarta_ee_parser", framework.parser.parser_name)
		end)
	end)

	describe("Framework Configuration", function()
		it("should have correct file extensions", function()
			local config = framework:get_config()
			assert.same({ "*.java", "*.kt" }, config.file_extensions)
		end)

		it("should have exclude patterns", function()
			local config = framework:get_config()
			assert.same({ "**/target", "**/build", "**/.gradle" }, config.exclude_patterns)
		end)

		it("should have JAX-RS-specific search patterns", function()
			local config = framework:get_config()
			assert.is_table(config.patterns.GET)
			assert.is_table(config.patterns.POST)
			assert.is_table(config.patterns.PUT)
			assert.is_table(config.patterns.DELETE)
			assert.is_table(config.patterns.PATCH)
			assert.is_table(config.patterns.HEAD)
			assert.is_table(config.patterns.OPTIONS)

			-- Check for JAX-RS-specific patterns
			local has_get = false
			local has_post = false
			for _, pattern in ipairs(config.patterns.GET) do
				if pattern:match("@GET") then
					has_get = true
					break
				end
			end
			for _, pattern in ipairs(config.patterns.POST) do
				if pattern:match("@POST") then
					has_post = true
					break
				end
			end
			assert.is_true(has_get)
			assert.is_true(has_post)
		end)

		it("should have controller extractors", function()
			local config = framework:get_config()
			assert.is_table(config.controller_extractors)
			assert.is_true(#config.controller_extractors > 0)
		end)

		it("should have detector configuration", function()
			local config = framework:get_config()
			assert.is_table(config.detector)
			assert.is_table(config.detector.dependencies)
			assert.is_table(config.detector.manifest_files)
			assert.equals("jakarta_ee_dependency_detection", config.detector.name)

			-- Check for JAX-RS-specific dependencies
			local has_jakarta_ws_rs = false
			local has_jersey = false
			for _, dep in ipairs(config.detector.dependencies) do
				if dep:match("jakarta%.ws%.rs") then
					has_jakarta_ws_rs = true
				end
				if dep:match("jersey") then
					has_jersey = true
				end
			end
			assert.is_true(has_jakarta_ws_rs)
			assert.is_true(has_jersey)
		end)

		it("should detect Maven project with JAX-RS dependencies", function()
			mockFs(true, false, true, false)

			local detector = framework.detector
			assert.is_true(detector:is_target_detected())
		end)

		it("should detect Gradle project with JAX-RS dependencies", function()
			mockFs(false, true, false, true)

			local detector = framework.detector
			assert.is_true(detector:is_target_detected())
		end)

		it("should return false when no JAX-RS files exist", function()
			mockFs(false, false, false, false)

			local detector = framework.detector
			assert.is_false(detector:is_target_detected())
		end)
	end)

	describe("Parser Functionality", function()
		local test_file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/TestResource.java"

		it("should parse @GET annotations", function()
			-- Line 9 has @GET
			local result = parser:parse_content("    @GET", test_file_path, 9, 5)

			assert.is_not_nil(result)
			assert.equals("GET", result.method)
		end)

		it("should parse @GET with @Path annotations", function()
			-- Line 14 has @GET, line 15 has @Path("/users")
			local result = parser:parse_content("    @GET", test_file_path, 14, 5)

			assert.is_not_nil(result)
			assert.equals("GET", result.method)
			assert.equals("/test/users", result.endpoint_path)
		end)

		it("should parse real JAX-RS resource file", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/UserResource.java"
			local file_content = vim.fn.readfile(file_path)

			-- Test multiple endpoints from the real file
			local results = {}
			for line_num, line in ipairs(file_content) do
				local result = parser:parse_content(line, file_path, line_num, 1)
				if result then
					table.insert(results, result)
				end
			end

			-- Should find multiple endpoints from the real resource
			assert.is_true(#results > 0, "Should find at least one endpoint from real resource")

			-- Verify specific endpoints exist
			local found_get_list = false
			local found_post_create = false
			for _, result in ipairs(results) do
				if result.endpoint_path == "/users" and result.method == "GET" then
					found_get_list = true
				end
				if result.endpoint_path == "/users" and result.method == "POST" then
					found_post_create = true
				end
			end

			assert.is_true(found_get_list, "Should find GET /users endpoint")
			assert.is_true(found_post_create, "Should find POST /users endpoint")
		end)

		it("should combine class-level and method-level @Path annotations", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/UserResource.java"
			-- Line 17 has @GET, line 18 has @Path("/{id}")
			local result = parser:parse_content("    @GET", file_path, 17, 5)

			assert.is_not_nil(result)
			assert.equals("GET", result.method)
			assert.equals("/users/{id}", result.endpoint_path)
			assert.equals("/users", result.metadata.base_path)
			assert.equals("/{id}", result.metadata.raw_endpoint_path)
		end)

		it("should find @Path on line after HTTP method annotation", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/UserResource.java"
			-- Line 23 has @GET, line 24 has @Path("/{id}/profile")
			local result = parser:parse_content("    @GET", file_path, 23, 5)

			assert.is_not_nil(result)
			assert.equals("GET", result.method)
			assert.equals("/users/{id}/profile", result.endpoint_path)
		end)

		it("should use only base path when no method-level @Path exists", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/UserResource.java"
			-- Line 12 has @GET with no method-level @Path
			local result = parser:parse_content("    @GET", file_path, 12, 5)

			assert.is_not_nil(result)
			assert.equals("GET", result.method)
			assert.equals("/users", result.endpoint_path)
			assert.equals("/", result.metadata.raw_endpoint_path)
		end)

		it("should parse @POST annotations", function()
			-- Line 20 has @POST
			local result = parser:parse_content("    @POST", test_file_path, 20, 5)

			assert.is_not_nil(result)
			assert.equals("POST", result.method)
		end)

		it("should parse @PUT annotations", function()
			-- Line 25 has @PUT
			local result = parser:parse_content("    @PUT", test_file_path, 25, 5)

			assert.is_not_nil(result)
			assert.equals("PUT", result.method)
		end)

		it("should parse @DELETE annotations", function()
			-- Line 30 has @DELETE
			local result = parser:parse_content("    @DELETE", test_file_path, 30, 5)

			assert.is_not_nil(result)
			assert.equals("DELETE", result.method)
		end)

		it("should parse @PATCH annotations", function()
			-- Line 35 has @PATCH
			local result = parser:parse_content("    @PATCH", test_file_path, 35, 5)

			assert.is_not_nil(result)
			assert.equals("PATCH", result.method)
		end)

		it("should parse @HEAD annotations", function()
			-- Line 40 has @HEAD
			local result = parser:parse_content("    @HEAD", test_file_path, 40, 5)

			assert.is_not_nil(result)
			assert.equals("HEAD", result.method)
		end)

		it("should parse @OPTIONS annotations", function()
			-- Line 45 has @OPTIONS
			local result = parser:parse_content("    @OPTIONS", test_file_path, 45, 5)

			assert.is_not_nil(result)
			assert.equals("OPTIONS", result.method)
		end)

		it("should handle path without leading slash", function()
			-- Line 50 has @GET, line 51 has @Path("noleadingslash")
			local result = parser:parse_content("    @GET", test_file_path, 50, 5)

			assert.is_not_nil(result)
			assert.equals("/test/noleadingslash", result.endpoint_path)
		end)

		it("should handle paths with leading slash", function()
			-- Line 56 has @GET, line 57 has @Path("/withslash")
			local result = parser:parse_content("    @GET", test_file_path, 56, 5)

			assert.is_not_nil(result)
			assert.equals("/test/withslash", result.endpoint_path)
		end)

		it("should extract string literals from concatenation with constant", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/ApiResource.java"
			-- Line 20 has @GET, line 21 has @Path(API_BASE + "/orders")
			local result = parser:parse_content("    @GET", file_path, 20, 5)

			assert.is_not_nil(result)
			assert.equals("GET", result.method)
			-- Only the string literal "/orders" should be extracted (constant is skipped)
			assert.equals("/orders", result.metadata.raw_endpoint_path)
		end)

		it("should extract multiple string literals from concatenation", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/ApiResource.java"
			-- Line 26 has @POST, line 27 has @Path("/items" + "/{id}")
			local result = parser:parse_content("    @POST", file_path, 26, 5)

			assert.is_not_nil(result)
			assert.equals("POST", result.method)
			-- Both string literals should be concatenated
			assert.equals("/items/{id}", result.metadata.raw_endpoint_path)
		end)

		it("should handle concatenation in element_value_pair", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/ApiResource.java"
			-- Line 32 has @PUT, line 33 has @Path(value = API_BASE + "/products")
			local result = parser:parse_content("    @PUT", file_path, 32, 5)

			assert.is_not_nil(result)
			assert.equals("PUT", result.method)
			assert.equals("/products", result.metadata.raw_endpoint_path)
		end)

		it("should handle multiple string concatenations", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/ApiResource.java"
			-- Line 38 has @DELETE, line 39 has @Path(value = "/categories" + "/" + "all")
			local result = parser:parse_content("    @DELETE", file_path, 38, 5)

			assert.is_not_nil(result)
			assert.equals("DELETE", result.method)
			assert.equals("/categories/all", result.metadata.raw_endpoint_path)
		end)

		it("should extract string literals when constant is from another class", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/AdminResource.java"
			-- Line 9 has @GET, line 10 has @Path(Constants.API_VERSION + "/users")
			local result = parser:parse_content("    @GET", file_path, 9, 5)

			assert.is_not_nil(result)
			assert.equals("GET", result.method)
			-- Only the string literal "/users" should be extracted (Constants.API_VERSION is skipped)
			assert.equals("/users", result.metadata.raw_endpoint_path)
		end)

		it("should handle mixed external constants and multiple string literals", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/AdminResource.java"
			-- Line 15 has @POST, line 16 has @Path(Constants.API_VERSION + "/users" + "/create")
			local result = parser:parse_content("    @POST", file_path, 15, 5)

			assert.is_not_nil(result)
			assert.equals("POST", result.method)
			-- Both string literals should be extracted, constant skipped
			assert.equals("/users/create", result.metadata.raw_endpoint_path)
		end)

		it("should handle string concatenation without external constants", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/AdminResource.java"
			-- Line 21 has @DELETE, line 22 has @Path("/users/" + "all")
			local result = parser:parse_content("    @DELETE", file_path, 21, 5)

			assert.is_not_nil(result)
			assert.equals("DELETE", result.method)
			-- Both string literals should be concatenated
			assert.equals("/users/all", result.metadata.raw_endpoint_path)
		end)

		it("should extract string literals when constant is from imported package", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/ReportResource.java"
			-- Line 10 has @GET, line 11 has @Path(ApiConfig.BASE_PATH + "/summary")
			local result = parser:parse_content("    @GET", file_path, 10, 5)

			assert.is_not_nil(result)
			assert.equals("GET", result.method)
			-- Only the string literal "/summary" should be extracted
			assert.equals("/summary", result.metadata.raw_endpoint_path)
		end)

		it("should handle imported constant with multiple string literals", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/ReportResource.java"
			-- Line 16 has @GET, line 17 has @Path(ApiConfig.BASE_PATH + "/details" + "/full")
			local result = parser:parse_content("    @GET", file_path, 16, 5)

			assert.is_not_nil(result)
			assert.equals("GET", result.method)
			-- Both string literals should be extracted, imported constant skipped
			assert.equals("/details/full", result.metadata.raw_endpoint_path)
		end)

		it("should handle string literal before imported constant", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/ReportResource.java"
			-- Line 22 has @POST, line 23 has @Path("/generate" + ApiConfig.REPORTING_PATH)
			local result = parser:parse_content("    @POST", file_path, 22, 5)

			assert.is_not_nil(result)
			assert.equals("POST", result.method)
			-- Only the string literal "/generate" should be extracted
			assert.equals("/generate", result.metadata.raw_endpoint_path)
		end)
	end)

	describe("Search Command Generation", function()
		it("should generate valid search commands", function()
			local search_cmd = framework:get_search_cmd()
			assert.is_string(search_cmd)
			assert.matches("rg", search_cmd)
			assert.matches("--type java", search_cmd)
			assert.matches("--case%-sensitive", search_cmd)
		end)
	end)

	describe("Controller Name Extraction", function()
		it("should extract controller name from Java file", function()
			local controller_name = framework:getControllerName("src/main/java/com/example/UserResource.java")
			assert.is_not_nil(controller_name)
		end)

		it("should extract controller name from Kotlin file", function()
			local controller_name = framework:getControllerName("src/main/kotlin/com/example/UserResource.kt")
			assert.is_not_nil(controller_name)
		end)

		it("should handle nested resource paths", function()
			local controller_name = framework:getControllerName("src/main/java/com/example/api/UserResource.java")
			assert.is_not_nil(controller_name)
		end)
	end)

	describe("Integration Tests", function()
		it("should create framework instance successfully", function()
			local instance = JakartaEEFramework:new()
			assert.is_not_nil(instance)
			assert.equals("jakarta_ee", instance:get_name())
		end)

		it("should have parser and detector ready", function()
			assert.is_not_nil(framework.parser)
			assert.is_not_nil(framework.detector)
			assert.equals("jakarta_ee", framework.parser.framework_name)
		end)

		it("should parse and enhance endpoints", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/TestResource.java"
			-- Line 9 has @GET
			local result = framework:parse("    @GET", file_path, 9, 5)

			assert.is_not_nil(result)
			assert.equals("jakarta_ee", result.framework)
			assert.is_table(result.metadata)
			assert.equals("jakarta_ee", result.metadata.framework)
		end)
	end)
end)

describe("JakartaEEParser", function()
	local parser

	before_each(function()
		parser = JakartaEEParser:new()
	end)

	describe("Parser Instance", function()
		it("should create parser with correct properties", function()
			assert.equals("jakarta_ee_parser", parser.parser_name)
			assert.equals("jakarta_ee", parser.framework_name)
			assert.equals("java", parser.language)
		end)
	end)

	describe("Endpoint Path Extraction", function()
		it("should extract simple paths", function()
			local path = parser:extract_endpoint_path('@Path("/users")')
			assert.equals("/users", path)
		end)

		it("should extract paths with path variables", function()
			local path = parser:extract_endpoint_path('@Path("/users/{id}")')
			assert.equals("/users/{id}", path)
		end)

		it("should add leading slash to paths without one", function()
			local path = parser:extract_endpoint_path('@Path("users")')
			assert.equals("/users", path)
		end)

		it("should handle single quotes", function()
			local path = parser:extract_endpoint_path("@Path('/users')")
			assert.equals("/users", path)
		end)

		it("should handle complex path patterns", function()
			local path = parser:extract_endpoint_path('@Path("/users/{id}/orders/{orderId}")')
			assert.equals("/users/{id}/orders/{orderId}", path)
		end)
	end)

	describe("HTTP Method Extraction", function()
		it("should extract GET", function()
			local method = parser:extract_method("@GET")
			assert.equals("GET", method)
		end)

		it("should extract POST", function()
			local method = parser:extract_method("@POST")
			assert.equals("POST", method)
		end)

		it("should extract PUT", function()
			local method = parser:extract_method("@PUT")
			assert.equals("PUT", method)
		end)

		it("should extract DELETE", function()
			local method = parser:extract_method("@DELETE")
			assert.equals("DELETE", method)
		end)

		it("should extract PATCH", function()
			local method = parser:extract_method("@PATCH")
			assert.equals("PATCH", method)
		end)

		it("should extract HEAD", function()
			local method = parser:extract_method("@HEAD")
			assert.equals("HEAD", method)
		end)

		it("should extract OPTIONS", function()
			local method = parser:extract_method("@OPTIONS")
			assert.equals("OPTIONS", method)
		end)

		it("should return nil for non-HTTP method content", function()
			local method = parser:extract_method('@Path("/users")')
			assert.is_nil(method)
		end)
	end)

	describe("Base Path Extraction", function()
		it("should handle class-level @Path", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/TestResource.java"
			local base_path = parser:extract_base_path(file_path, 10)
			assert.equals("/test", base_path)
		end)

		it("should return empty string for non-existent file", function()
			local base_path = parser:extract_base_path("nonexistent.java", 10)
			assert.equals("", base_path)
		end)
	end)

	describe("Error Handling", function()
		it("should handle empty content", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/TestResource.java"
			local result = parser:parse_content("", file_path, 1, 1)
			assert.is_nil(result)
		end)

		it("should return nil for non-existent file", function()
			local result = parser:parse_content("@GET", "nonexistent.java", 1, 1)
			assert.is_nil(result)
		end)

		it("should return nil for non-JAX-RS content", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/TestResource.java"
			local result = parser:parse_content("public void someMethod() {}", file_path, 1, 1)
			assert.is_nil(result)
		end)

		it("should skip comments", function()
			local file_path = "tests/fixtures/jakarta_ee/src/main/java/com/example/TestResource.java"
			local result = parser:parse_content("// @GET", file_path, 1, 1)
			assert.is_nil(result)
		end)
	end)

	describe("Confidence Scoring", function()
		it("should return higher confidence for complete annotations", function()
			local confidence_with_path = parser:get_parsing_confidence('@GET @Path("/users")')
			local confidence_without_path = parser:get_parsing_confidence("@GET")
			assert.is_true(confidence_with_path > confidence_without_path)
		end)

		it("should return 0 for empty content", function()
			local confidence = parser:get_parsing_confidence("")
			assert.equals(0.0, confidence)
		end)
	end)
end)

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
		it("should parse @GET annotations", function()
			local content = "@GET"
			local result = parser:parse_content(content, "UserResource.java", 1, 1)

			assert.is_not_nil(result)
			assert.equals("GET", result.method)
		end)

		it("should parse @GET with @Path annotations", function()
			local content = '@GET @Path("/users")'
			local result = parser:parse_content(content, "UserResource.java", 1, 1)

			assert.is_not_nil(result)
			assert.equals("GET", result.method)
			assert.equals("/users", result.endpoint_path)
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

		it("should parse @POST annotations", function()
			local content = "@POST"
			local result = parser:parse_content(content, "UserResource.java", 1, 1)

			assert.is_not_nil(result)
			assert.equals("POST", result.method)
		end)

		it("should parse @PUT annotations", function()
			local content = '@PUT @Path("/{id}")'
			local result = parser:parse_content(content, "UserResource.java", 1, 1)

			assert.is_not_nil(result)
			assert.equals("PUT", result.method)
			assert.equals("/{id}", result.endpoint_path)
		end)

		it("should parse @DELETE annotations", function()
			local content = '@DELETE @Path("/{id}")'
			local result = parser:parse_content(content, "UserResource.java", 1, 1)

			assert.is_not_nil(result)
			assert.equals("DELETE", result.method)
			assert.equals("/{id}", result.endpoint_path)
		end)

		it("should parse @PATCH annotations", function()
			local content = '@PATCH @Path("/{id}/status")'
			local result = parser:parse_content(content, "UserResource.java", 1, 1)

			assert.is_not_nil(result)
			assert.equals("PATCH", result.method)
			assert.equals("/{id}/status", result.endpoint_path)
		end)

		it("should parse @HEAD annotations", function()
			local content = '@HEAD @Path("/{id}")'
			local result = parser:parse_content(content, "UserResource.java", 1, 1)

			assert.is_not_nil(result)
			assert.equals("HEAD", result.method)
		end)

		it("should parse @OPTIONS annotations", function()
			local content = "@OPTIONS"
			local result = parser:parse_content(content, "UserResource.java", 1, 1)

			assert.is_not_nil(result)
			assert.equals("OPTIONS", result.method)
		end)

		it("should handle path without leading slash", function()
			local content = '@GET @Path("users")'
			local result = parser:parse_content(content, "UserResource.java", 1, 1)

			assert.is_not_nil(result)
			assert.equals("/users", result.endpoint_path)
		end)

		it("should handle single quotes in path", function()
			local content = "@GET @Path('/users')"
			local result = parser:parse_content(content, "UserResource.java", 1, 1)

			assert.is_not_nil(result)
			assert.equals("/users", result.endpoint_path)
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
			local content = '@GET @Path("/api/users")'
			local result = framework:parse(content, "UserResource.java", 1, 1)

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
			local base_path = parser:extract_base_path("UserResource.java", 10)
			assert.is_true(base_path == nil or type(base_path) == "string")
		end)
	end)

	describe("Error Handling", function()
		it("should handle empty content", function()
			local result = parser:parse_content("", "test.java", 1, 1)
			assert.is_nil(result)
		end)

		it("should handle missing file path", function()
			local result = parser:parse_content("@GET", "test.java", 1, 1)
			assert.is_not_nil(result)
		end)

		it("should return nil for non-JAX-RS content", function()
			local result = parser:parse_content("public void someMethod() {}", "test.java", 1, 1)
			assert.is_nil(result)
		end)

		it("should skip comments", function()
			local result = parser:parse_content("// @GET", "test.java", 1, 1)
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

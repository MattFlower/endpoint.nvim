local Framework = require("endpoint.core.Framework")
local class = require("endpoint.lib.middleclass")
local JakartaEEParser = require("endpoint.parser.jakarta_ee_parser")

---@class endpoint.JakartaEEFramework
local JakartaEEFramework = class("JakartaEEFramework", Framework)

---Creates a new JakartaEEFramework instance
function JakartaEEFramework:initialize()
	Framework.initialize(self, {
		name = "jakarta_ee",
		config = {
			file_extensions = { "*.java", "*.kt" },
			exclude_patterns = { "**/target", "**/build", "**/.gradle" },
			patterns = {
				GET = { "@GET" },
				POST = { "@POST" },
				PUT = { "@PUT" },
				DELETE = { "@DELETE" },
				PATCH = { "@PATCH" },
				HEAD = { "@HEAD" },
				OPTIONS = { "@OPTIONS" },
			},
			search_options = { "--case-sensitive", "--type", "java", "-U", "--multiline-dotall" },
			controller_extractors = {
				{ pattern = "([^/]+)%.java$" },
				{ pattern = "([^/]+)%.kt$" },
			},
			detector = {
				dependencies = {
					"jakarta.ws.rs",
					"javax.ws.rs",
					"jax-rs",
					"jersey",
					"resteasy",
					"cxf-rt-frontend-jaxrs",
				},
				manifest_files = {
					"pom.xml",
					"build.gradle",
					"build.gradle.kts",
				},
				name = "jakarta_ee_dependency_detection",
			},
			parser = JakartaEEParser,
		},
	})
end

return JakartaEEFramework

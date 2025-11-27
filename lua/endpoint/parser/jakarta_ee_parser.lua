local Parser = require("endpoint.core.Parser")
local class = require("endpoint.lib.middleclass")

---@class endpoint.JakartaEEParser
local JakartaEEParser = class("JakartaEEParser", Parser)

-- ========================================
-- PUBLIC METHODS
-- ========================================

---Creates a new JakartaEEParser instance
function JakartaEEParser:initialize()
	Parser.initialize(self, {
		parser_name = "jakarta_ee_parser",
		framework_name = "jakarta_ee",
		language = "java",
	})
end

---Extracts base path from JAX-RS resource file
function JakartaEEParser:extract_base_path(file_path, line_number)
	local lines = self:_read_file_lines(file_path, line_number)
	if not lines then
		return ""
	end

	return self:_find_class_level_path(lines, line_number)
end

---Extracts endpoint path from JAX-RS annotation content
function JakartaEEParser:extract_endpoint_path(content)
	-- Handle multiline patterns by normalizing whitespace
	local normalized_content = content:gsub("%s+", " "):gsub("[\r\n]+", " ")

	-- @Path("/users") or @Path("users")
	local path = normalized_content:match("@Path%s*%(%s*[\"']([^\"']+)[\"']")
	if path then
		-- Ensure path starts with /
		if not path:match("^/") then
			path = "/" .. path
		end
		return path
	end

	-- Method-level annotations without @Path default to root
	if self:_has_http_method_annotation(normalized_content) then
		return "/"
	end

	return nil
end

---Extracts HTTP method from JAX-RS annotation content
function JakartaEEParser:extract_method(content)
	-- Handle multiline patterns by normalizing whitespace
	local normalized_content = content:gsub("%s+", " "):gsub("[\r\n]+", " ")

	-- Check for specific HTTP method annotations
	if normalized_content:match("@GET") then
		return "GET"
	elseif normalized_content:match("@POST") then
		return "POST"
	elseif normalized_content:match("@PUT") then
		return "PUT"
	elseif normalized_content:match("@DELETE") then
		return "DELETE"
	elseif normalized_content:match("@PATCH") then
		return "PATCH"
	elseif normalized_content:match("@HEAD") then
		return "HEAD"
	elseif normalized_content:match("@OPTIONS") then
		return "OPTIONS"
	end

	return nil
end

---Validates if content contains JAX-RS annotations
function JakartaEEParser:is_content_valid_for_parsing(content)
	if not Parser.is_content_valid_for_parsing(self, content) then
		return false
	end

	-- Skip comments (lines starting with //)
	if content:match("^%s*//") then
		return false
	end

	-- Check if content contains JAX-RS HTTP method annotations
	return self:_has_http_method_annotation(content)
end

---Override parse_content to handle JAX-RS annotations with @Path on separate line
function JakartaEEParser:parse_content(content, file_path, line_number, column)
	if not self:is_content_valid_for_parsing(content) then
		return nil
	end

	-- Try to get extended content if this looks incomplete
	local extended_content = content
	local end_line = nil
	local path_line_number = line_number

	-- Look for @Path on this line or nearby lines
	local path_content, path_line = self:_find_path_annotation(file_path, line_number)
	if path_content then
		extended_content = path_content .. " " .. content
		if path_line and path_line < line_number then
			path_line_number = path_line
		end
	end

	-- Extract method and path
	local method = self:extract_method(extended_content)
	if not method then
		return nil
	end

	local base_path = self:extract_base_path(file_path, line_number)
	local endpoint_path = self:extract_endpoint_path(extended_content)

	-- If no explicit @Path on method, use root
	if not endpoint_path then
		endpoint_path = "/"
	end

	local full_path = self:combine_paths(base_path, endpoint_path)

	local result = {
		method = method:upper(),
		endpoint_path = full_path,
		file_path = file_path,
		line_number = line_number,
		column = column,
		display_value = method:upper() .. " " .. full_path,
		confidence = self:get_parsing_confidence(extended_content),
		tags = { "java", "jakarta_ee", "jax_rs" },
		metadata = self:create_metadata("endpoint", {
			base_path = base_path,
			raw_endpoint_path = endpoint_path,
		}, extended_content),
	}

	if end_line then
		result.end_line_number = end_line
	end

	return result
end

---Gets parsing confidence for JAX-RS annotations
function JakartaEEParser:get_parsing_confidence(content)
	if not content or content == "" then
		return 0.0
	end

	local base_confidence = 0.8
	local confidence_boost = 0

	-- Boost for having both HTTP method and @Path
	if self:_has_http_method_annotation(content) and content:match("@Path") then
		confidence_boost = confidence_boost + 0.15
	end

	-- Boost for well-formed paths
	local path = self:extract_endpoint_path(content)
	if path and path:match("^/") then
		confidence_boost = confidence_boost + 0.05
	end

	return math.min(base_confidence + confidence_boost, 1.0)
end

-- ========================================
-- PRIVATE METHODS
-- ========================================

---Checks if content has a JAX-RS HTTP method annotation
function JakartaEEParser:_has_http_method_annotation(content)
	return content:match("@GET")
		or content:match("@POST")
		or content:match("@PUT")
		or content:match("@DELETE")
		or content:match("@PATCH")
		or content:match("@HEAD")
		or content:match("@OPTIONS")
end

---Reads file lines up to specified line number
function JakartaEEParser:_read_file_lines(file_path, line_number)
	local file = io.open(file_path, "r")
	if not file then
		return nil
	end

	local lines = {}
	local current_line = 1
	for line in file:lines() do
		table.insert(lines, line)
		if current_line >= line_number then
			break
		end
		current_line = current_line + 1
	end
	file:close()

	return lines
end

---Finds class-level @Path annotation
function JakartaEEParser:_find_class_level_path(lines, line_number)
	-- Look backwards for class-level @Path
	for i = math.min(line_number, #lines), 1, -1 do
		local line = lines[i]

		-- Check if this is a class declaration
		if line:match("class%s+%w+") then
			-- Look for @Path on this class or preceding lines
			for j = math.max(1, i - 5), i do
				local annotation_line = lines[j]
				local base_path = self:_extract_path_value(annotation_line)
				if base_path then
					return base_path
				end
			end
			break
		end
	end

	return ""
end

---Extracts path value from @Path annotation
function JakartaEEParser:_extract_path_value(annotation_line)
	local path = annotation_line:match("@Path%s*%(%s*[\"']([^\"']+)[\"']")
	if path then
		-- Ensure path starts with /
		if not path:match("^/") then
			path = "/" .. path
		end
		return path
	end
	return nil
end

---Finds @Path annotation near the given line (method-level, not class-level)
function JakartaEEParser:_find_path_annotation(file_path, line_number)
	if not file_path then
		return nil, nil
	end

	local file = io.open(file_path, "r")
	if not file then
		return nil, nil
	end

	local lines = {}
	for line in file:lines() do
		table.insert(lines, line)
	end
	file:close()

	-- In JAX-RS, @Path can appear:
	--
	-- Before the REST method (@GET, @POST, etc) annotation
	-- After the REST method annotation
	-- On the same line as the REST method annotation
	--

	-- First check the current line itself
	if line_number <= #lines then
		local current_line = lines[line_number]
		if current_line:match("@Path") then
			return current_line, line_number
		end
	end

	-- Look a few lines AFTER for @Path annotation (JAX-RS style: @GET then @Path)
	for i = line_number + 1, math.min(line_number + 10, #lines) do
		local line = lines[i]
		if line:match("@Path") then
			-- Make sure we haven't hit a method declaration (public/private/protected)
			-- which would mean the @Path belongs to a different method
			local hit_method = false
			for j = line_number + 1, i - 1 do
				if
					lines[j]:match("^%s*public%s+")
					or lines[j]:match("^%s*private%s+")
					or lines[j]:match("^%s*protected%s+")
				then
					hit_method = true
					break
				end
			end
			if not hit_method then
				return line, i
			end
		end
		-- Stop if we hit a method declaration
		if line:match("^%s*public%s+") or line:match("^%s*private%s+") or line:match("^%s*protected%s+") then
			break
		end
	end

	-- Look a few lines BEFORE for @Path annotation
	for i = line_number - 1, math.max(1, line_number - 10), -1 do
		local line = lines[i]
		-- Stop if we hit another HTTP method annotation (means @Path would belong to previous method)
		-- This check MUST come before checking for @Path
		if self:_has_http_method_annotation(line) then
			break
		end
		-- Stop if we hit a method declaration (means we've gone past method annotations)
		if line:match("^%s*public%s+") or line:match("^%s*private%s+") or line:match("^%s*protected%s+") then
			break
		end
		if line:match("@Path") then
			-- Make sure this isn't a class-level @Path (check if class declaration is nearby)
			local is_class_level = false
			for j = i, math.min(i + 10, #lines) do
				if lines[j]:match("class%s+%w+") then
					is_class_level = true
					break
				end
			end
			if not is_class_level then
				return line, i
			end
		end
	end

	return nil, nil
end

return JakartaEEParser

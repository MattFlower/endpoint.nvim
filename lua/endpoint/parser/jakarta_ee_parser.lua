local Parser = require("endpoint.core.Parser")
local class = require("endpoint.lib.middleclass")

---@class endpoint.JakartaEEParser
local JakartaEEParser = class("JakartaEEParser", Parser)

-- HTTP method annotations lookup table
local HTTP_METHODS = {
	GET = true,
	POST = true,
	PUT = true,
	DELETE = true,
	PATCH = true,
	HEAD = true,
	OPTIONS = true,
}

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
	-- Cache for parsed file tree
	self._cached_file_path = nil
	self._cached_tree = nil
	self._cached_source = nil
end

---Extracts base path from JAX-RS resource file using TreeSitter
function JakartaEEParser:extract_base_path(file_path, line_number)
	local tree, source = self:_get_file_tree(file_path)
	if not tree or not source then
		return ""
	end

	local method_node = self:_find_method_at_line(tree, source, line_number)
	if not method_node then
		method_node = self:_find_method_near_line(tree, source, line_number)
	end
	if not method_node then
		return ""
	end

	local class_node = self:_find_containing_class(method_node)
	if not class_node then
		return ""
	end

	local path = self:_get_class_path_annotation(class_node, source)
	if path then
		if not path:match("^/") then
			path = "/" .. path
		end
		return path
	end

	return ""
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

---Override parse_content to handle JAX-RS annotations using TreeSitter
---Requires the file to exist and be parseable by TreeSitter
function JakartaEEParser:parse_content(content, file_path, line_number, column)
	if not self:is_content_valid_for_parsing(content) then
		return nil
	end

	-- Parse file with TreeSitter
	local tree, source = self:_get_file_tree(file_path)
	if not tree or not source then
		return nil
	end

	return self:_parse_with_treesitter(tree, source, content, file_path, line_number, column)
end

---Parses using TreeSitter AST
function JakartaEEParser:_parse_with_treesitter(tree, source, _, file_path, line_number, column)
	-- Find method at or near the line
	local method_node = self:_find_method_at_line(tree, source, line_number)
	if not method_node then
		method_node = self:_find_method_near_line(tree, source, line_number)
	end
	if not method_node then
		return nil
	end

	-- Get method annotations
	local annotations = self:_get_method_annotations(method_node, source)

	-- Find HTTP method from annotations
	local http_method = nil
	for _, ann in ipairs(annotations) do
		if self:_is_http_method_annotation(ann.name) then
			http_method = ann.name:upper()
			break
		end
	end

	if not http_method then
		return nil
	end

	-- Find method-level @Path
	local method_path = nil
	for _, ann in ipairs(annotations) do
		if ann.name == "Path" and ann.value then
			method_path = ann.value
			if not method_path:match("^/") then
				method_path = "/" .. method_path
			end
			break
		end
	end

	-- Default to root if no method-level path
	if not method_path then
		method_path = "/"
	end

	-- Get class-level @Path
	local class_node = self:_find_containing_class(method_node)
	local base_path = ""
	if class_node then
		local class_path = self:_get_class_path_annotation(class_node, source)
		if class_path then
			if not class_path:match("^/") then
				class_path = "/" .. class_path
			end
			base_path = class_path
		end
	end

	-- Combine paths
	local full_path = self:combine_paths(base_path, method_path)

	-- Build extended content for metadata
	local extended_content = self:_get_annotations_text(annotations, source)

	return {
		method = http_method,
		endpoint_path = full_path,
		file_path = file_path,
		line_number = line_number,
		column = column,
		display_value = http_method .. " " .. full_path,
		confidence = self:get_parsing_confidence(extended_content),
		tags = { "java", "jakarta_ee", "jax_rs" },
		metadata = self:create_metadata("endpoint", {
			base_path = base_path,
			raw_endpoint_path = method_path,
		}, extended_content),
	}
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
-- PRIVATE METHODS - TreeSitter Helpers
-- ========================================

---Parses file with TreeSitter and caches the result
---@param file_path string
---@return table|nil tree, string|nil source
function JakartaEEParser:_get_file_tree(file_path)
	if not file_path then
		return nil, nil
	end

	-- Return cached result if same file
	if self._cached_file_path == file_path and self._cached_tree then
		return self._cached_tree, self._cached_source
	end

	-- Read file content
	local file = io.open(file_path, "r")
	if not file then
		return nil, nil
	end
	local source = file:read("*all")
	file:close()

	-- Parse with TreeSitter
	local ok, parser = pcall(vim.treesitter.get_string_parser, source, "java")
	if not ok or not parser then
		return nil, nil
	end

	local trees = parser:parse()
	if not trees or #trees == 0 then
		return nil, nil
	end

	local tree = trees[1]

	-- Cache the result
	self._cached_file_path = file_path
	self._cached_tree = tree
	self._cached_source = source

	return tree, source
end

---Finds a method declaration that contains the given line
---@param tree table TreeSitter tree
---@param source string Source code
---@param line_number number 1-indexed line number
---@return table|nil method_node
function JakartaEEParser:_find_method_at_line(tree, source, line_number)
	local root = tree:root()
	local ts_line = line_number - 1 -- TreeSitter uses 0-indexed

	-- Find node at the given line
	local node = root:named_descendant_for_range(ts_line, 0, ts_line, 1000)
	if not node then
		return nil
	end

	-- Walk up to find method_declaration
	while node do
		if node:type() == "method_declaration" then
			return node
		end
		node = node:parent()
	end

	return nil
end

---Finds a method whose annotations include the given line
---@param tree table TreeSitter tree
---@param source string Source code
---@param line_number number 1-indexed line number
---@return table|nil method_node
function JakartaEEParser:_find_method_near_line(tree, source, line_number)
	local root = tree:root()
	local ts_line = line_number - 1

	-- Iterate through all method declarations
	for node in root:iter_children() do
		self:_find_methods_recursive(node, ts_line, source, function(method_node)
			return method_node
		end)
	end

	-- Use query to find all methods
	local query_str = "(method_declaration) @method"
	local ok, query = pcall(vim.treesitter.query.parse, "java", query_str)
	if not ok or not query then
		return nil
	end

	for _, node in query:iter_captures(root, source) do
		local start_row, _, end_row, _ = node:range()

		-- Check if line is within the method's range (including annotations)
		if ts_line >= start_row and ts_line <= end_row then
			-- Check if this method has JAX-RS annotations
			local annotations = self:_get_method_annotations(node, source)
			for _, ann in ipairs(annotations) do
				if self:_is_http_method_annotation(ann.name) then
					return node
				end
			end
		end
	end

	return nil
end

---Recursively finds methods (helper for _find_method_near_line)
function JakartaEEParser:_find_methods_recursive(node, ts_line, source, callback)
	if node:type() == "method_declaration" then
		local start_row, _, end_row, _ = node:range()
		if ts_line >= start_row and ts_line <= end_row then
			local annotations = self:_get_method_annotations(node, source)
			for _, ann in ipairs(annotations) do
				if self:_is_http_method_annotation(ann.name) then
					return callback(node)
				end
			end
		end
	end

	for child in node:iter_children() do
		local result = self:_find_methods_recursive(child, ts_line, source, callback)
		if result then
			return result
		end
	end

	return nil
end

---Gets all annotations from a method declaration
---@param method_node table TreeSitter method_declaration node
---@param source string Source code
---@return table annotations Array of {name, value, node, start_row}
function JakartaEEParser:_get_method_annotations(method_node, source)
	local annotations = {}

	-- Find modifiers node (contains annotations)
	for child in method_node:iter_children() do
		if child:type() == "modifiers" then
			for mod_child in child:iter_children() do
				local annotation_data = self:_parse_annotation_node(mod_child, source)
				if annotation_data then
					table.insert(annotations, annotation_data)
				end
			end
			break -- modifiers is always first
		end
	end

	return annotations
end

---Parses a single annotation node
---@param node table TreeSitter annotation node
---@param source string Source code
---@return table|nil {name, value, node, start_row}
function JakartaEEParser:_parse_annotation_node(node, source)
	if node:type() ~= "marker_annotation" and node:type() ~= "annotation" then
		return nil
	end

	local name_node = node:field("name")[1]
	if not name_node then
		return nil
	end

	local name = vim.treesitter.get_node_text(name_node, source)
	local start_row = node:start()

	local annotation_data = {
		name = name,
		node = node,
		start_row = start_row,
		value = nil,
	}

	-- Extract value for @Path annotations
	if name == "Path" then
		local args = node:field("arguments")[1]
		if args then
			annotation_data.value = self:_extract_annotation_value(args, source)
		end
	end

	return annotation_data
end

---Extracts string value from annotation arguments
---Handles simple string literals, binary expressions (concatenation), and element_value_pairs
---@param args_node table TreeSitter annotation_argument_list node
---@param source string Source code
---@return string|nil
function JakartaEEParser:_extract_annotation_value(args_node, source)
	for child in args_node:iter_children() do
		-- Handle @Path("/value") - direct string literal
		if child:type() == "string_literal" then
			local text = vim.treesitter.get_node_text(child, source)
			-- Remove quotes (handles both " and ')
			return text:match("^[\"'](.+)[\"']$")
		end

		-- Handle @Path(API_BASE + "/users") - binary expression (concatenation)
		if child:type() == "binary_expression" then
			return self:_extract_string_from_expression(child, source)
		end

		-- Handle @Path(value = "/value") or @Path(value = API_BASE + "/users")
		if child:type() == "element_value_pair" then
			local key_node = child:field("key")[1]
			local value_node = child:field("value")[1]
			if key_node and value_node then
				local key = vim.treesitter.get_node_text(key_node, source)
				if key == "value" then
					if value_node:type() == "string_literal" then
						local text = vim.treesitter.get_node_text(value_node, source)
						return text:match("^[\"'](.+)[\"']$")
					elseif value_node:type() == "binary_expression" then
						return self:_extract_string_from_expression(value_node, source)
					end
				end
			end
		end
	end

	return nil
end

---Recursively extracts string literals from a binary expression (concatenation)
---For expressions like API_BASE + "/users", extracts only the string literal parts
---@param expr_node table TreeSitter binary_expression node
---@param source string Source code
---@return string|nil
function JakartaEEParser:_extract_string_from_expression(expr_node, source)
	local parts = {}
	self:_collect_string_literals(expr_node, source, parts)

	if #parts == 0 then
		return nil
	end

	return table.concat(parts, "")
end

---Recursively collects string literals from an expression tree
---@param node table TreeSitter node
---@param source string Source code
---@param parts table Array to collect string parts into
function JakartaEEParser:_collect_string_literals(node, source, parts)
	local node_type = node:type()

	if node_type == "string_literal" then
		local text = vim.treesitter.get_node_text(node, source)
		-- Remove quotes
		local content = text:match("^[\"'](.+)[\"']$")
		if content then
			table.insert(parts, content)
		end
	elseif node_type == "binary_expression" then
		-- Recursively process left and right operands
		local left = node:field("left")[1]
		local right = node:field("right")[1]
		if left then
			self:_collect_string_literals(left, source, parts)
		end
		if right then
			self:_collect_string_literals(right, source, parts)
		end
	elseif node_type == "parenthesized_expression" then
		-- Handle (expr) by processing the inner expression
		for child in node:iter_children() do
			if child:named() then
				self:_collect_string_literals(child, source, parts)
			end
		end
	end
	-- For identifiers (like API_BASE), field_access, etc., we skip them
	-- as we can only extract the literal string parts at parse time
end

---Finds the containing class for a method
---@param method_node table TreeSitter method_declaration node
---@return table|nil class_node
function JakartaEEParser:_find_containing_class(method_node)
	local node = method_node:parent()
	while node do
		if node:type() == "class_declaration" then
			return node
		end
		-- Also check class_body -> class_declaration
		if node:type() == "class_body" then
			local parent = node:parent()
			if parent and parent:type() == "class_declaration" then
				return parent
			end
		end
		node = node:parent()
	end
	return nil
end

---Gets @Path annotation value from a class declaration
---@param class_node table TreeSitter class_declaration node
---@param source string Source code
---@return string|nil
function JakartaEEParser:_get_class_path_annotation(class_node, source)
	for child in class_node:iter_children() do
		if child:type() == "modifiers" then
			for mod_child in child:iter_children() do
				if mod_child:type() == "annotation" then
					local name_node = mod_child:field("name")[1]
					if name_node then
						local name = vim.treesitter.get_node_text(name_node, source)
						if name == "Path" then
							local args = mod_child:field("arguments")[1]
							if args then
								return self:_extract_annotation_value(args, source)
							end
						end
					end
				end
			end
			break
		end
	end
	return nil
end

---Checks if annotation name is an HTTP method
---@param name string Annotation name
---@return boolean
function JakartaEEParser:_is_http_method_annotation(name)
	return HTTP_METHODS[name:upper()] or false
end

---Builds text representation of annotations for metadata
---@param annotations table Array of annotation data
---@param source string Source code
---@return string
function JakartaEEParser:_get_annotations_text(annotations, source)
	local parts = {}
	for _, ann in ipairs(annotations) do
		local text = vim.treesitter.get_node_text(ann.node, source)
		table.insert(parts, text)
	end
	return table.concat(parts, " ")
end

---Checks if content has a JAX-RS HTTP method annotation (regex-based for validation)
function JakartaEEParser:_has_http_method_annotation(content)
	return content:match("@GET")
		or content:match("@POST")
		or content:match("@PUT")
		or content:match("@DELETE")
		or content:match("@PATCH")
		or content:match("@HEAD")
		or content:match("@OPTIONS")
end

return JakartaEEParser

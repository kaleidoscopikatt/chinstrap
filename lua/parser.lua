--[[
@name: parser.lua
@desc: Takes in an array of tokens from 'tokenizer.lua', and
processes them into an Abstract Syntax Tree.
]]--

local globals = require("globals")
local out = require("pretty")

local Cursor = {
	new = function(source)
		local newCursor = {
			id = 1,
			source = source,
			
			read = function(self, lookahead)
				if (not lookahead) then lookahead = 0 end
				if (self.id + lookahead) <= #self.source then return self.source[(self.id + lookahead)] end
			end,
			
			setId = function(self, n)
				if n <= #self.source then
					self.id = n
					out.constant_tok = n
					return true
				end
				return false
			end,
			
			progressCursor = function(self)
				return self:setId(self.id + 1)
			end,
			
			regressCursor = function(self)
				return self:setId(self.id - 1)
			end,
			
			eat = function(self)
				local contents = self:read()
				self:progressCursor()
				
				return contents
			end,
			
			expect = function(self, t)
				local contents = self:read().contents
				return contents == t, contents
			end,
			
			test = function(self, t)
				local condition, whatIsItThen = self:expect(t)
				self:progressCursor()
				return condition, whatIsItThen
			end,
			
			liquidate = function(self)
				self.source = nil
				self.id = nil
				setmetatable(self, nil)
				for k in pairs(self) do
					self[k] = nil
				end
			end
		}
		
		setmetatable(newCursor, {
			__add = function(a, b)
				if type(a) == "table" and type(b) == "number" then
					local nextId = a.id + b
					if nextId <= #a.source then a.id = nextId end
				end
				return a
			end,
			
			__eq = function(a, b)
				if type(a) == "table" and type(b) == "number" then
					return a.id == b
				end
				
				return false
			end,
			
			__sub = function(a, b)
				if type(a) == "table" and type(b) == "number" then
					local prevId = a.id - b
					if prevId <= #a.source then a.id = prevId end
				end
				return a
			end
		})
		return newCursor
	end
}

local quickMaths = { "sin", "max", "sample", "pi", "cos", "tan", "sinh", "cosh", "tanh", "dot" }

function Node(class, ...)
	local node = globals.druggedTable({
		class = class or "Root",
		children = { ... },

		push = function(self, child)
			table.insert(self.children, child)
		end,
	})

	return node
end

function IReader(t)
	local i = 0
	local n = #t
	return function()
		i = i + 1
		if i <= n then
			return i, t[i], function(o)
				local j = o + i
				if j <= n then return t[j], j end
			end
		end
	end
end

function TokenReader(cursor)
	local i = cursor.id - 1

	return function()
		i = i + 1
		local result = cursor:setId(i)
		if (result) then
			return i, cursor:read()			
		end
	end
end

function Is(object, value)
	return object.contents == value
end

function RPNtoAST(tokens)
	--print("RPN:", globals.tableToString(tokens))
	local stack = {}

	for i, token in ipairs(tokens) do
		local t = token.contents or token
		--print(i, token.contents, token.type)
		
		if tonumber(t) then
			--print("Pushing:", t)
			table.insert(stack, Node("Number", token))
		elseif t:match("^[%a_]+$") then -- RegEx sucks man
			--print("Pushing:", t)
			table.insert(stack, Node("Variable", token))
		elseif t == "+" or t == "-" or t == "*" or t == "/" or t == "^" then
			local right = table.remove(stack)
			local left = table.remove(stack)

			table.insert(stack, Node("Operator", token, left, right))
		else
			error("Error code 1: Unknown token [" .. tostring(t).. "]")
		end
	end

	if #stack ~= 1 then
		print("BAD RPN:", globals.tableToString(tokens))
		print("STACK:", globals.tableToString(stack))
	end
	assert(#stack == 1, "Error code 2: Malformed RPN Expression")
	return stack[1]
end

function ParseLogic(tokens)
	local outputStack = {}
	local operatorStack = {}
	
	local precedence = {
		["^"] = 4,
		["*"] = 3,
		["/"] = 3,
		["+"] = 2,
		["-"] = 2,
	}
	
	local rightHanded = {
		["^"] = true
	}
	
	for index, token, lookAhead in IReader(tokens) do
		local contents = token.contents

		if tonumber(contents) ~= nil then
			table.insert(outputStack, token)
		elseif lookAhead(1) and lookAhead(1).contents == "(" and token.type == 1 then
			table.insert(operatorStack, token)
		elseif token.type == 2 then
			local o2 = operatorStack[#operatorStack]
			while o2 and o2.contents ~= "(" and (precedence[o2.contents] > precedence[contents] or (precedence[o2.contents] == precedence[contents] and not rightHanded[contents])) do
				table.remove(operatorStack, #operatorStack)
				table.insert(outputStack, o2)
				o2 = operatorStack[#operatorStack]
			end
			table.insert(operatorStack, token)
		elseif contents == ',' then
			local o2 = operatorStack[#operatorStack]
			while (o2 and o2.contents ~= "(") do
				table.remove(operatorStack, #operatorStack)
				table.insert(outputStack, o2)
				o2 = operatorStack[#operatorStack]
			end
		elseif contents == '(' then
			table.insert(operatorStack, token)
		elseif contents == ')' then
			local o2 = operatorStack[#operatorStack]
			while (o2 and o2.contents ~= "(") do
				assert(out.assert(#operatorStack ~= 0, out.errorBlock("parser", 22, "There are mismatched parentheses in the expression! - (ln:tok) may be inacurrate!")))
				table.remove(operatorStack, #operatorStack)
				table.insert(outputStack, o2)
				o2 = operatorStack[#operatorStack]
			end
			assert(out.assert(o2.contents == '(', out.errorBlock("parser", 22, "There are mismatched parentheses in the expression! - (ln:tok) may be inacurrate!")))
			table.remove(operatorStack, #operatorStack)
			o2 = operatorStack[#operatorStack]
			if (o2 and o2.type == 1) then
				table.remove(operatorStack, #operatorStack)
				table.insert(outputStack, o2)
			end
		elseif token.type == 1 then
			table.insert(outputStack, token)
		else
			out.errorPrint(out.errorBlock("parser", 7, "Token ".. globals.tableToString(token).. " couldn't be identified in the expression!"))
			return -1
		end
	end

	while #operatorStack > 0 do
		local operator = operatorStack[#operatorStack]
		assert(out.assert(operator.contents ~= "(", out.errorBlock("parser", 22, "There are mismatched parentheses in the expression! - (ln:tok) may be inacurrate!")))
		table.remove(operatorStack, #operatorStack)
		table.insert(outputStack, operator)
	end
	
	return outputStack
end

function ParseNumber(cursor)
	local token = cursor:read()
	--print(token.contents)

	local contents = globals.druggedTable({})
	local depth = 0
	
	for i, tok in TokenReader(cursor) do
		if tok.contents == ';' then
			break
		end

		if tok.contents == '(' then
			depth = depth + 1
		end

		if tok.contents == ')' then
			depth = depth - 1
		end

		if tok.contents == ',' and depth == 0 then
			break
		end

		if (globals.tableFind({1, 2, 4, 5}, tok.type)) then
			table.insert(contents, tok)
		else
			break
		end
	end

	local rpnStack = ParseLogic(contents)

	if (rpnStack == -1) then
		return -1
	end

	local ASTNode = RPNtoAST(rpnStack)

	return ASTNode
end

function ParseIdentifier(cursor)
	local token = cursor:read()

	if globals.tableFind(quickMaths, token.contents) then
		return ParseNumber(cursor)
	elseif cursor:read(1) == "(" then
		-- It's a function!
		out.processPrint("parser", "Function found: ".. token)
		return Node("FunctionCall", token, "totallyRealParameters")
	else
		print(tostring(token.type).. " is not of quickMaths")
		return Node("Identifier", token)
	end

	return false
end

function ParseVariableType(cursor)
	local token = cursor:read()
	out.processPrint("parser", "Attempting to identify object type of ".. token.contents.. "!")

	if token.type == 1 then -- Identifier
		local parsed = ParseIdentifier(cursor)
		if not parsed then
			out.errorPrint(out.errorBlock("parser", 3, "Identifier cannot be parsed!"))
		end

		return parsed
	end
	if token.type == 3 then -- String
		return Node("String", token)
	end
	if token.type == 4 then -- Number/Logic
		return ParseNumber(cursor)
	end
	if token.type == 5 then -- Not all seperators are good!
		if token.contents == '(' then -- Number/Logic
			return ParseNumber(cursor)
		end
		if token.contents == '{' then -- Table
			return Node("Table", token)
		end
	end

	return false
end

function ParseAssignment(tokenList)
	local cursor = Cursor.new(tokenList)
	local lhs = cursor:eat()
	if lhs.type ~= 1 then
		return false
	end
	if not cursor:test("=") then
		return false
	end
	local rhs_node = ParseVariableType(cursor)
	if not rhs_node then
		out.errorPrint(out.errorBlock("parser", 22, "Expected object of any type, got ".. cursor:read().. "!"))
		return -1
	end

	if rhs_node == -1 then
		out.errorPrint(out.errorBlock("parser", 22, "Expected object of any type, but type failed to resolve itself"))
		return -1
	end

	cursor:progressCursor()

	if not cursor:expect(";") then
		out.errorPrint(out.errorBlock("parser", 8, "Expected ';', got ".. cursor:read().. "!"))
		return -1
	end
	cursor:progressCursor()

	local lhs_node = Node("Identifier", lhs)
	local node = Node("Assign", lhs_node, rhs_node)
	return node
end

function ParseProperty(tokenList)
	local cursor = Cursor.new(tokenList)
	local firstCheck = cursor:test("@property")
	if not firstCheck then
		return false
	end

	local lBracketTest, lBracketGot = cursor:test("(")
	if not lBracketTest then
		out.errorPrint(out.errorBlock("parser", 15, "Expected '(', got '".. lBracketGot.. "'!"))
		return -1
	end

	local lhs = cursor:eat()

	local commaTest, commaGot = cursor:test(",")
	if not commaTest then
		out.errorPrint(out.errorBlock("parser", 10, "Expected ',', got '".. commaGot.. "'!"))
		return -1
	end
	if lhs.type ~= 3 then
		return -1
	end

	local rhs = cursor:eat()
	if not rhs.type == 1 then
		return -1
	end
	if not globals.tableFind({"2D", "3D"}, rhs.contents) then
		out.errorPrint(out.errorBlock("parser", 6, "Expected '2D' or '3D', got '".. rhs.contents.. "'!"))
		return -1
	end
	local rBracketTest, rBracketGot = cursor:test(")")
	if not rBracketTest then
		out.errorPrint(out.errorBlock("parser", 16, "Expected ')', got '".. rBracketGot.. "'!"))
		return -1
	end
	local semiColonTest, semiColonGot = cursor:test(";")
	if not semiColonTest then
		out.errorPrint(out.errorBlock("parser", 8, "Expected ';', got '".. semiColonGot.. "'!"))
		return -1
	end

	return Node("Property", Node("String", lhs), Node("Identifier", rhs))
end

function ParseFunctionCall(tokenList)
	local cursor = Cursor.new(tokenList)

	local functionName = cursor:eat()
	if (functionName.type ~= 1) then
		return false
	end

	local lBracketTest = cursor:test("(")
	if not lBracketTest then
		return false
	end

	-- From here, we assume 'identifier(' is trying to call a function.
	local params = {}
	for i, tok in TokenReader(cursor) do
		if tok.contents ~= ',' then
			if tok.contents == ')' then
				break
			end
			table.insert(params, ParseVariableType(cursor))
		end
	end

	local rBracketTest, rBracketGot = cursor:test(')')
	if not rBracketTest then
		out.errorPrint(out.errorBlock("parser", 16, "Expected ')', got '".. rBracketGot.. "'!"))
		return -1
	end

	local semiColonTest, semiColonGot = cursor:test(";")
	if not semiColonTest then
		out.errorPrint(out.errorBlock("parser", 8, "Expected ';', got '".. semiColonGot.. "'!"))
		return -1
	end

	return Node("FunctionCall", table.unpack(params))
end

function ParseTokens(tokenList)
	print("") -- cool break in printing
	local motherStack = {}
	local stack = {}
	
	for i, token, lookAhead in IReader(tokenList) do
		if token.type ~= 7 and token.type ~= 6 then
			table.insert(stack, token)
			if Is(token, ";") then
				table.insert(motherStack, stack)
				stack = {}
			end
		end
	end

	local function isValidNode(n)
		if n ~= false then
			if (n == -1) then
				return false
			end

			return true
		end
	end

	out.constant_line = 1
	out.constant_tok = 1
	
	for i, line in ipairs(motherStack) do
		local assignmentNode = ParseAssignment(line)
		local propertyNode = ParseProperty(line)
		local callNode = ParseFunctionCall(line)

		local breakup = false -- Because goto didn't want to work, for whatever reason...

		if isValidNode(assignmentNode) then
			breakup = true
			motherStack[i] = assignmentNode
		end

		if isValidNode(propertyNode) then
			breakup = true
			motherStack[i] = propertyNode
		end

		if (isValidNode(callNode)) then
			breakup = true
			motherStack[i] = callNode
		end

		if (not breakup) then
			out.errorPrint(out.errorBlock("parser", 27, "Statement is not assignable or declarable. This may be due to encountering a previous error."))
			return {}
		else
			out.constant_line = out.constant_line + 1
		end
	end

	print(out.colString("[PARSER]:", "blue").. " " .. out.colString("AST Generation Done!", "green_bg", "bold"))
	return motherStack
end

-- print(globals.tableToString(ParseTokens({
--   [1] =     {
--       contents = "@property",
--       type = 1,
--     },
--   [2] =     {
--       contents = "(",
--       type = 5,
--     },
--   [3] =     {
--       contents = "\"_MainTex\"",
--       type = 3,
--     },
--   [4] =     {
--       contents = ",",
--       type = 5,
--     },
--   [5] =     {
--       contents = "2D",
--       type = 1,
--     },
--   [6] =     {
--       contents = ")",
--       type = 5,
--     },
--   [7] =     {
--       contents = ";",
--       type = 5,
--     },
--   [8] =     {
--       contents = "",
--       type = 7,
--     },
-- })))
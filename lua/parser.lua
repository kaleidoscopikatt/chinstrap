--[[
@name: parser.lua
@desc: Takes in an array of tokens from 'tokenizer.lua', and
processes them into an Abstract Syntax Tree.
]]--

local globals = require("..\\lua\\globals")
local out = require("..\\lua\\pretty")

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
	cursor:regressCursor()
	return function()
		local result = cursor:progressCursor()
		if (result) then
			return cursor.id, cursor:read()			
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

------------------------------
---   EXPRESSION PARSING    --
------------------------------
--- Testing out trying to do Recursive Descent parsing...

function ParsePrimary(cursor)
    local tok = cursor:read()
    if not tok then error("EOF in primary") end

    -- number
    if tok.type == globals.enum_TokenTypes.Enum("LiteralNumber") then
        local t = cursor:eat()
        return Node("Number", t)
    end

	-- string
	if tok.type == 3 then
	 	local t = cursor:eat()
		return Node("String", t)
	end

    -- identifier or function call
	
	--out.processPrint("parser", "tok type: ".. tostring(tok.type))
	--out.processPrint("parser", "tok contents: ".. tostring(tok.contents))
    if tok.type == globals.enum_TokenTypes.Enum("Identifier") then
        local name = cursor:eat()
        local isParen = cursor:test("(")
        if isParen then
			local isNoParam = cursor:expect(")")
			local params = {}

			if not isNoParam then
				for i, tok in TokenReader(cursor) do
					if tok.contents == ')' then
						break
					end

					table.insert(params, ParseExpression(cursor))
				end
			end

            return Node("FunctionCall", name, table.unpack(params))
        end

        return Node("Variable", name)
    end

    -- parenthesized
    if tok.contents == "(" then
        cursor:progressCursor()
        local expr = ParseExpression(cursor)
        if not cursor:read() or cursor:read().contents ~= ")" then
            out.errorPrint(out.errorBlock("parser", 16, "Expected ')', got ".. tostring(cursor:read().contents)))
        end
        cursor:progressCursor()
        return expr
    end

	if tok.contents == "," then
		return Node("PracticalWhitespace", tok)
	end

    out.errorPrint(out.errorBlock("parser", 0, "Invalid Primary: ".. tostring(cursor:read().contents)))
end

function ParseFactor(cursor)
    local left = ParsePrimary(cursor)
    local nextTok = cursor:read()
    if nextTok and nextTok.contents == "^" then
        cursor:progressCursor()
        local right = ParseFactor(cursor)
        return Node("Operator", nextTok, left, right)
    end
    return left
end

function ParseTerm(cursor)
    local node = ParseFactor(cursor)
    while true do
        local tok = cursor:read()
        if not tok then break end
        if tok.contents == "*" or tok.contents == "/" then
            cursor:progressCursor()
            node = Node("Operator", tok, node, ParseFactor(cursor))
        else
            break
        end
    end
    return node
end

function ParseExpression(cursor)
    local node = ParseTerm(cursor)
    while true do
        local tok = cursor:read()
        if not tok then break end
        if tok.contents == "+" or tok.contents == "-" then
            cursor:progressCursor()
            node = Node("Operator", tok, node, ParseTerm(cursor))
        else
            break
        end
    end
    return node
end

function ParseIdentifier(cursor)
	local token = cursor:eat()

	if globals.tableFind(quickMaths, token.contents) then
		return ParseExpression(cursor)
	elseif cursor:read().contents == "(" then
		-- It's a function!
		cursor:regressCursor()
		out.processPrint("parser", "Function found: ".. token.contents)
		return ParsePrimary(cursor)
	else
		print(tostring(cursor:read().contents).. " is not of quickMaths")
		return Node("Identifier", token)
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
	local rhs_node = ParseExpression(cursor)
	if not rhs_node then
		out.errorPrint(out.errorBlock("parser", 22, "Expected object of any type, got '".. cursor:read().contents.. "'!"))
		return -1
	end

	if rhs_node == -1 then
		out.errorPrint(out.errorBlock("parser", 22, "Expected object of any type, but type failed to resolve itself"))
		return -1
	end

	cursor:progressCursor()

	if not cursor:expect(";") then
		out.errorPrint(out.errorBlock("parser", 8, "Expected ';', got '".. cursor:read().contents.. "'!"))
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
		--local callNode = ParseFunctionCall(line)

		local breakup = false -- Because goto didn't want to work, for whatever reason...

		if isValidNode(assignmentNode) then
			breakup = true
			motherStack[i] = assignmentNode
		end

		if isValidNode(propertyNode) then
			breakup = true
			motherStack[i] = propertyNode
		end

		--if (isValidNode(callNode)) then
		--	breakup = true
		--	motherStack[i] = callNode
		--end

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

ParseTokens({
  [1] =     {
      contents = "sum",
      type = 1,
    },
  [2] =     {
      contents = "=",
      type = 2,
    },
  [3] =     {
      contents = "10",
      type = 4,
    },
  [4] =     {
      contents = ";",
      type = 5,
    },
  [5] =     {
      contents = "",
      type = 7,
    },
  [6] =     {
      contents = "sum",
      type = 1,
    },
  [7] =     {
      contents = "=",
      type = 2,
    },
  [8] =     {
      contents = "10",
      type = 4,
    },
  [9] =     {
      contents = "+",
      type = 2,
    },
  [10] =     {
      contents = "10",
      type = 4,
    },
  [11] =     {
      contents = ";",
      type = 5,
    },
  [12] =     {
      contents = "",
      type = 7,
    },
  [13] =     {
      contents = "sum",
      type = 1,
    },
  [14] =     {
      contents = "=",
      type = 2,
    },
  [15] =     {
      contents = "(",
      type = 5,
    },
  [16] =     {
      contents = "10",
      type = 4,
    },
  [17] =     {
      contents = "+",
      type = 2,
    },
  [18] =     {
      contents = "10",
      type = 4,
    },
  [19] =     {
      contents = ")",
      type = 5,
    },
  [20] =     {
      contents = ";",
      type = 5,
    },
  [21] =     {
      contents = "",
      type = 7,
    },
  [22] =     {
      contents = "sum",
      type = 1,
    },
  [23] =     {
      contents = "=",
      type = 2,
    },
  [24] =     {
      contents = "(",
      type = 5,
    },
  [25] =     {
      contents = "10",
      type = 4,
    },
  [26] =     {
      contents = "+",
      type = 2,
    },
  [27] =     {
      contents = "10",
      type = 4,
    },
  [28] =     {
      contents = ")",
      type = 5,
    },
  [29] =     {
      contents = "*",
      type = 2,
    },
  [30] =     {
      contents = "12",
      type = 4,
    },
  [31] =     {
      contents = ";",
      type = 5,
    },
  [32] =     {
      contents = "",
      type = 7,
    },
  [33] =     {
      contents = "",
      type = 7,
    },
  [34] =     {
      contents = "my_other_thing",
      type = 1,
    },
  [35] =     {
      contents = "=",
      type = 2,
    },
  [36] =     {
      contents = "hello_world",
      type = 1,
    },
  [37] =     {
      contents = "(",
      type = 5,
    },
  [38] =     {
      contents = ")",
      type = 5,
    },
  [39] =     {
      contents = ";",
      type = 5,
    },
  [40] =     {
      contents = "",
      type = 7,
    },
  [41] =     {
      contents = "",
      type = 7,
    },
  [42] =     {
      contents = "$ This is my comment",
      type = 6,
    },
  [43] =     {
      contents = "",
      type = 7,
    },
  [44] =     {
      contents = "myvar",
      type = 1,
    },
  [45] =     {
      contents = "=",
      type = 2,
    },
  [46] =     {
      contents = "\"Hello, World!\"",
      type = 3,
    },
  [47] =     {
      contents = ";",
      type = 5,
    },
  [48] =     {
      contents = "$ This is also my comment!",
      type = 6,
    },
  [49] =     {
      contents = "",
      type = 7,
    },
})

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
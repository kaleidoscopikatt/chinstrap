--[[
@name: parser.lua
@desc: Takes in an array of tokens from 'tokenizer.lua', and
processes them into an Abstract Syntax Tree.
]]--


-- Imports
local globals = require("...\\lua\\parsetime\\helpers\\globals")
local out = require("...\\lua\\parsetime\\helpers\\pretty")

-- Classes

--[[
	@name: Cursor
	@desc: Class for progressing through tokens in a list.


	@func: new(source)

	@func: read(self, lookahead)
	@func: setId(self, n)

	@func: progressCursor(self) - !CONSUME
	@func: regressCursor(self) - !CONSUME

	@func: eat(self) - CONSUME
	@func: expect(self, t) - !CONSUME
	@func: test(self, t) - CONSUME

	@func: liquidate(self)
]]
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

--[[
	@name: Node(class, ...)
	@desc: Class for defining a Node in the AST.

	@prop: class : @def("Root")
	@prop: children

	@func: push(self, child)
]]
function Node(class, ...)
	local children = { ... }

	local node = globals.druggedTable({
		class = class or "Root",
		children = children,

		push = function(self, child)
			table.insert(self.children, child)
		end,
	})

	return node
end

-- Helpers
local inbuilts = { "sin", "max", "sample", "pi", "cos", "tan", "sinh", "cosh", "tanh", "dot" }

--[[
	@name: Declare(obj, condition, err)
	@desc: Asserts that a condition must be true, returning an object, else giving a provided error.
]]
function Declare(obj, condition, err)
	if condition then
		return obj
	else
		out.errorPrint(err)
		return false
	end
end

--[[
	@name: IReader(t)
	@desc: Use in a for loop to progress through tokens without a cursor...
]]
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

--[[
	@name: TokenReader(cursor)
	@desc: Use in a for loop to progress through tokens, updating a given cursor
		   each time.
]]
function TokenReader(cursor)
	cursor:regressCursor()
	return function()
		local result = cursor:progressCursor()
		if (result) then
			return cursor.id, cursor:read()			
		end
	end
end

--[[
	@name: Is(object, value)
	@desc: Returns whether the object, presumed a Node, has the contents
		   of value.
]]
function Is(object, value)
	return object.contents == value
end

-- Recursive Descent - Functions

--[[
	@name: ParsePrimary(cursor)
]]
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

	-- boolean
	if tok.type == globals.enum_TokenTypes.Enum("Boolean") then
		local t = cursor:eat()
		return Node("Boolean", t)
	end

	-- null
	if tok.type == globals.enum_TokenTypes.Enum("Null") then
		local t = cursor:eat()
		return Node("Null")
	end

    -- identifier or function call
	
    if tok.type == globals.enum_TokenTypes.Enum("Identifier") then
        local name = cursor:eat()
        local isParen = cursor:test("(")
        if isParen then
			local isNoParam = cursor:expect(")")
			local params = globals.druggedTable({})

			if not isNoParam then
				table.insert(params, ParseExpression(cursor))
				while cursor:test(",") do
					table.insert(params, ParseExpression(cursor))
				end
			end

			local rBracketTest, rBracketGot = cursor:expect(")")
			if (not rBracketTest) then
				out.errorPrint(out.errorBlock("parser", 16, "Expected ')', got ".. tostring(rBracketGot.contents)))
				return -1
			end
			cursor:progressCursor()

			local node = nil
			if #params > 0 then
				node = Node("FunctionCall", name, table.unpack(params))
			else
				node = Node("FunctionCall", name)
			end

            return node
		else
			-- NTS: Remember to regress if :test() failed!
			cursor:regressCursor()
        end

        return Node("Variable", name)
	end

    -- parenthesized
    if tok.contents == "(" then
        cursor:progressCursor()
        local expr = ParseExpression(cursor)
		if not expr.class == "FunctionCall" then
			if not cursor:read() or cursor:read().contents ~= ")" then
				out.errorPrint(out.errorBlock("parser", 16, "Expected ')', got ".. tostring(cursor:read().contents)))
			end
		end
        cursor:progressCursor()
        return expr
    end

	if tok.type == 5 then
		cursor:progressCursor()
		return Node("Seperator", tok)
	end

    out.errorPrint(out.errorBlock("parser", 0, "Invalid Primary: ".. tostring(cursor:read().contents)))
end

--[[
	@name: ParseUnary(cursor)
	@desc: Parses Unary expressions, (e.g. ! and -)
]]
function ParseUnary(cursor)
	local tok = cursor:read()
	if tok and (tok.contents == "!" or tok.contents == "-") then
		cursor:eat()
		local operand = ParseUnary(cursor)

		if tok.contents == "-" then
			operand = Declare(operand, (operand.class == "Number" or operand.class == "Operator"), out.errorBlock("parser", 7, "Expected Unary Operand (-) of type Number or Operator, got ".. tostring(operand.class)))
		elseif tok.contents == "!" then
			operand = Declare(operand, (operand.class == "Conditional" or operand.class == "Boolean"), out.errorBlock("parser", 7, "Expected Unary Operand (!) of type Conditional or Boolean, got ".. tostring(operand.class)))
		end

		if not operand then
			return -1
		end

		return Node("UnaryOp", tok, operand)
	else
		return ParsePrimary(cursor)
	end
end

--[[
	@name: ParseFactor(cursor)
	@desc: Parses a^b
]]
function ParseFactor(cursor)
    local left = ParseUnary(cursor)
    local nextTok = cursor:read()
    if nextTok and nextTok.contents == "^" then
        cursor:progressCursor()
        local right = ParseFactor(cursor)
        return Node("Operator", nextTok, left, right)
    end
    return left
end

--[[
	@name: ParseTerm(cursor)
	@desc: Parses multiplication & division
]]
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

--[[
	@name: ParseExpression(cursor)
]]
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

--[[
	@name: ParseIdentifier(cursor)
]]
function ParseIdentifier(cursor)
	local token = cursor:eat()

	if globals.tableFind(inbuilts, token.contents) then
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

-- Syntax Definitions

--[[
	@name: ParseAssignment(tokenList)
]]
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

--[[
	@name: ParseProperty(tokenList)
	@desc: Parses Property blocks (e.g. @Property("MainTex", Tex2D))
]]
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
	if not globals.tableFind({"Tex2D", "Tex3D"}, rhs.contents) then
		out.errorPrint(out.errorBlock("parser", 6, "Expected 'Tex2D' or 'Tex3D', got '".. rhs.contents.. "'!"))
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

-- Main 

--[[
	@name: ParseTokens(tokenList)
	@desc: Called by the middleman.rs via ::passthru after being tokenized,
		   returns the AST of the Chinstrap code.
]]
function ParseTokens(tokenList)
	print("") -- cool break in printing
	local motherStack = globals.druggedTable({})
	local stack = globals.druggedTable({})
	
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

		local breakup = false -- Because goto didn't want to work, for whatever reason...

		if isValidNode(assignmentNode) then
			breakup = true
			motherStack[i] = assignmentNode
		end

		if isValidNode(propertyNode) then
			breakup = true
			motherStack[i] = propertyNode
		end

		local panicCursor = Cursor.new(line)
		local probablyMaybeACall = ParsePrimary(panicCursor)

		if (isValidNode(probablyMaybeACall) and (probablyMaybeACall.class == "FunctionCall")) then
			breakup = true
			motherStack[i] = probablyMaybeACall
		end

		panicCursor:liquidate()
		panicCursor = nil
		collectgarbage()

		if (not breakup) then
			out.errorPrint(out.errorBlock("parser", 2, "Statement is not assignable or declarable. This may be due to encountering a previous error."))
			-- out.errorPrint(out.errorBlock("parser", 27, "Stunted AST: ".. tostring(motherStack)))
			return {}
		else
			out.constant_line = out.constant_line + 1
		end
	end

	print(out.colString("[PARSER]:", "blue").. " " .. out.colString("AST Generation Done!", "green_bg", "bold"))
	return motherStack
end
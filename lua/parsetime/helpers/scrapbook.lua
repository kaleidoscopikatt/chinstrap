--[[
@name: scrapbook.lua
@desc: All old logic and functions, in case they get reused.
]]

-- function ParseLogic(tokens)
-- 	local outputStack = globals.druggedTable({})
-- 	local operatorStack = globals.druggedTable({})
	
-- 	local precedence = globals.druggedTable({
-- 		["^"] = 4,
-- 		["*"] = 3,
-- 		["/"] = 3,
-- 		["+"] = 2,
-- 		["-"] = 2,
-- 	})
	
-- 	local rightHanded = globals.druggedTable({
-- 		["^"] = true
-- 	})
	
-- 	for index, token, lookAhead in IReader(tokens) do
-- 		local contents = token.contents

-- 		if tonumber(contents) ~= nil then
-- 			table.insert(outputStack, token)
-- 		elseif lookAhead(1) and lookAhead(1).contents == "(" and token.type == 1 then
-- 			-- Is it a function token?
-- 			table.insert(operatorStack, token)
-- 		elseif token.type == 2 then
-- 			local o2 = operatorStack[#operatorStack]
-- 			while o2 and o2.contents ~= "(" and (precedence[o2.contents] > precedence[contents] or (precedence[o2.contents] == precedence[contents] and not rightHanded[contents])) do
-- 				table.remove(operatorStack, #operatorStack)
-- 				table.insert(outputStack, o2)
-- 				o2 = operatorStack[#operatorStack]
-- 			end
-- 			table.insert(operatorStack, token)
-- 		elseif contents == ',' then
-- 			local o2 = operatorStack[#operatorStack]
-- 			while (o2 and o2.contents ~= "(") do
-- 				table.remove(operatorStack, #operatorStack)
-- 				table.insert(outputStack, o2)
-- 				o2 = operatorStack[#operatorStack]
-- 			end
-- 		elseif contents == '(' then
-- 			table.insert(operatorStack, token)
-- 		elseif contents == ')' then
-- 			local o2 = operatorStack[#operatorStack]
-- 			while (o2 and o2.contents ~= "(") do
-- 				assert(out.assert(#operatorStack ~= 0, out.errorBlock("parser", 22, "There are mismatched parentheses in the expression! - (ln:tok) may be inacurrate!")))
-- 				table.remove(operatorStack, #operatorStack)
-- 				table.insert(outputStack, o2)
-- 				o2 = operatorStack[#operatorStack]
-- 			end
-- 			assert(out.assert(o2.contents == '(', out.errorBlock("parser", 22, "There are mismatched parentheses in the expression! - (ln:tok) may be inacurrate!")))
-- 			table.remove(operatorStack, #operatorStack)
-- 			o2 = operatorStack[#operatorStack]
-- 			if (o2 and o2.type == 1) then
-- 				table.remove(operatorStack, #operatorStack)
-- 				table.insert(outputStack, o2)
-- 			end
-- 		elseif token.type == 1 then
-- 			table.insert(outputStack, token)
-- 		else
-- 			out.errorPrint(out.errorBlock("parser", 7, "Token ".. globals.tableToString(token).. " couldn't be identified in the expression!"))
-- 			return -1
-- 		end
-- 	end

-- 	while #operatorStack > 0 do
-- 		local operator = operatorStack[#operatorStack]
-- 		assert(out.assert(operator.contents ~= "(", out.errorBlock("parser", 22, "There are mismatched parentheses in the expression! - (ln:tok) may be inacurrate!")))
-- 		table.remove(operatorStack, #operatorStack)
-- 		table.insert(outputStack, operator)
-- 	end
	
-- 	return outputStack
-- end

-- function ParseVariableType(cursor)
-- 	local token = cursor:read()
-- 	-- out.processPrint("parser", "Attempting to identify object type of ".. token.contents.. "!")

-- 	if token.type == 1 then -- Identifier
-- 		local parsed = ParseIdentifier(cursor)
-- 		if not parsed then
-- 			out.errorPrint(out.errorBlock("parser", 3, "Identifier cannot be parsed!"))
-- 		end

-- 		return parsed
-- 	end
-- 	if token.type == 3 then -- String
-- 		cursor:progressCursor()
-- 		return Node("String", token)
-- 	end
-- 	if token.type == 4 then -- Number/Logic
-- 		return ParseNumber(cursor)
-- 	end
-- 	if token.type == 5 then -- Not all seperators are good!
-- 		if token.contents == '(' then -- Number/Logic
-- 			return ParseNumber(cursor)
-- 		end
-- 		if token.contents == '{' then -- Table
-- 			return Node("Table", token)
-- 		end
-- 	end

-- 	return false
-- end
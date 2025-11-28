--[[
	@name: pretty.lua
	@desc: Helper module for printing pretty things to the
		   output.
]]

local out = {}

out.constant_line = 1
out.constant_tok = 1

out.codes = {
    ["RED"] = "31",
    ["GREEN"] = "32",
    ["YELLOW"] = "33",
    ["BLUE"] = "34",
    ["PURPLE"] = "35",

	["RED_BG"] = "41",
    ["GREEN_BG"] = "42",
    ["YELLOW_BG"] = "43",
    ["BLUE_BG"] = "44",
    ["PURPLE_BG"] = "45",

	["BOLD"] = "1",
	["UNDERLINE"] = "4",
	["ITALIC"] = "3",

    ["END"] = "0",
}

--[[
	@name: out.colString(t, ...)
	@desc: Returns a string in the given colour scheme.
]]
function out.colString(t, ...)
	local cols = { ... }
	local str = ''

	for i, v in ipairs(cols) do
		str = str.. out.codes[string.upper(v)]
		if i ~= #cols then
			str = str.. ";"
		else
			str = str.. "m"
		end
	end

	return "\27[".. str.. t.. "\27[".. out.codes["END"].. "m"
end

--[[
	@name: out.pprint(t, ...)
	@desc: Pretty-prints... prints output with colour scheme.
]]
function out.pprint(t, ...)
    print(out.colString(t, ...))
end

--[[
	@name: out.errorBlock(process, code, message)
	@desc: Defines an error block, to be used later.

	@prop: process
	@prop: code
	@prop: message
]]
function out.errorBlock(process, code, message)
	local t = {
		process=process,
		code=code,
		message=message,
	}

	setmetatable(t, {
		__tostring = function(v)
			print("{ process=".. v.process .. ", code=".. tostring(v.code).. ", message=".. v.message .." }")
		end,
	})

	return t
end

--[[
	@name: out.processPrint(processName, text, processCol)
	@desc: Pretty prints out in a specific format to give more info to the dev.
]]
function out.processPrint(processName, text, processCol)
	if not processCol then processCol = "blue" end
	print(out.colString("[".. processName:upper().. ("\\ln".. tostring(out.constant_line).. ":".. "tok".. tostring(out.constant_tok)) .. "]:", processCol).. " ".. text)
end


--[[
	@name: out.errorPrint(errorBlock)
	@desc: Pretty prints out the errorBlock in the proper error format to give more
		   info to the dev.
]]
function out.errorPrint(errorBlock)
	print(out.colString("[".. errorBlock.process:upper().. ("\\ln".. tostring(out.constant_line).. ":".. "tok".. tostring(out.constant_tok)) .. "]:".. " Error Code ".. tostring(errorBlock.code).. " - \"".. errorBlock.message .. "\"", "red_bg"))
end

--[[
	@name: out.assert(condition, errorBlock)
	@desc: Will call errorPrint if the condition is not true, and returns the
		   result of the condition to be used inline with if statements.
]]
function out.assert(condition, errorBlock)
    if (not condition) then out.errorPrint(errorBlock) return false end
	return true
end

return out
--[[
    @name: globals.lua
    @desc: Contains a list of global properties and functions, which may be helpers.
]]

local globals = {}

globals.enum_TokenTypes = {
    "Keyword",
    "Identifier",
    "Operator",
    "LiteralString",
    "LiteralNumber",
    "Seperator",
    "Comment",
    "Whitespace",
    "Unknown",
    "Boolean",
    "Null",
}

globals.seperators = { ';',
                     '(',
                     ')',
                     '{',
                     '}',
                     ',', -- SPECIAL USECASE
                     '"', -- SPECIAL USECASE
                     ":", -- SPECIAL USECASE
                    }

globals.operators = {
    '+', '-', '/', '*', '^', '%', '=', '!', '>', '<'
}
globals.keywords = {
    "if", "while", "return", "continue", "else", "elseif", "fn", "@property", "@uniform"
}

--[[
    @name: globals.enum_TokenTypes.Enum(name)
    @desc: Returns the index of the given Enum type.
]]
globals.enum_TokenTypes["Enum"] = function(name)
    for index, value in ipairs(globals.enum_TokenTypes) do
        if index ~= "Enum" then
            if value == name then
                return index-1
            end
        end
    end

    return -1
end

--[[
    @name: globals.tableFind(t, v)
    @desc: Returns whether the given object (v) can be found in the
           given table (t)
]]
globals.tableFind = function(t, v)
    if t == nil then return false end -- TODO: Unknown looping over nil value found when migrating to <globals.lua> - functions as expected.
    for _, tV in ipairs(t) do
        if v == tV then
            return true
        end
    end

    return false
end

--[[
    @name: globals.tableToString(t)
    @desc: Returns a string representation of the table's data.
]]
globals.tableToString = function(t, indent)
    indent = indent or 0
	local toprint = string.rep(" ", indent) .. "{\n"
	indent = indent + 2
	for k, v in pairs(t) do
		toprint = toprint .. string.rep(" ", indent)
		if type(k) == "number" then
			toprint = toprint .. "[" .. k .. "] = "
		elseif type(k) == "string" then
			toprint = toprint .. k .. " = "
		end
		if type(v) == "table" then
			toprint = toprint .. globals.tableToString(v, indent + 2) .. ",\n"
		elseif type(v) == "string" then
			toprint = toprint .. '"' .. v .. '",\n'
		else
			toprint = toprint .. tostring(v) .. ",\n"
		end
	end
	toprint = toprint .. string.rep(" ", indent - 2) .. "}"
	return toprint
end

--[[
    @name: globals.druggedTable(template)
    @desc: Creates a "druggedTable" variant of the given table,
           which means it uses globals.tableToString() when parsed through
           tostring(obj).
]]
globals.druggedTable = function(template)
    local t = template
    setmetatable(t, {
        __tostring = function(v)
			return globals.tableToString(v)
		end
    })
    return t
end

return globals
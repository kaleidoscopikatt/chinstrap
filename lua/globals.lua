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

globals.tableFind = function(t, v)
    if t == nil then return false end -- TODO: Unknown looping over nil value found when migrating to <globals.lua> - functions as expected.
    for _, tV in ipairs(t) do
        if v == tV then
            return true
        end
    end

    return false
end

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
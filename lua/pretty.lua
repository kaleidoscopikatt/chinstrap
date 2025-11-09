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

function out.pprint(t, ...)
    print(out.colString(t, ...))
end

function out.processPrint(processName, text, processCol)
	if not processCol then processCol = "blue" end
	print(out.colString("[".. processName:upper().. ("\\ln".. tostring(out.constant_line).. ":".. "tok".. tostring(out.constant_tok)) .. "]:", processCol).. " ".. text)
end

function out.errorPrint(processName, errorCode, text)
	print(out.colString("[".. processName:upper().. ("\\ln".. tostring(out.constant_line).. ":".. "tok".. tostring(out.constant_tok)) .. "]:".. " Error Code ".. tostring(errorCode).. " - \"".. text .. "\"", "red_bg"))
end

return out
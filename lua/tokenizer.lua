--[[
@name: tokenizer.lua
@desc: The actual logical... well, tokenizer, for the
       compiler.
]]--

local globals = require("globals")
local out = require("pretty")

function RetrieveTokens(lines)
    local tokenList = {}

    local function finalizeToken(token)
        if token.contents ~= "" then
            -- Match for keywords...
            if token.type == globals.enum_TokenTypes.Enum("Identifier") and globals.tableFind(keywords, token.contents) then
                token.type = globals.enum_TokenTypes.Enum("Keyword")
            end
            table.insert(tokenList, token)
        end
    end

    local function newToken(contents, tokenType)
        return { contents = contents or "", type = tokenType or globals.enum_TokenTypes.Enum("Unknown") }
    end

    local inString = false
    local currentQuote = nil

    for lineNum, line in ipairs(lines) do
        local currentToken = newToken()

        for i = 1, #line do
            local char = line:sub(i, i)
            local isWhitespace = char:match("%s")

            if inString then
                -- We're inside a string literal, so include all characters (including spaces)
                currentToken.contents = currentToken.contents .. char
                if char == currentQuote then
                    -- End of string literal, finalize it
                    finalizeToken(currentToken)
                    currentToken = newToken()
                    inString = false
                    currentQuote = nil
                end
            else
                -- Not inside a string
                if char == '"' or char == "'" then
                    -- Beginning of a string literal
                    finalizeToken(currentToken)
                    currentToken = newToken(char, globals.enum_TokenTypes.Enum("LiteralString"))
                    inString = true
                    currentQuote = char
                elseif isWhitespace then
                    -- It's just whitespace, pop the token currently being written.
                    finalizeToken(currentToken)
                    currentToken = newToken()
                else
                    -- Check for seperators...
                    if globals.tableFind(globals.seperators, char) then
                        -- Pop the token currently being written.
                        finalizeToken(currentToken)
                        currentToken = newToken()

                        -- We've reached a seperator, write this as a new token!
                        -- Parser should then process all from the previous seperator...
                        currentToken = {
                            contents = char,
                            type = globals.enum_TokenTypes.Enum("Seperator")
                        }

                        -- Pop the seperator token.
                        finalizeToken(currentToken)
                        currentToken = newToken()
                    elseif globals.tableFind(globals.operators, char) then
                        -- Check for operators...
                        finalizeToken(currentToken)
                        currentToken = newToken()

                        -- Pop the token currently being written
                        currentToken = {
                            contents = char,
                            type = globals.enum_TokenTypes.Enum("Operator")
                        }

                        -- Pop the operator token.
                        finalizeToken(currentToken)
                        currentToken = newToken()
                    elseif tonumber(char) ~= nil then 
                        -- Build a number literal token.
                        currentToken.type = globals.enum_TokenTypes.Enum("LiteralNumber")
                        currentToken.contents = currentToken.contents .. char
                    elseif char == '$' then
                        -- Start of a comment. Pop current token.
                        finalizeToken(currentToken)

                        -- Capture everything until end of line as comment contents
                        local commentText = line:sub(i)
                        currentToken = newToken(commentText, globals.enum_TokenTypes.Enum("Comment"))
                        finalizeToken(currentToken)

                        -- Move to end of line
                        currentToken = newToken()
                        break
                    else
                        -- Assume it's an identifier.
                        if currentToken.type ~= globals.enum_TokenTypes.Enum("Identifier")
                            and currentToken.type ~= globals.enum_TokenTypes.Enum("Keyword") then
                            currentToken.type = globals.enum_TokenTypes.Enum("Identifier")
                        end

                        currentToken.contents = currentToken.contents .. char
                    end
                end
            end
        end

        finalizeToken(currentToken)
        currentToken = newToken("\n", globals.enum_TokenTypes.Enum("Whitespace"))
        nowInComment = false
        finalizeToken(currentToken)
    end

    local shouldBindString = false
    local currentBind = ""
    local startIndex = nil
    local i = 1

    while i <= #tokenList do
        local token = tokenList[i]

        if token.contents == '"' then
            shouldBindString = not shouldBindString
            if shouldBindString then
                startIndex = i
                currentBind = '"'
            else
                currentBind = currentBind .. '"'
                tokenList[startIndex] = {
                    contents = currentBind,
                    type = globals.enum_TokenTypes.Enum("LiteralString")
                }

                for j = i, startIndex + 1, -1 do
                    table.remove(tokenList, j)
                end

                i = startIndex
                shouldBindString = false
                startIndex = nil
                currentBind = ""
            end

        elseif shouldBindString then
            currentBind = currentBind .. token.contents
        end

        i = i + 1
    end

    return tokenList
end

-- print(globals.tableToString(RetrieveTokens({
--     '@property("_MainTex", 2D);'
-- })))
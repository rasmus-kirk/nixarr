-- Changes "Example" and "Default" section fenced code blocks into "nix" tagged code blocks

function Para(elem)
    -- Check if the first element of the paragraph is Emph (italic)
    if #elem.content >= 1 and elem.content[1].t == "Emph" then
        -- Convert the first element to plain text to check its content
        local firstText = pandoc.utils.stringify(elem.content[1])
        local isExample = firstText:find("^Example:")
        local isDefault = firstText:find("^Default:")
        
        -- Check if the text starts with "Declared by:"
        if isExample or isDefault then
            local newElems = {}
            for i, el in ipairs(elem.content) do
                if el.t == "Code" then
                    -- Convert inline code to fenced code block and add it to new elements
                    -- Note: This will be outside the paragraph due to block-level constraint
                    local addedSpaces = string.gsub(el.text, "^", "  ");
                    table.insert(newElems, pandoc.CodeBlock(addedSpaces, pandoc.Attr("", {"nix"})))
                else
                    -- Keep other elements as inline, to be added to a new paragraph
                    table.insert(newElems, el)
                end
            end
            -- Replace paragraph with new elements (mixing inline and block-level elements isn't directly possible, so this part needs rethinking)
            return newElems
        end
    end
    -- Otherwise, return the paragraph unmodified
    return elem
end

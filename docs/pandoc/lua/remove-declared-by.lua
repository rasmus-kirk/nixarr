-- Removed "Declared by:" paragraphs. TODO: Make them link to the GH repo instead

function Para(elem)
    -- Check if the first element of the paragraph is Emph (italic)
    if #elem.content >= 1 and elem.content[1].t == "Emph" then
        -- Convert the first element to plain text to check its content
        local firstText = pandoc.utils.stringify(elem.content[1])
        
        -- Check if the text starts with "Declared by:"
        if firstText:find("^Declared by:") then
            -- Return an empty block to remove this paragraph
            return {}
        end
    end
    -- Otherwise, return the paragraph unmodified
    return elem
end

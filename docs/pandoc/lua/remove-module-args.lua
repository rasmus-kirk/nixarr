-- Remove junk module.args section of the nix documentation

-- This function checks if a string starts with a given start string
function starts_with(str, start)
   return str:sub(1, #start) == start
end

-- This recursive function traverses the AST and removes sections based on the header condition
function remove_sections(elements, condition)
    local result = {}
    local skip_level = nil  -- Define skip_level outside the loop, initialized to nil

    for _, el in ipairs(elements) do
        if el.t == "Header" then
            -- Check if we are currently skipping sections and this header is of equal or higher level
            if skip_level and el.level <= skip_level then
                skip_level = nil  -- Stop skipping sections
            end

            -- If skip_level is nil, check if this header starts a new section to skip
            if not skip_level and condition(el) then
                skip_level = el.level  -- Start skipping sections
            else
                table.insert(result, el)  -- Add the header to results if not skipping
            end
        elseif not skip_level then
            table.insert(result, el)  -- Add non-header elements if not skipping
        end
    end

    return result
end

-- The Pandoc filter function to apply our custom logic
function Pandoc(doc)
    -- Define the condition function to be used for identifying sections to remove
    local condition = function(header)
        -- Assuming the header's actual text is in the 'content' array and in the first element
        local header_text = pandoc.utils.stringify(header.content)
        return starts_with(header_text, "_module.args")
    end

    -- Apply the removal function to the document blocks
    doc.blocks = remove_sections(doc.blocks, condition)

    return doc
end

-- pandoc_indent_nix_blocks.lua
-- This Pandoc Lua filter indents all lines in code blocks by 2 spaces
-- TODO: This indents _all_ code blocks, not just example and default...

--if dump_debug then
--  local debug_file = io.open("pandoc_debug.log", "a")
--end
--
--function debug(msg)
--  if debug_file then
--    debug_file:write(msg .. "\n")
--  end
--end

function CodeBlock(block)
  -- Check if the code block language is unmarked
  if #block.classes == 0 then
    -- Split the block text into lines
    local lines = {}
    for line in block.text:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end

    -- Indent each line by 2 spaces
    for i, line in ipairs(lines) do
      lines[i] = "  " .. line
    end

    -- Join the lines back together and update the block text
    block.text = table.concat(lines, '\n')

    -- Return the modified block
    return block
  end
end

return {
  {CodeBlock = CodeBlock}
}

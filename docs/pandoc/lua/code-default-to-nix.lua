-- This function is called for each CodeBlock element in the document.
function CodeBlock(block)
  -- Check if the code block does not have a language specified.
  if block.classes[1] == nil then
    -- Set the language of the code block to "nix".
    block.classes[1] = "nix"
  end
  return block
end

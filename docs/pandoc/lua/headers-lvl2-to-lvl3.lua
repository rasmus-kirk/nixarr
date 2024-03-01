-- Changes all level 2 headers to level 3

function Header(elem)
  -- Check if the header is of level 2
  if elem.level == 2 then
    -- Change the header level to 3
    elem.level = 3
  end
  return elem
end

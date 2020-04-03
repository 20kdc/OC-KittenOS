-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

return {
 -- note: everything must already be unicode.safeTextFormat'd
 draw = function (sW, line, cursorX, rX)
  -- if no camera, provide a default
  rX = rX or math.max(1, (cursorX or 1) - math.floor(sW * 2 / 3))
  -- transform into area-relative
  local tl = unicode.sub(line, rX, rX + sW - 1)
  -- inject cursor
  if cursorX then
   cursorX = (cursorX - rX) + 1
   if cursorX >= 1 then
    if cursorX <= sW then
     tl = unicode.sub(tl, 1, cursorX - 1) .. "_" .. unicode.sub(tl, cursorX + 1)
    end
   end
  end
  return tl .. (" "):rep(sW - unicode.len(tl))
 end,
 clamp = function (tl, cursorX)
  tl = unicode.len(tl)
  if tl < cursorX - 1 then
   return tl + 1
  end
  return cursorX
 end,
 -- returns line, cursorX, special
 -- return values may be nil if irrelevant
 key = function (ks, kc, line, cursorX)
  local cS = unicode.sub(line, 1, cursorX - 1)
  local cE = unicode.sub(line, cursorX)
  local ll = unicode.len(line)
  if kc == 203 then -- navi <
   if cursorX > 1 then
    return nil, cursorX - 1
   else
    -- cline underflow
    return nil, nil, "l<"
   end
  elseif kc == 205 then -- navi >
   if cursorX > ll then
    -- cline overflow
    return nil, nil, "l>"
   end
   return nil, cursorX + 1
  elseif kc == 199 then -- home
   return nil, 1
  elseif kc == 207 then -- end
   return nil, unicode.len(line) + 1
  elseif ks == "\8" then -- del
   if cursorX == 1 then
    -- weld prev
    return nil, nil, "w<"
   else
    return unicode.sub(cS, 1, unicode.len(cS) - 1) .. cE, cursorX - 1
   end
  elseif kc == 211 then -- del
   if cursorX > ll then
    return nil, nil, "w>"
   end
   return cS .. unicode.sub(cE, 2)
  elseif ks then -- standard letters
   if ks == "\r" then
    -- new line
    return nil, nil, "nl"
   end
   return cS .. ks .. cE, cursorX + unicode.len(ks)
  end
  -- :(
 end
}

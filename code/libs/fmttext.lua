local fmt
fmt = {
 pad = function (t, len, centre, cut)
  local l = unicode.len(t)
  local add = len - l
  if add > 0 then
   if centre then
    t = (" "):rep(math.floor(add / 2)) .. t .. (" "):rep(math.ceil(add / 2))
   else
    t = t .. (" "):rep(add)
   end
  end
  if cut then
   t = unicode.sub(t, 1, len)
  end
  return t
 end,
 fmtText = function (text, w)
  local nl = text:find("\n")
  if nl then
   local base = text:sub(1, nl - 1)
   local ext = text:sub(nl + 1)
   local baseT = fmt.fmtText(base, w)
   local extT = fmt.fmtText(ext, w)
   for _, v in ipairs(extT) do
    table.insert(baseT, v)
   end
   return baseT
  end
  if unicode.len(text) > w then
   local lastSpace
   for i = 1, w do
    if unicode.sub(text, i, i) == " " then
     -- Check this isn't an inserted space (unicode safe text format)
     local ok = true
     if i > 1 then
      if unicode.charWidth(unicode.sub(text, i - 1, i - 1)) ~= 1 then
       ok = false
      end
     end
     if ok then
      lastSpace = i
     end
    end
   end
   local baseText, extText
   if not lastSpace then
    -- Break at a 1-earlier boundary 
    local wEffect = w
    if unicode.charWidth(unicode.sub(text, w, w)) ~= 1 then
     -- Guaranteed to be safe, so
     wEffect = wEffect - 1
    end
    baseText = unicode.sub(text, 1, wEffect)
    extText = unicode.sub(text, wEffect + 1)
   else
    baseText = unicode.sub(text, 1, lastSpace - 1)
    extText = unicode.sub(text, lastSpace + 1) 
   end
   local full = fmt.fmtText(extText, w)
   table.insert(full, 1, fmt.pad(baseText, w))
   return full
  end
  return {fmt.pad(text, w)}
 end
}
return neo.wrapMeta(fmt)

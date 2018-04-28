-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- app-claw-csi: addSource function
-- USING THIS LIBRARY OUTSIDE OF APP-CLAW IS A BAD IDEA.
-- SO DON'T DO IT.

-- NOTE: If a source is writable, it's added anyway despite any problems.
return function (claw, name, src, dst)
 local ifo = ""
 local ifok, e = src("data/app-claw/local.lua", function (t)
  ifo = ifo .. (t or "")
  return true
 end)
 e = e or "local.lua parse error"
 ifo = ifok and require("serial").deserialize(ifo)
 if not (dst or ifo) then return false, e end
 table.insert(claw.sourceList, {name, not not dst})
 local nifo = ifo or ""
 if type(nifo) == "table" then
  nifo = ""
  for k, v in pairs(ifo) do
   nifo = nifo .. claw.compressCSI(k, v)
  end
 end
 claw.sources[name] = {src, dst, nifo}
 return not not ifo, e
end

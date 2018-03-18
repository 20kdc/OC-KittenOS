-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.
local doSerialize = nil
function doSerialize(s)
 if type(s) == "table" then
  local str = "{\n"
  for k, v in pairs(s) do
   str = str .. "[" .. doSerialize(k) .. "]=" .. doSerialize(v) .. ",\n"
  end
  return str .. "}"
 end
 if type(s) == "string" then
  return string.format("%q", s)
 end
 if type(s) == "number" then
  return tostring(s)
 end
 error("Cannot serialize " .. type(s))
end
return neo.wrapMeta({
 serialize = function (x) return "return " .. doSerialize(x) end,
 deserialize = function (s)
  local r1, r2 = pcall(function() return load(s, "=serial", "t", {})() end)
  if r1 then
   return r2
  end
 end
})

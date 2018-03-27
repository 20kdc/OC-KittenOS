-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.
local doSerialize = nil
function doSerialize(s)
 if type(s) == "table" then
  local str = "{\n"
  local p = 1
  for k, v in pairs(s) do
   if k == p then
    str = str .. doSerialize(v) .. ",\n"
    p = p + 1
   else
    str = str .. "[" .. doSerialize(k) .. "]=" .. doSerialize(v) .. ",\n"
   end
  end
  return str .. "}"
 end
 if type(s) == "string" then
  return string.format("%q", s)
 end
 if type(s) == "number" or type(s) == "boolean" then
  return tostring(s)
 end
 if s == nil then
  return "nil"
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

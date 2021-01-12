-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

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
return {
 serialize = function (x) return "return " .. doSerialize(x) end,
 deserialize = function (s)
  local r1, r2 = pcall(function()
   return load(s, "=serial", "t", {})()
  end)
  if r1 then
   return r2
  else
   return nil, tostring(r2)
  end
 end
}

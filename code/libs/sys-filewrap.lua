-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

return function(dev, file, mode)
 local n = "rb"
 if mode then n = "wb" end
 local handle, r = dev.open(file, n)
 if not handle then return nil, r end
 local open = true
 local function closer()
  if not open then return end
  open = false
  pcall(function()
   dev.close(handle)
  end)
 end
 if not mode then
  return {
   close = closer,
   read = function (len)
    if len == "*a" then
     local ch = ""
     local c = dev.read(handle, neo.readBufSize)
     while c do
      ch = ch .. c
      c = dev.read(handle, neo.readBufSize)
     end
     return ch
    end
    if type(len) ~= "number" then error("Length of read must be number or '*a'") end
    return dev.read(handle, len)
   end
  }, closer
 else
  return {
   close = closer,
   write = function (txt)
    if type(txt) ~= "string" then error("Write data must be string-bytearray") end
    local ok, b = dev.write(handle, txt)
    if not ok then error(tostring(b)) end
   end
  }, closer
 end
end

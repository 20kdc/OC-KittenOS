-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

local function ensureMode(mode)
 local n = "rb"
 if type(mode) == "boolean" then
  if mode then
   n = "wb"
  end
 elseif type(mode) == "string" then
  if mode == "append" then
   n = "ab"
  else
   error("Invalid fmode " .. mode)
  end
 else
  error("Invalid fmode")
 end
 return n
end
local function create(dev, file, mode)
 local n = ensureMode(mode)
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
 local function reader(len)
  if not open then return end
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
 local function writer(txt)
  if not open then return end
  neo.ensureType(txt, "string")
  return dev.write(handle, txt)
 end
 local function seeker(whence, point)
  if not open then return end
  return dev.seek(handle, whence, point)
 end
 if mode == "rb" then
  return {
   close = closer,
   seek = seeker,
   read = reader
  }, closer
 else
  return {
   close = closer,
   seek = seeker,
   read = reader,
   write = writer
  }, closer
 end
end
return {
 ensureMode = ensureMode,
 create = create
}

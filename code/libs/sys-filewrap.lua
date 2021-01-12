-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

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

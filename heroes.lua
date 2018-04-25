-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- arg is the size of the code.tar file
local arg = ...
os.execute("lua com2/preproc.lua < code.tar | lua com2/bdivide.lua > com2/code.tar.bd")
os.execute("cat insthead.lua")
print("sC=" .. math.ceil(tonumber(arg) / 512))
local src = io.open("com2/bundiv.lua", "r")
while true do
 local line = src:read()
 if not line then
  io.flush()
  src:close()
  return
 end
 local endix = line:sub(#line-1,#line)
 if endix ~= "XX" then
  if endix == "--" then
   -- included
   print(line:sub(3,#line-2))
  else
   print(line)
  end
 end
 -- XX means ignored.
end

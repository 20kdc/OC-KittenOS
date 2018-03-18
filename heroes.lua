-- SYSTEM HEROES.
-- Nabbed Sonic Heroes lyrics follow:
--  "What comes up, must come down... "
--  "Yet, my feet don't touch the ground..."

-- arg is the size of the code.tar file
local arg = ...
os.execute("lua com2/preproc.lua < code.tar | lua com2/bdivide.lua > com2/code.tar.bd")
os.execute("cat insthead.lua")
print("sC=" .. math.ceil(tonumber(arg) / 512))
local src = io.open("com2/bundiv.lua", "r")
while true do
 local line = src:read()
 if not line then
  src:close()
  io.write("--[[")
  io.flush()
  os.execute("cat com2/code.tar.bd")
  io.write("]]")
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

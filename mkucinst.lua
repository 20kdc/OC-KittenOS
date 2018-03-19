-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

os.execute("tar -cf code.tar code")
os.execute("cat insthead.lua > inst.lua")
local f = io.open("inst.lua", "ab")

local df = io.open("code.tar", "rb")
local sc = 0
while true do
 local d = df:read(512)
 if not d then break end
 sc = sc + 1
end
df:close()
local df = io.open("code.tar", "rb")
f:write("sC = " .. sc .. "\n")
while true do
 local d = df:read(512)
 if d then
  f:write(string.format("sector(%q)", d))
 else
  break
 end
end
df:close()
f:close()

-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- Imitation CLAW
local done = {}

local f, e = loadfile("code/data/app-claw/local.lua")
if not f then error(e) end
f = f()
if not os.execute("mkdir work") then
 error("Delete 'work'")
end
for k, v in pairs(f) do
 for _, vd in ipairs(v.dirs) do
  os.execute("mkdir work/" .. vd .. " 2> /dev/null")
 end
 for _, vf in ipairs(v.files) do
  -- not totally proofed but will do
  if not os.execute("cp code/" .. vf .. " work/" .. vf) then
   error("Could not copy " .. vf .. " in " .. k)
  end
  if done[vf] then
   error("duplicate " .. vf .. " in " .. k)
  end
  print(vf .. "\t\t" .. k)
  done[vf] = true
 end
end
os.execute("mkdir -p work/data/app-claw")
os.execute("cp code/data/app-claw/local.lua work/data/app-claw/local.lua")
os.execute("cp code/libs/sys-secpolicy.lua work/libs/sys-secpolicy.lua")
os.execute("cd code ; find . > ../imitclaw.treecode")
os.execute("cd work ; find . > ../imitclaw.treework")
os.execute("diff -u imitclaw.treecode imitclaw.treework")
os.execute("rm imitclaw.treecode imitclaw.treework")

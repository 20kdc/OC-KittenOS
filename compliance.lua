-- KittenOS NEO Repository Compliance Check Tool
-- I'm still not a lawyer
local filesAccountedFor = {
 ["repository/data/app-claw/local.lua"] = 0,
 ["repository/inst.lua"] = 0
}
local f = io.popen("find repository/docs/repoauthors -type f", "r")
while true do
 local s = f:read()
 if not s then f:close() break end
 filesAccountedFor[s] = s
 local f2 = io.open(s, "r")
 while true do
  local s2 = f2:read()
  if not s2 then
   f2:close()
   break
  end
  local st = s2:match("^[^:]+")
  if st then
   filesAccountedFor[st] = s
  end
 end
end
f = io.popen("find repository -type f", "r")
while true do
 local s = f:read()
 if not s then f:close() return end
 if not filesAccountedFor[s] then
  print("File wasn't accounted for: " .. s)
 end
end

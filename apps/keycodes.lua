local math, table = A.request("math", "table")
local app = {}
local strs = {"", "Shift-C to quit."}
local keys = {}
local function rebuildKeys()
 local keylist = {}
 for k, v in pairs(keys) do
  if v then
   table.insert(keylist, k)
  end
 end
 table.sort(keylist)
 strs[1] = ""
 for _, v in ipairs(keylist) do
  strs[1] = strs[1] .. v .. " "
 end
end
app.key = function(ka, kc, down)
 if ka == ("C"):byte() and down then
  A.die()
  return false
 end
 keys[kc] = down
 rebuildKeys()
 return true
end
app.get_ch = function (x, y)
 return (strs[y]):sub(x, x)
end
return app, 20, 2
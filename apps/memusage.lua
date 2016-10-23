local math, stat = A.request("math", "stat")
local app = {}
app.key = function(ka, kc, down)
 if ka == ("C"):byte() and down then
  A.die()
 end
end
local strs = {"", "Shift-C to quit."}
app.update = function ()
 local tm = stat.totalMemory()
 local um = math.floor((tm - stat.freeMemory()) / 1024)
 strs[1] = um .. ":" .. math.floor(tm / 1024)
 A.timer(1)
 return true
end
app.get_ch = function (x, y)
 return (strs[y]):sub(x, x)
end
return app, 16, 2
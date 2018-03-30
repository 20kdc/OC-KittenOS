local merges = {...}
neo = {
 wrapMeta = function (x)
  return x
 end
}
local serial = loadfile("code/libs/serial.lua")()
local repo = {}
for _, v in ipairs(merges) do
 local f = io.open(v, "rb")
 local fd = f:read("*a")
 f:close()
 for k, v in pairs(serial.deserialize(fd)) do
  repo[k] = v
 end
end
io.write(serial.serialize(repo))

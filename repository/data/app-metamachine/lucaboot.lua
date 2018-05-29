-- LUCcABOOT v0
local lr = "(no inits)"
for a in component.list("filesystem", true) do
 local dat = component.proxy(a)
 local fh = dat.open("/init.lua", "rb")
 if fh then
  local ttl = ""
  while true do
   local chk = dat.read(fh, 2048)
   if not chk then break end
   ttl = ttl .. chk
  end
  computer.getBootAddress = function () return a end
  computer.setBootAddress = function () end
  local fn, r = load(ttl, "=init.lua", "t")
  if not fn then
   lr = r
   dat.close(fh)
  else
   dat.close(fh)
   return fn()
  end
 end
end
error("No available operating systems. " .. lr)


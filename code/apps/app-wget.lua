-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

local event = require("event")(neo)
local neoux = require("neoux")(event, neo)

local primaryINet = neo.requireAccess("c.internet", "internet access").list()()

-- Enter URL dialog
local running = true
-- useful to perform a system update
local url = "http://20kdc.duckdns.org/neo/inst.lua"
local w = neoux.create(25, 3, nil, neoux.tcwindow(25, 3, {
 neoux.tcrawview(1, 1, {"URL to download?"}),
 neoux.tcfield(1, 2, 25, function (t)
  url = t or url
  return url
 end),
 neoux.tcbutton(16, 3, "Confirm", function (w)
  local nurl = url
  local fd = neoux.fileDialog(true)
  if not fd then return end
  -- download!
  local req, err = primaryINet.request(nurl)
  if not req then
   neoux.startDialog("failed request:\n" .. tostring(err))
  end
  -- OpenComputers#535
  req.finishConnect()
  while true do
   local n, n2 = req.read(neo.readBufSize)
   if not n then
    req.close()
    fd.close()
    if n2 then
     neoux.startDialog("failed download:\n" .. tostring(n2))
     return
    else
     break
    end
   else
    if n == "" then
     yielder()
    else
     local o, r = fd.write(n)
     if not o then
      req.close()
      fd.close()
      neoux.startDialog("failed write:\n" .. tostring(r))
      return
     end
    end
   end
  end
 end)
}, function (w)
 w.close()
 running = false
end, 0xFFFFFF, 0))

while running do
 event.pull()
end


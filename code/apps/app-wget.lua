-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

local event = require("event")(neo)
local neoux = require("neoux")(event, neo)

local primaryINet = neo.requireAccess("c.internet", "internet access").list()()

-- Enter URL dialog
local running = true
local sRunning = true
-- useful to perform a system update
local url = "http://20kdc.duckdns.org/neo/inst.lua"
local function doWorking()
 return 50, 1, nil, neoux.tcwindow(50, 1, {
  neoux.tcrawview(1, 1, {"Downloading now..."}),
 }, function (w)
  sRunning = false
 end, 0xFFFFFF, 0)
end
local function doMainWin()
 return 50, 3, nil, neoux.tcwindow(50, 3, {
  neoux.tcrawview(1, 1, {"URL to download?"}),
  neoux.tcfield(1, 2, 50, function (t)
   url = t or url
   return url
  end),
  neoux.tcbutton(41, 3, "Download", function (w)
   sRunning = true
   w.reset(doWorking())
   local nurl = url
   local fd = neoux.fileDialog(true)
   if not fd then
    w.reset(doMainWin())
    return
   end
   -- download!
   local req, err = primaryINet.request(nurl)
   if not req then
    fd.close()
    neoux.startDialog("failed request:\n" .. tostring(err))
    w.reset(doMainWin())
    return
   end
   -- OpenComputers#535
   req.finishConnect()
   while sRunning do
    local n, n2 = req.read(neo.readBufSize)
    if not n then
     if n2 then
      neoux.startDialog("failed download:\n" .. tostring(n2))
      break
     else
      break
     end
    else
     if n == "" then
      event.sleepTo(os.uptime() + 0.05)
     else
      local o, r = fd.write(n)
      if not o then
       neoux.startDialog("failed write:\n" .. tostring(r))
       break
      end
     end
    end
   end
   pcall(req.close)
   pcall(fd.close)
   w.reset(doMainWin())
  end)
 }, function (w)
  w.close()
  running = false
 end, 0xFFFFFF, 0)
end
local w = neoux.create(doMainWin())

while running do
 event.pull()
end


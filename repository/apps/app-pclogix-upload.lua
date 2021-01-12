-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- app-pclogix-upload: Upload to PCLogix Hastebin (paste.pc-logix.com)
local inet = neo.requireAccess("c.internet", "to upload").list()()
assert(inet, "no internet card")
local event = require("event")(neo)
local neoux = require("neoux")(event, neo)

local f = neoux.fileDialog(false)
if not f then return end
local data = f.read("*a")
f.close()

local s = inet.request("http://paste.pc-logix.com/documents", data)
assert(s, "no socket")
s.finishConnect()
local code, msg = s.response()
local res = tostring(code) .. " " .. tostring(msg) .. "\n"
while true do
 local chk, err = s.read(neo.readBufSize)
 if not chk then
  res = res .. "\n" .. tostring(err)
  break
 end
 if chk == "" then
  event.sleepTo(os.uptime() + 0.05)
 else
  res = res .. chk
 end
end
res = res .. "\nPrefix ID with http://paste.pc-logix.com/raw/"
neoux.startDialog(res, "result", true)
s.close()
-- that's a hastebin client for OC!
-- done! now I'll upload this with itself.
-- - 20kdc

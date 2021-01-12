-- KittenOS NEO Repository Compliance Check Tool
-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

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

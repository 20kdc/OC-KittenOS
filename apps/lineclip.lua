local unicode, proc = A.request("unicode", "proc")
for _, v in ipairs(proc.listApps()) do
 if v[2] == "lineclip" then
  if v[1] ~= proc.aid then
   A.die()
   return {}, 1, 1
  end
 end
end
local app = {}
local board = ""
function app.rpc(srcP, srcD, cmd, txt)
 if type(cmd) ~= "string" then
  return ""
 end
 if cmd == "copy" then
  if type(txt) ~= "string" then
   error("RPC->lineclip: bad text")
  end
  board = txt
  A.resize(unicode.len(board), 1)
 end
 if cmd == "paste" then
  return board
 end
end
function app.get_ch(x, y)
 return unicode.sub(unicode.safeTextFormat(board), x, x)
end
function app.key(ka, kc, down)
 if down and ka == ("C"):byte() then
  A.die()
 end
 return false
end
function app.update()
 return true
end
return app, 8, 1
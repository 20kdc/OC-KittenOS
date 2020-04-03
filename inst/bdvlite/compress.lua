-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

local frw = require("libs.frw")

local bdCore = require("bdivide.core")

return function (data, lexCrunch)
 io.stderr:write("\nbdivide: ")
 local pi = frw.progress()
 local function p(b)
  pi(1 - (#b / #data))
 end
 data = bdCore.bdividePad(bdCore.bdivide(data, p))
 io.stderr:write("\n")
 return lexCrunch.process(frw.read("bdvlite/instdeco.lua"), {}), data
end


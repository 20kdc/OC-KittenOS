-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- This is a wrapper around (i.e. does not contain) Zopfli.
local frw = require("libs.frw")

return function (data, lexCrunch)
 frw.write("tempData.bin", data)
 os.execute("zopfli --i1 --deflate -c tempData.bin > tempZopf.bin")
 local res = frw.read("tempZopf.bin")
 os.execute("rm tempData.bin tempZopf.bin")
 return lexCrunch(frw.read("deflate/instdeco.lua"), {}), res
end


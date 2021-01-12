-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- This is a wrapper around (i.e. does not contain) Zopfli.
local frw = require("libs.frw")

return function (data, lexCrunch)
 frw.write("tempData.bin", data)
 os.execute("zopfli --i1 --deflate -c tempData.bin > tempZopf.bin")
 local res = frw.read("tempZopf.bin")
 os.execute("rm tempData.bin tempZopf.bin")
 return lexCrunch.process(frw.read("deflate/instdeco.lua"), {}), res
end


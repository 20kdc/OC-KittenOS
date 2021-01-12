-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

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

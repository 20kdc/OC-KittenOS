-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- BDIVIDE (r5 edition)
-- decompression engine used to decompress DEFLATE decompression engine

$bdBDBuffer = ""
$bdBDWindow = ("\x00"):rep(2^16)

${
function $engineInput($L|lData)
 $bdBDBuffer = $bdBDBuffer .. $lData
 while #$bdBDBuffer > 2 do
  $lData = $bdBDBuffer:byte()
  if $lData < 128 then
   $lData = $bdBDBuffer:sub(1, 1)
   $bdBDBuffer = $bdBDBuffer:sub(2)
  else
   ${
   $L|bdBDPtr = $bdBDBuffer:byte(2) * 256 + $bdBDBuffer:byte(3) + 1
   $lData = $bdBDWindow:sub($bdBDPtr, $bdBDPtr + $lData - 125)
   $bdBDBuffer = $bdBDBuffer:sub(4)
   $}
  end
  $bdBDWindow = ($bdBDWindow .. $lData):sub(-2^16)
  $engineOutput($lData)
 end
end
$}


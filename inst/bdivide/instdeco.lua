-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- BDIVIDE (r5 edition) and PREPROC (r9 edition)
-- decompression engine for installer

$bdPPBuffer = ""
$bdBDBuffer = ""
$bdBDWindow = ("\x00"):rep(2^16)
-- High-level breakdown:
-- q is unescaper.
-- It'll only begin to input if at least 3 bytes are available,
--  so you'll want to throw in 2 extra zeroes at the end of stream as done here.
-- It uses t (input buffer) and p (output buffer).
-- Ignore its second argument, as that's a lie, it's just there for a local.
-- L is the actual decompressor. It has the same quirk as q, wanting two more bytes.
-- It stores to c (compressed), and w (window).
-- It outputs that which goes to the window to q also.
-- And it also uses a fake local.

-- SEE compress.lua FOR THIS FUNCTION
function $bdPP(x, y)
 if x == 126 then
  return string.char(y), 3
 elseif x == 127 then
  return string.char(128 + y), 3
 elseif x >= 32 then
  return string.char(x), 2
 elseif x == 31 then
  return "\n", 2
 elseif x == 30 then
  return "\x00", 2
 end
 return string.char(("enart"):byte(x % 5 + 1), ("ndtelh"):byte((x - x % 5) / 5 + 1)), 2
end

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
  $bdPPBuffer = $bdPPBuffer .. $lData
  $bdBDWindow = ($bdBDWindow .. $lData):sub(-2^16)
  while #$bdPPBuffer > 1 do
   ${
   $lData, $L|bdPPAdv = $bdPP($bdPPBuffer:byte(), $bdPPBuffer:byte(2))
   $bdPPBuffer = $bdPPBuffer:sub($bdPPAdv)
   $}
   $engineOutput($lData)
  end
 end
end
$}


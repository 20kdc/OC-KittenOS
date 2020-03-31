-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

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

function $engineInput($a0)
 $bdBDBuffer = $bdBDBuffer .. $a0
 while #$bdBDBuffer > 2 do
  $a0 = $bdBDBuffer:byte()
  if $a0 < 128 then
   $a0 = $bdBDBuffer:sub(1, 1)
   $bdBDBuffer = $bdBDBuffer:sub(2)
  else
   $NT|bdBDPtr
   $bdBDPtr = $bdBDBuffer:byte(2) * 256 + $bdBDBuffer:byte(3) + 1
   $a0 = $bdBDWindow:sub($bdBDPtr, $bdBDPtr + $a0 - 125)
   $bdBDBuffer = $bdBDBuffer:sub(4)
   $DT|bdBDPtr
  end
  $bdPPBuffer = $bdPPBuffer .. $a0
  $bdBDWindow = ($bdBDWindow .. $a0):sub(-2^16)
  while #$bdPPBuffer > 1 do
   $NT|bdPPAdv
   $a0, $bdPPAdv = $bdPP($bdPPBuffer:byte(), $bdPPBuffer:byte(2))
   $bdPPBuffer = $bdPPBuffer:sub($bdPPAdv)
   $DT|bdPPAdv
   $engineOutput($a0)
  end
 end
end


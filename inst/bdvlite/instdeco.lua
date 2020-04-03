-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

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


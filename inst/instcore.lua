-- KOSNEO installer base
-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

$icScreen = $component.list("screen", true)()
$icGPU = $component.list("gpu", true)()

$icFilename = "Starting..."
$icBytesRemaining = 0

if $icScreen and $icGPU then
 $icGPU = $component.proxy($icGPU)
 $icGPU.bind($icScreen)
 $icGPU.setResolution(50, 5)
 $icGPU.setBackground(2^24-1)
 $icGPU.setForeground(0)
 $icGPU.fill(1, 1, 50, 5, "█")
 $icGPU.fill(1, 2, 50, 1, " ")
 $icGPU.set(2, 2, "KittenOS NEO Installer")
end

function $icOctalToNumber($a0)
 if $a0 == "" then return 0 end
 return $icOctalToNumber($a0:sub(1, -2)) * 8 + ($a0:byte(#$a0) - 48)
end

$icSectorsRead = 0
$iBlockingLen = 512
function $iBlockingHook($a0)
 if $icBytesRemaining > 0 then
  ${
  $L|icByteAdv = math.min(512, $icBytesRemaining)
  $icBytesRemaining = $icBytesRemaining - $icByteAdv
  if $icFile then
   $filesystem.write($icFile, $a0:sub(1, $icByteAdv))
   if $icBytesRemaining <= 0 then
    $filesystem.close($icFile)
    $icFile = nil
   end
  end
  $}
 else
  $icFilename = $a0:sub(1, 100):gsub("\x00", "")
  -- this sets up the reading/skipping of data
  $icBytesRemaining = $icOctalToNumber($a0:sub(125, 135))
  if $icFilename:sub(1, 2) == "./" and $icFilename ~= "./" then
   $icFilename = $icFilename:sub(3)
   if $icFilename:sub(#$icFilename) == "/" then
    $filesystem.makeDirectory($icFilename)
   else
    $icFile = $filesystem.open($icFilename, "wb")
    if $icBytesRemaining == 0 then
     $filesystem.close($icFile)
     $icFile = nil
    end
   end
  end
 end
 -- UPDATE DISPLAY --
 $icSectorsRead = $icSectorsRead + 1
 if $icScreen and $icGPU then
  $icGPU.fill(1, 2, 50, 1, " ")
  $icGPU.set(2, 2, "KittenOS NEO Installer : " .. $icFilename)
  $icGPU.fill(2, 4, 48, 1, "█")
  $icGPU.fill(2, 4, math.ceil(48 * $icSectorsRead / $$SECTORS), 1, " ")
 end
 if $icSectorsRead % 16 == 0 then
  $computer.pullSignal(0.01)
 end
 if $icSectorsRead == $$SECTORS then
  $filesystem.close($readInFile)
  $filesystem.remove("init.neoi.lua")
  $computer.shutdown(true)
 end
end


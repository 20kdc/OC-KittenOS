-- KOSNEO installer base
-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

$computer = computer
$component = component
assert($component, "KittenOS NEO installer: Copy as init.lua to the target disk, then remove other disks & reboot.")

$filesystem = $component.proxy($computer.getBootAddress())

$filesystem.remove("init.neoi.lua")
$filesystem.rename("init.lua", "init.neoi.lua")
$readInFile = $filesystem.open("init.neoi.lua", "rb")

$iBlockingBuffer = ""
$iBlockingLen = $$CORESIZE
$iBlockingHook = function ($a0)
 -- This takes over the iBlockingHook.
 assert(load($a0))()
end

$engineOutput = function ($a0)
 $iBlockingBuffer = $iBlockingBuffer .. $a0
 while #$iBlockingBuffer >= $iBlockingLen do
  $NTiBlock
  $iBlock = $iBlockingBuffer:sub(1, $iBlockingLen)
  $iBlockingBuffer = $iBlockingBuffer:sub($iBlockingLen + 1)
  $iBlockingHook($iBlock)
  $DTiBlock
 end
end

-- DECOMPRESSION ENGINE FOLLOWS THIS CODE --


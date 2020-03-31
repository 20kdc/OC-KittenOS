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
${
function $iBlockingHook($L|lBlock)
 -- Run the next script (replacement compression engine,)
 assert(load($lBlock))()
end
$}

${
function $engineOutput($L|lBlock)
 $iBlockingBuffer = $iBlockingBuffer .. $lBlock
 while #$iBlockingBuffer >= $iBlockingLen do
  $lBlock = $iBlockingBuffer:sub(1, $iBlockingLen)
  $iBlockingBuffer = $iBlockingBuffer:sub($iBlockingLen + 1)
  $iBlockingHook($lBlock)
 end
end
$}
$engineInput = $engineOutput

while true do
 $readInBlock = $filesystem.read($readInFile, 1024)
 ${
 for i = 1, #$readInBlock do
  -- Read-in state machine

  -- IT IS VERY IMPORTANT that read-in be performed char-by-char.
  -- This is because of compression chain-loading; if the switch between engines isn't "clean",
  --  bad stuff happens.

  -- This character becomes invalid once
  --  it gets passed to engineInput,
  --  but that's the last step, so it's ok!
  $L|readInChar = $readInBlock:sub(i, i)
  if not $readInState then
   if $readInChar == "\x00" then
    $readInState = 0
   end
  elseif $readInState == 0 then
   if $readInChar == "\xFE" then
    $readInState = 1
   else
    $engineInput($readInChar)
   end
  else
   $engineInput($readInChar)
   $readInState = 0
  end
 end
 $}
end


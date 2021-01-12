-- KOSNEO installer base
-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

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


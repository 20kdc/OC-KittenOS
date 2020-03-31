-- KOSNEO installer base
-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- DECOMPRESSION ENGINE PRECEDES THIS CODE --

while true do
 $readInBlock = $filesystem.read($readInFile, 1024)
 for i = 1, #$readInBlock do
  -- Read-in state machine
  $NT|readInChar
  $readInChar = $readInBlock:sub(i, i)
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
 $DT|readInChar
end

-- COMPRESSED DATA FOLLOWS THIS CODE --


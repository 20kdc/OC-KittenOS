-- PREPROC: preprocess input to be 7-bit
-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

while true do
 local c = io.read(1)
 if not c then return end
 local bc = c:byte()
 if bc < 127 then
  io.write(c)
 else
  if bc <= 253 then
   -- 127(0) through 253(126)
   io.write("\x7F" .. string.char(bc - 127))
  else
   -- 254(0) through 255 (1)
   io.write("\x7F\x7F" .. string.char(bc - 254))
  end
 end
end

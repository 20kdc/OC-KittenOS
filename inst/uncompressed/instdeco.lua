-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

t = ""
function L(d)
 t = t .. d
 while #t >= 512 do
  M(t:sub(1, 512))
  t = t:sub(513)
 end
end


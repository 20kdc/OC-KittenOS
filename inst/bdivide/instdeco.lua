-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- BDIVIDE (r5 edition) and PREPROC (r9 edition)
-- decompression engine for installer

-- a: temporary
--    touched by q,L
-- b: sector accumulator
-- c: bdivide accumulator
-- d: temporary
--    touched by q,L
-- t: preproc accumulator
-- q: function to submit to preproc
-- s: temporary
--    touched by L
-- w: bdivide window

-- L: function to submit to bdivide

b,t,c,w="","","",("\x00"):rep(2^16)
-- High-level breakdown:
-- q is unescaper & TAR-sector-breakup.
-- It'll only begin to input if at least 3 bytes are available,
--  so you'll want to throw in 2 extra zeroes at the end of stream as done here.
-- It uses t (input buffer) and p (output buffer).
-- Ignore its second argument, as that's a lie, it's just there for a local.
-- L is the actual decompressor. It has the same quirk as q, wanting two more bytes.
-- It stores to c (compressed), and w (window).
-- It outputs that which goes to the window to q also.
-- And it also uses a fake local.

-- SEE compress.lua FOR THIS FUNCTION
function p(x, y)
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

function q(w)
 t = t .. w
 while #t > 1 do
  d, a = p(t:byte(), t:byte(2))
  b = b .. d
  t = t:sub(a)
  if #b > 511 then
   M(b:sub(1, 512))
   b = b:sub(513)
  end
 end
end

function L(d)
 c = c .. d
 while #c > 2 do
  s = c:byte()
  if s < 128 then
   s, c = c:sub(1, 1), c:sub(2)
  else
   a = c:byte(2) * 256 + c:byte(3) + 1
   s, c = w:sub(a, a + s - 125), c:sub(4)
  end
  q(s)
  w = (w .. s):sub(-2^16)
 end
end


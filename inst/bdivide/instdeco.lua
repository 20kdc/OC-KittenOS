-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- BDIVIDE (r5 edition) and PREPROC (r9 edition)
-- decompression engine for installer

-- cb: sector accumulator
-- ct: preproc accumulator
-- cc: bdivide accumulator
-- cw: bdivide window

-- cp: function to submit to preproc
-- cd: function to submit to bdivide

cb,ct,cc,cw="","","",("\x00"):rep(2^16)
-- High-level breakdown:
-- CP is unescaper & TAR-sector-breakup.
-- It'll only begin to input if at least 3 bytes are available,
--  so you'll want to throw in 2 extra zeroes at the end of stream as done here.
-- It uses Ct (input buffer) and Cp (output buffer).
-- Ignore its second argument, as that's a lie, it's just there for a local.
-- CD is the actual decompressor. It has the same quirk as CP, wanting two more bytes.
-- It stores to Cc (compressed), and Cw (window).
-- It outputs that which goes to the window to CP also.
-- And it also uses a fake local.

-- SEE compress.lua FOR THIS FUNCTION
function p(x, y)
 if x == 126 then
  if y >= 32 then
   return ({
    -- Before adding to this, check how installer size is changed.
    "\x7E", "\x7F"
   })[y - 31], 3
  end
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
 return string.char(("enart"):byte(x % 5 + 1), ("ndtelh"):byte(math.floor(x / 5) + 1)), 2
end

function cp(d, b, a)
 ct = ct .. d
 while #ct > 1 do
  b, a = p(ct:byte(), ct:byte(2))
  cb = cb .. b
  ct = ct:sub(a)
  if #cb > 511 then
   M(cb:sub(1, 512))
   cb = cb:sub(513)
  end
 end
end

function cd(d, b, p)
 cc = cc .. d
 while #cc > 2 do
  b = cc:byte()
  if b < 128 then
   b, cc = cc:sub(1, 1), cc:sub(2)
  else
   p = cc:byte(2) * 256 + cc:byte(3) + 1
   b, cc = cw:sub(p, p + b - 125), cc:sub(4)
  end
  cp(b)
  cw = (cw .. b):sub(-65536)
 end
end

-- quick & dirty integration with the existing stuff
function L(d)
 if not d then
  cd("\x00\x00")cp("\x00\x00")
 else
  cd(d)
 end
end


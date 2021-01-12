-- Copyright (C) 2018-2021 by KittenOS NEO contributors
--
-- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
-- THIS SOFTWARE.

-- bmp: Portable OC BMP/DIB library
-- Flexible: Reading can be set to
--  ignore first 14 bytes,
--  allowing reuse of the library on
--  ICO/CUR data. Yes, really.

-- handle(i, valDiv, valMod)
local function bitsCore(i, fieldOfs, fieldWidth, handle)
 local adv = math.floor(fieldOfs / 8)
 i = i + adv
 fieldOfs = fieldOfs - (adv * 8)
 -- above 3 lines are a removable optimization
 while fieldWidth > 0 do
  local bitsHere = math.min(fieldWidth, math.max(0, 8 - fieldOfs))
  if bitsHere > 0 then
   local pow1 = math.floor(2 ^ bitsHere)
   -- offset
   -- pixels are "left to right" in the MostSigBitFirst stream
   local aFieldOfs = 8 - (fieldOfs + bitsHere)
   local pow2 = math.floor(2 ^ aFieldOfs)
   handle(i, pow2, pow1)
   fieldWidth = fieldWidth - bitsHere
   fieldOfs = 0
  else
   -- in case the 'adv' opt. gets removed
   fieldOfs = fieldOfs - 8
  end
  i = i + 1
 end
end

local function encode16(t)
 return string.char(t % 0x100) .. string.char(math.floor(t / 0x100))
end

local function encode32(t)
 return encode16(t % 0x10000) .. encode16(math.floor(t / 0x10000))
end

-- This & the BMP equivalent return a header,
--  a buffer size, and a 1-based data pointer,
--  and are used to initially create the image.
-- Notably, for bpp <= 8, a paletteSize of 0 is illegal.
-- topDown adjusts the order of scanlines.
-- cMode adjusts some values.
-- IT IS RECOMMENDED YOU PROPERLY SET THE MASK UP.
local function prepareDIB(w, h, p, bpp, paletteSize, topDown, cMode)
 if bpp <= 8 then
  if paletteSize == 0 then
   error("A palette size of 0 is invalid for <= 8-bit images. Use 16-bit or 32-bit for no palette, or specify the amount of palette entries.")
  end
 end

 local scanWB = math.ceil((bpp * w) / 32) * 4
 local palSize = paletteSize * 4
 local bufSize = scanWB * h * p

 local aH = h
 if cMode then
  -- O.o why change format? who knows!
  aH = aH * 2
  bufSize = bufSize + ((math.ceil(w / 32) * 4) * h * p)
 end
 if topDown then
  aH = 0x100000000 - aH
 end
 return
  "\x28\x00\x00\x00" .. -- 0x0E
  encode32(w) .. -- 0x12
  encode32(aH) .. -- 0x16
  encode16(p) .. -- 0x1A
  encode16(bpp) .. -- 0x1C
  "\x00\x00\x00\x00" .. -- 0x1E
  encode32(bufSize) .. -- 0x22
  "\x00\x00\x00\x00" .. -- 0x26
  "\x00\x00\x00\x00" .. -- 0x2A
  encode32(paletteSize) .. -- 0x2E
  encode32(paletteSize), -- 0x32 then EOH
  -- -14 here to move back into headless units
  0x36 + palSize + bufSize - 14,
  0x36 + palSize + 1 - 14 -- 1-based data pointer
end

return {
 headerMinSzBMP = 0x36,
 headerMinSzDIB = 0x36 - 14,
 -- get/set are (index) and (index, value) respectively
 -- they are 1-based
 -- If "packed" is used, two things happen:
 -- 1. The +1 offeset for 1-based is replaced
 --     with packed (so -13 is pure packed-DIB)
 -- 2. We don't try to use the BMP header
 connect = function (get, set, cMode, packed)
  -- NOTE: Internally, BMP addresses are used,
  --        so that the Wikipedia page can be used
  --        as a valid reference for header fields.
  -- verify cMode
  if cMode ~= nil and cMode ~= "mask" and cMode ~= "colour" then
   error("Unknown cMode " .. cMode)
  end
  -- NOTE: 0-base is used
  local function get8(i)
   return get(i + (packed or 1))
  end
  local function get16(i)
   return get8(i) + (256 * get8(i + 1))
  end
  local function get32(i)
   return get16(i) + (65536 * get16(i + 2))
  end
  local function set8(i, v)
   set(i + (packed or 1), v)
  end
  local function set32(i, v)
   local st = encode32(v)
   set8(i, st:byte(1))
   set8(i + 1, st:byte(2))
   set8(i + 2, st:byte(3))
   set8(i + 3, st:byte(4))
  end
  local function getBits(i, fieldOfs, fieldWidth)
   local v = 0
   local vp = 1
   bitsCore(i, fieldOfs, fieldWidth, function (i, valDiv, valMod)
    local data = math.floor(get8(i) / valDiv) % valMod
    v = v + (data * vp)
    vp = vp * valMod
   end)
   return v
  end
  local function setBits(i, fieldOfs, fieldWidth, v)
   return bitsCore(i, fieldOfs, fieldWidth, function (i, valDiv, valMod)
    local data = get8(i)
    -- Firstly need to eliminate the old data
    data = data - ((math.floor(data / valDiv) % valMod) * valDiv)
    -- Now to insert the new data
    data = data + ((v % valMod) * valDiv)
    set8(i, data)
    -- Advance
    v = math.floor(v / valMod)
   end)
  end
  -- direct header reads (all of them)
  local hdrSize = get32(0x0E)
  if hdrSize < 0x28 then
   error("OS/2 Bitmaps Incompatible")
  end
  local width = get32(0x12)
  local height = get32(0x16)
  local planes = get16(0x1A)
  local bpp = get16(0x1C)
  local compression = get32(0x1E)
  local paletteCol = get32(0x2E)

  -- negative height means sane coords
  local upDown = true
  if height >= 0x80000000 then
   height = height - 0x100000000
   height = -height
   upDown = false
  end

  -- postprocess

  -- The actual values used for addressing, for cMode to mess with
  local basePtr = 14 + hdrSize + (paletteCol * 4)
  local scanWB = math.ceil((bpp * width) / 32) * 4
  local monoWB = math.ceil(width / 32) * 4
  local planeWB = scanWB * height

  if not packed then
   basePtr = get32(0x0A) -- 'BM' header
  end

  -- Cursor/Icon
  if cMode then
   height = math.floor(height / 2)
   assert(planes == 1, "planes ~= 1 for cursor")
   planeWB = planeWB + (monoWB * height)
  end
  if cMode == "mask" then
   if upDown then
    basePtr = basePtr + (scanWB * height)
   end
   bpp = 1
   scanWB = monoWB
   paletteCol = 0
   compression = 3
  elseif cMode == "colour" then
   if not upDown then
    basePtr = basePtr + (monoWB * height)
   end
  end
  -- Check compression
  if (compression ~= 0) and (compression ~= 3) and (compression ~= 6) then
   error("compression " .. compression .. " unavailable")
  end
  -- paletteSize correction for comp == 0
  if (bpp <= 8) and (paletteCol == 0) and (compression == 0) then
   paletteCol = math.floor(2 ^ bpp)
  end
  return {
   width = width,
   height = height,
   planes = planes,
   bpp = bpp,
   ignoresPalette = (compression ~= 0) or (paletteCol == 0) or (cMode == "mask"),
   paletteCol = paletteCol,
   paletteAddress = 14 + hdrSize + (packed or 1),
   dataAddress = basePtr + (packed or 1),
   dsFull = get32(0x22),
   dsSpan = scanWB,
   dsPlane = planeWB,
   getPalette = function (i)
    return get32(14 + hdrSize + (i * 4))
   end,
   setPalette = function (i, xrgb)
    set32(14 + hdrSize + (i * 4), xrgb)
   end,
   -- Coordinates are 0-based for sanity. Returns raw colour value.
   getPixel = function (x, y, p)
    if upDown then
     y = height - (1 + y)
    end
    local i = basePtr + (y * scanWB) + (p * planeWB)
    return getBits(i, x * bpp, bpp)
   end,
   -- Uses raw colour value.
   setPixel = function (x, y, p, v)
    if upDown then
     y = height - (1 + y)
    end
    local i = basePtr + (y * scanWB) + (p * planeWB)
    setBits(i, x * bpp, bpp, v)
   end
  }
 end,
 -- See prepareDIB above for format.
 prepareBMP = function (...)
  local head, tLen, dtPtr = prepareDIB(...)
  tLen = tLen + 14 -- add BM header
  dtPtr = dtPtr + 14
  head = "BM" .. encode32(tLen) .. "mRWH" .. encode32(dtPtr - 1) .. head
  return head, tLen, dtPtr
 end,
 prepareDIB = prepareDIB
}

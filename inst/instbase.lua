-- KOSNEO installer base
-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- DECOMPRESSION ENGINE PRECEDES THIS CODE --
-- NOTE: upper-case is reserved for this file,
-- lower-case is reserved for the decompression engine

-- A: temporary

-- B: computer
-- C: component

-- D: additional temporary
-- E: read-in state machine

-- F: current file: filename
-- H: remaining bytes to copy/skip
-- I: current file: handle (nil if not writing)

-- J: sectors handled
-- K: sector count (injected during build)
-- L: compression engine data function (set by CE)
-- M: sector handler function (called by CE)

-- O: current character for read-in state machine
-- P: file handle for selfread

-- Q: octal decoding function

-- X: screen address
-- Y: component: gpu
-- Z: component: filesystem
B = computer
C = component
assert(C, "KittenOS NEO installer: Copy as init.lua to the target disk, then remove other disks & reboot.")

X = C.list("screen", true)()
Y = C.list("gpu", true)()

Z = C.proxy(B.getBootAddress())

Z.remove("init.neoi.lua")
Z.rename("init.lua","init.neoi.lua")
P = Z.open("init.neoi.lua","rb")

F = "Starting..."
H = 0

if X and Y then
 Y = C.proxy(Y)
 Y.bind(X)
 Y.setResolution(50, 5)
 Y.setBackground(2^24-1)
 Y.setForeground(0)
 Y.fill(1, 1, 50, 5, "█")
 Y.fill(1, 2, 50, 1, " ")
 Y.set(2, 2, "KittenOS NEO Installer")
end

function Q(A)
 if A == "" then return 0 end
 return Q(A:sub(1, -2)) * 8 + (A:byte(#A) - 48)
end

J = 0

function M(n)
 if H > 0 then
  A = math.min(512, H)
  H = H - A
  if I then
   Z.write(I, n:sub(1, A))
   if H <= 0 then
    Z.close(I)
    I = nil
   end
  end
 else
  F = n:sub(1, 100):gsub("\x00", "")
  -- this sets up the reading/skipping of data
  H = Q(n:sub(125, 135))
  if F:sub(1, 2) == "./" and F ~= "./" then
   F = F:sub(3)
   if F:sub(#F) == "/" then
    Z.makeDirectory(F)
   else
    I = Z.open(F, "wb")
    if H == 0 then
     Z.close(I)
     I = nil
    end
   end
  end
 end
 -- UPDATE DISPLAY --
 J = J + 1
 if X and Y then
  Y.fill(1, 2, 50, 1, " ")
  Y.set(2, 2, "KittenOS NEO Installer : " .. F)
  Y.fill(2, 4, 48, 1, "█")
  Y.fill(2, 4, math.ceil(48 * J / K), 1, " ")
 end
 if J % 8 == 0 then
  B.pullSignal(0.01)
 end
 if J == K then
  Z.close(P)
  Z.remove("init.neoi.lua")
  B.shutdown(true)
 end
end

while true do
 A = Z.read(P, 64)
 D = ""
 for i = 1, #A do
  -- Read-in state machine
  O = A:sub(i, i)
  if not E then
   if O == "\x00" then
    E = 0
   end
  elseif E == 0 then
   if O == "\xFE" then
    E = 1
   else
    D = D .. O
   end
  else
   D = D .. O
   E = 0
  end
 end
 L(D)
end

-- COMPRESSED DATA FOLLOWS THIS CODE --


-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- THE DEFLATE DECOMPRESSOR OF MADNESS --

-- Core I/O --

-- $dfAlignToByteRemaining is
--  set to 8 in the outer engine

${
function $dfGetIntField($L|lLen, $L|lVal)
 $lVal = 0
 for $L|lI = 0, $lLen - 1 do
  if coroutine.yield() then
   $lVal = $lVal + 2^$lI
  end
 end
 return $lVal
end
$}

-- Huffman Core --
-- The approach here is based around 1-prefixed integers.
-- These are stored in a flat table.
-- So 0b1000 is the pattern 000.

${
function $dfReadHuffmanSymbol($L|lTree, $L|lVal)
 $lVal = 1
 while not $lTree[$lVal] do
  $lVal = ($lVal * 2) + $dfGetIntField(1)
 end
 return $lTree[$lVal]
end
$}

${
function $dfGenHuffmanTree($L|lCodeLens)
 -- $L|lI (used everywhere; defining inside creates a bug because it gets globalized)
 $L|lNextCode = {}
 ${
 -- To explain:
 -- lNextCode is needed all the way to the end.
 -- But lBLCount isn't needed after it's used to
 --  generate lNextCode.
 -- And lCode is very, very temporary.
 -- Hence this massive block.
 $L|lBLCount = {}
 -- Note the 0
 for $lI = 0, 15 do
  $lBLCount[$lI] = 0
 end
 for $lI = 0, #$lCodeLens do
  ${
  $L|lCodeLen = $lCodeLens[$lI]
  if $lCodeLen ~= 0 then
   $lBLCount[$lCodeLen] = $lBLCount[$lCodeLen] + 1
  end
  $}
 end

 $L|lCode = 0
 for $lI = 1, 15 do
  $lCode = ($lCode + $lBLCount[$lI - 1]) * 2
  $lNextCode[$lI] = $lCode
 end
 $}

 $L|lTree = {}
 for $lI = 0, #$lCodeLens do
  ${
  $L|lCodeLen = $lCodeLens[$lI]
  if $lCodeLen ~= 0 then
   $L|lPow = math.floor(2 ^ $lCodeLen)
   assert($lNextCode[$lCodeLen] < $lPow, "Tl" .. $lCodeLen)
   $L|lK = $lNextCode[$lCodeLen] + $lPow
   assert(not $lTree[$lK], "conflict @ " .. $lK)
   $lTree[$lK] = $lI
   $lNextCode[$lCodeLen] = $lNextCode[$lCodeLen] + 1
  end
  $}
 end
 return $lTree
end
$}

-- DEFLATE fixed trees --
${
$L|dfFixedTL = {}
for $L|lI = 0, 143 do $dfFixedTL[$lI] = 8 end
for $lI = 144, 255 do $dfFixedTL[$lI] = 9 end
for $lI = 256, 279 do $dfFixedTL[$lI] = 7 end
for $lI = 280, 287 do $dfFixedTL[$lI] = 8 end
$dfFixedLit = $dfGenHuffmanTree($dfFixedTL)
-- last line possibly destroyed dfFixedTL, but that's alright
$dfFixedTL = {}
for $lI = 0, 31 do $dfFixedTL[$lI] = 5 end
$dfFixedDst = $dfGenHuffmanTree($dfFixedTL)
$}

-- DEFLATE LZ Core --

$dfWindow = ("\x00"):rep(2^16)
$dfPushBuf = ""
function $dfOutput($a0)
 $dfWindow = ($dfWindow .. $a0):sub(-2^16)
 $dfPushBuf = $dfPushBuf .. $a0
end

$dfBittblLength = {
 0, 0, 0, 0, 0, 0, 0, 0,
 1, 1, 1, 1, 2, 2, 2, 2,
 3, 3, 3, 3, 4, 4, 4, 4,
 5, 5, 5, 5, 0
}
$dfBasetblLength = {
 3, 4, 5, 6, 7, 8, 9, 10,
 11, 13, 15, 17, 19, 23, 27, 31,
 35, 43, 51, 59, 67, 83, 99, 115,
 131, 163, 195, 227, 258
}
$dfBittblDist = {
 0, 0, 0, 0, 1, 1, 2, 2,
 3, 3, 4, 4, 5, 5, 6, 6,
 7, 7, 8, 8, 9, 9, 10, 10,
 11, 11, 12, 12, 13, 13
}
$dfBasetblDist = {
 1, 2, 3, 4, 5, 7, 9, 13,
 17, 25, 33, 49, 65, 97, 129, 193,
 257, 385, 513, 769, 1025, 1537, 2049, 3073,
 4097, 6145, 8193, 12289, 16385, 24577
}

${
function $dfReadBlockBody($L|lLit, $L|lDst, $L|lLitSym, $L|lLen, $L|lDCode, $L|lPtr)
 while true do
  $lLitSym = $dfReadHuffmanSymbol($lLit)
  if $lLitSym <= 255 then
   $dfOutput(string.char($lLitSym))
  elseif $lLitSym == 256 then
   return
  elseif $lLitSym <= 285 then
   $lLen = $dfBasetblLength[$lLitSym - 256] + $dfGetIntField($dfBittblLength[$lLitSym - 256])
   $lDCode = $dfReadHuffmanSymbol($lDst)
   $lPtr = 65537 - ($dfBasetblDist[$lDCode + 1] + $dfGetIntField($dfBittblDist[$lDCode + 1]))
   for $L|lI = 1, $lLen do
    $dfOutput($dfWindow:sub($lPtr, $lPtr))
   end
  else
   error("nt" .. v)
  end
 end
end
$}

-- Huffman Dynamics --

function $dfReadHuffmanDynamicSubcodes(distlens, dst, metatree)
 local loopVar = 0
 distlens[-1] = 0
 while loopVar < dst do
  local instr = $dfReadHuffmanSymbol(metatree)
  if instr < 16 then
   distlens[loopVar] = instr
   loopVar = loopVar + 1
  elseif instr == 16 then
   for loopVar2 = 1, 3 + $dfGetIntField(2) do
    distlens[loopVar] = distlens[loopVar - 1]
    loopVar = loopVar + 1
    if loopVar > dst then error("Overflow") end
   end
  elseif instr == 17 then
   for loopVar2 = 1, 3 + $dfGetIntField(3) do
    distlens[loopVar] = 0
    loopVar = loopVar + 1
    if loopVar > dst then error("Overflow") end
   end
  elseif instr == 18 then
   for loopVar2 = 1, 11 + $dfGetIntField(7) do
    distlens[loopVar] = 0
    loopVar = loopVar + 1
    if loopVar > dst then error("Overflow") end
   end
  else
   error("unable to handle cl instruction " .. instr)
  end
 end
 distlens[-1] = nil
end

function $dfReadHuffmanDynamic()
 local metalensi = {16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15}
 local metalens = {}
 for loopVar = 0, 18 do metalens[loopVar] = 0 end
 local ltl = $dfGetIntField(5) + 257
 local dst = $dfGetIntField(5) + 1
 local cln = $dfGetIntField(4) + 4
 for loopVar = 1, cln do
  metalens[metalensi[loopVar]] = $dfGetIntField(3)
 end
 local metatree = $dfGenHuffmanTree(metalens)
 local alllens = {}
 $dfReadHuffmanDynamicSubcodes(alllens, ltl + dst, metatree)
 local litlens = {}
 local distlens = {}
 for loopVar = 0, ltl - 1 do
  litlens[loopVar] = alllens[loopVar]
 end
 for loopVar = 0, dst - 1 do
  distlens[loopVar] = alllens[ltl + loopVar]
 end
 return $dfGenHuffmanTree(litlens), $dfGenHuffmanTree(distlens)
end

-- Main Thread --

$dfThread = coroutine.create(function ($a0, $a1)
 while true do
  $a0 = coroutine.yield()
  $NT|dfBlockType
  $dfBlockType = $dfGetIntField(2)
  if $dfBlockType == 0 then
   -- literal
   $dfGetIntField($dfAlignToByteRemaining)
   $a1 = $dfGetIntField(16)
   -- this is weird, ignore it
   $dfGetIntField(16)
   for loopVar = 1, $a1 do
    $dfOutput(string.char($dfGetIntField(8)))
   end
  elseif $dfBlockType == 1 then
   -- fixed Huffman
   $dfReadBlockBody($dfFixedLit, $dfFixedDst)
  elseif $dfBlockType == 2 then
   -- dynamic Huffman
   $dfReadBlockBody($dfReadHuffmanDynamic())
  else
   error("b3")
  end
  $DT|dfBlockType
  while $a0 do
   coroutine.yield()
  end
 end
end)

-- The Outer Engine --

coroutine.resume($dfThread)
function $engineInput($a0, $a1)
 $NT|dfForLoopVar
 $NT|dfForLoopVar2
 for $dfForLoopVar = 1, #$a0 do
  $a1 = $a0:byte($dfForLoopVar)
  $dfAlignToByteRemaining = 8
  while $dfAlignToByteRemaining > 0 do
   -- If we're providing the first bit (v = 8), then there are 7 bits remaining.
   -- So this hits 0 when the *next* 8 yields will provide an as-is byte.
   $dfAlignToByteRemaining = $dfAlignToByteRemaining - 1
   assert(coroutine.resume($dfThread, $a1 % 2 == 1))
   $a1 = math.floor($a1 / 2)
  end
 end
 $DT|dfForLoopVar2
 $DT|dfForLoopVar
 -- flush prepared buffer
 $engineOutput($dfPushBuf)
 $dfPushBuf = ""
end


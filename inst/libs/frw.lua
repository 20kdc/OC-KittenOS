-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

return {
 read = function (fn)
  local f = io.open(fn, "rb")
  local d = f:read("*a")
  f:close()
  return d
 end,
 write = function (fn, data)
  local f = io.open(fn, "wb")
  f:write(data)
  f:close()
 end,
 progress = function ()
  io.stderr:write("00% \\")
  local lastPercent = 0
  local chr = 0
  return function (fraction)
   local percent = math.ceil(fraction * 100)
   if percent ~= lastPercent then
    lastPercent = percent
    chr = (chr + 1) % 4
    io.stderr:write(string.format("\8\8\8\8\8%02i%% %s", percent, ("\\|/-"):sub(chr + 1, chr + 1)))
   end
  end
 end
}


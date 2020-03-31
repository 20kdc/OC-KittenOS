-- This is released into the public domain.
-- No warranty is provided, implied or otherwise.

-- Example compression engine.
-- Given: data, lexCrunch
--  returns compressionEngine, compressedData
return function (data, lexCrunch)
 return lexCrunch(" $engineInput = $engineOutput ", {}), data
end


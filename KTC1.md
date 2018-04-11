# KTC1 Specification

KittenOS Texture Compression 1 is an image compression format that, while not
 size-optimized or performance-optimized for OC screens, is optimized for
 streaming from disk, and always produces precise results.

KTC1's concepts are "inspired by" ETC1, and it was conceived after evaluating
 ETC1 for use in KittenOS NEO. ETC1, however, is not optimally fit for
 OpenComputers rendering, and thus KTC1 was created to provide an equal-size
 solution that better fit these requirements.

A 256-colour palette is assumed, and it is assumed that the palette is provided
 outside of KTC1's context.

A KTC1 block is one OpenComputers character (2x4 pixels), and is 4 bytes long.

The format amounts to a foreground palette index, a background palette index,
 and a Unicode character index in the Basic Multilingual Plane.

The unicode character is displayed with the given colours at the position of the
 block.

The renderer does not get more complicated when more blocks are involved.

Simply put, blocks that are overlapped by a previous wide character are to be
 totally ignored.

The size of this format is equivalent to 4-bit indexed data and to ETC1.

For standardization's sake, the container format for KTC1 has an 8-byte header:
 "OC" followed by two 16-bit big-endian unsigned integers, for width 
 and height in blocks, the bytes-per-block count for this format (4) as 
 an unsigned byte, and the amount of "comment" bytes that go after the image,
 as another unsigned byte.

 Example image, showing a 4x4 white "A" on black, with a standard text 
 black "A" on white underneath:

  4F 43 00 02 00 02 04 00
  FF 00 28 6E FF 00 28 B5
  00 FF 00 41 00 FF 00 00

## Additional Notes

A KTC1 file is theoretically a "lossless" screenshot under the limits of the
 OpenComputers system assuming the palette is correct.

The Basic Multilingual Plane access allows mixing images and text inside a
 KTC1 file, and covers all characters that OpenComputers supports.

This makes KTC1 an interesting option for use as a mixed text/image interchange
 format between applications.

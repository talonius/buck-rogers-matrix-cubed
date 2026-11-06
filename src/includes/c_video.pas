{ The display hardware several units program: the video BIOS's set-mode function, and display memory. }
unit C_Video;

interface

const
  { the video BIOS function that sets the mode in AL: Blit's SetVideoMode and GameIo's ExitGame }
  BIOS_SET_VIDEO_MODE = 0;
  { the segment of EGA and VGA display memory, EGA page 0 (page n is $200 paragraphs above it): Blit, TextRend }
  EGA_VIDEO_SEG = $A000;
  { the VGA frame buffer, EGA_VIDEO_SEG:0, as a 32-bit value: Border's ClearBox and TextRend's FillRect add a Word
    offset to it and cast the sum to a pointer }
  VGA_BASE = $A0000000;

implementation

end.

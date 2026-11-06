{ Resident VGA animation-frame preparation: PrepareVgaFrame puts a portrait animation frame in GDVars.vgaAnimation's
  display, copying the key frame as it is or expanding a delta frame's run-length code and XORing it with the key frame.
  XorFrame and ExpandRleFrame are in vgaframe.asm; Portrait's loader calls them too. The unit owns no storage. }
{$F+,O-,S-,R-,V-,B-,I-}
unit VgaFrame;

interface

{ Decodes a frame into vgaAnimation.display; does nothing while no animation is loaded.
  @param(frameIndex The frame: the key frame is copied as it is, any other is expanded and XORed with it.) }
procedure PrepareVgaFrame(frameIndex: Byte);

{ Stores src xor key into dst, byte by byte; dst may be src.
  @param(src The bytes to combine.)
  @param(dst Receives the result.)
  @param(key The bytes src is XORed with.)
  @param(count The byte count, above 0: 0 processes 65536 bytes.) }
procedure XorFrame(src, dst, key: Pointer; count: Word);

{ Expands a run-length-coded frame into dst.
  @param(src The run-length code.)
  @param(dst Receives the expanded frame.)
  @param(encodedBytes The length of the code at src.) }
procedure ExpandRleFrame(src, dst: Pointer; encodedBytes: Word);

implementation

uses GDVars, Types;

type
  { the buffer DecodeDelta expands a delta frame's code into }
  PVgaFrame = ^TVgaFrame;

{$L VGAFRAME.OBJ}
procedure XorFrame(src, dst, key: Pointer; count: Word); external;

procedure ExpandRleFrame(src, dst: Pointer; encodedBytes: Word); external;

procedure PrepareVgaFrame(frameIndex: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  frameSize: LongInt;
  workBuf: PVgaFrame;

  { Expands the current frame's code into the work buffer, then XORs it with the key frame into the display picture. }
  procedure DecodeDelta;
  begin
    VgaFrame.ExpandRleFrame(GDVars.vgaAnimation.frames[frameIndex], workBuf,
                   GDVars.portraitAnimation.encodedSizes[frameIndex]);
    VgaFrame.XorFrame(workBuf, @GDVars.vgaAnimation.display^.data,
             GDVars.vgaAnimation.frames[GDVars.portraitAnimation.keyFrameIndex], SizeOf(Types.TVgaFrame))
  end;

begin
  if GDVars.vgaAnimation.frames[0] = nil then Exit;
  GetMem(workBuf, SizeOf(Types.TVgaFrame));
  if frameIndex <> GDVars.portraitAnimation.keyFrameIndex then
    DecodeDelta
  else
    Move(GDVars.vgaAnimation.frames[frameIndex]^, GDVars.vgaAnimation.display^.data, SizeOf(Types.TVgaFrame));
  FreeMem(workBuf, SizeOf(Types.TVgaFrame))
end;
end.

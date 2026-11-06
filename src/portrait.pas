{ Loads and shows portrait animations, the 3-D view's sprites and the big picture, and sets the DAC range each uses. In
  VGA mode the key frame is decoded when it loads and the delta frames stay run-length coded, VgaFrame decoding the one
  shown against the key. In the other modes, and for sprite archives, every frame is decoded into a picture in
  imageFrames when it loads. The animation's state lives in GDVars: portraitAnimation, vgaAnimation, imageFrames,
  picArcName and picArcId. }
{$O+,F+,S-,R-,V-,B-,I-}
unit Portrait;

interface

type TResourceName = String[8];

{ Shows a frame of the loaded animation; in C_Ifc.ORBIT_MAP it first frames the picture in the planet's color, its name
  in the bottom edge.
  @param(col The text column of the picture's left edge.)
  @param(row The text row of the picture's top edge.)
  @param(isAnimated Ignored: it is set False before it is tested, so the frame is always shown directly, never drawn
    into viewPicture.)
  @param(frameIndex The frame shown.) }
procedure DisplayImageBuf(col, row: Integer; isAnimated: Boolean; frameIndex: Byte);

{ Loads an animation from an archive named with the data set's digit, unless it is the one loaded; six PIC records come
  from fixed archives 7 to 9. An archive whose name starts with S holds sprites. Frees the big picture first, except on
  the orbit map. A missing record shows 'PIC not found'. Note: the name and id are recorded before the load, so after a
  missing record the same request is taken as loaded.
  @param(archiveName The archive's name, without the data set's digit.)
  @param(resourceId The animation's record.)
  @param(withMask The mask flag each frame's picture is allocated and expanded with.) }
procedure LoadAnimation(archiveName: TResourceName; resourceId, withMask: Byte);

{ Frees the loaded animation and forgets which one is loaded. }
procedure FreeAnimation;

{ Draws the loaded sprite's frame for the distance into the 3-D view and flushes the view.
  @param(distance The squares ahead, 1 to 3; any other distance aborts the game.) }
procedure Show3DSprite(distance: Byte);

{ Frees the animation and loads a big picture from BIGPIC plus the data set's digit, unless it is the one loaded.
  @param(pictureId The big picture's record.) }
procedure LoadBigPic(pictureId: Byte);

{ Draws Border's text-screen frame and shows the big picture inside it, at cell 1, 1. }
procedure DisplayBigPic;

implementation

uses DaxIo, Mouse, TextRend, GameIo, Types, C_Pic, GDVars, Border, VgaFrame, Blit,
  C_Ifc, C_Vm;

const
  { the DAC registers a sprite archive's colors load into }
  SPRITE_DAC_FIRST = $B0;
  SPRITE_DAC_COUNT = 80;

procedure DisplayImageBuf(col, row: Integer; isAnimated: Boolean; frameIndex: Byte);
var
  color: Byte;
  planetName: String[10];
  planetIndent: Byte;
begin
  if ((GDVars.displayMode = C_Vm.VGA) and (GDVars.vgaAnimation.frames[frameIndex] = nil)) or
      (((GDVars.displayMode <> C_Vm.VGA) or GDVars.spriteArchive) and
       (GDVars.imageFrames[frameIndex] = nil)) then Exit;
  if GDVars.interfaceState = C_Ifc.ORBIT_MAP then begin
    case GDVars.zone0^.planet of
      0: begin color := 5; planetIndent := 0; planetName := '' end;
      1: begin color := 12; planetIndent := 1; planetName := 'Mercury' end;
      2: begin color := 2; planetIndent := 2; planetName := 'Venus' end;
      3: begin color := 1; planetIndent := 2; planetName := 'Earth' end;
      4: begin color := 4; planetIndent := 3; planetName := 'Mars' end;
    else begin color := 8; planetIndent := 0; planetName := 'Asteroids' end
    end;
    TextRend.FillRect(1, 1, 15, 1, color);
    TextRend.FillRect(1, 2, 1, 14, color);
    TextRend.FillRect(15, 2, 15, 14, color);
    TextRend.FillRect(1, 15, planetIndent + 3, 15, color);
    TextRend.FillRect(planetIndent + 4 + Length(planetName), 15, 15, 15, color);
    TextRend.DisplayString(planetIndent + 4, 15, 15, color, planetName)
  end;
  if (GDVars.displayMode = C_Vm.VGA) and not GDVars.spriteArchive then
    VgaFrame.PrepareVgaFrame(frameIndex);
  isAnimated := False;
  if isAnimated then begin
    if (GDVars.displayMode = C_Vm.VGA) and not GDVars.spriteArchive then
      Blit.BlitTileClipped(col - 1, row - 1, 0, 0, GDVars.vgaAnimation.display, GDVars.viewPicture)
    else
      Blit.BlitTileClipped(col - 1, row - 1, 0, 0, GDVars.imageFrames[frameIndex], GDVars.viewPicture);
    Mouse.HideMouse;
    Blit.FlushView;
    Mouse.ShowMouse
  end else begin
    Mouse.HideMouse;
    if (GDVars.displayMode = C_Vm.VGA) and not GDVars.spriteArchive then
      Blit.ShowPic(col, row, GDVars.vgaAnimation.display)
    else
      Blit.ShowPic(col, row, GDVars.imageFrames[frameIndex]);
    Mouse.ShowMouse
  end
end;

procedure LoadAnimation(archiveName: TResourceName; resourceId, withMask: Byte);
var
  imageX: Word;
  imageY: Word;
  frameNumber: Integer;
  pixelOffset: Word;
  lastLoadedFrame: Byte;
  paletteFirst: Byte;
  paletteCount: Byte;
  { the key frame's pixels }
  xorBuf: Types.PByteArr;
  { a frame's code or pixels }
  workBuf: Types.PByteArr;
  resourceData: Types.PByteArr;
  decodedBytes: Word;
  imageHeight: Word;
  imageWidth: Word;
  { Unused in this version; see the other implementations of this routine. }
  frameSize: Word;
  resourceSize: Word;
  frameDataOffset: Word;
  dataOffset: Word;
  archiveSuffix: String[1];
  maxEncodedSize: Word;
begin
  if resourceId = C_Pic.NO_ANIMATION then Exit;
  if (archiveName = GDVars.picArcName) and (resourceId = GDVars.picArcId) then begin
    if GDVars.spriteArchive then
      Blit.SetDacPalette(Portrait.SPRITE_DAC_FIRST, Portrait.SPRITE_DAC_COUNT, GDVars.loadedPalette)
    else if GDVars.interfaceState <> C_Ifc.ORBIT_MAP then
      Blit.SetDacPalette(C_Pic.PICTURE_DAC_FIRST, C_Pic.PICTURE_DAC_COUNT, GDVars.loadedPalette);
    Exit
  end;
  if (GDVars.bigPicture <> nil) and (GDVars.interfaceState <> C_Ifc.ORBIT_MAP) then
    Blit.FreePic(GDVars.bigPicture);
  TextRend.DisplayLoading;
  Portrait.FreeAnimation;
  FillChar(GDVars.portraitAnimation, SizeOf(GDVars.portraitAnimation), 0);
  GDVars.picArcName := archiveName;
  GDVars.spriteArchive := UpCase(archiveName[1]) = 'S';
  GDVars.picArcId := resourceId;
  Str(LongInt(GDVars.dataSet), archiveSuffix);
  if archiveName = 'PIC' then
    case resourceId of
      105, 64: archiveSuffix := '7';
      72, 92, 74: archiveSuffix := '8';
      62: archiveSuffix := '9'
    end;
  DaxIo.LoadDax(archiveName + archiveSuffix, '.dax', resourceId, resourceSize, resourceData);
  if resourceSize = 0 then begin
    TextRend.DisplayAndPause(14, 0, 'PIC not found');
    Exit
  end;
  dataOffset := 0;
  Move(resourceData^[dataOffset], imageHeight, SizeOf(imageHeight)); Inc(dataOffset, SizeOf(imageHeight));
  Move(resourceData^[dataOffset], imageWidth, SizeOf(imageWidth)); Inc(dataOffset, SizeOf(imageWidth));
  Move(resourceData^[dataOffset], imageX, SizeOf(imageX)); Inc(dataOffset, SizeOf(imageX));
  Move(resourceData^[dataOffset], imageY, SizeOf(imageY)); Inc(dataOffset, SizeOf(imageY));
  Move(resourceData^[dataOffset], lastLoadedFrame, SizeOf(lastLoadedFrame)); Inc(dataOffset, SizeOf(lastLoadedFrame));
  if lastLoadedFrame > SizeOf(GDVars.portraitAnimation.frameDelays) - 1 then
    lastLoadedFrame := SizeOf(GDVars.portraitAnimation.frameDelays) - 1;
  GDVars.portraitAnimation.lastFrameIndex := lastLoadedFrame;
  Move(resourceData^[dataOffset], paletteFirst, SizeOf(paletteFirst)); Inc(dataOffset, SizeOf(paletteFirst));
  Move(resourceData^[dataOffset], paletteCount, SizeOf(paletteCount)); Inc(dataOffset, SizeOf(paletteCount));
  Move(resourceData^[dataOffset], GDVars.picturePalette[paletteFirst], paletteCount * SizeOf(Types.TRgb));
  Inc(dataOffset, paletteCount * SizeOf(Types.TRgb));
  for frameNumber := 0 to (paletteCount div 2) - 1 do begin
    GDVars.paletteNibbles[paletteFirst + frameNumber * 2] := resourceData^[dataOffset] shr 4;
    GDVars.paletteNibbles[paletteFirst + frameNumber * 2 + 1] := resourceData^[dataOffset] and $F;
    Inc(dataOffset)
  end;
  for frameNumber := 0 to SizeOf(GDVars.nibbleCgaColors) div 4 - 1 do begin
    for pixelOffset := 0 to 3 do
      GDVars.nibbleCgaColors[frameNumber * 4 + Integer(pixelOffset)] :=
        (resourceData^[dataOffset] shr (6 - pixelOffset * 2)) and 3;
    Inc(dataOffset)
  end;
  GDVars.paletteMode := 0;
  Move(resourceData^[dataOffset], GDVars.portraitAnimation.keyFrameIndex,
       SizeOf(GDVars.portraitAnimation.keyFrameIndex));
  Inc(dataOffset, SizeOf(GDVars.portraitAnimation.keyFrameIndex));
  Move(resourceData^[dataOffset], GDVars.portraitAnimation.loopStartFrame,
       SizeOf(GDVars.portraitAnimation.loopStartFrame));
  Inc(dataOffset, SizeOf(GDVars.portraitAnimation.loopStartFrame));
  for frameNumber := 0 to lastLoadedFrame do begin
    Move(resourceData^[dataOffset], GDVars.portraitAnimation.encodedSizes[frameNumber],
         SizeOf(GDVars.portraitAnimation.encodedSizes[frameNumber]));
    Move(resourceData^[dataOffset + SizeOf(GDVars.portraitAnimation.encodedSizes[frameNumber])],
         GDVars.portraitAnimation.frameDelays[frameNumber],
         SizeOf(GDVars.portraitAnimation.frameDelays[frameNumber]));
    Inc(dataOffset, SizeOf(GDVars.portraitAnimation.encodedSizes[frameNumber]) +
      SizeOf(GDVars.portraitAnimation.frameDelays[frameNumber]))
  end;
  if (GDVars.displayMode = C_Vm.VGA) and not GDVars.spriteArchive then begin
    Blit.AllocPic(imageHeight, imageWidth, 1, withMask, GDVars.vgaAnimation.display);
    GDVars.vgaAnimation.display^.transparentColor := C_Pic.KEY_COLOR;
    GDVars.vgaAnimation.display^.hdrC := imageX;
    GDVars.vgaAnimation.display^.hdrD := imageY
  end;
  { The work buffer holds a decoded frame or, in VGA mode, the key frame's code: at least a decoded frame, more when a
    frame's code is longer. Note: it is freed as a decoded frame whatever size it was allocated with. }
  maxEncodedSize := SizeOf(Types.TVgaFrame);
  for frameNumber := 0 to lastLoadedFrame do
    if GDVars.portraitAnimation.encodedSizes[frameNumber] > maxEncodedSize then
      maxEncodedSize := GDVars.portraitAnimation.encodedSizes[frameNumber];
  GetMem(workBuf, maxEncodedSize);
  if (GDVars.displayMode = C_Vm.VGA) and not GDVars.spriteArchive then begin
    for frameNumber := 0 to lastLoadedFrame do begin
      if frameNumber = GDVars.portraitAnimation.keyFrameIndex then begin
        GetMem(GDVars.vgaAnimation.frames[frameNumber], SizeOf(Types.TVgaFrame));
        Move(resourceData^[dataOffset], workBuf^, GDVars.portraitAnimation.encodedSizes[frameNumber]);
        VgaFrame.ExpandRleFrame(workBuf, GDVars.vgaAnimation.frames[frameNumber],
                                GDVars.portraitAnimation.encodedSizes[frameNumber])
      end else begin
        GetMem(GDVars.vgaAnimation.frames[frameNumber], GDVars.portraitAnimation.encodedSizes[frameNumber]);
        Move(resourceData^[dataOffset], GDVars.vgaAnimation.frames[frameNumber]^,
             GDVars.portraitAnimation.encodedSizes[frameNumber])
      end;
      Inc(dataOffset, GDVars.portraitAnimation.encodedSizes[frameNumber])
    end
  end else begin
    GetMem(xorBuf, SizeOf(Types.TVgaFrame));
    frameDataOffset := dataOffset;
    frameNumber := 0;
    while frameNumber < GDVars.portraitAnimation.keyFrameIndex do begin
      Inc(dataOffset, GDVars.portraitAnimation.encodedSizes[frameNumber]); Inc(frameNumber)
    end;
    VgaFrame.ExpandRleFrame(@resourceData^[dataOffset], xorBuf,
                            GDVars.portraitAnimation.encodedSizes[GDVars.portraitAnimation.keyFrameIndex]);
    dataOffset := frameDataOffset;
    for frameNumber := 0 to lastLoadedFrame do begin
      Blit.AllocPic(imageHeight, imageWidth, 1, withMask, GDVars.imageFrames[frameNumber]);
      GDVars.imageFrames[frameNumber]^.hdrC := imageX;
      GDVars.imageFrames[frameNumber]^.hdrD := imageY;
      GDVars.imageFrames[frameNumber]^.transparentColor := C_Pic.KEY_COLOR;
      if frameNumber <> GDVars.portraitAnimation.keyFrameIndex then begin
        VgaFrame.ExpandRleFrame(@resourceData^[dataOffset], workBuf,
                                GDVars.portraitAnimation.encodedSizes[frameNumber]);
        VgaFrame.XorFrame(workBuf, workBuf, xorBuf, SizeOf(Types.TVgaFrame));
        if GDVars.spriteArchive then
          for pixelOffset := 0 to SizeOf(Types.TVgaFrame) - 1 do
            case workBuf^[pixelOffset] of
              0: workBuf^[pixelOffset] := C_Pic.KEY_COLOR;
              C_Pic.KEY_COLOR: workBuf^[pixelOffset] := 0
            end;
        decodedBytes := 0;
        Blit.ExpandPicFrames(workBuf, decodedBytes, withMask, C_Pic.KEY_COLOR, GDVars.imageFrames[frameNumber])
      end;
      Inc(dataOffset, GDVars.portraitAnimation.encodedSizes[frameNumber])
    end;
    if GDVars.spriteArchive then
      for pixelOffset := 0 to SizeOf(Types.TVgaFrame) - 1 do
        case xorBuf^[pixelOffset] of
          0: xorBuf^[pixelOffset] := C_Pic.KEY_COLOR;
          C_Pic.KEY_COLOR: xorBuf^[pixelOffset] := 0
        end;
    decodedBytes := 0;
    Blit.ExpandPicFrames(xorBuf, decodedBytes, withMask, C_Pic.KEY_COLOR,
                         GDVars.imageFrames[GDVars.portraitAnimation.keyFrameIndex]);
    FreeMem(xorBuf, SizeOf(Types.TVgaFrame))
  end;
  FreeMem(resourceData, resourceSize);
  FreeMem(workBuf, SizeOf(Types.TVgaFrame));
  if GDVars.spriteArchive then begin
    Blit.ShadowPaletteEntries(Portrait.SPRITE_DAC_FIRST, Portrait.SPRITE_DAC_COUNT, GDVars.loadedPalette);
    Blit.SetDacPalette(Portrait.SPRITE_DAC_FIRST, Portrait.SPRITE_DAC_COUNT, GDVars.loadedPalette)
  end else if GDVars.interfaceState = C_Ifc.ORBIT_MAP then begin
    Blit.ShadowPaletteEntries(C_Pic.ORBIT_DAC_FIRST, C_Pic.ORBIT_DAC_COUNT, GDVars.loadedPalette);
    Blit.SetDacPalette(C_Pic.ORBIT_DAC_FIRST, C_Pic.ORBIT_DAC_COUNT, GDVars.loadedPalette)
  end else begin
    Blit.ShadowPaletteEntries(C_Pic.PICTURE_DAC_FIRST, C_Pic.PICTURE_DAC_COUNT, GDVars.loadedPalette);
    Blit.SetDacPalette(C_Pic.PICTURE_DAC_FIRST, C_Pic.PICTURE_DAC_COUNT, GDVars.loadedPalette)
  end
end;

procedure FreeAnimation;
begin
  if (GDVars.displayMode = C_Vm.VGA) and not GDVars.spriteArchive then begin
    for GDVars.loopIndex := 0 to GDVars.portraitAnimation.lastFrameIndex do
      if GDVars.vgaAnimation.frames[GDVars.loopIndex] <> nil then
        if GDVars.loopIndex = GDVars.portraitAnimation.keyFrameIndex then
          FreeMem(GDVars.vgaAnimation.frames[GDVars.loopIndex], SizeOf(Types.TVgaFrame))
        else
          FreeMem(GDVars.vgaAnimation.frames[GDVars.loopIndex],
                  GDVars.portraitAnimation.encodedSizes[GDVars.loopIndex]);
    Blit.FreePic(GDVars.vgaAnimation.display);
    { Note: 66 runs past vgaAnimation and 26 bytes into imageFrames }
    FillChar(GDVars.vgaAnimation, 66, 0)
  end else begin
    for GDVars.loopIndex := 0 to GDVars.portraitAnimation.lastFrameIndex do
      Blit.FreePic(GDVars.imageFrames[GDVars.loopIndex]);
    FillChar(GDVars.imageFrames, SizeOf(GDVars.imageFrames), 0)
  end;
  GDVars.picArcName[0] := #0;
  GDVars.picArcId := C_Pic.NO_ANIMATION
end;

procedure Show3DSprite(distance: Byte);
begin
  if (distance < 1) or (distance > 3) then begin
    Blit.RestoreVideoMode;
    WriteLn('Illegal range in Show3DSprite.');
    GameIo.ExitGame
  end;
  if GDVars.imageFrames[distance - 1] = nil then Exit;
  Blit.BlitTileClipped(2, 2, 0, 1, GDVars.imageFrames[distance - 1], GDVars.viewPicture);
  Blit.FlushView
end;

procedure LoadBigPic(pictureId: Byte);
var suffix: String[1];
begin
  Portrait.FreeAnimation;
  if (GDVars.bigPictureId = pictureId) and (GDVars.bigPicture <> nil) then
    Blit.SetDacPalette(C_Pic.PICTURE_DAC_FIRST, C_Pic.PICTURE_DAC_COUNT, GDVars.bigPicturePalette)
  else begin
    TextRend.DisplayLoading;
    Str(LongInt(GDVars.dataSet), suffix);
    Blit.LoadPic('bigpic' + suffix, pictureId, False, 0, GDVars.bigPicture);
    GDVars.bigPictureId := pictureId;
    Blit.ShadowPaletteEntries(C_Pic.PICTURE_DAC_FIRST, C_Pic.PICTURE_DAC_COUNT, GDVars.bigPicturePalette);
    Blit.SetDacPalette(C_Pic.PICTURE_DAC_FIRST, C_Pic.PICTURE_DAC_COUNT, GDVars.picturePalette);
    TextRend.ClearStatusLine
  end
end;

procedure DisplayBigPic;
begin
  Mouse.HideMouse;
  Border.ScreenText;
  Blit.ShowPic(1, 1, GDVars.bigPicture);
  Mouse.ShowMouse
end;

begin
end.

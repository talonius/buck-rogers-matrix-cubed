{ The 24x24 pictures: the combat arena's terrain tiles, loaded into GDVars.arenaTiles, and the two-frame icons in
  GDVars.iconFrames that stand for characters, creatures and effects. }
{$O+,F+,I-,A-}
unit MapTiles;

interface

{ Loads a record of an archive and copies its tiles into arenaTiles from a tile slot on, unless arenaTiles is nil; a
  slot above 59 stops the game.
  @param(name The archive's name.)
  @param(fileId The record.)
  @param(slot The first tile slot.)
  @param(count The number of tiles.) }
procedure Load24x24Set(name: String; fileId, slot, count: Byte);

{ Frees both frames of an icon.
  @param(animIdx The icon.) }
procedure FreeIconAnim(animIdx: Byte);

{ Loads records fileId and fileId + 128 of an archive as an icon's two frames. COMSPR, ICON, CHARS and CPIC (CPIC plus
  the data set's digit) are transparent in color 8, and CHARS and CPIC copy their palette range into combatPalette (in
  VGA mode); any other name takes the data set's digit, is transparent in 0, and is recolored by iconRecolors outside
  CGA.
  @param(name The archive's name.)
  @param(fileId The record of the first frame.)
  @param(animIdx The icon.) }
procedure LoadIconAnim(name: String; fileId, animIdx: Byte);

{ Draws a frame of an icon into viewPicture at a 24x24 cell.
  @param(col The cell's column.)
  @param(row The cell's row.)
  @param(facing Above 3 draws the frame mirrored.)
  @param(frame The frame, 0 or 1.)
  @param(animIdx The icon.) }
procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);

implementation

uses Blit, GameIo, Types, GDConsts, GDVars, C_Vm, C_Pic;

const
  { the highest slot Load24x24Set accepts }
  LAST_TILE_SLOT = 59;
  { added to an icon's record number for its second frame }
  SECOND_FRAME_RECORD = 128;
  { facings up to it draw an icon as stored, those above it mirrored }
  LAST_UNMIRRORED_FACING = 3;
  { dark gray, the transparent color of the COMSPR, ICON, CHARS and CPIC icons }
  SPRITE_KEY_COLOR = 8;
  { black, the other icons' }
  ICON_KEY_COLOR = 0;
  { the DAC range $90..$FF: LoadIconAnim shadows CPIC icons' colors into combatPalette there }
  CPIC_ICON_DAC_FIRST = $90;
  CPIC_ICON_DAC_COUNT = 112;

procedure Load24x24Set(name: String; fileId, slot, count: Byte);
var
  pic: Types.PImgBuf;
  total: Word;
  offset: Word;
begin
  if slot > MapTiles.LAST_TILE_SLOT then begin
    Blit.RestoreVideoMode;
    WriteLn('Start range error in Load24x24Set');
    GameIo.ExitGame
  end;
  pic := nil;
  Blit.LoadPic(name, fileId, False, 0, pic);
  total := count * pic^.frameSize;
  offset := slot * pic^.frameSize;
  if GDVars.arenaTiles <> nil then
    Move(pic^.data, GDVars.arenaTiles^.data[offset], total);
  Blit.FreePic(pic);
  GameIo.FlushKeys
end;

procedure FreeIconAnim(animIdx: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  frameIndex: Integer;
begin
  if GDVars.iconFrames[animIdx, 0] <> nil then
    Blit.FreePic(GDVars.iconFrames[animIdx, 0]);
  if GDVars.iconFrames[animIdx, 1] <> nil then
    Blit.FreePic(GDVars.iconFrames[animIdx, 1])
end;

procedure LoadIconAnim(name: String; fileId, animIdx: Byte);
var
  suffix: String[1];
  { Unused in this version; see the other implementations of this routine. }
  index: Integer;
begin
  if (name = 'COMSPR') or (name = 'ICON') or (name = 'CHARS') or (name = 'CPIC') then
  begin
    if name = 'CPIC' then
      Str(GDVars.dataSet, suffix)
    else
      suffix := '';
    Blit.LoadPic(name + suffix, fileId, True, MapTiles.SPRITE_KEY_COLOR, GDVars.iconFrames[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + MapTiles.SECOND_FRAME_RECORD, True, MapTiles.SPRITE_KEY_COLOR,
                 GDVars.iconFrames[animIdx, 1]);
    if name = 'CHARS' then
      Blit.ShadowPaletteEntries(C_Pic.CHARS_ICON_DAC_FIRST, C_Pic.CHARS_ICON_DAC_COUNT, GDVars.combatPalette)
    else if name = 'CPIC' then
      Blit.ShadowPaletteEntries(MapTiles.CPIC_ICON_DAC_FIRST, MapTiles.CPIC_ICON_DAC_COUNT, GDVars.combatPalette)
  end else begin
    Str(GDVars.dataSet, suffix);
    Blit.LoadPic(name + suffix, fileId, True, MapTiles.ICON_KEY_COLOR, GDVars.iconFrames[animIdx, 0]);
    if GDVars.displayMode <> C_Vm.CGA then
      Blit.RemapPic(GDConsts.identityColors, GDConsts.iconRecolors, 0, False, GDVars.iconFrames[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + MapTiles.SECOND_FRAME_RECORD, True, MapTiles.ICON_KEY_COLOR,
                 GDVars.iconFrames[animIdx, 1]);
    if GDVars.displayMode <> C_Vm.CGA then
      Blit.RemapPic(GDConsts.identityColors, GDConsts.iconRecolors, 0, False, GDVars.iconFrames[animIdx, 1])
  end;
  GameIo.FlushKeys
end;

procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);
var
  work: Types.PImgBuf;
begin
  if GDVars.iconFrames[animIdx, frame] = nil then Exit;
  with GDVars.iconFrames[animIdx, frame]^ do
    if facing > MapTiles.LAST_UNMIRRORED_FACING then begin
      Blit.AllocPic(height, width, 1, 1, work);
      work^.transparentColor := GDVars.iconFrames[animIdx, frame]^.transparentColor;
      Blit.MirrorPic(GDVars.iconFrames[animIdx, frame], work);
      Blit.BlitTileClipped(col * 3, row * 3, 0, 1, work, GDVars.viewPicture);
      Blit.FreePic(work)
    end else
      Blit.BlitTileClipped(col * 3, row * 3, 0, 1, GDVars.iconFrames[animIdx, frame],
                           GDVars.viewPicture)
end;

begin
end.

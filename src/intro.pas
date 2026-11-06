{ The title sequence: TITLE pictures 1 to 3, the credits screen, then picture 4. Each title picture stays up for 5
  seconds and the credits for 20; input ends a wait early, and input during the first wait skips pictures 2 and 3.
  Introduction loads the pictures from data set 6 and restores the data set on the way out, showing the mouse and
  setting GDVars.isGameUp. }
{$O+,F+,V+}
unit Intro;

interface

{ Starts music sequence 0 and runs the title sequence. }
procedure Introduction;

implementation

uses Types, C_Pic, GDVars, GameIo, TextRend, Mouse, Border, Blit, Music, Portrait;

const
  { the data set the TITLE pictures load from }
  TITLE_DATA_SET = 6;
  { credits color, yellow: the first line }
  CREDITS_BANNER = 14;
  { credits color, white: each role }
  CREDITS_HEADING = 15;
  { credits color, light green: the names }
  CREDITS_NAME = 10;
  { the DAC entries $10..$FF the last title picture loads }
  TITLE_DAC_FIRST = $10;
  TITLE_DAC_COUNT = 240;

{ Waits until the time runs out or input arrives. The once-a-second sample in the loop is a hook for per-second work and
  does nothing here.
  @param(seconds The wait.)
  @returns(True when input cut the wait short.) }
function DelayOrKey(seconds: Word): Boolean;
var
  base: LongInt;
  target: LongInt;
  sample: LongInt;
begin
  GameIo.FlushKeys;
  base := TextRend.GetTicks;
  target := base + seconds * 100;
  sample := TextRend.GetTicks;
  repeat
    if TextRend.GetTicks - sample >= 100 then
      sample := TextRend.GetTicks
  until GameIo.InputPending or (TextRend.GetTicks >= target);
  if TextRend.GetTicks >= target then
    DelayOrKey := False else DelayOrKey := True;
  GameIo.FlushKeys
end;

{ Shows the mouse, marks the game up and puts the data set back. }
procedure FinishIntroduction;
begin
  Mouse.ShowMouse;
  GDVars.isGameUp := True;
  GDVars.dataSet := GDVars.oldDataSet
end;

{ Shows the credits screen in the view palette for 20 seconds or until input, then clears the screen. }
procedure Credits;
begin
  Blit.SetDacPalette(C_Pic.VIEW_DAC_FIRST, C_Pic.VIEW_DAC_COUNT, GDVars.viewPalette);
  TextRend.ClearScreen;
  Border.ScreenCredits;
  TextRend.DisplayString(2, 1, Intro.CREDITS_BANNER, 0, 'CREATED BY:SSI SPECIAL PROJECTS TEAM');
  TextRend.DisplayString(2, 3, Intro.CREDITS_HEADING, 0, 'GAME DEVELOPMENT:');
  TextRend.DisplayString(21, 3, Intro.CREDITS_HEADING, 0, 'PROGRAMMING:');
  TextRend.DisplayString(2, 4, Intro.CREDITS_NAME, 0, 'Rhonda Gilbert');
  TextRend.DisplayString(21, 4, Intro.CREDITS_NAME, 0, 'Russ Brown');
  TextRend.DisplayString(21, 5, Intro.CREDITS_NAME, 0, 'Kerry Bonin');
  TextRend.DisplayString(2, 6, Intro.CREDITS_HEADING, 0, 'ENCOUNTER CODE:');
  TextRend.DisplayString(2, 7, Intro.CREDITS_NAME, 0, 'Dave Shelley');
  TextRend.DisplayString(20, 7, Intro.CREDITS_HEADING, 0, 'GRAPHIC ARTS:');
  TextRend.DisplayString(2, 8, Intro.CREDITS_NAME, 0, 'Chris Carr');
  TextRend.DisplayString(20, 8, Intro.CREDITS_NAME, 0, 'Laura Bowen');
  TextRend.DisplayString(2, 9, Intro.CREDITS_NAME, 0, 'Tom Ono');
  TextRend.DisplayString(20, 9, Intro.CREDITS_NAME, 0, 'Fred Butts');
  TextRend.DisplayString(2, 10, Intro.CREDITS_NAME, 0, 'Ken Eklund');
  TextRend.DisplayString(20, 10, Intro.CREDITS_NAME, 0, 'Maurine Starkey');
  TextRend.DisplayString(2, 11, Intro.CREDITS_NAME, 0, 'Tony Van');
  TextRend.DisplayString(20, 11, Intro.CREDITS_NAME, 0, 'Mike Provenza');
  TextRend.DisplayString(2, 12, Intro.CREDITS_NAME, 0, 'Gary Shockley');
  TextRend.DisplayString(20, 12, Intro.CREDITS_NAME, 0, 'Mark Johnson');
  TextRend.DisplayString(2, 13, Intro.CREDITS_NAME, 0, 'Cynthia Huang');
  TextRend.DisplayString(20, 13, Intro.CREDITS_NAME, 0, 'Cyrus Lum');
  TextRend.DisplayString(2, 14, Intro.CREDITS_NAME, 0, 'Adragon Demello');
  TextRend.DisplayString(20, 14, Intro.CREDITS_NAME, 0, 'Susan Manley');
  TextRend.DisplayString(2, 16, Intro.CREDITS_HEADING, 0, 'MUSIC:');
  TextRend.DisplayString(9, 16, Intro.CREDITS_NAME, 0, 'Ralph Thomas & The Fat Man');
  TextRend.DisplayString(2, 18, Intro.CREDITS_HEADING, 0, 'PLAYTEST :');
  TextRend.DisplayString(13, 18, Intro.CREDITS_NAME, 0, 'John Boockholdt, Al Brown,');
  TextRend.DisplayString(2, 19, Intro.CREDITS_NAME, 0, 'Glen Cureton, Mike Gilmartin,');
  TextRend.DisplayString(2, 20, Intro.CREDITS_NAME, 0, 'Cyrus Harris, Rob Lupo, Sean House,');
  TextRend.DisplayString(2, 21, Intro.CREDITS_NAME, 0, 'John Kirk, Alan Marenco, Brian Lowe,');
  TextRend.DisplayString(2, 22, Intro.CREDITS_NAME, 0, 'Jeff Shotwell, Larry Webber,');
  TextRend.DisplayString(2, 23, Intro.CREDITS_NAME, 0, 'Chris Warshauer, James Young');
  { input only cuts the wait short }
  if Intro.DelayOrKey(20) then;
  TextRend.ClearScreen
end;

procedure Introduction;
var
  pic: Types.PImgBuf;
  { Unused in this version; see the other implementations of this routine. }
  keyed: Boolean;

  { Shows the last title picture on a cleared screen. }
  procedure ShowLastTitle;
  begin
    pic := nil;
    Blit.LoadPic('title', 4, False, 0, pic);
    TextRend.ClearScreen;
    Blit.SetDacPalette(Intro.TITLE_DAC_FIRST, Intro.TITLE_DAC_COUNT, GDVars.picturePalette);
    Blit.ShowPic(0, 0, pic);
    Blit.FreePic(pic)
  end;

begin
  Music.StartMusic(0);
  pic := nil;
  Portrait.FreeAnimation;
  Mouse.HideMouse;
  TextRend.ClearScreen;
  GDVars.oldDataSet := GDVars.dataSet;
  GDVars.dataSet := Intro.TITLE_DATA_SET;
  Blit.LoadPic('title', 1, False, 0, pic);
  Blit.SetDacPalette(C_Pic.VIEW_DAC_FIRST, C_Pic.VIEW_DAC_COUNT, GDVars.picturePalette);
  Blit.ShowPic(0, 7, pic);
  Blit.FreePic(pic);
  if Intro.DelayOrKey(5) then begin
    Intro.Credits;
    ShowLastTitle;
    Intro.FinishIntroduction;
    Exit
  end;
  Blit.LoadPic('title', 2, False, 0, pic);
  TextRend.ClearScreen;
  Blit.ShowPic(2, 1, pic);
  Blit.FreePic(pic);
  Blit.LoadPic('title', 3, False, 0, pic);
  Blit.ShowPic(3, 21, pic);
  Blit.FreePic(pic);
  if Intro.DelayOrKey(5) then begin
    Intro.Credits;
    ShowLastTitle;
    Intro.FinishIntroduction;
    Exit
  end;
  Intro.Credits;
  ShowLastTitle;
  Intro.FinishIntroduction;
  Exit
end;

begin
end.

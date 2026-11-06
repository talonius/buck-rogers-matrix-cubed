{ A debug display, active while GDVars.isDebugMode (GameIo's Ctrl-D) is set. Both callers are combat's: CombatSt's
  CombatStart shows the name of each entry on the party list (the loaded monsters too) with its status and enabled
  bytes, and FxEngine's AttackRoll shows 'thac0' with the attack bonus, target and modifier. The unit owns no state. }
{$O+,F+}
unit Debug;

interface

uses Types, GDVars, Crt, TextRend;

{ While the debug display is on, shows three numbers on the top text row, pauses on a message, and clears the row again;
  otherwise does nothing.
  @param(msg The message shown with the pause.)
  @param(a The first number shown.)
  @param(b The second number shown.)
  @param(c The third number shown.) }
procedure PrintDebug(msg: Types.TString40; a, b, c: Byte);

implementation

procedure PrintDebug(msg: Types.TString40; a, b, c: Byte);
var
  firstText: String;
  secondText: String;
  thirdText: String;
  { Unused in this version; see the other implementations of this routine. }
  index: Byte;
begin
  if GDVars.isDebugMode then begin
    Str(a, firstText);
    Str(b, secondText);
    Str(c, thirdText);
    TextRend.ClearRect(0, 0, 39, 0);
    TextRend.DisplayString(0, 0, Yellow, Black, firstText + ' , ' + secondText + ' , ' + thirdText);
    TextRend.DisplayAndPause(Yellow, Black, msg);
    TextRend.ClearRect(0, 0, 39, 0)
  end
end;

begin
end.

{ The Log Book copy protection, which FixMain runs before play. Each stage of CopyProtection sets one of
  GDVars.protectionFlags; FixMain quits if any is still clear, so skipping the check by patching the result alone does
  not get the player into the game. }
{$O+,F+,A-}
unit CopyProt;

interface

{ Asks for a word from the log book, up to three times, each time a random question. The answer is matched case-blind:
  ReadString upper-cases the typed word, and the expected one is upper-cased to match.
  @returns(True when an answer matched.) }
function CopyProtection: Boolean;

implementation

uses Crt, Border, TextRend, GDConsts, GDVars, Types;

const
  MAX_ATTEMPTS = 3;
  { ReadString's limit on the typed answer }
  ANSWER_MAX_LENGTH = 20;

function CopyProtection: Boolean;
var
  i: Byte;
  entryNumber: Byte;
  attempt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  index: Byte;
  expected: String;
  reply: String;

  { Reverses an encoded answer and takes its length off each character's code. }
  function Decode(source: String): String;
  var
    result: String;
    i: Byte;
    limit: Byte;
  begin
    limit := Length(source);
    result := '';
    for i := limit downto 1 do
      result := result + Chr(Ord(source[i]) - limit);
    Decode := result
  end;

  { The width of the ordinal word wordOrdinals[ordinal] plus one space, where the question's tail starts. }
  function OrdinalWidth(ordinal: Byte): Byte;
  begin
    case ordinal of
      7: OrdinalWidth := 8;
      2, 4, 8: OrdinalWidth := 7
    else
      OrdinalWidth := 6
    end
  end;

begin
  FillChar(GDVars.protectionFlags, SizeOf(GDVars.protectionFlags), 0);
  Border.DrawWindowFrame(1);
  attempt := 0;
  entryNumber := 0;
  repeat
    Inc(attempt);
    expected := '';
    entryNumber := Random(SizeOf(GDConsts.logBookEntries) div SizeOf(Types.TLogBookEntry)) + 1;
    with GDConsts.logBookEntries[entryNumber] do begin
      GDVars.protectionFlags[1] := 1;
      TextRend.DisplayString(3, 2, LightGreen, Black, GDConsts.logBookPrompt);
      TextRend.DisplayString(29, 2, White, Black, TextRend.ByteToString(page) + '   ');
      TextRend.DisplayString(3, 4, LightGreen, Black, GDConsts.headingPrompt);
      Border.ClearBox(1, 5, 38, 5);
      TextRend.DisplayString(20 - headingLen div 2, 5, White, Black, Decode(heading));
      TextRend.DisplayString(3, 7, LightGreen, Black, GDConsts.questionHead + '  ');
      TextRend.DisplayString(15, 7, White, Black, GDConsts.wordOrdinals[wordIndex] + ' ');
      TextRend.DisplayString(OrdinalWidth(wordIndex) + 15, 7, LightGreen, Black, GDConsts.questionTail);
      GDVars.protectionFlags[2] := 1;
      expected := Decode(answer);
      reply := TextRend.ReadString('', Yellow, Black, CopyProt.ANSWER_MAX_LENGTH);
      for i := 1 to Length(expected) do
        expected[i] := UpCase(expected[i])
    end;
  until (attempt = CopyProt.MAX_ATTEMPTS) or (reply = expected);
  GDVars.protectionFlags[3] := 1;
  if reply = expected then
    CopyProtection := True
  else
    CopyProtection := False;
  GDVars.protectionFlags[4] := 1;
end;

begin
end.

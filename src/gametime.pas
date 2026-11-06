{ The game clock and what time does to the party: advancing zone 0's clock, carrying each unit into the next, running
  effect durations down, and resting. GDVars.effectFlags lets TimeOutEffects skip members with nothing running down
  while the party camps. }
{$O+,F+,A-}
unit GameTime;

interface

{ Advances zone 0's game clock by amount of one clock unit, then has TimeOutEffects run the party's effects down by
  amount of that unit. Note: for segments, the clock's smallest unit, that is amount minutes, ten times the clock's
  advance.
  @param(amount The count of clock units to advance by.)
  @param(timeUnit The clock unit, from segments (0) to years (6).) }
procedure AdvanceTime(amount: Byte; timeUnit: ShortInt);

{ Advances the clock by amount days and gives each party member who is okay or unconscious amount hit points, up to the
  maximum; the unconscious come round and every member healed is enabled.
  @param(amount The days of rest, and the hit points each member gains.) }
procedure RestAndHeal(amount: Byte);

implementation

uses Types, C_Status, GDConsts, GDVars, FxEngine, C_Ifc, C_Time;

const
  { the clock's smallest unit, as GDConsts.clockUnitScale carries them: ten segments make a minute }
  TIME_SEGMENT = 0;
  { the clock unit RestAndHeal advances by }
  TIME_DAY = 4;
  { the clock's largest unit }
  TIME_YEAR = 6;
  { zone 0's clock, one cell per unit from TIME_SEGMENT }
  GBVM_CLOCK = $4BC6;
  { the most minutes TimeOutEffects takes off a duration at once }
  MAX_EFFECT_STEP = 10;

type
  TClock = array[GameTime.TIME_SEGMENT..GameTime.TIME_YEAR] of Word;

{ Runs the party's effect durations, which count minutes, down by count of clock unit timeUnit, converted to minutes for
  units above C_Time.MINUTES and taken at most 10 at a time, removing each effect that runs out. Outside C_Ifc.CAMPING
  every member is checked; in it, only members effectFlags still marks, and nothing when none is marked. Note: a count
  of segments is taken as minutes, unconverted. And after an effect runs out, the walk resumes at the head of the list
  when the effect before it was the head, and otherwise at the second effect the list began with, so effects already
  passed can lose another step, and that second effect may by then have been freed.
  @param(count The count of clock units that passed.)
  @param(timeUnit The clock unit, from segments (0) to years (6).) }
procedure TimeOutEffects(count: Byte; timeUnit: ShortInt);
var
  u: ShortInt;
  i: Byte;
  step: Byte;
  total: Word;
  cur: Types.PCharRecord;
  isDone: Boolean;
  isFound: Boolean;
  tail: Types.PEffectRec;
  prev: Types.PEffectRec;
  next: Types.PEffectRec;
  effect: Types.PEffectRec;
begin
  if GDVars.interfaceState <> C_Ifc.CAMPING then
    FillChar(GDVars.effectFlags, SizeOf(GDVars.effectFlags), 1)
  else begin
    isFound := False;
    i := 1;
    repeat
      if GDVars.effectFlags[i] <> 0 then isFound := True;
      Inc(i)
    until isFound or (i > GDVars.zone1^.partyCount);
    if not isFound then Exit
  end;
  total := count;
  u := timeUnit;
  while u > C_Time.MINUTES do begin
    total := GDConsts.clockUnitScale[Pred(u)] * total;
    u := Pred(u)
  end;
  while total > 0 do begin
    if total > GameTime.MAX_EFFECT_STEP then step := GameTime.MAX_EFFECT_STEP else step := total;
    i := 1;
    cur := GDVars.partyHead;
    while cur <> nil do begin
      if GDVars.effectFlags[i] <> 0 then begin
        GDVars.effectFlags[i] := 0;
        effect := cur^.effectsAddr;
        tail := cur^.effectsAddr;
        prev := cur^.effectsAddr;
        next := prev^.next;
        if cur^.effectsAddr <> nil then
          while tail^.next <> nil do tail := tail^.next;
        isDone := False;
        while (effect <> nil) and not isDone do begin
          if effect = tail then isDone := True;
          if effect^.duration = 0 then
            effect := effect^.next
          else if step < effect^.duration then begin
            Dec(effect^.duration, step);
            GDVars.effectFlags[i] := 1;
            effect := effect^.next
          end else begin
            FxEngine.RemoveEffect(cur, effect^.effectId, effect);
            if prev = cur^.effectsAddr then
              effect := cur^.effectsAddr
            else
              effect := next
          end;
          prev := cur^.effectsAddr;
          while (prev <> nil) and (prev <> effect) and (prev^.next <> effect) do
            prev := prev^.next
        end;
        while effect <> nil do begin
          if effect^.duration > 0 then GDVars.effectFlags[i] := 1;
          effect := effect^.next
        end
      end;
      Inc(i);
      cur := cur^.nextCharAddr
    end;
    if total > GameTime.MAX_EFFECT_STEP then Dec(total, GameTime.MAX_EFFECT_STEP) else total := 0
  end
end;

{ Carries each clock unit that has reached its clockUnitScale into the next; the last unit's carry ages every party
  member a year, takes the carried years off the clock and sets hasCenturyPassed.
  @param(clock The clock, normalized in place.) }
procedure ValidateClock(var clock: TClock);
var
  i: ShortInt;
  cur: Types.PCharRecord;
begin
  for i := GameTime.TIME_SEGMENT to GameTime.TIME_YEAR do begin
    if clock[i] >= GDConsts.clockUnitScale[i] then begin
      if i <> GameTime.TIME_YEAR then begin
        Inc(clock[Succ(i)]);
        clock[i] := clock[i] - GDConsts.clockUnitScale[i]
      end else begin
        cur := GDVars.partyHead;
        while cur <> nil do begin
          Inc(cur^.age);
          cur := cur^.nextCharAddr
        end;
        clock[GameTime.TIME_YEAR] := clock[GameTime.TIME_YEAR] - GDConsts.clockUnitScale[GameTime.TIME_YEAR];
        GDVars.hasCenturyPassed := True
      end
    end
  end
end;

procedure AdvanceTime(amount: Byte; timeUnit: ShortInt);
var
  clock: TClock;
  i: ShortInt;
  j: Byte;
begin
  for i := GameTime.TIME_SEGMENT to GameTime.TIME_YEAR do
    clock[i] := GDVars.zone0^.clock.units[GameTime.GBVM_CLOCK + i];
  for j := 1 to amount do begin
    Inc(clock[timeUnit]);
    GameTime.ValidateClock(clock)
  end;
  for i := GameTime.TIME_SEGMENT to GameTime.TIME_YEAR do
    GDVars.zone0^.clock.units[GameTime.GBVM_CLOCK + i] := clock[i];
  GameTime.TimeOutEffects(amount, timeUnit)
end;

procedure RestAndHeal(amount: Byte);
var cur: Types.PCharRecord;
begin
  GameTime.AdvanceTime(amount, GameTime.TIME_DAY);
  cur := GDVars.partyHead;
  while cur <> nil do begin
    if cur^.status = C_Status.UNCONSCIOUS then cur^.status := C_Status.OKAY;
    if cur^.status = C_Status.OKAY then begin
      cur^.enabled := 1;
      Inc(cur^.hitPoints, amount);
      if cur^.hitPoints > cur^.hpMax then
        cur^.hitPoints := cur^.hpMax
    end;
    cur := cur^.nextCharAddr
  end
end;

begin
end.

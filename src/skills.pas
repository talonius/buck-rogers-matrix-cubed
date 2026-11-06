{ The skill screen: spending career and general skill points group by group, with the prerequisites skills demand of
  each other, and the read-only list of a character's general skills; also a new character's starting skill levels. The
  screen's state (the group shown, the count of general skills known, the view-only switch) and the skill lists it
  builds (skillList, groupStart and groupEnd) are GDVars'. }
{$A-,O+,F+,V-}
unit Skills;

interface

uses Types, C_Menu, GDConsts, GDVars, Crt, CharHlp, TextRend, Border, MenuCore, C_Skill,
  C_Ifc, C_Career, C_Group, C_Keys;

{ Lets the player spend careerPoints on the current character's career skills, then generalPoints on the general ones,
  at most maxPerSkill a skill this time.
  @param(careerPoints The points for the career skills.)
  @param(generalPoints The points for the general skills.)
  @param(maxPerSkill 0, with isNewCharacter 0, only lists the general skills the character has.)
  @param(isNewCharacter Non-zero (CharGen's character creation): each skill's floor, and the base of its maxPerSkill
    cap, is its StartingSkillLevel rather than its present level.) }
procedure EditSkills(careerPoints, generalPoints, maxPerSkill: Word; isNewCharacter: Byte);

{ Gives the level a character starts a skill at.
  @param(cr The character.)
  @param(skill The skill.)
  @returns(10 for the skills its career favors when it meets their prerequisites, otherwise 0.) }
function StartingSkillLevel(cr: Types.PCharRecord; skill: ShortInt): ShortInt;

{ Gives cr its career's starting skills from GDConsts.careerInitialSkills.
  @param(cr The character.) }
procedure ApplyInitialSkills(cr: Types.PCharRecord);

implementation

const
  { the level StartingSkillLevel gives a skill the career favors }
  FAVORED_START = 10;
  { the most points a general skill can take }
  MAX_GENERAL_LEVEL = 80;
  { the level CharGen gives a new character }
  NEW_CHARACTER_LEVEL = 7;
  { the general skills a new character may learn }
  NEW_CHARACTER_GENERAL_SKILLS = 12;
  { the screen column the points and each skill's level are shown in }
  POINTS_COLUMN = 23;
  { TSkill.group with no skill in it, as skillGroupNames heads it: the general skills are all listed under it to view
    them }
  GROUP_CONSTITUTION = 2;
  { the Read Lips skill's skillDefinitions row and TCharRecord.skillLevels index }
  READ_LIPS = 82;

function StartingSkillLevel(cr: Types.PCharRecord; skill: ShortInt): ShortInt;
begin
  StartingSkillLevel := 0;
  if CharHlp.MeetsSkillPrerequisite(cr, Byte(skill)) then
    if ((cr^.career = C_Career.ROCKET_JOCK) and (skill >= C_Skill.PILOT_ROCKET) and
        (skill <= C_Skill.DRIVE_JETCAR)) or
        ((cr^.career = C_Career.ROGUE) and
         ((skill = C_Skill.BYPASS_SECURITY) or (skill = C_Skill.OPEN_LOCK) or
          (skill = C_Skill.MOVE_SILENTLY) or (skill = C_Skill.PICK_POCKETS) or
          (skill = C_Skill.HIDE_IN_SHADOWS) or (skill = C_Skill.CLIMB) or
          (skill = C_Skill.ANIMAL_TRAINING) or (skill = Skills.READ_LIPS) or
          (skill = C_Skill.NOTICE) or (skill = C_Skill.FAST_TALK))) then
      StartingSkillLevel := Skills.FAVORED_START
end;

procedure ApplyInitialSkills(cr: Types.PCharRecord);
var
  skill: Byte;
  value: Byte;
  index: Byte;
begin
  index := 1;
  repeat
    skill := GDConsts.careerInitialSkills[cr^.career, index].skill;
    value := GDConsts.careerInitialSkills[cr^.career, index].value;
    if skill <> 0 then cr^.skillLevels[skill] := value;
    Inc(index)
  until (skill = 0) or (index > SizeOf(GDConsts.careerInitialSkills[cr^.career]) div SizeOf(Types.TInitialSkill))
end;

{ Fills skillList, groupStart and groupEnd for the current character: its career's eight skills, then by group each
  other skill skillDefinitions offers except the medical ones (only those it has when isViewOnly), and counts the
  general skills it knows. }
procedure BuildSkillLists;
var
  skill: ShortInt;
  offset: ShortInt;
  group: ShortInt;
begin
  FillChar(GDVars.skillList, SizeOf(GDVars.skillList), 0);
  FillChar(GDVars.groupStart, SizeOf(GDVars.groupStart), 0);
  FillChar(GDVars.groupEnd, SizeOf(GDVars.groupEnd), 0);
  GDVars.groupStart[C_Group.CAREER] := 1;
  GDVars.groupEnd[C_Group.CAREER] := SizeOf(GDConsts.careerSkills[GDVars.currentCharacter^.career]);
  for skill := 1 to SizeOf(GDConsts.careerSkills[GDVars.currentCharacter^.career]) do
    GDVars.skillList[skill] := GDConsts.careerSkills[GDVars.currentCharacter^.career, skill];
  group := GDConsts.skillDefinitions[1].group;
  GDVars.groupStart[group] := SizeOf(GDConsts.careerSkills[GDVars.currentCharacter^.career]) + 1;
  offset := SizeOf(GDConsts.careerSkills[GDVars.currentCharacter^.career]);
  GDVars.knownGeneralCount := 0;
  for skill := 1 to SizeOf(GDConsts.skillDefinitions) div SizeOf(Types.TSkill) do begin
    if (skill <> GDVars.skillList[1]) and (skill <> GDVars.skillList[2]) and (skill <> GDVars.skillList[3]) and
        (skill <> GDVars.skillList[4]) and (skill <> GDVars.skillList[5]) and (skill <> GDVars.skillList[6]) and
        (skill <> GDVars.skillList[7]) and (skill <> GDVars.skillList[8]) and
        not ((skill >= C_Skill.FIRST_MEDICAL_SKILL) and (skill <= C_Skill.LAST_MEDICAL_SKILL)) and
        (not GDVars.isViewOnly or Boolean(CharHlp.SkillValue(GDVars.currentCharacter, Byte(skill)))) and
        (GDConsts.skillDefinitions[skill].enabled <> 0) then begin
      if GDVars.currentCharacter^.skillLevels[skill] > 0 then Inc(GDVars.knownGeneralCount);
      GDVars.skillList[skill + offset] := skill;
      if GDConsts.skillDefinitions[skill].group <> group then begin
        GDVars.groupEnd[group] := skill + offset - 1;
        group := GDConsts.skillDefinitions[skill].group;
        GDVars.groupStart[group] := skill + offset
      end
    end else
      Dec(offset)
  end;
  GDVars.groupEnd[group] := skill + offset;
  GDVars.groupStart[Skills.GROUP_CONSTITUTION] := SizeOf(GDConsts.careerSkills[GDVars.currentCharacter^.career]) +
    1;
  GDVars.groupEnd[Skills.GROUP_CONSTITUTION] := skill + offset
end;

{ Shows the points left at the top of the skill screen.
  @param(n The points left.) }
procedure PrintSkillNumber(n: Word);
begin
  TextRend.DisplayString(Skills.POINTS_COLUMN, 1, White, Black, TextRend.WordToString(n) + ' ')
end;

{ Draws the skill screen for a group, the whole screen when asked, then redraws the previous and the selected row, the
  selected one highlighted with its unmet prerequisites listed below.
  @param(group The skill group shown.)
  @param(selectedGroup The highlighted row, counted from 1 within the group.)
  @param(previousGroup The row highlighted before it.)
  @param(careerPoints The points shown as left to spend.)
  @param(maxPerSkill The most points a skill may take this time, shown.)
  @param(active Set to draw the whole screen first; clear to redraw only the two rows.) }
procedure SkillScreen(group: ShortInt; selectedGroup, previousGroup: Integer; careerPoints, maxPerSkill: Word;
                      active: Byte);
var
  i: Byte;
  count: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rowBuffer: array[1..512] of Byte;

  { Draws one skill row of the group, highlighted or not, with its unmet prerequisites below when highlighted. }
  procedure DrawSkillRow(index: Byte; highlight: Boolean);
  var
    name: String[25];
    color: Byte;
    x: Byte;
    row: Byte;
    skill: Byte;
    textRow: Byte;

    { Prints 'Needs required points in skill' on the next line while the character has fewer. }
    procedure PrintPrerequisite(skill, required: Byte);
    var name: String[18];
    begin
      if GDVars.currentCharacter^.skillLevels[skill] < required then begin
        name := GDConsts.skillDefinitions[skill].name;
        TextRend.DisplayString(1, textRow, LightRed, Black,
                               'Needs ' + TextRend.ByteToString(required) + ' points in ' + name);
        Inc(textRow)
      end
    end;

  begin
    skill := GDVars.skillList[GDVars.groupStart[group] + index - 1];
    x := 1;
    if GDVars.isViewOnly then
      row := index + 3
    else
      row := index + 5;
    if CharHlp.MeetsSkillPrerequisite(GDVars.currentCharacter, Byte(skill)) then
      color := LightGreen
    else
      color := Yellow;
    if highlight and (index = selectedGroup) and not GDVars.isViewOnly then begin
      Border.ClearBox(1, 21, 38, 22);
      if not CharHlp.MeetsSkillPrerequisite(GDVars.currentCharacter, Byte(skill)) then begin
        textRow := 21;
        case skill of
          C_Skill.REPAIR_ENGINE: PrintPrerequisite(C_Skill.REPAIR_MECHANICAL,
                                                       C_Skill.REPAIR_ENGINE_NEEDS_MECHANICAL);
          C_Skill.REPAIR_LIFE_SUPPORT: begin
                 PrintPrerequisite(C_Skill.REPAIR_MECHANICAL, C_Skill.REPAIR_LIFE_SUPPORT_NEEDS_MECHANICAL);
                 PrintPrerequisite(C_Skill.REPAIR_ELECTRICAL, C_Skill.REPAIR_LIFE_SUPPORT_NEEDS_ELECTRICAL)
               end;
          C_Skill.REPAIR_HULL: PrintPrerequisite(C_Skill.REPAIR_MECHANICAL,
                                                 C_Skill.REPAIR_HULL_NEEDS_MECHANICAL);
          C_Skill.JURY_RIG: begin
                 PrintPrerequisite(C_Skill.REPAIR_MECHANICAL, C_Skill.JURY_RIG_NEEDS_MECHANICAL);
                 PrintPrerequisite(C_Skill.REPAIR_ELECTRICAL, C_Skill.JURY_RIG_NEEDS_ELECTRICAL)
               end;
          C_Skill.REPAIR_COMPUTER: PrintPrerequisite(C_Skill.REPAIR_ELECTRICAL,
                                                         C_Skill.REPAIR_COMPUTER_NEEDS_ELECTRICAL);
          C_Skill.TREAT_SERIOUS: PrintPrerequisite(C_Skill.TREAT_LIGHT,
                                                   C_Skill.TREAT_SERIOUS_NEEDS_TREAT_LIGHT);
          C_Skill.TREAT_CRITICAL: begin
                 PrintPrerequisite(C_Skill.TREAT_SERIOUS, C_Skill.TREAT_CRITICAL_NEEDS_TREAT_SERIOUS);
                 { Serious's own need, listed here too; MeetsSkillPrerequisite asks it of Serious only }
                 PrintPrerequisite(C_Skill.TREAT_LIGHT, C_Skill.TREAT_SERIOUS_NEEDS_TREAT_LIGHT)
               end;
          C_Skill.TREAT_POISONING: PrintPrerequisite(C_Skill.DIAGNOSE,
                                                     C_Skill.TREAT_POISONING_NEEDS_DIAGNOSE);
          C_Skill.TREAT_DISEASE: PrintPrerequisite(C_Skill.DIAGNOSE, C_Skill.TREAT_DISEASE_NEEDS_DIAGNOSE);
          C_Skill.PROGRAMMING: PrintPrerequisite(C_Skill.MATHEMATICS,
                                                 C_Skill.PROGRAMMING_NEEDS_MATHEMATICS);
          C_Skill.ASTROGATION: begin
                 PrintPrerequisite(C_Skill.ASTRONOMY, C_Skill.ASTROGATION_NEEDS_ASTRONOMY);
                 PrintPrerequisite(C_Skill.MATHEMATICS, C_Skill.ASTROGATION_NEEDS_MATHEMATICS)
               end;
          C_Skill.NAVIGATION: begin
                 PrintPrerequisite(C_Skill.ASTRONOMY, C_Skill.NAVIGATION_NEEDS_ASTRONOMY);
                 PrintPrerequisite(C_Skill.MATHEMATICS, C_Skill.NAVIGATION_NEEDS_MATHEMATICS)
               end;
          C_Skill.ANIMAL_TRAINING: PrintPrerequisite(C_Skill.BEFRIEND_ANIMAL,
                                                         C_Skill.ANIMAL_TRAINING_NEEDS_BEFRIEND_ANIMAL);
          C_Skill.PLANETARY_SURVIVAL: PrintPrerequisite(C_Skill.PLANETOLOGY,
                                                            C_Skill.PLANETARY_SURVIVAL_NEEDS_PLANETOLOGY)
        end
      end;
      color := LightMagenta
    end;
    name := GDConsts.skillDefinitions[skill].name;
    if GDVars.isViewOnly then begin
      TextRend.DisplayString(x, row, color, Black, name);
      TextRend.DisplayString(x + 25, row, color, Black,
                             TextRend.ByteToString(CharHlp.SkillValue(GDVars.currentCharacter, skill)))
    end else begin
      TextRend.DisplayString(1, row, color, Black, name);
      TextRend.DisplayString(Skills.POINTS_COLUMN, row, color, Black,
                             TextRend.ByteToString(GDVars.currentCharacter^.skillLevels[skill]) + ' ');
      TextRend.DisplayString(29, row, color, Black,
                             TextRend.ByteToString(Byte(CharHlp.SkillAbilityScore(GDVars.currentCharacter,
                                                                                  skill))) + ' ');
      TextRend.DisplayString(35, row, color, Black,
                             TextRend.ByteToString(CharHlp.SkillValue(GDVars.currentCharacter, skill)) + ' ')
    end;
    if not highlight then Inc(row)
  end;

begin
  count := GDVars.groupEnd[group] - GDVars.groupStart[group] + 1;
  if active <> 0 then begin
    Border.DrawWindowFrame(1);
    if GDVars.isViewOnly then
      TextRend.DisplayString(2, 2, LightGreen, Black, 'General skills')
    else begin
      if group = C_Group.CAREER then
        TextRend.DisplayString(1, 1, LightGreen, Black, 'Career skill points:')
      else
        TextRend.DisplayString(1, 1, LightGreen, Black, 'General skill points:');
      Skills.PrintSkillNumber(careerPoints);
      TextRend.DisplayString(1, 2, LightGreen, Black, 'Maximum per skill:');
      TextRend.DisplayString(Skills.POINTS_COLUMN, 2, White, Black, TextRend.ByteToString(maxPerSkill));
      TextRend.DisplayString(1, 4, LightGreen, Black, GDConsts.skillGroupNames[group]);
      TextRend.DisplayString(21, 4, LightGreen, Black, 'Points Bonus Total')
    end;
    for i := 1 to count do DrawSkillRow(i, False)
  end;
  if selectedGroup <> previousGroup then DrawSkillRow(previousGroup, True);
  DrawSkillRow(selectedGroup, True)
end;

procedure EditSkills(careerPoints, generalPoints, maxPerSkill: Word; isNewCharacter: Byte);
var
  savedInterfaceState: Byte;
  redraw: Byte;
  done: Byte;
  selected: Byte;
  previous: Byte;
  count: Byte;
  skill: Byte;
  points: Word;
  maxGeneral: ShortInt;
  menu: String;
  { each skill's floor: Subtract stops at it, and Add caps the skill at it plus maxPerSkill }
  oldSkills: array[1..84] of Byte;

  { Resets the skills that depend on changedSkill as it crosses their prerequisite; True when one was reset. }
  function AdjustPrerequisites(changedSkill: Byte; increasing: Boolean): Boolean;
  var
    hasReset: Boolean;

    { Resets dependent to its start when changedSkill just reached required; refunds and zeroes it when it fell below. }
    procedure ResetDependent(required, dependent: ShortInt);
    var
      base: ShortInt;
      refund: ShortInt;
    begin
      base := Skills.StartingSkillLevel(GDVars.currentCharacter, dependent);
      if increasing then begin
        if GDVars.currentCharacter^.skillLevels[changedSkill] = required then begin
          GDVars.currentCharacter^.skillLevels[dependent] := base;
          oldSkills[dependent] := base;
          hasReset := True
        end
      end else if GDVars.currentCharacter^.skillLevels[changedSkill] = required - 1 then begin
        oldSkills[dependent] := base;
        refund := GDVars.currentCharacter^.skillLevels[dependent] - base;
        if refund > 0 then begin
          if GDVars.currentGroup = C_Group.CAREER then begin
            Inc(points, refund);
            Inc(careerPoints, refund)
          end else begin
            Inc(points, refund);
            Inc(generalPoints, refund)
          end
        end;
        GDVars.currentCharacter^.skillLevels[dependent] := 0;
        hasReset := True
      end
    end;

  begin
    hasReset := False;
    case changedSkill of
      C_Skill.REPAIR_ELECTRICAL: begin
             ResetDependent(C_Skill.JURY_RIG_NEEDS_ELECTRICAL, C_Skill.JURY_RIG);
             ResetDependent(C_Skill.REPAIR_LIFE_SUPPORT_NEEDS_ELECTRICAL, C_Skill.REPAIR_LIFE_SUPPORT);
             ResetDependent(C_Skill.REPAIR_COMPUTER_NEEDS_ELECTRICAL, C_Skill.REPAIR_COMPUTER)
           end;
      C_Skill.REPAIR_MECHANICAL: begin
             ResetDependent(C_Skill.JURY_RIG_NEEDS_MECHANICAL, C_Skill.JURY_RIG);
             ResetDependent(C_Skill.REPAIR_HULL_NEEDS_MECHANICAL, C_Skill.REPAIR_HULL);
             ResetDependent(C_Skill.REPAIR_LIFE_SUPPORT_NEEDS_MECHANICAL, C_Skill.REPAIR_LIFE_SUPPORT);
             ResetDependent(C_Skill.REPAIR_ENGINE_NEEDS_MECHANICAL, C_Skill.REPAIR_ENGINE)
           end;
      C_Skill.TREAT_LIGHT: begin
             ResetDependent(C_Skill.TREAT_SERIOUS_NEEDS_TREAT_LIGHT, C_Skill.TREAT_SERIOUS);
             { at Serious's level, as the prerequisite lines list it }
             ResetDependent(C_Skill.TREAT_SERIOUS_NEEDS_TREAT_LIGHT, C_Skill.TREAT_CRITICAL)
           end;
      C_Skill.TREAT_SERIOUS: ResetDependent(C_Skill.TREAT_CRITICAL_NEEDS_TREAT_SERIOUS,
                                            C_Skill.TREAT_CRITICAL);
      C_Skill.DIAGNOSE: begin
             ResetDependent(C_Skill.TREAT_DISEASE_NEEDS_DIAGNOSE, C_Skill.TREAT_DISEASE);
             ResetDependent(C_Skill.TREAT_POISONING_NEEDS_DIAGNOSE, C_Skill.TREAT_POISONING)
           end;
      C_Skill.MATHEMATICS: begin
             ResetDependent(C_Skill.NAVIGATION_NEEDS_MATHEMATICS, C_Skill.NAVIGATION);
             ResetDependent(C_Skill.ASTROGATION_NEEDS_MATHEMATICS, C_Skill.ASTROGATION);
             ResetDependent(C_Skill.PROGRAMMING_NEEDS_MATHEMATICS, C_Skill.PROGRAMMING)
           end;
      C_Skill.PLANETOLOGY: ResetDependent(C_Skill.PLANETARY_SURVIVAL_NEEDS_PLANETOLOGY,
                                               C_Skill.PLANETARY_SURVIVAL);
      C_Skill.ASTRONOMY: begin
             ResetDependent(C_Skill.NAVIGATION_NEEDS_ASTRONOMY, C_Skill.NAVIGATION);
             ResetDependent(C_Skill.ASTROGATION_NEEDS_ASTRONOMY, C_Skill.ASTROGATION)
           end;
      { Note: Composition resets at 10, not the 20 CharHlp's MeetsSkillPrerequisite asks }
      C_Skill.LITERATURE: begin
             if (GDVars.currentCharacter^.skillLevels[C_Skill.PLAY_INSTRUMENT] < 10) and
                 (GDVars.currentCharacter^.skillLevels[C_Skill.SINGING] < 10) then
               ResetDependent(10, C_Skill.COMPOSITION)
           end;
      C_Skill.PLAY_INSTRUMENT: begin
             if (GDVars.currentCharacter^.skillLevels[C_Skill.SINGING] < 10) and
                 (GDVars.currentCharacter^.skillLevels[C_Skill.LITERATURE] < 10) then
               { overwritten at the end; ResetDependent runs either way }
               AdjustPrerequisites := False;
             ResetDependent(10, C_Skill.COMPOSITION)
           end;
      C_Skill.BEFRIEND_ANIMAL: ResetDependent(C_Skill.ANIMAL_TRAINING_NEEDS_BEFRIEND_ANIMAL,
                                                  C_Skill.ANIMAL_TRAINING);
      C_Skill.SINGING: begin
             if (GDVars.currentCharacter^.skillLevels[C_Skill.PLAY_INSTRUMENT] < 10) and
                 (GDVars.currentCharacter^.skillLevels[C_Skill.LITERATURE] < 10) then
               { overwritten at the end; ResetDependent runs either way }
               AdjustPrerequisites := False;
             ResetDependent(10, C_Skill.COMPOSITION)
           end
    end;
    AdjustPrerequisites := hasReset
  end;

  { Moves to the next group, or the one before; the career group leads into the technical one and is not returned to. }
  procedure ChangeGroup(next: Boolean);
  begin
    if next then begin
      case GDVars.currentGroup of
        C_Group.CAREER: begin
             GDVars.currentGroup := C_Group.TECHNICAL;
             points := generalPoints
           end;
        C_Group.TECHNICAL: GDVars.currentGroup := C_Group.INTELLIGENCE;
        C_Group.INTELLIGENCE: GDVars.currentGroup := C_Group.DEXTERITY;
        C_Group.DEXTERITY: GDVars.currentGroup := C_Group.CHARISMA;
        C_Group.CHARISMA: GDVars.currentGroup := C_Group.WISDOM;
        C_Group.WISDOM: GDVars.currentGroup := C_Group.TECHNICAL
      end
    end else begin
      case GDVars.currentGroup of
        C_Group.CAREER: Exit;
        C_Group.TECHNICAL: GDVars.currentGroup := C_Group.WISDOM;
        C_Group.INTELLIGENCE: GDVars.currentGroup := C_Group.TECHNICAL;
        C_Group.DEXTERITY: GDVars.currentGroup := C_Group.INTELLIGENCE;
        C_Group.CHARISMA: GDVars.currentGroup := C_Group.DEXTERITY;
        C_Group.WISDOM: GDVars.currentGroup := C_Group.CHARISMA
      end
    end;
    count := GDVars.groupEnd[GDVars.currentGroup] - GDVars.groupStart[GDVars.currentGroup] + 1;
    redraw := 1;
    previous := 1;
    selected := 1
  end;

begin
  GDVars.isViewOnly := (maxPerSkill = 0) and (isNewCharacter = 0);
  Skills.BuildSkillLists;
  if GDVars.isViewOnly and (GDVars.knownGeneralCount = 0) then begin
    CharHlp.PrintBottomLine(GDVars.currentCharacter^.name + ' has no general skills.');
    Exit
  end;
  savedInterfaceState := GDVars.interfaceState;
  if not GDVars.isViewOnly then GDVars.interfaceState := C_Ifc.EDITING_SKILLS;
  if GDVars.currentCharacter^.level = Skills.NEW_CHARACTER_LEVEL then
    maxGeneral := Skills.NEW_CHARACTER_GENERAL_SKILLS
  else
    maxGeneral := GDVars.knownGeneralCount + 1;
  done := 0;
  if GDVars.isViewOnly then
    GDVars.currentGroup := Skills.GROUP_CONSTITUTION
  else
    GDVars.currentGroup := C_Group.CAREER;
  count := GDVars.groupEnd[GDVars.currentGroup] - GDVars.groupStart[GDVars.currentGroup] + 1;
  selected := 1;
  previous := 1;
  points := careerPoints;
  Skills.SkillScreen(GDVars.currentGroup, selected, previous, careerPoints, maxPerSkill, 1);
  redraw := 0;
  if isNewCharacter <> 0 then begin
    FillChar(oldSkills, SizeOf(oldSkills), 0);
    for GDVars.loopIndex := 1 to SizeOf(oldSkills) do
      oldSkills[GDVars.loopIndex] := Skills.StartingSkillLevel(GDVars.currentCharacter, GDVars.loopIndex)
  end else
    Move(GDVars.currentCharacter^.skillLevels[1], oldSkills[1], SizeOf(oldSkills));
  repeat
    menu := '';
    if not GDVars.isViewOnly then begin
      menu := menu + 'Add Subtract ';
      if GDVars.currentGroup <> C_Group.CAREER then menu := menu + 'Prev Next '
    end;
    menu := menu + 'Done';
    MenuCore.MenuHorizontal('', menu, True, False);
    if (GDVars.clickedSkillLine > 0) and (GDVars.clickedSkillLine <= count) then begin
      GDVars.extFlag := False;
      if GDVars.menuKey = C_Keys.ENTER then begin
        GDVars.menuKey := 'A';
        GDVars.horizChoice := 1
      end else if GDVars.menuKey = C_Keys.ESCAPE then begin
        GDVars.menuKey := 'S';
        GDVars.horizChoice := 2
      end else
        GDVars.menuKey := C_Keys.NONE;
      if GDVars.clickedSkillLine <> selected then begin
        previous := selected;
        selected := GDVars.clickedSkillLine;
        Skills.SkillScreen(GDVars.currentGroup, selected, previous, points, maxPerSkill, redraw);
        redraw := 0
      end;
      GDVars.clickedSkillLine := C_Menu.NO_SKILL_LINE
    end;
    skill := GDVars.skillList[GDVars.groupStart[GDVars.currentGroup] + selected - 1];
    if GDVars.extFlag then begin
      case GDVars.menuKey of
        C_Keys.UP: begin
               previous := selected;
               if selected = 1 then selected := count else Dec(selected)
             end;
        C_Keys.DOWN: begin
               previous := selected;
               if selected = count then selected := 1 else Inc(selected)
             end;
        C_Keys.PAGE_DOWN, C_Keys.PAGE_UP:
          if (GDVars.currentGroup <> C_Group.CAREER) and (GDVars.currentGroup <> Skills.GROUP_CONSTITUTION) then
            ChangeGroup(GDVars.menuKey = C_Keys.PAGE_DOWN);
        { Note: meant as Escape, which MenuHorizontal answers as NONE }
        C_Keys.RIGHT_BRACKET: done := 1
      end;
      Skills.SkillScreen(GDVars.currentGroup, selected, previous, points, maxPerSkill, redraw);
      redraw := 0
    end else case GDVars.menuKey of
      'A': with GDVars.currentCharacter^ do begin
             if GDVars.currentGroup = C_Group.CAREER then begin
               if careerPoints <= 0 then
                 CharHlp.PrintBottomLine('No career skill points left')
               else if not CharHlp.MeetsSkillPrerequisite(GDVars.currentCharacter, Byte(skill)) then
                 CharHlp.PrintBottomLine('Prerequisites not satisfied')
               else if skillLevels[skill] >= oldSkills[skill] + maxPerSkill then
                 CharHlp.PrintBottomLine('Skill at maximum for this level')
               else begin
                 Dec(careerPoints);
                 Dec(points);
                 Inc(skillLevels[skill]);
                 if AdjustPrerequisites(skill, True) then begin
                   redraw := 1;
                   Skills.BuildSkillLists;
                   count := GDVars.groupEnd[GDVars.currentGroup] - GDVars.groupStart[GDVars.currentGroup] + 1
                 end
               end
             end else begin
               if generalPoints <= 0 then
                 CharHlp.PrintBottomLine('No general skill points left')
               else if skillLevels[skill] >= Skills.MAX_GENERAL_LEVEL then
                 CharHlp.PrintBottomLine('Skill at maximum for general skills')
               else if skillLevels[skill] >= oldSkills[skill] + maxPerSkill then
                 CharHlp.PrintBottomLine('Skill at maximum for this level')
               else if not CharHlp.MeetsSkillPrerequisite(GDVars.currentCharacter, Byte(skill)) then
                 CharHlp.PrintBottomLine('Prerequisites not satisfied')
               else if (skillLevels[skill] = Skills.StartingSkillLevel(GDVars.currentCharacter, skill)) and
                 (GDVars.knownGeneralCount >= maxGeneral) then
                 CharHlp.PrintBottomLine('No more new skills allowed this level')
               else begin
                 if skillLevels[skill] = Skills.StartingSkillLevel(GDVars.currentCharacter, skill) then
                   Inc(GDVars.knownGeneralCount);
                 Dec(generalPoints);
                 Dec(points);
                 Inc(skillLevels[skill]);
                 if AdjustPrerequisites(skill, True) then begin
                   redraw := 1;
                   Skills.BuildSkillLists;
                   count := GDVars.groupEnd[GDVars.currentGroup] - GDVars.groupStart[GDVars.currentGroup] + 1
                 end
               end
             end;
             Skills.SkillScreen(GDVars.currentGroup, selected, previous, points, maxPerSkill, redraw);
             redraw := 0;
             Skills.PrintSkillNumber(points)
           end;
      'S': with GDVars.currentCharacter^ do
             if skillLevels[skill] > oldSkills[skill] then begin
               if GDVars.currentGroup = C_Group.CAREER then
                 Inc(careerPoints)
               else
                 Inc(generalPoints);
               Inc(points);
               Dec(skillLevels[skill]);
               if skillLevels[skill] = Skills.StartingSkillLevel(GDVars.currentCharacter, skill) then
                 Dec(GDVars.knownGeneralCount);
               if AdjustPrerequisites(skill, False) then begin
                 redraw := 1;
                 Skills.BuildSkillLists
               end;
               Skills.SkillScreen(GDVars.currentGroup, selected, previous, points, maxPerSkill, redraw);
               redraw := 0;
               Skills.PrintSkillNumber(points)
             end;
      'D', C_Keys.NONE, C_Keys.ESCAPE:
        if GDVars.currentGroup = C_Group.CAREER then begin
          if (careerPoints = 0) or
              (MenuCore.YesNoMenu('some career points unspent. Exit?', C_Menu.DEFAULT_NO) = 'Y') then begin
            ChangeGroup(True);
            Skills.SkillScreen(GDVars.currentGroup, selected, previous, points, maxPerSkill, redraw);
            redraw := 0
          end else
            done := 0
        end else
          done := 1;
      'P': begin
             ChangeGroup(False);
             Skills.SkillScreen(GDVars.currentGroup, selected, previous, points, maxPerSkill, redraw);
             redraw := 0
           end;
      'N': begin
             ChangeGroup(True);
             Skills.SkillScreen(GDVars.currentGroup, selected, previous, points, maxPerSkill, redraw);
             redraw := 0
           end
    end;
    if (done <> 0) and (generalPoints <> 0) then
      if MenuCore.YesNoMenu('some general points unspent. Exit?', C_Menu.DEFAULT_NO) = 'N' then
        done := 0
  until done <> 0;
  GDVars.interfaceState := savedInterfaceState
end;

begin
end.

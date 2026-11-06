{ The skill numbers: GDConsts' skillDefinitions rows and TCharRecord.skillLevels' indices. }
unit C_Skill;

interface

const
  { the skillDefinitions rows (TCharRecord.skillLevels indices) the code refers to by name }
  REPAIR_ELECTRICAL = 1;
  REPAIR_MECHANICAL = 2;
  { Repair Nuclear Engine }
  REPAIR_ENGINE = 3;
  REPAIR_LIFE_SUPPORT = 4;
  { Repair Rocket Hull }
  REPAIR_HULL = 5;
  JURY_RIG = 6;
  BYPASS_SECURITY = 7;
  OPEN_LOCK = 8;
  DEMOLITIONS = 11;
  FIRST_AID = 13;
  REPAIR_WEAPON = 14;
  REPAIR_COMPUTER = 15;
  { Treat Light Wounds }
  TREAT_LIGHT = 17;
  { Treat Serious Wounds }
  TREAT_SERIOUS = 18;
  { Treat Critical Wounds }
  TREAT_CRITICAL = 19;
  TREAT_POISONING = 20;
  { Treat Stun/Paralysis }
  TREAT_STUN = 21;
  TREAT_DISEASE = 22;
  DIAGNOSE = 23;
  COMPOSITION = 26;
  MATHEMATICS = 27;
  PLANETOLOGY = 30;
  BATTLE_TACTICS = 31;
  ASTRONOMY = 36;
  LITERATURE = 38;
  PROGRAMMING = 43;
  ASTROGATION = 46;
  NAVIGATION = 47;
  PILOT_ROCKET = 51;
  DRIVE_GROUND_CAR = 53;
  USE_JETPACK = 56;
  DRIVE_JETCAR = 59;
  ANIMAL_RIDING = 60;
  HIDE_IN_SHADOWS = 61;
  MOVE_SILENTLY = 62;
  PICK_POCKETS = 63;
  CLIMB = 65;
  { Maneuver in 0G }
  MANEUVER_IN_0G = 67;
  { Play Instrumnt }
  PLAY_INSTRUMENT = 68;
  INTIMIDATE = 72;
  LEADERSHIP = 73;
  BEFRIEND_ANIMAL = 74;
  ANIMAL_TRAINING = 75;
  { Fast Talk/Convince }
  FAST_TALK = 76;
  SINGING = 77;
  TRACKING = 80;
  NOTICE = 83;
  PLANETARY_SURVIVAL = 84;
  { Life Suspension Tech; 16..23 are the medic's career skills, which CharHlp's MeetsSkillPrerequisite opens to medics
    only and Skills leaves out of the general list }
  FIRST_MEDICAL_SKILL = 16;
  { Diagnose }
  LAST_MEDICAL_SKILL = 23;
  { the level in another skill that a skill requires, for CharHlp's MeetsSkillPrerequisite and Skills' prerequisite
    lines and resets: <skill>_NEEDS_<skill> }
  REPAIR_ENGINE_NEEDS_MECHANICAL = 10;
  REPAIR_LIFE_SUPPORT_NEEDS_ELECTRICAL = 30;
  REPAIR_LIFE_SUPPORT_NEEDS_MECHANICAL = 25;
  REPAIR_HULL_NEEDS_MECHANICAL = 10;
  JURY_RIG_NEEDS_ELECTRICAL = 10;
  JURY_RIG_NEEDS_MECHANICAL = 10;
  REPAIR_COMPUTER_NEEDS_ELECTRICAL = 40;
  TREAT_SERIOUS_NEEDS_TREAT_LIGHT = 30;
  TREAT_CRITICAL_NEEDS_TREAT_SERIOUS = 40;
  TREAT_POISONING_NEEDS_DIAGNOSE = 15;
  TREAT_DISEASE_NEEDS_DIAGNOSE = 25;
  PROGRAMMING_NEEDS_MATHEMATICS = 10;
  ASTROGATION_NEEDS_ASTRONOMY = 20;
  ASTROGATION_NEEDS_MATHEMATICS = 25;
  NAVIGATION_NEEDS_ASTRONOMY = 15;
  NAVIGATION_NEEDS_MATHEMATICS = 25;
  ANIMAL_TRAINING_NEEDS_BEFRIEND_ANIMAL = 20;
  PLANETARY_SURVIVAL_NEEDS_PLANETOLOGY = 10;

implementation

end.

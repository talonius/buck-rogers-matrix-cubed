{ The armor bits, TCharRecord.armorFlags, set for the readied gear. }
unit C_Armor;

interface

const
  { TCharRecord.armorFlags bits, which AdjustEquippedItem sets from the readied gear }
  { CbtActs spares the wearer a dazzle grenade }
  GOGGLES = $08;
  { CbtActs cancels half the rocket hits }
  ECM = $10;
  { Battle armor w/fields: CbtActs cancels three rocket hits in four }
  FIELDS = $20;
  { any body armor: CbtActs cancels a microwave hit }
  BODY = $40;
  { the Breathing Mask or body armor: FxEngine spares the wearer harmful terrain, CbtActs a gas grenade }
  BREATHING_PROTECTION = $80;

implementation

end.

{ Redraws the exploration view for the area the party is in: the big picture of a Venus or Mars wilderness, the orbit
  map's picture, or the 3-D view with its colors, VGA palette and automap switch brought up to date. }
{$O+,F+,A-}
unit MapView;

interface

{ Redraw the view the current area shows, and clear GDVars.portraitPending; a wilderness's big picture is redrawn only
  while portraitPending is set. Nothing is drawn, and portraitPending is kept, while GDVars.partyDefeated is set or, in
  a 3-D area, outside the 3-D view's interface state. }
procedure DisplayMapView;

implementation

uses Blit, Portrait, View3D, Types, C_Map, GDConsts, GDVars, C_Ifc, C_Area, C_Vm, Crt, C_Pic;

procedure DisplayMapView;
var
  { Unused in this version; see the other implementations of this routine. }
  wildernessX: Integer;
  { Unused in this version; see the other implementations of this routine. }
  wildernessY: Integer;

  { The CGA upper horizon color of an ECL color code. }
  function HorizonUpperColorOf(colorCode: Byte): Byte;
  begin
    case colorCode of
      $08: HorizonUpperColorOf := Black;
      $41: HorizonUpperColorOf := Black;
      $E8: HorizonUpperColorOf := White
    else
      HorizonUpperColorOf := White
    end
  end;

  { The CGA lower horizon color of an ECL color code. }
  function HorizonLowerColorOf(colorCode: Byte): Byte;
  begin
    case colorCode of
      $08: HorizonLowerColorOf := DarkGray;
      $41: HorizonLowerColorOf := LightGray;
      $E8: HorizonLowerColorOf := LightGray
    else
      HorizonLowerColorOf := LightGray
    end
  end;

  { The CGA floor color of an ECL color code. }
  function FloorColorOf(colorCode: Byte): Byte;
  begin
    case colorCode of
      $0B: FloorColorOf := DarkGray;
      $09: FloorColorOf := Brown;
      $DB: FloorColorOf := Brown;
      $06: FloorColorOf := Blue
    else
      FloorColorOf := Brown
    end
  end;

begin
  if GDVars.partyDefeated <> 0 then Exit;
  case GDVars.zone0^.areaType of
    C_Area.VENUS_WILDERNESS, C_Area.MARS_WILDERNESS:
      begin
        if GDVars.portraitPending <> 0 then Portrait.DisplayBigPic
      end;
    C_Area.ORBIT:
      begin
        Portrait.DisplayImageBuf(3, 3, True, 0)
      end else begin
      if GDVars.interfaceState <> C_Ifc.VIEW_3D then Exit;
      GDVars.partyPosition.mapEvent := View3D.GetMapEvent(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY);
      if GDVars.partyPosition.mapEvent > $7F then
        GDVars.skyColor := GDConsts.skyCeilingColors[GDVars.zone0^.skyIndexHi]
      else
        GDVars.skyColor := GDConsts.skyCeilingColors[GDVars.zone0^.skyIndexLo];
      if GDVars.displayMode = C_Vm.CGA then begin
        if GDVars.viewColorsChanged <> 0 then begin
          GDVars.horizonColor1 := HorizonUpperColorOf(GDVars.horizonColorCode);
          GDVars.horizonColor2 := HorizonLowerColorOf(GDVars.horizonColorCode);
          GDVars.floorColor := FloorColorOf(GDVars.floorColorCode);
          View3D.SetView3DColors(GDVars.skyColor, GDVars.horizonColor1, GDVars.horizonColor2, GDVars.floorColor)
        end else
          GDVars.floorColor := DarkGray
      end;
      if GDVars.viewPaletteStale <> 0 then begin
        Blit.SetDacPalette(C_Pic.WALL_DAC_FIRST, C_Pic.WALL_DAC_COUNT, GDVars.viewPalette);
        GDVars.viewPaletteStale := 0
      end;
      if (GDVars.zone0^.areaLock <> 0) or
          (GDVars.zone0^.readoutX <> C_Map.NO_READOUT) then GDVars.automapOn := 0;
      View3D.Display3DMapView(GDVars.partyPosition.mapX, GDVars.partyPosition.mapY, GDVars.partyPosition.facing)
    end
  end;
  GDVars.portraitPending := 0
end;

begin
end.

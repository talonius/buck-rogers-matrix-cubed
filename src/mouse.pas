{ The INT 33h mouse driver calls, made through GDVars.regs. Every call but InitMouse does nothing while GDVars.isMouseOn
  is False, so the rest of the game can call them whether or not a mouse is installed. }
{$O+,F+}
unit Mouse;

interface

{ Resets the driver (function 0) and sets isMouseOn by its answer, storing the button count in mouseButtons when a mouse
  is found. }
procedure InitMouse;

{ Shows the pointer, when a mouse driver answered. }
procedure ShowMouse;

{ Hides the pointer, when a mouse driver answered. }
procedure HideMouse;

{ Reads the buttons and position, when a mouse driver answered (otherwise the variables are left unchanged). x comes
  back halved while isMouseScaled is False, turning the driver's 640-column units into the game's 320.
  @param(buttons Receives the buttons held.)
  @param(x Receives the column.)
  @param(y Receives the row.) }
procedure GetMouse(var buttons, x, y: Integer);

{ Moves the pointer, when a mouse driver answered; x is doubled while isMouseScaled is False, as GetMouse halves it.
  @param(x The column.)
  @param(y The row.) }
procedure SetMouse(x, y: Integer);

{ Sets the graphics cursor, when a mouse driver answered.
  @param(hotX The hot spot's column within the cursor.)
  @param(hotY The hot spot's row within the cursor.)
  @param(shape A TMouseCursor: the screen mask, then the cursor mask.) }
procedure SetMouseCursor(hotX, hotY: Integer; shape: Pointer);

{ The driver's software reset (function $21). }
procedure ResetMouse;

implementation

uses Dos, GDVars;

const
  { the mouse driver's functions, staged in AX }
  { detects and resets the driver: AX returns $FFFF when one is present, BX its buttons }
  RESET_DRIVER = $00;
  { shows the cursor }
  SHOW_CURSOR = $01;
  { hides the cursor }
  HIDE_CURSOR = $02;
  { returns the buttons in BX, x in CX and y in DX }
  GET_STATE = $03;
  { moves the cursor to x in CX, y in DX }
  SET_POSITION = $04;
  { sets the cursor shape: hot spot in BX and CX, masks at ES:DX }
  SET_CURSOR = $09;
  { the driver's software reset }
  SOFT_RESET = $21;

procedure InitMouse;
begin
  GDVars.regs.ax := Mouse.RESET_DRIVER;
  Intr($33, Registers(GDVars.regs));
  if GDVars.regs.ax = $FFFF then begin
    GDVars.mouseButtons := GDVars.regs.bl;
    GDVars.isMouseOn := True;
  end else
    GDVars.isMouseOn := False;
end;

procedure ShowMouse;
begin
  if not GDVars.isMouseOn then Exit;
  GDVars.regs.ax := Mouse.SHOW_CURSOR;
  Intr($33, Registers(GDVars.regs));
end;

procedure HideMouse;
begin
  if not GDVars.isMouseOn then Exit;
  GDVars.regs.ax := Mouse.HIDE_CURSOR;
  Intr($33, Registers(GDVars.regs));
end;

procedure GetMouse(var buttons, x, y: Integer);
begin
  if not GDVars.isMouseOn then Exit;
  GDVars.regs.ax := Mouse.GET_STATE;
  Intr($33, Registers(GDVars.regs));
  buttons := GDVars.regs.bx;
  x := GDVars.regs.cx;
  if not GDVars.isMouseScaled then x := x div 2;
  y := GDVars.regs.dx;
end;

procedure SetMouse(x, y: Integer);
begin
  if not GDVars.isMouseOn then Exit;
  GDVars.regs.ax := Mouse.SET_POSITION;
  if not GDVars.isMouseScaled then x := x * 2;
  GDVars.regs.cx := x;
  GDVars.regs.dx := y;
  Intr($33, Registers(GDVars.regs));
end;

procedure SetMouseCursor(hotX, hotY: Integer; shape: Pointer);
begin
  if not GDVars.isMouseOn then Exit;
  GDVars.regs.ax := Mouse.SET_CURSOR;
  GDVars.regs.bx := hotX;
  GDVars.regs.cx := hotY;
  GDVars.regs.es := Seg(shape^);
  GDVars.regs.dx := Ofs(shape^);
  Intr($33, Registers(GDVars.regs));
end;

procedure ResetMouse;
begin
  if not GDVars.isMouseOn then Exit;
  GDVars.regs.ax := Mouse.SOFT_RESET;
  Intr($33, Registers(GDVars.regs));
end;

begin
end.

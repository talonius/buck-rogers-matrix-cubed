@echo off
rem ===================================================================
rem  Buck Rogers: Matrix Cubed v1.0 -- THE WHOLE-IMAGE BUILD. Run from
rem  e:\src by build.sh, which mounts:
rem     C: games      D: the compiler     E: this tree
rem     F: TASM 1.0   G: EXEPACK          H: TASM 3.1
rem
rem  Every output goes to e:\obj: each .OBJ and .TPU, FIXMAIN.EXE and
rem  FIXMAIN.MAP, and the two files SSI shipped under their shipped names,
rem  the EXEPACK'd START.EXE and GAME.OVR. FIXMAIN.EXE stays beside them
rem  as the packer's input.
rem
rem  `BUILD.BAT ASM` assembles and stops: a probe build of one unit needs
rem  the same objects, from the same lines.
rem
rem  TPC takes its switches from e:\src\TPC.CFG, its working directory's.
rem  Each one is there because the build needs it:
rem     /L          keeps the link buffer on disk: in memory, the whole-
rem                 image link fails with Error 1, out of memory
rem     /$A-        byte alignment: $A+ word-aligns storage, moving DGROUP
rem     /$S-        no stack-overflow check on entry to each routine
rem     /GD         a detailed FIXMAIN.MAP, which the repository tools read
rem  Every other setting is TPC 6.0's default or a unit's own directive.
rem ===================================================================
rem  Nothing an earlier build left may stand in for this one's: a .OBJ
rem  TASM failed to rewrite would still link, and TPC searches e:\src,
rem  which holds source only, as well as e:\obj.
if exist e:\obj\*.OBJ del e:\obj\*.OBJ
if exist e:\obj\*.TPU del e:\obj\*.TPU
if exist e:\src\*.OBJ del e:\src\*.OBJ
if exist e:\src\*.TPU del e:\src\*.TPU
rem  ail.asm is the Miles AIL library. It needs TASM 3.1: its extended
rem  CALL with a language specifier is 2.0+ syntax, and /m because a
rem  single pass reports "Forward reference needs override". TASM 1.0
rem  assembles the rest; TASM 3.1 builds the same image from them too.
h:\tasm /m ail,..\obj\ail > e:\build\logs\TASM.OUT
f:\tasm blit,..\obj\blit >> e:\build\logs\TASM.OUT
f:\tasm joystick,..\obj\joystick >> e:\build\logs\TASM.OUT
f:\tasm sounddrv,..\obj\sounddrv >> e:\build\logs\TASM.OUT
f:\tasm textrend,..\obj\textrend >> e:\build\logs\TASM.OUT
f:\tasm vgaframe,..\obj\vgaframe >> e:\build\logs\TASM.OUT
if "%1"=="ASM" goto done
rem  DOS REN refuses an existing target, and a stale output would score
rem  as this build's.
if exist e:\obj\FIXMAIN.EXE del e:\obj\FIXMAIN.EXE
if exist e:\obj\FIXMAIN.OVR del e:\obj\FIXMAIN.OVR
if exist e:\obj\FIXMAIN.MAP del e:\obj\FIXMAIN.MAP
if exist e:\obj\START.EXE del e:\obj\START.EXE
if exist e:\obj\GAME.OVR del e:\obj\GAME.OVR
path d:\
rem  /B recompiles every unit; /E and /O are where TPC writes its output
rem  and finds TASM's objects.
tpc fixmain.pas /B /E..\obj /O..\obj > e:\build\logs\TPC.OUT
g:\exepack e:\obj\FIXMAIN.EXE e:\obj\START.EXE > e:\build\logs\EXEPACK.OUT
rem  TPC names the overlay after the root; SSI shipped it as GAME.OVR.
ren e:\obj\FIXMAIN.OVR GAME.OVR
:done

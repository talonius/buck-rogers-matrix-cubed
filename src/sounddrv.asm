; sounddrv.asm -- the assembly half of the SoundDrv unit, linked through {$L SOUNDDRV.OBJ} into the unit's code segment.
; It is an INT 8 sound driver for the PC speaker and the Tandy SN76489: InstallSoundTimer hooks the timer and raises its
; rate, and on every tick the ISR steps four voices per device through their streams and writes the result to the
; hardware. ProgramTandyVoices and ProgramSpeakerVoices start a tune, SetSoundOutputEnabled turns output on and off, and
; UninstallSoundTimer undoes InstallSoundTimer. ExitCount holds the countdown SoundCommand(21) arms, which ends the
; program with a fake runtime error.
;
; The driver keeps its tables, streams and voice state in its own code segment. Each entry point and the ISR load DS
; with CODE, so every DS operand here addresses this segment; the other memory operands are CS: and ES: overrides and
; the parameter reads on the stack.

        LOCALS

TICKCOUNT    EQU 13B1h          ; PIT channel 0 count: 1193182 / 5041 = 236.7 ticks a second
TICKDIV      EQU 13             ; ISR ticks per BIOS tick: 236.7 / 13 = 18.2 a second
TANDYPORT    EQU 0C0h           ; SN76489 write port
TANDYOFF     EQU 9Fh            ; latch: channel 0 attenuation 15, silent; +20h per channel
ERRLEN       EQU 21h            ; characters of exitMsg the ISR prints
BIOSVIDEO    EQU 10h            ; the video BIOS interrupt
VSETMODE     EQU 00h            ; its function: set the mode in AL
VGETMODE     EQU 0Fh            ; its function: return the current mode in AL
VWRITESTR    EQU 13h            ; its function: write CX characters at ES:BP

; A voice block: the state of one voice, VOICESIZE bytes. Streams address the fields by these offsets.
VOICESIZE       EQU 30h
vfDuration      EQU 00h         ; ticks left of the current note; zero: the voice is idle
vfStream        EQU 02h         ; the next stream byte; zero: no stream
vfPeriod        EQU 04h         ; the note's divisor or tone value, before modulation
vfPeriodAdd     EQU 06h         ; added to vfPeriod every tick
vfOutPeriod     EQU 08h         ; vfPeriod plus the modulation: what reaches the hardware
vfLevel         EQU 0Ah         ; volume; the speaker takes its low two bits as the gate
vfLevelAdd      EQU 0Ch         ; added to vfLevel every tick
vfTempo         EQU 0Eh         ; ticks per note-length unit, when more than 1
vfReleaseLead   EQU 10h         ; set by some streams (FF 10) and cleared with the block; unused by this driver
vfTranspose     EQU 12h         ; semitones added to every note number
vfGateLen       EQU 14h         ; ticks until the envelope's release, from entry 4
vfEnvBase       EQU 16h         ; envelope: entries of (step, ticks), ticks FFFFh = set
vfEnvPos        EQU 18h         ; byte offset of the current envelope entry
vfEnvWait       EQU 1Ah         ; ticks left in the current entry
vfLfoTable      EQU 1Ch         ; LFO wave table modulating the pitch
vfLfoPhase      EQU 1Eh         ; position in it, in sixteenths of a sample
vfLfoRate       EQU 20h         ; added to vfLfoPhase every tick; a zero sum: no modulation
vfLfoDepth      EQU 22h         ; modulation depth
vfLfoWrap       EQU 24h         ; vfLfoPhase wraps here: sixteen times the table's length
vfLoopCounterA  EQU 26h         ; an FE loop's counter, set by FF 26; cleared with the block, not by FA/FD
vfLoopCounterB  EQU 28h         ; the counter of an FE loop nested inside one on vfLoopCounterA

CODE    SEGMENT BYTE PUBLIC             ; no 'CODE' class -> {$L} merges into the unit seg
        ASSUME  CS:CODE, DS:CODE
        PUBLIC  ExitCount, InstallSoundTimer, UninstallSoundTimer
        PUBLIC  ProgramTandyVoices, ProgramSpeakerVoices, SetSoundOutputEnabled

divCount        db TICKDIV              ; counts ISR ticks down to the next BIOS tick
isSeqBusy       db 0                    ; non-zero: a tick or a voice writer is running
voiceLeft       db 0                    ; loop counter over the four voices, 4 down to 1
blockSize       db VOICESIZE            ; RunStream's multiplier from voice to block
ExitCount       dw 0                    ; ISR ticks left before exitMsg; zero: not armed

; exitMsg: a Turbo Pascal run-time error 209 message, LF, CR, stored with every high bit set so it does not read as text
; in a dump. The ISR clears the high bits of the first ERRLEN bytes and prints those; the CR is neither. 209 is Turbo
; Pascal's overlay-read error; the error address is part of the text, not computed.
exitMsg LABEL BYTE
        db 0D2h,0F5h,0EEh,0ADh,0F4h,0E9h,0EDh,0E5h,0A0h,0A0h,0C5h,0F2h,0F2h,0EFh,0F2h,0A0h
        db 0B2h,0B0h,0B9h,0A0h,0E1h,0F4h,0A0h,0B0h,0C2h,0C1h,0C4h,0BAh,0B0h,0B0h,0B3h,0B8h
        db 08Ah,08Dh

; RunStream and the voice writers' shared state. StartSound starts both devices on tune 0 as soon as InstallSoundTimer
; returns.
curTune         dw 0                    ; the tune last started, on either device; zero: both silent
seqVoice        dw 0                    ; the block whose stream RunStream is reading
voiceBase       dw 0                    ; the block set of the device being ticked
freqBase        dw 0                    ; the pitch table of the device being ticked
seqRet          dw 0                    ; where a stream return (FB) resumes
voiceTune       db 000h,000h,000h,000h  ; per voice: its tune, zeroed when its stream ends; unused
isOutputOn      db 001h                 ; zero: both devices silent; set by SetSoundOutputEnabled

; noteLen: note lengths indexed by the low five bits of a note's first byte. Unused: this driver's notes carry their own
; length.
noteLen db 000h,000h,000h,002h,000h,003h,004h,000h,006h,008h,000h,00Ch,010h,000h,018h,020h
        db 000h,030h,040h

; RunStream's command handlers, for command bytes FA to FF.
cmdTable        dw seqCmdReset,seqCmdReturn,seqCmdCall,seqCmdClear,seqCmdLoop,seqCmdSet

; Eight voice blocks per device, VOICESIZE bytes each (fields at the top of the file). The ISR ticks the first four; a
; stream can address all eight.
spkrBlocks      db 8*VOICESIZE dup (0)

; PIT divisors for C to B of the lowest octave (1193182 / 8E84h = 32.7 Hz, C1); E1, 714Fh, is 2.9 cents flat.
; SpeakerTick and TandyTick point freqBase at the pitch tables, and RunStream's note path reads them through it.
spkrFreq LABEL WORD
        dw 8E84h,8684h,7EF7h,77D7h,714Fh,6AC4h
        dw 64C6h,5F1Eh,59C7h,54BDh,4FFCh,4B7Eh

spkrVoice       dw 0                    ; the block driving the speaker this tick, or 0

tandyBlocks     db 8*VOICESIZE dup (0)

; SN76489 tone values for A2 to G#3, in bits 15-6 of each word (3579545 / (32 * 3FFh) = 109.3 Hz, A2). The values fit a
; clock of about 3.6 MHz, on which A2 is 110.0 Hz; on the 3.579545 MHz chip this octave sounds 7 to 13 cents flat. The
; higher octaves shift the value right, which truncates it and changes each octave's error (from about 10 cents flat to
; 9 cents sharp three octaves up). No stream plays a pitched note, so neither pitch table is used in play.
tandyFreq LABEL WORD
        dw 0FFC0h,0F140h,0E3C0h,0D700h,0CB40h,0BF80h
        dw 0B4C0h,0AA80h,0A100h,9800h,8F80h,8740h

; Per tune, the stream of each of the device's four voices: tune n at n*8. Zero: the voice keeps what it has. Tune n,
; from 1, is SoundCommand's command n+1 (tune 0 is command 0's), and its streams take the name of GDConsts' constant
; for that command; the ship-laser streams play command 19, shipWeaponSounds' entry for ShipCbt's two lasers. GDConsts
; has no constant for tunes 14 and 19, and no command starts tune 20.
speakerTunes LABEL WORD
        dw spkrSilence,spkrSilence,spkrSilence,spkrSilence         ; tune 0
        dw spkrDamage,spkrSilence,spkrSilence,spkrSilence          ; tune 1
        dw spkrLaunch,spkrSilence,spkrSilence,spkrSilence          ; tune 2
        dw spkrCloudGrenade,spkrSilence,spkrSilence,spkrSilence    ; tune 3
        dw spkrDowned,spkrSilence,spkrSilence,spkrSilence          ; tune 4
        dw spkrSonicStunner,spkrSilence,spkrSilence,spkrSilence    ; tune 5
        dw spkrHit,spkrSilence,spkrSilence,spkrSilence             ; tune 6
        dw spkrDazzleGrenade,spkrSilence,spkrSilence,spkrSilence   ; tune 7
        dw spkrMiss,spkrSilence,spkrSilence,spkrSilence            ; tune 8
        dw spkrStep,spkrSilence,spkrSilence,spkrSilence            ; tune 9
        dw spkrExplosion,spkrSilence,spkrSilence,spkrSilence       ; tune 10
        dw spkrBolt,spkrSilence,spkrSilence,spkrSilence            ; tune 11
        dw spkrHeatGun,spkrSilence,spkrSilence,spkrSilence         ; tune 12
        dw spkrLaser,spkrSilence,spkrSilence,spkrSilence           ; tune 13
        dw spkrTune14,spkrSilence,spkrSilence,spkrSilence          ; tune 14
        dw spkrRocket,spkrSilence,spkrSilence,spkrSilence          ; tune 15
        dw spkrNeedleGun,spkrSilence,spkrSilence,spkrSilence       ; tune 16
        dw spkrMicrowaveGun,spkrSilence,spkrSilence,spkrSilence    ; tune 17
        dw spkrShipLaser,spkrSilence,spkrSilence,spkrSilence       ; tune 18
        dw spkrTune19,spkrSilence,spkrSilence,spkrSilence          ; tune 19
        dw spkrTune20,0,0,0                                        ; tune 20

tandyTunes LABEL WORD
        dw tandySilence,tandySilence,tandySilence,tandySilence                        ; tune 0
        dw tandyDamageV0,tandyDamageV1,tandyDamageV2,tandySilence                     ; tune 1
        dw tandySilence,tandySilence,tandySilence,tandyLaunchV3                       ; tune 2
        dw tandyCloudGrenadeV0,tandyCloudGrenadeV1,tandyCloudGrenadeV2,tandySilence   ; tune 3
        dw tandyDownedV0,tandySilence,tandyDownedV2,tandyDownedV3                     ; tune 4
        dw tandySonicStunnerV0,tandySilence,tandySilence,tandySilence                 ; tune 5
        dw tandySilence,tandySilence,tandyHitV2,tandyHitV3                            ; tune 6
        dw tandyDazzleGrenadeV0,tandyDazzleGrenadeV1,tandySilence,tandySilence        ; tune 7
        dw tandySilence,tandySilence,tandySilence,tandyMissV3                         ; tune 8
        dw tandySilence,tandySilence,tandySilence,tandyStepV3                         ; tune 9
        dw tandySilence,tandySilence,tandyExplosionV2,tandyExplosionV3                ; tune 10
        dw tandyBoltV0,tandyBoltV1,tandyBoltV2,tandySilence                           ; tune 11
        dw tandySilence,tandySilence,tandyHeatGunV2,tandyHeatGunV3                    ; tune 12
        dw tandyLaserV0,tandySilence,tandyLaserV2,tandyLaserV3                        ; tune 13
        dw tandySilence,tandySilence,tandyTune14V2,tandyTune14V3                      ; tune 14
        dw tandySilence,tandySilence,tandyRocketV2,tandyRocketV3                      ; tune 15
        dw tandySilence,tandySilence,tandyNeedleGunV2,tandyNeedleGunV3                ; tune 16
        dw tandySilence,tandySilence,tandyMicrowaveGunV2,tandySilence                 ; tune 17
        dw tandyShipLaserV0,tandySilence,tandyShipLaserV2,tandyShipLaserV3            ; tune 18
        dw tandyTune19V0,tandySilence,tandySilence,tandySilence                       ; tune 19
        dw tandyTune20V0,tandySilence,tandySilence,tandySilence                       ; tune 20

; LFO wave tables for the pitch modulation: a sine of 256 signed samples, a 32-sample square and 512 bytes of noise. A
; stream selects one by setting vfLfoTable (FF 1C).
lfoSine LABEL BYTE
        db 000h,003h,006h,009h,00Ch,00Fh,012h,015h,018h,01Bh,01Eh,021h,024h,027h,02Ah,02Dh
        db 030h,033h,036h,039h,03Bh,03Eh,041h,043h,046h,049h,04Bh,04Eh,050h,052h,055h,057h
        db 059h,05Bh,05Eh,060h,062h,064h,066h,067h,069h,06Bh,06Ch,06Eh,070h,071h,072h,074h
        db 075h,076h,077h,078h,079h,07Ah,07Bh,07Bh,07Ch,07Dh,07Dh,07Eh,07Eh,07Eh,07Eh,07Eh
        db 07Eh,07Eh,07Eh,07Eh,07Eh,07Eh,07Dh,07Dh,07Ch,07Bh,07Bh,07Ah,079h,078h,077h,076h
        db 075h,074h,072h,071h,070h,06Eh,06Ch,06Bh,069h,067h,066h,064h,062h,060h,05Eh,05Bh
        db 059h,057h,055h,052h,050h,04Eh,04Bh,049h,046h,043h,041h,03Eh,03Bh,039h,036h,033h
        db 030h,02Dh,02Ah,027h,024h,021h,01Eh,01Bh,018h,015h,012h,00Fh,00Ch,009h,006h,003h
        db 000h,0FDh,0FAh,0F7h,0F4h,0F1h,0EEh,0EBh,0E8h,0E5h,0E2h,0DFh,0DCh,0D9h,0D6h,0D3h
        db 0D0h,0CDh,0CAh,0C7h,0C5h,0C2h,0BFh,0BDh,0BAh,0B7h,0B5h,0B2h,0B0h,0AEh,0ABh,0A9h
        db 0A7h,0A5h,0A2h,0A0h,09Eh,09Ch,09Ah,099h,097h,095h,094h,092h,090h,08Fh,08Eh,08Ch
        db 08Bh,08Ah,089h,088h,087h,086h,085h,085h,084h,083h,083h,082h,082h,082h,082h,082h
        db 082h,082h,082h,082h,082h,082h,083h,083h,084h,085h,085h,086h,087h,088h,089h,08Ah
        db 08Bh,08Ch,08Eh,08Fh,090h,092h,094h,095h,097h,099h,09Ah,09Ch,09Eh,0A0h,0A2h,0A5h
        db 0A7h,0A9h,0ABh,0AEh,0B0h,0B2h,0B5h,0B7h,0BAh,0BDh,0BFh,0C2h,0C5h,0C7h,0CAh,0CDh
        db 0D0h,0D3h,0D6h,0D9h,0DCh,0DFh,0E2h,0E5h,0E8h,0EBh,0EEh,0F1h,0F4h,0F7h,0FAh,0FDh

lfoSquare LABEL BYTE
        db 000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h
        db 078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h,078h

lfoNoise LABEL BYTE
        db 029h,023h,0BEh,084h,0E1h,06Ch,0D6h,0AEh,052h,090h,049h,0F1h,0F1h,0BBh,0E9h,0EBh
        db 0B3h,0A6h,0DBh,03Ch,087h,00Ch,03Eh,099h,024h,05Eh,00Dh,01Ch,006h,0B7h,047h,0DEh
        db 0B3h,012h,04Dh,0C8h,043h,0BBh,08Bh,0A6h,01Fh,003h,05Ah,07Dh,009h,038h,025h,01Fh
        db 05Dh,0D4h,0CBh,0FCh,096h,0F5h,045h,03Bh,013h,00Dh,089h,00Ah,01Ch,0DBh,0AEh,032h
        db 020h,09Ah,050h,0EEh,040h,078h,036h,0FDh,012h,049h,032h,0F6h,09Eh,07Dh,049h,0DCh
        db 0ADh,04Fh,014h,0F2h,044h,040h,066h,0D0h,06Bh,0C4h,030h,0B7h,032h,03Bh,0A1h,022h
        db 0F6h,022h,091h,09Dh,0E1h,08Bh,01Fh,0DAh,0B0h,0CAh,099h,002h,0B9h,072h,09Dh,049h
        db 02Ch,080h,07Eh,0C5h,099h,0D5h,0E9h,080h,0B2h,0EAh,0C9h,0CCh,053h,0BFh,067h,0D6h
        db 0BFh,014h,0D6h,07Eh,02Dh,0DCh,08Eh,066h,083h,0EFh,057h,049h,061h,0FFh,069h,08Fh
        db 061h,0CDh,0D1h,01Eh,09Dh,09Ch,016h,072h,072h,0E6h,01Dh,0F0h,084h,04Fh,04Ah,077h
        db 002h,0D7h,0E8h,039h,02Ch,053h,0CBh,0C9h,012h,01Eh,033h,074h,09Eh,00Ch,0F4h,0D5h
        db 0D4h,09Fh,0D4h,0A4h,059h,07Eh,035h,0CFh,032h,022h,0F4h,0CCh,0CFh,0D3h,090h,02Dh
        db 048h,0D3h,08Fh,075h,0E6h,0D9h,01Dh,02Ah,0E5h,0C0h,0F7h,02Bh,078h,081h,087h,044h
        db 00Eh,05Fh,050h,000h,0D4h,061h,08Dh,0BEh,07Bh,005h,015h,007h,03Bh,033h,082h,01Fh
        db 018h,070h,092h,0DAh,064h,054h,0CEh,0B1h,085h,03Eh,069h,015h,0F8h,046h,06Ah,004h
        db 096h,073h,00Eh,0D9h,016h,02Fh,067h,068h,0D4h,0F7h,04Ah,04Ah,0D0h,057h,068h,076h
        db 0FAh,016h,0BBh,011h,0ADh,0AEh,024h,088h,079h,0FEh,052h,0DBh,025h,043h,0E5h,03Ch
        db 0F4h,045h,0D3h,0D8h,028h,0CEh,00Bh,0F5h,0C5h,060h,059h,03Dh,097h,027h,08Ah,059h
        db 076h,02Dh,0D0h,0C2h,0C9h,0CDh,068h,0D4h,049h,06Ah,079h,025h,008h,061h,040h,014h
        db 0B1h,03Bh,06Ah,0A5h,011h,028h,0C1h,08Ch,0D6h,0A9h,00Bh,087h,097h,08Ch,02Fh,0F1h
        db 015h,01Dh,09Ah,095h,0C1h,09Bh,0E1h,0C0h,07Eh,0E9h,0A8h,09Ah,0A7h,086h,0C2h,0B5h
        db 054h,0BFh,09Ah,0E7h,0D9h,023h,0D1h,055h,090h,038h,028h,0D1h,0D9h,06Ch,0A1h,066h
        db 05Eh,04Eh,0E1h,030h,09Ch,0FEh,0D9h,071h,09Fh,0E2h,0A5h,0E2h,00Ch,09Bh,0B4h,047h
        db 065h,038h,02Ah,046h,089h,0A9h,082h,079h,07Ah,076h,078h,0C2h,063h,0B1h,026h,0DFh
        db 0DAh,029h,06Dh,03Eh,062h,0E0h,096h,012h,034h,0BFh,039h,0A6h,03Fh,089h,05Eh,0F1h
        db 06Dh,00Eh,0E3h,06Ch,028h,0A1h,01Eh,020h,01Dh,0CBh,0C2h,003h,03Fh,041h,007h,084h
        db 00Fh,014h,005h,065h,01Bh,028h,061h,0C9h,0C5h,0E7h,02Ch,08Eh,046h,036h,008h,0DCh
        db 0F3h,0A8h,08Dh,0FEh,0BEh,0F2h,0EBh,071h,0FFh,0A0h,0D0h,03Bh,075h,006h,08Ch,07Eh
        db 087h,078h,073h,04Dh,0D0h,0BEh,082h,0BEh,0DBh,0C2h,046h,041h,02Bh,08Ch,0FAh,030h
        db 07Fh,070h,0F0h,0A7h,054h,086h,032h,095h,0AAh,05Bh,068h,013h,00Bh,0E6h,0FCh,0F5h
        db 0CAh,0BEh,07Dh,09Fh,089h,08Ah,041h,01Bh,0FDh,0B8h,04Fh,068h,0F6h,072h,07Bh,014h
        db 099h,0CDh,0D3h,00Dh,0F0h,044h,03Ah,0B4h,0A6h,066h,053h,033h,00Bh,0CBh,0A1h,010h

; The streams, in RunStream's format, and the envelope tables they select through vfEnvBase, in StepVoice's (words of
; step, ticks). A stream is named for the tune and voice that start it; a label ending in Loop is the target of its FE
; loop on vfLoopCounterA (Inner before Loop marks the one on vfLoopCounterB), and Sub the target of its FC call.
spkrExplosion LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,004h,030h,075h,0FFh,01Ch
        dw lfoNoise
        db 0FFh,024h,000h,020h,0FFh,022h,010h,027h,0FFh,020h,010h,000h,0FFh,000h,01Ch,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,00Ch,000h,0FFh,00Ah,003h,000h,0FFh,004h,004h,010h
        db 0FFh,022h,098h,008h,0FFh,006h,010h,000h,0FFh,000h,02Ch,001h,0FFh,00Ah,000h,000h
        db 0FFh,000h,000h,000h
spkrHeatGun LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,004h,010h,027h,0FFh,01Ch
        dw lfoNoise
        db 0FFh,024h,000h,020h,0FFh,022h,028h,023h,0FFh,020h,010h,000h,0FFh,000h,019h,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,002h,000h,0FFh,00Ah,003h,000h,0FFh,004h,088h,013h
        db 0FFh,022h,0A0h,00Fh,0FFh,006h,02Ch,001h,0FFh,000h,050h,000h,0FFh,00Ah,000h,000h
        db 0FFh,000h,000h,000h
spkrLaser LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,004h,0B8h,00Bh,0FFh,01Ch
        dw lfoNoise
        db 0FFh,024h,000h,020h,0FFh,022h,04Ch,004h,0FFh,020h,010h,000h,0FFh,000h,002h,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,001h,000h,0FFh,00Ah,003h,000h,0FFh,004h,034h,008h
        db 0FFh,022h,0F4h,001h,0FFh,006h,09Ch,0FFh,0FFh,000h,01Eh,000h,0FFh,00Ah,000h,000h
        db 0FFh,000h,000h,000h
spkrShipLaser LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,004h,040h,01Fh,0FFh,01Ch
        dw lfoNoise
        db 0FFh,024h,000h,020h,0FFh,022h,04Ch,004h,0FFh,020h,010h,000h,0FFh,000h,002h,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,001h,000h,0FFh,00Ah,003h,000h,0FFh,004h,0D4h,017h
        db 0FFh,022h,0F4h,001h,0FFh,006h,09Ch,0FFh,0FFh,000h,050h,000h,0FFh,00Ah,000h,000h
        db 0FFh,000h,000h,000h
spkrNeedleGun LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,01Ch
        dw lfoNoise
        db 0FFh,024h,000h,020h,0FFh,022h,0E8h,003h,0FFh,020h,010h,000h,0FFh,006h,0CEh,0FFh
        db 0FFh,026h,004h,000h
spkrNeedleGunLoop LABEL BYTE
        db 0FFh,004h,010h,027h,0FFh,000h,004h,000h,0FFh,004h,020h,04Eh,0FFh,00Ah,000h,000h
        db 0FFh,000h,004h,000h,0FFh,00Ah,003h,000h,0FFh,000h,004h,000h,0FEh,026h
        dw spkrNeedleGunLoop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrMicrowaveGun LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,01Ch
        dw lfoNoise
        db 0FFh,024h,000h,020h,0FFh,022h,0E8h,003h,0FFh,020h,010h,000h,0FFh,006h,0CEh,0FFh
        db 0FFh,026h,014h,000h
spkrMicrowaveGunLoop LABEL BYTE
        db 0FFh,004h,088h,013h,0FFh,000h,001h,000h,0FFh,00Ah,000h,000h,0FFh,000h,001h,000h
        db 0FFh,00Ah,003h,000h,0FFh,004h,030h,075h,0FFh,000h,001h,000h,0FEh,026h
        dw spkrMicrowaveGunLoop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrTune14 LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,004h,010h,027h,0FFh,01Ch
        dw lfoNoise
        db 0FFh,024h,000h,020h,0FFh,022h,0F4h,001h,0FFh,020h,010h,000h,0FFh,006h,0CEh,0FFh
        db 0FFh,000h,01Ch,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrRocket LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,004h,020h,04Eh,0FFh,01Ch
        dw lfoNoise
        db 0FFh,024h,000h,020h,0FFh,022h,010h,027h,0FFh,020h,010h,000h,0FFh,000h,005h,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,001h,000h,0FFh,00Ah,003h,000h,0FFh,004h,034h,008h
        db 0FFh,022h,098h,008h,0FFh,006h,064h,000h,0FFh,000h,064h,000h,0FFh,00Ah,000h,000h
        db 0FFh,000h,000h,000h
spkrMiss LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,004h,0A0h,00Fh,0FFh,000h,005h,000h,0FFh,004h,0E8h,003h
        db 0FFh,000h,004h,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrStep LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,004h,0B0h,036h,0FFh,006h,0C8h,000h,0FFh,01Ch
        dw lfoNoise
        db 0FFh,024h,000h,020h,0FFh,022h,070h,017h,0FFh,020h,07Bh,000h,0FFh,000h,008h,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrDazzleGrenade LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,004h,0B4h,03Fh,0FFh,026h,01Eh,000h
spkrDazzleGrenadeLoop LABEL BYTE
        db 0FFh,006h,03Ch,0FEh,0FFh,000h,00Ch,000h,0FFh,006h,077h,002h,0FFh,000h,008h,000h
        db 0FEh,026h
        dw spkrDazzleGrenadeLoop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrLaunch LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,01Ch
        dw lfoNoise
        db 0FFh,024h,000h,020h,0FFh,022h,040h,006h,0FFh,020h,09Bh,001h,0FFh,004h,0CCh,010h
        db 0FFh,006h,00Ah,000h,0FFh,000h,01Eh,000h,0FFh,022h,084h,003h,0FFh,004h,014h,005h
        db 0FFh,006h,050h,000h,0FFh,000h,005h,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrSonicStunner LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,026h,005h,000h,0FFh,004h,038h,018h
spkrSonicStunnerLoop LABEL BYTE
        db 0FFh,006h,000h,000h,0FFh,000h,006h,000h,0FFh,028h,00Ch,000h
spkrSonicStunnerInnerLoop LABEL BYTE
        db 0FFh,006h,05Eh,0FCh,0FFh,000h,001h,000h,0FFh,006h,084h,003h,0FFh,000h,001h,000h
        db 0FEh,028h
        dw spkrSonicStunnerInnerLoop
        db 0FEh,026h
        dw spkrSonicStunnerLoop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrCloudGrenade LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,004h,07Bh,019h,0FFh,026h,00Ah,000h
spkrCloudGrenadeLoop LABEL BYTE
        db 0FFh,006h,0D3h,0FFh,0FFh,000h,014h,000h,0FFh,006h,0F4h,001h,0FFh,000h,001h,000h
        db 0FEh,026h
        dw spkrCloudGrenadeLoop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrDowned LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,01Ch
        dw lfoNoise
        db 0FFh,024h,000h,020h,0FFh,022h,010h,027h,0FFh,020h,010h,000h,0FFh,004h,0E0h,02Eh
        db 0FFh,026h,02Ch,000h
spkrDownedLoop LABEL BYTE
        db 0FFh,006h,0F0h,0F1h,0FFh,000h,002h,000h,0FFh,006h,088h,00Eh,0FFh,000h,002h,000h
        db 0FEh,026h
        dw spkrDownedLoop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrHit LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,01Ch
        dw lfoNoise
        db 0FFh,024h,000h,020h,0FFh,022h,028h,00Ah,0FFh,020h,010h,000h,0FFh,004h,070h,017h
        db 0FFh,006h,060h,0FFh,0FFh,000h,01Eh,000h,0FFh,006h,046h,000h,0FFh,000h,023h,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrSilence LABEL BYTE
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrDamage LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,004h,088h,013h,0FFh,01Ch
        dw lfoSine
        db 0FFh,024h,000h,010h,0FFh,022h,0F4h,001h,0FFh,020h,04Eh,000h,0FFh,026h,028h,000h
spkrDamageLoop LABEL BYTE
        db 0FFh,006h,000h,000h,0FFh,000h,002h,000h,0FFh,006h,0ADh,0FDh,0FFh,000h,001h,000h
        db 0FFh,006h,000h,000h,0FFh,000h,002h,000h,0FFh,006h,0F4h,001h,0FFh,000h,001h,000h
        db 0FEh,026h
        dw spkrDamageLoop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrBolt LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,01Ch
        dw lfoSine
        db 0FFh,024h,000h,010h,0FFh,022h,0E8h,003h,0FFh,020h,000h,001h,0FFh,004h,0E4h,00Ch
        db 0FFh,006h,0ECh,0FFh,0FFh,000h,01Eh,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
spkrTune20 LABEL BYTE
        db 0FCh
        dw spkrTune20Sub
        db 0FFh,000h,000h,000h
spkrTune20Sub LABEL BYTE
        db 0FDh,030h,000h,0FFh,012h,0E8h,0FFh,0FFh,016h
        dw spkrTune20Env2
        db 0FFh,01Ch
        dw lfoSine
        db 0FFh,024h,000h,010h,0FFh,022h,028h,000h,0FFh,020h,02Ch,001h,0FDh,060h,000h,0FFh
        db 012h,0E8h,0FFh,0FFh,010h,005h,000h,0FFh,016h
        dw spkrTune20Env1
        db 0FFh,01Ch
        dw lfoSine
        db 0FFh,024h,000h,010h,0FFh,022h,014h,000h,0FFh,020h,078h,000h,0FDh,000h,000h,0FFh
        db 012h,0E8h,0FFh,0FFh,016h
        dw spkrTune20Env3
        db 0FFh,01Ch
        dw lfoSine
        db 0FFh,024h,000h,010h,0FFh,022h,078h,000h,0FFh,020h,0E4h,000h,0FDh,090h,000h,0FFh
        db 012h,0E8h,0FFh,0FFh,016h
        dw spkrTune20Env4
        db 0FFh,01Ch
        dw lfoSine
        db 0FFh,024h,000h,010h,0FFh,022h,078h,000h,0FFh,020h,0E4h,000h,0FFh,00Eh,001h,000h
        db 0FBh
spkrTune20Env1 LABEL BYTE
        dw 0003h,0FFFFh,0000h,0000h
        dw 0000h,0FFFFh,0000h,0000h
        dw 0000h,0FFFFh,0000h,0000h
spkrTune20Env2 LABEL BYTE
        dw 0003h,0FFFFh,0000h,0010h
        dw 0000h,0FFFFh,0000h,0000h
        dw 0000h,001Eh,0000h,0000h
spkrTune20Env3 LABEL BYTE
        dw 0003h,0FFFFh,0000h,0008h
        dw 0000h,0FFFFh,0000h,0000h
        dw 0000h,001Eh,0000h,0000h
spkrTune20Env4 LABEL BYTE
        dw 0003h,0FFFFh,0000h,0014h
        dw 0000h,0FFFFh,0000h,0000h
        dw 0000h,001Eh,0000h,0000h
spkrTune19 LABEL BYTE
        db 0FFh,00Ah,003h,000h,0FFh,004h,0A0h,00Fh,0FFh,006h,014h,000h,0FFh,000h,010h,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyExplosionV2 LABEL BYTE
        db 0FFh,004h,0B8h,00Bh,0FFh,000h,01Ch,000h,0FFh,004h,080h,03Eh,0FFh,006h,0E7h,0FFh
        db 0FFh,000h,090h,001h,0FFh,000h,000h,000h
tandyExplosionV3 LABEL BYTE
        db 0FFh,004h,0C0h,001h,0FFh,00Ah,060h,0EAh,0FFh,000h,01Ch,000h,0FFh,00Ah,050h,0C3h
        db 0FFh,00Ch,09Ch,0FFh,0FFh,000h,090h,001h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyHeatGunV2 LABEL BYTE
        db 0FFh,004h,0B8h,00Bh,0FFh,000h,012h,000h,0FFh,004h,080h,03Eh,0FFh,006h,0E7h,0FFh
        db 0FFh,000h,064h,000h,0FFh,000h,000h,000h
tandyHeatGunV3 LABEL BYTE
        db 0FFh,004h,0C0h,001h,0FFh,00Ah,060h,0EAh,0FFh,000h,012h,000h,0FFh,00Ah,050h,0C3h
        db 0FFh,00Ch,09Ch,0FFh,0FFh,000h,064h,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyLaserV2 LABEL BYTE
        db 0FFh,004h,028h,023h,0FFh,006h,0E7h,0FFh,0FFh,000h,019h,000h,0FFh,000h,000h,000h
tandyLaserV3 LABEL BYTE
        db 0FFh,004h,0C0h,001h,0FFh,00Ah,0D8h,0D6h,0FFh,00Ch,09Ch,0FFh,0FFh,000h,019h,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyLaserV0 LABEL BYTE
        db 0FFh,004h,0A0h,00Fh,0FFh,00Ah,040h,09Ch,0FFh,00Ch,09Ch,0FFh,0FFh,006h,09Ch,0FFh
        db 0FFh,000h,019h,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyShipLaserV2 LABEL BYTE
        db 0FFh,004h,010h,027h,0FFh,006h,0E7h,0FFh,0FFh,000h,037h,000h,0FFh,000h,000h,000h
tandyShipLaserV3 LABEL BYTE
        db 0FFh,004h,0C0h,001h,0FFh,00Ah,060h,0EAh,0FFh,00Ch,09Ch,0FFh,0FFh,000h,037h,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyShipLaserV0 LABEL BYTE
        db 0FFh,004h,058h,01Bh,0FFh,00Ah,028h,0A0h,0FFh,00Ch,09Ch,0FFh,0FFh,006h,09Ch,0FFh
        db 0FFh,000h,037h,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyNeedleGunV2 LABEL BYTE
        db 0FFh,004h,040h,01Fh,0FFh,000h,028h,000h,0FFh,000h,000h,000h
tandyNeedleGunV3 LABEL BYTE
        db 0FFh,004h,0C0h,001h,0FFh,026h,004h,000h
tandyNeedleGunV3Loop LABEL BYTE
        db 0FFh,00Ah,0D8h,0D6h,0FFh,000h,005h,000h,0FFh,00Ah,001h,000h,0FFh,000h,005h,000h
        db 0FEh,026h
        dw tandyNeedleGunV3Loop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyMicrowaveGunV2 LABEL BYTE
        db 0FFh,026h,014h,000h
tandyMicrowaveGunV2Loop LABEL BYTE
        db 0FFh,004h,070h,017h,0FFh,00Ah,050h,0C3h,0FFh,000h,001h,000h,0FFh,004h,088h,013h
        db 0FFh,00Ah,001h,000h,0FFh,000h,001h,000h,0FFh,004h,030h,075h,0FFh,00Ah,050h,0C3h
        db 0FFh,000h,001h,000h,0FEh,026h
        dw tandyMicrowaveGunV2Loop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyTune14V2 LABEL BYTE
        db 0FFh,004h,0A0h,00Fh,0FFh,000h,01Ch,000h,0FFh,000h,000h,000h
tandyTune14V3 LABEL BYTE
        db 0FFh,004h,0C0h,001h,0FFh,00Ah,050h,0C3h,0FFh,000h,01Ch,000h,0FFh,00Ah,000h,000h
        db 0FFh,000h,000h,000h
tandyRocketV2 LABEL BYTE
        db 0FFh,004h,010h,027h,0FFh,000h,005h,000h,0FFh,004h,0A0h,00Fh,0FFh,006h,064h,000h
        db 0FFh,000h,064h,000h,0FFh,000h,000h,000h
tandyRocketV3 LABEL BYTE
        db 0FFh,004h,0C0h,001h,0FFh,00Ah,060h,0EAh,0FFh,000h,005h,000h,0FFh,00Ah,050h,0C3h
        db 0FFh,00Ch,09Ch,0FFh,0FFh,000h,064h,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyMissV3 LABEL BYTE
        db 0FFh,004h,000h,001h,0FFh,00Ah,030h,075h,0FFh,00Ch,0E8h,003h,0FFh,000h,014h,000h
        db 0FFh,00Ch,018h,0FCh,0FFh,000h,028h,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyStepV3 LABEL BYTE
        db 0FFh,004h,080h,001h,0FFh,00Ah,060h,0EAh,0FFh,00Ch,054h,0F2h,0FFh,000h,010h,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyDazzleGrenadeV1 LABEL BYTE
        db 0FFh,000h,004h,000h
tandyDazzleGrenadeV0 LABEL BYTE
        db 0FFh,00Ah,060h,0EAh,0FFh,00Ch,09Ch,0FFh,0FFh,004h,0E8h,0FDh,0FFh,026h,01Eh,000h
tandyDazzleGrenadeV0Loop LABEL BYTE
        db 0FFh,006h,08Ah,0FDh,0FFh,000h,00Ch,000h,0FFh,006h,076h,002h,0FFh,000h,008h,000h
        db 0FEh,026h
        dw tandyDazzleGrenadeV0Loop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyHitV2 LABEL BYTE
        db 0FFh,004h,0D0h,007h,0FFh,006h,05Ah,000h,0FFh,000h,014h,000h,0FFh,000h,000h,000h
tandyHitV3 LABEL BYTE
        db 0FFh,004h,0C0h,001h,0FFh,00Ah,060h,0EAh,0FFh,00Ch,030h,0F8h,0FFh,000h,014h,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandySonicStunnerV0 LABEL BYTE
        db 0FFh,004h,0C2h,009h,0FFh,00Ah,030h,075h,0FFh,026h,00Ch,000h
tandySonicStunnerV0Loop LABEL BYTE
        db 0FFh,006h,0F7h,0FFh,0FFh,000h,00Ch,000h,0FFh,006h,009h,000h,0FFh,000h,008h,000h
        db 0FEh,026h
        dw tandySonicStunnerV0Loop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyCloudGrenadeV2 LABEL BYTE
        db 0FFh,000h,014h,000h
tandyCloudGrenadeV1 LABEL BYTE
        db 0FFh,000h,014h,000h
tandyCloudGrenadeV0 LABEL BYTE
        db 0FFh,004h,0E3h,098h,0FFh,00Ah,060h,0EAh,0FFh,00Ch,038h,0FFh,0FFh,006h,04Eh,0FFh
        db 0FFh,000h,0C8h,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyDownedV0 LABEL BYTE
        db 0FFh,00Ah,010h,027h,0FFh,00Ch,0F4h,001h,0FFh,004h,000h,0FAh,0FFh,006h,010h,0FFh
        db 0FFh,000h,050h,000h,0FFh,00Ch,000h,000h,0FFh,026h,02Ch,000h
tandyDownedV0Loop LABEL BYTE
        db 0FFh,006h,050h,0FBh,0FFh,000h,002h,000h,0FFh,006h,0D8h,004h,0FFh,000h,002h,000h
        db 0FEh,026h
        dw tandyDownedV0Loop
        db 0FFh,00Ch,061h,0FEh,0FFh,006h,03Ch,000h,0FFh,000h,078h,000h,0FFh,00Ah,000h,000h
        db 0FFh,000h,000h,000h
tandyDownedV2 LABEL BYTE
        db 0FFh,004h,030h,011h,0FFh,006h,00Bh,000h,0FFh,000h,0BCh,000h,0FFh,006h,0F5h,0FFh
        db 0FFh,000h,0BCh,000h,0FFh,000h,000h,000h
tandyDownedV3 LABEL BYTE
        db 0FFh,004h,0C0h,001h,0FFh,00Ah,0A8h,061h,0FFh,00Ch,09Fh,000h,0FFh,000h,0BCh,000h
        db 0FFh,00Ch,061h,0FFh,0FFh,000h,0BCh,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyLaunchV3 LABEL BYTE
        db 0FFh,00Ch,060h,009h,0FFh,004h,000h,001h,0FFh,000h,019h,000h,0FFh,00Ch,0A0h,0F6h
        db 0FFh,000h,019h,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandySilence LABEL BYTE
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyDamageV0 LABEL BYTE
        db 0FFh,00Ah,060h,0EAh,0FFh,00Ch,015h,0FFh,0FFh,004h,0E0h,01Fh,0FFh,026h,006h,000h
tandyDamageV0Loop LABEL BYTE
        db 0FFh,006h,01Eh,000h,0FFh,000h,010h,000h,0FFh,006h,0E2h,0FFh,0FFh,000h,010h,000h
        db 0FEh,026h
        dw tandyDamageV0Loop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyDamageV1 LABEL BYTE
        db 0FFh,00Ah,050h,0C3h,0FFh,00Ch,038h,0FFh,0FFh,004h,010h,040h,0FFh,026h,00Ah,000h
tandyDamageV1Loop LABEL BYTE
        db 0FFh,006h,042h,000h,0FFh,000h,008h,000h,0FFh,006h,0BEh,0FFh,0FFh,000h,008h,000h
        db 0FEh,026h
        dw tandyDamageV1Loop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyDamageV2 LABEL BYTE
        db 0FFh,00Ah,0E8h,0FDh,0FFh,00Ch,0D4h,0FEh,0FFh,004h,0B0h,036h,0FFh,026h,008h,000h
tandyDamageV2Loop LABEL BYTE
        db 0FFh,006h,052h,000h,0FFh,000h,00Ch,000h,0FFh,006h,0B2h,0FFh,0FFh,000h,00Ch,000h
        db 0FEh,026h
        dw tandyDamageV2Loop
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyBoltV0 LABEL BYTE
        db 0FFh,00Ah,060h,0EAh,0FFh,00Ch,050h,0FBh,0FFh,004h,0D0h,034h,0FFh,000h,01Eh,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyBoltV1 LABEL BYTE
        db 0FFh,00Ah,060h,0EAh,0FFh,00Ch,050h,0FBh,0FFh,004h,020h,080h,0FFh,000h,01Eh,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyBoltV2 LABEL BYTE
        db 0FFh,00Ah,060h,0EAh,0FFh,00Ch,050h,0FBh,0FFh,004h,070h,017h,0FFh,000h,00Ah,000h
        db 0FFh,00Ah,000h,000h,0FFh,000h,000h,000h
tandyTune20V0 LABEL BYTE
        db 0FCh
        dw tandyTune20V0Sub
        db 0FFh,000h,000h,000h
tandyTune20V0Sub LABEL BYTE
        db 0FDh,030h,000h,0FFh,010h,00Ch,000h,0FFh,012h,0D3h,0FFh,0FFh,016h
        dw tandyTune20V0Env2
        db 0FFh,01Ch
        dw lfoSine
        db 0FFh,024h,000h,010h,0FFh,022h,028h,000h,0FFh,020h,02Ch,001h,0FDh,060h,000h,0FFh
        db 010h,007h,000h,0FFh,012h,0D3h,0FFh,0FFh,016h
        dw tandyTune20V0Env1
        db 0FFh,01Ch
        dw lfoSine
        db 0FFh,024h,000h,010h,0FFh,022h,016h,000h,0FFh,020h,078h,000h,0FDh,000h,000h,0FFh
        db 010h,007h,000h,0FFh,012h,0D3h,0FFh,0FFh,016h
        dw tandyTune20V0Env3
        db 0FFh,01Ch
        dw lfoSquare
        db 0FFh,024h,000h,002h,0FFh,022h,0C8h,000h,0FFh,020h,010h,000h,0FFh,00Eh,006h,000h
        db 0FBh
tandyTune20V0Env1 LABEL BYTE
        dw 0C350h,0FFFFh,09C4h,0004h
        dw 0F830h,0006h,0000h,0000h
        dw 0BB80h,0FFFFh,0E0C0h,0006h
        dw 0000h,0FFFFh,0000h,0000h
tandyTune20V0Env2 LABEL BYTE
        dw 9C40h,0FFFFh,09C4h,0008h
        dw 0F448h,0005h,0000h,0000h
        dw 0AFC8h,0FFFFh,0F060h,000Bh
        dw 0000h,0FFFFh,0000h,0000h
tandyTune20V0Env3 LABEL BYTE
        dw 0DEA8h,0FFFFh,0FA24h,0006h
        dw 0000h,0000h,0000h,0000h
        dw 0BB80h,0FFFFh,0E0C0h,0006h
        dw 0000h,0FFFFh,0000h,0000h
tandyTune19V0 LABEL BYTE
        db 0FFh,004h,040h,01Fh,0FFh,00Ah,030h,075h,0FFh,006h,014h,000h,0FFh,00Ch,09Ch,0FFh
        db 0FFh,000h,010h,000h,0FFh,00Ah,000h,000h,0FFh,000h,000h,000h

oldInt8Off      dw 0                    ; the INT 8 handler InstallSoundTimer replaced:
oldInt8Seg      dw 0                    ; offset, then segment

; ---------------------------------------------------------------------------------
; InstallSoundTimer: hook INT 8 and speed the timer up to the driver's tick rate.

InstallSoundTimer PROC FAR
        push    ds                      ; keep the caller's DS and ES
        push    es
        mov     ax,CODE
        mov     ds,ax                   ; DS = the driver's data
        mov     ax,3508h                ; DOS get vector: INT 8, the timer tick
        int     21h                     ; ES:BX = the current handler
        mov     word ptr cs:[oldInt8Off],bx     ; kept for the ISR to chain to and for
        mov     word ptr cs:[oldInt8Seg],es     ; UninstallSoundTimer to put back
        push    ds                      ; redundant: DS is already CODE, so
        mov     dx,CODE                 ; this reload of DS and the pop below
        mov     ds,dx                   ; change nothing
        mov     dx,offset TimerIsr      ; the new handler
        mov     ax,2508h                ; DOS set vector: INT 8
        int     21h                     ; the ISR is now INT 8
        pop     ds                      ; DS = CODE again
        mov     al,0B6h                 ; PIT control: channel 2 (speaker), lo/hi byte, mode 3;
        out     43h,al                  ; SpeakerTick loads its count
        mov     ax,TICKCOUNT            ; channel 0 count, written lo then hi through
        out     40h,al                  ; the access mode the BIOS left it in
        mov     al,ah
        out     40h,al
        pop     es
        pop     ds
        retf
InstallSoundTimer ENDP

; ---------------------------------------------------------------------------------
; UninstallSoundTimer: give INT 8 back, slow the timer down again and silence both devices.

UninstallSoundTimer PROC FAR
        push    ds                      ; keep the caller's DS
        mov     ax,CODE
        mov     ds,ax                   ; DS = the driver's data
        push    ds                      ; saved while DS holds the old handler's segment
        mov     dx,word ptr cs:[oldInt8Off] ; the handler InstallSoundTimer saved
        mov     ax,word ptr cs:[oldInt8Seg]
        mov     ds,ax
        mov     ax,2508h                ; DOS set vector: INT 8
        int     21h                     ; the old handler is INT 8 again
        pop     ds                      ; DS = CODE again
        mov     ax,0FFFFh               ; channel 0 count 65535: about the BIOS's 18.2 Hz
        out     40h,al                  ; written lo then hi
        mov     al,ah
        out     40h,al
        in      al,61h                  ; speaker control port
        and     al,0FCh                 ; clear the timer-2 gate and speaker data bits
        out     61h,al                  ; speaker off
        mov     al,TANDYOFF+00h         ; attenuate Tandy tone channels 0, 1, 2 and the
        out     TANDYPORT,al            ; noise channel to off
        mov     al,TANDYOFF+20h         ; channel 1 attenuation off
        out     TANDYPORT,al
        mov     al,TANDYOFF+40h         ; channel 2 attenuation off
        out     TANDYPORT,al
        mov     al,TANDYOFF+60h         ; noise channel attenuation off
        out     TANDYPORT,al
        pop     ds
        retf
UninstallSoundTimer ENDP

; ---------------------------------------------------------------------------------
; TimerIsr: the INT 8 handler. First the timeout: once armed, it counts ticks down, and at zero puts a fake
; runtime-error message on screen and ends the program. Otherwise it runs one tick of each device, unless a tick or a
; voice writer is already in progress, and passes every TICKDIVth tick on to the BIOS handler so the time of day keeps
; its usual rate.

TimerIsr PROC FAR
        sti                             ; let other interrupts in during the tick
        push    ax                      ; save what the tick uses; StepVoice saves CX and DI
        push    bx
        push    dx
        push    ds
        push    si
        mov     ax,CODE
        mov     ds,ax                   ; DS = the driver's data, whatever was interrupted
        cmp     ExitCount,0
        jz      @@tick                  ; not armed: go straight to the tick
        dec     ExitCount               ; one tick nearer the exit
        jnz     @@tick                  ; armed and still counting
        mov     ah,VGETMODE             ; BIOS get video mode, into AL
        int     BIOSVIDEO               ; AL = the current mode
        mov     ah,VSETMODE             ; and set that same mode, which clears the screen
        int     BIOSVIDEO
        mov     bl,7                    ; redundant: overwritten by the next load of BX
        mov     ah,7Fh                  ; mask off each character's high bit, in place;
        mov     cx,ERRLEN               ; CX, ES and BP go unsaved: this path never returns
        mov     bx,CODE                 ; ES = this segment
        mov     es,bx
        mov     bx,offset exitMsg       ; ES:BX = the text
@@unmask:
        mov     al,es:[bx]              ; clear bit 7 of each of the ERRLEN bytes
        and     al,ah
        mov     es:[bx],al
        inc     bx
        loop    @@unmask
        mov     bl,7                    ; attribute: light gray on black
        mov     ah,VWRITESTR            ; BIOS write string, AL = 1: move the cursor
        mov     al,1
        mov     bh,0                    ; page 0
        mov     cx,ERRLEN               ; CX = characters to write
        xor     dx,dx                   ; row 0, column 0
        mov     bp,CODE                 ; ES = this segment
        mov     es,bp
        mov     bp,offset exitMsg       ; ES:BP = the text
        int     BIOSVIDEO               ; write the message
        mov     ah,4Ch                  ; DOS terminate, exit code 255 -- with INT 8
        mov     al,0FFh                 ; and the timer rate still the driver's
        int     21h                     ; never returns
@@tick:
        cmp     isSeqBusy,0
        jnz     @@divide                ; a tick or a voice writer is mid-update: skip this one
        mov     isSeqBusy,1             ; a tick is running
        call    SpeakerTick
        call    TandyTick
        mov     isSeqBusy,0             ; tick over
@@divide:
        dec     divCount                ; one ISR tick nearer a BIOS tick
        jnz     @@eoi                   ; not yet the BIOS's tick
        mov     divCount,TICKDIV        ; restart the count
        pop     si                      ; the interrupted code's registers back
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        jmp     dword ptr cs:[oldInt8Off] ; the BIOS handler acknowledges the PIC itself
@@eoi:
        mov     al,20h                  ; non-specific end of interrupt to the master PIC
        out     20h,al
        pop     si                      ; the interrupted code's registers back
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        iret
TimerIsr ENDP

; ---------------------------------------------------------------------------------
; SpeakerTick: step the speaker's four voices. The speaker plays one note at a time: the first voice left with a
; non-zero level and a note still running drives PIT channel 2 and the gate bits of port 61h. No tune, output off or no
; such voice leaves both gate bits clear.

SpeakerTick PROC NEAR
        mov     bx,curTune              ; BX = the tune last started
        cmp     bx,0
        jz      @@gate                  ; BL = 0: speaker off
        mov     spkrVoice,0             ; no voice has the speaker yet
        mov     voiceLeft,4             ; four voices to step
        mov     si,offset spkrFreq      ; the speaker's pitch table
        mov     freqBase,si             ; RunStream's notes read the speaker's pitches
        mov     si,offset spkrBlocks    ; the speaker's first block
        mov     voiceBase,si            ; and address the speaker's blocks
@@voice:
        cmp     word ptr [si+vfDuration],0
        jz      @@next                  ; voice idle
        call    StepVoice               ; one tick of the voice at SI
        cmp     spkrVoice,0
        jnz     @@next                  ; an earlier voice already has the speaker
        cmp     word ptr [si+vfLevel],0 ; a zero level is silent
        jz      @@next
        cmp     word ptr [si+vfDuration],0
        jz      @@next                  ; its stream ended during the step
        mov     spkrVoice,si            ; this voice drives the speaker
@@next:
        add     si,VOICESIZE
        dec     voiceLeft
        jnz     @@voice
        mov     bl,isOutputOn           ; BL = the output switch
        cmp     bl,0
        jz      @@gate                  ; output off: BL = 0
        mov     bx,spkrVoice            ; BX = the chosen voice
        cmp     bx,0
        jz      @@gate                  ; no voice: BL = 0
        mov     si,bx                   ; SI = its block
        mov     ax,[si+vfOutPeriod]     ; the voice's PIT divisor to channel 2, lo then hi
        out     42h,al                  ; PIT channel 2 data, low byte
        mov     al,ah
        out     42h,al
        mov     bx,[si+vfLevel]         ; low two bits: timer-2 gate and speaker data
        and     bl,3                    ; BL = those two bits
@@gate:
        in      al,61h                  ; port 61h's gate and data bits = BL's low two
        and     al,0FCh                 ; keep the other bits
        or      al,bl                   ; set the gate and data bits from BL
        out     61h,al
        ret
SpeakerTick ENDP

; ---------------------------------------------------------------------------------
; TandyTick: step the Tandy voices, then write each one's tone and attenuation to the SN76489. Voices 0-2 are its tone
; channels; voice 3 is the noise channel, which takes a single control byte and so gets no second tone byte.

TandyTick PROC NEAR
        mov     bx,curTune              ; BX = the tune last started
        cmp     bx,0
        jz      @@silence               ; no tune
        mov     voiceLeft,4             ; four voices to step
        mov     si,offset tandyFreq     ; the Tandy's pitch table
        mov     freqBase,si             ; RunStream's notes read the Tandy's pitches
        mov     si,offset tandyBlocks   ; the Tandy's first block
        mov     voiceBase,si            ; and address the Tandy's blocks
@@step:
        cmp     word ptr [si+vfDuration],0
        jz      @@stepped               ; voice idle
        call    StepVoice               ; one tick of the voice at SI
@@stepped:
        add     si,VOICESIZE
        dec     voiceLeft
        jnz     @@step
        mov     al,isOutputOn           ; AL = the output switch
        cmp     al,0
        jz      @@silence               ; output off
        mov     voiceLeft,4             ; second pass: write the four voices out
        mov     si,offset tandyBlocks   ; from the first Tandy block
        mov     dl,80h                  ; latch bit plus channel 0; +20h per channel
@@write:
        mov     ax,[si+vfOutPeriod]     ; the tone register takes bits 15-6 of it
        shr     ax,1                    ; AX >> 2: bits 15-6 now bits 13-4
        shr     ax,1
        shr     al,1                    ; AL >> 4
        shr     al,1
        shr     al,1
        shr     al,1                    ; AL = its low four bits, AH = its high six
        xor     al,dl                   ; with the latch and channel bits
        out     TANDYPORT,al            ; latch the channel's tone, low bits
        cmp     dl,0E0h                 ; the noise channel (DL = E0h)?
        jz      @@volume                ; the noise channel has no second byte
        mov     al,ah                   ; AL = tone bits 9-4
        out     TANDYPORT,al            ; tone, high bits
@@volume:
        mov     ax,0FFFFh               ; FFFFh - vfLevel
        sub     ax,[si+vfLevel]         ; louder level, smaller attenuation
        shr     ah,1                    ; AH >> 4
        shr     ah,1
        shr     ah,1
        shr     ah,1                    ; AH = the attenuation, 0 to 15
        mov     al,ah
        xor     al,dl                   ; with the latch and channel bits
        add     al,10h                  ; the channel's attenuation register
        out     TANDYPORT,al
        add     dl,20h                  ; the next channel
        add     si,VOICESIZE
        dec     voiceLeft
        jnz     @@write
        ret
@@silence:
        mov     al,TANDYOFF+00h         ; channels 0, 1, 2 and noise to off
        out     TANDYPORT,al
        mov     al,TANDYOFF+20h         ; channel 1 off
        out     TANDYPORT,al
        mov     al,TANDYOFF+40h         ; channel 2 off
        out     TANDYPORT,al
        mov     al,TANDYOFF+60h         ; noise channel off
        out     TANDYPORT,al
        ret
TandyTick ENDP

; ---------------------------------------------------------------------------------
; StepVoice: one tick of the voice block at SI. Apply the level and pitch slides and the LFO modulation, count the note
; and its gate time down, run the stream when the note ends, and walk the envelope table when its step timer runs out.

StepVoice PROC NEAR
        push    cx                      ; the ISR does not save CX or DI
        push    di
        mov     ax,[si+vfLevelAdd]
        add     [si+vfLevel],ax         ; level slide
        mov     ax,[si+vfPeriodAdd]
        add     [si+vfPeriod],ax        ; pitch slide
        sub     dx,dx                   ; DX = the modulation, zero with no wave running
        mov     ax,[si+vfLfoPhase]
        add     ax,[si+vfLfoRate]
        jz      @@nowave                ; zero sum: no modulation
        cmp     ax,[si+vfLfoWrap]
        jc      @@phase
        sub     ax,[si+vfLfoWrap]       ; past the table's end: wrap
@@phase:
        mov     [si+vfLfoPhase],ax
        mov     cl,4
        sar     ax,cl                   ; the phase counts sixteenths of a sample
        add     ax,[si+vfLfoTable]
        mov     di,ax                   ; DI = the sample
        mov     ah,[di]                 ; signed sample, scaled by the depth: DX = the
        mov     al,0                    ; high word of sample*256*depth
        imul    word ptr [si+vfLfoDepth] ; DX:AX = AX * depth
@@nowave:
        add     dx,[si+vfPeriod]        ; plus the unmodulated period
        mov     [si+vfOutPeriod],dx     ; what the device writers send
        cmp     word ptr [si+vfGateLen],0
        jz      @@count                 ; no gate running
        dec     word ptr [si+vfGateLen]
        jnz     @@count
        mov     word ptr [si+vfEnvPos],10h      ; gate over: envelope from entry 4, at once
        mov     word ptr [si+vfEnvWait],1 ; step on the next test
@@count:
        dec     word ptr [si+vfDuration]
        jnz     @@envelope              ; the note is still sounding
        call    RunStream               ; read the stream's next event
@@envelope:
        cmp     word ptr [si+vfEnvWait],0
        jz      @@done                  ; no envelope running
        dec     word ptr [si+vfEnvWait]
        jnz     @@done
@@entry:
        mov     bx,[si+vfEnvBase]       ; BX = the envelope table
        add     bx,[si+vfEnvPos]        ; BX = the current entry: step word, ticks word
        cmp     word ptr [bx+2],0FFFFh
        jnz     @@ramp                  ; no: a ramp entry
        mov     ax,[bx]                 ; count FFFFh: set the level outright
        mov     [si+vfLevel],ax
        cmp     ax,0
        jnz     @@setnext               ; non-zero: leave the ramp
        mov     [si+vfLevelAdd],ax      ; and a zero level stops the ramp
@@setnext:
        add     word ptr [si+vfEnvPos],4
        jmp     @@entry                 ; and go straight on to the next entry
@@ramp:
        mov     ax,[bx]                 ; otherwise ramp by this step for this many ticks
        mov     [si+vfLevelAdd],ax
        mov     ax,[bx+2]
        mov     [si+vfEnvWait],ax
        add     word ptr [si+vfEnvPos],4
@@done:
        pop     di                      ; the ISR's CX and DI back
        pop     cx
        ret
StepVoice ENDP

; ---------------------------------------------------------------------------------
; RunStream: read the stream of the voice at SI from its stream pointer, up to and including the next note, and leave
; the pointer after it. A byte from 0FAh up is a command, dispatched through cmdTable; anything lower begins a note.
;
;   FA            clear the current block's sound fields
;   FB            return to the address FC saved
;   FC addr       call: save the address after the operand, continue at addr
;   FD blk        make block blk (an offset into the block set) current, and clear it
;   FE fld addr   loop: while the counter at field fld counts down, continue at addr;
;                 a counter already zero loops for ever
;   FF fld val    set field fld of the current block; setting vfDuration ends the step
;   vvv.. nn len  note: voice vvv in the top three bits of the first byte, note number
;                 nn (7Fh a rest, bit 7 set on the last note of a chord), length len
;                 in ticks, or in units of vfTempo when that is more than 1

RunStream PROC NEAR
        mov     di,[si+vfStream]        ; DI = the stream pointer throughout
        cmp     di,0
        jnz     @@start
        ret                             ; no stream: the voice stays idle
@@start:
        mov     seqVoice,si             ; the voice whose stream this is; SI may move (FD)
seqNext:
        mov     bl,[di]                 ; the next stream byte
        inc     di
        cmp     bl,0FAh                 ; FA to FF is a command
        jnc     @@command
        jmp     @@note                  ; lower: a note
@@command:
        sub     bh,bh
        sub     bl,0FAh                 ; BL = 0 for FA ... 5 for FF
        add     bl,bl                   ; BX = (byte - FA) * 2
        jmp     cmdTable[bx]
seqCmdLoop:
        mov     bl,[di]                 ; the counter's field
        inc     di
        mov     bh,0                    ; BX = the field offset
        mov     ax,[di]                 ; the loop's target
        add     di,2
        cmp     word ptr [bx+si],0
        jz      @@loopback              ; zero: loop without counting
        dec     word ptr [bx+si]
        jz      seqNext                 ; counted out: fall past the loop
@@loopback:
        mov     di,ax
        jmp     seqNext
seqCmdClear:
        mov     si,[di]                 ; the block's offset in the block set
        add     di,2
        add     si,voiceBase            ; SI = that block; then clear it as FA does
seqCmdReset:
        sub     bx,bx                   ; zero every field but the duration, the stream
        mov     [si+vfPeriod],bx        ; pointer, the tempo, the gate and the two loop
        mov     [si+vfPeriodAdd],bx     ; counters
        mov     [si+vfOutPeriod],bx
        mov     [si+vfLevel],bx
        mov     [si+vfLevelAdd],bx
        mov     [si+vfReleaseLead],bx
        mov     [si+vfTranspose],bx
        mov     [si+vfEnvBase],bx
        mov     [si+vfEnvPos],bx
        mov     [si+vfEnvWait],bx
        mov     [si+vfLfoTable],bx
        mov     [si+vfLfoPhase],bx
        mov     [si+vfLfoRate],bx
        mov     [si+vfLfoDepth],bx
        mov     [si+vfLfoWrap],bx
        jmp     seqNext
seqCmdSet:
        mov     bl,[di]                 ; the field
        inc     di
        mov     bh,0                    ; BX = the field offset
        mov     ax,[di]                 ; its new value
        inc     di
        inc     di
        mov     [bx+si],ax
        cmp     bl,vfDuration
        jnz     seqNext                 ; any other field: read on
@@endstep:
        mov     si,seqVoice             ; back to the voice whose stream this is
        cmp     word ptr [si+vfDuration],0 ; a duration set?
        jnz     @@save
        mov     bl,4                    ; stream over: clear this voice's tune byte
        sub     bl,voiceLeft            ; (voice number = 4 - voiceLeft)
        sub     bh,bh
        mov     voiceTune[bx],0
        mov     di,0                    ; and park the stream pointer
@@save:
        mov     [si+vfStream],di
        ret
seqCmdReturn:
        mov     di,seqRet               ; DI = where the FC call left off
        jmp     seqNext
seqCmdCall:
        mov     ax,[di]                 ; the target
        add     di,2
        mov     seqRet,di               ; one level only: a nested call overwrites it
        mov     di,ax
        jmp     seqNext
@@chord:
        mov     bl,[di]                 ; a chord's next note: its first byte
        inc     di
@@note:
        push    di                      ; the note's second byte
        mov     al,bl                   ; AL = the first byte
        mov     cl,5
        shr     al,cl                   ; AL = its top three bits
        mov     cl,al                   ; CL = the voice number
        mul     blockSize               ; AX = voice * VOICESIZE
        add     ax,voiceBase            ; plus the device's block set
        mov     di,ax                   ; DI = that voice's block
        pop     bx                      ; pop and push again:
        push    bx                      ; BX = the note's second byte, kept for @@nextnote
        mov     ax,[si+vfTempo]         ; AX = the tempo
        cmp     al,1
        ja      @@scaled
        xor     ah,ah                   ; AX = the length byte alone
        mov     al,[bx+1]               ; length in ticks
        jmp     short @@length
@@scaled:
        mul     byte ptr [bx+1]         ; length in tempo units
@@length:
        mov     [si+vfDuration],ax      ; the current block waits out the note
        mov     al,[bx]                 ; AL = the note byte
        and     ax,7Fh                  ; AX = the note number
        cmp     ax,7Fh
        jz      @@nextnote              ; a rest: no pitch
        cmp     cl,0
        ja      @@nextnote              ; only voice 0 takes a pitch
        mov     cx,[si+vfDuration]      ; CX = the note's length
        mov     [di+vfDuration],cx      ; the voice sounds for the note's length
        mov     [di+vfGateLen],cx       ; and releases when it ends
        add     ax,[di+vfTranspose]     ; transposed
        mov     word ptr [di+vfEnvPos],0        ; restart the envelope: now if DI is seqVoice, else at its next step
        mov     word ptr [di+vfEnvWait],1 ; the envelope's first entry on its next test
        mov     cx,0FFh                 ; CL = -1: the octave count
@@octave:
        inc     cl                      ; CL = note / 12, AX = note mod 12
        sub     ax,12                   ; one octave (12 semitones) down
        jnc     @@octave                ; until the note goes negative
        add     ax,12                   ; back to the last non-negative
        mov     bx,ax                   ; BX = the semitone
        add     bx,bx
        cmp     di,offset tandyBlocks+3*VOICESIZE ; decides nothing: both ways land on
        jnz     @@pitch                           ; the next instruction
@@pitch:
        add     bx,freqBase             ; plus the device's pitch table
        mov     ax,[bx]                 ; the semitone's value, halved once per octave
        shr     ax,cl
        mov     [di+vfPeriod],ax
        mov     [di+vfOutPeriod],ax     ; reaches the hardware at once
@@nextnote:
        pop     di                      ; DI = the note's second byte
        mov     al,[di]                 ; AL = the note byte
        inc     di
        inc     di
        and     al,80h
        jnz     @@last                  ; bit 7: the chord's last note ends the step
        jmp     @@chord
@@last:
        jmp     @@endstep               ; save the pointer and return
RunStream ENDP

; ---------------------------------------------------------------------------------
; ProgramSpeakerVoices(song) and ProgramTandyVoices(song): start tune song on the speaker voices or the Tandy voices.
; Every voice the tune has a stream for is cleared, pointed at that stream and given a one-tick note, so the ISR's next
; tick reads its first event; a voice with no stream in the table is left alone. isSeqBusy holds the ISR off while the
; blocks are rewritten.

ProgramSpeakerVoices PROC FAR
        push    bp
        mov     bp,sp                   ; BP addresses the song parameter
        push    ax                      ; Pascal's registers, DS included, come back intact
        push    bx
        push    di
        push    si
        push    ds
        mov     si,CODE
        mov     ds,si                   ; DS = the driver's data
        mov     si,[bp+6]
        mov     curTune,si              ; the tune last started
        add     si,si
        add     si,si
        add     si,si                   ; four words per tune
        mov     isSeqBusy,1             ; hold the ISR off
        mov     voiceLeft,4
        mov     di,offset spkrBlocks    ; DI = the speaker's first block
@@voice:
        mov     ax,speakerTunes[si]     ; this voice's stream
        cmp     ax,0
        jz      @@next                  ; none: leave the voice alone
        mov     bx,VOICESIZE-2
@@clear:
        mov     word ptr [bx+di],0      ; clear the whole block, last word first
        sub     bx,2
        jge     @@clear
        mov     [di+vfStream],ax
        mov     bl,4
        sub     bl,voiceLeft            ; BX = the voice number, 4 - voiceLeft
        sub     bh,bh
        mov     ax,curTune
        mov     voiceTune[bx],al        ; record it for the voice
        mov     word ptr [di+vfDuration],1      ; read the stream on the next tick
@@next:
        add     di,VOICESIZE
        add     si,2
        dec     voiceLeft
        jnz     @@voice
        mov     isSeqBusy,0             ; let the ISR back in
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        retf    2                       ; pop the song parameter
ProgramSpeakerVoices ENDP

ProgramTandyVoices PROC FAR             ; ProgramSpeakerVoices over the Tandy's tables
        push    bp
        mov     bp,sp                   ; BP addresses the song parameter
        push    ax                      ; Pascal's registers, DS included, come back intact
        push    bx
        push    di
        push    si
        push    ds
        mov     si,CODE
        mov     ds,si                   ; DS = the driver's data
        mov     si,[bp+6]
        mov     curTune,si              ; the tune last started
        add     si,si
        add     si,si
        add     si,si                   ; four words per tune
        mov     isSeqBusy,1             ; hold the ISR off
        mov     voiceLeft,4
        mov     di,offset tandyBlocks   ; DI = the Tandy's first block
@@voice:
        mov     ax,tandyTunes[si]       ; this voice's stream
        cmp     ax,0
        jz      @@next                  ; none: leave the voice alone
        mov     bx,VOICESIZE-2
@@clear:
        mov     word ptr [bx+di],0      ; clear the whole block, last word first
        sub     bx,2
        jge     @@clear
        mov     [di+vfStream],ax
        mov     bl,4
        sub     bl,voiceLeft            ; BX = the voice number, 4 - voiceLeft
        sub     bh,bh
        mov     ax,curTune
        mov     voiceTune[bx],al        ; record it for the voice
        mov     word ptr [di+vfDuration],1      ; read the stream on the next tick
@@next:
        add     di,VOICESIZE
        add     si,2
        dec     voiceLeft
        jnz     @@voice
        mov     isSeqBusy,0             ; let the ISR back in
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        retf    2                       ; pop the song parameter
ProgramTandyVoices ENDP

; ---------------------------------------------------------------------------------
; SetSoundOutputEnabled(value): the low byte of value becomes isOutputOn.

SetSoundOutputEnabled PROC FAR
        push    bp
        mov     bp,sp                   ; BP addresses the value parameter
        push    ax                      ; Pascal's registers, DS included, come back intact
        push    ds
        mov     ax,CODE
        mov     ds,ax                   ; DS = the driver's data
        mov     ax,[bp+6]
        mov     isOutputOn,al           ; its low byte is the switch
        pop     ds
        pop     ax
        pop     bp
        retf    2                       ; pop the value parameter
SetSoundOutputEnabled ENDP

CODE    ENDS
        END

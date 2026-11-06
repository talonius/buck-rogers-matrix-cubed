; ail.asm -- John Miles' IBM Audio Interface Library (AIL) 2.x application program interface, linked into Xmidi's
; code segment through {$L AIL.OBJ}.  Xmidi calls it through the Turbo Pascal adapters at the end of this file, which
; take Turbo Pascal's argument order and call the C-convention AIL routines.
;
; The API keeps all of its state in this code segment and addresses it through CS, whatever the caller's DS.
; It owns a 17-slot timer multiplexer on INT 8 (slots 0..15 for callers, slot BIOS_H for the BIOS clock handler it
; displaces), the 8253 PIT programming behind it, a private interrupt stack, and a table of up to 16 registered drivers.
; A driver is a loaded image whose procedure table pairs AIL function numbers (the equates below) with entry offsets;
; each AIL call loads its number and jumps to call_driver, which finds the entry and enters it with the caller's own
; argument frame.  current_rev (200) is the API revision a driver may require.
;
; Every AIL_* routine is a FAR, C-convention PROC (MODEL MEDIUM,C): arguments are pushed right to left and the
; caller removes them.  The Turbo Pascal adapters are FAR with its callee-pops RET n; API_timer is an interrupt
; handler, find_proc takes registers, and call_driver is entered by a jump, or by a far call once its caller has
; pushed the arguments again.  A PROC's USES line makes its prologue push those registers and each RET pop them again.
;
; The DIGPAK driver interface and the INT 70h real-time-clock timer are assembly options turned off here (DIGPAK
; FALSE, USE_INT8 TRUE).
;
; Author: John Miles.  Copyright (C) 1991, 1992 Miles Design, Inc.
; Miles Design, Inc., 10926 Jollyville #308, Austin, TX 78759
; (512) 345-2642 / FAX (512) 338-9630 / BBS (512) 454-9990

                MODEL MEDIUM,C          ;Procedures far, data near by default
                LOCALS __               ;Enable local labels with __ prefix
                JUMPS                   ;Enable auto jump sizing

                ;
                ;Configuration equates
                ;

FALSE           equ 0
TRUE            equ -1

DIGPAK          equ FALSE               ;TRUE to assemble DIGPAK support code
DIGPAK_SHARE    equ FALSE               ;FALSE to disable DIGPAK timer sharing

USE_INT8        equ TRUE                ;FALSE to use real-time clock INT 70H
                                        ;(incompatible w/Windows & OS/2)

RTC_FREQ        equ 256                 ;RTC rate default = 256 Hz.
RTC_FREQ_BITS   equ 1000b               ;(establishes maximum timer frequency)

                ;
                ;Macros, internal equates
                ;

; The assembly equates of John Miles' IBM Audio Interface Library (AIL) 2.x:
; sequence and digital-playback states, the MIDI and XMIDI controller numbers AIL drivers recognize, and the
; function numbers by which this file finds each routine in a loaded driver's procedure table.  Equates emit no bytes;
; this file refers only to the driver function numbers, and to the DAC states in its unassembled DIGPAK branch.
;
; Author: John Miles.  Copyright (C) 1991, 1992 Miles Design, Inc.
; Miles Design, Inc., 10926 Jollyville #308, Austin, TX 78759
; (512) 345-2642 / FAX (512) 338-9630 / BBS (512) 454-9990

SEQ_STOPPED     equ 0                   ;AIL_sequence_status results
SEQ_PLAYING     equ 1
SEQ_DONE        equ 2

DAC_STOPPED     equ 0                   ;digital playback and sound buffer states
DAC_PAUSED      equ 1
DAC_PLAYING     equ 2
DAC_DONE        equ 3

                        ;
                        ;MIDI and XMIDI controllers recognized by AIL drivers
                        ;

START_MSB_1     equ 32                  ;System Exclusive XMIDI controllers
START_KSB_1     equ 33                  ;(Roland DT1 format)
START_LSB_1     equ 34
DATA_BYTE_1     equ 35
FINAL_BYTE_1    equ 36
START_MSB_2     equ 37
START_KSB_2     equ 38
START_LSB_2     equ 39
DATA_BYTE_2     equ 40
FINAL_BYTE_2    equ 41
START_MSB_3     equ 42
START_KSB_3     equ 43
START_LSB_3     equ 44
DATA_BYTE_3     equ 45
FINAL_BYTE_3    equ 46

RHYTHM_KEY_TIMB equ 58                  ;Roland-exclusive XMIDI controllers
PATCH_REVERB    equ 59
PATCH_BENDER    equ 60
REVERB_MODE     equ 61
REVERB_TIME     equ 62
REVERB_LEVEL    equ 63

CHAN_LOCK       equ 110                 ;General XMIDI controllers
CHAN_PROTECT    equ 111
VOICE_PROTECT   equ 112
TIMBRE_PROTECT  equ 113
PATCH_BANK_SEL  equ 114
INDIRECT_C_PFX  equ 115
FOR_LOOP        equ 116
NEXT_LOOP       equ 117
CLEAR_BEAT_BAR  equ 118
CALLBACK_TRIG   equ 119
SEQ_INDEX       equ 120

MODULATION      equ 1                   ;MIDI controllers and Channel Mode
PART_VOLUME     equ 7                   ;messages recognized by AIL drivers
PANPOT          equ 10
EXPRESSION      equ 11
SUSTAIN         equ 64
RESET_ALL_CTRLS equ 121
ALL_NOTES_OFF   equ 123

                        ;
                        ;Driver function numbers: the first word of each entry in a driver's procedure table,
                        ;which find_proc searches.  Each comment names the AIL call that reaches it.
                        ;

AIL_DESC_DRVR           equ 100         ;AIL_describe_driver
AIL_DET_DEV             equ 101         ;AIL_detect_device
AIL_INIT_DRVR           equ 102         ;AIL_init_driver
AIL_SERVE_DRVR          equ 103         ;the driver's timer service, which AIL_init_driver registers
AIL_SHUTDOWN_DRVR       equ 104         ;AIL_shutdown_driver

AIL_INDEX_VOC_BLK       equ 120         ;AIL_index_VOC_block
AIL_REG_SND_BUFF        equ 121         ;AIL_register_sound_buffer
AIL_SND_BUFF_STAT       equ 122         ;AIL_sound_buffer_status
AIL_P_VOC_FILE          equ 123         ;AIL_play_VOC_file
AIL_VOC_PB_STAT         equ 124         ;AIL_VOC_playback_status
AIL_START_D_PB          equ 125         ;AIL_start_digital_playback
AIL_STOP_D_PB           equ 126         ;AIL_stop_digital_playback
AIL_PAUSE_D_PB          equ 127         ;AIL_pause_digital_playback
AIL_RESUME_D_PB         equ 128         ;AIL_resume_digital_playback
AIL_SET_D_PB_VOL        equ 129         ;AIL_set_digital_playback_volume
AIL_D_PB_VOL            equ 130         ;AIL_digital_playback_volume
AIL_SET_D_PB_PAN        equ 131         ;AIL_set_digital_playback_panpot
AIL_D_PB_PAN            equ 132         ;AIL_digital_playback_panpot
AIL_F_VOC_FILE          equ 133         ;format a .VOC file for the device (DIGPAK branch only)
AIL_F_SND_BUFF          equ 134         ;format a sound buffer for the device (DIGPAK branch only)

AIL_STATE_TAB_SIZE      equ 150         ;AIL_state_table_size
AIL_REG_SEQ             equ 151         ;AIL_register_sequence
AIL_REL_SEQ_HND         equ 152         ;AIL_release_sequence_handle
AIL_T_CACHE_SIZE        equ 153         ;AIL_default_timbre_cache_size
AIL_DEFINE_T_CACHE      equ 154         ;AIL_define_timbre_cache
AIL_T_REQ               equ 155         ;AIL_timbre_request
AIL_INSTALL_T           equ 156         ;AIL_install_timbre
AIL_PROTECT_T           equ 157         ;AIL_protect_timbre
AIL_UNPROTECT_T         equ 158         ;AIL_unprotect_timbre
AIL_T_STATUS            equ 159         ;AIL_timbre_status

AIL_START_SEQ           equ 170         ;AIL_start_sequence
AIL_STOP_SEQ            equ 171         ;AIL_stop_sequence
AIL_RESUME_SEQ          equ 173         ;AIL_resume_sequence
AIL_SEQ_STAT            equ 174         ;AIL_sequence_status
AIL_REL_VOL             equ 175         ;AIL_relative_volume
AIL_REL_TEMPO           equ 176         ;AIL_relative_tempo
AIL_SET_REL_VOL         equ 177         ;AIL_set_relative_volume
AIL_SET_REL_TEMPO       equ 178         ;AIL_set_relative_tempo
AIL_BEAT_CNT            equ 179         ;AIL_beat_count
AIL_BAR_CNT             equ 180         ;AIL_measure_count
AIL_BRA_INDEX           equ 181         ;AIL_branch_index

AIL_CON_VAL             equ 182         ;AIL_controller_value
AIL_SET_CON_VAL         equ 183         ;AIL_set_controller_value
AIL_CHAN_NOTES          equ 185         ;AIL_channel_notes
AIL_SEND_CV_MSG         equ 186         ;AIL_send_channel_voice_message
AIL_SEND_SYSEX_MSG      equ 187         ;AIL_send_sysex_message
AIL_WRITE_DISP          equ 188         ;AIL_write_display
AIL_INSTALL_CB          equ 189         ;AIL_install_callback
AIL_CANCEL_CB           equ 190         ;AIL_cancel_callback

AIL_LOCK_CHAN           equ 191         ;AIL_lock_channel
AIL_MAP_SEQ_CHAN        equ 192         ;AIL_map_sequence_channel
AIL_RELEASE_CHAN        equ 193         ;AIL_release_channel
AIL_TRUE_SEQ_CHAN       equ 194         ;AIL_true_sequence_channel

                INCLUDE ail.mac         ;general-use macros

                .CODE

                ;
                ;Process services
                ;

                PUBLIC AIL_startup
                PUBLIC AIL_shutdown
                PUBLIC AIL_register_timer
                PUBLIC AIL_set_timer_period
                PUBLIC AIL_set_timer_frequency
                PUBLIC AIL_set_timer_divisor
                PUBLIC AIL_interrupt_divisor
                PUBLIC AIL_start_timer
                PUBLIC AIL_start_all_timers
                PUBLIC AIL_stop_timer
                PUBLIC AIL_stop_all_timers
                PUBLIC AIL_release_timer_handle
                PUBLIC AIL_release_all_timers

                ;
                ;Installation services
                ;

                PUBLIC AIL_register_driver
                PUBLIC AIL_release_driver_handle
                PUBLIC AIL_describe_driver
                PUBLIC AIL_detect_device
                PUBLIC AIL_init_driver
                PUBLIC AIL_shutdown_driver

                ;
                ;Extended MIDI (XMIDI) performance services
                ;

                PUBLIC AIL_state_table_size
                PUBLIC AIL_register_sequence
                PUBLIC AIL_release_sequence_handle

                PUBLIC AIL_default_timbre_cache_size
                PUBLIC AIL_define_timbre_cache
                PUBLIC AIL_timbre_request
                PUBLIC AIL_install_timbre
                PUBLIC AIL_protect_timbre
                PUBLIC AIL_unprotect_timbre
                PUBLIC AIL_timbre_status

                PUBLIC AIL_start_sequence
                PUBLIC AIL_stop_sequence
                PUBLIC AIL_resume_sequence
                PUBLIC AIL_sequence_status
                PUBLIC AIL_relative_volume
                PUBLIC AIL_relative_tempo
                PUBLIC AIL_set_relative_volume
                PUBLIC AIL_set_relative_tempo
                PUBLIC AIL_beat_count
                PUBLIC AIL_measure_count
                PUBLIC AIL_branch_index

                PUBLIC AIL_controller_value
                PUBLIC AIL_set_controller_value
                PUBLIC AIL_channel_notes
                PUBLIC AIL_send_channel_voice_message
                PUBLIC AIL_send_sysex_message
                PUBLIC AIL_write_display
                PUBLIC AIL_install_callback
                PUBLIC AIL_cancel_callback

                PUBLIC AIL_lock_channel
                PUBLIC AIL_map_sequence_channel
                PUBLIC AIL_true_sequence_channel
                PUBLIC AIL_release_channel

                ;
                ;Digital performance services
                ;

                PUBLIC AIL_index_VOC_block
                PUBLIC AIL_register_sound_buffer
                PUBLIC AIL_sound_buffer_status
                PUBLIC AIL_play_VOC_file
                PUBLIC AIL_VOC_playback_status
                PUBLIC AIL_start_digital_playback
                PUBLIC AIL_stop_digital_playback
                PUBLIC AIL_pause_digital_playback
                PUBLIC AIL_resume_digital_playback
                PUBLIC AIL_set_digital_playback_volume
                PUBLIC AIL_digital_playback_volume
                PUBLIC AIL_set_digital_playback_panpot
                PUBLIC AIL_digital_playback_panpot

                ;
                ;Local data, in the code segment.  Timer tables have 17 slots: 0..15 for AIL_register_timer's
                ;callers and BIOS_H for the displaced BIOS handler.  Driver tables have one slot per handle 0..15.
                ;

BIOS_H          equ 16                  ;Handle to BIOS default timer

active_timers   dw ?                    ;callers' timers registered (BIOS_H not counted)
timer_busy      dw 0                    ;nonzero while API_timer dispatches callbacks

timer_callback  dd 17 dup (?)           ;Callback function addrs for timers
callback_ds     dw 17 dup (?)           ;DS loaded for each callback: its registrant's DS
timer_status    dw 17 dup (?)           ;Status of timers (0=free 1=off 2=on)
timer_elapsed   dd 17 dup (?)           ;microseconds accumulated toward the timer's period
timer_value     dd 17 dup (?)           ;the timer's period in microseconds
timer_period    dd ?                    ;microseconds per interrupt: the shortest timer_value

bios_callback   dd ?                    ;the INT 8 vector hook_timer_process displaced
current_timer   dw ?                    ;API_timer's slot index; -1 restarts its scan at slot 0
temp_period     dd ?                    ;program_timers' running minimum of timer_value
PIT_divisor     dw ?                    ;count last written to PIT channel 0 (0 = 65536)

index_base      dd 16 dup (?)           ;far ptr to each driver's procedure table; 0 = free handle
assigned_timer  dw 16 dup (?)           ;timer serving each driver; -1 = none
driver_active   dw 16 dup (?)           ;1 once AIL_init_driver has initialized the driver

drvproc         dd ?                    ;unused
cur_drvr        dw ?                    ;driver handle being scanned or registered
rtn_off         dw ?                    ;unused
rtn_seg         dw ?                    ;unused
timer_handle    dw ?                    ;AIL_init_driver: the driver's service timer; -1 = none

drvr_desc       STRUC                   ;a driver's description, AIL_describe_driver's result
min_API_version dw ?                    ;lowest current_rev the driver accepts
drvr_type       dw ?                    ;kind of driver (Xmidi accepts only 3)
data_suffix     db 4 dup (?)            ;extension of its timbre data files, NUL-terminated
dev_names       dd ?                    ;far ptr to its supported device names
def_IO          dw ?                    ;default I/O port, IRQ, DMA channel and DRQ
def_IRQ         dw ?
def_DMA         dw ?
def_DRQ         dw ?
svc_rate        dw ?                    ;timer service rate in Hz; -1 = no service wanted
dsp_size        dw ?                    ;characters of the device's text display; 0 = none
                ENDS

                ALIGN 2
stack_check     db 'Test'               ;overflow guard below the interrupt stack
                dw 256 dup (?)          ;512-byte interrupt stack for API_timer
intstack        LABEL WORD              ;its top: API_timer's initial SP

old_ss          dw ?                    ;the stack API_timer interrupted
old_sp          dw ?

current_rev     dw 200                  ;API revision, checked against min_API_version

;*****************************************************************************
;*                                                                           *
;* RTC CMOS access                                                           *
;*                                                                           *
;*****************************************************************************
                ;Assembled only when USE_INT8 is FALSE.  Note: RTC_install's "jne __busy" has no __busy of its
                ;own to reach.

                IF NOT USE_INT8

PIC0_DATA       equ 020h                ;8259 interrupt controllers: master, slave
PIC0_CTRL       equ 021h
PIC1_DATA       equ 0a0h
PIC1_CTRL       equ 0a1h
EOI             equ 020h
ALARMINT        equ 04Ah                ;BIOS RTC alarm vector
RTCINT          equ 070h                ;RTC periodic interrupt vector (IRQ 8)
CMOS_CONTROL    equ 070h                ;CMOS register select port
CMOS_DATA       equ 071h                ;CMOS data port
SRA             equ 00ah                ;RTC status registers A..D
SRB             equ 00bh
SRC             equ 00ch
SRD             equ 00dh

UIP             equ 080h                ;register A: update in progress

SET             equ 080h                ;register B bits
PIE             equ 040h
AIE             equ 020h
UIE             equ 010h
SQWE            equ 008h
DM              equ 004h
AMPM            equ 002h
DSE             equ 001h

IRQF            equ 080h                ;register C bits
PF              equ 040h
AF              equ 020h
UF              equ 010h

VRT             equ 080h                ;register D: valid RAM and time

RTC_old_int     dd ?                    ;INT 70h vector RTC_install displaced
RTC_active      dw 0                    ;1 while API_timer holds INT 70h

IO_WAIT         MACRO                   ;delay between CMOS port accesses
                jmp $+2
                jmp $+2
                jmp $+2
                ENDM

;*****************************************************************************
read_CMOS       PROC Addr:BYTE          ;AL = CMOS register Addr
                pushf                   ;no interrupt between select and read
                cli

                mov al,[Addr]           ;select the register
                out CMOS_CONTROL,al

                IO_WAIT

                in al,CMOS_DATA         ;read it

                POP_F
                ret
                ENDP

;*****************************************************************************
write_CMOS      PROC Addr:BYTE,Val:BYTE ;CMOS register Addr = Val
                pushf                   ;no interrupt between select and write
                cli

                mov al,[Addr]           ;select the register
                out CMOS_CONTROL,al

                IO_WAIT

                mov al,[Val]            ;write it
                out CMOS_DATA,al

                POP_F
                ret
                ENDP

;*****************************************************************************
RTC_set_freq    PROC Freq:WORD          ;set register A's rate bits unless PIE is on;
                USES ds,si,di           ;AX = 1 if it was on, else 0

                call read_CMOS,SRB
                and al,PIE
                jz __not_set            ;periodic interrupt off: free to set the rate

                mov ax,1                ;in use: leave the rate alone
                jmp __out

__not_set:      call read_CMOS,SRA      ;keep register A's upper nibble...
                and al,0f0h
                mov bx,[Freq]           ;...and put the rate select below it
                and bx,0fh
                or bl,al
                call write_CMOS,SRA,bx

                mov ax,0
__out:          ret
                ENDP

;*****************************************************************************
RTC_enable      PROC                    ;turn on the RTC periodic interrupt
                USES ds,si,di

                call read_CMOS,SRB
                and al,(NOT (PIE AND (UF OR AF)))       ;PIE AND (UF OR AF) is 0: no-op
                or al,(PIE AND PF)                      ;set PIE
                call write_CMOS,SRB,ax

                ret
                ENDP

;*****************************************************************************
RTC_disable     PROC                    ;turn off the RTC periodic interrupt (clear PIE)
                USES ds,si,di

                call read_CMOS,SRB
                and al,(NOT (PIE AND (UF OR PF OR AF))) ;clear PIE
                call write_CMOS,SRB,ax

                ret
                ENDP

;*****************************************************************************
RTC_install     PROC                    ;hook INT 70h and unmask IRQ 8
                USES ds,si,di

                pushf                   ;no interrupt while the vector changes
                cli

                cmp RTC_active,0
                jne __busy              ;already installed

                mov ax,0                ;keep the old INT 70h vector
                mov es,ax
                les ax,es:[RTCINT*4]
                mov WORD PTR RTC_old_int+2,es
                mov WORD PTR RTC_old_int,ax

                mov ax,0                ;INT 70h = CS:API_timer
                mov es,ax
                lea ax,API_timer
                mov es:[(RTCINT*4)],ax
                mov es:[(RTCINT*4)+2],cs

                call read_CMOS,SRC      ;reading register C clears a pending interrupt

                in al,PIC1_CTRL         ;unmask IRQ 8 at the slave controller
                and al,11111110b
                out PIC1_CTRL,al

                mov RTC_active,1

__exit:         POP_F
                ret
                ENDP

;*****************************************************************************
RTC_uninstall   PROC                    ;mask IRQ 8 and restore INT 70h
                USES ds,si,di

                pushf                   ;no interrupt while the vector changes
                cli

                cmp RTC_active,0
                je __exit               ;not installed

                in al,PIC1_CTRL         ;mask IRQ 8 at the slave controller
                or al,00000001b
                out PIC1_CTRL,al

                mov ax,0                ;put the old INT 70h vector back
                mov ds,ax
                les ax,RTC_old_int
                mov ds:[(RTCINT*4)],ax
                mov ds:[(RTCINT*4)+2],es

                mov RTC_active,0

__exit:         POP_F
                ret
                ENDP

                ENDIF

;*****************************************************************************
;*                                                                           *
;* Internal procedures                                                       *
;*                                                                           *
;*****************************************************************************

find_proc       PROC                    ;DX:AX = entry of function AX in driver BX,
                                        ;or 0:0 (reentrant: writes no storage)
                cmp bx,16
                jae __bad_handle        ;handle out of range: 0:0
                shl bx,1                ;BX = handle * 4, a dword index
                shl bx,1
                les bx,index_base[bx]   ;ES:BX -> driver procedure table
                mov cx,es
                or cx,bx
                jz __bad_handle         ;null: no driver in this slot

__find_proc:    mov cx,es:[bx]          ;CX = this entry's function number
                cmp cx,ax
                je __found              ;the one asked for
                add bx,4                ;step past its (number, offset) pair
                cmp cx,-1
                jne __find_proc         ;until the -1 terminator

                mov ax,0                ;return 0: function not available
                mov dx,0
                ret

__bad_handle:   mov ax,0                ;return 0: invalid driver handle
                mov dx,0
                ret

__found:        mov ax,es:[bx+2]        ;AX = entry offset within the driver
                mov dx,es               ;DX = driver segment (its image is ORG 0)
                ret

                ENDP

;*****************************************************************************
call_driver     PROC                    ;enter driver function AX with the frame
                                        ;our caller received (reentrant)
                mov bx,sp               ;BX = first argument, the driver handle,
                mov bx,ss:[bx+4]        ;above our caller's far return address

                call find_proc          ;DX:AX = the function's entry

                cmp ax,0
                jne __do_call
                cmp dx,0
                je __invalid_call       ;0:0: no such driver or function

__do_call:      push dx                 ;RETF into the entry: the driver sees the
                push ax                 ;same frame and returns to its caller
                retf

__invalid_call: ret                     ;return DX:AX = 0 if call failed

                ENDP

;*****************************************************************************
API_timer       PROC                    ;INT 8 handler: runs each timer that is due

                cmp timer_busy,0
                jne __busy              ;a tick during a dispatch is only acknowledged
                mov timer_busy,1

                cld                     ;callbacks run with DF clear
                push ax                 ;keep the interrupted context
                push bx
                push cx
                push dx
                push si
                push di
                push bp
                push es
                push ds

                IF NOT USE_INT8
                call read_CMOS C,SRC    ;RTC: reading register C acknowledges it
                sti
                ENDIF

                mov old_ss,ss           ;keep the interrupted stack
                mov old_sp,sp

                mov ax,cs               ;run on the private stack below intstack,
                mov ss,ax               ;whatever the interrupted program's stack
                lea sp,intstack

                mov current_timer,0
__for_timer:    mov si,current_timer    ;for timer = 0 to 16
                shl si,1                ;SI = word index
                cmp timer_status[si],2  ;is timer "running"?
                jne __next_timer        ;no, go on to the next one
                mov ds,callback_ds[si]  ;else load callback's data segment...
                shl si,1                ;SI = dword index

                mov ax,WORD PTR timer_elapsed[si]       ;DX:AX = elapsed + this
                mov dx,WORD PTR timer_elapsed[si]+2     ;interrupt's period

                add ax,WORD PTR timer_period
                adc dx,WORD PTR timer_period+2

                cmp dx,WORD PTR timer_value[si]+2       ;reached the timer's own
                jb __dec_timer                          ;period yet?
                ja __timer_tick
                cmp ax,WORD PTR timer_value[si]
                jae __timer_tick

__dec_timer:    mov WORD PTR timer_elapsed[si],ax       ;no: keep the sum
                mov WORD PTR timer_elapsed[si]+2,dx
                jmp __next_timer

__timer_tick:   sub ax,WORD PTR timer_value[si]         ;yes: keep the remainder,
                sbb dx,WORD PTR timer_value[si]+2       ;so no time is lost

                mov WORD PTR timer_elapsed[si],ax
                mov WORD PTR timer_elapsed[si]+2,dx

                call timer_callback[si] ;DDA timer expired, call timer proc

__next_timer:   inc current_timer       ;next slot; a callback that sets -1 (via
                cmp current_timer,16    ;program_timers) restarts the scan at 0
                jbe __for_timer

                mov ss,old_ss           ;back to the interrupted stack
                mov sp,old_sp

__exit:         pop ds                  ;restore the interrupted context
                pop es
                pop bp
                pop di
                pop si
                pop dx
                pop cx
                pop bx
                pop ax

                mov timer_busy,0

__busy:
                push ax
                mov al,20h              ;non-specific EOI to the 8259
                IF NOT USE_INT8
                out 0a0h,al             ;(RTC: the slave controller too)
                ENDIF
                out 20h,al              ;master controller command port

                pop ax

                cmp WORD PTR stack_check,'eT'           ;guard intact?
                jne __stack_fault
                cmp WORD PTR stack_check+2,'ts'
                jne __stack_fault

                iret

__stack_fault:  sti                     ;the interrupt stack overflowed: stop here
                int 3                   ;at a breakpoint, forever
                jmp __stack_fault

                ENDP

;*****************************************************************************
init_DDA_arrays PROC                    ;Initialize timer DDA counters
                USES ds,si,di

                pushf                   ;no tick while the tables change
                cli

                cld
                mov WORD PTR timer_period,-1    ;no base period yet
                mov WORD PTR timer_period+2,-1

                push cs                 ;ES:DI -> our tables
                pop es
                mov di,OFFSET timer_status
                mov cx,17
                mov ax,0
                rep stosw               ;mark all timer handles "free"

                mov di,OFFSET timer_elapsed     ;elapsed and periods = 0
                mov cx,17*2
                rep stosw

                mov di,OFFSET timer_value
                mov cx,17*2
                rep stosw

                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
bios_caller     PROC                    ;BIOS_H's callback: run the displaced
                                        ;INT 8 handler, which keeps the BIOS clock
                IF USE_INT8
                pushf                   ;flags for its IRET, as an INT would
                call DWORD PTR bios_callback
                ENDIF

                ret
                ENDP

;*****************************************************************************
hook_timer_process PROC                 ;Take over default BIOS INT 8 handler
                USES ds,si,di

                pushf                   ;no tick while the vector changes
                cli

                mov ax,3508h            ;DOS get vector 08h: ES:BX = the BIOS
                int 21h                 ;handler

                mov WORD PTR bios_callback,bx
                mov WORD PTR bios_callback+2,es

                mov bx,OFFSET bios_caller               ;slot BIOS_H calls it,
                mov WORD PTR timer_callback[BIOS_H*4],bx ;registered but stopped
                mov WORD PTR timer_callback[BIOS_H*4]+2,cs
                mov timer_status[BIOS_H*2],1

                IF USE_INT8

                mov ax,cs               ;DS:DX = API_timer
                mov ds,ax
                mov dx,OFFSET API_timer

                mov ax,2508h            ;DOS set vector 08h
                int 21h

                ELSE

                call RTC_set_freq C,RTC_FREQ_BITS
                call RTC_enable
                call RTC_install

                ENDIF

                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
unhook_timer_process PROC               ;Restore default BIOS INT 8 handler
                USES ds,si,di

                pushf                   ;no tick while the vector changes
                cli

                mov current_timer,-1    ;restart a scan in progress

                IF USE_INT8

                mov dx,WORD PTR bios_callback           ;DS:DX = BIOS handler
                mov ds,WORD PTR bios_callback+2

                mov ax,2508h            ;DOS set vector 08h
                int 21h

                ELSE

                call RTC_uninstall
                call RTC_disable

                ENDIF

                POP_F                   ;interrupts as they were
                ret
                ENDP

                IF USE_INT8
;*****************************************************************************
set_PIT_divisor PROC Divisor            ;Set 8253 Programmable Interval Timer
                USES ds,si,di           ;to desired IRQ 0 (INT 8) interval

                pushf                   ;no interrupt between the two count bytes
                cli

                mov al,36h              ;channel 0, low then high byte, mode 3,
                out 43h,al              ;binary: to the PIT mode register
                mov ax,[Divisor]        ;PIT granularity = 1/1193181 sec.
                mov PIT_divisor,ax
                jmp $+2                 ;I/O delay
                out 40h,al              ;count low byte to channel 0
                mov al,ah
                jmp $+2                 ;I/O delay
                out 40h,al              ;count high byte

                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
set_PIT_period  PROC Period             ;Set 8253 Programmable Interval Timer
                USES ds,si,di           ;to desired period in microseconds

                mov ax,0                ;divisor 0 (65536): the BIOS's own rate,
                cmp [Period],54925      ;for periods of 54,925 uS and more
                jae __set_PIT

                mov ax,[Period]         ;divisor = Period * 10000 / 8381, a PIT
                mov bx,8381             ;count being .8381 uS; the division
                mov cx,10000            ;truncates, rounding the period down
                mul cx
                div bx

__set_PIT:      call set_PIT_divisor C,ax

                ret
                ENDP

                ENDIF

;*****************************************************************************
ul_divide       PROC Num:DWORD,Den:DWORD ;DX:AX = Num / Den, both unsigned 32-bit
                USES ds,si,di

                mov ax,WORD PTR [Num]   ;DX:AX = numerator
                mov dx,WORD PTR [Num]+2
                mov bx,WORD PTR [Den]   ;CX:BX = denominator
                mov cx,WORD PTR [Den]+2

                or cx,cx
                jne __long_div          ;denominator over 16 bits
                or dx,dx
                je __short_div          ;16-bit numerator: one DIV does it
                or bx,bx
                je __short_div          ;Den = 0 takes DIV too, and faults

__long_div:     mov bp,cx               ;BP:BX = denominator (BP is free: no
                mov cx,20h              ;locals, and RET restores it); 32 bits
                xor di,di               ;DI:SI = remainder = 0
                xor si,si

__div_loop:     shl ax,1                ;shift the next numerator bit into the
                rcl dx,1                ;remainder; DX:AX collects the quotient
                rcl si,1
                rcl di,1
                cmp di,bp               ;remainder >= denominator?
                jb __cont_loop
                ja __bump_quot
                cmp si,bx
                jb __cont_loop
__bump_quot:    sub si,bx               ;yes: subtract it, quotient bit = 1
                sbb di,bp
                inc ax
__cont_loop:    loop __div_loop         ;32 bits
                jmp __end_div

__short_div:    div bx                  ;AX = quotient
                xor dx,dx

__end_div:      ret

                ENDP

;*****************************************************************************
program_timers  PROC                    ;Establish timer interrupt rates
                USES ds,si,di           ;based on fastest active timer

                pushf
                cli                     ;non-reentrant, don't interrupt

                cld
                mov WORD PTR temp_period,-1     ;minimum so far: none
                mov WORD PTR temp_period+2,-1

                mov si,0
__for_timer:    mov bx,si               ;find fastest active timer....
                shl bx,1
                cmp timer_status[bx],0  ;timer active (registered)?
                je __next_timer         ;no, skip it
                shl bx,1                ;DX:AX = its period
                mov ax,WORD PTR timer_value[bx]
                mov dx,WORD PTR timer_value[bx]+2

                cmp dx,WORD PTR temp_period+2   ;shorter than the minimum?
                jb __set_temp
                ja __next_timer
                cmp ax,WORD PTR temp_period
                jae __next_timer

__set_temp:     mov WORD PTR temp_period,ax     ;yes: new minimum
                mov WORD PTR temp_period+2,dx

__next_timer:   inc si
                cmp si,16               ;(include BIOS reserved timer)
                jbe __for_timer

                mov ax,WORD PTR temp_period     ;DX:AX = the minimum
                mov dx,WORD PTR temp_period+2

                cmp ax,WORD PTR timer_period
                jne __must_reset
                cmp dx,WORD PTR timer_period+2
                je __no_change          ;current rate hasn't changed, exit

__must_reset:   mov current_timer,-1    ;restart a scan in progress
                                        ;(slowest possible base = 54 msec!)
                mov WORD PTR timer_period,ax
                mov WORD PTR timer_period+2,dx

                IF USE_INT8
                call set_PIT_period C,ax ;low word only: BIOS_H's 54,925 uS
                ENDIF                    ;bounds the minimum

                push cs                 ;ES:DI -> timer_elapsed
                pop es
                mov di,OFFSET timer_elapsed
                mov cx,17*2
                mov ax,0                ;reset ALL elapsed counters to 0 uS
                rep stosw

__no_change:
                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
;*                                                                           *
;* Process services                                                          *
;*                                                                           *
;*****************************************************************************

AIL_startup     PROC                    ;Initialize AIL API
                USES ds,si,di

                pushf                   ;no tick while the tables change
                cli

                mov active_timers,0     ;# of registered timers
                mov timer_busy,0        ;timer re-entrancy protection
                IF DIGPAK
                mov DP_registered,0
                ENDIF

                cld
                mov ax,cs               ;ES:DI -> our tables
                mov es,ax
                lea di,index_base       ;every driver handle free
                mov cx,16*2
                mov ax,0
                rep stosw
                lea di,assigned_timer   ;no driver has a timer
                mov cx,16
                mov ax,-1
                rep stosw
                lea di,driver_active    ;none initialized
                mov cx,16
                mov ax,0
                rep stosw

                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_shutdown    PROC SignOff:FAR PTR    ;Quick shutdown of all AIL resources;
                USES ds,si,di           ;SignOff goes to each driver's shutdown

                pushf                   ;no tick during the shutdown
                cli

                mov cur_drvr,0
__for_slot:     mov si,cur_drvr         ;for each driver handle
                shl si,1                ;SI = word index
                mov dx,assigned_timer[si]
                shl si,1                ;SI = dword index
                mov ax,WORD PTR index_base[si]
                or ax,WORD PTR index_base[si+2]
                jz __next_slot          ;no driver installed, skip slot

                cmp dx,-1
                je __shut_down          ;no timer assigned, continue
                call AIL_release_timer_handle C,dx

__shut_down:    call AIL_shutdown_driver C,cur_drvr,[SignOff]

__next_slot:    inc cur_drvr
                cmp cur_drvr,16
                jne __for_slot

                call AIL_release_all_timers     ;and every caller's timer

                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_register_timer PROC Callback:FAR PTR ;AX = new timer handle 0..15, stopped,
                USES ds,si,di            ;that far calls Callback; -1 if none free

                pushf                   ;no tick while the tables change
                cli

                mov cx,ds               ;save application module's DS segment

                mov bx,0                ;look for a free timer handle....
__find_free:    cmp timer_status[bx],0
                je __found              ;found one
                add bx,2
                cmp bx,32               ;slots 0..15 only; BIOS_H is ours
                jb __find_free
                mov ax,-1
                jmp __return            ;no free timers, return -1

__found:        mov ax,bx               ;yes, set up to return handle
                shr ax,1
                mov timer_status[bx],1  ;turn the new timer "off" (stopped)
                mov callback_ds[bx],cx  ;register timer proc's DS segment
                shl bx,1                ;BX = dword index
                lds si,[Callback]       ;register the timer proc
                mov WORD PTR timer_callback[bx],si
                mov WORD PTR timer_callback+2[bx],ds
                inc active_timers
                cmp active_timers,1     ;is this the first timer registered?
                jne __return            ;no, just return

                push ax                 ;yes, set up our own interrupt handler

                call init_DDA_arrays    ;init timer countdown values
                call hook_timer_process ;seize interrupt and register BIOS handler

                IF USE_INT8
                call AIL_set_timer_period C,BIOS_H,54925 ;BIOS clock at its own
                call AIL_start_timer C,BIOS_H            ;18.2 Hz
                ELSE
                call AIL_set_timer_frequency C,BIOS_H,RTC_FREQ,0
                ENDIF

                pop ax

                mov bx,ax
                shl bx,1
                mov timer_status[bx],1  ;(cleared by init_DDA_arrays)

__return:
                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_release_timer_handle PROC Timer     ;free timer Timer; the last one frees
                USES ds,si,di           ;INT 8 and the PIT

                pushf                   ;no tick while the tables change
                cli

                mov bx,[Timer]          ;BX = word index
                shl bx,1
                cmp timer_status[bx],0  ;is the specified timer active?
                je __return             ;no, exit

                mov timer_status[bx],0  ;release the timer's handle

                dec active_timers       ;any active timers left?
                jnz __return            ;if not, put the default handler back

                IF USE_INT8
                call set_PIT_divisor C,0 ;PIT back to 65536, the BIOS rate
                ENDIF

                call unhook_timer_process
__return:
                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_release_all_timers PROC             ;free every caller's timer, 15..0
                USES ds,si,di

                pushf                   ;no tick until all are released
                cli

                mov si,15               ;free all external timer handles
__release_it:   call AIL_release_timer_handle C,si
                dec si
                jge __release_it

                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_start_timer PROC Timer              ;run timer Timer if it is stopped
                USES ds,si,di

                pushf                   ;no tick during the update
                cli

                mov bx,[Timer]          ;BX = word index
                shl bx,1
                cmp timer_status[bx],1  ;is the specified timer stopped?
                jne __return
                mov timer_status[bx],2  ;yes, start it
__return:
                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_start_all_timers PROC               ;start every caller's timer, 15..0
                USES ds,si,di

                pushf                   ;no tick until all are started
                cli

                mov si,15               ;start all stopped timers
__start_it:     call AIL_start_timer C,si
                dec si
                jge __start_it

                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_stop_timer  PROC Timer              ;stop timer Timer if it is running
                USES ds,si,di

                pushf                   ;no tick during the update
                cli

                mov bx,[Timer]          ;BX = word index
                shl bx,1
                cmp timer_status[bx],2  ;is the specified timer running?
                jne __return
                mov timer_status[bx],1  ;yes, stop it
__return:
                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_stop_all_timers PROC                ;stop every caller's timer, 15..0
                USES ds,si,di

                pushf                   ;no tick until all are stopped
                cli

                mov si,15               ;stop all running timers
__stop_it:      call AIL_stop_timer C,si
                dec si
                jge __stop_it

                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_set_timer_period PROC Timer,uS:DWORD
                USES ds,si,di           ;accepts timer period in microseconds

                pushf                   ;no tick while the tables change
                cli

                mov bx,[Timer]          ;BX = word index
                shl bx,1
                mov ax,timer_status[bx] ;save timer's status
                push ax
                mov timer_status[bx],1  ;stop timer while calculating...

                shl bx,1                ;BX = dword index
                mov ax,WORD PTR [uS]    ;its period = uS
                mov dx,WORD PTR [uS]+2
                mov WORD PTR timer_value[bx],ax
                mov WORD PTR timer_value[bx]+2,dx

                mov WORD PTR timer_elapsed[bx],0        ;counted from now
                mov WORD PTR timer_elapsed[bx]+2,0

                call program_timers     ;reset base interrupt rate if needed

                pop ax
                mov bx,[Timer]
                shl bx,1
                mov timer_status[bx],ax ;restore timer's former status

                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_set_timer_frequency PROC Timer,Hz:DWORD
                USES ds,si,di           ;accepts timer frequency in Hertz

                pushf                   ;no tick during the update
                cli

                call ul_divide C,4240h,000fh,[Hz]       ;period = 1,000,000 / Hz
                call AIL_set_timer_period C,[Timer],ax,dx

                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_set_timer_divisor PROC Timer,PIT
                USES ds,si,di           ;accepts PIT register values directly

                pushf                   ;no tick during the update
                cli

                cmp [PIT],0             ;special case: 0 wraps to 65536
                jne __nonzero
                mov ax,54925            ;65536 counts = 54,925 uS
                mov dx,0
                jmp __set_AXDX

__nonzero:      mov ax,10000            ;period = PIT * 10000 / 11932, 1.1932
                mov bx,11932            ;counts being a microsecond
                mul [PIT]
                div bx
                mov dx,0                ;DX:AX = period, under 65536 uS

__set_AXDX:     call AIL_set_timer_period C,[Timer],ax,dx

                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_interrupt_divisor PROC Dummy        ;Get value last used by the API to
                USES ds,si,di           ;program the PIT chip (Dummy unused)

                pushf                   ;read it with no tick in between
                cli

                mov ax,PIT_divisor

                POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
;*                                                                           *
;* Installation services                                                     *
;*                                                                           *
;*****************************************************************************

AIL_register_driver PROC Addr:FAR PTR   ;AX = handle for the driver image at Addr,
                USES ds,si,di           ;or -1

                pushf                   ;no tick while the tables change
                cli

                mov cur_drvr,0
__find_handle:  mov si,cur_drvr         ;find a free handle
                shl si,1                ;SI = dword index
                shl si,1
                mov ax,WORD PTR index_base[si]
                or ax,WORD PTR index_base[si+2]
                je __found
                inc cur_drvr
                cmp cur_drvr,16
                jne __find_handle
                mov ax,-1               ;return -1 if no free handles
                jmp __return

__found:        les di,[Addr]           ;get driver base address

                IF DIGPAK
                cmp es:[di+3],'ID'
                jne __check_ADV         ;check for 'DIGPAK' ID string
                cmp es:[di+5],'PG'
                jne __check_ADV
                cmp es:[di+7],'KA'
                je __register_DP        ;if it's a DIGPAK driver, register the
                ENDIF                   ;Integrated Driver Interface instead

__check_ADV:    mov ax,-1               ;else check for copyright string to
                cmp es:[di+2],'oC'      ;avoid calling non-AIL drivers: "Copy"
                jne __return            ;at image bytes 2..5
                cmp es:[di+4],'yp'
                jne __return

                add di,es:[di]          ;the image's first word skips the copyright
                mov WORD PTR index_base[si],di  ;text to the procedure table,
                mov WORD PTR index_base[si+2],es ;which claims the handle

                call AIL_describe_driver C,cur_drvr

                mov es,dx               ;check API version compatibility
                mov di,ax
                or dx,ax
                mov ax,-1
                je __return             ;return -1 if description call failed

                mov dx,es:[di].min_API_version
                cmp dx,current_rev
                ja __return             ;return -1 if API out of date
                                        ;(either -1 leaves the handle claimed)

__valid_handle: mov ax,cur_drvr         ;else return AX=new driver handle

__return:       POP_F                   ;interrupts as they were
                ret

                IF DIGPAK
__register_DP:  mov ax,-1               ;Register a DIGPAK driver from The
                cmp DP_registered,0     ;Audio Solution, Inc.
                jne __return
                mov DP_registered,1     ;(multiple DP drivers not supported)

                mov ax,cur_drvr
                mov DP_handle,ax

                mov ax,es
                sub ax,10h              ;get entry point for .COM driver
                add di,100h             ;(ES:0 -> AX-10H:100h)

                mov WORD PTR DP_base+2,ax
                mov WORD PTR DP_base,di

                mov WORD PTR index_base[si],OFFSET DP_IDI_index ;handle -> the
                mov WORD PTR index_base[si+2],cs                ;simulated table

                mov DP_installed,0      ;flag driver not yet installed
                jmp __valid_handle      ;return valid handle to DIGPAK IDI
                ENDIF

                ENDP

;*****************************************************************************
AIL_release_driver_handle PROC H        ;free driver handle H (the driver is
                USES ds,si,di           ;not shut down)

                pushf                   ;no tick while the tables change
                cli

                mov bx,[H]
                cmp bx,16
                jae __exit              ;exit cleanly if invalid handle passed
                shl bx,1                ;BX = dword index
                shl bx,1
                mov WORD PTR index_base[bx],0   ;null table pointer: free
                mov WORD PTR index_base[bx+2],0

                IF DIGPAK
                cmp DP_registered,0     ;Release DIGPAK driver handle
                je __exit
                mov ax,[H]
                cmp ax,DP_handle
                jne __exit
                mov DP_registered,0
                ENDIF

__exit:         POP_F                   ;interrupts as they were
                ret
                ENDP

;*****************************************************************************
AIL_describe_driver PROC HDrvr          ;DX:AX -> driver HDrvr's drvr_desc, or 0:0

                push SEG AIL_interrupt_divisor          ;driver function 100's
                push OFFSET AIL_interrupt_divisor       ;arguments: HDrvr and the
                push [HDrvr]                            ;far address of
                mov ax,AIL_DESC_DRVR                    ;AIL_interrupt_divisor
                call call_driver
                add sp,6                ;drop the three argument words
                ret
                ENDP

;*****************************************************************************
AIL_detect_device PROC                  ;(H,IO,IRQ,DMA,DRQ): AX nonzero if found

                mov ax,AIL_DET_DEV      ;the driver takes the caller's frame
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_init_driver PROC HDrvr,IO,IRQ,DMA,DRQ
                USES ds,si,di

                pushf                   ;no tick during the installation
                cli

                cmp [HDrvr],16
                jae __return            ;exit cleanly if invalid handle passed

                mov timer_handle,-1     ;no service timer yet

                call AIL_describe_driver C,[HDrvr]

                mov es,dx               ;ES:DI -> its description
                mov di,ax
                mov si,es:[di].svc_rate ;get desired service rate
                cmp si,-1
                je __do_init            ;(no timer service requested)

                mov ax,AIL_SERVE_DRVR   ;find the driver's service routine
                mov bx,[HDrvr]
                call find_proc

                mov es,dx
                mov bx,ax               ;ES:BX = the driver's service routine

                call AIL_register_timer C,bx,es ;a timer that calls it,
                mov bx,[HDrvr]                  ;assigned to this driver
                shl bx,1
                mov assigned_timer[bx],ax
                mov timer_handle,ax

                call AIL_set_timer_frequency C,ax,si,0  ;at svc_rate Hz

__do_init:      push DRQ                ;driver function 102 with this frame's
                push DMA                ;arguments, pushed again
                push IRQ
                push IO
                push HDrvr
                mov ax,AIL_INIT_DRVR
                call call_driver
                add sp,10               ;drop the five argument words

                mov bx,[HDrvr]          ;mark the driver initialized
                shl bx,1
                mov driver_active[bx],1

                cmp timer_handle,-1
                je __return
                call AIL_start_timer C,timer_handle     ;start its service

__return:       POP_F                   ;interrupts as they were
                ret

                ENDP

;*****************************************************************************
AIL_shutdown_driver PROC                ;(H,SignOff): shut an initialized driver
                                        ;down and free its timer
                mov bx,sp               ;BX = H, above the far return address
                mov bx,ss:[bx+4]        ;get handle
                cmp bx,16
                jae __exit              ;exit cleanly if invalid handle passed

                shl bx,1                ;BX = word index
                mov dx,0
                xchg driver_active[bx],dx       ;DX = was it active; now it is not
                cmp dx,0
                je __exit               ;driver never initialized, exit
                mov dx,assigned_timer[bx]
                cmp dx,-1
                je __shut_down          ;no timer assigned, continue
                call AIL_release_timer_handle C,dx

__shut_down:    mov ax,AIL_SHUTDOWN_DRVR        ;the driver takes the caller's
                jmp call_driver                 ;frame

__exit:         ret
                ENDP

;*****************************************************************************
;*                                                                           *
;* Performance services                                                      *
;*                                                                           *
;*****************************************************************************
                ;Each service below loads its driver function number (the equates above) and
                ;jumps to call_driver, so the driver receives the caller's own
                ;arguments, driver handle first, and returns straight to the caller.

AIL_index_VOC_block PROC

                mov ax,AIL_INDEX_VOC_BLK        ;driver function 120
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_register_sound_buffer PROC

                mov ax,AIL_REG_SND_BUFF         ;driver function 121
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_sound_buffer_status PROC

                mov ax,AIL_SND_BUFF_STAT        ;driver function 122
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_play_VOC_file  PROC

                mov ax,AIL_P_VOC_FILE           ;driver function 123
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_VOC_playback_status PROC

                mov ax,AIL_VOC_PB_STAT          ;driver function 124
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_start_digital_playback PROC

                mov ax,AIL_START_D_PB           ;driver function 125
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_stop_digital_playback PROC

                mov ax,AIL_STOP_D_PB            ;driver function 126
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_pause_digital_playback PROC

                mov ax,AIL_PAUSE_D_PB           ;driver function 127
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_resume_digital_playback PROC

                mov ax,AIL_RESUME_D_PB          ;driver function 128
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_set_digital_playback_volume PROC

                mov ax,AIL_SET_D_PB_VOL         ;driver function 129
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_digital_playback_volume PROC

                mov ax,AIL_D_PB_VOL             ;driver function 130
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_set_digital_playback_panpot PROC

                mov ax,AIL_SET_D_PB_PAN         ;driver function 131
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_digital_playback_panpot PROC

                mov ax,AIL_D_PB_PAN             ;driver function 132
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_state_table_size PROC

                mov ax,AIL_STATE_TAB_SIZE       ;driver function 150
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_register_sequence PROC

                mov ax,AIL_REG_SEQ              ;driver function 151
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_release_sequence_handle PROC

                mov ax,AIL_REL_SEQ_HND          ;driver function 152
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_default_timbre_cache_size PROC

                mov ax,AIL_T_CACHE_SIZE         ;driver function 153
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_define_timbre_cache PROC

                mov ax,AIL_DEFINE_T_CACHE       ;driver function 154
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_timbre_request PROC

                mov ax,AIL_T_REQ                ;driver function 155
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_install_timbre PROC

                mov ax,AIL_INSTALL_T            ;driver function 156
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_protect_timbre PROC

                mov ax,AIL_PROTECT_T            ;driver function 157
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_unprotect_timbre PROC

                mov ax,AIL_UNPROTECT_T          ;driver function 158
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_timbre_status  PROC

                mov ax,AIL_T_STATUS             ;driver function 159
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_start_sequence PROC

                mov ax,AIL_START_SEQ            ;driver function 170
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_stop_sequence  PROC

                mov ax,AIL_STOP_SEQ             ;driver function 171
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_resume_sequence PROC

                mov ax,AIL_RESUME_SEQ           ;driver function 173
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_sequence_status PROC

                mov ax,AIL_SEQ_STAT             ;driver function 174
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_relative_volume PROC

                mov ax,AIL_REL_VOL              ;driver function 175
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_relative_tempo PROC

                mov ax,AIL_REL_TEMPO            ;driver function 176
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_set_relative_volume PROC

                mov ax,AIL_SET_REL_VOL          ;driver function 177
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_set_relative_tempo PROC

                mov ax,AIL_SET_REL_TEMPO        ;driver function 178
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_beat_count     PROC

                mov ax,AIL_BEAT_CNT             ;driver function 179
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_measure_count  PROC

                mov ax,AIL_BAR_CNT              ;driver function 180
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_branch_index   PROC

                mov ax,AIL_BRA_INDEX            ;driver function 181
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_controller_value PROC

                mov ax,AIL_CON_VAL              ;driver function 182
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_set_controller_value PROC

                mov ax,AIL_SET_CON_VAL          ;driver function 183
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_channel_notes  PROC

                mov ax,AIL_CHAN_NOTES           ;driver function 185
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_send_channel_voice_message PROC

                mov ax,AIL_SEND_CV_MSG          ;driver function 186
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_send_sysex_message PROC

                mov ax,AIL_SEND_SYSEX_MSG       ;driver function 187
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_write_display  PROC

                mov ax,AIL_WRITE_DISP           ;driver function 188
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_install_callback PROC

                mov ax,AIL_INSTALL_CB           ;driver function 189
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_cancel_callback PROC

                mov ax,AIL_CANCEL_CB            ;driver function 190
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_lock_channel   PROC

                mov ax,AIL_LOCK_CHAN            ;driver function 191
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_map_sequence_channel PROC

                mov ax,AIL_MAP_SEQ_CHAN         ;driver function 192
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_release_channel PROC

                mov ax,AIL_RELEASE_CHAN         ;driver function 193
                jmp call_driver

                ENDP

;*****************************************************************************
AIL_true_sequence_channel PROC

                mov ax,AIL_TRUE_SEQ_CHAN        ;driver function 194
                jmp call_driver

                ENDP

;*****************************************************************************
;*                                                                           *
;* DIGPAK Integrated Driver Interface                                        *
;*                                                                           *
;* Simulated AIL driver shell allows access to The Audio Solution's DIGPAK   *
;* driver loaded as .COM file                                                *
;*                                                                           *
;*****************************************************************************
                ;Assembled only when DIGPAK is TRUE.  DIGPAK
                ;drivers are called through INT 66h, AX = 687h + function number.

                IF DIGPAK

DP_IDI_index:   dw AIL_DESC_DRVR,OFFSET DP_describe_driver      ;the simulated
                dw AIL_DET_DEV,OFFSET DP_detect_device          ;driver's procedure
                dw AIL_INIT_DRVR,OFFSET DP_init_driver          ;table: (function,
                dw AIL_SHUTDOWN_DRVR,OFFSET DP_shutdown_driver  ;entry) pairs that
                dw AIL_P_VOC_FILE,OFFSET DP_play_VOC_file       ;find_proc searches
                dw AIL_START_D_PB,OFFSET DP_start_d_pb
                dw AIL_STOP_D_PB,OFFSET DP_stop_d_pb
                dw AIL_VOC_PB_STAT,OFFSET DP_get_VOC_status
                dw AIL_INDEX_VOC_BLK,OFFSET DP_index_VOC_blk
                dw AIL_REG_SND_BUFF,OFFSET DP_register_sb
                dw AIL_SND_BUFF_STAT,OFFSET DP_get_sb_status
                dw AIL_F_VOC_FILE,OFFSET DP_format_VOC_file
                dw AIL_F_SND_BUFF,OFFSET DP_format_sb
                dw -1                                           ;terminator

BKGND_PLAY      equ 00000001b           ;Function 068CH attributes
MODIFIES_DATA   equ 00000010b
DOWNSAMPLES     equ 00000100b
USES_TICK       equ 00001000b
SHARES_TIMER    equ 00010000b

BLK_SIZE        equ 32768               ;max. block size for INT 66 calls

DP_DDT          LABEL WORD              ;Simulated AIL device description
                dw 210                  ;Minimum API version required = 2.10
                dw 2                    ;Type 2: Sound Blaster DSP emulation
                db 'VOC',0              ;Supports .VOC files directly
                dw OFFSET DP_name       ;Pointer to list of supported devices
DP_devname_s    dw ?                    ;(its segment, set to CS)
                dw -1                   ;TAS drivers responsible for handling
                dw -1                   ;I/O parms
                dw -1
                dw -1
DP_uses_INT8    dw ?                    ;0 if driver stops music; -1 if OK
                dw 0                    ;No display

DP_name         db 80 dup (?)           ;the driver's name, as a device name list

DP_call         LABEL DWORD             ;far entry DP_describe_driver and
call_off        dw ?                    ;DP_shutdown_driver call in the .COM
call_seg        dw ?

DP_handle       dw ?                    ;AIL handle of the DIGPAK driver
DP_registered   dw ?                    ;1 while one is registered
DP_installed    dw ?                    ;1 once its installation call has run
DP_base         dd ?                    ;its image start, as (seg-10h):100h
DP_attribs      dw ?                    ;its function 68Ch attributes

VOC_MODE        equ 0                   ;Creative Voice File playback mode
BUF_MODE        equ 1                   ;Dual-buffer DMA playback mode

sbuffer         STRUC                   ;AIL sound buffer structure
pack_type       dw ?
sample_rate     dw ?
data            dd ?
len_l           dw ?
len_h           dw ?
                ENDS

DP_sndstruc     STRUC                   ;DIGPAK sound sample structure
sndptr          dd ?
sndlen          dw ?
sndstat         dd ?
sndfreq         dw ?
                ENDS

DPS             DP_sndstruc <>          ;the chunk being played
DPT             DP_sndstruc <>          ;the block being preformatted

buff_data_o     dw 2 dup (?)            ;the two registered sound buffers:
buff_data_s     dw 2 dup (?)            ;data pointer, length, sample rate
buff_len_l      dw 2 dup (?)            ;and DAC_* state
buff_len_h      dw 2 dup (?)
buff_sample     dw 2 dup (?)
buff_status     dw 2 dup (?)

buffer_mode     dw ?                    ;VOC_MODE or BUF_MODE
DAC_status      dw ?                    ;playback state, DAC_*
current_buffer  dw ?                    ;word index of the buffer playing
block_ptr       dd ?                    ;current .VOC block
loop_ptr        dd ?                    ;block after the repeat-loop start
loop_cnt        dw ?                    ;repeats left; 0FFFFh = endless
DMA_ptr         dd ?                    ;data not yet sent, and its length
DMA_len_l       dw ?
DMA_len_h       dw ?
packing         dw ?                    ;unused
playing_flag    dw ?                    ;DIGPAK's status word for each sample

DP_timer        dw ?                    ;dummy timer that keeps AIL's hook
AIL_hooked      dw ?                    ;1 while AIL holds INT 8

;****************************************************************************
;*                                                                          *
;*  DP IDI internal procedures                                              *
;*                                                                          *
;****************************************************************************

AIL_unhook      PROC                    ;give INT 8 to a DIGPAK driver that
                USES ds,si,di           ;uses the timer tick

                IF USE_INT8

                test DP_attribs,USES_TICK
                jz __exit               ;it doesn't: keep INT 8

                cmp active_timers,0
                je __exit               ;AIL has no timers: nothing to give up

                cmp AIL_hooked,0
                je __exit               ;already given up

                IF DIGPAK_SHARE
                test DP_attribs,SHARES_TIMER
                jnz __share
                ENDIF

                call unhook_timer_process

                mov AIL_hooked,0
                jmp __exit

__share:        mov ax,693h             ;function #12: share timer
                mov dx,PIT_divisor      ;(reached only when DIGPAK_SHARE)
                int 66h

                ENDIF

__exit:         ret
                ENDP

;****************************************************************************
AIL_hook        PROC                    ;take INT 8 back after DIGPAK output
                USES ds,si,di

                IF USE_INT8

                test DP_attribs,USES_TICK
                jz __exit               ;the driver never took it

                IF DIGPAK_SHARE
                test DP_attribs,SHARES_TIMER
                jnz __exit
                ENDIF

                cmp active_timers,0
                je __exit               ;AIL has no timers

                cmp AIL_hooked,0
                jne __exit              ;already ours

                call AIL_interrupt_divisor              ;restore AIL's PIT rate
                call set_PIT_divisor C,ax

                call hook_timer_process
                mov AIL_hooked,1

                ENDIF

__exit:         ret
                ENDP

;****************************************************************************
sub_ptr         PROC Off1,Seg1,Off2,Seg2
                USES ds,si,di           ;Return DX:AX = ptr 2 - ptr 1 (unused)

                mov ax,[Seg2]           ;DX:AX = linear address of ptr 2
                mov dx,0
                REPT 4
                shl ax,1
                rcl dx,1
                ENDM
                add ax,[Off2]
                adc dx,0

                mov bx,[Seg1]           ;CX:BX = linear address of ptr 1
                mov cx,0
                REPT 4
                shl bx,1
                rcl cx,1
                ENDM
                add bx,[Off1]
                adc cx,0

                sub ax,bx               ;the difference
                sbb dx,cx

                ret
                ENDP

;****************************************************************************
block_type      PROC                    ;Return AX=current block type
                USES ds,si,di

                lds si,block_ptr        ;the block's first byte
                lodsb
                mov ah,0

                ret
                ENDP

;****************************************************************************
marker_num      PROC                    ;Return AX=block's marker #
                USES ds,si,di

                lds si,block_ptr
                cmp BYTE PTR [si],4     ;type 4: marker
                mov ax,-1
                jne __exit              ;(not a marker block)
                mov ax,[si+4]           ;return marker #

__exit:         ret
                ENDP

;****************************************************************************
get_sample_rate PROC SB_Rate            ;Establish DSP sample rate
                USES ds,si,di

                mov bx,[SB_Rate]        ;BX = the .VOC time constant byte
                mov bh,0

                mov ax,256              ;f in Hz. = 1E6 / (256 - SB_Rate)
                sub ax,bx
                call ul_divide C,4240h,0fh,ax,0

                ret                     ;return DX:AX=sample rate in hertz
                ENDP

;****************************************************************************
DP_preformat    PROC SampRate,BufPtr:DWORD,Len:DWORD
                USES ds,si,di           ;have the driver convert Len bytes at
                                        ;BufPtr for output, BLK_SIZE at a time
                test DP_attribs,MODIFIES_DATA
                jz __exit               ;preformatting unnecessary, exit

                mov WORD PTR DPT.sndstat,OFFSET playing_flag    ;status word
                mov WORD PTR DPT.sndstat+2,cs

                mov ax,[SampRate]
                mov DPT.sndfreq,ax

                lds si,[BufPtr]         ;DS:SI -> the data

__while_gt_BLK: mov WORD PTR DPT.sndptr,si
                mov WORD PTR DPT.sndptr+2,ds

                cmp WORD PTR [Len+2],0  ;more than one block left?
                ja __gt_BLK
                cmp WORD PTR [Len],BLK_SIZE
                jbe __remainder

__gt_BLK:       mov DPT.sndlen,BLK_SIZE ;yes: convert a whole block

                push ds
                push si
                push cs                 ;DS:SI -> DPT
                pop ds
                lea si,DPT
                mov ax,68ah             ;function #3: massage audio
                int 66h
                pop si
                pop ds

                ADD_PTR BLK_SIZE,0,ds,si        ;next block

                sub WORD PTR [Len],BLK_SIZE
                sbb WORD PTR [Len+2],0
                jmp __while_gt_BLK

__remainder:    mov cx,WORD PTR [Len]   ;then what is left, if anything
                jcxz __exit

                mov DPT.sndlen,cx

                push cs                 ;DS:SI -> DPT
                pop ds
                lea si,DPT
                mov ax,68ah             ;massage audio
                int 66h

__exit:         ret
                ENDP

;****************************************************************************
CB_set_vect     PROC Handler:FAR PTR    ;Install simulated DMA IRQ handler
                USES ds,si,di

                mov ax,cs
                mov ds,ax
                mov bx,WORD PTR [Handler]       ;BX = offset, DX = segment
                mov dx,WORD PTR [Handler+2]
                mov ax,68eh
                int 66h                 ;DP function 7: set callback address

__exit:         ret
                ENDP

;****************************************************************************
CB_play_VOC     PROC                    ;Callback handler for .VOC file output

                cld

                call AIL_hook           ;restore AIL service

                mov ax,DMA_len_l        ;at end of block?
                or ax,DMA_len_h
                jz __end_of_block

                call xfer_chunk         ;no, send next chunk
                jmp __exit

__end_of_block: call next_block         ;else go on to next block in chain
                call process_block

__exit:         ret
                ENDP

;****************************************************************************
CB_play_buffer  PROC                    ;Callback handler for double-buffering

                cld

                call AIL_hook           ;restore AIL service

                mov ax,DMA_len_l        ;at end of block?
                or ax,DMA_len_h
                jz __end_of_block

                call xfer_chunk         ;no, send next chunk
                jmp __exit

__end_of_block: mov bx,current_buffer   ;else look for an unplayed buffer...
                mov buff_status[bx],DAC_DONE

                call next_buffer
                cmp ax,-1
                je __exit               ;no buffers left, terminate playback

                call process_buffer C,ax

__exit:         ret
                ENDP

;****************************************************************************
next_block      PROC                    ;Index next block in voice data
                USES ds,si,di

                lds si,block_ptr
                inc si                  ;skip block type
                lodsw
                mov dl,[si]
                mov dh,0                ;blk len: AL=LSB, AH=KSB, DL=MSB, DH=0
                inc si

                ADD_PTR ax,dx,ds,si     ;point to next block

                mov WORD PTR block_ptr,si
                mov WORD PTR block_ptr+2,ds

                ret
                ENDP

;****************************************************************************
next_buffer     PROC                    ;Find a registered, unplayed buffer
                USES ds,si,di

                mov ax,0                ;buffer 0 registered?
                cmp buff_status[0*2],DAC_STOPPED
                je __return             ;yes, return its handle
                mov ax,1                ;buffer 1 registered?
                cmp buff_status[1*2],DAC_STOPPED
                je __return             ;yes, return its handle

                mov DAC_status,DAC_DONE ;else signal playback complete and
                mov ax,-1               ;return AX=-1

__return:       ret
                ENDP

;****************************************************************************
process_block   PROC                    ;Process current block in voice data
                USES ds,si,di           ;(May be called from IRQ handler)

__do_block:     call block_type
                cmp ax,0                ;terminator?
                je __terminate
                cmp ax,1                ;new voice block?
                je __new_voice
                cmp ax,2                ;continued voice block?
                je __cont_voice
                cmp ax,4                ;marker (end of data?)
                je __terminate
                cmp ax,6                ;beginning of repeat loop?
                je __rept_loop
                cmp ax,7                ;end of repeat loop?
                je __end_loop
                jmp __skip_block        ;else unrecognized block type, skip it

__terminate:    mov DAC_status,DAC_DONE
                jmp __exit

__skip_block:   call next_block
                jmp __do_block

__rept_loop:    lds si,block_ptr        ;repeat count from the block
                mov ax,[si+4]
                mov loop_cnt,ax
                call next_block         ;loop back to the block after it
                lds si,block_ptr
                mov WORD PTR loop_ptr,si
                mov WORD PTR loop_ptr+2,ds
                jmp __do_block

__end_loop:     cmp loop_cnt,0
                je __skip_block         ;repeats done: go past the loop
                lds si,loop_ptr         ;else back to its start
                mov WORD PTR block_ptr,si
                mov WORD PTR block_ptr+2,ds
                cmp loop_cnt,0ffffh
                je __do_block           ;endless: count nothing
                dec loop_cnt
                jmp __do_block

__cont_voice:   lds si,block_ptr        ;continue output from new voice block
                lea ax,CB_play_VOC      ;enable EOD interrupts from DSP
                call CB_set_vect C,ax,cs
                mov ax,[si+1]
                mov dl,[si+3]
                mov dh,0                ;DX:AX = voice len
                ADD_PTR 4,0,ds,si       ;DS:SI -> start-of-data
                call DMA_transfer C,si,ds,ax,dx
                jmp __exit

__new_voice:    lds si,block_ptr        ;initiate output from new voice block

                call get_sample_rate C,[si+4]
                mov DPS.sndfreq,ax

                lea ax,CB_play_VOC      ;enable EOD interrupts from DSP
                call CB_set_vect C,ax,cs
                mov ax,[si+1]
                mov dl,[si+3]
                mov dh,0
                sub ax,2                ;less the rate and packing bytes
                sbb dx,0                ;DX:AX = voice len
                ADD_PTR 6,0,ds,si       ;DS:SI -> start-of-data
                call DMA_transfer C,si,ds,ax,dx

__exit:         ret
                ENDP

;****************************************************************************
process_buffer  PROC Buf                ;Play specified buffer
                USES ds,si,di

                mov si,[Buf]            ;get buffer handle
                shl si,1                ;derive index

                mov buff_status[si],DAC_PLAYING
                mov current_buffer,si   ;save index to playing buffer

                call get_sample_rate C,buff_sample[si]
                mov DPS.sndfreq,ax

                lea ax,CB_play_buffer   ;enable EOD interrupts from DSP
                call CB_set_vect C,ax,cs

                call DMA_transfer C,buff_data_o[si],buff_data_s[si],\
                     buff_len_l[si],buff_len_h[si]

                ret
                ENDP

;****************************************************************************
DMA_transfer    PROC Addr:FAR PTR,LenL,LenH
                USES ds,si,di           ;Set up simulated DMA transfer,
                                        ;and send first "chunk"
                lds si,[Addr]
                mov ax,[LenL]
                mov dx,[LenH]

                mov WORD PTR DMA_ptr,si ;remember what is left to send
                mov WORD PTR DMA_ptr+2,ds
                mov DMA_len_l,ax
                mov DMA_len_h,dx

                call xfer_chunk

                ret
                ENDP

;****************************************************************************
xfer_chunk      PROC                    ;Get addr, size of next chunk; send it
                USES ds,si,di
                LOCAL blk_len

                mov ax,BLK_SIZE         ;chunk = the rest, at most BLK_SIZE
                cmp DMA_len_h,0
                ja __set_size
                cmp DMA_len_l,ax
                ja __set_size
                mov ax,DMA_len_l
__set_size:     mov blk_len,ax          ;blk_len = # of bytes

                mov DPS.sndlen,ax

                mov WORD PTR DPS.sndstat,OFFSET playing_flag    ;status word
                mov WORD PTR DPS.sndstat+2,cs

                lds si,DMA_ptr
                FAR_TO_HUGE ds,si       ;DS:SI = start of data to send

                mov WORD PTR DPS.sndptr,si
                mov WORD PTR DPS.sndptr+2,ds

                ADD_PTR blk_len,0,ds,si ;add len of chunk to "DMA pointer"
                mov WORD PTR DMA_ptr,si
                mov WORD PTR DMA_ptr+2,ds

                mov ax,DMA_len_l        ;subtract len of transmitted chunk
                mov dx,DMA_len_h
                sub ax,blk_len
                sbb dx,0
                mov DMA_len_h,dx
                mov DMA_len_l,ax

                call AIL_unhook         ;let the driver have INT 8 if it needs it

                mov ax,cs               ;DS:SI -> DPS
                mov ds,ax
                lea si,DPS
                mov ax,688h             ;DP function 1: play digitized sound
                test DP_attribs,MODIFIES_DATA
                jz __DigPlay
                mov ax,68bh             ;DP function 4: play preformatted sound
__DigPlay:      int 66h

                ret
                ENDP

;****************************************************************************
;*                                                                          *
;*  Public (API-accessible) procedures                                      *
;*                                                                          *
;****************************************************************************

DP_describe_driver PROC H               ;Return far ptr to DDT
                USES ds,si,di

                cmp DP_installed,0
                jne __get_desc          ;installed already

                les di,DP_base
                mov call_seg,es
                add di,100h             ;offset to installation call
                mov call_off,di
                call [DP_call]          ;enable INT 66H interface

                mov ax,68ch             ;DP function 5: audio capabilities
                int 66h
                mov DP_attribs,ax

                mov ax,-1
                test DP_attribs,USES_TICK
                jz __set_int_svc        ;let application know if music will
                mov ax,0                ;be stopped by digitized output
__set_int_svc:  mov DP_uses_INT8,ax

                mov DP_installed,1

__get_desc:     les di,DP_base          ;copy DIGPAK device description string
                mov si,0                ;to local data area and return as
                mov cx,78               ;AIL device name list
__copy_name:    mov al,es:[di+12]       ;up to the first control character
                cmp al,32
                jb __end_string
                mov DP_name[si],al
                inc si
                inc di
                loop __copy_name
__end_string:   mov DP_name[si],0       ;add 2 0-bytes to end device name list
                mov DP_name[si+1],0

                mov dx,cs               ;DX:AX -> DP_DDT, whose name list is in CS
                mov DP_devname_s,dx
                lea ax,DP_DDT

                ret
                ENDP

;****************************************************************************
DP_detect_device PROC H,IO_ADDR,IRQ,DMA,DRQ
                USES ds,si,di

                mov ax,1                ;assume DIGPAK device exists

                ret
                ENDP

;****************************************************************************
DP_init_driver  PROC H,IO_ADDR,IRQ,DMA,DRQ
                USES ds,si,di

                call AIL_register_timer C,0,0
                mov DP_timer,ax         ;register dummy timer

                mov AIL_hooked,1        ;assume AIL timers currently enabled

                call DP_describe_driver C,0     ;install the driver

                mov loop_cnt,0          ;idle, in buffer mode, no buffers
                mov DAC_status,DAC_STOPPED
                mov buffer_mode,BUF_MODE

                mov buff_status[0*2],DAC_DONE
                mov buff_status[1*2],DAC_DONE

                ret
                ENDP

;****************************************************************************
DP_shutdown_driver PROC H,SignOff:FAR PTR
                USES ds,si,di

                call DP_stop_d_pb

                les di,DP_base
                mov call_seg,es
                add di,103h             ;offset to removal call
                mov call_off,di
                call [DP_call]

                call AIL_release_timer_handle C,[DP_timer]

                ret
                ENDP

;****************************************************************************
DP_index_VOC_blk PROC H,File:FAR PTR,Block,SBuf:FAR PTR
                USES ds,si,di           ;SBuf = the voice block after marker
                                        ;Block (-1: the first); AX = 1, or 0
                lds si,[File]           ;DS:SI -> the .VOC file
                mov ax,[si+14h]         ;get offset of data block
                ADD_PTR ax,0,ds,si

                mov bx,[Block]

__get_type:     mov al,[si]             ;get block type
                mov ah,0
                cmp ax,0                ;terminator block?
                je __exit               ;yes, return AX=0 (block not found)

                cmp ax,1                ;voice data block?
                jne __chk_marker        ;no

                cmp bx,-1               ;marker found (or disregarded)?
                je __vblk_found         ;yes, use this voice data block
                jmp __next_blk          ;no, keep looking

__chk_marker:   cmp ax,4                ;marker block?
                jne __next_blk          ;no, keep looking

                cmp bx,[si+4]           ;yes, compare marker numbers
                jne __next_blk

                mov bx,-1               ;marker found, use next voice block

__next_blk:     inc si
                lodsw
                mov dl,[si]
                mov dh,0                ;blk len: AL=LSB, AH=KSB, DL=MSB, DH=0
                inc si

                ADD_PTR ax,dx,ds,si     ;point to next block
                jmp __get_type

__vblk_found:   les di,[SBuf]           ;get pointer to output structure

                mov al,[si+4]           ;copy sampling rate
                mov ah,0
                mov es:[di].sample_rate,ax

                mov al,[si+5]           ;copy packing type
                mov ah,0
                mov es:[di].pack_type,ax

                mov ax,[si+1]           ;copy voice data length
                mov dl,[si+3]
                mov dh,0
                sub ax,2
                sbb dx,0
                mov es:[di].len_l,ax
                mov es:[di].len_h,dx

                mov dx,ds               ;copy pointer to voice data
                mov ax,si
                ADD_PTR 6,0,dx,ax
                mov WORD PTR es:[di].data,ax
                mov WORD PTR es:[di].data+2,dx

                mov ax,1

__exit:         ret
                ENDP

;****************************************************************************
DP_register_sb  PROC H,BufNum,SBuf:FAR PTR
                USES ds,si,di

                cmp buffer_mode,VOC_MODE
                jne __get_bufnum        ;not in VOC mode, proceed
                call DP_stop_d_pb C,0   ;else stop VOC file output first
                mov buffer_mode,BUF_MODE

__get_bufnum:   mov di,[BufNum]         ;get buffer #0-1
                shl di,1

                lds si,[SBuf]           ;copy structure data to buffer
                mov ax,[si].sample_rate ;descriptor fields
                mov buff_sample[di],ax

                les bx,[si].data
                mov buff_data_o[di],bx
                mov buff_data_s[di],es

                mov ax,[si].len_l
                mov buff_len_l[di],ax
                mov ax,[si].len_h
                mov buff_len_h[di],ax

                mov buff_status[di],DAC_STOPPED ;registered, not yet played

                ret
                ENDP

;****************************************************************************
DP_get_sb_status PROC H,HBuffer
                USES ds,si,di

                mov bx,[HBuffer]        ;AX = buffer HBuffer's DAC_* state
                shl bx,1
                mov ax,buff_status[bx]

                ret
                ENDP

;****************************************************************************
DP_play_VOC_file PROC H,File:FAR PTR,Block
                LOCAL block_file:DWORD
                USES ds,si,di

                call DP_stop_d_pb C,0   ;assert VOC mode
                mov buffer_mode,VOC_MODE

                les di,[File]
                mov WORD PTR block_file,di
                mov WORD PTR block_file+2,es

                mov DAC_status,DAC_DONE ;until the block is found

                lds si,block_file
                mov ax,[si+14h]         ;get offset of data block
                ADD_PTR ax,0,ds,si
                mov WORD PTR block_ptr,si
                mov WORD PTR block_ptr+2,ds

                cmp [Block],-1          ;play 1st block if no marker specified
                je __do_it

__find_blk:     call block_type
                cmp ax,0                ;terminator block?
                je __exit               ;yes, exit (block not found)
                call marker_num         ;get marker # (or -1 if non-marker)
                mov si,ax
                call next_block
                cmp si,[Block]
                jne __find_blk

__do_it:        mov DAC_status,DAC_STOPPED
                                        ;return w/block_ptr -> the block to play:
                                        ;the first, or the one after the marker
__exit:         ret
                ENDP

;****************************************************************************
DP_format_VOC_file PROC H,File:FAR PTR,Block
                LOCAL block_file:DWORD  ;leave interrupts enabled; this might
                LOCAL pack:BYTE         ;take awhile
                LOCAL freq:WORD
                USES ds,si,di

                mov pack,-1             ;no voice block seen yet

                les di,[File]
                mov WORD PTR block_file,di
                mov WORD PTR block_file+2,es

                lds si,block_file
                mov ax,[si+14h]         ;get offset of data block
                ADD_PTR ax,0,ds,si
                mov WORD PTR block_ptr,si
                mov WORD PTR block_ptr+2,ds

                cmp [Block],-1          ;format 1st blk if no marker specified
                je __preform_blk

__form_find:    call block_type
                cmp ax,0                ;terminator block?
                je __exit               ;yes, exit (block not found)
                call marker_num         ;get marker # (or -1 if non-marker)
                mov si,ax
                call next_block
                cmp si,[Block]
                jne __form_find

__preform_blk:  call block_type
                cmp ax,0
                je __exit               ;terminator: done
                cmp ax,1
                jne __not_vdata

                lds si,block_ptr        ;new voice block: its rate, packing
                call get_sample_rate C,[si+4]
                mov freq,ax

                mov al,[si+5]
                and al,0fh
                mov pack,al
                mov ax,[si+1]
                mov dx,[si+3]
                mov dh,0
                sub ax,2                ;voice data len = BLKLEN - 2
                sbb dx,0
                add si,6                ;DS:SI -> its data
                jmp __preform

__not_vdata:    cmp ax,2
                jne __preform_next      ;not voice data: skip

                lds si,block_ptr        ;continued voice block: length, data
                mov ax,[si+1]
                mov dx,[si+3]
                mov dh,0
                add si,4

__preform:      cmp pack,0              ;preformat only 8-bit PCM data
                jne __preform_next

                call DP_preformat,freq,si,ds,ax,dx

__preform_next: call next_block
                jmp __preform_blk

__exit:         ret
                ENDP

;****************************************************************************
DP_format_sb    PROC H,SBuf:FAR PTR
                USES ds,si,di
                LOCAL ssize:DWORD

                lds si,[SBuf]           ;preformat the buffer SBuf describes
                mov ax,[si].len_l
                mov dx,[si].len_h
                mov WORD PTR ssize,ax
                mov WORD PTR ssize+2,dx

                call get_sample_rate C,[si].sample_rate
                call DP_preformat C,ax,[si].data,ssize

                ret
                ENDP

;****************************************************************************
DP_start_d_pb   PROC H
                USES ds,si,di

                cmp buffer_mode,VOC_MODE
                je __voc_mode           ;start Creative Voice File playback

                cmp DAC_status,DAC_PLAYING
                je __exit               ;bail out if already playing

                call next_buffer        ;start dual-buffer playback
                cmp ax,-1
                je __exit               ;no buffers registered, exit

                mov DAC_status,DAC_PLAYING

                call process_buffer C,ax
                jmp __exit

__voc_mode:     cmp DAC_status,DAC_STOPPED
                jne __exit              ;no block ready, or already playing

                mov DAC_status,DAC_PLAYING

                call process_block

__exit:         ret
                ENDP

;****************************************************************************
DP_stop_d_pb    PROC H
                USES ds,si,di

                mov DAC_status,DAC_STOPPED

                call CB_set_vect C,0,0  ;remove callback trap

                mov ax,68fh             ;DP function 8: stop sound
                int 66h

                mov buff_status[0*2],DAC_DONE   ;both buffers played out
                mov buff_status[1*2],DAC_DONE

                call AIL_hook           ;restore AIL service

                ret
                ENDP

;****************************************************************************
DP_get_VOC_status PROC H
                USES ds,si,di

                mov ax,DAC_status       ;AX = the DAC_* playback state

                ret
                ENDP

                ENDIF                   ;end IF DIGPAK

;*****************************************************************************
;*                                                                           *
;* Turbo Pascal adapters                                                     *
;*                                                                           *
;*****************************************************************************
                ;Xmidi declares these as far externals.  Turbo Pascal pushes
                ;arguments left to right and the callee removes them, so its last
                ;argument lies nearest the saved BP and far return address.  Each
                ;adapter pushes copies in C order (first argument on top, a far
                ;pointer's segment above its offset), calls the AIL routine, drops
                ;the copies and returns with RET n.  PUBLIC PASCAL exports each
                ;name without the underscore the C model would prefix, so that
                ;it matches Xmidi's external declaration.

                PUBLIC PASCAL AilStartup
                PUBLIC PASCAL AilShutdown
                PUBLIC PASCAL AilRegisterDriver
                PUBLIC PASCAL AilDescribeDriver
                PUBLIC PASCAL AilDetectDevice
                PUBLIC PASCAL AilInitDriver
                PUBLIC PASCAL AilStateTableSize
                PUBLIC PASCAL AilDefaultTimbreCacheSize
                PUBLIC PASCAL AilDefineTimbreCache
                PUBLIC PASCAL AilRegisterSequence
                PUBLIC PASCAL AilTimbreRequest
                PUBLIC PASCAL AilInstallTimbre
                PUBLIC PASCAL AilStartSequence
                PUBLIC PASCAL AilSequenceStatus

AilStartup PROC FAR                     ;no arguments
                call AIL_startup
                ret
                ENDP

AilShutdown PROC FAR                    ;(signoff: Pointer)
                push bp
                mov bp,sp
                push WORD PTR [bp+8]    ;signoff
                push WORD PTR [bp+6]
                call AIL_shutdown
                add sp,4
                pop bp
                ret 4
                ENDP

AilRegisterDriver PROC FAR              ;(image: Pointer): AX = driver handle
                push bp
                mov bp,sp
                push WORD PTR [bp+8]    ;image
                push WORD PTR [bp+6]
                call AIL_register_driver
                add sp,4
                pop bp
                ret 4
                ENDP

AilDescribeDriver PROC FAR              ;(driver): DX:AX -> its drvr_desc
                push bp
                mov bp,sp
                push WORD PTR [bp+6]    ;driver
                call AIL_describe_driver
                add sp,2
                pop bp
                ret 2
                ENDP

AilDetectDevice PROC FAR                ;(driver, ioPort, irq, dma, drq): AX
                push bp
                mov bp,sp
                push WORD PTR [bp+6]    ;drq
                push WORD PTR [bp+8]    ;dma
                push WORD PTR [bp+10]   ;irq
                push WORD PTR [bp+12]   ;ioPort
                push WORD PTR [bp+14]   ;driver
                call AIL_detect_device
                add sp,10
                pop bp
                ret 10
                ENDP

AilInitDriver PROC FAR                  ;(driver, ioPort, irq, dma, drq)
                push bp
                mov bp,sp
                push WORD PTR [bp+6]    ;drq
                push WORD PTR [bp+8]    ;dma
                push WORD PTR [bp+10]   ;irq
                push WORD PTR [bp+12]   ;ioPort
                push WORD PTR [bp+14]   ;driver
                call AIL_init_driver
                add sp,10
                pop bp
                ret 10
                ENDP

AilStateTableSize PROC FAR              ;(driver): AX = bytes
                push bp
                mov bp,sp
                push WORD PTR [bp+6]    ;driver
                call AIL_state_table_size
                add sp,2
                pop bp
                ret 2
                ENDP

AilDefaultTimbreCacheSize PROC FAR        ;(driver): AX = bytes
                push bp
                mov bp,sp
                push WORD PTR [bp+6]    ;driver
                call AIL_default_timbre_cache_size
                add sp,2
                pop bp
                ret 2
                ENDP

AilDefineTimbreCache PROC FAR           ;(driver, cache: Pointer, cacheSize)
                push bp
                mov bp,sp
                push WORD PTR [bp+6]    ;cacheSize
                push WORD PTR [bp+10]   ;cache
                push WORD PTR [bp+8]
                push WORD PTR [bp+12]   ;driver
                call AIL_define_timbre_cache
                add sp,8
                pop bp
                ret 8
                ENDP

AilRegisterSequence PROC FAR            ;(driver, image: Pointer, number,
                push bp                 ;state, controllers: Pointer): AX
                mov bp,sp
                push WORD PTR [bp+8]    ;controllers
                push WORD PTR [bp+6]
                push WORD PTR [bp+12]   ;state
                push WORD PTR [bp+10]
                push WORD PTR [bp+14]   ;number
                push WORD PTR [bp+18]   ;image
                push WORD PTR [bp+16]
                push WORD PTR [bp+20]   ;driver
                call AIL_register_sequence
                add sp,16
                pop bp
                ret 16
                ENDP

AilTimbreRequest PROC FAR               ;(driver, sequence): AX
                push bp
                mov bp,sp
                push WORD PTR [bp+6]    ;sequence
                push WORD PTR [bp+8]    ;driver
                call AIL_timbre_request
                add sp,4
                pop bp
                ret 4
                ENDP

AilInstallTimbre PROC FAR               ;(driver, bank, patch, image: Pointer)
                push bp
                mov bp,sp
                push WORD PTR [bp+8]    ;image
                push WORD PTR [bp+6]
                push WORD PTR [bp+10]   ;patch
                push WORD PTR [bp+12]   ;bank
                push WORD PTR [bp+14]   ;driver
                call AIL_install_timbre
                add sp,10
                pop bp
                ret 10
                ENDP

AilStartSequence PROC FAR               ;(driver, sequence)
                push bp
                mov bp,sp
                push WORD PTR [bp+6]    ;sequence
                push WORD PTR [bp+8]    ;driver
                call AIL_start_sequence
                add sp,4
                pop bp
                ret 4
                ENDP

AilSequenceStatus PROC FAR              ;(driver, sequence): AX
                push bp
                mov bp,sp
                push WORD PTR [bp+6]    ;sequence
                push WORD PTR [bp+8]    ;driver
                call AIL_sequence_status
                add sp,4
                pop bp
                ret 4
                ENDP

                END

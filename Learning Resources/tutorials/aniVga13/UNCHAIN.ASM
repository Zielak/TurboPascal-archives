;Here's the TSR I mentioned a few days ago.  Only it's not a TSR, and
;I took the easy way out of supporting only the mode I use.  Just change my
;mode set to yours and save any register you change!
;
;Do what the hell you like with it...
;.----------------------------------------------------.
;| Colin Buckley                                      |
;| Toronto, Ontario, Canada                           |
;| InterNet: colin.buckley@rose.com                   |
;|                                                    |
;| So Eager to Play, So Relunctant to Admit it...     |
;`----------------------------------------------------'
;
;UNCHAIN.ASM starts here...
;
; ---------------------------------------------------------------------
; UNCHAIN.EXE -- 320x200x256x4 Enforcer -- Colin Buckley
; Released to the PUBLIC DOMAIN January 14, 1993.
; If you modify this, add your name and changes and please
; send the source my way.  (Internet: colin.buckley@rose.com)
;
; January 14, 1993
; o Started
; o Released
;
; NOTES:
;
; Use TASM to compile.
;
; Requires 1K of memory
;
; Most of display memory on Plane 1 from Page 1 (0..16000) will be corrupt
; because of entering text mode.  So don't use the first page during debugging,
; although it's not all that bad of a mess.  Perhaps I'll add an option to
; watch for text mode and save that plane, of course it'll need ~10,000 bytes.
; I don't know what text mode places in A000, fonts ring a bell.  Anyways,
; maybe using mono text mode will help.  I haven't tried.
;
; You can turn off EGA/VGA graphic save if your debugger uses it, as it won't
; work.  At least you'll get ~10,000 bytes back.
;
; UNCHAIN has been tested with Turbo Pascal 6, and Turbo Debugger.
;
; TP doesn't save the palette correctly either, I'll probably add that
; next.
;
; I wrote UNCHAIN for myself, I don't plan to support it, remove the
; 320x200x256x4 set mode, add yours, save and restore all modified registers,
; compile, and it should work fine.
;
;
; PURPOSE:
;
; Most debuggers will only remember which Video Mode you're in, if you're
; using an unchained (aka planar, mode x) mode, then the debugger will drop
; you in Mode 13h, and not restore your VGA register modifications.
;
; UNCHAIN will modify the registers everytime Mode 13h is called.  If
; you're not using 320x200x256x4, then use your Mode Set instead of
; the 320x200x256x4 routine curently used.
;
;
; USAGE:
;
; If you use
;
; >TD YourGame.EXE <YourGame commandline options>
;
; then use
;
; >UNCHAIN TD YourGame.EXE <YourGame commandline options>
;
; UNCHAIN will spawn TD and Turbo Debugger will load your game and
; operate as usual.
;
;
; ENHANCEMENTS:
;
; You could use some marker like FF13h and upon encountering that you
; save all VGA registers, and every 0013h encountered restore all VGA
; registers.
;
;
; WARNING, IF YOU CHANGE THE SOURCE:
;
; Watch out for the small stack!
;
; Save and restore all modified registers in your mode set routine.
; I change AX and DX, so I save them and restore them at both possible
; exits.
;
; Add all the segment sizes in your MAP and place that value in the
; MemoryReq equate.
; ---------------------------------------------------------------------

    IDEAL
    DOSSEG
    MODEL  Small
    STACK  24
    LOCALS

; Program Size in bytes
MemoryReq      EQU  1024             ;Only need 720 bytes, but what the hell.

; VGA Registers
AC_Addr        EQU  3C0h             ;Attribute Controller Port Address
GC_Addr        EQU  3CEh             ;Graphic Controller Port Address
SC_Addr        EQU  3C4h             ;Sequence Controller Port Address
CRTC_Addr      EQU  3D4h             ;CRT Controller Port Address

    DATASEG

; Variables
Copyright   DB 13,10,'UNCHAIN -- 320x200x256x4 Enforcer! -- Colin Buckley (colin.buckley@rose.com)'
            DB 13,10,'Released to the PUBLIC DOMAIN January 14, 1993.'
            DB 13,10,'$'
Usage       DB 13,10,'Usage: UNCHAIN <Filename> <Parameters>'
            DB 13,10,'$'
FileError   DB 13,10,'Error: Can not execute file!'
            DB 13,10,'$'

FileOkay    DB 0                     ;File Okay to execute
File        DB 80 DUP(0)             ;File to execute
ParamLen    DB 0                     ;Length of Parameter
Param       DB 80 DUP(13)            ;Parameter
FCB         DB 16 DUP(0)             ;File control block
ParamBlock  DW 0                     ;Parameter block
            DW ParamLen
            DW @DATA
            DW FCB,@DATA
            DW FCB,@DATA

    CODESEG

; Variables
VideoISR        DD 0                 ;To save original INT 10h vector
OldSS           DW ?                 ;To save SS
OldSP           DW ?                 ;To save SP
; New VideoISR
PROC Int10hISR FAR
    PUSH  AX DX
    ; Check for Video BIOS Function 00h -- Set Video Mode
    CMP   AX,0013h                    ;If VGA then
    JZ    @@DoIt                      ;  DoIt;
    CMP   AX,0013h+128                ;If Not VGA then
    JNZ   @@OriginalISR               ;  OriginalISR;
@@DoIt:
    ; Call original Int 10h and let it set Mode 13h
    PUSHF
    CALL  [CS:VideoISR]
    ;
    ; Unchain Mode 13 (320x200x256x4)
    ;
    ; Alter CPU addressing of Video Memory
    MOV   DX,SC_Addr                  ; |Disable Chain 4
    MOV   AL,4                        ; |Disable Odd/Even
    OUT   DX,AL                       ; |
    INC   DX                          ; |
    IN    AL,DX                       ; |
    AND   AL,NOT 08h                  ; |
    OR    AL,04h                      ; |
    OUT   DX,AL                       ;/
    MOV   DX,GC_Addr                  ; |Disable Odd/Even
    MOV   AL,5                        ; |
    OUT   DX,AL                       ; |
    INC   DX                          ; |
    IN    AL,DX                       ; |
    AND   AL,NOT 10h                  ; |
    OUT   DX,AL                       ;/
    DEC   DX                          ; |Disable Chain
    MOV   AL,6                        ; |
    OUT   DX,AL                       ; |
    INC   DX                          ; |
    IN    AL,DX                       ; |
    AND   AL,NOT 02h                  ; |
    OUT   DX,AL                       ;/
    ; Change linear 320x200 to planar 320x200
    MOV   DX,CRTC_Addr                ; |Disable DoubleWord Mode
    MOV   AL,14h                      ; |
    OUT   DX,AL                       ; |
    INC   DX                          ; |
    IN    AL,DX                       ; |
    AND   AL,NOT 40h                  ; |
    OUT   DX,AX                       ;/
    DEC   DX                          ; |Enable Byte Mode
    MOV   AL,17h                      ; |
    OUT   DX,AL                       ; |
    INC   DX                          ; |
    IN    AL,DX                       ; |
    OR    AL,40h                      ; |
    OUT   DX,AL                       ;/
    ;
    ;
    ;
    POP   DX AX
    IRET
@@OriginalISR:
    POP   DX AX
    JMP   [CS:VideoISR]              ;Continue Original ISR chain
ENDP Int10hISR

PROC DoParams
    ;ES = PSP, DS = DataSeg
    CMP   [BYTE ES:80h],0             ;Compare PSP:80h to 0
    JE    @@Exit                      ;Yes, Exit
    XOR   CX,CX                       ;CX <- 0
    MOV   AL,' '                      ;Look for Space
    MOV   DI,82h                      ;Search starting at PSP:82h
    MOV   CL,[ES:80h]                 ;Search for length of PSP:81h
    CLD                               ;Auto increment
    REPNZ SCASB                       ;Search until Space is found
    DEC   DI                          ;Go back to found position
    PUSH  DI ES DS                    ;Save Position, ES, & DS
    POP   ES DS                       ;Restore DS in ES
    ;ES = DataSeg, DS = PSP
    MOV   SI,82h                      ;SI <- PSP:82h
    MOV   DI,OFFSET File              ;DI <- File String
    POP   CX                          ;AX <- Length
    SUB   CL,82h                      ;Get Length of file string
    MOV   AX,CX                       ;Store AX <- CX
    REP   MOVSB                       ;Copy File <- SI
    INC   AL                          ;Include one more character for spaces
    CMP   [BYTE 80h],AL               ;Are there anymore Params?
    JE    @@Equal                     ;No, jump to Equal
    MOV   DI,OFFSET Param             ;DI <- Param String
    MOV   CL,[80h]                    ; | CX <- Calculate length of Param
    SUB   CL,AL                       ;/
    MOV   [ES:ParamLen],CL            ;Store length of Param in ParamLen
    REP   MOVSB                       ;Copy Param <- SI
@@Equal:
    INC   [ES:FileOkay]               ;Okay to execute file
    PUSH  ES                          ; |Make ES and DS equal
    POP   DS                          ;/
@@Exit:
    RET
ENDP DoParams

; Install Procedure
PROC Install
    PUSH  ES                          ;Save ES
    ; Save Original Int 10h ISR
    MOV   AX,3510h                    ;Get Interrupt function
    INT   21h                         ;DOS Interrupt
    MOV   [WORD PTR CS:VideoISR],BX   ;Save Int 10h Offset
    MOV   [WORD PTR CS:VideoISR+2],ES ;Save Int 10h Segment
    POP   ES                          ;Restore ES
    PUSH  DS CS                       ; |Save DS then Make DS and CS Equal
    POP   DS                          ;/
    ; Install Int 10h ISR
    MOV   AX,2510h                    ;Set Interrupt function
    LEA   DX,[Int10hISR]              ;Use new Interrupt handler
    INT   21h                         ;DOS Interrupt
    POP   DS                          ;Restore DS
    RET
ENDP Install

; Un-Install Procedure
PROC UnInstall
    PUSH  DS
    ; Resets Original Int 10h handler
    LDS   DX,[CS:VideoISR]            ;Use old Interrupt
    MOV   AX,2510h                    ;Set Interrupt Vector function
    INT   21h                         ;DOS Interrupt
    POP   DS
    RET
ENDP UnInstall

; Start of Program
Start:
    ; Shrink Memory
    MOV   AH,4Ah                      ;Modify Memory Allocation
    MOV   BX,MemoryReq/16             ;Request enough memory
    INT   21h                         ;Ask nicely.

    ; Initilize Segments
    MOV   AX,@DATA                    ; |Initilize Extra Segment
    MOV   DS,AX                       ;/

    ; Split Commandline
    CALL  DoParams                    ;Splits Commandline

    ; Do Intro
    MOV   AH,9h
    MOV   DX,OFFSET Copyright
    INT   21h
    ; Check Parameters
    CMP   [FileOkay],1                ;Is file okay to execute
    JE    @@ParamOkay                 ;Yes, Jump
    ; Parameter Error
    MOV   AH,9h
    MOV   DX,OFFSET Usage
    INT   21h
    JMP   SHORT @@ExitProgram         ;Jump to exit

@@ParamOkay:
    CALL  Install                     ;Install

    MOV   BX,Offset ParamBlock        ;ParamBlock -> BX
    MOV   DX,Offset File              ;Filename -> DX
    MOV   [CS:OldSS],SS               ;Save Stack Segment
    MOV   [CS:OldSP],SP               ;Save Stack Pointer
    MOV   AX,4B00h                    ;Execute program
    INT   21h                         ;DOS Interrupt
    STI                               ;Disable Interrupts
    MOV   SS,[CS:OldSS]               ;ReStore Stack Segment
    MOV   SP,[CS:OldSP]               ;ReStore Stack Pointer
    CLI                               ;Enable Interrupt
    JNC   @@Okay                      ; |If Carry set then
    MOV   AH,9h                       ; |  Error;
    MOV   DX,OFFSET FileError         ; |
    INT   21h                         ;/
@@Okay:
    CALL  UnInstall                   ;UnInstall

@@ExitProgram:
    MOV   AX,4C00h
    INT   21h

    END   START

.org   $E000
.store $E000, $2000, "kernal-by-bsa.bin"

#ifdef MAKE_K1                  ; b500-kernal.901244-01.bin
        K1      = 1             ; FIXME: this version is not implemented yet
        K3B     = 0
        K4A     = 0
        K4AO    = 0
        K4BO    = 0
        MHZ     = 2             ; 2 MHz machine
#else
#ifdef MAKE_K3B                 ; kernal.901244-03b.bin
        K1      = 0
        K3B     = 1
        K4A     = 0
        K4AO    = 0
        K4BO    = 0
        MHZ     = 2             ; 2 MHz machine
#else
#ifdef MAKE_K4A                 ; kernal.901244-04a.bin
        K1      = 0
        K3B     = 0
        K4A     = 1
        K4AO    = 0
        K4BO    = 0
        MHZ     = 2             ; 2 MHz machine
#else
#ifdef MAKE_K4AO                ; kernal.901244-04a.official.bin
        K1      = 0
        K3B     = 0
        K4A     = 0
        K4AO    = 1
        K4BO    = 0
        MHZ     = 2             ; 2 MHz machine
#else
#ifdef MAKE_K4BO                ; kernal.901244-04b.official.bin
        K1      = 0
        K3B     = 0
        K4A     = 0
        K4AO    = 0
        K4BO    = 1
        MHZ     = 2             ; 2 MHz machine
#else
#error Please define MAKE_<your version> to select a KERNAL version
#endif ; MAKE_K4BO
#endif ; MAKE_K4AO
#endif ; MAKE_K4A
#endif ; MAKE_K3B
#endif ; MAKE_K1

; ***********************************************************
;
; Speicher-Deklarationen
;


.include        "cbm-ii.inc"

bad                  = $0100
StackP               = $01FF


; Definitionen für Inter Process Communication

IPCBuf               = $0800
IPCjmpTab            = $0810
IPCParmTab           = $0910


; ***********************************************************
;
; Routinen für Bildschirmbehandlung und Tastatur
;


; -------------------------------------------------------------------------
; Sprungtabelle für Kernal-Funktionen

        jmp     MonitorW                ; Monitor-Einsprung
        nop
jmp_scrinit:
        jmp     do_scrinit              ; Reset Tastatur unc CRT Format
jmp_GetKey:
        jmp     GetKey                  ; Zeichen aus Tastaturpuffer holen
jmp_basin_crt:
        jmp     basin_crt               ; Zeichen vom Bildschirm holen
jmp_bsout_crt:
        jmp     bsout_crt               ; Ausgabe auf CRT
jmp_screen:
        jmp     do_screen               ; Anzahl Zeilen und Spalten holen
jmp_scnkey:
        jmp     do_scnkey               ; Tastatur abfragen
        jmp     SetCurs                 ; Cursor setzen (Hardware)
jmp_plot:
        jmp     do_plot                 ; Cursorposition setzen/holen (Software)
jmp_iobase:
        jmp     do_iobase               ; Basisadresse CIA holen
jmp_escseq:
        jmp     ESCseq                  ; ESC-Sequenz ausführen, Zeichen in AC
jmp_funkey:
        jmp     do_funkey               ; Funktionstasten listen/belegen

; -------------------------------------------------------------------------
; Cursorposition setzen/holen

do_plot:
        bcs     do_plot20
        stx     CursLine
        stx     LastCol
        sty     CursCol
        sty     LastLine
        jsr     InitLine                ; Zeiger auf Zeilenanfang im RAM setzen
        jsr     SetCurs                 ; Cursor setzen (Hardware)
do_plot20:
        ldx     CursLine
        ldy     CursCol
        rts
; -------------------------------------------------------------------------
; Begin des I/O-Bereiches holen

do_iobase:
        ldx     #<cia
        ldy     #>cia
        rts
; -------------------------------------------------------------------------
; Bildschirmformat holen

do_screen:
        ldx     #80             ; Anzahl Spalten
        ldy     #25             ; und Zeilen
        rts
; -------------------------------------------------------------------------
; Bildschirm und Tastatur rücksetzen

do_scrinit:
        lda     #$00
        ldx     #$23
LE048:
        sta     PgmKeyPtr,x     ; Zeropage-Merker löschen
        dex
        bpl     LE048
        ldx     #$20
LE04F:
        sta     rvsFlag,x
        dex
        bpl     LE04F
        lda     #$0C
        sta     RepeatDelay     ; 12*20ms = 240ms bis Tastenrepeat
        lda     #$60
        sta     Config          ; Cursorformat setzen
        lda     #<ProcessFunKey
        sta     funvec
        lda     #>ProcessFunKey
        sta     funvec+1        ; Funktionstastenvektor belegen

; Funktionstasten belegen, wenn noch nicht geschehen

        lda     PgmKeyBuf
        ora     PgmKeyBuf+1     ; bereits belegt ?
        bne     LE0AA           ; ja: skip

        lda     SysMemTop
        sta     PgmKeyEnd
        lda     SysMemTop+1
        sta     PgmKeyEnd+1
        lda     #$40
        ldx     #$00
        ldy     #$02            ; 512 Bytes...
        jsr     getmem          ; ... Speicher reservieren
        bcs     LE0AA           ; Fehler: Ende
        sta     PgmKeySeg
        inx
        stx     PgmKeyBuf
        bne     LE08D
        iny

; Texte der Funktionstasten kopieren

LE08D:
        sty     PgmKeyBuf+1
        ldy     #PgmKeyTxtLen   ; Gesamtlänge der Texte
        jsr     SwToPgmKeySeg   ; Auf Bank mit Funktionstastentexten schalten
LE094:
        lda     PgmKeyDefTxt-1,y
        dey
        sta     (PgmKeyBuf),y
        bne     LE094
        jsr     SwitchOldSeg
        ldy     #DefPgmKeyAnz           ; Anzahl zu belegender Tasten
LE0A1:
        lda     PgmKeyDefLen-1,y        ; Längen der Texte kopieren
        sta     PgmKeySeg,y
        dey
        bne     LE0A1
LE0AA:
        jsr     ResetCRTSize            ; Bildschirmgröße rücksetzen
        jsr     LE251                   ; Auf Lower Case schalten
        jsr     Init6545                ; Videocontroller initialisieren
ClrHome:
        jsr     Home                    ; Cursor nach links oben setzen
LE0B6:
        jsr     LE0CF                   ; Zeiger auf Zeile im Videoram setzen
        jsr     EraseLine               ; Zeile löschen
        cpx     ScreenBot               ; unterste Zeile erreicht ?
        inx
        bcc     LE0B6                   ; nein: nächste

; Cursor nach links oben setzen

Home:
        ldx     ScreenTop
        stx     CursLine
        stx     LastCol
LE0C7:
        ldy     ScreenLeft
        sty     CursCol
        sty     LastLine

; Zeiger auf Zeilenanfang im Videoram setzen

InitLine:
        ldx     CursLine
LE0CF:
        lda     LineLSBTab,x            ; Adresse aus Tabelle holen
        sta     CharPtr
        lda     LineMSBTab,x
        sta     CharPtr+1
        rts
; -------------------------------------------------------------------------
; Dem 6545 die Cursorposition mitteilen

SetCurs:
        ldy     #$0F
        clc
        lda     CharPtr
        adc     CursCol
        sty     crtc+CAdrReg
        sta     crtc+CDataReg
        dey
        sty     crtc+CAdrReg
        lda     crtc+CDataReg
        and     #$F8
        sta     sedt1
        lda     CharPtr+1
        adc     #$00
        and     #$07
        ora     sedt1
        sta     crtc+CDataReg
        rts
; -------------------------------------------------------------------------
; Zeichen von Tastatur holen

GetKey:
        ldx     KeyIndex        ; Zeichen von Funktionstaste ?
        beq     LE114           ; nein: jmp

; Zeichen nicht aus Puffer sondern direkt von Text holen

        ldy     PgmKeyIndex
        jsr     SwToPgmKeySeg   ; Auf Bank mit Funktionstastentexten schalten
        lda     (PgmKeyPtr),y   ; Zeichen holen
        jsr     SwitchOldSeg    ; Bank rückschalten
        dec     KeyIndex
        inc     PgmKeyIndex
        cli
        rts
; -------------------------------------------------------------------------
; Zeichen aus Tastaturpuffer holen

LE114:
        ldy     Keyd            ; erstes Zeichen im Puffer holen
        ldx     #$00
LE119:
        lda     Keyd+1,x        ; Zeichen im Puffer aufrücken
        sta     Keyd,x
        inx
        cpx     KeyBufIndex
        bne     LE119
        dec     KeyBufIndex
        tya
        cli
        rts
; -------------------------------------------------------------------------
; Warteschleife für Tastatureingaben

LE129:
        jsr     bsout_crt       ; Ausgabe auf CRT
LE12C:
        ldy     #$0A
        lda     Config          ; Cursorformat
        sty     crtc+CAdrReg
        sta     crtc+CDataReg   ; Cursor setzen
LE136:
        lda     KeyBufIndex
        ora     KeyIndex        ; Taste gedrückt ?
        beq     LE136           ; nein: warten
        sei
#if K1 | K3B | K4AO | K4BO
        lda     #$20
        sty     crtc+CAdrReg
        sta     crtc+CDataReg   ; Cursor löschen
#endif
        jsr     GetKey          ; Zeichen holen
        cmp     #$0D            ; cr ?
        bne     LE129           ; nein, dann ausgeben und weiter warten
#if K4A
        jsr     LECDC
        nop
        nop
        nop
        nop
        nop
#endif
        sta     crsw            ; cr merken
        jsr     CurToEOL        ; Zeilenende nach xr
        stx     linetmp         ; und merken
#if K1 | K3B | K4AO | K4BO
        jsr     LE536           ; Cursor auf Zeilenanfang
        lda     #$00
#endif
#if K4A
        jsr	LECB0
        sta     Insrt
#endif
        sta     QuoteSw         ; Insertflag löschen
        ldy     ScreenLeft
        lda     LastCol
        bmi     LE174
        cmp     CursLine
        bcc     LE174
        ldy     LastLine
        cmp     linetmp
        bne     LE170
        cpy     LastLinePos
        beq     LE172
LE170:
        bcs     LE183
LE172:
        sta     CursLine
LE174:
        sty     CursCol
        jmp     LE18B           ; Zeichen vom CRT holen
; -------------------------------------------------------------------------
; Eingabe vom CRT holen

basin_crt:
        tya
        pha
        txa
        pha
        lda     crsw            ; Zeile mit cr abgeschlossen ?
        beq     LE12C           ; nein: Warten
        bpl     LE18B
LE183:                          ; Zeile war zu Ende
        lda     #$00
        sta     crsw            ; Flag löschen
        lda     #$0D            ; cr rückgeben
        bne     LE1C4
LE18B:
        jsr     InitLine        ; Zeiger auf Zeilenanfang im RAM setzen
        jsr     GetChar         ; Zeichen vom Bildschirm holen
        sta     PrtData
        and     #$3F
        asl     PrtData
        bit     PrtData
        bpl     LE19D
        ora     #$80
LE19D:
        bcc     LE1A3
        ldx     QuoteSw
        bne     LE1A7
LE1A3:
        bvs     LE1A7
        ora     #$40
LE1A7:
        jsr     ChkHochKomma
        ldy     CursLine
        cpy     linetmp
        bcc     LE1BB
        ldy     CursCol
        cpy     LastLinePos
        bcc     LE1BB
        ror     crsw
        bmi     LE1BE
LE1BB:
        jsr     LE574
LE1BE:
        cmp     #$DE
        bne     LE1C4
        lda     #$FF
LE1C4:
        sta     PrtData
        pla
        tax
        pla
        tay
        lda     PrtData
        rts
; -------------------------------------------------------------------------
ChkHochKomma:
        cmp     #'"'
        bne     LE1DD
        lda     Insrt
        bne     LE1DB
        lda     QuoteSw         ; Hochkommaflag invertieren
        eor     #$01
        sta     QuoteSw
LE1DB:
        lda     #'"'
LE1DD:
        rts
; -------------------------------------------------------------------------
; Zeichen auf Bildschirm ausgeben

PrtChar:
        bit     rvsFlag
        bpl     LE1E5
        ora     #$80
LE1E5:
        ldx     Insrt
        beq     LE1EB
        dec     Insrt
LE1EB:
        bit     InsertFlag
        bpl     LE1F9
        pha
        jsr     do_INST
        ldx     #$00
        stx     Insrt
        pla
LE1F9:
        jsr     PutChar
        cpy     #$45
        bne     LE203
        jsr     bell
LE203:
        jsr     LE62E
LE206:
        lda     PrtData
        sta     LastPrtChar
        jsr     SetCurs                 ; Cursor setzen (Hardware)
        pla
        tay
        lda     Insrt
        beq     LE216
        lsr     QuoteSw
LE216:
        pla
        tax
        pla
        rts
; -------------------------------------------------------------------------
EraseChar:
        lda     #' '
PutChar:
        ldy     CursCol
        jsr     SwitchSeg
        sta     (CharPtr),y
        jsr     SwitchOldSeg    ; Bank rückschalten
        rts
; -------------------------------------------------------------------------
; aktuelle Zeile löschen

EraseLine:
        ldy     ScreenLeft
        jsr     LE505
LE22C:
        txa
        pha
        lda     CursCol
        pha
        dey
LE232:
        iny
        sty     CursCol
        jsr     EraseChar
        cpy     ScreenRight
        bne     LE232
        pla
        sta     CursCol
        pla
        tax
        rts
; -------------------------------------------------------------------------
; Zeichen vom Bildschirm holen

GetChar:
        ldy     CursCol
LE244:
        jsr     SwitchSeg
        lda     (CharPtr),y
        jsr     SwitchOldSeg    ; Bank rückschalten
        rts
; -------------------------------------------------------------------------
SwitchCase:
        ldy     #$10
        bcs     LE253
LE251:
        ldy     #$00
LE253:
        sty     GrafMode
        lda     tpi1+tpiCtrlReg
        and     #$EF
        ora     GrafMode
        sta     tpi1+tpiCtrlReg
        rts
; -------------------------------------------------------------------------
Init6545:
        ldy     #$11
        bit     tpi2+tpiPortC
        bmi     LE26D
        ldy     #$23
        bvs     LE26D
        ldy     #$35
LE26D:
        ldx     #$11
LE26F:
        lda     m6545tab,y
        stx     crtc+CAdrReg
        sta     crtc+CDataReg
        dey
        dex
        bpl     LE26F
        rts
; -------------------------------------------------------------------------
SwitchSeg:
        pha
        lda     #$3F
        bne     LE286

; Auf Bank mit Funktionstastentexten schalten

SwToPgmKeySeg:
        pha
        lda     PgmKeySeg
LE286:
        pha
        lda     IndReg
        sta     SegSave
        pla
        sta     IndReg
        pla
        rts
; -------------------------------------------------------------------------
; Bank rückschalten

SwitchOldSeg:
        pha
        lda     SegSave
        sta     IndReg
        pla
        rts
; -------------------------------------------------------------------------
; Ausgabe auf CRT

bsout_crt:
        pha
        cmp     #$FF
        bne     LE2A0
        lda     #$DE
LE2A0:
        sta     PrtData
        txa
        pha
        tya
        pha
        lda     #$00
        sta     crsw
        ldy     CursCol
        lda     PrtData
        and     #$7F
        cmp     #$20
        bcc     CtrlCode
        ldx     LastPrtChar
        cpx     #$1B
        bne     LE2C1
        jsr     do_ESC
        jmp     LE303
; -------------------------------------------------------------------------
LE2C1:
        and     #$3F
LE2C3:
        bit     PrtData
        bpl     LE2C9
        ora     #$40
LE2C9:
        jsr     ChkHochKomma
        jmp     PrtChar
; -------------------------------------------------------------------------
CtrlCode:
        cmp     #$0D
        beq     LE2FC
        cmp     #$14
        beq     LE2FC
        cmp     #$1B
        bne     LE2EC
        bit     PrtData
        bmi     LE2EC
        lda     QuoteSw
        ora     Insrt
        beq     LE2FC
        jsr     CancelIModes
        sta     PrtData
        beq     LE2FC
LE2EC:
        cmp     #$03
        beq     LE2FC
        ldy     Insrt
        bne     LE2F8
        ldy     QuoteSw
        beq     LE2FC
LE2F8:
        ora     #$80
        bne     LE2C3
LE2FC:
        lda     PrtData
        asl     a
        tax
        jsr     LE306
LE303:
        jmp     LE206
; -------------------------------------------------------------------------
LE306:
        lda     WhiteSpaceTab+1,x
        pha
        lda     WhiteSpaceTab,x
        pha
        lda     PrtData
        rts
; -------------------------------------------------------------------------
do_CTRL:
        jmp     (ctrlvec)
; -------------------------------------------------------------------------
; cursor vertical move

CursVertMove:
        bcs     LE323
        jsr     LE37A
LE319:
        jsr     LE4F5
        bcs     LE321
        sec
        ror     LastCol
LE321:
        clc
        rts
; -------------------------------------------------------------------------
LE323:
        ldx     ScreenTop
        cpx     CursLine
        bcs     LE338
LE329:
        jsr     LE319
        dec     CursLine
        jmp     InitLine                ; Zeiger auf Zeilenanfang im RAM setzen
; -------------------------------------------------------------------------
; Cursor horizontal move

CursHorMove:
        bcs     LE339
        jsr     LE574
        bcs     LE319
LE338:
        rts
; -------------------------------------------------------------------------
LE339:
        jsr     LE587
        bcs     LE338
        bne     LE321
        inc     CursLine
        bne     LE329

RVSOnOff:
        eor     #$80
        sta     rvsFlag
        rts
; -------------------------------------------------------------------------
; Clear/Home; bei zweifachem Tastendruck CRT-Size rücksetzen

do_ClearHome:
        bcc     LE34F
        jmp     ClrHome
; -------------------------------------------------------------------------
LE34F:
        cmp     LastPrtChar
        bne     LE357
        jsr     ResetCRTSize
LE357:
        jmp     Home
; -------------------------------------------------------------------------
do_tab:
        ldy     CursCol
        bcs     SetResetTab
LE35E:
        cpy     ScreenRight
        bcc     NextTab
        lda     ScreenRight
        sta     CursCol
        rts
; -------------------------------------------------------------------------
NextTab:
        iny
        jsr     ChkTabStop
        beq     LE35E
        sty     CursCol
        rts
; -------------------------------------------------------------------------
SetResetTab:
        jsr     ChkTabStop
        eor     FktTemp
        sta     TabStopTable,x
        rts
; -------------------------------------------------------------------------
LE37A:
        ldx     CursLine
        cpx     ScreenBot
        bcc     LE38F
        bit     ScrollFlag
        bpl     LE38B
        lda     ScreenTop
        sta     CursLine
        bcs     LE391
LE38B:
        jsr     LE3F6
        clc
LE38F:
        inc     CursLine
LE391:
        jmp     InitLine                ; Zeiger auf Zeilenanfang im RAM setzen
; -------------------------------------------------------------------------
; CR ausführen

do_CR:
        jsr     CurToEOL
        inx
        jsr     LE505
        ldy     ScreenLeft
        sty     CursCol
        jsr     LE37A
CancelIModes:
        lda     #$00
        sta     Insrt
        sta     rvsFlag
        sta     QuoteSw
        cmp     BellMode
        bne     LE3B3
        sta     sid+Volume
LE3B3:
        rts
; -------------------------------------------------------------------------
CopyCRTLine:
        lda     LineLSBTab,x
        sta     sedsal
        lda     LineMSBTab,x
        sta     sedsal+1
        jsr     SwitchSeg
LE3C1:
        lda     (sedsal),y
        sta     (CharPtr),y
        cpy     ScreenRight
        iny
        bcc     LE3C1
        jmp     SwitchOldSeg    ; Bank rückschalten
; -------------------------------------------------------------------------
LE3CD:
        ldx     LastCol
        bmi     LE3D7
        cpx     CursLine
        bcc     LE3D7
        inc     LastCol
LE3D7:
        ldx     ScreenBot
LE3D9:
        jsr     LE0CF
        ldy     ScreenLeft
        cpx     CursLine
        beq     LE3F0
        dex
        jsr     LE4F7
        inx
        jsr     LE503
        dex
        jsr     CopyCRTLine
        bcs     LE3D9
LE3F0:
        jsr     EraseLine               ; Zeile löschen
        jmp     LE512
; -------------------------------------------------------------------------
LE3F6:
        ldx     ScreenTop
LE3F8:
        inx
        jsr     LE4F7
        bcc     LE408
        cpx     ScreenBot
        bcc     LE3F8
        ldx     ScreenTop
        inx
        jsr     LE505
LE408:
        dec     CursLine
        bit     LastCol
        bmi     LE410
        dec     LastCol
LE410:
        ldx     ScreenTop
        cpx     sedt2
        bcs     LE418
        dec     sedt2
LE418:
        jsr     LE42D
        ldx     ScreenTop
        jsr     LE4F7
        php
        jsr     LE505
        plp
        bcc     LE42C
        bit     LogScrollFlag
        bmi     LE408
LE42C:
        rts
; -------------------------------------------------------------------------
LE42D:
        jsr     LE0CF
        ldy     ScreenLeft
        cpx     ScreenBot
        bcs     LE444
        inx
        jsr     LE4F7
        dex
        jsr     LE503
        inx
        jsr     CopyCRTLine
        bcs     LE42D
LE444:
        jsr     EraseLine               ; Zeile löschen
        ldx     #$FF
        ldy     #$FE
        jsr     LE480
        and     #$20
        bne     LE45F
LE452:
        nop
        nop
        dex
        bne     LE452
        dey
        bne     LE452
LE45A:
        sty     KeyBufIndex
LE45C:
        jmp     LE8F7
; -------------------------------------------------------------------------
LE45F:
        ldx     #$F7
        ldy     #$FF
        jsr     LE480
        and     #$10
        bne     LE45C
LE46A:
        jsr     LE480
        and     #$10
        beq     LE46A
LE471:
        ldy     #$00
        ldx     #$00
        jsr     LE480
        and     #$3F
        eor     #$3F
        beq     LE471
        bne     LE45A
LE480:
        php
        sei
        stx     tpi2+tpiPortA
        sty     tpi2+tpiPortB
        jsr     LE91E
        plp
        rts
; -------------------------------------------------------------------------
bell:
        lda     BellMode
        bne     LE4B9
        lda     #$0F
        sta     sid+Volume
        ldy     #$00
        sty     sid+Osc1+AtkDcy
        lda     #$0A
        sta     sid+Osc1+SusRel
        lda     #$30
        sta     sid+Osc1+FreqHi
        lda     #$60
        sta     sid+Osc3+FreqHi
        ldx     #$15
        stx     sid+Osc1+OscCtl
LE4B0:
        nop
        nop
        iny
        bne     LE4B0
        dex
        stx     sid+Osc1+OscCtl
LE4B9:
        rts
; -------------------------------------------------------------------------

ClearLastEntry:
        lda     CursCol
        pha
LE4BD:
        ldy     CursCol
        dey
        jsr     LE244
        cmp     #$2B
        beq     LE4CB
        cmp     #$2D
        bne     LE4D3
LE4CB:
        dey
        jsr     LE244
        cmp     #$05
        bne     LE4ED
LE4D3:
        cmp     #$05
        bne     LE4DB
        dey
        jsr     LE244
LE4DB:
        cmp     #$2E
        bcc     LE4ED
        cmp     #$2F
        beq     LE4ED
        cmp     #$3A
        bcs     LE4ED
        jsr     do_DEL
        jmp     LE4BD
; -------------------------------------------------------------------------
LE4ED:
        pla
        cmp     CursCol
        bne     LE4B9
        jmp     do_DEL
; -------------------------------------------------------------------------
LE4F5:
        ldx     CursLine
LE4F7:
        jsr     LE51E
        and     BitTable,x
        cmp     #$01
        jmp     LE50E
; -------------------------------------------------------------------------
LE501:
        ldx     CursLine
LE503:
        bcs     LE512
LE505:
        jsr     LE51E
        eor     #$FF
        and     BitTable,x
LE50C:
        sta     BitTable,x
LE50E:
        ldx     FktTemp
        rts
; -------------------------------------------------------------------------
LE512:
        bit     ScrollFlag
        bvs     LE4F7
        jsr     LE51E
        ora     BitTable,x
        bne     LE50C
LE51E:
        stx     FktTemp
        txa
        and     #$07
        tax
        lda     BitMapTab,x
        pha
        lda     FktTemp
        lsr     a
        lsr     a
        lsr     a
        tax
        pla
        rts
; -------------------------------------------------------------------------
CurToSOL:
        ldy     ScreenLeft
        sty     CursCol
LE536:
        jsr     LE4F5
        bcc     LE541
        dec     CursLine
        bpl     LE536
        inc     CursLine
LE541:
        jmp     InitLine                ; Zeiger auf Zeilenanfang im RAM setzen
; -------------------------------------------------------------------------
CurToEOL:
        lda     CursLine
        cmp     ScreenBot
        bcs     LE553
        inc     CursLine
        jsr     LE4F5
        bcs     CurToEOL
        dec     CursLine
LE553:
        jsr     InitLine                ; Zeiger auf Zeilenanfang im RAM setzen
GetCRTLineEnd:
        ldy     ScreenRight
        sty     CursCol
        bpl     LE561
LE55C:
        jsr     LE587
        bcs     LE571
LE561:
        jsr     GetChar         ; Zeichen vom Bildschirm holen
        cmp     #$20
        bne     LE571
        cpy     ScreenLeft
        bne     LE55C
        jsr     LE4F5
        bcs     LE55C
LE571:
        sty     LastLinePos
        rts
; -------------------------------------------------------------------------
LE574:
        pha
        ldy     CursCol
        cpy     ScreenRight
        bcc     LE582
        jsr     LE37A
        ldy     ScreenLeft
        dey
        sec
LE582:
        iny
        sty     CursCol
        pla
        rts
; -------------------------------------------------------------------------
LE587:
        ldy     CursCol
        dey
        bmi     LE590
        cpy     ScreenLeft
        bcs     LE59F
LE590:
        ldy     ScreenTop
        cpy     CursLine
        bcs     LE5A4
        dec     CursLine
        pha
        jsr     InitLine                ; Zeiger auf Zeilenanfang im RAM setzen
        pla
        ldy     ScreenRight
LE59F:
        sty     CursCol
        cpy     ScreenRight
        clc
LE5A4:
        rts
; -------------------------------------------------------------------------
SaveCursPos:
        ldy     CursCol
        sty     sedt1
        ldx     CursLine
        stx     sedt2
        rts
; -------------------------------------------------------------------------
do_INST_DEL:
        bcs     do_INST
do_DEL:
        jsr     LE339
        jsr     SaveCursPos
        bcs     LE5C7
LE5B8:
        cpy     ScreenRight
        bcc     LE5D2
        ldx     CursLine
        inx
        jsr     LE4F7
        bcs     LE5D2
        jsr     EraseChar
LE5C7:
        lda     sedt1
        sta     CursCol
        lda     sedt2
        sta     CursLine
        jmp     InitLine                ; Zeiger auf Zeilenanfang im RAM setzen
; -------------------------------------------------------------------------
LE5D2:
        jsr     LE574
        jsr     GetChar         ; Zeichen vom Bildschirm holen
        jsr     LE587
        jsr     PutChar
        jsr     LE574
        jmp     LE5B8
; -------------------------------------------------------------------------
do_INST:
        jsr     SaveCursPos
        jsr     CurToEOL
        cpx     sedt2
        bne     LE5F0
        cpy     sedt1
LE5F0:
        bcc     LE613
        jsr     LE62E
        bcs     LE619
LE5F7:
        jsr     LE587
        jsr     GetChar         ; Zeichen vom Bildschirm holen
        jsr     LE574
        jsr     PutChar
        jsr     LE587
        ldx     CursLine
        cpx     sedt2
        bne     LE5F7
        cpy     sedt1
        bne     LE5F7
        jsr     EraseChar
LE613:
        inc     Insrt
        bne     LE619
        dec     Insrt
LE619:
        jmp     LE5C7
; -------------------------------------------------------------------------
PrtDLRUN:
        bcc     LE62D
        sei
        ldx     #DLRunTextLen
        stx     KeyBufIndex
LE623:
        lda     DLRunText-1,x
        sta     Keyd-1,x
        dex
        bne     LE623
        cli
LE62D:
        rts
; -------------------------------------------------------------------------
LE62E:
        cpy     ScreenRight
        bcc     LE63D
        ldx     CursLine
        cpx     ScreenBot
        bcc     LE63D
        bit     ScrollFlag
        bmi     LE654
LE63D:
        jsr     InitLine                ; Zeiger auf Zeilenanfang im RAM setzen
        jsr     LE574
        bcc     LE654
        jsr     LE4F5
        bcs     LE653
        jsr     LED00
        sec
        bvs     LE654
        jsr     LE3CD
LE653:
        clc
LE654:
        rts
; -------------------------------------------------------------------------
do_ESC:
        jmp     (escvec)
; -------------------------------------------------------------------------
InsLine:
        jsr     LE3CD
        jsr     LE0C7
        inx
        jsr     LE4F7
        php
        jsr     LE501
        plp
        bcs     LE66C
        sec
        ror     LastCol
LE66C:
        rts
; -------------------------------------------------------------------------
DelLine:
        jsr     LE536
        lda     ScreenTop
        pha
        lda     CursLine
        sta     ScreenTop
        lda     LogScrollFlag
        pha
        lda     #$80
        sta     LogScrollFlag
        jsr     LE408
        pla
        sta     LogScrollFlag
        lda     ScreenTop
        sta     CursLine
        pla
        sta     ScreenTop
        sec
        ror     LastCol
        jmp     LE0C7
; -------------------------------------------------------------------------
EraToEOL:
        jsr     SaveCursPos
LE697:
        jsr     LE22C
        inc     CursLine
        jsr     InitLine                ; Zeiger auf Zeilenanfang im RAM setzen
        ldy     ScreenLeft
        jsr     LE4F5
        bcs     LE697
LE6A6:
        jmp     LE5C7
; -------------------------------------------------------------------------
EraToSOL:
        jsr     SaveCursPos
LE6AC:
        jsr     EraseChar
        cpy     ScreenLeft
        bne     LE6B8
        jsr     LE4F5
        bcc     LE6A6
LE6B8:
        jsr     LE587
        bcc     LE6AC
ScrollUp:
        jsr     SaveCursPos
        txa
        pha
        jsr     LE3F6
        pla
        sta     sedt2
        jmp     LE6A6
; -------------------------------------------------------------------------
ScrollDown:
        jsr     SaveCursPos
        jsr     LE4F5
        bcs     LE6D6
        sec
        ror     LastCol
LE6D6:
        lda     ScreenTop
        sta     CursLine
        jsr     LE3CD
        jsr     LE505
        jmp     LE6A6
; -------------------------------------------------------------------------
EnableScroll:
        clc
        .byte   $24
DisableScroll:
        sec
        lda     #$00
        ror     a
        sta     ScrollFlag
        rts
; -------------------------------------------------------------------------
        clc
        bcc     LE6F1
        sec
LE6F1:
        lda     #$00
        ror     a
        sta     LogScrollFlag
        rts
; -------------------------------------------------------------------------
do_funkey:
        sei
        dey
        bmi     LE6FF
        jmp     SetFunKey
; -------------------------------------------------------------------------
LE6FF:
        ldy     #$00
LE701:
        iny
        sty     FunKeyTmp
        dey
        lda     PgmKeySize,y
        beq     LE777
        sta     PgmKeyIndex
        jsr     LE949
        sta     PgmKeyPtr
        stx     PgmKeyPtr+1
        ldx     #$03
LE717:
        lda     ChrTxt,x
        jsr     bsout
        dex
        bpl     LE717
        ldx     #$2F
        lda     FunKeyTmp
        sec
LE726:
        inx
        sbc     #$0A
        bcs     LE726
        adc     #$3A
        cpx     #$30
        beq     LE737
        pha
        txa
        jsr     bsout
        pla
LE737:
        jsr     bsout
        ldy     #$00
        lda     #$2C
LE73E:
        jsr     bsout
        ldx     #$07
LE743:
        jsr     SwToPgmKeySeg   ; Auf Bank mit Funktionstastentexten schalten
        lda     (PgmKeyPtr),y
        jsr     SwitchOldSeg    ; Bank rückschalten
        cmp     #$0D
        beq     LE781
        cmp     #$8D
        beq     LE784
        cmp     #$22
        beq     LE787
        cpx     #$09
        beq     LE762
        pha
        lda     #$22
        jsr     bsout
        pla
LE762:
        jsr     bsout
        ldx     #$09
        iny
        cpy     PgmKeyIndex
        bne     LE743
        lda     #$22
        jsr     bsout
LE772:
        lda     #$0D
        jsr     bsout
LE777:
        ldy     FunKeyTmp
        cpy     #$14
        bne     LE701
        cli
        clc
        rts
; -------------------------------------------------------------------------
LE781:
#if K4AO | K4BO
        lda     #ChrStr13Txt-1
        .byte   $2C
LE784:
        lda     #ChrStr141Txt-1
        .byte   $2C
LE787:
	lda	#$0E
	pha
	jsr	LFF45
#else
        ldx     #ChrStr13Txt-1
        .byte   $2C
LE784:
        ldx     #ChrStr141Txt-1
        .byte   $2C
LE787:
        ldx     #ChrStr34Txt-1
        txa
        pha
        ldx     #ChrStrTxt-1
#endif

LE78D:
        lda     ChrTxt1,x
        beq     LE79C
        jsr     bsout
        dex
        bpl     LE78D
        pla
        tax
        bne     LE78D
LE79C:
        iny
        cpy     PgmKeyIndex
        beq     LE772
        lda     #$2B
        bne     LE73E


ChrTxt:
        .byte   " YEK"
ChrTxt1:
        .byte   "($RHC+",'"'
ChrStrTxt       = *-ChrTxt1
        .byte   $00
        .byte   ")31"
ChrStr13Txt     = *-ChrTxt1
        .byte   $00
        .byte   ")43"
ChrStr34Txt     = *-ChrTxt1
        .byte   $00
        .byte   ")141"
ChrStr141Txt    = *-ChrTxt1

; -------------------------------------------------------------------------
SetFunKey:
        pha
        tax
        sty     sedt1
        lda     ExecReg,x
        sec
        sbc     PgmKeySize,y
        sta     sedt2
        ror     FktTemp
        iny
        jsr     LE949
        sta     sedsal
        stx     sedsal+1
        ldy     #$14
        jsr     LE949
        sta     sedeal
        stx     sedeal+1
        ldy     FktTemp
        bpl     LE7F6
        clc
        sbc     PgmKeyEnd
        tay
        txa
        sbc     PgmKeyEnd+1
        tax
        tya
        clc
        adc     sedt2
        txa
        adc     #$00
        bcs     LE862
LE7F6:
        jsr     SwToPgmKeySeg   ; Auf Bank mit Funktionstastentexten schalten
LE7F9:
        lda     sedeal
        clc
        sbc     sedsal
        lda     sedeal+1
        sbc     sedsal+1
        bcc     LE82E
        ldy     #$00
        lda     FktTemp
        bpl     LE81C
        lda     sedeal
        bne     LE811
        dec     sedeal+1
LE811:
        dec     sedeal
        lda     (sedeal),y
        ldy     sedt2
        sta     (sedeal),y
        jmp     LE7F9
; -------------------------------------------------------------------------
LE81C:
        lda     (sedsal),y
        ldy     sedt2
        dec     sedsal+1
        sta     (sedsal),y
        inc     sedsal+1
        inc     sedsal
        bne     LE7F9
        inc     sedsal+1
        bne     LE7F9
LE82E:
        ldy     sedt1
        jsr     LE949
        sta     sedsal
        stx     sedsal+1
        ldy     sedt1
        pla
        pha
        tax
        lda     ExecReg,x
        sta     PgmKeySize,y
        tay
        beq     LE85E
        lda     IndReg,x
        sta     sedeal
        lda     $02,x
        sta     sedeal+1
LE84C:
        dey
        lda     $03,x
        sta     IndReg
        lda     (sedeal),y
        jsr     SwitchOldSeg    ; Bank rückschalten
        jsr     SwToPgmKeySeg   ; Auf Bank mit Funktionstastentexten schalten
        sta     (sedsal),y
        tya
        bne     LE84C
LE85E:
        jsr     SwitchOldSeg    ; Bank rückschalten
        clc
LE862:
        pla
        cli
        rts
; -------------------------------------------------------------------------
do_scnkey:
        ldy     #$FF
        sty     ModKey
        sty     NorKey
        iny
        sty     tpi2+tpiPortB
        sty     tpi2+tpiPortA
        jsr     LE91E
        and     #$3F
        eor     #$3F
        bne     LE87E
        jmp     LE8F3
; -------------------------------------------------------------------------
LE87E:
        lda     #$FF
        sta     tpi2+tpiPortA
        asl     a
        sta     tpi2+tpiPortB
        jsr     LE91E
        pha
        sta     ModKey
        ora     #$30
        bne     LE894
LE891:
        jsr     LE91E
LE894:
        ldx     #$05
LE896:
        lsr     a
        bcc     LE8A9
        iny
        dex
        bpl     LE896
        sec
        rol     tpi2+tpiPortB
        rol     tpi2+tpiPortA
        bcs     LE891
        pla
        bcc     LE8F3
LE8A9:
        sty     NorKey
        ldx     TastTab,y
        pla
        asl     a
        asl     a
        asl     a
        bcc     LE8C2
        bmi     LE8C5
        ldx     TastTabShiftNorm,y
        lda     GrafMode
        beq     LE8C5
        ldx     TastTabShiftGraph,y
        bne     LE8C5
LE8C2:
        ldx     TastTabCtrl,y
LE8C5:
        cpx     #$FF
        beq     LE8F5
        cpx     #$E0
        bcc     LE8D6
        tya
        pha
        jsr     LE927
        pla
        tay
        bcs     LE8F5
LE8D6:
        txa
        cpy     LastIndex
        beq     RepeatKey
        ldx     #$13
        stx     RepeatDelay
        ldx     KeyBufIndex
        cpx     #$09
        beq     LE8F3
        cpy     #$59
        bne     LE912
        cpx     #$08
        beq     LE8F3
        sta     Keyd,x
        inx
        bne     LE912
LE8F3:
        ldy     #$FF
LE8F5:
        sty     LastIndex
LE8F7:
        ldx     #$7F
        stx     tpi2+tpiPortA
        ldx     #$FF
        stx     tpi2+tpiPortB
        rts
; -------------------------------------------------------------------------
RepeatKey:
        dec     RepeatDelay
        bpl     LE8F7
        inc     RepeatDelay
        dec     RepeatCount
        bpl     LE8F7
        inc     RepeatCount
        ldx     KeyBufIndex
        bne     LE8F7
LE912:
        sta     Keyd,x
        inx
        stx     KeyBufIndex
        ldx     #$03
        stx     RepeatCount
        bne     LE8F5
LE91E:
        lda     tpi2+tpiPortC
        cmp     tpi2+tpiPortC
        bne     LE91E
        rts
; -------------------------------------------------------------------------
LE927:
        jmp     (funvec)                ; normalerweise ProcessFunKey
; -------------------------------------------------------------------------
; Funktionstasten behandeln

ProcessFunKey:
        cpy     LastIndex
        beq     LE947
        lda     KeyBufIndex
        ora     KeyIndex
        bne     LE947
        sta     PgmKeyIndex
        txa
        and     #$1F
        tay
        lda     PgmKeySize,y
        sta     KeyIndex
        jsr     LE949
        sta     PgmKeyPtr
        stx     PgmKeyPtr+1
LE947:
        sec
        rts
; -------------------------------------------------------------------------
LE949:
        lda     PgmKeyBuf
        ldx     PgmKeyBuf+1
LE94D:
        clc
        dey
        bmi     LE959
        adc     PgmKeySize,y
        bcc     LE94D
        inx
        bne     LE94D
LE959:
        rts
; -------------------------------------------------------------------------
ChkTabStop:
        tya
        and     #$07
        tax
        lda     BitMapTab,x
        sta     FktTemp
        tya
        lsr     a
        lsr     a
        lsr     a
        tax
        lda     TabStopTable,x
        bit     FktTemp
        rts
; -------------------------------------------------------------------------
ESCseq:
        and     #$7F
        sec
        sbc     #$41
        cmp     #$1A
        bcc     jmpESCseq
CancelESC:
        rts
; -------------------------------------------------------------------------
jmpESCseq:
        asl     a
        tax
        lda     ESCjmpTab+1,x
        pha
        lda     ESCjmpTab,x
        pha
        rts
; -------------------------------------------------------------------------
ESCjmpTab:
        .word   InsertOn-1              ; A
        .word   SetWinRUCur-1           ; B
        .word   InsertOff-1             ; C
        .word   DelLine-1               ; D
        .word   NonFlashCurs-1          ; E
        .word   FlashingCurs-1          ; F
        .word   BellOn-1                ; G
        .word   BellOff-1               ; H
        .word   InsLine-1               ; I
        .word   CurToSOL-1              ; J
        .word   CurToEOL-1              ; K
        .word   EnableScroll-1          ; L
        .word   DisableScroll-1         ; M
        .word   NormScreen-1            ; N
        .word   CancelIModes-1          ; O
        .word   EraToSOL-1              ; P
        .word   EraToEOL-1              ; Q
        .word   RVSScreen-1             ; R
        .word   SolidCurs-1             ; S
        .word   SetWinRU-1              ; T
        .word   UnderscCurs-1           ; U
        .word   ScrollUp-1              ; V
        .word   ScrollDown-1            ; W
        .word   CancelESC-1             ; X
        .word   NormCharSet-1           ; Y
        .word   AltCharSet-1            ; Z

; -------------------------------------------------------------------------
SetWinRU:
        clc
        .byte   $24
SetWinRUCur:
        sec
do_WinRuCur:                    ; Einsprung von CTRL mit vorbesetztem Carry
        ldx     CursCol
        lda     CursLine
        bcc     SetWinLO
LE9C2:
        sta     ScreenBot
        stx     ScreenRight
        rts
; -------------------------------------------------------------------------
ResetCRTSize:
        lda     #$18
        ldx     #$4F
        jsr     LE9C2
        lda     #$00
        tax
SetWinLO:
        sta     ScreenTop
        stx     ScreenLeft
        rts
; -------------------------------------------------------------------------
BellOn:
        lda     #$00
BellOff:
        sta     BellMode
        rts
; -------------------------------------------------------------------------
UnderscCurs:
        lda     #$0B
        bit     tpi2+tpiPortC
        bmi     LE9E8
        lda     #$06
        .byte   $2c
FlashingCurs:
        lda     #$60
LE9E8:
        ora     Config
        bne     LE9F3
SolidCurs:
        lda     #$F0
        .byte   $2C
NonFlashCurs:
        lda     #$0F
        and     Config
LE9F3:
        sta     Config
        rts
; -------------------------------------------------------------------------
RVSScreen:
        lda     #$20
        .byte   $2C
AltCharSet:
        lda     #$10
        ldx     #$0E
        stx     crtc+CAdrReg
        ora     crtc+CDataReg
        bne     LEA12
NormScreen:
        lda     #$DF
        .byte   $2C
NormCharSet:
        lda     #$EF
        ldx     #$0E
        stx     crtc+CAdrReg
        and     crtc+CDataReg
LEA12:
        sta     crtc+CDataReg
        and     #$30
        ldx     #$0C
        stx     crtc+CAdrReg
        sta     crtc+CDataReg
        rts
; -------------------------------------------------------------------------
InsertOff:
        lda     #$00
        .byte   $2C
InsertOn:
        lda     #$FF
        sta     InsertFlag
        rts
; -------------------------------------------------------------------------
TastTab:
        .byte   $E0,$1B,$09,$FF,$00,$01,$E1,$31
        .byte   $51,$41,$5A,$FF,$E2,$32,$57,$53
        .byte   $58,$43,$E3,$33,$45,$44,$46,$56
        .byte   $E4,$34,$52,$54,$47,$42,$E5,$35
        .byte   $36,$59,$48,$4E,$E6,$37,$55,$4A
        .byte   $4D,$20,$E7,$38,$49,$4B,$2C,$2E
        .byte   $E8,$39,$4F,$4C,$3B,$2F,$E9,$30
        .byte   $2D,$50,$5B,$27,$11,$3D,$5F,$5D
        .byte   $0D,$DE,$91,$9D,$1D,$14,$02,$FF
        .byte   $13,$3F,$37,$34,$31,$30,$12,$04
        .byte   $38,$35,$32,$2E,$8E,$2A,$39,$36
        .byte   $33,$30,$03,$2F,$2D,$2B,$0D,$FF
; -------------------------------------------------------------------------
TastTabShiftNorm:
        .byte   $EA,$1B,$89,$FF,$00,$01,$EB,$21
        .byte   $D1,$C1,$DA,$FF,$EC,$40,$D7,$D3
        .byte   $D8,$C3,$ED,$23,$C5,$C4,$C6,$D6
        .byte   $EE,$24,$D2,$D4,$C7,$C2,$EF,$25
        .byte   $5E,$D9,$C8,$CE,$F0,$26,$D5,$CA
        .byte   $CD,$A0,$F1,$2A,$C9,$CB,$3C,$3E
        .byte   $F2,$28,$CF,$CC,$3A,$3F,$F3,$29
        .byte   $2D,$D0,$5B,$22,$11,$2B,$5C,$5D
        .byte   $8D,$DE,$91,$9D,$1D,$94,$82,$FF
        .byte   $93,$3F,$37,$34,$31,$30,$92,$84
        .byte   $38,$35,$32,$2E,$0E,$2A,$39,$36
        .byte   $33,$30,$83,$2F,$2D,$2B,$8D,$FF
; -------------------------------------------------------------------------
TastTabShiftGraph:
        .byte   $EA,$1B,$89,$FF,$00,$01,$EB,$21
        .byte   $D1,$C1,$DA,$FF,$EC,$40,$D7,$D3
        .byte   $D8,$C0,$ED,$23,$C5,$C4,$C6,$C3
        .byte   $EE,$24,$D2,$D4,$C7,$C2,$EF,$25
        .byte   $5E,$D9,$C8,$DD,$F0,$26,$D5,$CA
        .byte   $CD,$A0,$F1,$2A,$C9,$CB,$3C,$3E
        .byte   $F2,$28,$CF,$D6,$3A,$3F,$F3,$29
        .byte   $2D,$D0,$5B,$22,$11,$2B,$5C,$5D
        .byte   $8D,$DE,$91,$9D,$1A,$94,$82,$FF
        .byte   $93,$3F,$37,$34,$31,$30,$92,$04
        .byte   $38,$35,$32,$2E,$0E,$2A,$39,$36
        .byte   $33,$30,$83,$2F,$2D,$2B,$8D,$FF
; -------------------------------------------------------------------------
TastTabCtrl:
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$A1
        .byte   $11,$01,$1A,$FF,$FF,$A2,$17,$13
        .byte   $18,$03,$FF,$A3,$05,$04,$06,$16
        .byte   $FF,$A4,$12,$14,$07,$02,$FF,$A5
        .byte   $A7,$19,$08,$0E,$FF,$BE,$15,$0A
        .byte   $0D,$FF,$FF,$BB,$09,$0B,$CE,$FF
        .byte   $FF,$BF,$0F,$0C,$DC,$FF,$FF,$AC
        .byte   $BC,$10,$CC,$A8,$FF,$A9,$DF,$BA
        .byte   $FF,$A6,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$B7,$B4,$B1,$B0,$AD,$FF,$B8
        .byte   $B5,$B2,$AE,$BD,$FF,$B9,$B6,$B3
        .byte   $DB,$FF,$FF,$AF,$AA,$AB,$FF,$FF
; -------------------------------------------------------------------------
DLRunText:
        .pet    'dL"*\r'
        .pet    'run\r'

        DLRunTextLen    = *-DLRunText

; -------------------------------------------------------------------------
LineLSBTab:
        .byte   $00,$50,$A0,$F0,$40,$90,$E0,$30
        .byte   $80,$D0,$20,$70,$C0,$10,$60,$B0
        .byte   $00,$50,$A0,$F0,$40,$90,$E0,$30
        .byte   $80
; -------------------------------------------------------------------------
LineMSBTab:
        .byte   $D0,$D0,$D0,$D0,$D1,$D1,$D1,$D2
        .byte   $D2,$D2,$D3,$D3,$D3,$D4,$D4,$D4
        .byte   $D5,$D5,$D5,$D5,$D6,$D6,$D6,$D7
        .byte   $D7
; -------------------------------------------------------------------------
WhiteSpaceTab:
        .word   do_CTRL-1
        .word   do_CTRL-1
        .word   do_CTRL-1
        .word   PrtDLRUN-1
        .word   ClearLastEntry-1
        .word   do_CTRL-1
        .word   do_CTRL-1
        .word   bell-1
        .word   do_CTRL-1
        .word   do_tab-1
        .word   do_CTRL-1
        .word   do_CTRL-1
        .word   do_CTRL-1
        .word   do_CR-1
        .word   SwitchCase-1
        .word   do_WinRuCur-1
        .word   do_CTRL-1
        .word   CursVertMove-1
        .word   RVSOnOff-1
        .word   do_ClearHome-1
        .word   do_INST_DEL-1
        .word   do_CTRL-1
        .word   do_CTRL-1
        .word   do_CTRL-1
        .word   do_CTRL-1
        .word   do_CTRL-1
        .word   do_CTRL-1
        .word   do_CTRL-1
        .word   do_CTRL-1
        .word   CursHorMove-1
        .word   do_CTRL-1
        .word   do_CTRL-1
; -------------------------------------------------------------------------
; Länge der Texte für die Vorbelegung der Funktionstasten 1-10

PgmKeyDefLen:
        .byte   5,4,6,6,5,6,4,9,7,5

        DefPgmKeyAnz    = *-PgmKeyDefLen

; -------------------------------------------------------------------------
; Texte für die Vorbelegung der Funktionstasten 1-10

PgmKeyDefTxt:
        .byte   "PRINT"
        .byte   "LIST"
        .byte   "DLOAD",'"'
        .byte   "DSAVE",'"'
        .byte   "DOPEN"
        .byte   "DCLOSE"
        .byte   "COPY"
        .byte   "DIRECTORY"
        .byte   "SCRATCH"
        .byte   "CHR$("

        PgmKeyTxtLen    = *-PgmKeyDefTxt

; -------------------------------------------------------------------------
BitMapTab:
        .byte   $80,$40,$20,$10,$08,$04,$02,$01
; -------------------------------------------------------------------------
; Konstanten zur Initialisierung des Video-Controllers

m6545tab:
#if K1 | K3B | K4AO | K4BO
	.byte   $6C
#endif
#if K4A
	.byte	$6B
#endif
        .byte       $50,$53,$0F,$19,$03,$19,$19
        .byte   $00,$0D,$60,$0D,$00,$00,$00,$00
        .byte   $00,$00,$7E,$50,$62,$0A,$1F,$06
        .byte   $19,$1C,$00,$07,$00,$07,$00,$00
        .byte   $00,$00,$00,$00,$7F,$50,$60,$0A
        .byte   $26,$01,$19,$1E,$00,$07,$00,$07
        .byte   $00,$00,$00,$00,$00,$00
#if K1 | K3B | K4AO | K4BO
	.byte	$65
#endif
#if K4A
	.byte	$2E
#endif
; -------------------------------------------------------------------------
#if K1 | K3B | K4AO | K4BO
        .fill    90 ($aa)
#endif
#if K4A
        .fill    $ECB0-* ($aa)
LECB0:  jsr     LE536
        lda     #$00
        rts
LECB6:  ora     $D0
        sta     $D0
        lda     $DD
        sta     $0398
        lda     $DF
        rts
LECC2:  bcc     LECC7
        .byte   $4C
LECC5:  .byte   $53
        .byte   $F9
LECC7:  php
        pha
        lda     $A0
        and     #$01
        beq     LECD9
        ldx     $9E
        jsr     chkout
        jsr     clrch
        ldx     $A6
LECD9:  pla
        plp
        rts
LECDC:  pha
        lda     #$0A
        sta     $D800
        lda     #$20
        sta     $D801
        pla
        rts
        .fill    $ED00-* ($aa)
#endif
; -------------------------------------------------------------------------
LED00:
        ldx     ScreenBot
        cpx     ScreenTop
        bne     LED08
        pla
        pla
LED08:
        bit     ScrollFlag
        rts
; -------------------------------------------------------------------------
        .fill    244 ($aa)
; -------------------------------------------------------------------------


; -------------------------------------------------------------------------
; Monitor-Einsprung nach Reset


MonitorC:
        jsr     do_ioinit
        jsr     do_restor
        jsr     jmp_scrinit

; -------------------------------------------------------------------------
; Monitor-Einsprung bei Warmstart

MonitorW:
        jsr     clrch                   ; offene Files schließen
        lda     #$5A                    ; Warmstartkennung
        ldx     #<MonitorC
        ldy     #>MonitorC
        jsr     do_setwst               ; und Adresse setzen
        cli
        lda     #%11000000              ; alle Msgs zugelassen
        sta     MsgFlag
        lda     #MoniTxt                ; '** MONITOR 1.0 **'
        sta     MoniCntr
        bne     LEE31                   ; unbedingter Sprung
; -------------------------------------------------------------------------
; Monitor-Einsprung bei Break (vom Break-Vektor)

Break:
        jsr     clrch                   ; offene Files schließen
        lda     #BreakTxt               ; 'BREAK'
        sta     MoniCntr
        cld
        ldx     #6-1                    ; Bytes
LEE2B:
        pla
        sta     PChighSave,x            ; Stackinhalt bei Break retten
        dex
        bpl     LEE2B
LEE31:
        lda     IndReg                  ; Ind. Segment retten
        sta     IndSegSave
        lda     IRQvec
        sta     IRQSaveLo
        lda     IRQvec+1
        sta     IRQSaveHi
        tsx
        stx     SPSave
        cli
        lda     #$08
        sta     MoniDevNr
        ldy     MoniCntr
        jsr     ChkPrtSysMsg
        lda     #'R'
        bne     MoniCmd
MoniErr:
        jsr     PrtQuestMark
        pla
        pla
MoniLoop:
        lda     #$C0
        sta     MsgFlag
        lda     #$00
        sta     FileNameAdrLo
        lda     #$02
        sta     FileNameAdrHi
        lda     #$0F
        sta     FileNameAdrSeg
        jsr     MoniPrompt
LEE69:
        jsr     basin
        cmp     #'.'
        beq     LEE69
        cmp     #' '
        beq     LEE69
        jmp     (usrcmd)
; -------------------------------------------------------------------------
MoniCmd:
        ldx     #$00
        stx     FileNameLen
        tay
        lda     #$EE
        pha
        lda     #$54
        pha
        tya
LEE83:
        cmp     MoniCmdTab,x
        bne     LEE98
        sta     SaveX
        lda     MoniCmdTab+1,x
        sta     Adr1
        lda     MoniCmdTab+2,x
        sta     Adr1+1
        jmp     (Adr1)
; -------------------------------------------------------------------------
LEE98:
        inx
        inx
        inx
        cpx     #$24
        bcc     LEE83
        ldx     #$00
LEEA1:
        cmp     #$0D
        beq     LEEB2
        cmp     #$20
        beq     LEEB2
        sta     $0200,x
        jsr     basin
        inx
        bne     LEEA1
LEEB2:
        sta     MoniCntr
        txa
        beq     LEED4
        sta     FileNameLen
        lda     #$40
        sta     MsgFlag
        lda     MoniDevNr
        sta     FirstAdr
        lda     #$0F
        sta     IndReg
        ldx     #$FF
        ldy     #$FF
        jsr     load
        bcs     LEED4
        lda     MoniCntr
        jmp     (StartAdrLow)
; -------------------------------------------------------------------------
LEED4:
        rts
; -------------------------------------------------------------------------
; Tabelle mit den Monitorkommandos + Sprungadressen

MoniCmdTab:
        .byte   ':'
        .word   MoniSetMem
        .byte   ';'
        .word   MoniSetRegs
        .byte   "R"
        .word   MoniPrtRegs
        .byte   "M"
        .word   MoniMemDump
        .byte   "G"
        .word   MoniGo
        .byte   "L"
        .word   MoniLoadSave
        .byte   "S"
        .word   MoniLoadSave
        .byte   "V"
        .word   MoniSetIndReg
        .byte   "@"
        .word   MoniIECStatus
        .byte   "Z"
        .word   runcopro
        .byte   "X"
        .word   MoniExit
        .byte   "U"
        .word   MoniIECDef

; -------------------------------------------------------------------------
MoniExit:
        pla
        pla
        sei
        jmp     (wstvec)
; -------------------------------------------------------------------------
LEEFF:
        lda     Adr1
        sta     PClowSave
        lda     Adr1+1
        sta     PChighSave
        rts
; -------------------------------------------------------------------------
LEF08:
        lda     #$B0
        sta     Adr1
        lda     #$00
        sta     Adr1+1
        lda     #$0F
        sta     IndReg
        lda     #$05
        rts
; -------------------------------------------------------------------------
MoniPromptCmd:
        pha
        jsr     MoniPrompt
        pla
        jsr     bsout
PrtSpace:
        lda     #$20
        .byte   $2C
PrtQuestMark:
        lda     #$3F
        jmp     bsout
; -------------------------------------------------------------------------
MoniPrompt:
        lda     #$0D
        jsr     bsout
PrtPoint:                       ; Nur für Moni (extern)
        lda     #$2E
        jmp     bsout
; -------------------------------------------------------------------------
RegTxt:
        .byte   $0d
        .byte   "   PC  IRQ  SR AC XR YR SP"

RegTxtLen       = *-RegTxt
; -------------------------------------------------------------------------
; Ausgabe der Werte der Prozessor-Register nach dem BRK

MoniPrtRegs:
        ldx     #$00
LEF4E:
        lda     RegTxt,x
        jsr     bsout
        inx
        cpx     #RegTxtLen
        bne     LEF4E
        lda     #$3b            ; // FIXME: ';'
        jsr     MoniPromptCmd
        ldx     PChighSave
        ldy     PClowSave
        jsr     PrtHex2Asc16
        jsr     PrtSpace
        ldx     IRQSaveHi
        ldy     IRQSaveLo
        jsr     PrtHex2Asc16
        jsr     LEF08
PrtBytes:
        sta     MoniCntr
        ldy     #$00
        sty     FileNameLen
LEF78:
        jsr     PrtSpace
        lda     (Adr1),y
        jsr     PrtHex2Asc8
        inc     Adr1
        bne     LEF8A
        inc     Adr1+1
        bne     LEF8A
        dec     FileNameLen
LEF8A:
        dec     MoniCntr
        bne     LEF78
        rts
; -------------------------------------------------------------------------
MoniMemDump:
        jsr     LF040
        jsr     XchgAdr1esAdr2
        jsr     GetAdr1
        bcc     LEFA2
        lda     Adr2
        sta     Adr1
        lda     Adr2+1
        sta     Adr1+1
LEFA2:
        jsr     XchgAdr1esAdr2
LEFA5:
        jsr     ChkStopKey
        beq     LEFCA
        lda     #$3A
        jsr     MoniPromptCmd
        ldx     Adr1+1
        ldy     Adr1
        jsr     PrtHex2Asc16
        lda     #$10
        jsr     PrtBytes
        lda     FileNameLen
        bne     LEFCA
        sec
        lda     Adr2
        sbc     Adr1
        lda     Adr2+1
        sbc     Adr1+1
        bcs     LEFA5
LEFCA:
        rts
; -------------------------------------------------------------------------
MoniSetRegs:
        jsr     LF040
        jsr     LEEFF
        jsr     LF040
        lda     Adr1
        sta     IRQSaveLo
        lda     Adr1+1
        sta     IRQSaveHi
        jsr     LEF08
        bne     LEFFA
MoniSetIndReg:
        jsr     LF03A
        cmp     #$10
        bcs     LF047
        sta     IndReg
        rts
; -------------------------------------------------------------------------
MoniIECDef:
        jsr     LF03A
        cmp     #$20
        bcs     LF047
        sta     MoniDevNr
        rts
; -------------------------------------------------------------------------
MoniSetMem:
        jsr     LF040
        lda     #$10
LEFFA:
        sta     MoniCntr
LEFFC:
        jsr     GetAsc2Hex8
        bcs     LF00F
        ldy     #$00
        sta     (Adr1),y
        inc     Adr1
        bne     LF00B
        inc     Adr1+1
LF00B:
        dec     MoniCntr
        bne     LEFFC
LF00F:
        rts
; -------------------------------------------------------------------------
MoniGo:
        jsr     BasinChkCr
        beq     LF01B
        jsr     LF040
        jsr     LEEFF
LF01B:
        ldx     SPSave
        txs
        sei
        lda     IRQSaveHi
        sta     IRQvec+1
        lda     IRQSaveLo
        sta     IRQvec
        lda     IndSegSave
        sta     IndReg
        ldx     #$00
LF02F:
        lda     PChighSave,x
        pha
        inx
        cpx     #$06
        bne     LF02F
        jmp     LFCA5
; -------------------------------------------------------------------------
LF03A:
        jsr     GetAsc2Hex8
        bcs     LF045
LF03F:
        rts
; -------------------------------------------------------------------------
LF040:
        jsr     GetAdr1
        bcc     LF03F
LF045:
        pla
        pla
LF047:
        jmp     MoniErr
; -------------------------------------------------------------------------
MoniLoadSave:
        ldy     #$01
        sty     FirstAdr
        dey
        lda     #$FF
        sta     Adr1
        sta     Adr1+1
        lda     IndReg
        sta     MoniTmp
        lda     #$0F
        sta     IndReg
LF05D:
        jsr     BasinChkCr
        beq     LF07E
        cmp     #$20
        beq     LF05D
        cmp     #$22
LF068:
        bne     LF047
LF06A:
        jsr     BasinChkCr
        beq     LF07E
        cmp     #$22
        beq     LF090
        sta     (FileNameAdrLo),y
        inc     FileNameLen
        iny
        cpy     #$10
        beq     LF047
        bne     LF06A
LF07E:
        lda     SaveX
        cmp     #$4C
        bne     LF068
        lda     MoniTmp
        and     #$0F
        ldx     Adr1
        ldy     Adr1+1
        jmp     load
; -------------------------------------------------------------------------
LF090:
        jsr     BasinChkCr
        beq     LF07E
        cmp     #$2C
LF097:
        bne     LF068
        jsr     LF03A
        sta     FirstAdr
        jsr     BasinChkCr
        beq     LF07E
        cmp     #$2C
LF0A5:
        bne     LF097
        jsr     LF03A
        cmp     #$10
        bcs     LF0F3
        sta     MoniTmp
        sta     StartAdrSeg
        jsr     LF040
        lda     Adr1
        sta     StartAdrLow
        lda     Adr1+1
        sta     StartAdrHi
        jsr     BasinChkCr
        beq     LF07E
        cmp     #$2C
        bne     LF0F3
        jsr     LF03A
        cmp     #$10
        bcs     LF0F3
        sta     EndAdrSeg
        jsr     LF040
        lda     Adr1
        sta     EndAdrLow
        lda     Adr1+1
        sta     EndAdrHi
LF0DA:
        jsr     basin
        cmp     #$20
        beq     LF0DA
        cmp     #$0D
LF0E3:
        bne     LF0A5
        lda     SaveX
        cmp     #$53
        bne     LF0E3
        ldx     #$99
        ldy     #$96
        jmp     save
; -------------------------------------------------------------------------
LF0F3:
        jmp     MoniErr
; -------------------------------------------------------------------------
PrtHex2Asc16:
        txa
        jsr     PrtHex2Asc8
        tya
PrtHex2Asc8:
        pha
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        jsr     LF107
        tax
        pla
        and     #$0F
LF107:
        clc
        adc     #$F6
        bcc     LF10E
        adc     #$06
LF10E:
        adc     #$3A
        jmp     bsout
; -------------------------------------------------------------------------
XchgAdr1esAdr2:
        ldx     #$02
LF115:
        lda     IRQSaveLo,x
        pha
        lda     Adr1+1,x
        sta     IRQSaveLo,x
        pla
        sta     Adr1+1,x
        dex
        bne     LF115
        rts
; -------------------------------------------------------------------------
GetAdr1:
        jsr     GetAsc2Hex8
        bcs     LF12F
        sta     Adr1+1
        jsr     GetAsc2Hex8
        sta     Adr1
LF12F:
        rts
; -------------------------------------------------------------------------
GetAsc2Hex8:
        lda     #$00
        sta     bad
        jsr     BasinChkCr
        beq     LF153
        cmp     #$20
        beq     GetAsc2Hex8
        jsr     Asc2HexNibble
        asl     a
        asl     a
        asl     a
        asl     a
        sta     bad
        jsr     BasinChkCr
        beq     LF153
        jsr     Asc2HexNibble
        ora     bad
LF153:
        rts
; -------------------------------------------------------------------------
Asc2HexNibble:
        cmp     #$3A
        php
        and     #$0F
        plp
        bcc     LF15E
        adc     #$08
LF15E:
        rts
; -------------------------------------------------------------------------
BasinChkCr:
        jsr     basin
        cmp     #$0D
        rts
; -------------------------------------------------------------------------
MoniIECStatus:
        lda     #$00
        sta     Status
        sta     FileNameLen
        ldx     MoniDevNr
        ldy     #$0F
        jsr     do_setlfs
        clc
        jsr     open
        bcs     LF1BA
        jsr     BasinChkCr
        beq     LF19A
        pha
        ldx     #$00
        jsr     chkout
        pla
        bcs     LF1BA
        bcc     LF18B
LF188:
        jsr     basin
LF18B:
        cmp     #$0D
        php
        jsr     bsout
        lda     Status
        bne     LF1B6
        plp
        bne     LF188
        beq     LF1BA
LF19A:
        jsr     MoniPrompt
        ldx     #$00
        jsr     chkin
        bcs     LF1BA
LF1A4:
        jsr     BasinChkCr
        php
        jsr     bsout
        lda     Status
        and     #$BF
        bne     LF1B6
        plp
        bne     LF1A4
        beq     LF1BA
LF1B6:
        pla
        jsr     DevNotPresent
LF1BA:
        jsr     clrch
        lda     #$00
        clc
        jmp     close
; -------------------------------------------------------------------------
; Betriebssystem-Meldungen

Messages:
        IOErrorTxt      = *-Messages
        .byte   $0D, "I/O ERROR #"^
        SearchingTxt    = *-Messages
        .byte   $0D, "SEARCHING "^
        ForTxt          = *-Messages
        .byte   "FOR "^
        LoadingTxt      = *-Messages
        .byte   $0D, "LOADING"^
        SavingTxt       = *-Messages
        .byte   $0D, "SAVING "^
        VerifyingTxt    = *-Messages
        .byte   $0d, "VERIFYING"^
        FoundTxt        = *-Messages
        .byte   $0d, "FOUND "^
        OKTxt           = *-Messages
        .byte   $0d, "OK", $8d                  ; FIXME: CR + $80
        MoniTxt         = *-Messages
        .byte   $0d, "** MONITOR 1.0 **", $8d   ; FIXME: CR + $80
        BreakTxt        = *-Messages
        .byte   $0d, "BREAK"^

; -------------------------------------------------------------------------
; Bedingte Ausgabe der System-Meldungen

ChkPrtSysMsg:
        bit     MsgFlag
        bpl     LF22E
PrtSysMsg:
        lda     Messages,y
        php
        and     #$7F
        jsr     bsout
        iny
        plp
        bpl     PrtSysMsg
LF22E:
        clc
        rts
; -------------------------------------------------------------------------
; Send TALK

do_talk:
        ora     #%01000000      ; TALK cmd: $40..$5e
        bne     LIST1
; -------------------------------------------------------------------------
; Send LISTEN

do_listen:
        ora     #%00100000      ; LISTEN cmd: $20..$3e
LIST1:
        pha                     ; save talk or listen bit
        lda     #$3F
        sta     tpi1+tpiDDRA    ; EOI,DAV,ATN,REN,TE,DC: out, NRFD,NDAC: in
        lda     #$FF
        sta     cia+PortA       ; release data lines
        sta     cia+DDRA        ; data lines as output
        lda     #$FA
        sta     tpi1+tpiPortA   ; DC=0; REN=0
        lda     C3PO            ; Get IEEE flags
        bpl     TALI_20         ; branch if data in buffer

        lda     tpi1+tpiPortA
        and     #%11011111
        sta     tpi1+tpiPortA   ; Set EOI (bit 5) low

        lda     BSOUR           ; Get byte to send
        jsr     TBYTE           ; Transmit last character

        lda     C3PO            ; Clear byte in buffer flag
        and     #%01111111
        sta     C3PO

        lda     tpi1+tpiPortA   ; Set EOI (bit 5) high
        ora     #%00100000
        sta     tpi1+tpiPortA

TALI_20:
        lda     tpi1+tpiPortA   ; Set ATN (bit 3) low
        and     #%11110111
        sta     tpi1+tpiPortA

        pla                     ; Restore TALK/LISTEN address
        jmp     TBYTE

; -------------------------------------------------------------------------
; Send secondary address after LISTEN

do_second:
        jsr     TBYTE
SCATN:
        lda     tpi1+tpiPortA
        ora     #%00001000      ; Set ATN (bit 3) high
        sta     tpi1+tpiPortA
        rts
; -------------------------------------------------------------------------
; TALK secondary address

do_tksa:
        jsr     TBYTE           ; Send secondary address
TKATN:
        lda     #%00111001      ; Set NRFD,NDAC,TE,REN low
        and     tpi1+tpiPortA

SETLNS:                         ; Exit entry for UNTALK/UNLISTEN
        sta     tpi1+tpiPortA   ; Set control lines for input
                                ; This is a BUG: ATN is also set to input
        lda     #%11000111      ; NRFD,NDAC,REN,TC,DC: out, EOI,DAV,ATN: in
        sta     tpi1+tpiDDRA
        lda     #$00
        sta     cia+DDRA        ; Set data lines for receive
        beq     SCATN           ; Branch always

; -------------------------------------------------------------------------
; Buffered output to IEEE-488

NCIOUT:
        pha                     ; Save data
        lda     C3PO            ; Get IEEE flags
        bpl     CI1             ; Branch if no data in buffer
        lda     BSOUR           ; Get data from buffer
        jsr     TBYTE           ; Transmit data
        lda     C3PO
CI1:
        ora     #%10000000      ; Set data in buffer flag
        sta     C3PO

        pla                     ; Get new data
        sta     BSOUR
        rts

; -------------------------------------------------------------------------
; Send UNTALK command on IEEE-488 bus

NUNTLK:
        lda     #$5F            ; UNTALK cmd
        bne     UNLS1           ; branch always

NUNLSN:
        lda     #$3F            ; UNLISTEN cmd
UNLS1:
        jsr     LIST1           ; Send it

; Set for receive all lines high
#if K1 | K3B | K4AO | K4BO
        lda     #%11111001      ; NRFD,NDAC,EOI,DAV,ATN,DC: high; REN,TE: low
#endif
#if K4A
        lda     #%11111000      ; NRFD,NDAC,EOI,DAV,ATN: high; REN,TE,DC: low
#endif
        jmp     SETLNS          ; Go setup proper exit state

; -------------------------------------------------------------------------
; TBYTE -- output byte onto IEEE bus
;
; Entry A = data byte to be output
;
; Uses A register
; 1 byte of stack space

TBYTE:
        eor     #$FF            ; Invert data
        sta     cia+PortA

        lda     tpi1+tpiPortA
        ora     #%00010010      ; Enable talk mode (TE=1), set DAV high
        sta     tpi1+tpiPortA

        bit     tpi1+tpiPortA   ; Test NRFD & NDAC
        bvc     TBY2            ; Branch if either NRFD or NDAC low --> ok
        bpl     TBY2
        lda     #$80            ; Set NO-DEVICE bit in status
        jsr     OrStatus
        bne     TBY7            ; Branch always
TBY2:
        lda     tpi1+tpiPortA
        bpl     TBY2            ; Loop until NRFD high

        and     #%11101111      ; Set DAV low
        sta     tpi1+tpiPortA
TBY3:
        jsr     SetTimB32ms     ; Set timeout
        bcc     TBY4            ; Branch always
                                ; Carry clear means first time through
TBY3T:
        sec                     ; Carry set is second time
TBY4:
        bit     tpi1+tpiPortA
        bvs     TBY6            ; Branch if NDAC high

        lda     cia+IntCtrReg
        and     #%00000010      ; Timer B position (CIA)
        beq     TBY4            ; Branch if no timeout

        lda     TimOut          ; Timeout selection flag
        bmi     TBY3            ; no, try again
        bcc     TBY3T           ; Wait full 64us

        lda     #$01
        jsr     OrStatus        ; Set write timeout flag in status

TBY6:
        lda     tpi1+tpiPortA
        ora     #%00010000      ; Set DAV high
        sta     tpi1+tpiPortA
TBY7:
        lda     #$FF            ; Release data bus
        sta     cia+PortA
        rts
; -------------------------------------------------------------------------
; RBYTE -- input byte from IEEE bus
;
; Uses A register
; 1 byte of stack space
;
; Exit A = input data byte
;
NACPTR:
NRBYTE:
        lda     tpi1+tpiPortA
        and     #%10111001      ; Set TE,REN,NDAC low (TE=0: listen mode)
#if K1 | K3B | K4AO | K4BO
        ora     #%10000001      ; Set DC,NRFD high: say: ready for data
#endif
#if K4A
        ora     #$80            ; SET NRFD high: say ready for data
#endif
        sta     tpi1+tpiPortA

RBY1:
        jsr     SetTimB32ms     ; Return carry clear for CBM-II
        bcc     RBY2            ; Carry clear is first time trough
RBY1T:
        sec                     ; Carry set is second time trough
RBY2:
        lda     tpi1+tpiPortA
        and     #%00010000      ; Mask DAV bit
        beq     RBY4            ; Branch if data available (DAV low)

        lda     cia+IntCtrReg
        and     #%00000010      ; Timer B position (CIA)
        beq     RBY2            ; Branch if no timeout
        lda     TimOut          ; Timeout selection flag
        bmi     RBY1            ; no, try again
        bcc     RBY1T           ; go trough twice

        lda     #%00000010      ; Set read timeout bit in status
        jsr     OrStatus

        lda     tpi1+tpiPortA
        and     #%00111101      ; Set NRFD,NDAC,TE low
        sta     tpi1+tpiPortA

        lda     #$0D            ; Return null input = carriage return
        rts

RBY4:
        lda     tpi1+tpiPortA
        and     #%01111111      ; Set NRFD low: say not ready for data
        sta     tpi1+tpiPortA

        and     #%00100000      ; Mask EOI bit
        bne     RBY5            ; branch if EOI high
        lda     #%01000000      ; Set EOI bit in status
        jsr     OrStatus
RBY5:
        lda     cia+PortA       ; Read data lines from IEEE bus
        eor     #$FF            ; Invert data bits
        pha                     ; Save data on stack
        lda     tpi1+tpiPortA
        ora     #%01000000      ; Set NDAC high: say data accepted
        sta     tpi1+tpiPortA
RBY7:
        lda     tpi1+tpiPortA   ; Get IEEE control lines
        and     #%00010000      ; Mask DAV
        beq     RBY7            ; Wait without timeout for DAV high

        lda     tpi1+tpiPortA
        and     #%10111111      ; Set NDAC low
        sta     tpi1+tpiPortA

        pla                     ; Restore data from stack
        rts                     ; and return in A

; -------------------------------------------------------------------------
; Set up 6226 timer B to 32.64 ms and start timer

SetTimB32ms:
#if (MHZ==2)
        lda     #$FF            ; 255*256*0.5 us
#else
#if (MHZ==1)
        lda     #$80            ; 127*256*0.5 us
#else
#error MHZ out of range
#endif
#endif
        sta     cia+TimBHi      ; as MSB, LSB = 0
        lda     #$11            ; turn on timer continuous in case
        sta     cia+CtrlB       ; of other IRQs
        lda     cia+IntCtrReg   ; clear interrupt
        clc                     ; Mark first time
        rts
; -------------------------------------------------------------------------





        jmp     IllDeviceNr
; -------------------------------------------------------------------------
OpenRS232:
        jsr     LF42E           ; RS232 Status prüfen
        ldy     #$00
LF386:
        cpy     FileNameLen     ; Länge des Filenamens = 0 ?
        beq     LF395
        jsr     LFE92           ; Byte von Filename holen
        sta     m6551Ctrl,y     ; merken
        iny
        cpy     #$04            ; 4 Stück müssen's sein
        bne     LF386
LF395:
        lda     m6551Ctrl       ; Command und Control-Register belegen
        sta     acia+ACtrlReg
        lda     m6551Cmd
        and     #%11110010
        ora     #%00000010      ; Receiver Interrupt enable setzen
        sta     acia+ACmdReg
        clc
        lda     SecondAdr
        and     #$02            ; Inputfile ?
        beq     LF3C1           ; nein: Skip
        lda     rs232tail
        sta     rs232head       ; Anzahl der Zeichen im Puffer ist 0
        lda     rs232BufPtrSeg
        and     #$F0            ; schon Ram reserviert ?
        beq     LF3C1           ; ja: Skip
        jsr     do_GetMem256    ; Nein: 256 Bytes Puffer reservieren
        sta     rs232BufPtrSeg  ; ... und Adresse eintragen
        stx     rs232BufPtr
        sty     rs232BufPtr+1
LF3C1:
#if K1 | K3B | K4AO | K4BO
        bcc     LF3C6           ; Fehlerfrei
        jmp     IOError         ; ... oder mit Fehler
#endif
#if K4A
        jmp     LECC2
        nop
        nop
#endif
; -------------------------------------------------------------------------
LF3C6:
        rts
; -------------------------------------------------------------------------
; Commodore-ASCII nach echtem ASCII wandeln

Com2Asc:
        cmp     #'A'
        bcc     LF3DB
        cmp     #'Z'+1
        bcs     LF3D1
        ora     #$20
LF3D1:
        cmp     #'A'+$80
        bcc     LF3DB
        cmp     #'Z'+1+$80
        bcs     LF3DB
        and     #$7F
LF3DB:
        rts
; -------------------------------------------------------------------------
; ASCII nach Commodore-ASCII wandeln

Asc2Com:
        cmp     #'A'
        bcc     LF3F0
        cmp     #'Z'+1
        bcs     LF3E6
        ora     #$80
LF3E6:
        cmp     #'a'
        bcc     LF3F0
        cmp     #'z'+1
        bcs     LF3F0
        and     #$DF
LF3F0:
        rts
; -------------------------------------------------------------------------
; Setze RS232 Command-Register: transmit on, disable interrupts, enable receiver

LF3F1:
        lda     acia+ACmdReg
        ora     #%00001001
        and     #%11111011      ; transmit without interrupt
        sta     acia+ACmdReg
        rts
; -------------------------------------------------------------------------
; Platz im Speicher unterhalb MemTop reservieren, Pointer entsprechend setzen
; und Adresse freier Speicher zurück. Carry wenn Fehler.
; Input:  yr/xr : benötigter Speicher
; Output: ac/yr/xr : Pointer auf Speicher

do_GetMem256:
        ldx     #$00
        ldy     #$01            ; Default: 256 Bytes
do_GetMem:
        txa
        sec
        eor     #$FF
        adc     SysMemTop
        tax
        tya
        eor     #$FF
        adc     SysMemTop+1
        tay
        lda     SysMemTop+2
        bcs     LF41A
        lda     #$FF
LF416:
        ora     #$40
        sec
        rts
; -------------------------------------------------------------------------
LF41A:
        cpy     UsrMemTop+1
        bcc     LF416
        bne     LF426
        cpx     UsrMemTop
        bcc     LF416
LF426:
        stx     SysMemTop
        sty     SysMemTop+1
        clc
        rts
; -------------------------------------------------------------------------
; RS232 DSR- und DCD-Status holen und merken

LF42E:
        php
        sei
        lda     acia+AStatusReg
        and     #%01100000
        sta     rs232status             ; merken
        sta     dcddsr
        plp
        rts
; -------------------------------------------------------------------------
do_getin:
        lda     DefInpDev
        bne     LF44D
        lda     KeyBufIndex
        ora     KeyIndex
        beq     LF49A
        sei
        jsr     jmp_GetKey
        clc
        rts
; -------------------------------------------------------------------------
LF44D:
        cmp     #$02
        beq     GetIn_RS232
        jmp     basin
; -------------------------------------------------------------------------
GetIn_RS232:
        sty     XSave
        stx     SaveX                   ; Register retten
        ldy     rs232head               ; Ringpufferzeiger
        cpy     rs232tail               ; ... Zeichen da ?
        bne     LF478                   ; ja : skip
        lda     acia+ACmdReg            ; Cmd register holen
        and     #%11111101              ; Receiver-Int. sperren
        ora     #$01                    ; Enable Receiver (-DTR low)
        sta     acia+ACmdReg            ; wieder setzen
        lda     rs232status             ; Status holen
        ora     #%00010000              ; Flag für Eingabepuffer leer
        sta     rs232status
        lda     #$00                    ; 0 rückgeben, kein Zeichen
        beq     LF494                   ; unbedingter Sprung

; Zeichen war da:

LF478:
        lda     rs232status             ; Status holen
        and     #%11101111              ; Flag für Puffer leer rücksetzen
        sta     rs232status
        ldx     IndReg                  ; Ind. Segment retten
        lda     rs232BufPtrSeg
        sta     IndReg
        lda     (rs232BufPtr),y         ; Byte aus Puffer holen
        stx     IndReg                  ; Ind. Segmetn rücksetzen
        inc     rs232head               ; Ringpufferzeiger anpassen
        bit     SecondAdr               ; Wandlung ASCII nach Commodore
        bpl     LF494                   ; .. wenn Bit 7 der Sekundär-
        jsr     Asc2Com                 ; .. adresse gesetzt
LF494:
        ldy     XSave                   ; alte Registerinhalte
        ldx     SaveX
LF49A:
        clc                             ; Ende
        rts
; -------------------------------------------------------------------------
do_basin:
        lda     DefInpDev
        bne     LF4AB
        lda     CursCol
        sta     LastLine
        lda     CursLine
        sta     LastCol
        jmp     LF4B5
; -------------------------------------------------------------------------
LF4AB:
        cmp     #$03
        bne     LF4BA
#if K1 | K3B
        sta     crsw
        lda     ScreenRight
#endif
#if K4A
        jsr     LECB6
        nop
#endif
#if K4AO | K4BO
        jsr     LFF3E
        nop
#endif
        sta     LastLinePos
LF4B5:
        jsr     jmp_basin_crt
        clc
        rts
; -------------------------------------------------------------------------
LF4BA:
        bcs     LF4C3
        cmp     #$02
        beq     Basin_RS232
        jsr     LFE5A
LF4C3:
        lda     Status
        beq     LF4CB
LF4C7:
        lda     #$0D
LF4C9:
        clc
LF4CA:
        rts
; -------------------------------------------------------------------------
LF4CB:
        jsr     acptr
        clc
        rts
; -------------------------------------------------------------------------
Basin_RS232:
        jsr     getin
        bcs     LF4CA
        cmp     #$00
        bne     LF4C9
        lda     rs232status
        and     #$10
        beq     LF4C9
        lda     rs232status
        and     #$60
        bne     LF4C7
        jsr     ChkStopKey
        bne     Basin_RS232
        sec
        rts
; -------------------------------------------------------------------------
do_bsout:
        pha
        lda     DefOutDev
        cmp     #$03
        bne     LF4FB
        pla
        jsr     jmp_bsout_crt
        clc
        rts
; -------------------------------------------------------------------------
LF4FB:
        bcc     LF503
        pla
        jsr     ciout
        clc
        rts
; -------------------------------------------------------------------------
LF503:
        cmp     #$02
        beq     LF511
        pla
        jsr     LFE5A
LF50B:
        pla
        bcc     LF510
        lda     #$00
LF510:
        rts
; -------------------------------------------------------------------------
LF511:
        stx     t1
        sty     t2
        lda     rs232status
        and     #$60
        bne     LF540
        pla
        bit     SecondAdr
        bpl     LF526
        jsr     Com2Asc
LF526:
        sta     acia+ADataReg
        pha
LF52A:
        lda     rs232status
        and     #$60
        bne     LF540
        lda     acia+AStatusReg
        and     #$10
        bne     LF540
        jsr     ChkStopKey
        bne     LF52A
        sec
        bcs     LF50B
LF540:
        pla
        ldx     t1
        ldy     t2
        clc
        rts
; -------------------------------------------------------------------------
do_chkin:
        jsr     LF63E
        beq     LF551
        jmp     FileNotOpen
; -------------------------------------------------------------------------
LF551:
        jsr     LF650
        lda     FirstAdr
        beq     LF586
        cmp     #$03
        beq     LF586
        bcs     LF58A
        cmp     #$02
        bne     LF580
        lda     SecondAdr
        and     #$02
        beq     LF583
        and     acia+ACmdReg
        beq     LF57C
        eor     #$FF
        and     acia+ACmdReg
        ora     #$01
        pha
        jsr     LF42E
        pla
        sta     acia+ACmdReg
LF57C:
        lda     #$02
        bne     LF586
LF580:
        jsr     LFE5A
LF583:
        jmp     NotInputFile
; -------------------------------------------------------------------------
LF586:
        sta     DefInpDev
        clc
        rts
; -------------------------------------------------------------------------
LF58A:
        tax
        jsr     talk
        lda     SecondAdr
        bpl     LF598
        jsr     TKATN
        jmp     LF59B
; -------------------------------------------------------------------------
LF598:
        jsr     tksa
LF59B:
        txa
        bit     Status
        bpl     LF586
        jmp     DevNotPresent
; -------------------------------------------------------------------------
do_chkout:
        jsr     LF63E
        beq     LF5AB
        jmp     FileNotOpen
; -------------------------------------------------------------------------
LF5AB:
        jsr     LF650
        lda     FirstAdr
        bne     LF5B5
LF5B2:
        jmp     NotOutputFile
; -------------------------------------------------------------------------
LF5B5:
        cmp     #$03
        beq     LF5D1
        bcs     LF5D5
        cmp     #$02
        bne     LF5CE
        lda     SecondAdr
        lsr     a
        bcc     LF5B2
        jsr     LF42E
        jsr     LF3F1
        lda     #$02
        bne     LF5D1
LF5CE:
        jsr     LFE5A
LF5D1:
        sta     DefOutDev
        clc
        rts
; -------------------------------------------------------------------------
LF5D5:
        tax
        jsr     listen
        lda     SecondAdr
        bpl     LF5E2
        jsr     SCATN
        bne     LF5E5
LF5E2:
        jsr     second
LF5E5:
        txa
        bit     Status
        bpl     LF5D1
        jmp     DevNotPresent
; -------------------------------------------------------------------------
do_close:
        php
        jsr     LF643
        beq     LF5F6
        plp
        clc
        rts
; -------------------------------------------------------------------------
LF5F6:
        jsr     LF650
        plp
        txa
        pha
        bcc     LF61D
        lda     FirstAdr
        beq     LF61D
        cmp     #$03
        beq     LF61D
        bcs     LF61A
        cmp     #$02
        bne     LF613
        lda     #$00
        sta     acia+ACmdReg
        beq     LF61D
LF613:
        pla
        jsr     LF61E
        jsr     LFE5A
LF61A:
        jsr     LF8BF
LF61D:
        pla
LF61E:
        tax
        dec     DevTabIndex
        cpx     DevTabIndex
        beq     LF63C
        ldy     DevTabIndex
        lda     LogicalAdrTable,y
        sta     LogicalAdrTable,x
        lda     FirstAdrTable,y
        sta     FirstAdrTable,x
        lda     SecondAdrTable,y
        sta     SecondAdrTable,x
LF63C:
        clc
        rts
; -------------------------------------------------------------------------
; Sucht logische Filenummer (in x)

LF63E:
        lda     #$00
        sta     Status
        txa
LF643:
        ldx     DevTabIndex
LF646:
        dex
        bmi     LF676
        cmp     LogicalAdrTable,x
        bne     LF646
        clc
        rts
; -------------------------------------------------------------------------
LF650:
        lda     LogicalAdrTable,x
        sta     LogicalAdr
        lda     FirstAdrTable,x
        sta     FirstAdr
        lda     SecondAdrTable,x
        sta     SecondAdr
        rts
; -------------------------------------------------------------------------
do_setfnr:
        tya
        ldx     DevTabIndex
LF664:
        dex
        bmi     LF676
        cmp     SecondAdrTable,x
        bne     LF664
        clc
LF66D:
        jsr     LF650
        tay
        lda     LogicalAdr
        ldx     FirstAdr
        rts
; -------------------------------------------------------------------------
LF676:
        sec
        rts
; -------------------------------------------------------------------------
do_chgfpar:
        tax
        jsr     LF63E
        bcc     LF66D
        rts
; -------------------------------------------------------------------------
do_clrall:
        ror     XSave
        sta     SaveX
LF685:
        ldx     DevTabIndex
LF688:
        dex
        bmi     do_clrch
        bit     XSave
        bpl     LF698
        lda     SaveX
        cmp     FirstAdrTable,x
        bne     LF688
LF698:
        lda     LogicalAdrTable,x
        sec
        jsr     close
        bcc     LF685
        lda     #$00
        sta     DevTabIndex
do_clrch:
        ldx     #$03
        cpx     DefOutDev
        bcs     LF6AF
        jsr     unlisten
LF6AF:
        cpx     DefInpDev
        bcs     LF6B6
        jsr     untalk
LF6B6:
        ldx     #$03
        stx     DefOutDev
        lda     #$00
        sta     DefInpDev
        rts
; -------------------------------------------------------------------------
do_open:
        bcc     LF6C4
        jmp     LF73A
; -------------------------------------------------------------------------
LF6C4:
        ldx     LogicalAdr
        jsr     LF63E
        bne     LF6CE
        jmp     FileOpen
; -------------------------------------------------------------------------
LF6CE:
        ldx     DevTabIndex
        cpx     #$0A
        bcc     LF6D8
        jmp     TooManyFiles
; -------------------------------------------------------------------------
LF6D8:
        inc     DevTabIndex
        lda     LogicalAdr
        sta     LogicalAdrTable,x
        lda     SecondAdr
        ora     #$60
        sta     SecondAdr
        sta     SecondAdrTable,x
        lda     FirstAdr
        sta     FirstAdrTable,x
        beq     LF705
        cmp     #$03
        beq     LF705
        bcc     LF6FB
        jsr     LF707
        bcc     LF705
LF6FB:
        cmp     #$02
        bne     LF702
        jmp     OpenRS232
; -------------------------------------------------------------------------
LF702:
        jsr     LFE5A
LF705:
        clc
        rts
; -------------------------------------------------------------------------
LF707:
        lda     SecondAdr
        bmi     LF738
        ldy     FileNameLen
        beq     LF738
        lda     FirstAdr
        jsr     listen
        lda     SecondAdr
        ora     #$F0
LF718:
        jsr     second
        lda     Status
        bpl     LF724
        pla
        pla
        jmp     DevNotPresent
; -------------------------------------------------------------------------
LF724:
        lda     FileNameLen
        beq     LF735
        ldy     #$00
LF72A:
        jsr     LFE92
        jsr     ciout
        iny
        cpy     FileNameLen
        bne     LF72A
LF735:
        jsr     unlisten
LF738:
        clc
        rts
; -------------------------------------------------------------------------
LF73A:
        lda     FirstAdr
        jsr     listen
        lda     #$6F
        sta     SecondAdr
        jmp     LF718
; -------------------------------------------------------------------------
do_load:
        stx     LoadStAdr
        sty     LoadStAdr+1
        sta     VerifyFlag
        sta     LoadStAdr+2
        lda     #$00
        sta     Status
        lda     FirstAdr
        bne     LF75D
LF75A:
        jmp     IllDeviceNr
; -------------------------------------------------------------------------
LF75D:
        cmp     #$03
        beq     LF75A
        bcs     LF766
        jmp     LF810
; -------------------------------------------------------------------------
LF766:
        lda     #$60
        sta     SecondAdr
        ldy     FileNameLen
        bne     LF771
        jmp     MissingFName
; -------------------------------------------------------------------------
LF771:
        jsr     LF81B
        jsr     LF707
        lda     FirstAdr
        jsr     talk
        lda     SecondAdr
        jsr     tksa
        jsr     acptr
        sta     EndAdrLow
        sta     StartAdrLow
        lda     Status
        lsr     a
        lsr     a
        bcc     LF791
        jmp     FileNotFound
; -------------------------------------------------------------------------
LF791:
        jsr     acptr
        sta     EndAdrHi
        sta     StartAdrHi
        jsr     LF840
        lda     LoadStAdr+2
        sta     EndAdrSeg
        sta     StartAdrSeg
        lda     LoadStAdr
        and     LoadStAdr+1
        cmp     #$FF
        beq     LF7BA
        lda     LoadStAdr
        sta     EndAdrLow
        sta     StartAdrLow
        lda     LoadStAdr+1
        sta     EndAdrHi
        sta     StartAdrHi
LF7BA:
        lda     #$FD
        and     Status
        sta     Status
        jsr     ChkStopKey
        bne     LF7C8
        jmp     LF8B3
; -------------------------------------------------------------------------
LF7C8:
        jsr     acptr
        tax
        lda     Status
        lsr     a
        lsr     a
        bcs     LF7BA
        txa
        ldx     IndReg
        ldy     EndAdrSeg
        sty     IndReg
        ldy     #$00
        bit     VerifyFlag
        bpl     LF7EE
        sta     SaveAdrLow
        lda     (EndAdrLow),y
        cmp     SaveAdrLow
        beq     LF7F0
        lda     #$10
        jsr     OrStatus
        .byte   $AD
LF7EE:
        sta     (EndAdrLow),y
LF7F0:
        stx     IndReg
        inc     EndAdrLow
        bne     LF800
        inc     EndAdrHi
        bne     LF800
        inc     EndAdrSeg
        lda     #$02
        sta     EndAdrLow
LF800:
        bit     Status
        bvc     LF7BA
        jsr     untalk
        jsr     LF8BF
        jmp     LF813
; -------------------------------------------------------------------------
        jmp     FileNotFound
; -------------------------------------------------------------------------
LF810:
        jsr     LFE5A
LF813:
        clc
        lda     EndAdrSeg
        ldx     EndAdrLow
        ldy     EndAdrHi
        rts
; -------------------------------------------------------------------------
LF81B:
        bit     MsgFlag
        bpl     LF83F
        ldy     #SearchingTxt           ; 'SEARCHING'
        jsr     ChkPrtSysMsg
        lda     FileNameLen
        beq     LF83F
        ldy     #ForTxt                 ; 'FOR'
        jsr     ChkPrtSysMsg
LF82E:
        ldy     FileNameLen
        beq     LF83F
        ldy     #$00
LF834:
        jsr     LFE92
        jsr     bsout
        iny
        cpy     FileNameLen
        bne     LF834
LF83F:
        rts
; -------------------------------------------------------------------------
LF840:
        ldy     #$1B
        lda     VerifyFlag
        bpl     LF849
        ldy     #VerifyingTxt           ; 'VERIFYING'
LF849:
        jmp     ChkPrtSysMsg
; -------------------------------------------------------------------------
do_save:
        lda     ExecReg,x
        sta     StartAdrLow
        lda     IndReg,x
        sta     StartAdrHi
        lda     $02,x
        sta     StartAdrSeg
        tya
        tax
        lda     ExecReg,x
        sta     EndAdrLow
        lda     IndReg,x
        sta     EndAdrHi
        lda     $02,x
        sta     EndAdrSeg
        lda     FirstAdr
        bne     LF86D
LF86A:
        jmp     IllDeviceNr
; -------------------------------------------------------------------------
LF86D:
        cmp     #$03
        beq     LF86A
        bcc     LF8D6
        lda     #$61
        sta     SecondAdr
        ldy     FileNameLen
        bne     LF87E
        jmp     MissingFName
; -------------------------------------------------------------------------
LF87E:
        jsr     LF707
        jsr     LF8D9
        lda     FirstAdr
        jsr     listen
        lda     SecondAdr
        jsr     second
        ldx     IndReg
        jsr     SetFPtoStart
        lda     SaveAdrLow
        jsr     ciout
        lda     SaveAdrHi
        jsr     ciout
        ldy     #$00
LF89F:
        jsr     CmpFPtoEnd
        bcs     LF8BA
        lda     (SaveAdrLow),y
        jsr     ciout
        jsr     IncFP
        jsr     ChkStopKey
        bne     LF89F
        stx     IndReg
LF8B3:
        jsr     LF8BF
        lda     #$00
        sec
        rts
; -------------------------------------------------------------------------
LF8BA:
        stx     IndReg
        jsr     unlisten
LF8BF:
        bit     SecondAdr
        bmi     LF8D4
        lda     FirstAdr
        jsr     listen
        lda     SecondAdr
        and     #$EF
        ora     #$E0
        jsr     second
        jsr     unlisten
LF8D4:
        clc
LF8D5:
        rts
; -------------------------------------------------------------------------
LF8D6:
        jsr     LFE5A
LF8D9:
        lda     MsgFlag
        bpl     LF8D5
        ldy     #SavingTxt              ; 'SAVING'
        jsr     ChkPrtSysMsg
        jmp     LF82E
; -------------------------------------------------------------------------
; Zeit holen
; Ausgabeformat:    ac    t1 sh4 sh2 sh1 sl8 sl4 sl2 sl1
;                   xr    t2 mh4 mh2 mh1 ml8 ml4 ml2 ml1
;                   yr    pm  t8  t4  hh hl8 hl4 hl2 hl1

do_rdtim:
        lda     cia+TOD10
        pha
        pha
        asl     a
        asl     a
        asl     a
        and     #$60
        ora     cia+TODhour
        tay
        pla
        ror     a
        ror     a
        and     #$80
        ora     cia+TODsec
        sta     SaveAdrLow
        ror     a
        and     #$80
        ora     cia+TODmin
        tax
        pla
        cmp     cia+TOD10
        bne     do_rdtim
        lda     SaveAdrLow
        rts
; -------------------------------------------------------------------------
; Zeit setzen
; Eingabe: Zeit im Format wie unter do_rdtim beschrieben

do_settim:
        pha
        pha
        ror     a
        and     #$80
        ora     cia+CtrlB
        sta     cia+CtrlB
        tya
        rol     a
        rol     a
        rol     SaveAdrLow
        rol     a
        rol     SaveAdrLow
        txa
        rol     a
        rol     SaveAdrLow
        pla
        rol     a
        rol     SaveAdrLow
        sty     cia+TODhour
        stx     cia+TODmin
        pla
        sta     cia+TODsec
        lda     SaveAdrLow
        sta     cia+TOD10
        rts
; -------------------------------------------------------------------------
TooManyFiles:
        lda     #$01
        .byte   $2C
FileOpen:
        lda     #$02
        .byte   $2C
FileNotOpen:
        lda     #$03
        .byte   $2C
FileNotFound:
        lda     #$04
        .byte   $2C
DevNotPresent:
        lda     #$05
        .byte   $2C
NotInputFile:
        lda     #$06
        .byte   $2C
NotOutputFile:
        lda     #$07
        .byte   $2C
MissingFName:
        lda     #$08
        .byte   $2C
IllDeviceNr:
        lda     #$09
; -------------------------------------------------------------------------
IOError:
        pha
        jsr     clrch
        ldy     #IOErrorTxt             ; 'I/O ERROR #'
        bit     MsgFlag
        bvc     LF968
        jsr     PrtSysMsg
        pla
        pha
        ora     #$30
        jsr     bsout
LF968:
        pla
        sec
        rts
; -------------------------------------------------------------------------
; Flag für gedrückte Stoptaste abfragen

do_stop:
        lda     StopKeyFlag
        and     #$01
        bne     LF978           ; nicht gedrückt
        php                     ; Zero Flag retten
        jsr     clrch           ; I/O auf Default
        sta     KeyBufIndex     ; = $00 (keine Taste gedrückt)
        plp
LF978:
        rts
; -------------------------------------------------------------------------
; tastatur auf Stoptaste abfragen

do_udtim:
        lda     tpi2+tpiPortC
        lsr     a
        bcs     LF991
        lda     #$FE
        sta     tpi2+tpiPortB
        lda     #$10
        and     tpi2+tpiPortC
        bne     LF98C
        sec
LF98C:
        lda     #$FF
        sta     tpi2+tpiPortB
LF991:
        rol     a
        sta     StopKeyFlag     ; Flag für Stoptaste retten
        rts
; -------------------------------------------------------------------------
; Kennung für Module

ModulText:
        .byte   $C2,$CD         ; 'B'+$80 + 'M'+$80
; -------------------------------------------------------------------------
; Reset-Routine

RESET:
        ldx     #$FE
        sei
        txs                     ; Stackpointer setzen
        cld
        lda     #$A5
        cmp     WstFlag         ; Test auf Warmstart
        bne     LF9AA
        lda     WstFlag+1
        cmp     #$5A
        beq     LF9F8

; Kaltstart

LF9AA:
        lda     #$06            ; Suche Autostart-Header
        sta     EndAdrLow
        lda     #$00
        sta     EndAdrHi
        sta     wstvec
        ldx     #$30
LF9B7:
        ldy     #$03
        lda     EndAdrHi
        bmi     LF9D5           ; bis $8000
        clc
        adc     #$10            ; alle 4 KB $X000
        sta     EndAdrHi        ; ab $1000 (X=1)
        inx                     ; = $3X
        txa
        cmp     (EndAdrLow),y   ; $X009 = $3X ?
        bne     LF9B7           ; nein : Skip
        dey
LF9C9:
        lda     (EndAdrLow),y   ; ja: Vergleiche Rest mit Modulheader-Kennung
        dey
        bmi     LF9D8
        cmp     ModulText,y
        beq     LF9C9
        bne     LF9B7           ; Header stimmt nicht
LF9D5:
        ldy     #$E0            ; nichts gefunden: Start bei $e000
        .byte   $2C
LF9D8:
        ldy     EndAdrHi
        sty     wstvec+1        ; Startvektor setzen
        tax                     ; ($X006)
        bpl     LF9F8           ; positiv: Skip
        jsr     do_ioinit       ; sonst Standardinit
        lda     #$F0
        sta     PgmKeyBuf+1     ; Flag für keine Tasten belegt
        jsr     jmp_scrinit     ; Init CRT und Tastatur
        jsr     RamTas          ; Ramtest
        jsr     do_restor       ; Vektoren setzen
        jsr     jmp_scrinit
        lda     #$A5
        sta     WstFlag         ; Warmstartkennung setzen
LF9F8:
        jmp     (wstvec)        ; Autostart oder $e000
; -------------------------------------------------------------------------
; Peripherie initialisieren

do_ioinit:
        lda     #$F3
        sta     tpi1+tpiCtrlReg
        ldy     #$FF
        sty     tpi1+tpiDDRC
        lda     #$5C
        sta     tpi1+tpiPortB
        lda     #$7D
        sta     tpi1+tpiDDRB
#if K1 | K3B | K4AO | K4BO
        lda     #$3D
#endif
#if K4A
        lda     #$38
#endif
        sta     tpi1+tpiPortA
        lda     #$3F
        sta     tpi1+tpiDDRA
        sty     tpi2+tpiPortA
        sty     tpi1+tpiPortB
        sty     tpi2+tpiDDRA
        sty     tpi2+tpiDDRB
        lsr     tpi2+tpiPortA
        iny
        sty     tpi2+tpiPortC
        sty     tpi2+tpiDDRC
        lda     #$7F
        sta     cia+IntCtrReg
        sty     cia+DDRA
        sty     cia+DDRB
        sty     cia+CtrlB
        sta     cia+TOD10
        sty     tpi1+tpiPortC
LFA43:
        lda     tpi1+tpiPortC
        ror     a
        bcc     LFA43
        sty     tpi1+tpiPortC
        ldx     #$00
LFA4E:
        inx
        bne     LFA4E
        iny
        lda     tpi1+tpiPortC
        ror     a
        bcc     LFA4E
        cpy     #$1B
        bcc     LFA5F
        lda     #$88
        .byte   $2C
LFA5F:
        lda     #$08
        sta     cia+CtrlA
        lda     IPCcia+IntCtrReg
        lda     #$90
        sta     IPCcia+IntCtrReg
        lda     #$40
        sta     IPCcia+PortB
        stx     IPCcia+DDRA
        stx     IPCcia+CtrlB
        stx     IPCcia+CtrlA
        lda     #$48
        sta     IPCcia+DDRB
        lda     #$01
        ora     tpi1+tpiPortB
        sta     tpi1+tpiPortB
        rts
; -------------------------------------------------------------------------
; RAM testen und initialisieren

RamTas:
        lda     #$00
        tax
LFA8B:
;       sta     $0002,x         ; war nicht ZP-codiert
        .byte   $9D,$02,$00
        sta     $0200,x         ; Zeropage, Page 2 und 3 löschen
        sta     $02F8,x         ;
        inx
        bne     LFA8B
        lda     #$01
        sta     IndReg
        sta     UsrMemBot+2
        sta     SysMemBot+2
        lda     #$02
        sta     UsrMemBot
        sta     SysMemBot
        dec     IndReg
LFAAB:
        inc     IndReg          ; Teste auf Ram in allen Bänken
        lda     IndReg
        cmp     #$0F
        beq     LFAD7
        ldy     #$02            ; komplette 64KB
LFAB5:
        lda     (SaveAdrLow),y
        tax
        lda     #$55
        sta     (SaveAdrLow),y
        lda     (SaveAdrLow),y
        cmp     #$55
        bne     LFAD7           ; muß zusammenhängend sein, sonst Abbruch
        asl     a
        sta     (SaveAdrLow),y
        lda     (SaveAdrLow),y
        cmp     #$AA
        bne     LFAD7
        txa
        sta     (SaveAdrLow),y
        iny
        bne     LFAB5
        inc     SaveAdrHi
        bne     LFAB5
        beq     LFAAB           ; alle Bänke testen
LFAD7:
        ldx     IndReg          ; Einsprung nach Speichertest
        dex                     ; letztes belegtes Segment
        txa
        ldx     #$FF
        ldy     #$FD
        sta     SysMemTop+2     ; Zeiger auf Ende des freien Speichers setzen
        sty     SysMemTop+1
        stx     SysMemTop
        ldy     #$FA
        clc
        jsr     do_memtop
        dec     rs232BufPtrSeg
        dec     TapeBufPtrSeg
        lda     #<do_tape       ; Tape-Pointer setzen
        sta     TapeVec
        lda     #>do_tape
        sta     TapeVec+1
        rts
; -------------------------------------------------------------------------
; Sprungvektoren für Page 3

Page3Vectors:
        .word   do_IRQ
        .word   Break
        .word   do_NMI
        .word   do_open
        .word   do_close
        .word   do_chkin
        .word   do_chkout
        .word   do_clrch
        .word   do_basin
        .word   do_bsout
        .word   do_stop
        .word   do_getin
        .word   do_clrall
        .word   do_load
        .word   do_save
        .word   MoniCmd
        .word   jmp_escseq
        .word   jmp_escseq
        .word   do_second
        .word   do_tksa
        .word   NACPTR
        .word   NCIOUT
        .word   NUNTLK
        .word   NUNLSN
        .word   do_listen
        .word   do_talk

        Page3VecLen     = *-Page3Vectors

; -------------------------------------------------------------------------
; NMI-Einsprung (zeigt normalerweise auf do_NMI = rti)

NMI:
        jmp     (NMIvec)
; -------------------------------------------------------------------------
; Parameter für Filename setzen

do_setnam:
        sta     FileNameLen
        lda     ExecReg,x
        sta     FileNameAdrLo
        lda     IndReg,x
        sta     FileNameAdrHi
        lda     $02,x
        sta     FileNameAdrSeg
        rts
; -------------------------------------------------------------------------
; Fileparameter setzen

do_setlfs:
        sta     LogicalAdr
        stx     FirstAdr
        sty     SecondAdr
        rts
; -------------------------------------------------------------------------
; Status setzen/holen

do_readst:
        bcc     LFB64
        lda     FirstAdr
        cmp     #$02
        bne     LFB5D
        lda     rs232status
        pha
        lda     #$00
        beq     LFB6B
do_setst:
        sta     MsgFlag
LFB5D:
        lda     Status
OrStatus:
        ora     Status
        sta     Status
        rts
; -------------------------------------------------------------------------
LFB64:
        pha
        lda     FirstAdr
        cmp     #$02
        bne     LFB70
LFB6B:
        pla
        sta     rs232status
        rts
; -------------------------------------------------------------------------
LFB70:
        pla
        sta     Status
        rts
; -------------------------------------------------------------------------
; IEC-Bus Timeout-Flag setzen

do_settmo:
        sta     TimOut
        rts
; -------------------------------------------------------------------------
; Obergrenze des Speichers setzen/holen

do_memtop:
        bcc     LFB83
        lda     UsrMemTop+2
        ldx     UsrMemTop
        ldy     UsrMemTop+1
LFB83:
        stx     UsrMemTop
        sty     UsrMemTop+1
        sta     UsrMemTop+2
        rts
; -------------------------------------------------------------------------
; Untergrenze des Benutzer-Speichers holen

LFB8D:
        bcc     LFB98
        lda     UsrMemBot+2
        ldx     UsrMemBot
        ldy     UsrMemBot+1
LFB98:
        stx     UsrMemBot
        sty     UsrMemBot+1
        sta     UsrMemBot+2
        rts
; -------------------------------------------------------------------------
; RAM-Vektoren auf Page 3 rücksetzen

do_restor:
        ldx     #$FD
        ldy     #$FA
        lda     #$0F
        clc
; -------------------------------------------------------------------------
; RAM-Vektoren auf Page 3 setzen/holen

do_vector:
        stx     SaveAdrLow
        sty     SaveAdrHi
        ldx     IndReg
        sta     IndReg
        bcc     LFBBD
        ldy     #Page3VecLen-1
LFBB5:
        lda     IRQvec,y
        sta     (SaveAdrLow),y
        dey
        bpl     LFBB5
LFBBD:
        ldy     #Page3VecLen-1
LFBBF:
        lda     (SaveAdrLow),y
        sta     IRQvec,y
        dey
        bpl     LFBBF
        stx     IndReg
        rts
; -------------------------------------------------------------------------
; Warmstartkennung und Vektor setzen. Vektor in YR/XR

do_setwst:
        stx     wstvec
        sty     wstvec+1
        lda     #$5A
        sta     WstFlag+1
        rts
; -------------------------------------------------------------------------
IRQ:
        pha
        txa
        pha
        tya
        pha
        tsx
        lda     $0104,x                 ; Prozessorstatus vom Stapel
        and     #$10                    ; Break Flag gesetzt ?
        bne     LFBE6
        jmp     (IRQvec)                ; zeigt normalerweise auf do_IRQ
; -------------------------------------------------------------------------
LFBE6:
        jmp     (BRKvec)                ; zeigt normalerweise auf Break
; -------------------------------------------------------------------------
do_IRQ:
        lda     IndReg                  ; Ind. Segment retten
        pha
        cld
        lda     tpi1+tpiActIntReg       ; Interrupt Register 6525
        bne     do_IRQ1                   ; IRQ ?
        jmp     LFCA2                   ; sonst Fehler, IRQ beenden
; -------------------------------------------------------------------------
;
; IRQ-Reg. 6525:
;
; Bit   7       6       5       4       3       2       1       0
;                               |       |       |       |       ^ 50 Hz
;                               |       |       |       ^ SRQ IEEE 488
;                               |       |       ^ cia
;                               |       ^ IRQB ext. Port
;                               ^ acia



do_IRQ1:
        cmp     #%10000                 ; IRQ von acia ?
        beq     LFBFC                   ; ja
        jmp     LFC5B                   ; sonst weiter
; -------------------------------------------------------------------------
; IRQ von acia behandeln

LFBFC:
        lda     acia+AStatusReg
        tax
        and     #$60
        tay
        eor     dcddsr
        beq     LFC15
        tya
        sta     dcddsr
        ora     rs232status
        sta     rs232status
        jmp     IRQEnd1
; -------------------------------------------------------------------------
LFC15:
        txa
        and     #$08
        beq     LFC40
        ldy     rs232tail
        iny
        cpy     rs232head
        bne     LFC27
        lda     #$08
        bne     LFC3A
LFC27:
        sty     rs232tail
        dey
        ldx     rs232BufPtrSeg
        stx     IndReg
        ldx     acia+AStatusReg
        lda     acia+ADataReg
        sta     (rs232BufPtr),y
        txa
        and     #$07
LFC3A:
        ora     rs232status
        sta     rs232status
LFC40:
        lda     acia+AStatusReg
        and     #$10
        beq     LFC58
        lda     acia+ACmdReg
        and     #$0C
        cmp     #$04
        bne     LFC58
        lda     #$F3
        and     acia+ACmdReg
        sta     acia+ACmdReg
LFC58:
        jmp     IRQEnd1
; -------------------------------------------------------------------------
LFC5B:
        cmp     #$08
        bne     LFC69
        lda     IPCcia+IntCtrReg
        cli
        jsr     LFD48
        jmp     IRQEnd1
; -------------------------------------------------------------------------
LFC69:
        cli
        cmp     #$04
        bne     LFC7A
        lda     cia+IntCtrReg
        ora     alarm
        sta     alarm
        jmp     IRQEnd1
; -------------------------------------------------------------------------
LFC7A:
        cmp     #$02
        bne     LFC81
        jmp     IRQEnd1
; -------------------------------------------------------------------------
LFC81:
        jsr     jmp_scnkey
        jsr     do_udtim
IRQChkCass:                     ; Label nur für Moni (extern)
        lda     tpi1+tpiPortB
        bpl     LFC95
        ldy     #$00
        sty     CassMotFlag
        ora     #$40
        bne     LFC9C
LFC95:
        ldy     CassMotFlag
        bne     IRQEnd1
        and     #$BF
LFC9C:
        sta     tpi1+tpiPortB
IRQEnd1:
        sta     tpi1+tpiActIntReg
LFCA2:
        pla
        sta     IndReg
LFCA5:
        pla
        tay
        pla
        tax
        pla
do_NMI:
        rti
; -------------------------------------------------------------------------
;

do_copro:
        lda     IPCBuf
        and     #$7F
        tay
        jsr     LFE21
        lda     #$04
        and     IPCcia+PortB
        bne     do_copro
        lda     #$08
        ora     IPCcia+PortB
        sta     IPCcia+PortB
        nop
        lda     IPCcia+PortB
        tax
        and     #$04
        beq     LFCD8
        txa
        eor     #$08
        sta     IPCcia+PortB
        txa
        nop
        nop
        nop
        bne     do_copro
LFCD8:
        lda     #$FF
        sta     IPCcia+DDRA
        lda     IPCBuf
        sta     IPCcia+PortA
        jsr     LFE08
        lda     IPCcia+PortB
        and     #$BF
        sta     IPCcia+PortB
        ora     #$40
        cli
        nop
        nop
        nop
        sta     IPCcia+PortB
        jsr     LFDEE
        lda     #$00
        sta     IPCcia+DDRA
        jsr     LFDF6
        jsr     LFDE6
        ldy     #$00
        beq     LFD26
LFD09:
        lda     #$FF
        sta     IPCcia+DDRA
        lda     $0805,y
        sta     IPCcia+PortA
        jsr     LFDFF
        jsr     LFDEE
        lda     #$00
        sta     IPCcia+DDRA
        jsr     LFDF6
        jsr     LFDE6
        iny
LFD26:
        cpy     $0803
        bne     LFD09
        ldy     #$00
        beq     LFD42
LFD2F:
        jsr     LFDFF
        jsr     LFDEE
        lda     IPCcia+PortA
        sta     $0805,y
        jsr     LFDF6
        jsr     LFDE6
        iny
LFD42:
        cpy     $0804
        bne     LFD2F
        rts
; -------------------------------------------------------------------------
LFD48:
        lda     #$00
        sta     IPCcia+DDRA
        lda     IPCcia+PortA
        sta     IPCBuf
        and     #$7F
        tay
        jsr     LFE21
        tya
        asl     a
        tay
        lda     IPCjmpTab,y
        sta     IPCBuf+1
        iny
        lda     IPCjmpTab,y
        sta     $0802
        jsr     LFDFF
        jsr     LFDE6
        ldy     #$00
LFD71:
        cpy     $0803
        beq     do_membot
        jsr     LFDF6
        jsr     LFDEE
        lda     IPCcia+PortA
        sta     $0805,y
        jsr     LFDFF
        jsr     LFDE6
        iny
        bne     LFD71
do_membot:
        bit     IPCBuf
        bmi     LFDC3
        lda     #$FD
        pha
        lda     #$98
        pha
        jmp     (IPCBuf+1)
; -------------------------------------------------------------------------
        jsr     LFDF6
        ldy     #$00
        beq     LFDBD
LFDA0:
        jsr     LFDEE
        lda     #$FF
        sta     IPCcia+DDRA
        lda     $0805,y
        sta     IPCcia+PortA
        jsr     LFDFF
        jsr     LFDE6
        lda     #$00
        sta     IPCcia+DDRA
        jsr     LFDF6
        iny
LFDBD:
        cpy     $0804
        bne     LFDA0
LFDC2:
        rts
; -------------------------------------------------------------------------
LFDC3:
        lda     #$FD
        pha
        lda     #$CE
        pha
        jsr     LFE11
        jmp     (IPCBuf+1)
; -------------------------------------------------------------------------
        jsr     LFE08
        lda     $0804
        sta     $0803
        sta     IPCBuf
        lda     #$00
        sta     $0804
        jsr     do_copro
        jmp     LFDC2
; -------------------------------------------------------------------------
LFDE6:
        lda     IPCcia+PortB
        and     #$04
        bne     LFDE6
        rts
; -------------------------------------------------------------------------
LFDEE:
        lda     IPCcia+PortB
        and     #$04
        beq     LFDEE
        rts
; -------------------------------------------------------------------------
LFDF6:
        lda     IPCcia+PortB
        and     #$F7
        sta     IPCcia+PortB
        rts
; -------------------------------------------------------------------------
LFDFF:
        lda     #$08
        ora     IPCcia+PortB
        sta     IPCcia+PortB
        rts
; -------------------------------------------------------------------------
LFE08:
        lda     tpi1+tpiPortB
        and     #$EF
        sta     tpi1+tpiPortB
        rts
; -------------------------------------------------------------------------
LFE11:
        lda     IPCcia+PortB
        and     #$02
        beq     LFE11
        lda     tpi1+tpiPortB
        ora     #$10
        sta     tpi1+tpiPortB
        rts
; -------------------------------------------------------------------------
LFE21:
        lda     IPCParmTab,y
        pha
        and     #$0F
        sta     $0803
        pla
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     $0804
        rts
; -------------------------------------------------------------------------
do_runcopro:
        ldx     #$FF
        stx     IndReg
        lda     tpi1+tpiPortB           ; -DRAMON
        and     #$EF                    ; ... auf 0 setzen
        sta     tpi1+tpiPortB           ; ... und damit den Bus freigeben
        nop
        lda     IPCcia+PortB
        ror     a
        bcs     LFE47
        rts
; -------------------------------------------------------------------------
; Interrupt an Copro um diesen zu starten

LFE47:
        lda     #$00
        sei
        sta     IPCcia+PortB
        lda     #$40            ; Bit 6 = IRQ Copro
        nop
        nop
        nop
        nop
        sta     IPCcia+PortB
        cli
LFE57:
        jmp     LFE57
; -------------------------------------------------------------------------
; Tape-Einsprung

LFE5A:
        jmp     (TapeVec)               ; zeigt normalerweise auf do_tape
; -------------------------------------------------------------------------
; Tape-Einsprung für die aktuelle Kernal-Version (keine Unterstützung)

do_tape:
        pla
        pla
        jmp     DevNotPresent
; -------------------------------------------------------------------------
; Filepointer auf Startadresse setzen

SetFPtoStart:
        lda     StartAdrHi
        sta     SaveAdrHi
        lda     StartAdrLow
        sta     SaveAdrLow
        lda     StartAdrSeg
        sta     SaveAdrSeg
        sta     IndReg
        rts
; -------------------------------------------------------------------------
; Filepointer mit Endadresse vergleichen

CmpFPtoEnd:
        sec
        lda     SaveAdrLow
        sbc     EndAdrLow
        lda     SaveAdrHi
        sbc     EndAdrHi
        lda     SaveAdrSeg
        sbc     EndAdrSeg
        rts
; -------------------------------------------------------------------------
; Filepointer erhöhen

IncFP:
        inc     SaveAdrLow
        bne     LFE91
        inc     SaveAdrHi
        bne     LFE91
        inc     SaveAdrSeg
        lda     SaveAdrSeg
        sta     IndReg
        lda     #$02
        sta     SaveAdrLow
LFE91:
        rts
; -------------------------------------------------------------------------
LFE92:
        ldx     IndReg
        lda     FileNameAdrSeg
        sta     IndReg
        lda     (FileNameAdrLo),y
        stx     IndReg
        rts
; -------------------------------------------------------------------------
do_jsrseg:
        sta     IndReg
        txa
        clc
        adc     #$02
        bcc     LFEA6
        iny
LFEA6:
        tax
        tya
        pha
        txa
        pha
        jsr     LFF19
        lda     #$FE
        sta     (SegChgPtr),y
        php
        sei
        pha
        txa
        pha
        tya
        pha
        jsr     LFF19
        tay
        lda     ExecReg
        jsr     LFF2A
        lda     #$04
        ldx     #$FF
        jsr     LFF24
        tsx
        lda     $0105,x
        sec
        sbc     #$03
        pha
        lda     $0106,x
        sbc     #$00
        tax
        pla
        jsr     LFF24
        tya
LFEDC:
        sec
        sbc     #$04
        sta     StackP
        tay
        ldx     #$04
LFEE5:
        pla
        iny
        sta     (SegChgPtr),y
        dex
        bne     LFEE5
        ldy     StackP
        lda     #$2D
        ldx     #$FF
        jsr     LFF24
        pla
        pla
        tsx
        stx     StackP
        tya
        tax
        txs
        lda     IndReg
        jmp     LFFF6
; -------------------------------------------------------------------------
        nop
        php
        php
        sei
        pha
        txa
        pha
        tya
        pha
        tsx
        lda     $0106,x
        sta     IndReg
        jsr     LFF19
        jmp     LFEDC
; -------------------------------------------------------------------------
LFF19:
        ldy     #$01
        sty     SegChgPtr+1
        dey
        sty     SegChgPtr
        dey
        lda     (SegChgPtr),y
        rts
; -------------------------------------------------------------------------
LFF24:
        pha
        txa
        sta     (SegChgPtr),y
        dey
        pla
LFF2A:
        sta     (SegChgPtr),y
        dey
        rts
; -------------------------------------------------------------------------
        pla
        tay
        pla
        tax
        pla
        plp
        rts
; -------------------------------------------------------------------------
; Nachgebildeter NMI

        php
        jmp     (LFFFA)
; -------------------------------------------------------------------------
        .byte   $00,$ea,$60,$58,$60
; -------------------------------------------------------------------------
#if K4AO | K4BO
LFF3E:  ora     crsw
        sta     crsw
        lda ScreenRight
        rts
#endif

#if K4AO
LFF45:  ; TODO: WTF is going on here?
        cpx $A209
        asl FileNameAdrLo
        .byte $02 ; KIL = halts the CPU. the data bus will be set to #$FF
        ldx #$04
        rts
#endif

#if K4BO
LFF45:  cpx #9
        ldx #6
        bcc     LFF4D
        ldx #4
LFF4D:  rts
#endif

        .fill   $ff6c-* ($aa)
; -------------------------------------------------------------------------
; Maschinenprogramm in anderer Bank ausführen

jsrseg:
        jmp     do_jsrseg
; -------------------------------------------------------------------------
; Kennung für Warmstart setzen

setwst:
        jmp     do_setwst
; -------------------------------------------------------------------------
; Coprozessor starten wenn mgl

runcopro:
        jmp     do_runcopro
; -------------------------------------------------------------------------
; Auflisten der Funktionstastenbelegung / Setzen des Fkttasten

funkey:
        jmp     jmp_funkey
; -------------------------------------------------------------------------
; Kommunikation mit dem copro

copro:
        jmp     do_copro
; -------------------------------------------------------------------------
; I/O-Peripherie Init

ioinit:
        jmp     do_ioinit
; -------------------------------------------------------------------------
; Reset Tastatur und CRT-Format

scrinit:
        jmp     jmp_scrinit
; -------------------------------------------------------------------------
; Platz im Ram holen: X/Y = Bedarf --> X/Y = Adresse

getmem:
        jmp     do_GetMem
; -------------------------------------------------------------------------
; Page 3 Vektoren setzen/holen

vector:
        jmp     do_vector
; -------------------------------------------------------------------------
; Page 3 Vektoren mit Kernal-Werten belegen

restor:
        jmp     do_restor
; -------------------------------------------------------------------------
; Filenummer setzen und Parameter eintragen

setfnr:
        jmp     do_setfnr
; -------------------------------------------------------------------------
chgfpar:
        jmp     do_chgfpar
; -------------------------------------------------------------------------
; IEC-Status setzen

setst:
        jmp     do_setst
; -------------------------------------------------------------------------
; Sekundäradresse nach Listen senden

second:
        jmp     (secndVec)
; -------------------------------------------------------------------------
; Sekundäradresse nach Talk senden

tksa:
        jmp     (tksaVec)
; -------------------------------------------------------------------------
; Ramende setzen/holen

memtop:
        jmp     do_memtop
; -------------------------------------------------------------------------
; Ramanfang setzen/holen

membot:
        jmp     LFB8D
; -------------------------------------------------------------------------
; Tastatur abfragen (eigentlich IRQ-Routine)

scnkey:
        jmp     jmp_scnkey
; -------------------------------------------------------------------------
; Timeout-Flag für IEC-Bus setzen

settmo:
        jmp     do_settmo
; -------------------------------------------------------------------------
; Holen eines Bytes vom IEC-Bus

acptr:
        jmp     (acptrVec)
; -------------------------------------------------------------------------
; Ausgabe eines Datenbytes auf den IEC-Bus

ciout:
        jmp     (cioutVec)
; -------------------------------------------------------------------------
; Untalk senden

untalk:
        jmp     (untlkVec)
; -------------------------------------------------------------------------
; Unlisten senden

unlisten:
        jmp     (unlsnVec)
; -------------------------------------------------------------------------
; Listen senden

listen:
        jmp     (listnVec)
; -------------------------------------------------------------------------
; Talk senden

talk:
        jmp     (talkVec)
; -------------------------------------------------------------------------
; Status setzen/holen

readST:
        jmp     do_readst
; -------------------------------------------------------------------------
; Fileparameter setzen

setlfs:
        jmp     do_setlfs
; -------------------------------------------------------------------------
; Parameter für Filename setzen

setnam:
        jmp     do_setnam
; -------------------------------------------------------------------------
; Logische Datei öffnen

open:
        jmp     (openVec)
; -------------------------------------------------------------------------
; Logische Datei schließen

close:
        jmp     (closeVec)
; -------------------------------------------------------------------------
; Eingabegerät setzen

chkin:
        jmp     (chkinVec)
; -------------------------------------------------------------------------
; Ausgabegerät setzen

chkout:
        jmp     (ckoutVec)
; -------------------------------------------------------------------------
; Ein-/Ausgabegerät auf Default

clrch:
        jmp     (clrchVec)
; -------------------------------------------------------------------------
; Byte vom aktuellen Eingabegerät holen

basin:
        jmp     (basinVec)
; -------------------------------------------------------------------------
; Byte auf aktuelles Ausgabegerät ausgeben

bsout:
        jmp     (bsoutVec)
; -------------------------------------------------------------------------
; Load

load:
        jmp     (loadVec)
; -------------------------------------------------------------------------
; Save

save:
        jmp     (saveVec)
; -------------------------------------------------------------------------
; Zeit setzen

settim:
        jmp     do_settim
; -------------------------------------------------------------------------
; Zeit holen

rdtim:
        jmp     do_rdtim
; -------------------------------------------------------------------------
; Flag für gedrückte Stoptaste prüfen

ChkStopKey:
        jmp     (stopVec)
; -------------------------------------------------------------------------
; Zeichen von Tastatur holen

getin:
        jmp     (getinVec)
; -------------------------------------------------------------------------
; Alle I/O rücksetzen

clall:
        jmp     (clallVec)
; -------------------------------------------------------------------------
; Auf gedrückte Stoptaste prüfen (IRQ-Routine, Tastatur)

udtim:
        jmp     do_udtim
; -------------------------------------------------------------------------
; Bildschirmgröße (Spalten/Zeilen) holen

screen:
        jmp     jmp_screen
; -------------------------------------------------------------------------
; Cursorposition setzen/holen

plot:
        jmp     jmp_plot
; -------------------------------------------------------------------------
; Basisadresse des I/O-Bereichs holen

iobase:
        jmp     jmp_iobase
; -------------------------------------------------------------------------
LFFF6:
        sta     ExecReg
        rts
; -------------------------------------------------------------------------
        .byte   $01
LFFFA:
        .word   NMI
        .word   RESET
        .word   IRQ


; -------------------------------------------------------------------------
        .end

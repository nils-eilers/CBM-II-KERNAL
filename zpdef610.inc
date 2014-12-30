; ***********************************************************
;
; Include-Datei mit Definitionen für Zeropage
;



ExecReg		= $0000
IndReg		= $0001
FileNameAdrLo	= $0090
FileNameAdrHi	= $0091
FileNameAdrSeg	= $0092
SaveAdrLow	= $0093
SaveAdrHi	= $0094
SaveAdrSeg	= $0095
EndAdrLow	= $0096
EndAdrHi	= $0097
EndAdrSeg	= $0098
StartAdrLow	= $0099
StartAdrHi	= $009A
StartAdrSeg	= $009B
Status		= $009C
FileNameLen	= $009D
LogicalAdr	= $009E
FirstAdr	= $009F
SecondAdr	= $00A0
DefInpDev	= $00A1
DefOutDev	= $00A2
TapeBufPtr	= $00A3
TapeBufPtrSeg	= $00A5
rs232BufPtr	= $00A6
rs232BufPtrSeg	= $00A8
StopKeyFlag	= $00A9
CTemp		= $00AA
snsw1		= $00AB
SegChgPtr	= $00AC
PChighSave	= $00AE
PClowSave	= $00AF
SRSave		= $00B0
ACSave		= $00B1
XRSave		= $00B2
YRSave		= $00B3
SPSave		= $00B4
IndSegSave	= $00B5
IRQSaveHi	= $00B7
IRQSaveLo	= $00B8
Adr1		= $00B9		; im Assembler etc. verwendet
Adr2		= $00BB		; w.o.
MoniCntr	= $00BD
MoniTmp		= $00BE
MoniDevNr	= $00BF
PgmKeyBuf	= $00C0
PgmKeyPtr	= $00C2
sedsal		= $00C4
sedeal		= $00C6
CharPtr		= $00C8
CursLine	= $00CA
CursCol		= $00CB
GrafMode	= $00CC
LastIndex	= $00CD
LastLine	= $00CE
LastCol		= $00CF
crsw		= $00D0
KeyBufIndex	= $00D1
QuoteSw		= $00D2
Insrt		= $00D3
Config		= $00D4
LastLinePos	= $00D5
KeyIndex	= $00D6
RepeatCount	= $00D7
RepeatDelay	= $00D8
sedt1		= $00D9		; Temp
sedt2		= $00DA		; Temp, frequently used
PrtData		= $00DB
ScreenTop	= $00DC
ScreenBot	= $00DD
ScreenLeft	= $00DE
ScreenRight	= $00DF
ModKey		= $00E0
NorKey		= $00E1
BitTable	= $00E2

; ***********************************************************
;
; Speicherstellen, die nur im Monitor verwendet werden
;

OperandLen			= $E8
AdrFlagBuf			= $E9
MnemoBuf			= $EA
Ptr1				= $EC
InputPtr			= $EE
Ptr2				= $F0
Ptr3				= $F2
FindBuf				= $F4	; 10 Bytes: auch vom Assembler verwendet
MnemoBuf2			= $F4
MnemoTextBuf			= $F6






; ***********************************************************
;
; Definitionen für Zeropage
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




; ***********************************************************
;
; Definitionen für Speicherseite 3
;

;
; system ram vectors
;

IRQvec		     = $0300
BRKvec		     = $0302
NMIvec		     = $0304
openVec		     = $0306
closeVec	     = $0308
chkinVec	     = $030A
ckoutVec	     = $030C
clrchVec	     = $030E
basinVec	     = $0310
bsoutVec	     = $0312
stopVec		     = $0314
getinVec	     = $0316
clallVec	     = $0318
loadVec		     = $031A
saveVec		     = $031C
usrcmd		     = $031E
escvec		     = $0320
ctrlvec		     = $0322
secndVec	     = $0324
tksaVec		     = $0326
acptrVec	     = $0328
cioutVec	     = $032A
untlkVec	     = $032C
unlsnVec	     = $032E
listnVec	     = $0330
talkVec		     = $0332

;
;
;

LogicalAdrTable      = $0334
FirstAdrTable	     = $033E
SecondAdrTable	     = $0348
SysMemBot	     = $0352
SysMemTop	     = $0355
UsrMemBot	     = $0358
UsrMemTop	     = $035B
TimOut		     = $035E
VerifyFlag	     = $035F
DevTabIndex	     = $0360
MsgFlag		     = $0361
CassBufPtr	     = $0362
t1		     = $0363
t2		     = $0364
XSave		     = $0365
SaveX		     = $0366
SaveXt		     = $0367
temp		     = $0368
alarm		     = $0369
TapeVec		     = $036A
LoadStAdr	     = $036F
CassMotFlag	     = $0375
m6551Ctrl	     = $0376
m6551Cmd	     = $0377
rs232status	     = $037A
dcddsr		     = $037B
rs232head	     = $037C
rs232tail	     = $037D
PgmKeyEnd	     = $0380
PgmKeySeg	     = $0382
PgmKeySize	     = $0383
rvsFlag		     = $0397
linetmp		     = $0398
LastPrtChar	     = $0399
InsertFlag	     = $039A
ScrollFlag	     = $039B
FktTemp		     = $039C
PgmKeyIndex	     = $039D
LogScrollFlag	     = $039E
BellMode	     = $039F	; Glocke an/aus 00 = an
SegSave		     = $03A0
TabStopTable	     = $03A1	; 80 Bits für Tabstops
Keyd		     = $03AB	; Tastaturpuffer
funvec		     = $03B5	; Vektor für Funktionstastenbehandlung
FunKeyTmp	     = $03B7
sedt3		     = $03B9
MoniSegSave	     = $03f0	; Bankreg save im Monitor
wstvec		     = $03F8
WstFlag		     = $03FA


; ***********************************************************
;
; Deklarationen für den I/O-Bereich
;


; I/O  $d800: CRTC 6545

	crtc		=	$d800

	CAdrReg		=	$00
	CDataReg	=	$01



; I/O  $da00: SID 6581

	sid		=	$da00

	Osc1		=	$00
	Osc2		=	$07
	Osc3		=	$0e

	FreqLo		=	$00
	FreqHi		=	$01
	PulseF		=	$02
	PulseC		=	$03
	OscCtl		=	$04
	AtkDcy		=	$05
	SusRel		=	$06

	FiCtlLo		=	$15
	FiCtlHi		=	$16
	Resonance	=	$17
	Volume		=	$18
	PotX		=	$19
	PotY		=	$1A
	Random		=	$1B
	Env3		=	$1C



; I/O  $db00: CIA 6526 Inter Process Communication

	IPCcia		=	$db00

	PortA		=	$00
	PortB		=	$01
	DDRA		=	$02
	DDRB		=	$03
	TimALo		=	$04
	TimAHi		=	$05
	TimBLo		=	$06
	TimBHi		=	$07
	TOD10		=	$08
	TODsec		=	$09
	TODmin		=	$0A
	TODhour		=	$0B
	SerDataReg	=	$0C
	IntCtrReg	=	$0D
	CtrlA		=	$0E
	CtrlB		=	$0F



; I/O  $dc00: CIA 6526

	cia		=	$dc00



; I/O  $dd00: ACIA 6551

	acia		=	$dd00

	ADataReg	=	$00
	AStatusReg	=	$01
	ACmdReg		=	$02
	ACtrlReg	=	$03



; I/O  $de00: Triport #1 6525

	tpi1		=	$de00

	tpiPortA	=	$00
	tpiPortB	=	$01
	tpiPortC	=	$02
	tpiIntLatch	=	$02
	tpiDDRA		=	$03
	tpiDDRB		=	$04
	tpiDDRC		=	$05
	tpiIntMask	=	$05
	tpiCtrlReg	=	$06
	tpiActIntReg	=	$07



; I/O  $df00: Triport #2 6525

	tpi2		=	$df00





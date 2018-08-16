*************************************
***        BBS-View V1.13         ***
***				  ***
*** by SieGeL (tRSi/X-iNNOVATiON) ***
***				  ***
*** Time of Creation : 04.06.1993 ***
***				  ***
*** Version 1.0      : 06.06.1993 ***
***                               ***
*** Added UserBreak +		  ***
*** Mousebuttonselect: 19.06.1993 ***
***				  ***
*** Added ALL S.Resu.: 01.07.1993 ***
*** Changed Colors   : 24.07.1993 ***
***                               ***
*** Version 1.13     : 19.06.1995 ***
*************************************

		INCDIR	"AINC:"
		INCLUDE	"asl_lib.i"
		INCLUDE	"libraries/asl.i"
		INCLUDE	"exec/exec.i"
		INCLUDE "exec/exec_lib.i"
		INCLUDE "devices/console.i"
		INCLUDE "devices/conunit.i"
		INCLUDE "dos/dos_lib.i"
		INCLUDE	"dos/dos.i"
		INCLUDE	"dos/dostags.i"
		INCLUDE	"dos/rdargs.i"
		INCLUDE	"intuition/intuition_lib.i"
                INCLUDE	"intuition/intuition.i"
                INCLUDE	"graphics/graphics_lib.i"
		INCLUDE	"WBSTARTUP.i"
PRG:

* Oeffnen der Libraries *

	lea	Dname(pc),a1		;Name der Lib ->a1
	moveq	#36,d0			;Versionsnummer egal
	CALLEXE	OpenLibrary		;Lib oeffnen
	move.l	d0,_DosBase		;Konnte geoffnet werden ?
	beq	Ende			;Nope...raus hier
			
	lea	IName(pc),a1
	moveq	#36,d0
	CALLEXE	OpenLibrary
	move.l	d0,_IntuitionBase
	beq 	CloseD

	lea	GName(pc),a1		;Name der Lib ->a1
	moveq	#36,d0			;Immer OS 2
	CALLEXE	OpenLibrary
	move.l	d0,_GFXBase		;Pointer retten
	beq	CloseI

	lea	AName(pc),a1
	moveq	#36,d0
	CALLEXE	OpenLibrary
	move.l	d0,_ASLBase
	beq	CloseG

	clr.l	-(a7)			;Dummy
	clr.l	-(a7)			;Dummy
	clr.l	-(a7)			;ARG[1]
	clr.l	-(a7)			;ARG[2]
	
	lea	_Template(pc),a0	;Befehlsschablone ->a0
	move.l	a0,d1			;Für Aufruf ->d1
	move.l	a7,d2			;Argumentfeld ->d2
	move.l	#0,d3			;Keine RDArgs-Str.
	CALLDOS	ReadArgs		;Argumente Read Args
	move.l	d0,_rd			;RDArgs-Struktur retten
	bne.s	_ParseArgs		;Wenn RD<>0...okay

	move.l	#_currdir,d1		;Current Directory setzen
	move.l	#200,d2			;Laenge des Buffers
	CALLDOS	GetCurrentDirName	;Aktuelles Programdir holen

	move.l	_ASLBase,a6		;ASL->a6
	lea	_Filepuffer(pc),a1	;DIr-Puffer ->a1
	lea	_FileReqTags(pc),a0	;TagItems ->a0
	jsr	_Dateiauswahl		;Requester zeigen...
	beq	_RDArgsFreigabe			
	move.l	a0,_file
	bra	checkfile		;Weiter gehts beim filecheck

_parseArgs
	moveq	#RETURN_OK,d4		;ReturnCode Merken
	lea	_FormatString(pc),a0	;FormatString
	move.l	a0,d1			;fuer Aufruf nach d1
	move.l	a7,d2			;ArgumentenFeld nach d2
	CALLDOS	VPrintf			;Und ausgeben
	movea.l	(a7),a5			;Filename herausfiltern
	move.l	a5,_file

checkfile:
        movea.l	_file,a0		;Filename ->a0
	move.l	a0,d1			;Fuer Lock() ->d1
	move.l	#ACCESS_READ,d2		;LeseLock
	CALLDOS	Lock			;Und versuchen zu 'locken'
	tst.l	d0			;Iss es gut gegangen ?
	beq	_RDArgsFreigabe		;Nope, also raus hier..
	move.l	d0,d1                   ;Handle ->d1
	CALLDOS	UnLock			;Und File wieder 'unlocken'

OEFFNESCREEN:

	lea	MyScreen(pc),a0		;Screen-Struktur ->a0
	CALLINT	OpenScreen		;Screen öffnen
	move.l	d0,_SCREENPOINTER	;Pointer sichern
	beq	_RDArgsFreigabe		;oder raus
	movea.l	_ScreenPointer,a0
        move.w	$0e(a0),d5		;Aktuelle Screenhöhe ermitteln
	move.w	d5,Hoch			;In Win-Struct eintragen
	move.w	$0c(a0),d5		;Aktuelle Screenbreite ermitteln
	move.w	d5,breit		;In Win-Struct eintragen

* Window auf Screen oeffnen *

	lea	MyWindow(pc),a0		;Window-Struktur ->a0
	CALLINT	OpenWindow		;Und oeffnen
	move.l	d0,_Winhandle		;PTR retten
	beq	CloseScr		;0 = wech hier...

	move.l	_Winhandle,a0		;Jetzt den View-Port
	CALLINT	ViewPortAddress		;Aus der Win-Strk. holen
	move.l	d0,_VPort		;und sichern
	
* Farben ändern auf ANSI-Farben *

	movea.l	_VPort,a0		;ViewPort ->a0
	lea	colors(pc),a1		;Farbtabelle ->a1
	moveq	#8,d0			;8 Farben
       CALLGRAF	LoadRGB4		;Und Farben einlesen

* Datei öffnen und auf Window ausgeben *

	CALLEXE	CreateMsgPort		;MSg-Port initalizieren
	move.l	d0,_port		;Zeiger retten
	beq	CloseWin
	
	movea.l	_port,a0		;Port ->a0
	move.l	#IOSTD_SIZE,d0		;Groesse der Str. (STANDARD) ->d0
	CALLEXE	CreateIORequest		;Und Strk. initalizieren
	move.l	d0,_ioReq		;Und Zeiger retten
	beq	DelPort			;Fehler ? Dann Port weg und raus

	movea.l	_IOReq,a1
	movea.l	_Winhandle,a2		;Window-Addresse in die Struktur
	move.l	a2,IO_DATA(a1)
	lea	devname(pc),a0		;Name des Devices (console.device)
	moveq	#0,d0			;Unit 0
	moveq	#0,d1			;Keine Flags
	CALLEXE	OpenDevice		;console.device oeffnen
	tst.l	d0			;Alles klaro ?
	bne	DelIO			;Neee...wech hier....

OpenDatei:
	movea.l	_file,a5		;Filename ->a5
	move.l	a5,d1			;Für DosOpen ->d1
	move.l	#MODE_OLDFILE,d2	;Datei MUSS! existieren...
	CALLDOS	Open
	move.l	d0,_Filehandle		;Adresse des Files sichern...
	beq	Close_Device		;Nich da...also raus hier..(Erstmal!)
	move.l	_Winhandle,a0		;Window-Str. ->a0
	move.l	86(a0),_UPort		;Messageport herrausfiltern
Dateilesen:
	bsr	Test_Break		;auf User-Break checken
	cmp.l	#$200,d2
	beq	CloseFile
	cmp.l	#$100,d2
        beq	ReadIt
	cmp.l	#$8,d2
	beq	Readit
Readit:
	move.l	_Filehandle,d1		;Filename ->d1
	move.l	#_Puffer,d2		;Pufferadr. ->d2
	move.l	#80,d3			;80 Zeichen lesen
	CALLDOS	Read			;Und leeeesen...:)
	tst.l	d0			;0 = Keine Zeichen mehr ?
	beq	Main			;Jaa...tschuess...
	cmp.l	#-1,d0			;Iss nen Fehler aufgetreten ?
	beq	Main			;Jep...auch tschuess...

	movea.l	_IOReq,a1		;IO-Str. nach a1
	move.l	d0,IO_LENGTH(a1)	;LAENGE = KOMPLETT!
	move.l	#_puffer,IO_DATA(a1)	;Pufferadr. eintragen
	move.w	#CMD_WRITE,IO_COMMAND(a1) ;Kommando : Schreiben!
	CALLEXE	DoIO			;Und ab gehts...
	tst.l	d0
	
        bra	Dateilesen		;Und weitergehts...

Main:
	movea.l	_UPort,a0		;Userport ->a0
	CALLEXE	WaitPort		;Und schlafen schicken den Task...

	move.l	_UPort,a0		;Userport ->a0
	CALLEXE	GetMsg			;Message abholen
	move.l	d0,_Msg			;Und retten

	move.l	_Msg,a1			;Message für nächsten Aufruf ->a1
	CALLEXE	ReplyMsg		;Messi beantworten

	move.l	_Msg,a2			;Messi nach a2
	move.l	$14(a2),d2		;Messi-Code rausfiltern
        cmp.l	#$200,d2		;Wars das CloseGadget ???
	beq	CloseFile		;Jups...also raus hier...
        cmp.l	#$8,d2
	beq	CloseFile		;Jau...raus hier....
	jmp	Main			;Und weiter warten

CloseFile:
	move.l	_Filehandle,d1
	CALLDOS	Close

Close_Device:
	move.l	_IOReq,a1		;IO-Str. ->a1
	CALLEXE	CloseDevice		;Und schliessen

DelIO:
	movea.l	_ioreq,a0      		;IOSTRUKTUR ->A0
	CALLEXE	DeleteIORequest  	;UND LÖSCHEN
DelPort:
	movea.l	_port,a0		;Message-Portptr. ->a0
	CALLEXE	DeleteMsgPort		;Und loeschen

CloseWin:
	move.l	_Winhandle,a0		;Windowptr. ->a0
	CALLINT	CloseWindow		;Und zu das Erbe
	
CloseSCR:
	move.l	_ScreenPointer,a0	;Screenptr. ->a0
	CALLINT	CloseScreen		;Und auch schliessen

_RDArgsFreigabe
	move.l	_rd,d1			;RDArgs-Str. ->d1
	CALLDOS	FreeArgs
	
_FeldFreigabe
	addq.l	#8,a7
	addq.l	#8,a7
	
CloseA:
	move.l	_ASLBase,a1		;ASL-PTR. ->a1
	CALLEXE	CloseLibrary		;Und schliessen

CloseG:
	move.l	_GFXBase,a1		;GFX-Ptr. ->a1
	CALLEXE	CloseLibrary		;Und schliessen

CloseI:
	move.l	_IntuitionBase,a1
	CALLEXE	CloseLibrary

CloseD:
	move.l	_DosBase,a1		;Adresse ->a1
	CALLEXE	CloseLibrary		;Und schliessen

Ende:
	tst.l	d0
	rts

Test_BreaK:
	movea.l	_UPort,a0		;User-Port ->a0
	CALLEXE	GetMsg			;Message vorhanden...?
        tst.l	d0			;Messi da ?
	beq	GoAhead			;Nöö..also weiter
	move.l	d0,_Msg			;Msg retten
	move.l	_Msg,a1			;Für nächsten Aufruf ->a1
	CALLEXE	ReplyMsg		;Msg beantworten (WICHTIG!)
        move.l	_Msg,a2			;Jetzt Msg ->a2
	move.l	$14(a2),d2		;Message-Flag herausfilter
	rts
goahead:
	rts

***************************************
*     Unterprogramm Dateiauswahl      *
*     --------------------------      *
* INPUT :                             *
*		A6 = _ASLBASE         *
*		A1 = Buffer           *
*		A0 = TagItems         *
* OUPUT :                             *
*		D0 = Buffer oder Null *
*		A6 = _ASLBASE         *
*		A0 = BUFFER           *
***************************************
_Dateiauswahl:
	clr.b	(a1)			;0-Byte in Puffer
	movem.l	d0/a1,-(a7)		;Ergebnis + Puffer
	moveq	#ASL_FILEREQUEST,d0	;Tags liegen ja in a0!!!
	jsr	_LVOAllocASLRequest(a6)	;Strk. initalisieren
	move.l	d0,(a7)			;Ergebnis retten
	beq.s	.Error			;Im Fehlerfall ->
	movea.l	d0,a0			;FileRequester nach a0
	jsr	_LVORequestFile(a6)	;darstellen
	movem.l	(a7),a0-a1		;Filereq. + Buffer
	move.l	a0,d1			;Filereq. retten
	move.l	d0,(a7)			;Okay/Cancel testen
	beq.s	.Cancel			;Im Fehlerfall...
	move.l	a1,(a7)			;Ergebnis=Buffer
	movea.l	rf_Dir(a0),a0		;Directory-String
.CopyDir
	move.b	(a0)+,(a1)+		;Kopieren
	bne.s	.CopyDir
	subq.l	#1,a1			;Leerbyte zurueck
	cmpi.b	#":",-1(a1)		;Endung prüfen
	beq.s	.Okay			;Wenn drive ->
	cmpi.b	#"/",-1(a1)		;Endung prüfen
	beq.s	.Okay			;Wenn Directory
	move.b	#"/",(a1)+		;Sonst Trennbyte rein
.Okay
	movea.l	d1,a0			;FileRequester
	movea.l	rf_File(a0),a0		;Dateiname
.CopyFile
	move.b	(a0)+,(a1)+		;Anhängen...
	bne.s	.CopyFile
.Cancel
	movea.l	d1,a0			;FileRequester
	jsr	_LVOFreeFileRequest(a6)	;Und freigeben
.Error
	movem.l	(a7)+,d0/a0		;Stack aufräumen
	tst.l	d0			;CCR setzten
	rts
		
* Datenreservierungen *

Version		dc.b	"$VER: BBS-VIEW 1.13 (19.06.95)",0
DName		dc.b	"dos.library",0
IName		dc.b	"intuition.library",0
GName		dc.b	"graphics.library",0
AName		dc.b	"asl.library",0
devname		dc.b	"console.device",0
		even

_DosBase	dc.l	0
_IntuitionBase	dc.l	0
_GFXBase	dc.l	0
_ASLBase	dc.l	0
_Winhandle	dc.l	0
_VPort		dc.l	0
_rp		dc.l	0
_Filehandle	dc.l	0
_laenge		dc.l	0
_port		dc.l	0
_ioreq		dc.l	0
_File		dc.l	0
_rd		dc.l	0
_UPort		dc.l	0
_Msg		dc.l	0
again		dc.l	0

		even
		
MySCREEN:
		dc.w	0,0
		dc.w	-1
		dc.w	-1
		dc.w	3			;Tiefe der Screen ( 8 Farben!)
		dc.b	0			;Detailpen
		dc.b	1			;Blockpen
		dc.w	$C000			;ViewModes ?
		dc.w	$F			;Customscreen
		dc.l	0			;Fontattribute
		dc.l	0			;Screentitel
		dc.l	0
		dc.l	0
		dc.l	0

MyWindow:
		dc.w	0		;linke ecke
		dc.w	0		;obere ecke
breit:		dc.w	0		;Breite
hoch:		dc.w	0		;Hoehe
		dc.b	0,1		;Farben (sinnlos!)
		dc.l	CLOSEWINDOW|VANILLAKEY|MOUSEBUTTONS|MENUPICK
		dc.l	WINDOWCLOSE|BORDERLESS|ACTIVATE
		dc.l	0		;Zeiger auf erstes Gadget
		dc.l	0		;Checkmark
		dc.l	_titel		;Windowname
_Screenpointer	dc.l	0		;Screenpointer
		dc.l	0		;BitMap
		dc.w	0		;Mindest-Breite
		dc.w	0		;Mindest-Hoehe
		dc.w	0		;Max. Hoehe
		dc.w	0		;Max. Breite
		dc.w	15		;Screentyp

		even		
_titel		dc.b	"          BBS-VieW V1.13 - Coded by SieGeL (tRSi/X-iNNOVATiON)          ",0

_Puffer		blk.b	80,0
_currdir	blk.b	200,0		;Puffer fuer CurrentDir

		even

_FileReqTags
		dc.l	ASL_HAIL,_TitelText
		dc.l	ASL_PATTERN,_PatternName
		dc.l	ASL_OKTEXT,_Okay
		dc.l	ASL_CANCELTEXT,_Cancel
		dc.l	ASL_LEFTEDGE,_Links
		dc.l	ASL_TOPEDGE,_Oben
		dc.l	ASL_WIDTH,_Breite
		dc.l	ASL_HEIGHT,_Hoehe
		dc.l	ASL_DIR,_currdir
		dc.l	TAG_DONE



_Template	dc.b	"FILENAME/A",0

_FormatString	dc.b	"Viewing %s...",10,10,0

		even

_request	dc.l	0
_FilePuffer	blk.b	80,0
		even
	
_TitelText	dc.b	"BBS-VieW:Select an ANSI to view",0
_PatternName	dc.b	"~(#?.info)",0

_Okay		dc.b	"SHOW!",0
_Cancel		dc.b	"NOPE!",0
		even
		
_Links		equ	10
_Oben		equ	10
_Breite		equ	250
_Hoehe		equ	240

colors:
		dc.w	$0000		;schwarz
		dc.w	$0FFF		;rot
		dc.w	$00F0		;Grün
		dc.w	$0FF0		;Gelb
		dc.w	$000F		;Blau
		dc.w	$0F0F		;Lila
		dc.w	$00FF		;Türkis
		dc.w	$0F00		;Weiss


 END
	

{$UNDEF test}
{$IFDEF test}
  PROGRAM dateien;
  {$A+,B-,D+,E-,F-,G-,I+,L+,N-,O-,R+,S+,V-,X-}
  {$M 32768,0,655360}
{$ELSE}
  unit dateien;
  {$A+,B-,D+,E-,F-,G-,I-,L+,N-,O-,R-,S+,V-,X-}
  {$M 32768,150000,655360}

{Zweck    : Stellt eine komfortable Dateiauswahlschachtel fÅr die    }
{           Auswahl einzelner oder mehrerer Dateien zur VerfÅgung    }
{Autor    : Kai Rohrbacher    }
{Sprache  : TurboPascal 6.0   }
{Datum    : 17.09.1992        }
{Anmerkung: Arbeitet dynamisch und mit allen Textmodi                }

interface
{$ENDIF}
USES crt,dos,eingaben;

type TArt=(Laufwerk,Verzeichnis,Datei);
     TPath =String[67];
     TName =String[8];
     TPunkt=CHAR;
     TExten=String[3];
     TAlles=STRING[8+1+3];
     TSize =LONGINT;
     TDate =LONGINT;
     PDateiName=^Dateiname;
     Dateiname=
       RECORD
        next:PDateiName;
        art:TArt;
        size:TSize;
        date:TDate;
        Vorname:TName; Punkt:TPunkt; Nachname:TExten;
        ganz:TAlles;
       END;

TYPE VideoMem=ARRAY[0..32766] OF WORD;
VAR ScreenX,ScreenY:BYTE; {enthalten aktuelle Auflîsung, z.B. 80 und 43}
    Basis:^VideoMem;      {zeigt auf Pos. (0,0) der akt. Textseite}

VAR  Laufwerke:String;  {Laufwerke im System, wird noch ergÑnzt!}

{$IFNDEF test}
 PROCEDURE Auswahl(x,y,MaxZeilen:BYTE; Header:STRING;
                   list:PDateiname; listlen:WORD;
                   nur_eins:BOOLEAN; VAR last,sel:PDateiname;
                   VAR CursSelected:BOOLEAN);
 PROCEDURE MakeFileList(VAR p:TPath; typ:STRING;
                        VAR list:PDateiName; VAR listlen:WORD;
                        VAR error:BOOLEAN);
 FUNCTION ChooseSingleFile(xpos,ypos,max_zeilen:BYTE;
                           Pf:TPath; typ:STRING; VAR error:BOOLEAN):TPath;
 FUNCTION ChooseMultipleFiles(xpos,ypos,max_zeilen:BYTE;
                              VAR Pfad:TPath; typ:STRING;
                              VAR error:BOOLEAN):PDateiname;
 PROCEDURE StripBlanks(VAR s:TAlles);
 PROCEDURE DelList(VAR list:PDateiName);
 FUNCTION UpString(St:String):STRING;
 FUNCTION LoString(St:String):STRING;
 PROCEDURE Rahmen(x1,y1,x2,y2:byte);
 PROCEDURE DetectXYresolution(VAR x,y:BYTE);
 FUNCTION BaseAddress:POINTER;
 PROCEDURE OutCharXY(x,y:BYTE; ch:WORD);
 FUNCTION GetCharXY(x,y:BYTE):WORD;
 PROCEDURE OutStringXY(x,y,attr:BYTE; s:STRING);
 FUNCTION min(x,y:INTEGER):INTEGER;
 FUNCTION max(x,y:INTEGER):INTEGER;
 FUNCTION BIOSreadKey:WORD;
 FUNCTION Festplatten_im_System:String;

implementation
{$ENDIF}

CONST SelUnsel:InputString='*.*'; {Suchmaske bei "+","-"; Ersatz fÅr "STATIC"}
VAR oldx,oldy,attr:BYTE;
    oldDir:TPath;

{---------- Routinen fÅr exotische Bildschirmmodi------------}

 PROCEDURE DetectXYResolution(VAR x,y:BYTE); ASSEMBLER;
 { in: - }
 {out: x = Anzahl Spalten des aktuellen Videomodus}
 {     y = dto., Zeilen}
 ASM
  PUSH BP

  MOV DL,24
  XOR BH,BH
  MOV AX,$1130
  INT $10
  MOV AH,$F
  INT $10
  INC DL

  POP BP

  LES DI,x
  MOV AL,AH
  STOSB
  LES DI,y
  MOV AL,DL
  STOSB
 END;

 FUNCTION BaseAddress:POINTER; ASSEMBLER;
 {out: Zeiger auf 1.Byte der aktuellen Textseite}
 {rem: Mono-/Farbgrafikadapter, exotische Auflîsungen}
 {     und mehrere Bildschirmseiten werden berÅcksichtigt!}
 ASM
  PUSH DS
  PUSH BP

  MOV AH,$F
  INT $10   {danach: BH=Display page }
  MOV AH,3
  INT $10   {danach: DH/DL=Cursor Y/X}
  PUSH DX   {merken!}

  MOV AH,2
  XOR DX,DX
  INT $10   {Cursor ist jetzt bei Pos. (0,0)}

  MOV AH,8
  INT $10   {Zeichen von dort lesen: AL/AH=ASCII/Attr.}
  PUSH AX   {merken!}

  XOR SI,SI
  MOV DS,SI
  MOV SI,$44E
  MOV DI,[SI]  {DI=Pageoffset der aktuellen Seite}
  MOV SI,$B800 {Farbsegment ausprobieren}
  MOV ES,SI    {ES:DI=^Pos(0,0) der akt. Seite, wenn Farbmonitor}
  NEG AX    {Zeichen verÑndert zurÅckschreiben}
  STOSW

  MOV AH,2
  XOR DX,DX
  INT $10   {Cursor ist jetzt wieder bei Pos. (0,0)}

  MOV AH,8
  INT $10   {Zeichen prÅflesen: in AL/AH}
  POP CX    {altes Zeichen}
  POP DX    {alte Cursorposition}
  CMP AX,CX {vergleiche Zeichen mit altem}
  PUSHF     {Ergebnis merken}
  PUSH CX   {altes Zeichen wird nochmal gebraucht}

  MOV AH,9
  MOV AL,CL
  MOV BL,CH
  MOV CX,1
  INT $10   {altes Zeichen zurÅck nach Pos(0,0) schreiben}

  MOV AH,2
  INT $10   {Cursor ist jetzt wieder an alter Stelle}

  XOR SI,SI
  MOV DS,SI
  MOV SI,$44E
  MOV DI,[SI]  {DI=Pageoffset der aktuellen Seite}
  MOV SI,$B800 {Farbsegment}
  MOV ES,SI    {ES:DI=^Pos(0,0) der akt. Seite}
  POP AX       {altes Zeichen zurÅckschreiben}
  MOV ES:[DI],AX

  POPF      {Vergleichsergebnis von vorhin}

  POP BP
  POP DS

  JE @monochrom
  MOV DX,$B800
  JMP @offset
 @monochrom:
  MOV DX,$B000
 @offset:
  MOV AX,DI
 END;

 PROCEDURE OutCharXY(x,y:BYTE; ch:WORD);
 { in: (x,y) = Bildschirmposition fÅr auszugebendes Zeichen}
 {     ch = auszugebendes Zeichen, inklusive Attribut, in  }
 {          der Form "Farbe SHL 8 +Ord(Zeichen)"}
 {     Basis = Zeiger auf Pos. (0,0) des Schirms}
 {     ScreenX = horizontale Auflîsung des Bildschirms}
 {     ScreenY = dto., vertikal}
 {rem: Die Cursorposition wurde durch OutCharXY() nicht weitergesetzt!}
 BEGIN
  Basis^[(ScreenX*Pred(y) +Pred(x))]:=ch
 END;

 FUNCTION GetCharXY(x,y:BYTE):WORD;
 { in: (x,y) = Bildschirmposition des auszulesenden Zeichens}
 {     Basis = Zeiger auf Pos. (0,0) des Schirms}
 {     ScreenX = horizontale Auflîsung des Bildschirms}
 {     ScreenY = dto., vertikal}
 {out: vom Bildschirm gelesenens Zeichen, inklusive Attribut, in}
 {     der Form "Farbe SHL 8 +Ord(Zeichen)"}
 BEGIN
  GetCharXY:=Basis^[(ScreenX*Pred(y) +Pred(x))]
 END;

 PROCEDURE OutStringXY(x,y,attr:BYTE; s:STRING);
 { in: (x,y) = Bildschirmposition fÅr auszugebendes Zeichen}
 {     attr  = Attribut fÅr Stringzeichen}
 {     s = auszugebende Zeichen}
 {     Basis = Zeiger auf Pos. (0,0) des Schirms}
 {     ScreenX = horizontale Auflîsung des Bildschirms}
 {     ScreenY = dto., vertikal}
 {rem: Die Cursorposition wurde durch OutStringXY() nicht weitergesetzt!}
 VAR i:BYTE;
     offs:WORD;
 BEGIN
  offs:=ScreenX*Pred(y) +Pred(x);
  FOR i:=1 TO Length(s) DO
   Basis^[offs +Pred(i)]:=attr SHL 8 +BYTE(s[i])
 END;

{------------------------------------------------------------}

 PROCEDURE StripBlanks(VAR s:TAlles);
 VAR i:BYTE;
 BEGIN
  FOR i:=length(s) DOWNTO 1 DO
   IF s[i]=' ' THEN Delete(s,i,1)
 END;

 FUNCTION min(x,y:INTEGER):INTEGER;
 BEGIN
  IF x<=y THEN min:=x ELSE min:=y
 END;

 FUNCTION max(x,y:INTEGER):INTEGER;
 BEGIN
  IF x>=y THEN max:=x ELSE max:=y
 END;

 FUNCTION BIOSreadKey:WORD; ASSEMBLER;
 {rem: Wird benîtigt, da ReadKey() keine Scancodes zurÅckliefert}
 ASM
  MOV AH,0
  INT $16
 END;

 FUNCTION UpString(St:STRING):STRING;
 VAR i:byte;
 BEGIN
  FOR i:=1 TO length(st) DO
   Case St[i] OF
    'Ñ':St[i]:='é';
    'î':St[i]:='ô';
    'Å':St[i]:='ö';
    else St[i]:=Upcase(St[i]);
   END;
  UpString:=St
 END;

 FUNCTION LoString(St:STRING):STRING;
 VAR i:BYTE;
 BEGIN
  FOR i:=1 TO length(st) DO
   Case St[i] OF
    'é':St[i]:='a';
    'ô':St[i]:='î';
    'ö':St[i]:='Å';
    'A'..'Z':St[i]:=CHAR(BYTE(St[i]) OR $20);
   END;
  LoString:=St
 END;

 FUNCTION Festplatten_im_System:String;
 {in : - }
 {out: String mit Namen der angeschlossenen}
 {     Festplatten, z.B.: 'CD'             }
 VAR Laufwerk,Id_Byte,Code:Byte;
     s:String;
 BEGIN
  s:='';
  Laufwerk:=3;
  REPEAT
  INLINE(
    $8A/$56/<Laufwerk/ { MOV  DL,[Laufwerk]}
    $1E/               { PUSH DS           }
    $B4/$1C/           { MOV  AH,1C        }
    $CD/$21/           { INT  21           }
    $1E/               { PUSH DS           }
    $07/               { POP  ES           }
    $1F/               { POP  DS           }
    $26/               { ES:               }
    $8A/$17/           { MOV  DL,[BX]      }
    $88/$56/<ID_Byte/  { MOV  [ID_Byte],DL }
    $88/$46/<Code      { MOV  [Code],AL    }
    );
   IF (Code<>255) and (ID_Byte=$F8)
    THEN s:=s+chr(64+Laufwerk);
   INC(Laufwerk);
  UNTIL (Code=255) or (Laufwerk>26);
  Festplatten_im_System:=s;
 END;


 PROCEDURE Rahmen(x1,y1,x2,y2:byte);
 VAR i:byte;
 BEGIN
  OutCharXY(x1,y1,TextAttr SHL 8 +218);
  FOR i:=x1+1 TO x2-1 DO OutCharXY(i,y1,TextAttr SHL 8 +196);
  OutCharXY(x2,y1,TextAttr SHL 8 +191);
  FOR i:=y1+1 TO y2-1 DO
   BEGIN
    OutCharXY(x1,i,TextAttr SHL 8 +179);
    OutCharXY(x2,i,TextAttr SHL 8 +179);
   END;
  OutCharXY(x1,y2,TextAttr SHL 8 +192);
  FOR i:=x1+1 TO x2-1 DO OutCharXY(i,y2,TextAttr SHL 8 +196);
  OutCharXY(x2,y2,TextAttr SHL 8 +217)
 END;

 PROCEDURE DelList(VAR list:PDateiName);
 VAR p:PDateiName;
 BEGIN
  WHILE list<>NIL DO
   BEGIN
    p:=list;
    list:=list^.next;
    dispose(p)
   END;
 END;

 FUNCTION LeadingChars(t:WORD; ch:CHAR; n:BYTE):STRING;
 {Wandelt t in STRING und fÅllt ihn vorn auf n Stellen mit ch auf}
 VAR s:STRING;
     i:BYTE;
 BEGIN
  STR(t,s);
  FOR i:=succ(length(s)) TO n DO insert(ch,s,1);
  LeadingChars:=s
 END;

{$IFDEF test}
 PROCEDURE WriteEntry(x,y:BYTE; p:DateiName);
 VAR t:DateTime;
 BEGIN
  GotoXY(x,y);
  WITH p DO
   BEGIN
    WRITE(ganz,'≥');
    CASE art OF
     Datei: IF size<1E9
             THEN WRITE(size:8,'≥') {pa·t ins Feld}
             ELSE WRITE(LeadingChars((size DIV 1024),' ',7)+'K','≥');
     Laufwerk:WRITE(#16+' DISK '+#17,'≥');
     Verzeichnis:IF pos('..',Vorname)=0
                  THEN WRITE(#16+'SUBDIR'+#17,'≥')
                  ELSE WRITE(#16+'UP-DIR'+#17,'≥')
    END;
    IF art<>Laufwerk
     THEN BEGIN
           UnpackTime(Date,t);
           WRITE(LeadingChars(t.day,'0',2),'.',
                 LeadingChars(t.month,'0',2),'.',
                 LeadingChars(t.year,'0',4),
                 '≥',
                 LeadingChars(t.hour,'0',2),':',
                 LeadingChars(t.min,'0',2));
          END
     ELSE WRITE('          ','≥','     ');
   END;
 END;

 PROCEDURE WriteList(list:PDateiName);
 VAR y:BYTE;
 BEGIN
  y:=1;
  WHILE list<>NIL DO
   BEGIN
    WriteEntry(1,y,list^);
    list:=list^.next;
    inc(y); IF y>25 THEN y:=1;
   END;
 END;
{$ENDIF}

FUNCTION NameCompare(Muster,Name:TAlles):BOOLEAN;
{ in: Muster = evtl. mit Wildcards "*","?" behaftetes Vergleichsmuster}
{     Name   = mit "Muster" zu vergleichender Name}
{out: TRUE/FALSE, wenn Muster auf Name zutrifft/nicht zutrifft}
{rem: o Einzuhaltende Konventionen: Hat die Datei keine Extension, so mu·}
{       ihr Name mit abschlie·endem Punkt eingeben werden "sowiedas.", um}
{       per Suchmaske "*." gefunden werden zu kînnen!}
{     o "*" entspricht "*.*"}

  FUNCTION SimpleCompare(Muster,Name:TAlles):BOOLEAN;
  {rem: Funktionell wie ComplexCompare(), aber nur fÅr Muster, die die}
  {     Wildcard "*" nicht enthalten}
  VAR i:BYTE;
      gleich:BOOLEAN;
  BEGIN
   IF Length(Muster)<>Length(Name)
    THEN SimpleCompare:=FALSE
    ELSE BEGIN
          gleich:=TRUE;
          i:=Length(Muster);
	  WHILE (i>0) AND gleich DO
           BEGIN
            gleich:=gleich AND
             ( (Muster[i]='?') OR (Muster[i]=Name[i]) );
            DEC(i)
           END;
          SimpleCompare:=gleich
         END;
  END;

  FUNCTION ComplexCompare(Muster,Name:TAlles):BOOLEAN;
  {rem: Funktionell wie NameCompare(), erwartet aber "*.*" bereits }
  {     konvertiert in "*" und "**"->"*"}
  VAR i,p,anzahl:BYTE;
      j:INTEGER;
      found:BOOLEAN;
      ch:CHAR;
  BEGIN
   IF Muster='*'  {erster IF-Zweig ist Abk., kînnte auch weggelassen werden}
    THEN ComplexCompare:=TRUE
    ELSE BEGIN
          p:=POS('*',Muster);
          IF p=0
           THEN ComplexCompare:=SimpleCompare(Muster,Name)
	   ELSE BEGIN
                 IF NOT SimpleCompare(Copy(Muster,1,p-1),Copy(Name,1,p-1))
                  THEN ComplexCompare:=FALSE
		  ELSE BEGIN
                        delete(Muster,1,p-1); {1.Zeichen ist jetzt "*"}
                        delete(Name,1,p-1);
                        p:=Length(Muster);
                        IF p=1
                         THEN ComplexCompare:=TRUE  {Muster='*'}
			 ELSE BEGIN
                               WHILE Muster[p]<>'*' DO DEC(p); {letztes "*" suchen}
                               anzahl:=Length(Muster)-p;
                               IF NOT SimpleCompare(
                                       Copy(Muster,p+1,anzahl),
                                       Copy(Name,Length(Name)-anzahl+1,anzahl))
                                THEN ComplexCompare:=FALSE
				ELSE BEGIN
                                      delete(Muster,p+1,anzahl); {letztes Zeichen='*'}
                                      delete(Name,Length(Name)-anzahl+1,anzahl);
                                      {Hier: 1.& letztes Zeichen von Muster='*'}
                                      IF Name=''
                                       THEN ComplexCompare:=Muster='*'
				       ELSE BEGIN {auf Folgezeichen von '*' synchronisieren}
                                             delete(Muster,1,1); {'*' lîschen}
                                             anzahl:=0; p:=0;
                                             FOR i:=Length(Muster) DOWNTO 1 DO
                                              IF Muster[i]='?' THEN INC(anzahl)
                                              ELSE IF Muster[i]<>'*' THEN p:=i;
                                             {p=Position des 1.Zeichens<>'?','*'}
                                             {anzahl=#'?' in Muster}
                                             IF p=0  {besteht Muster nur aus Wildcards?}
                                              THEN ComplexCompare:=Length(Name)>anzahl
					      ELSE BEGIN {nein, synchronisieren}
                                                    found:=FALSE;
                                                    ch:=Muster[p];
                                                    WHILE (NOT found) AND
                                                      (POS(ch,Name)>0) DO
						     BEGIN
                                                      j:=POS(ch,Name)-p+1;
                                                      IF j<1 THEN j:=1;
                                                      found:=ComplexCompare(Muster,Copy(Name,j,255));
                                                      delete(Name,1,POS(ch,Name))
                                                     END;
                                                    ComplexCompare:=found
                                                   END;
                                            END;
                                     END;
                              END;
                       END;
                END;
        END;
  END;

BEGIN {of NameCompare}
 WHILE POS('**',Muster)>0 DO delete(Muster,POS('**',Muster),1);
 IF Muster='*.*' THEN Muster:='*';
 NameCompare:=ComplexCompare(Muster,Name)
END;

 PROCEDURE Auswahl(x,y,MaxZeilen:BYTE; Header:STRING;
                   list:PDateiname; listlen:WORD;
                   nur_eins:BOOLEAN; VAR last,sel:PDateiname;
                   VAR CursSelected:BOOLEAN);
 { in: Maxzeilen = zu verwendende Zeilenzahl}
 {     x,y = Position fÅr li. obere Ecke der Auswahlbox}
 {     Header = Headerstring fÅr Box, i.d.R. der aktuelle Pfad, aber an}
 {            sich ein beliebiger String}
 {     list = Liste der EintrÑge, aus denen ausgewÑhlt werden soll}
 {     listlen = LÑnge dieser Liste}
 {     nur_eins = Flag fÅr: es darf nur 1 Datei|mehrere Dateien gewÑhlt werden}
 {     sel  = NIL (ansonsten wird evtl. Liste gelîscht)}
 {     ScreenX,ScreenY = Bildschirmweite, -hîhe}
 {     SelUnsel = Vorgabe fÅr Suchmaske bei "+","-"}
 {out: last = Zeiger auf letzten Eintrag, auf dem der Cursor stand}
 {     sel  = Liste der selektierten EintrÑge}
 {     CursSelected = TRUE, wenn der Eintrag unter dem Cursor bereits in }
 {      der Selektionsliste steht, also spÑter nicht noch gesondert be-  }
 {      trachtet werden mu·. Diese Information ist nur fÅr nur_eins=FALSE}
 {      sinnvoll!}
 {     SelUnsel = evtl. neue Suchmaske fÅr nÑchstes "+","-"}
 {rem: ab x mÅssen 40 Spalten zur VerfÅgung stehen,}
 {     ab y mÅssen MaxZeilen zur VerfÅgung stehen, }
 {     MaxZeilen>6}
 {     SelUnsel dient als "GedÑchtnis" von evtl. Suchmasken und ist deshalb}
 {     global definiert und vorbesetzt}
 {     Bildschirm wird *nicht* gerettet/gelîscht!}
 {     Dateinamen werden in Kleinschrift zurÅckgegeben, Verzeichnisse und}
 {     Laufwerke in Gro·schrift}

 {     FÅr nur_eins=TRUE ist der RÅckgabewert von "sel" nicht definiert; }
 {     stattdessen mu· "last" ausgewertet werden: ist last=NIL, so wurde }
 {     die Selektion per ESC abgebrochen, ansonsten ist last^ dasjenige  }
 {     File, auf dem der Benutzer RETURN drÅckte.}
 {     FÅr nur_eins=FALSE gilt Analoges, nur da· "sel" hier zusÑtzlich   }
 {     eine Liste aller Files des zuletzt gezeigten Verzeichnisses dar-  }
 {     stellt, die vom Benutzer per INSERT selektiert wurden. Achtung:   }
 {     Das File, auf dem der Benutzer zuletzt RETURN drÅckte, wurde da-  }
 {     durch nicht automatisch in die Selektionsliste "sel" mitaufgenom- }
 {     men (hîchstens, es wurde bereits vorher ebenfalls mit INSERT aus- }
 {     gewÑhlt), d.h.: *wenn* es ebenfalls mitverwendet werden soll, so  }
 {     mu· der "last"-Eintrag zusÑtzlich ausgewertet werden; dabei ist zu}
 {     beachten, da· zur Vermeidung evtl. doppelten Auftretens des Cur-  }
 {     soreintrages (1x in last^, 1x in sel-Liste) "CursSelected" ver-   }
 {     wendet werden kann!}
 {     ACHTUNG: Die Ausgaben dieser Prozedur sind mit Blanks aufgefÅllt! }
 {     (Z.B.: "config  .sys" statt "config.sys"). Zum entfernen steht die}
 {     Prozedur "StripBlanks() zur VerfÅgung!}
 LABEL break1,quit_CASE;
 TYPE TBild=ARRAY[1..132,1..60] OF WORD; {sollte fÅr alle Textmodi reichen}
 CONST width=40;
       CNormalText=White;
       BNormalText=Blue;
       BCursor=Cyan;
       CInfoText=Yellow;
       CSelectedText=Yellow;
       MaxEntries=1000; {max. Anzahl an Files/Directory}
 VAR oldAttr,Textzeilen,letzte,oldx,oldy:BYTE;
     i,erstegezeigte,cursorzeile,anzselected:WORD;
     sizeselected:LONGINT;
     speedaccess:ARRAY[0..MaxEntries] OF PDateiName; {Schnellzugriff auf Daten}
     selected:ARRAY[0..MaxEntries] OF Boolean;
     p,temp:PDateiName;
     oldcurs,wahl:WORD;
     ch:CHAR;
     flag:BOOLEAN;

     s:TAlles;
     attr,BoxX,BoxY,bx,by:BYTE;
     Bild:^TBild; {Speicher fÅr Bildschirmspeicher}

  (* nicht mehr nîtig, da kein WRITELN() mehr benutzt!
  PROCEDURE HideCursor; ASSEMBLER;
  ASM
   PUSH DS
   PUSH BP

   MOV AH,$F
   INT $10   {danach: BH=Display page }

   mov ah,3
   int $10
   mov dx,$FFFF
   mov ah,2
   xor bh,bh
   int $10     {set it to pos. 255,255 -> invisible}

   POP BP
   POP DS
  END;

  PROCEDURE ShowCursor;
  VAR dummy:WORD;
  BEGIN
   dummy:=oldcurs;
   ASM
    MOV CX,dummy
    PUSH DS
    PUSH BP

    MOV AH,$F
    INT $10   {danach: BH=Display page }

    mov ah,2
    mov DX,CX
    int $10     {set it to page 0 -> visible}

    POP BP
    POP DS
   END;
  END;
  *)

  PROCEDURE WriteLine(Zeile:BYTE; p:PDateiName; sel:BOOLEAN);
  { in: (x+1,Zeile) = Position fÅr Textausgabe}
  {     p = Zeiger auf auszugebenden Record }
  {     sel = TRUE|FALSE fÅr: Datei ist selektiert/nicht sel.}
  VAR t:DateTime;
      s:STRING[8];
  BEGIN
   IF sel
    THEN TextColor(CSelectedText)
    ELSE TextColor(CNormalText);
   WITH p^ DO
    BEGIN
     OutStringXY(x+1,Zeile,TextAttr,ganz+'≥');
     CASE art OF
      Datei: BEGIN
              IF size<1E9
               THEN BEGIN {pa·t ins Feld}
                     STR(size:8,s);
                     OutStringXY(x+14,zeile,TextAttr,s+'≥')
                    END
               ELSE OutStringXY(x+14,zeile,TextAttr,
                     LeadingChars((size DIV 1024),' ',7)+'K'+'≥');
             END;
      Laufwerk:OutStringXY(x+14,zeile,TextAttr,#16+' DISK '+#17+'≥');
      Verzeichnis:IF pos('..',Vorname)=0
                   THEN OutStringXY(x+14,zeile,TextAttr,#16+'SUBDIR'+#17+'≥')
                   ELSE OutStringXY(x+14,zeile,TextAttr,#16+'UP-DIR'+#17+'≥')
     END;
     IF art<>Laufwerk
      THEN BEGIN
            UnpackTime(Date,t);
            OutStringXY(x+23,zeile,TextAttr,
                  LeadingChars(t.day,'0',2)+'.'+
                  LeadingChars(t.month,'0',2)+'.'+
                  LeadingChars(t.year,'0',4)+
                  '≥'+
                  LeadingChars(t.hour,'0',2)+':'+
                  LeadingChars(t.min,'0',2));
           END
      ELSE OutStringXY(x+23,zeile,TextAttr,'          ≥     ');
    END;
   IF sel THEN TextColor(CNormalText)
  END;

  PROCEDURE UpdateStatus;
  { in: sizeselected = Grî·e der selektierten Dateien}
  {     anzselected  = #selektierte Dateien}
  {     x+1,letzte-1 = Position fÅr Textausgabe}
  VAR s:STRING[15];
      t:STRING[5];
  BEGIN
   STR(sizeselected:8,s); STR(anzselected:5,t);
   OutStringXY(x+1,letzte-1,BNormalText SHL 4 +CInfoText,
    s+' bytes in'+t+' selected files');
  END;

  PROCEDURE ShowCursorLine;
  { in: erstegezeigte = 1. angezeigte Zeile}
  {     cursorzeile   = Zeile fÅr Cursor (absolut, nicht Bildschirm!)}
  {     x+1,y+3 = Position der 1.Bildschirmzeile fÅr DateieneintrÑge}
  {out: cursorzeile wurde farblich hervorgehoben}
  {rem: Cursorzeile mu· sichtbar sein}
  VAR old:BYTE;
  BEGIN
   old:=TextAttr;
   TextBackground(BCursor);
   WriteLine(cursorzeile-erstegezeigte+y+3,SpeedAccess[cursorzeile],
    selected[cursorzeile]);
   (* HideCursor; *) {nicht mehr nîtig, da kein WRITELN() mehr benutzt!}
   TextAttr:=old
  END;

  PROCEDURE DisplayList;
  { in: speedaccess[0..listlen-1] = Zeiger auf Daten}
  {     erstegezeigte = 1. anzuzeigende Zeile}
  {     cursorzeile   = Zeile fÅr Cursor (absolut, nicht Bildschirm!)}
  {     Textzeilen    = #Zeilen, die anzuzeigen sind}
  {     x+1,y+3       = Anfang fÅr 1.Zeile}
  {rem: cursorzeile mu· auf Schirm sein!}
  VAR i,last:WORD;
  BEGIN
   last:=min(listlen-1,erstegezeigte+Textzeilen-1);
   FOR i:=erstegezeigte TO last DO
    WriteLine(y+(i-erstegezeigte)+3,speedaccess[i],selected[i]);
   FOR i:=succ(last) TO erstegezeigte+Textzeilen-1 DO
    OutStringXY(x+1,y+3+i,TextAttr,'            ≥        ≥          ≥     ≥');
  END;

 BEGIN
  (* nicht mehr nîtig, da kein WRITELN() mehr benutzt!
  ASM
   PUSH DS
   PUSH BP

   MOV AH,$F
   INT $10   {danach: BH=Display page }
   mov ah,3
   int $10   {Cursorposition auslesen }
   POP BP
   POP DS

   mov oldcurs,DX
  END;
  *)

  IF nur_eins
   THEN Textzeilen:=MaxZeilen-4
   ELSE Textzeilen:=MaxZeilen-4-2; {Platz schaffen}
  letzte:=y+MaxZeilen-1;   {letzte Textzeile}
  oldAttr:=TextAttr; {alte Textfarben}

  TextAttr:=BNormalText SHL 4 +CNormalText;
  OutStringXY(x,y,TextAttr,'’ÕÕÕÕÕÕÕÕÕÕÕÕ—ÕÕÕÕÕÕÕÕ—ÕÕÕÕÕÕÕÕÕÕ—ÕÕÕÕÕ∏');
  {Header evtl. zurechtschneiden:}
  Header:=Copy(Header,Length(Header)-(width-2)+1,width-2);
  OutStringXY(x+ (width-Length(Header)) SHR 1,y,TextAttr,Header);
  OutStringXY(x,y+1,TextAttr,'≥    '); TextColor(CInfoText);
  OutStringXY(x+5,y+1,TextAttr,'Name'); TextColor(CNormalText);
  OutStringXY(x+9,y+1,TextAttr,'    ≥  '); TextColor(CInfoText);
  OutStringXY(x+16,y+1,TextAttr,'Size'); TextColor(CNormalText);
  OutStringXY(x+20,y+1,TextAttr,'  ≥   '); TextColor(CInfoText);
  OutStringXY(x+26,y+1,TextAttr,'Date'); TextColor(CNormalText);
  OutStringXY(x+30,y+1,TextAttr,'   ≥ '); TextColor(CInfoText);
  OutStringXY(x+35,y+1,TextAttr,'Time'); TextColor(CNormalText);
  OutCharXY(x+39,y+1,TextAttr SHL 8 +BYTE('≥'));
  OutStringXY(x,y+2,TextAttr,'√ƒƒƒƒƒƒƒƒƒƒƒƒ≈ƒƒƒƒƒƒƒƒ≈ƒƒƒƒƒƒƒƒƒƒ≈ƒƒƒƒƒ¥');
  FOR i:=y+3 TO letzte-3 DO
   BEGIN
    OutCharXY(x,i,TextAttr SHL 8 +BYTE('≥'));
    OutCharXY(x+Width-1,i,TextAttr SHL 8 +BYTE('≥'));
   END;
  IF nur_eins
   THEN BEGIN
         OutCharXY(x,letzte-2,TextAttr SHL 8 +BYTE('≥'));
         OutCharXY(x+Width-1,letzte-2,TextAttr SHL 8 +BYTE('≥'));
        END
   ELSE OutStringXY(x,letzte-2,TextAttr,
         '√ƒƒƒƒƒƒƒƒƒƒƒƒ¡ƒƒƒƒƒƒƒƒ¡ƒƒƒƒƒƒƒƒƒƒ¡ƒƒƒƒƒ¥');
  OutStringXY(x,letzte-1,TextAttr,
   '≥                                      ≥');
  OutStringXY(x,letzte,TextAttr,
   '‘ÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕ');
  OutCharXY(x+39,letzte,TextAttr SHL 8 ++ORD('æ'));

  erstegezeigte:=0; {absolut}
  cursorzeile  :=0; {absolut}
  anzselected  :=0; sizeselected:=0; {noch nichts selektiert}
  IF NOT nur_eins THEN UpdateStatus;

  {Schnellzugriff auf Daten ermîglichen:}
  FillChar(selected,SizeOf(selected),FALSE);
  p:=list;
  FOR i:=0 TO listlen-1 DO
   BEGIN
    speedaccess[i]:=p;
    p:=p^.next
   END;
  DisplayList;
  ShowCursorLine;

  {Jetzt Taste abwarten und geeignet reagieren:}
  REPEAT
   Wahl:=BIOSreadKey;
   ch:=CHAR(Lo(Wahl)); {ASCII-Zeichen}
   CASE Wahl OF
    $4800: {Up}
     IF cursorzeile>0
      THEN BEGIN
            dec(cursorzeile);
            IF cursorzeile<erstegezeigte
	     THEN BEGIN {scrollen nîtig}
                   erstegezeigte:=cursorzeile;
                   DisplayList;
                   ShowCursorLine
                  END
	     ELSE BEGIN {kein scrollen nîtig}
                   WriteLine(Succ(cursorzeile)-erstegezeigte+y+3,
                             SpeedAccess[Succ(cursorzeile)],
                             Selected[Succ(cursorzeile)]);
                   ShowCursorLine
                  END;
           END;
    $5000: {Down}
     IF cursorzeile<Pred(listlen)
      THEN BEGIN
            inc(cursorzeile);
            IF cursorzeile>=erstegezeigte+Textzeilen
	     THEN BEGIN {scrollen nîtig}
                   erstegezeigte:=cursorzeile-Textzeilen+1;
                   DisplayList;
                   ShowCursorLine
                  END
	     ELSE BEGIN {kein scrollen nîtig}
                   WriteLine(Pred(cursorzeile)-erstegezeigte+y+3,
                             SpeedAccess[Pred(cursorzeile)],
                             Selected[Pred(cursorzeile)]);
                   ShowCursorLine
                  END;
           END;
    $4700: {Pos1}
     IF cursorzeile<>0
      THEN BEGIN
            cursorzeile:=0;
            erstegezeigte:=0;
            DisplayList;
            ShowCursorLine
           END;
    $4F00: {End}
     IF cursorzeile<>Pred(listlen)
      THEN BEGIN
            cursorzeile:=Pred(listlen);
            erstegezeigte:=max(INTEGER(cursorzeile-Textzeilen+1),0);
            DisplayList;
            ShowCursorLine
           END;
    $5200: {Insert}
     IF (NOT nur_eins) AND (SpeedAccess[CursorZeile]^.Art=Datei)
      THEN BEGIN
            IF Selected[CursorZeile]
             THEN BEGIN
                   dec(anzselected);
                   dec(sizeselected,SpeedAccess[CursorZeile]^.size)
                  END
	     ELSE BEGIN
                   inc(anzselected);
                   inc(sizeselected,SpeedAccess[CursorZeile]^.size)
                  END;
            Selected[CursorZeile]:=NOT Selected[CursorZeile];
            UpdateStatus;
            {Jetzt noch Cursor um eins nach unten bewegen:}
            IF cursorzeile<Pred(listlen)
             THEN BEGIN
                   inc(cursorzeile);
                   IF cursorzeile>=erstegezeigte+Textzeilen
	            THEN BEGIN {scrollen nîtig}
                          erstegezeigte:=cursorzeile-Textzeilen+1;
                          DisplayList;
                          ShowCursorLine
                         END
	            ELSE BEGIN {kein scrollen nîtig}
                          WriteLine(Pred(cursorzeile)-erstegezeigte+y+3,
                                    SpeedAccess[Pred(cursorzeile)],
                                    Selected[Pred(cursorzeile)]);
                          ShowCursorLine
                         END;
                  END
             ELSE ShowCursorLine
           END;
    $4900: {PgUp}
     IF (max(0,INTEGER(erstegezeigte-TextZeilen))<>CursorZeile)
      THEN BEGIN
            erstegezeigte:=max(0,INTEGER(erstegezeigte-Textzeilen));
            IF erstegezeigte=0
             THEN CursorZeile:=0
             ELSE CursorZeile:=max(0,INTEGER(CursorZeile-Textzeilen));
            DisplayList;
            ShowCursorLine
           END;
    $5100: {PgDn}
     IF (min(Pred(listlen),erstegezeigte+TextZeilen)<>CursorZeile)
      THEN BEGIN
            erstegezeigte:=min(Pred(listlen)-Textzeilen+1,erstegezeigte+TextZeilen);
            IF (erstegezeigte+TextZeilen)=listlen
             THEN CursorZeile:=Pred(listlen)
             ELSE CursorZeile:=min(Pred(listlen),CursorZeile+Textzeilen);
            DisplayList;
            ShowCursorLine
           END;
    $8400: {Ctrl-PgUp}
     BEGIN
      FOR i:=0 TO Pred(listlen) DO
       IF POS('..',SpeedAccess[i]^.Vorname)<>0
	THEN BEGIN {so tun, als hÑtte User auf ".." positioniert und CR gedrÅckt}
              CursorZeile:=i;
              ch:=#13;
              goto quit_CASE
             END;
      sound(1000); delay(70); nosound  {piepsen, da im Rootverzeichnis}
     END;
    $4E2B: {Grey "+"}
     BEGIN
      BoxX:=ScreenX SHR 1 -7; BoxY:=ScreenY SHR 1;

      New(Bild);
      FOR by:=BoxY-1 TO BoxY+1 DO      {Bildausschnitt retten}
       FOR bx:=BoxX-1 TO BoxX+14+1 DO
        Bild^[bx,by]:=GetCharXY(bx,by);

      (* ShowCursor; *) {nicht mehr nîtig, da kein WRITELN() mehr benutzt!}
      oldX:=WhereX; oldY:=WhereY;
      GotoXY(BoxX,BoxY);
      FLAG:=FALSE;
      attr:=TextAttr; TextColor(Black); TextBackground(Cyan);
      BoxGetString(SelUnsel,14,FLAG,'select files:');
      GotoXY(oldX,oldY);
      (* HideCursor; *) {nicht mehr nîtig, da kein WRITELN() mehr benutzt!}
      TextAttr:=attr;

      FOR by:=BoxY-1 TO BoxY+1 DO      {Bildausschnitt wiederherstellen}
       FOR bx:=BoxX-1 TO BoxX+14+1 DO
        OutCharXY(bx,by,Bild^[bx,by]);
      Dispose(Bild);

      IF NOT FLAG
       THEN BEGIN {Liste absuchen nach Muster "SelUnsel"}
             SelUnsel:=Upstring(SelUnsel);
             StripBlanks(SelUnsel);
             FOR i:=0 TO Pred(Listlen) DO
	      BEGIN
               s:=Upstring(SpeedAccess[i]^.ganz);
               StripBlanks(s);
               IF NameCompare(SelUnsel,s)
                THEN BEGIN {Match gefunden!}
                      IF (NOT nur_eins) AND
                         (NOT Selected[i]) AND
                         (SpeedAccess[i]^.Art=Datei)
                       THEN BEGIN
                             inc(anzselected);
                             inc(sizeselected,SpeedAccess[i]^.size);
                             Selected[i]:=TRUE;
                            END;
                      IF nur_eins
                       THEN BEGIN
                             CursorZeile:=i;
                             erstegezeigte:=max(INTEGER(cursorzeile-Textzeilen+1),0);
                             DisplayList;
                             ShowCursorLine;
                             goto break1
                            END;
                     END
              END;
             IF NOT nur_eins
              THEN BEGIN {gefundene farblich anzeigen}
                    DisplayList;
                    UpdateStatus;
                    ShowCursorLine;
                   END
	      ELSE BEGIN {kein einzelnes gefunden}
                    sound(1000); delay(70); nosound
                   END;
             break1:;
            END;

     END;
    $4A2D: {Grey "-"}
     BEGIN
      IF (NOT nur_eins) AND (anzselected>0)
       THEN BEGIN
             BoxX:=ScreenX SHR 1 -7; BoxY:=ScreenY SHR 1;

             New(Bild);
             FOR by:=BoxY-1 TO BoxY+1 DO      {Bildausschnitt retten}
              FOR bx:=BoxX-1 TO BoxX+14+1 DO
               Bild^[bx,by]:=GetCharXY(bx,by);

             (* ShowCursor; *) {nicht mehr nîtig, da kein WRITELN() mehr benutzt!}
             oldX:=WhereX; oldY:=WhereY;
             GotoXY(BoxX,BoxY);
             FLAG:=FALSE;
             attr:=TextAttr; TextColor(Black); TextBackground(Cyan);
             BoxGetString(SelUnsel,14,FLAG,'unselect files:');
             GotoXY(oldX,oldY);
             (* HideCursor; *) {nicht mehr nîtig, da kein WRITELN() mehr benutzt!}
             TextAttr:=attr;

             FOR by:=BoxY-1 TO BoxY+1 DO      {Bildausschnitt wiederherstellen}
              FOR bx:=BoxX-1 TO BoxX+14+1 DO
               OutCharXY(bx,by,Bild^[bx,by]);
             Dispose(Bild);

             IF NOT FLAG
              THEN BEGIN {Liste absuchen nach Muster "SelUnsel"}
                    SelUnsel:=Upstring(SelUnsel);
                    StripBlanks(SelUnsel);
                    FOR i:=0 TO Pred(Listlen) DO
	             BEGIN
                      s:=Upstring(SpeedAccess[i]^.ganz);
                      StripBlanks(s);
                      IF Selected[i] AND
                         (SpeedAccess[i]^.Art=Datei) AND
                         NameCompare(SelUnsel,s)
                       THEN BEGIN {Match gefunden!}
                             dec(anzselected);
                             dec(sizeselected,SpeedAccess[i]^.size);
                             Selected[i]:=FALSE;
                            END;
                     END;
                    DisplayList;
                    UpdateStatus;
                    ShowCursorLine;
                   END;
            END
       ELSE IF anzselected=0
	THEN BEGIN
              sound(1000); delay(70); nosound
             END;
     END;
   END; {of CASE}
  quit_CASE:;
  UNTIL (ch=#13) OR (ch=#27);

  IF (ch=#13)
   THEN last:=SpeedAccess[CursorZeile]
   ELSE last:=NIL;

  IF ch<>#27
   THEN BEGIN {Auswahlliste zusammenstellen}
         DelList(sel); {evtl. alten Inhalt lîschen}
         FOR i:=0 TO Pred(listlen) DO
          IF Selected[i]
	   THEN BEGIN
                 new(temp);
                 temp^:=SpeedAccess[i]^;
                 IF sel=NIL
                  THEN BEGIN
                        sel:=temp;
                        p:=sel
                       END
                  ELSE BEGIN
                        p^.next:=temp;
                        p:=temp
                       END
                END;
         IF sel<>NIL THEN p^.next:=NIL
        END;

  CursSelected:=Selected[CursorZeile];

  (* ShowCursor; *) {nicht mehr nîtig, da kein WRITELN() mehr benutzt!}
  TextAttr:=oldAttr;
 END;



 PROCEDURE add(VAR list:PDateiName; VAR listlen:WORD;
               elem:TAlles; typ:TArt; Groesse:TSize; Datum:TDate);
 CONST Blanks12='            '; {mindestens SizeOf(TAlles) =8+1+3 Blanks}
 VAR p,temp:PDateiName;
     po:BYTE;
 BEGIN
  IF elem='.' THEN exit; {aktuelles Verzeichnis nicht speichern}
  new(temp);
  WITH temp^ DO
   BEGIN
    art:=typ;
    size:=Groesse;
    date:=Datum;
    IF typ=Laufwerk
     THEN BEGIN
           Vorname:=elem+COPY(Blanks12,1,SizeOf(TName)-Length(elem));
           Punkt:=' ';
           Nachname:='   ';
          END
     ELSE BEGIN
           IF POS('..',elem)<>0
	    THEN BEGIN {Updir}
                  Vorname:=' ..'+COPY(Blanks12,1,SizeOf(TName)-length(' ..'));
                  Punkt:=' ';
                  Nachname:='   '
                 END
            ELSE BEGIN
                  po:=pos('.',elem+'.');
                  Vorname:=COPY(elem,1,pred(po))
                          +COPY(Blanks12,1,SizeOf(TName)-pred(po));
                  IF po<=length(elem)
	           THEN BEGIN
                         Punkt:='.';
                         Nachname:=COPY(elem,succ(po),length(elem)-po)
                          +COPY(Blanks12,1,SizeOf(TExten)-(length(elem)-po));
                        END
	           ELSE BEGIN
                         Punkt:=' '; Nachname:='   '
                        END;
                 END;
          END;
    ganz:=Vorname+Punkt+Nachname;
   END;

  IF list=NIL
   THEN BEGIN {neue Liste}
         list:=temp;
         temp^.next:=NIL;
         listlen:=1
        END
  ELSE IF (temp^.ganz<list^.ganz) OR (temp^.Art<list^.Art)
   THEN BEGIN {am Anfang der Liste einfÅgen}
         temp^.next:=list;
         list:=temp;
         inc(listlen)
        END
  ELSE  BEGIN {irgendwo zwischendrin}
         p:=list;
         {suche richtige "Sparte": Laufwerk/Verzeichnis/Typ:}
         WHILE (p^.next<>NIL) AND (temp^.Art>p^.next^.Art) DO p:=p^.next;
         {neue Sparte aufmachen oder in richtiger Sparte suchen?}
         IF (p^.next<>NIL) AND (temp^.Art=p^.next^.Art)
          THEN WHILE (p^.next<>NIL) AND (temp^.Art=p^.next^.Art)
                AND (temp^.ganz>=p^.next^.ganz) DO p:=p^.next;
         IF (temp^.ganz<>p^.ganz) OR (temp^.Art<>p^.Art) {doppelte vermeiden}
	  THEN BEGIN
                temp^.next:=p^.next; {einfÅgen von temp nach p}
                p^.next:=temp;
                inc(listlen)
               END;
        END;
 END;

 PROCEDURE NormalizePath(VAR p:TPath);
 VAR i:BYTE;
 BEGIN
  FOR i:=length(p) DOWNTO 1 DO
   IF p[i]=' ' THEN Delete(p,i,1);
  IF p[length(p)]<>'\' THEN p:=p+'\'
 END;

 PROCEDURE MakeFileList(VAR p:TPath; typ:STRING;
                        VAR list:PDateiName; VAR listlen:WORD;
                        VAR error:BOOLEAN);
 { in: Laufwerke = String mit LW im System}
 {     p = Suchpfad zum Verzeichnis, z.B.: "C:\TURBO6\"}
 {     typ = Suchmaske(n), mit Blanks getrennt, z.B.: "*.pas *.bak"}
 {     list = NIL (ansonsten wird Liste gelîscht)}
 {out: p = evtl. normierter Pfad}
 {     list = Liste der gefundenen Dateien}
 {     listlen = Anzahl EintrÑge in dieser Liste}
 {     error = TRUE, falls ungewîhnlicher Fehler auftrat (Pfad ex. nicht o.Ñ.)}
 {             Kann i.d.R. aber ignoriert werden, da Schachtel eh nur gÅltige }
 {             EintrÑge zur Auswahl stellt!}
 VAR dirinfo:SearchRec;
     i,anzahl:word;
     temp:TAlles;
     po:BYTE;
     name:TPath;
     originalINT24h:POINTER;
 BEGIN
  GetIntVec($24,originalINT24h); {momentanen CriticalErrHandler" retten  }
  SetIntVec($24,SaveInt24);      {auf TP's "CriticalErrHandler" umstellen}
  NormalizePath(p);
  DelList(list);
  listlen:=0;
  IF typ='' THEN typ:='*.*';
  IF (length(p)=0) OR (p[length(p)]<>'\') THEN p:=p+'\';
  IF typ[length(typ)]<>' ' THEN typ:=typ+' ';
  {Dateien suchen:}
  WHILE typ>'' DO
   BEGIN
    po:=pos(' ',typ);
    name:=p+copy(typ,1,pred(po)); delete(typ,1,po);
    findfirst(Name,Archive OR SysFile OR Hidden OR Readonly,dirinfo);
    WHILE (doserror=0) DO
     BEGIN
      IF (dirinfo.attr AND (VolumeID OR Directory))=0
       THEN add(list,listlen,LoString(dirinfo.name),Datei,dirinfo.size,dirinfo.time);
      FindNext(dirinfo)
     END;
    error:=NOT (doserror in [0,2,18]); {ok|keine Datei gefunden|alle durch}
   END;

  {Nun Verzeichnisse eintragen:}
  name:=p+'*.*';
  findfirst(Name,Directory,dirinfo);
  WHILE (doserror=0) DO
   BEGIN
    IF (dirinfo.attr AND Directory)<>0
     THEN add(list,listlen,UpString(dirinfo.name),Verzeichnis,dirinfo.size,dirinfo.time);
    FindNext(dirinfo)
   END;
  error:=error OR NOT (doserror in [0,2,18]);

  {Jetzt noch evtl. Laufwerke mitaufnehmen:}
  IF length(p)<=3
   THEN BEGIN {Rootverzeichnis, deshalb Laufwerke mitaufnehmen}
         FOR i:=1 TO length(Laufwerke)
          DO add(list,listlen,' '+Laufwerke[i]+':',Laufwerk,0,0);
        END
   ELSE add(list,listlen,' '+'..',Verzeichnis,0,0); {ansonsten Updir mitaufnehmen}
  SetIntVec($24,originalINT24h);
 END;

 FUNCTION ChooseSingleFile(xpos,ypos,max_zeilen:BYTE;
                           Pf:TPath; typ:STRING; VAR error:BOOLEAN):TPath;
 { in: xpos,ypos =li. obere Ecke der Auswahlbox}
 {     max_zeilen=Zeilen fÅr Auswahlbox}
 {     Pf  =Anfangsverzeichnis fÅr Suche, z.B.: "C:\DOS\"}
 {     typ =Filemaske(n), durch Blank getrennt, z.B.: "*.BAT *.PAS"}
 {     Laufwerke = Disks im System, z.B.: 'ABC'}
 {out: Name des selektierten Files oder '' fÅr keines (=Abbruch per ESC)}
 {     error = TRUE, falls ungewîhnlicher Dos-Fehler auftrat}
 {             Kann i.d.R. aber ignoriert werden, da Schachtel eh nur gÅltige }
 {             EintrÑge zur Auswahl stellt!}
 {rem: ab xpos mÅssen 40 Spalten zur VerfÅgung stehen,}
 {     ab ypos mÅssen MaxZeilen zur VerfÅgung stehen, }
 {     Max_Zeilen>6}
 {     Bildschirm wird *nicht* gerettet/gelîscht!}
 {     Es wird nur der *Name* zurÅckgegeben, keine zusÑtzlichen Angaben wie}
 {     Grî·e, Datum, etc. Dazu mÅ·te man den ganzen Record "letztes" (s.u.)}
 {     zurÅckgeben!}
 LABEL quit;
 VAR liste,letztes,gewaehlte:PDateiName;
     listlen:WORD;
     p:BYTE;
     CursInList:BOOLEAN;
     Pfad:TPath;
 BEGIN
  liste:=NIL; letztes:=NIL; gewaehlte:=NIL;
  Pfad:=Pf; {MakeFileListe() will VAR-Typ!}
  REPEAT
   MakeFileList(Pfad, typ, liste, listlen,error);
   Auswahl(xpos,ypos,max_zeilen,Pfad+typ,liste,listlen,TRUE,letztes,gewaehlte,CursInList);
   (*
   IF error
    THEN BEGIN {bei Fehler: Schnellausstieg}
          ChooseSingleFile:='';
          goto quit
         END;
   *)
   IF letztes<>NIL
    THEN BEGIN
          CASE letztes^.Art OF
           Laufwerk:Pfad:=letztes^.ganz;
           Verzeichnis:
            IF POS('..',letztes^.Vorname)=0
	     THEN BEGIN {runter im Verzeichnispfad}
                   IF Pfad[length(Pfad)]<>'\' THEN Pfad:=Pfad+'\';
                   Pfad:=Pfad+letztes^.ganz
                  END
	     ELSE BEGIN {hoch im Verzeichnispfad}
                   IF Pfad[length(Pfad)]='\'
                    THEN Delete(Pfad,length(Pfad),1);
                   p:=length(Pfad);
                   WHILE (Pfad[p]<>'\') AND (p>0) DO dec(p);
                   IF p=0
                    THEN write(#7)  {sind schon auf der Root}
                    ELSE Delete(Pfad,succ(p),length(Pfad)-p)
                  END;
          END; {of CASE}
         END;
  UNTIL (letztes=NIL) OR (letztes^.Art=Datei);

  IF letztes=NIL
   THEN ChooseSingleFile:=''
   ELSE BEGIN
         StripBlanks(letztes^.ganz);
         ChooseSingleFile:=Pfad+letztes^.ganz;
        END;

 quit:;
  DelList(Liste);
  DelList(gewaehlte); {nur der Ordnung halber, ist eh leer}
 END;

 FUNCTION ChooseMultipleFiles(xpos,ypos,max_zeilen:BYTE;
                              VAR Pfad:TPath; typ:STRING;
                              VAR error:BOOLEAN):PDateiname;
 { in: xpos,ypos =li. obere Ecke der Auswahlbox}
 {     max_zeilen=Zeilen fÅr Auswahlbox}
 {     Pf  =Anfangsverzeichnis fÅr Suche, z.B.: "C:\DOS\"}
 {     typ =Filemaske(n), durch Blank getrennt, z.B.: "*.BAT *.PAS"}
 {     Laufwerke = Disks im System, z.B.: 'ABC'}
 {out: Zeiger auf selektierte Files oder NIL fÅr keine (=Abbruch per ESC)}
 {     Pfad = Pfadname zu den selektierten Dateien}
 {     error = TRUE, falls ungewîhnlicher Dos-Fehler auftrat}
 {             Kann i.d.R. aber ignoriert werden, da Schachtel eh nur gÅltige }
 {             EintrÑge zur Auswahl stellt!}
 {rem: ab xpos mÅssen 40 Spalten zur VerfÅgung stehen,}
 {     ab ypos mÅssen MaxZeilen zur VerfÅgung stehen, }
 {     Max_Zeilen>6}
 {     Bildschirm wird *nicht* gerettet/gelîscht!}
 {     Die Namen der selektierten Dateien wurden von ÅberflÅssigen Blanks}
 {     befreit}
 LABEL quit;
 VAR liste,letztes,gewaehlte:PDateiName;
     listlen:WORD;
     p:BYTE;
     CursInList:BOOLEAN;
 BEGIN
  liste:=NIL; letztes:=NIL; gewaehlte:=NIL;
  REPEAT
   MakeFileList(Pfad, typ, liste, listlen, error);
   Auswahl(xpos,ypos,max_zeilen,Pfad+typ,liste,listlen,FALSE,letztes,gewaehlte,CursInList);
   (*
   IF error
    THEN BEGIN {bei Fehler: Schnellausstieg}
          ChooseMultipleFiles:=NIL;
          goto quit
         END;
   *)
   IF letztes<>NIL
    THEN BEGIN
          CASE letztes^.Art OF
           Laufwerk:Pfad:=letztes^.ganz;
           Verzeichnis:
            IF POS('..',letztes^.Vorname)=0
	     THEN BEGIN {runter im Verzeichnispfad}
                   IF Pfad[length(Pfad)]<>'\' THEN Pfad:=Pfad+'\';
                   Pfad:=Pfad+letztes^.ganz
                  END
	     ELSE BEGIN {hoch im Verzeichnispfad}
                   IF Pfad[length(Pfad)]='\'
                    THEN Delete(Pfad,length(Pfad),1);
                   p:=length(Pfad);
                   WHILE (Pfad[p]<>'\') AND (p>0) DO dec(p);
                   IF p=0
                    THEN write(#7)  {sind schon auf der Root}
                    ELSE Delete(Pfad,succ(p),length(Pfad)-p)
                  END;
          END; {of CASE}
         END;
  UNTIL (letztes=NIL) OR (letztes^.Art=Datei);

  IF letztes=NIL
   THEN ChooseMultipleFiles:=NIL  {Abbruch per ESC}
   ELSE BEGIN
         ChooseMultipleFiles:=gewaehlte;
         WHILE gewaehlte<>NIL DO
          BEGIN
           StripBlanks(gewaehlte^.ganz);
           gewaehlte:=gewaehlte^.next
          END
        END;

 quit:;
  DelList(Liste);
 END;

{$IFDEF test}
VAR liste,letztes,gewaehlte:PDateiName;
    listlen:WORD;
    Pfad:TPath;
    error:BOOLEAN;
{$ENDIF}
begin
 Laufwerke:='';
 Laufwerke:='AB'+Festplatten_im_System;
 DetectXYresolution(ScreenX,ScreenY);
 Basis:=BaseAddress;

{$IFDEF test}
 clrscr;
 WRITELN(ChooseSingleFile(41,1,ScreenY,'C:\','*.EXE *.COM *.BAT',error));
 WRITELN('(Fehler: ',error,')');
 READLN;
 ClrScr;
 Pfad:='C:\';
 liste:=ChooseMultipleFiles(5,1,ScreenY,Pfad,'*.EXE *.COM *.BAT',error);
 IF liste<>NIL
  THEN BEGIN
        WRITELN('Pfad: ',Pfad);
        WriteList(liste)
       END;
 WRITELN; WRITELN('(Fehler: ',error,')');
 DelList(liste);
{$ENDIF}
end.

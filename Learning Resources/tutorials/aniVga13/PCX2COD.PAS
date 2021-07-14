{$DEFINE StackCheck}
{$DEFINE test}

{$IFDEF test}
  {$A+,B-,D+,E-,F-,G-,I+,L+,N-,O-,R+,S+,V+,X-}
  {$M 16384,0,655360}
{$ELSE}
  {$A+,B-,D+,E-,F-,G-,I-,L+,N-,O-,R-,S-,V-,X-}
  {$M 16384,150000,655360}
{$ENDIF}

PROGRAM PCX_to_COD_and_PIC_converter;

USES Dos,Graph,crt,Eingaben,Dateien;
const
      MausMinX=0;     {Koordinatenbereich fÅr Maus}
      MausMinY=0;
      MausMaxX:INTEGER=0;
      MausMaxY:INTEGER=0;
      MausMaxX_mul2:INTEGER=0;
      MausMaxY_mul2:INTEGER=0;

      SVGA320x200x256	= 0;	(* 320x200x256 Standard VGA *)
      SVGA640x400x256	= 1;	(* 640x400x256 Svga *)
      SVGA640x480x256	= 2;	(* 640x480x256 Svga *)
      SVGA800x600x256	= 3;	(* 800x600x256 Svga *)
      SVGA1024x768x256	= 4;	(* 1024x768x256 Svga *)

CONST EventNone=0;                 {gar nix}
      EventError=1;                {Fehler }
      EventQuit=2;                 {Programm vielleicht beenden}
      EventHelp=9;                 {Hilfe}
      EventMouseMoved=17;          {Maus wurde bewegt}
      EventEndProgram=41;          {Programm tatsÑchlich beenden}
      EventSpeichern=100;          {ausgewÑhlten Grafikbereich abspeichern}

{---------Menu-Felder---------}

TYPE DrawBox=PROCEDURE;
     box=RECORD  {Datentyp fÅr ein Menufeld:}
          x1,y1,                 {obere linke Boxecke}
          x2,y2:WORD;            {untere rechte Ecke }
          Name1,Name2:STRING[8]; {Beschriftung 1.+2.Zeile}
          Show :DrawBox;         {Routine zum anzeigen des Icons}
          Event:BYTE;            {zurÅckzugebender Wert}
          Click:BOOLEAN;         {mu· Maus geclickt werden fÅr Event?}
          Paint:BOOLEAN;         {Flag, ob Box zu zeichnen ist}
         END;
     boxes=ARRAY[1..3] OF box;  {alle Menufelder zusammen}

     ButtonStringTyp=STRING[8];  {Meldung in Clickboxen}

PROCEDURE Dummy; FAR; BEGIN END;

CONST Menu:boxes=(

 {gesamter Mausbereich kann auch als "Menubox" realisiert werden:}
       (x1:MausMinX;    y1:MausMinY;
        x2:0 {MausMaxX};    y2:0 {MausMaxY};
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventMouseMoved;
        Click:FALSE;    {kein Anclicken nîtig}
        Paint:FALSE),   {...wird aber nicht gezeichnet}

 {Sentinelwert, da x1>x2!}
       (x1:1; y1:0; x2:0; y2:0;    
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventNone;
        Click:TRUE;
        Paint:TRUE),

 {Noch einer als FÅller, x1>x2!}
       (x1:1; y1:0; x2:0; y2:0;    
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventNone;
        Click:TRUE;
        Paint:TRUE)
      );

VAR event:BYTE;
    CRTAddress,      {Adresse des CRT-Ports, $3B4/$3D4 fuer monochrom/Farbe}
    StatusReg:WORD;  {dto., fuer Statusregister, $3BA/$3DA}
    Shift:BOOLEAN;   {gibt wieder, ob wÑhrend Auswertung Shift gedrÅckt war}
    BestWhite,       {Beste NÑherungen der angeg. Farben}
    BestBlack,
    BestCyan,
    BestLightGray,
    BestDarkGray:BYTE;
    MeldungX,MeldungY:INTEGER;

{-------------------- Ziffernausgabe ------------------}
TYPE Ziffer=ARRAY[0..6,0..7] OF BYTE;
     ToldArea=ARRAY[0..9*8,0..7] OF BYTE;
CONST Ziffern:ARRAY['0'..'9'] OF Ziffer=
(
((0,1,1,1,1,1,0,0),
 (1,1,0,0,0,1,1,0),
 (1,1,0,0,1,1,1,0),
 (1,1,0,1,1,1,1,0),
 (1,1,1,1,0,1,1,0),
 (1,1,1,0,0,1,1,0),
 (0,1,1,1,1,1,0,0)),

((0,0,1,1,0,0,0,0),
 (0,1,1,1,0,0,0,0),
 (0,0,1,1,0,0,0,0),
 (0,0,1,1,0,0,0,0),
 (0,0,1,1,0,0,0,0),
 (0,0,1,1,0,0,0,0),
 (1,1,1,1,1,1,0,0)),

((0,1,1,1,1,0,0,0),
 (1,1,0,0,1,1,0,0),
 (0,0,0,0,1,1,0,0),
 (0,0,1,1,1,0,0,0),
 (0,1,1,0,0,0,0,0),
 (1,1,0,0,1,1,0,0),
 (1,1,1,1,1,1,0,0)),

((0,1,1,1,1,0,0,0),
 (1,1,0,0,1,1,0,0),
 (0,0,0,0,1,1,0,0),
 (0,0,1,1,1,0,0,0),
 (0,0,0,0,1,1,0,0),
 (1,1,0,0,1,1,0,0),
 (0,1,1,1,1,0,0,0)),

((0,0,0,1,1,1,0,0),
 (0,0,1,1,1,1,0,0),
 (0,1,1,0,1,1,0,0),
 (1,1,0,0,1,1,0,0),
 (1,1,1,1,1,1,1,0),
 (0,0,0,0,1,1,0,0),
 (0,0,0,1,1,1,1,0)),

((1,1,1,1,1,1,0,0),
 (1,1,0,0,0,0,0,0),
 (1,1,1,1,1,0,0,0),
 (0,0,0,0,1,1,0,0),
 (0,0,0,0,1,1,0,0),
 (1,1,0,0,1,1,0,0),
 (0,1,1,1,1,0,0,0)),

((0,0,1,1,1,0,0,0),
 (0,1,1,0,0,0,0,0),
 (1,1,0,0,0,0,0,0),
 (1,1,1,1,1,0,0,0),
 (1,1,0,0,1,1,0,0),
 (1,1,0,0,1,1,0,0),
 (0,1,1,1,1,0,0,0)),

((1,1,1,1,1,1,0,0),
 (1,1,0,0,1,1,0,0),
 (0,0,0,0,1,1,0,0),
 (0,0,0,1,1,0,0,0),
 (0,0,1,1,0,0,0,0),
 (0,0,1,1,0,0,0,0),
 (0,0,1,1,0,0,0,0)),

((0,1,1,1,1,0,0,0),
 (1,1,0,0,1,1,0,0),
 (1,1,0,0,1,1,0,0),
 (0,1,1,1,1,0,0,0),
 (1,1,0,0,1,1,0,0),
 (1,1,0,0,1,1,0,0),
 (0,1,1,1,1,0,0,0)),

((0,1,1,1,1,0,0,0),
 (1,1,0,0,1,1,0,0),
 (1,1,0,0,1,1,0,0),
 (0,1,1,1,1,1,0,0),
 (0,0,0,0,1,1,0,0),
 (0,0,0,1,1,0,0,0),
 (0,1,1,1,0,0,0,0))
);

FUNCTION min(a,b:INTEGER):INTEGER;
BEGIN
 IF a<=b THEN min:=a ELSE min:=b
END;

FUNCTION max(a,b:INTEGER):INTEGER;
BEGIN
 IF a>=b THEN max:=a ELSE max:=b
END;

FUNCTION min3(a,b,c:INTEGER):INTEGER;
BEGIN
 min3:=min(a,min(b,c))
END;

FUNCTION max3(a,b,c:INTEGER):INTEGER;
BEGIN
 max3:=max(a,max(b,c))
END;

PROCEDURE PrintXY(x,y,a,b:INTEGER; VAR oldP:ToldArea);
VAR n,i,j:INTEGER;
    s:STRING[8];
BEGIN
 FOR i:=Max(0,x) TO Min(x+9*8-1,GetMaxX) DO
  FOR j:=Max(0,y) TO Min(y+7,GetMaxY) DO
   oldP[i-x,j-y]:=GetPixel(i,j);

 Str(a,s);
 FOR n:=1 TO Length(s) DO
  FOR j:=0 TO 6 DO
   BEGIN
    FOR i:=0 TO 7 DO
     IF (Ziffern[s[n]][j,i]=1)
       THEN PutPixel(x+i +Pred(n) SHL 3,y+j,BestWhite)
   END;

 INC(x,Length(s) SHL 3 +4);
 Str(b,s);
 FOR n:=1 TO Length(s) DO
  FOR j:=0 TO 6 DO
   BEGIN
    FOR i:=0 TO 7 DO
     IF (Ziffern[s[n]][j,i]=1)
       THEN PutPixel(x+i +Pred(n) SHL 3,y+j,BestWhite)
   END;
END;

{----------Maus-Routinen----------}
CONST MouseMoved=1;
      LeftButtonPressed=2;
      LeftButtonReleased=4;
      RightButtonPressed=8;
      RightButtonReleased=16;
      SuppressMouse:BOOLEAN=FALSE;
VAR   Aufrufmaske,Maustasten:WORD;
      MausX,MausY,MausXalt,MausYalt:INTEGER;
      mouseX2,mouseY2:INTEGER; {interne Mauskoordinaten}
      oldMouse:RECORD
                BoxLeft,BoxRight,BoxTop,BoxBottom :ARRAY[0..1023] OF BYTE;
                {Speicher fÅr Windowbox}
                oldX,oldY:WORD;   {alte Mauskoordinaten}
                breite,hoehe:WORD;  {des Fensters}
                oldP:ToldArea;
               END;
      MouseUpdate:BOOLEAN;
      LeftButton,RightButton:BOOLEAN;
      regs:REGISTERS;


FUNCTION MouseEvent(VAR menu):BYTE;
{ in: MausX,MausY = aktuelle Mausposition}
{     LeftButton, RightButton = TRUE, wenn Mausbutton gedrÅckt}
{     Shift = TRUE, falls Shifttaste wÑhrend des Mausclicks gedrÅckt  }
{             worden ist}
{     menu = Array vom Typ "boxes", das die Menuboxkoordinaten enthÑlt}
{     EventNone = RÅckgabewert, falls Maus in keinem der Felder steht }
{out: Der Index desjenigen "menu"-Eintrages, in dem die Maus steht;   }
{     sollte dies keiner sein, so wird "EventNone"=0 zurÅckgegeben    }
{rem: Das Ende der MenueintrÑge mu· durch einen Eintrag mit x1>x2 an- }
{     gegeben werden!}
VAR i:BYTE;
    a:boxes ABSOLUTE menu;
BEGIN
 i:=1;
 WHILE (a[i].x1<=a[i].x2) DO
  BEGIN
   WITH a[i] DO
   IF (x1<=MausX) AND (MausX<=x2) AND (y1<=MausY) AND (MausY<=y2)
      AND ( (NOT click) OR (LeftButton OR RightButton) )
    THEN BEGIN
          MouseEvent:=Event;
          exit
         END
    ELSE INC(i)
   END;
 MouseEvent:=EventNone;
END;

PROCEDURE DrawMaus;
{ in: MausX,MausY = Koordinaten fÅr Mauscursor}
{     MausXalt,MausYalt = Koord. des vorherigen Aufrufs}
{     oldMouse.Box* = Platz fÅr Grafikausschnitt unter Mauscursor}
{out: oldMouse.* = gerettete Grafikdaten}
{rem: Der Speicherplatz MouseMem^ mu· bereits reserviert worden sein  }
{     Obwohl die Routine "Cursor" nicht verÑndert, wird als VAR-Para- }
{     meter Åbergeben, da dann nur ein Zeiger Åbergeben wird!}
VAR i,oldX2,oldY2:WORD;
    diff:INTEGER;
BEGIN
 WITH oldMouse DO
  BEGIN
   oldx:=MausX;  oldY:=MausY;
   diff:=GetMaxX-(MausX+breite-1);
   IF diff<0 THEN inc(breite,diff);
   diff:=GetMaxY-(MausY+hoehe-1);
   IF diff<0 THEN inc(hoehe,diff);
   IF breite<1 THEN breite:=1;
   IF hoehe<1 THEN hoehe:=1;
   PrintXY(oldX+1,oldY+1,breite,hoehe,oldP);

   oldx2:=MausX+breite-1; oldY2:=MausY+hoehe-1;
   FOR i:=oldX TO oldX2 DO
    BEGIN
     BoxTop[i]:=GetPixel(i,oldY);
     BoxBottom[i]:=GetPixel(i,oldY2);
     IF Odd(i)
      THEN BEGIN
            PutPixel(i,oldY,BestWhite);
            PutPixel(i,oldY2,BestWhite)
           END
      ELSE BEGIN
            PutPixel(i,oldY,BestBlack);
            PutPixel(i,oldY2,BestBlack)
           END
    END;
   FOR i:=oldY+1 TO oldY2-1 DO
    BEGIN
     BoxLeft[i]:=GetPixel(oldX,i);
     BoxRight[i]:=GetPixel(oldX2,i);
     IF Odd(i)
      THEN BEGIN
            PutPixel(oldX,i,BestWhite);
            PutPixel(oldX2,i,BestWhite)
           END
      ELSE BEGIN
            PutPixel(oldX,i,BestBlack);
            PutPixel(oldX2,i,BestBlack)
           END
    END;

  END;
END;

PROCEDURE UnDrawMaus;
{ in: oldMouse.* = zu restaurierende Grafikdaten}
VAR i,j,oldX2,oldY2:WORD;
BEGIN
 WITH oldMouse DO
  BEGIN
   oldX2:=oldX+breite-1; oldY2:=oldY+hoehe-1;
   FOR i:=oldX TO oldX2 DO
    BEGIN
     PutPixel(i,oldY,BoxTop[i]);
     PutPixel(i,oldY2,BoxBottom[i])
    END;
   FOR i:=oldY+1 TO oldY2-1 DO
    BEGIN
     PutPixel(oldX,i,BoxLeft[i]);
     PutPixel(oldX2,i,BoxRight[i])
    END;
   FOR i:=Max(0,oldX+1) TO Min(oldX+1+9*8-1,GetMaxX) DO
    FOR j:=Max(0,oldY+1) TO Min(oldY+1+7,GetMaxY) DO
     PutPixel(i,j,oldP[i-(oldX+1),j-(oldY+1)]);
  END;
END;

FUNCTION MouseInstalled : Boolean;
{ in: - }
{out: TRUE|FALSE fÅr: Maus gefunden/nicht gefunden}
VAR INT33h:POINTER;
BEGIN
 GetIntVec($33,INT33h);
 IF (BYTE(INT33h^)=$CF) OR (LONGINT(INT33h)=0)
  THEN MouseInstalled:=FALSE  {nur IRET oder Nullpointer}
  ELSE BEGIN {INT33h fÅhrt nicht ins Nirwana, trau dich!}
        WRITELN(10);
     (* regs.ax := 0;   {Ja hallo, gibt's hier ne Maus im System?}
        Intr($33,regs);
        MouseInstalled:=(regs.ax=$FFFF); *)
        ASM
          PUSHF
          CLI
          PUSH BX
          PUSH CX
          PUSH DX
          PUSH SI
          PUSH DI
          PUSH BP
          PUSH ES
          PUSH DS

          mov ax,0
          int 33h

          POP DS
          POP ES
          POP BP
          POP DI
          POP SI
          POP DX
          POP CX
          POP BX
          STI
          POPF

          CMP AX,$FFFF
          JNE @noMouse
          MOV @Result,TRUE
          JMP @done
         @noMouse:
          MOV @Result,FALSE
         @done:
        END;
        WRITELN(9);
       END;
END;

PROCEDURE DisableMouse;
inline($B0/<BYTE(TRUE)/     {MOV AL,TRUE}
       $A2/SuppressMouse);  {MOV SuppressMouse,AL}

PROCEDURE EnableMouse;
inline($B0/<BYTE(FALSE)/    {MOV AL,FALSE}
       $A2/SuppressMouse);  {MOV SuppressMouse,AL}

PROCEDURE ClearMouse;
BEGIN
 MouseUpdate:=FALSE; LeftButton:=FALSE; RightButton:=FALSE;
 EnableMouse;
END;

{$S-}
PROCEDURE MouseCallBack; FAR; ASSEMBLER;
{ in: mouseX2,mouseY2 = alte Mauskoordinaten}
{     SuppressMouse = TRUE falls Mausereignis ignoriert werden soll}
{     MausMinX,MausMinY = minimal zulÑssige Mauskoordinaten}
{     MausMaxX,MausMaxY = maximal zulÑssige Mauskoordinaten}
{out: Falls SuppressMouse=FALSE war, wurden folgende Variablen neugesetzt:}
{     MouseUpdate = TRUE}
{     MPressed = TRUE, falls linker Button gedrÅckt}
{     Shift = TRUE, falls eine der Shifttasten gedrÅckt wurde}
{     MausX,MausY = aktuelle Mauskoordinaten}
{     SuppressMouse = TRUE}
{rem: Diese Prozedur entspricht einer Interrupt-Service-Routine, die}
{     immer dann aufgerufen wird, wenn eine der bei ihrer Initialisierung}
{     angegebenen Aufrufbedingungen erfÅllt ist}
{     MouseUpdate = TRUE impliziert SuppressMouse:=TRUE, d.h.: die weitere}
{     Aktualisierung von Mausdaten ist solange gesperrt, bis die alten   }
{     verarbeitet wurden und die Maus mit "EnableMouse()" wieder freige- }
{     geben wird!}
ASM
  pushf
  push ax
  push bx
  push cx
  push dx
  push si
  push di
  push bp
  push ds
  push es
  mov bp,SEG @DATA
  mov DS,bp

  CMP SuppressMouse,TRUE {soll Maus Åberhaupt behandelt werden?}
  JE @quit

  MOV AufrufMaske,AX
  MOV MausTasten,BX
  MOV SI,MausX
  MOV MausXalt,SI
  MOV MausX,CX
  MOV SI,MausY
  MOV MausYalt,SI
  MOV MausY,DX

  MOV MouseUpdate,TRUE
  MOV DX,AX
  AND AX,LeftButtonPressed
  JE @noLeftButton
  MOV LeftButton,TRUE
 @noLeftButton:
  AND DX,RightButtonPressed
  JE @noRightButton
  MOV RightButton,TRUE
 @noRightButton:

  XOR AX,AX       {Shift-Status der Tastatur auslesen:}
  MOV ES,AX       {steht in mem[$40:$17] in den untersten 2 Bits}
  MOV SI,417h
  MOV AL,ES:[SI]
  AND AL,3
  JE @noShift
  MOV Shift,TRUE
  JMP @L1
 @noShift:
  MOV Shift,FALSE

 @L1:
  MOV AX,11
  INT 33h         {KoordinatenÑnderung einlesen}
  MOV AX,mouseX2  {und Mauskoordinaten aktualisieren}
  ADD AX,CX
  CMP AX,MausMinX*2  {mouseX2:=max(MausMinX*2,mouseX2)}
  JGE @noSmall1
  MOV AX,MausMinX*2
 @noSmall1:
  CMP AX,MausMaxX_mul2  {mouseX2:=min(MausMaxX*2,mouseX2)}
  JLE @noBig1
  MOV AX,MausMaxX_mul2
 @noBig1:
  MOV mouseX2,AX
  SHR AX,1        {dem doofen Treiber doch noch eine Auflîsung}
  MOV MausX,AX    {von 640x400 Punkten abringen}

  MOV AX,mouseY2
  ADD AX,DX
  CMP AX,MausMinY*2  {mouseY2:=max(MausMinY*2,mouseY2)}
  JGE @noSmall2
  MOV AX,MausMinY*2
 @noSmall2:
  CMP AX,MausMaxY_mul2  {mouseY2:=min(MausMaxY*2,mouseY2)}
  JLE @noBig2
  MOV AX,MausMaxY_mul2
 @noBig2:
  MOV mouseY2,AX
  SHR AX,1
  MOV MausY,AX

  MOV SuppressMouse,TRUE

 @quit:
  pop es
  pop ds
  pop bp
  pop di
  pop si
  pop dx
  pop cx
  pop bx
  pop ax
  popf
END;
{$IFDEF StackCheck} {$S+} {$ENDIF}

PROCEDURE PushAll;
INLINE(
  $9C/   { PUSHF     }
  $50/   { PUSH   AX }
  $53/   { PUSH   BX }
  $51/   { PUSH   CX }
  $52/   { PUSH   DX }
  $56/   { PUSH   SI }
  $57/   { PUSH   DI }
  $55/   { PUSH   BP }
  $06/   { PUSH   ES }
  $1E);  { PUSH   DS }

PROCEDURE PopAll;
INLINE(
  $1F/   { POP    DS }
  $07/   { POP    ES }
  $5D/   { POP    BP }
  $5F/   { POP    DI }
  $5E/   { POP    SI }
  $5A/   { POP    DX }
  $59/   { POP    CX }
  $5B/   { POP    BX }
  $58/   { POP    AX }
  $9D);  { POPF      }

FUNCTION LeftButtonStillPressed:BOOLEAN; ASSEMBLER;
{ in: - }
{out: TRUE, falls linker Button noch immer gedrÅckt}
ASM
  PUSHF
  PUSH BP
  PUSH DS
  MOV DI,OFFSET(@RestoreSS)
  MOV CS:[DI+1],SS
  MOV DI,OFFSET(@RestoreSP)
  MOV CS:[DI+1],SP

  mov ax,5
  mov bx,0
  int 33h
  and ax,1

  @RestoreSS:
  MOV SP,1234h
  MOV SS,SP
  @RestoreSP:
  MOV SP,1234h

  POP DS
  POP BP
  POPF
END;

PROCEDURE UpdateBox;
{ in: MausX,MausY = Koordinaten fÅr Mauscursor}
{     MausXalt,MausYalt = Koord. des vorherigen Aufrufs}
{rem: hierher, wenn Maus bewegt oder ein Button gedrÅckt wurde}
BEGIN
 IF LeftButton OR LeftButtonStillPressed
  THEN BEGIN
        Sound(100); Delay(10); NoSound;
        WITH oldmouse DO
         BEGIN
          INC(breite,(MausXalt-MausX));
          INC(hoehe,(MausYalt-MausY));
          IF breite<1 THEN breite:=1;
          IF hoehe<1 THEN hoehe:=1
         END
       END;
 IF RightButton
  THEN BEGIN
        Sound(1000); Delay(10); NoSound;
       END;
END;

PROCEDURE initmouse;
{ in: MausMaxX,MausMaxY = max. zulÑssige Mausbildschirmkoordinaten}
{     MausCallBack = Maus-Event-Handler (FAR-Prozedur!) }
{out: mouseX|Y2=MausMinX|Y*2, MausX|Y=MausMinX|Y}
{     Koordinatenbereich fÅr Maus wurde entsprechend initialisert }
{     MausCallBack wird bei jeder Mausbewegung/ButtonbetÑtigung gerufen}
{     Maus ist "abgeschaltet" und mu· erst mit "EnableMouse" aktiviert }
{     werden}
{rem: Vorhandensein einer Maus mu· vorher geprÅft worden sein}
{     Koordinatenbereich wird verdoppelt, um Maustreiber eine echte }
{     Auflîsung 0..MausMaxX,0..MausMaxY in Einerschritten abzuringen}
BEGIN
 writeln(8);

 DisableMouse;
 mouseX2:=MausMinX*2;  mouseY2:=MausMinY*2;
 MausX:=mouseX2 SHR 1; MausY:=mouseY2 SHR 1;
 MausXalt:=MausX;      MausYalt:=MausY;
 MouseUpdate:=FALSE;   LeftButton:=FALSE; RightButton:=FALSE;

 writeln(7);

 (* regs.ax := 0; Intr($33,regs); {Maustreiber initialisieren} *)
 PushAll;
 ASM
   MOV DI,OFFSET(@RestoreSS)
   MOV CS:[DI+1],SS
   MOV DI,OFFSET(@RestoreSP)
   MOV CS:[DI+1],SP

   mov ax,0
   int 33h

   @RestoreSS:
   MOV SP,1234h
   MOV SS,SP
   @RestoreSP:
   MOV SP,1234h
 END;
 PopAll;

 writeln(6);

 (* regs.ax := 2; Intr($33,regs); {Cursor aus} *)
 PushAll;
 ASM
   MOV DI,OFFSET(@RestoreSS)
   MOV CS:[DI+1],SS
   MOV DI,OFFSET(@RestoreSP)
   MOV CS:[DI+1],SP

   mov ax,2
   int 33h

   @RestoreSS:
   MOV SP,1234h
   MOV SS,SP
   @RestoreSP:
   MOV SP,1234h
 END;
 PopAll;

 writeln(5);

 (* regs.ax := 4; regs.cx := 0; regs.dx := 0; *)
 (* Intr($33,regs); {Maus in die obere linke Ecke setzen...} *)
 PushAll;
 ASM
   MOV DI,OFFSET(@RestoreSS)
   MOV CS:[DI+1],SS
   MOV DI,OFFSET(@RestoreSP)
   MOV CS:[DI+1],SP

   mov ax,4
   mov cx,0
   mov dx,0
   int 33h

   @RestoreSS:
   MOV SP,1234h
   MOV SS,SP
   @RestoreSP:
   MOV SP,1234h
 END;
 PopAll;

 Writeln(4);

 (* regs.ax := 7; regs.cx := 0; regs.dx := MausMaxX*2; *)
 (* Intr($33,regs); {x-Koordinatenbereich definieren}  *)
 PushAll;
 ASM
   MOV DI,OFFSET(@RestoreSS)
   MOV CS:[DI+1],SS
   MOV DI,OFFSET(@RestoreSP)
   MOV CS:[DI+1],SP

   mov ax,7
   mov cx,0
   mov dx,MausMaxX_mul2
   int 33h

   @RestoreSS:
   MOV SP,1234h
   MOV SS,SP
   @RestoreSP:
   MOV SP,1234h
 END;
 PopAll;

 Writeln(3);

 (* regs.ax := 8; regs.cx := 0; regs.dx := MausMaxY*2; *)
 (* Intr($33,regs); {y-Koordinatenbereich definieren}  *)
 PushAll;
 ASM
   MOV DI,OFFSET(@RestoreSS)
   MOV CS:[DI+1],SS
   MOV DI,OFFSET(@RestoreSP)
   MOV CS:[DI+1],SP

   mov ax,8
   mov cx,0
   mov dx,MausMaxY_mul2
   int 33h

   @RestoreSS:
   MOV SP,1234h
   MOV SS,SP
   @RestoreSP:
   MOV SP,1234h
 END;
 PopAll;

 writeln(2);

 (* regs.ax := 12; *)
 (* regs.cx := MouseMoved OR LeftButtonPressed OR RightButtonPressed; *)
 (* regs.es := seg(MouseCallBack); regs.dx := ofs(MouseCallBack); *)
 (* intr($33,regs); {Eigenen ISR installieren} *)
 PushAll;
 ASM
   MOV DI,OFFSET(@RestoreSS)
   MOV CS:[DI+1],SS
   MOV DI,OFFSET(@RestoreSP)
   MOV CS:[DI+1],SP

   mov ax,12
   mov cx,MouseMoved OR LeftButtonPressed OR RightButtonPressed
   mov dx,SEG MouseCallBack
   mov es,dx
   mov dx,OFFSET MouseCallBack
   int 33h

   @RestoreSS:
   MOV SP,1234h
   MOV SS,SP
   @RestoreSP:
   MOV SP,1234h
 END;
 PopAll;

 writeln(1);
END;


{------- noch ein paar Popup-Boxen definieren: --------}
CONST ButtonWidth=(SizeOf(ButtonStringTyp)-1)*8; {LÑnge einer Textbox}
      EventOk=100;
      abfrage:ARRAY[1..2] OF box=(
 {"Ok"-Box:}
       (x1:0; y1:0; x2:0; y2:0;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventOk;
        Click:TRUE;     {Anclicken nîtig}
        Paint:FALSE),   {zeichnen tun wir selber!}

       {Sentinelwert, da x1>x2!}
       (x1:1; y1:0; x2:0; y2:0;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventNone;
        Click:TRUE;
        Paint:TRUE)
      );

      {-------------------}

      EventYes=101;
      EventNo=102;
      alternative:ARRAY[1..3] OF box=(
 {"Ja"/"Nein"-Box:}
       {"Ja"-Box:}
       (x1:0; y1:0; x2:0; y2:0;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventYes;
        Click:TRUE;     {Anclicken nîtig}
        Paint:FALSE),   {zeichnen tun wir selber!}

       {"Nein"-Box:}
       (x1:0; y1:0; x2:0; y2:0;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventNo;
        Click:TRUE;
        Paint:FALSE),

       {Sentinelwert, da x1>x2!}
       (x1:1; y1:0; x2:0; y2:0;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventNone;
        Click:TRUE;
        Paint:TRUE)
      );

      {-------------------}

VAR oldGraph:pointer;
    oldGraphSize:WORD;

{-----Hintergrundbildspeicher: -----------}
CONST XMAX=319; {Abmessungen einer Hintergrunddatei}
      YMAX=199;
      LINESIZE=(XMAX+1) DIV 4;    {Groesse einer Zeile=80 Bytes}
      PAGESIZE=(YMAX+1)*LINESIZE; {200 Zeilen zu je 320/4 Bytes}
TYPE bitmap=ARRAY[0..PAGESIZE-1] OF BYTE;
     bitmapPtr=^bitmap;
     bild=ARRAY[0..3] OF bitmapPtr;

{-----Fehlerbehandlung: ------------------}
CONST {Fehlercodes: }
      ErrNone=0;
      Error:BYTE=ErrNone;

{-----Palette: --------------------------}
TYPE PaletteEntry=RECORD red,green,blue:BYTE END;
     BigPalette=ARRAY[0..255] OF PaletteEntry;
     PalettePtr=^BigPalette;
CONST DefaultColors:BigPalette=  {Defaultfarben-Palette; erste 16-Farben}
 (                               {sind identisch zu 16-Farbmodi-Farben! }
  (red:  0; green:  0; blue:  0),  {Black}
  (red:  0; green:  0; blue: 42),  {Blue }
  (red:  0; green: 42; blue:  0),  {Green}
  (red:  0; green: 42; blue: 42),  {Cyan }
  (red: 42; green:  0; blue:  0),  {Red  }
  (red: 42; green:  0; blue: 42),  {Magenta   }
  (red: 42; green: 21; blue:  0),  {Brown}
  (red: 42; green: 42; blue: 42),  {LightGray }
  (red: 21; green: 21; blue: 21),  {DarkGray  }
  (red: 21; green: 21; blue: 63),  {LightBlue }
  (red: 21; green: 63; blue: 21),  {LightGreen}
  (red: 21; green: 63; blue: 63),  {LightCyan }
  (red: 63; green: 21; blue: 21),  {LightRed  }
  (red: 63; green: 21; blue: 63),  {LightMagenta}
  (red: 63; green: 63; blue: 21),  {Yellow}
  (red: 63; green: 63; blue: 63),  {White }
  (red:  0; green:  0; blue:  0),
  (red:  5; green:  5; blue:  5),
  (red:  8; green:  8; blue:  8),
  (red: 11; green: 11; blue: 11),
  (red: 14; green: 14; blue: 14),
  (red: 17; green: 17; blue: 17),
  (red: 20; green: 20; blue: 20),
  (red: 24; green: 24; blue: 24),
  (red: 28; green: 28; blue: 28),
  (red: 32; green: 32; blue: 32),
  (red: 36; green: 36; blue: 36),
  (red: 40; green: 40; blue: 40),
  (red: 45; green: 45; blue: 45),
  (red: 50; green: 50; blue: 50),
  (red: 56; green: 56; blue: 56),
  (red: 63; green: 63; blue: 63),
  (red:  0; green:  0; blue: 63),
  (red: 16; green:  0; blue: 63),
  (red: 31; green:  0; blue: 63),
  (red: 47; green:  0; blue: 63),
  (red: 63; green:  0; blue: 63),
  (red: 63; green:  0; blue: 47),
  (red: 63; green:  0; blue: 31),
  (red: 63; green:  0; blue: 16),
  (red: 63; green:  0; blue:  0),
  (red: 63; green: 16; blue:  0),
  (red: 63; green: 31; blue:  0),
  (red: 63; green: 47; blue:  0),
  (red: 63; green: 63; blue:  0),
  (red: 47; green: 63; blue:  0),
  (red: 31; green: 63; blue:  0),
  (red: 16; green: 63; blue:  0),
  (red:  0; green: 63; blue:  0),
  (red:  0; green: 63; blue: 16),
  (red:  0; green: 63; blue: 31),
  (red:  0; green: 63; blue: 47),
  (red:  0; green: 63; blue: 63),
  (red:  0; green: 47; blue: 63),
  (red:  0; green: 31; blue: 63),
  (red:  0; green: 16; blue: 63),
  (red: 31; green: 31; blue: 63),
  (red: 39; green: 31; blue: 63),
  (red: 47; green: 31; blue: 63),
  (red: 55; green: 31; blue: 63),
  (red: 63; green: 31; blue: 63),
  (red: 63; green: 31; blue: 55),
  (red: 63; green: 31; blue: 47),
  (red: 63; green: 31; blue: 39),
  (red: 63; green: 31; blue: 31),
  (red: 63; green: 39; blue: 31),
  (red: 63; green: 47; blue: 31),
  (red: 63; green: 55; blue: 31),
  (red: 63; green: 63; blue: 31),
  (red: 55; green: 63; blue: 31),
  (red: 47; green: 63; blue: 31),
  (red: 39; green: 63; blue: 31),
  (red: 31; green: 63; blue: 31),
  (red: 31; green: 63; blue: 39),
  (red: 31; green: 63; blue: 47),
  (red: 31; green: 63; blue: 55),
  (red: 31; green: 63; blue: 63),
  (red: 31; green: 55; blue: 63),
  (red: 31; green: 47; blue: 63),
  (red: 31; green: 39; blue: 63),
  (red: 45; green: 45; blue: 63),
  (red: 49; green: 45; blue: 63),
  (red: 54; green: 45; blue: 63),
  (red: 58; green: 45; blue: 63),
  (red: 63; green: 45; blue: 63),
  (red: 63; green: 45; blue: 58),
  (red: 63; green: 45; blue: 54),
  (red: 63; green: 45; blue: 49),
  (red: 63; green: 45; blue: 45),
  (red: 63; green: 49; blue: 45),
  (red: 63; green: 54; blue: 45),
  (red: 63; green: 58; blue: 45),
  (red: 63; green: 63; blue: 45),
  (red: 58; green: 63; blue: 45),
  (red: 54; green: 63; blue: 45),
  (red: 49; green: 63; blue: 45),
  (red: 45; green: 63; blue: 45),
  (red: 45; green: 63; blue: 49),
  (red: 45; green: 63; blue: 54),
  (red: 45; green: 63; blue: 58),
  (red: 45; green: 63; blue: 63),
  (red: 45; green: 58; blue: 63),
  (red: 45; green: 54; blue: 63),
  (red: 45; green: 49; blue: 63),
  (red:  0; green:  0; blue: 28),
  (red:  7; green:  0; blue: 28),
  (red: 14; green:  0; blue: 28),
  (red: 21; green:  0; blue: 28),
  (red: 28; green:  0; blue: 28),
  (red: 28; green:  0; blue: 21),
  (red: 28; green:  0; blue: 14),
  (red: 28; green:  0; blue:  7),
  (red: 28; green:  0; blue:  0),
  (red: 28; green:  7; blue:  0),
  (red: 28; green: 14; blue:  0),
  (red: 28; green: 21; blue:  0),
  (red: 28; green: 28; blue:  0),
  (red: 21; green: 28; blue:  0),
  (red: 14; green: 28; blue:  0),
  (red:  7; green: 28; blue:  0),
  (red:  0; green: 28; blue:  0),
  (red:  0; green: 28; blue:  7),
  (red:  0; green: 28; blue: 14),
  (red:  0; green: 28; blue: 21),
  (red:  0; green: 28; blue: 28),
  (red:  0; green: 21; blue: 28),
  (red:  0; green: 14; blue: 28),
  (red:  0; green:  7; blue: 28),
  (red: 14; green: 14; blue: 28),
  (red: 17; green: 14; blue: 28),
  (red: 21; green: 14; blue: 28),
  (red: 24; green: 14; blue: 28),
  (red: 28; green: 14; blue: 28),
  (red: 28; green: 14; blue: 24),
  (red: 28; green: 14; blue: 21),
  (red: 28; green: 14; blue: 17),
  (red: 28; green: 14; blue: 14),
  (red: 28; green: 17; blue: 14),
  (red: 28; green: 21; blue: 14),
  (red: 28; green: 24; blue: 14),
  (red: 28; green: 28; blue: 14),
  (red: 24; green: 28; blue: 14),
  (red: 21; green: 28; blue: 14),
  (red: 17; green: 28; blue: 14),
  (red: 14; green: 28; blue: 14),
  (red: 14; green: 28; blue: 17),
  (red: 14; green: 28; blue: 21),
  (red: 14; green: 28; blue: 24),
  (red: 14; green: 28; blue: 28),
  (red: 14; green: 24; blue: 28),
  (red: 14; green: 21; blue: 28),
  (red: 14; green: 17; blue: 28),
  (red: 20; green: 20; blue: 28),
  (red: 22; green: 20; blue: 28),
  (red: 24; green: 20; blue: 28),
  (red: 26; green: 20; blue: 28),
  (red: 28; green: 20; blue: 28),
  (red: 28; green: 20; blue: 26),
  (red: 28; green: 20; blue: 24),
  (red: 28; green: 20; blue: 22),
  (red: 28; green: 20; blue: 20),
  (red: 28; green: 22; blue: 20),
  (red: 28; green: 24; blue: 20),
  (red: 28; green: 26; blue: 20),
  (red: 28; green: 28; blue: 20),
  (red: 26; green: 28; blue: 20),
  (red: 24; green: 28; blue: 20),
  (red: 22; green: 28; blue: 20),
  (red: 20; green: 28; blue: 20),
  (red: 20; green: 28; blue: 22),
  (red: 20; green: 28; blue: 24),
  (red: 20; green: 28; blue: 26),
  (red: 20; green: 28; blue: 28),
  (red: 20; green: 26; blue: 28),
  (red: 20; green: 24; blue: 28),
  (red: 20; green: 22; blue: 28),
  (red:  0; green:  0; blue: 16),
  (red:  4; green:  0; blue: 16),
  (red:  8; green:  0; blue: 16),
  (red: 12; green:  0; blue: 16),
  (red: 16; green:  0; blue: 16),
  (red: 16; green:  0; blue: 12),
  (red: 16; green:  0; blue:  8),
  (red: 16; green:  0; blue:  4),
  (red: 16; green:  0; blue:  0),
  (red: 16; green:  4; blue:  0),
  (red: 16; green:  8; blue:  0),
  (red: 16; green: 12; blue:  0),
  (red: 16; green: 16; blue:  0),
  (red: 12; green: 16; blue:  0),
  (red:  8; green: 16; blue:  0),
  (red:  4; green: 16; blue:  0),
  (red:  0; green: 16; blue:  0),
  (red:  0; green: 16; blue:  4),
  (red:  0; green: 16; blue:  8),
  (red:  0; green: 16; blue: 12),
  (red:  0; green: 16; blue: 16),
  (red:  0; green: 12; blue: 16),
  (red:  0; green:  8; blue: 16),
  (red:  0; green:  4; blue: 16),
  (red:  8; green:  8; blue: 16),
  (red: 10; green:  8; blue: 16),
  (red: 12; green:  8; blue: 16),
  (red: 14; green:  8; blue: 16),
  (red: 16; green:  8; blue: 16),
  (red: 16; green:  8; blue: 14),
  (red: 16; green:  8; blue: 12),
  (red: 16; green:  8; blue: 10),
  (red: 16; green:  8; blue:  8),
  (red: 16; green: 10; blue:  8),
  (red: 16; green: 12; blue:  8),
  (red: 16; green: 14; blue:  8),
  (red: 16; green: 16; blue:  8),
  (red: 14; green: 16; blue:  8),
  (red: 12; green: 16; blue:  8),
  (red: 10; green: 16; blue:  8),
  (red:  8; green: 16; blue:  8),
  (red:  8; green: 16; blue: 10),
  (red:  8; green: 16; blue: 12),
  (red:  8; green: 16; blue: 14),
  (red:  8; green: 16; blue: 16),
  (red:  8; green: 14; blue: 16),
  (red:  8; green: 12; blue: 16),
  (red:  8; green: 10; blue: 16),
  (red: 11; green: 11; blue: 16),
  (red: 12; green: 11; blue: 16),
  (red: 13; green: 11; blue: 16),
  (red: 15; green: 11; blue: 16),
  (red: 16; green: 11; blue: 16),
  (red: 16; green: 11; blue: 15),
  (red: 16; green: 11; blue: 13),
  (red: 16; green: 11; blue: 12),
  (red: 16; green: 11; blue: 11),
  (red: 16; green: 12; blue: 11),
  (red: 16; green: 13; blue: 11),
  (red: 16; green: 15; blue: 11),
  (red: 16; green: 16; blue: 11),
  (red: 15; green: 16; blue: 11),
  (red: 13; green: 16; blue: 11),
  (red: 12; green: 16; blue: 11),
  (red: 11; green: 16; blue: 11),
  (red: 11; green: 16; blue: 12),
  (red: 11; green: 16; blue: 13),
  (red: 11; green: 16; blue: 15),
  (red: 11; green: 16; blue: 16),
  (red: 11; green: 15; blue: 16),
  (red: 11; green: 13; blue: 16),
  (red: 11; green: 12; blue: 16),
  (red:  0; green:  0; blue:  0),
  (red:  0; green:  0; blue:  0),
  (red:  0; green:  0; blue:  0),
  (red:  0; green:  0; blue:  0),
  (red:  0; green:  0; blue:  0),
  (red:  0; green:  0; blue:  0),
  (red:  0; green:  0; blue:  0),
  (red:  0; green:  0; blue:  0)
 );
VAR ActualColors :BigPalette;{aktuelle Farben}

FUNCTION PalEqual(p1,p2:BigPalette):BOOLEAN;
{ in: p1,p2 = zu vergleichende Paletten}
{out: p1=p2 }
VAR i:WORD;
    flag:BOOLEAN;
BEGIN
 i:=0;
 REPEAT
  flag:=    (p1[i].red  =p2[i].red)
        AND (p1[i].green=p2[i].green)
        AND (p1[i].blue =p2[i].blue);
  inc(i);
 UNTIL (i>255) OR (NOT flag);
 PalEqual:=flag
END;

PROCEDURE GetBigPalette(VAR pal:BigPalette); ASSEMBLER;
{ in: pal = Zeiger auf Palette-Speicher}
{out: pal = momentan aktueller Inhalt der 256-Farben CLUT}
ASM
   CLI
   XOR AL,AL
   MOV DX,3C7h
   OUT DX,AL
   LES DI,pal
   MOV CX,768
   MOV DX,3C9h
  @L1:
   IN AL,DX
   STOSB
   LOOP @L1
   STI
END;

FUNCTION BestFit(Color:BYTE):BYTE; ASSEMBLER;
{ in: Color = Farbnummer des 16 Farbmodus, die approximiert werden soll}
{     ActualColors = gerade gesetzte 256 Farben}
{     DefaultColors= Tabelle der Defaultfarben der 16 (256) Farbmodi}
{out: Farbnummer, deren Farbe am ehesten der uebergebenen Farbe entspricht}
{rem: von Defaultcolors werden nur die ersten 16 Eintraege benoetigt, um  }
{     die Umsetzung Farbname -> RGB-Tripel machen zu koennen!}
ASM
  MOV BL,Color
  XOR BH,BH
  MOV SI,BX
  SHL SI,1
  ADD SI,BX
  ADD SI,OFFSET DefaultColors
  MOV BX,[SI]
  MOV DH,[SI+2]    {BL/BH/DH = aktuelle Farbe, RGB}

  PUSH BP
  MOV DI,65535     {DI=bisher gefundenes minimales Fehlerquadrat}
  MOV CX,255
  MOV SI,OFFSET ActualColors  {DS:SI = Zeiger auf aktuelle Farben}

 @searchloop:
     MOV AL,BL
     SUB AL,[SI]   {Farbdifferenz im Rotanteil}
     IMUL AL       {Fehler*quadrat* optimieren}
     MOV BP,AX

     MOV AL,BH     {dto., Gruenanteil}
     SUB AL,[SI+1]
     IMUL AL
     ADD BP,AX
     JC @noNewMin

     MOV AL,DH     {dto., Blauanteil}
     SUB AL,[SI+2]
     IMUL AL
     ADD AX,BP
     JC @noNewMin

     CMP AX,DI
     JAE @noNewMin
     MOV DI,AX
     MOV DL,CL     {100h-DL=bisher optimale Farbe}
    @noNewMin:
     ADD SI,3      {naechste Farbe zum Vergleich}
     LOOP @searchloop

  POP BP

  MOV AL,DL
  NOT AL           {AL:=100h-DL = optimale Farbe}
  XOR AH,AH
END;

PROCEDURE SetPalette(pal:BigPalette);
{ in: pal = Zeiger auf zu setzende Palette }
{     StatusReg = Statusregister der VGA-Karte}
{out: Best* = Farbnummern der gerade gesetzten}
{     Palette, die den Fraben am Ñhnlichsten sind }
{rem: Palette wurde uebernommen}
VAR p:PalettePtr;
BEGIN
 p:=@pal; {Trick, da der Assembler nicht mit dem SS-Segment klarkommt}
 ASM
   mov dx,StatusReg

   PUSH DS
   LDS SI,p

   CLI
  @WaitNotVSyncLoop:
    in   al,dx
    and  al,8
    jnz  @WaitNotVSyncLoop
  @WaitVSyncLoop:
    in   al,dx
    and  al,8
    jz   @WaitVSyncLoop

   MOV DX,3C8h
   XOR AL,AL
   OUT DX,AL
   INC DX

   MOV CX,256
  @L1:
   LODSB
   OUT DX,AL
   LODSB
   OUT DX,AL
   LODSB
   OUT DX,AL
   LOOP @L1

   STI
   POP DS
 END; {of ASM}
 BestWhite:=BestFit(White);
 BestBlack:=BestFit(Black);
 BestCyan :=BestFit(Cyan);
 BestLightGray:=BestFit(LightGray);
 BestDarkGray:=BestFit(DarkGray);
END;

PROCEDURE SetPaletteEntry(nr,rot,gruen,blau:BYTE); ASSEMBLER;
{ in: nr = zu setzende Farbe}
{     rot,gruen,blau = deren RGB-Werte (0..63)}
{     StatusReg = Portadresse des VGA-Statusregisters}
{out: - }
{rem: Die entsprechende Farbe wurde verÑndert}
ASM
  MOV AH,rot
  MOV BL,gruen
  MOV BH,blau
  MOV SI,3C8h
  MOV CL,nr
  MOV DX,StatusReg

  CLI
 @WaitNotHSync:
  IN AL,DX
  TEST AL,1
  JNE @WaitNotHSync
 @WaitHSync:
  IN AL,DX
  TEST AL,1
  JE @WaitHSync

  MOV DX,SI
  MOV AL,CL
  OUT DX,AL    {Farbnr. an 3C8h}
  INC DX
  MOV AL,AH
  OUT DX,AL    {rot an 3C9h}
  MOV AL,BL
  OUT DX,AL    {gruen auch}
  MOV AL,BH
  OUT DX,AL    {blau auch}
  STI
END;


{---------------------------------------------}
var n,x,y,button:integer;
    s:String[5];
    ch,ch2:Char;
    buttonzahl,i,j:Integer;
    FarbenStartX,FarbenStartY,FarbenHoehegesamt,
    Koordmeldx,Koordmeldy,        {Koordinaten fÅr X/Y-Angabe}
    FilenameStartX,FilenameStartY:Integer; {dto., fÅr Filename}
    PalnameStartX ,PalnameStartY :Integer; {dto., fÅr Filename}
    Filenamelang,Filenamekurz: PathStr; {Dateinamen mit/ohne Pfadangabe}
    Palnamelang ,Palnamekurz : PathStr; {Palettennnamen m/o Pfadangabe }
    oldNamelang ,oldNamekurz : PathStr;
    Wahl:WORD;

PROCEDURE ErrBeep;
BEGIN
 sound(100); delay(300); nosound;
END;

function DetectVGA256 : Integer; FAR;
VAR ch:CHAR;
begin
 ClrScr;
 WRITELN('Select one of the following graphic modes:');
 WRITELN('320x200x256  = 0 ');
 WRITELN('640x400x256  = 1 ');
 WRITELN('640x480x256  = 2 ');
 WRITELN('800x600x256  = 3 ');
 WRITELN('1024x768x256 = 4 ');
 WRITELN;
 WRITELN('ATTENTION! Depending on your VGA''s chipset, some of the modes may not be');
 WRITELN('supported by your system.');
 REPEAT
  WRITE('Your choice: ');
  ch:=ReadKey;
  CASE ch OF
   '0': DetectVGA256 := SVGA320x200x256;
   '1': DetectVGA256 := SVGA640x400x256;
   '2': DetectVGA256 := SVGA640x480x256;
   '3': DetectVGA256 := SVGA800x600x256;
   '4': DetectVGA256 := SVGA1024x768x256;
   ELSE BEGIN
         WRITELN(ch);
         WRITELN('Gee man, I said: a number between 0..4!');
         Sound(200); Delay(200); Nosound;
        END;
  END;
 UNTIL ch IN ['0'..'4'];
end;

VAR GraphMode,GraphDriver:INTEGER;

PROCEDURE InitGrafikDisplay;
VAR Fehler : integer;
    Size   : LongInt;
BEGIN
 GraphDriver := detect;
 InitGraph(GraphDriver,GraphMode,'');
 Fehler:=GraphResult;

 IF Fehler<>GrOK
  THEN BEGIN
        restorecrtmode;
        WRITELN('*** Error while initializing graphic:');
        CASE Fehler OF
         -2:WRITELN('No graphic card found.');
         -3:WRITELN('Could not find *.BGI-driver.');
         -4:WRITELN('Graphic driver has wrong format.');
         -5:WRITELN('Not enough memory to load graphic driver.');
         else WRITELN('Errorcode: ',Fehler);
        END;
        Halt(1);
       END;

 Fehler:=GraphResult;

 IF Fehler<>0
  THEN BEGIN
        restorecrtmode;
        WRITELN('*** Unknown graphic error (while trying to switch into'+
                ' the 256-color-mode).');
        WRITELN('Errorcode: ',Fehler);
       END
  ELSE BEGIN
        ActualColors:=DefaultColors;
        SetPalette(ActualColors);   {aktuelle Farben=Defaultfarben}
       END;
  
END;

PROCEDURE ShowCursorDaten;
{ in: MausX,MausY = aktuelle Mauskoordinaten, innerhalb der Workarea!}
{     zoom = aktueller Zoomfaktor}
{out: Ausgabe der relativen Mauskoordinaten bzgl. der Workarea am Schirm}
{     und der Farbe unter dem Mauscursor}
{rem: Dieselben Koordinaten werden im Hauptprogramm nochmals benîtigt, }
{     bei einer énderung dort also auch Ñndern!}
VAR relX,relY:INTEGER;
    b:BYTE;
    s:STRING[3];
BEGIN
END;

FUNCTION sign(a:INTEGER):INTEGER;
BEGIN
 IF a<0 THEN sign:=-1
 ELSE IF a>0 THEN sign:=+1
 ELSE sign:=0
END;


PROCEDURE FindVGARegisters; ASSEMBLER;
{ in: - }
{out: CRTAddress = Adresse des CRT-Ports, $3B4/$3D4 fÅr monochrom/Farbe}
{     StatusReg  = dto., fÅr Statusregister, $3BA/$3DA}
ASM
  MOV DX,3CCh
  IN AL,DX
  TEST AL,1
  MOV DX,3D4h
  JNZ @L1
  MOV DX,3B4h
 @L1:
  MOV CRTAddress,DX
  ADD DX,6
  MOV StatusReg,DX
END;

PROCEDURE init;
{ prÅft + initialisiert Maus, reserviert Platz fÅr Mausmaske}
{ initialisiert Grafik, sucht VGA-Karten-spezifische Grafikregister}
{ reserviert Platz fÅr Workarea-Inhalt}
{ initialisiert Grafikbildschirm}
{ initialisiert Variablen: Filename*, Palname*, Farben*, Koordmeld?}
{ Event=EventNone}
BEGIN
 writeln(11);
 IF NOT MouseInstalled
  THEN BEGIN  {Ohne Maus lÑuft nix!}
        WRITELN(#7+'Error! Couldn''t detect mouse!');
        Halt(1)
       END
  ELSE BEGIN
        SwapVectors;
        initmouse;
       END;

 FindVGARegisters;
 InitGrafikDisplay;

 Event:=EventNone;

 MausMaxX:=GetMaxX;
 MausMaxY:=GetMaxY;
 MausMaxX_mul2:=GetMaxX*2;
 MausMaxY_mul2:=GetMaxY*2;
 Menu[1].x2:=MausMaxX; Menu[1].y2:=MausMaxY;
 oldMouse.breite:=MausMaxX-MausX+1;
 oldMouse.hoehe :=MausMaxY-MausY+1;
 MeldungX:=GetMaxX DIV 4;
 MeldungY:=GetMaxY DIV 4;
 IF (GetMaxX-MeldungX)<150 THEN MeldungX:=0;
 IF (GetMaxY-MeldungY)<100 THEN MeldungY:=0;

 FileNameLang:='';
 FileNameKurz:='';
 PalNameLang:='';
 PalNameKurz:='';
END;

PROCEDURE DrawOkBox(x1,y1,x2,y2:WORD; Text1:ButtonStringTyp;
          s1,s2,s3:STRING; VAR menu);
{ in: s1|s2|s3 = auszugebende Strings}
{     Text1 = beschriftung fÅr anzuzeigenden Button}
{     x1,y1 = linke obere Ecke der Meldungsbox (absolute Koord.)  }
{     x2,y2 = rechte untere Ecke der Meldungsbox (absolute Koord.)}
{     menu = auszugebende Menubox}
{out: oldGraph^ = alter Inhalt unter Meldebox}
{     oldGraphSize = deren Grî·e}
{     menu = um Koordinaten erweiterte Menubox (=fÅr }
{     AskOkBox() vorbereitet}
{rem: Grafikmodus mu· bereits aktiv sein!}
{     Length(s1|s2|s3)*8 >= x2-x1+1 !}
{     Der Meldungsboxbereich mu· kleiner als 64K sein!}
{     Das Menu darf hîchstens aus 10 Boxen bestehen}
VAR BoxBreite,BoxHoehe,disx,disy:INTEGER;
    x,y:WORD;
    mymenu:ARRAY[1..10] OF box ABSOLUTE menu;
BEGIN
 {alte Grafik sichern:}
 oldGraphSize:=ImageSize(x1,y1,x2,y2);
 GetMem(oldGraph,oldGraphSize);
 GetImage(x1,y1,x2,y2,oldGraph^);

 SetFillStyle(SolidFill,BestLightGray);
 Bar(x1,y1,x2,y2);
 SetFillStyle(SolidFill,BestWhite);
 Bar(x1,y1,x2-1,y1+1);
 Bar(x1,y1,x1+1,y2-1);
 SetFillStyle(SolidFill,BestDarkGray);
 Bar(x1,y2-1,x2,y2);
 Bar(x2-1,y1,x2,y2);

 BoxBreite:=Succ(x2-x1); BoxHoehe:=Succ(y2-y1);
 SetColor(BestBlack);
 y:=y1+10;
 IF s1<>''
  THEN BEGIN
        OutTextXY(x1+ (BoxBreite -(Length(s1) SHL 3)) SHR 1,y,s1);
        INC(y,10);
       END;
 IF s2<>''
  THEN BEGIN
        OutTextXY(x1+ (BoxBreite -(Length(s2) SHL 3)) SHR 1,y,s2);
        INC(y,10);
       END;
 IF s3<>''
  THEN BEGIN
        OutTextXY(x1+ (BoxBreite -(Length(s3) SHL 3)) SHR 1,y,s3);
        INC(y,10);
       END;

 disx:=(BoxBreite-ButtonWidth) DIV 2;
 disy:=(BoxHoehe-(y-y1)) DIV 4;
 mymenu[1].x1:=x1+disx; mymenu[1].y1:=y+disy;
 mymenu[1].x2:=x2-disx; mymenu[1].y2:=y2-disy;

 {Jetzt die Box einzeichnen:}
 y:=y+disy + ((y2-disy)-(y+disy)-8) SHR 1; {fÅr's zentrieren des Textes...}
 WITH mymenu[1] DO
  BEGIN
   SetFillStyle(SolidFill,BestLightGray);
   Bar(x1,y1,x2,y2);
   SetFillStyle(SolidFill,BestWhite);
   Bar(x1,y1,x2-1,y1+1);
   Bar(x1,y1,x1+1,y2-1);
   SetFillStyle(SolidFill,BestDarkGray);
   Bar(x1,y2-1,x2,y2);
   Bar(x2-1,y1,x2,y2);
   OutTextXY(x1+ (ButtonWidth-(Length(Text1) SHL 3)) SHR 1,y,Text1);
  END;
END;

PROCEDURE AskOkBox(x1,y1:WORD; VAR menu);
{ in: menu = komplett ausgefÅllte Menubox}
{     oldGraph^ = alte Grafikdaten}
{     oldGraphSize = deren Grî·e  }
{out: Event = aufgetretenes Event }
{rem: Maus wird freigegeben, um lokales Menu bearbeiten zu kînnen!}
{     Das Menu darf hîchstens aus 10 Boxen bestehen}
VAR mymenu:ARRAY[1..10] OF box ABSOLUTE menu;
    ch:CHAR;
BEGIN;
 ch:=#0;
 DrawMaus;
 Event:=EventNone;

 {Maus freigeben:}
 ClearMouse;

 REPEAT
  IF MouseUpdate
   THEN BEGIN
         UndrawMaus;
         Event:=MouseEvent(mymenu);
         IF (Event=EventNone)
	  THEN BEGIN {das war nichts, nochmal!}
                DrawMaus;
                ClearMouse;
               END;
        END;
  WHILE KeyPressed DO ch:=ReadKey;
  IF ch<>#0
   THEN Event:=EventOK; {auch per Taste abbrechbar}
 UNTIL Event<>EventNone;

 UndrawMaus;
 {alte Grafik wiederherstellen:}
 PutImage(x1,y1,oldGraph^,NormalPut);
 FreeMem(oldGraph,oldGraphSize);
END;

PROCEDURE OkBox(x1,y1,x2,y2:WORD; Text1:ButtonStringTyp;
                s1,s2,s3:STRING; VAR menu);
{ in: s1|s2|s3 = auszugebende Strings}
{     x1,y1 = linke obere Ecke der Meldungsbox (absolute Koord.)  }
{     x2,y2 = rechte untere Ecke der Meldungsbox (absolute Koord.)}
{     Text1 = Beschriftung fÅr auszugebenden Button}
{     menu = auszugebende Ok-Box}
{out: (In menu wurden die Koordinaten verÑndert, was aber ohne Bedeutung}
{     sein sollte, da die Åbergebenen Menus eh nur fÅr diesen Zweck ge- }
{     dacht sind)}
{     Event = aufgetretenes Event}
{rem: Grafikmodus mu· bereits aktiv sein!}
{     Length(s1|s2|s3)*8 >= x2-x1+1 !}
{     Maus wird freigegeben, um lokales Menu bearbeiten zu kînnen!}
{     Der Meldungsboxbereich mu· kleiner als 64K sein!}
{     Das Menu darf hîchstens aus 10 Boxen bestehen}
BEGIN
 DrawOkBox(x1,y1,x2,y2,Text1,s1,s2,s3,menu);
 AskOkBox(x1,y1,menu);
END;

PROCEDURE DrawFirstOfTwoBoxes(x1,y1,x2,y2:WORD;
                              Text1,Text2:ButtonStringTyp;
                              s1,s2,s3:STRING;
                              VAR menu);
{ in: s1|s2|s3 = auszugebende Strings}
{     Text1|2 = Beschriftung der beiden Buttons}
{     x1,y1 = linke obere Ecke der Meldungsbox (absolute Koord.)  }
{     x2,y2 = rechte untere Ecke der Meldungsbox (absolute Koord.)}
{     menu  = auszugebndes Menu}
{out: TRUE|FALSE fÅr erste|zweite Box angeclickt}
{     menu = um Koordinaten erweitertes Menu}
{rem: Grafikmodus mu· bereits aktiv sein!}
{     Length(s1|s2|s3)*8 >= x2-x1+1 !}
{     Maus wird freigegeben, um lokales Menu bearbeiten zu kînnen!}
{     Der Meldungsboxbereich mu· kleiner als 64K sein!}
{     Das Menu darf hîchstens aus 10 Boxen bestehen}
VAR BoxBreite,BoxHoehe,disx,disy:INTEGER;
    x,y:WORD;
    mymenu:ARRAY[1..10] OF box ABSOLUTE menu;
BEGIN
 {alte Grafik sichern:}
 oldGraphSize:=ImageSize(x1,y1,x2,y2);
 GetMem(oldGraph,oldGraphSize);
 GetImage(x1,y1,x2,y2,oldGraph^);

 SetFillStyle(SolidFill,BestLightGray);
 Bar(x1,y1,x2,y2);
 SetFillStyle(SolidFill,BestWhite);
 Bar(x1,y1,x2-1,y1+1);
 Bar(x1,y1,x1+1,y2-1);
 SetFillStyle(SolidFill,BestDarkGray);
 Bar(x1,y2-1,x2,y2);
 Bar(x2-1,y1,x2,y2);

 BoxBreite:=Succ(x2-x1); BoxHoehe:=Succ(y2-y1);
 SetColor(BestBlack);
 y:=y1+10;
 IF s1<>''
  THEN BEGIN
        OutTextXY(x1+ (BoxBreite -(Length(s1) SHL 3)) SHR 1,y,s1);
        INC(y,10);
       END;
 IF s2<>''
  THEN BEGIN
        OutTextXY(x1+ (BoxBreite -(Length(s2) SHL 3)) SHR 1,y,s2);
        INC(y,10);
       END;
 IF s3<>''
  THEN BEGIN
        OutTextXY(x1+ (BoxBreite -(Length(s3) SHL 3)) SHR 1,y,s3);
        INC(y,10);
       END;

 disx:=(BoxBreite-(ButtonWidth SHL 1)) DIV 3;
 disy:=(BoxHoehe-(y-y1)) DIV 4;
 mymenu[1].x1:=x1+disx;             mymenu[1].y1:=y+disy;
 mymenu[1].x2:=x1+disx+ButtonWidth; mymenu[1].y2:=y2-disy;

 mymenu[2].x1:=x2-disx-ButtonWidth; mymenu[2].y1:=y+disy;
 mymenu[2].x2:=x2-disx;             mymenu[2].y2:=y2-disy;

 {Jetzt die beiden Boxen einzeichnen:}
 y:=y+disy + ((y2-disy)-(y+disy)-8) SHR 1; {fÅr's zentrieren des Textes...}
 WITH mymenu[1] DO
  BEGIN
   SetFillStyle(SolidFill,BestLightGray);
   Bar(x1,y1,x2,y2);
   SetFillStyle(SolidFill,BestWhite);
   Bar(x1,y1,x2-1,y1+1);
   Bar(x1,y1,x1+1,y2-1);
   SetFillStyle(SolidFill,BestDarkGray);
   Bar(x1,y2-1,x2,y2);
   Bar(x2-1,y1,x2,y2);
   OutTextXY(x1+ (ButtonWidth-(Length(Text1) SHL 3)) SHR 1,y,Text1);
  END;

 WITH mymenu[2] DO
  BEGIN
   SetFillStyle(SolidFill,BestLightGray);
   Bar(x1,y1,x2,y2);
   SetFillStyle(SolidFill,BestWhite);
   Bar(x1,y1,x2-1,y1+1);
   Bar(x1,y1,x1+1,y2-1);
   SetFillStyle(SolidFill,BestDarkGray);
   Bar(x1,y2-1,x2,y2);
   Bar(x2-1,y1,x2,y2);
   OutTextXY(x1+ (ButtonWidth-(Length(Text2) SHL 3)) SHR 1,y,Text2);
  END;

 DrawMaus;
 {Maus freigeben:}
 ClearMouse;
END;

FUNCTION AskFirstOfTwoBoxes(x1,y1:WORD; Text1,Text2:ButtonStringTyp;
                            VAR menu):BOOLEAN;
{ in: menu = komplett ausgefÅllte Menubox}
{     oldGraph^ = alte Grafikdaten}
{     oldGraphSize = deren Grî·e  }
{out: Event = aufgetretenes Event }
{rem: Maus wird freigegeben, um lokales Menu bearbeiten zu kînnen!}
{     Das Menu darf hîchstens aus 10 Boxen bestehen}
VAR ch:CHAR;
    mymenu:ARRAY[1..10] OF box ABSOLUTE menu;
BEGIN
 Event:=EventNone;
 REPEAT
  IF MouseUpdate
   THEN BEGIN
         UndrawMaus;
         Event:=MouseEvent(mymenu);
         IF (Event=EventNone)
	  THEN BEGIN {das war nichts, nochmal!}
                DrawMaus;
                ClearMouse;
               END;
        END
   ELSE IF (KeyPressed) AND (Upcase(Text1[1])<>Upcase(Text2[1])) THEN
        BEGIN
         WHILE KeyPressed DO ch:=Upcase(ReadKey);
         IF ch=Upcase(Text1[1]) THEN Event:=mymenu[1].Event
         ELSE IF ch=Upcase(Text2[1]) THEN Event:=mymenu[2].Event;
        END;
 UNTIL Event<>EventNone;

 UndrawMaus;
 {alte Grafik wiederherstellen:}
 PutImage(x1,y1,oldGraph^,NormalPut);
 FreeMem(oldGraph,oldGraphSize);

 AskFirstOfTwoBoxes:=Event=EventYes
END;

FUNCTION FirstOfTwoBoxes(x1,y1,x2,y2:WORD;
                         Text1,Text2:ButtonStringTyp;
                         s1,s2,s3:STRING;
                         VAR menu):BOOLEAN;
{ in: s1|s2|s3 = auszugebende Strings}
{     Text1|2 = Beschriftung der beiden Buttons}
{     x1,y1 = linke obere Ecke der Meldungsbox (absolute Koord.)  }
{     x2,y2 = rechte untere Ecke der Meldungsbox (absolute Koord.)}
{     menu = auszugebendes Menu}
{out: TRUE|FALSE fÅr erste|zweite Box angeclickt}
{     (In "menu" wurden die Koordinaten verÑndert, was aber keine }
{     Probleme verursachen sollte, da die Åbergebenen Menus eh nur}
{     fÅr diesen Zweck gedacht sind)}
{     Event = aufgetretenes Event}
{rem: Grafikmodus mu· bereits aktiv sein!}
{     Length(s1|s2|s3)*8 >= x2-x1+1 !}
{     Maus wird freigegeben, um lokales Menu bearbeiten zu kînnen!}
{     Der Meldungsboxbereich mu· kleiner als 64K sein!}
{     Das Menu darf hîchstens aus 10 Boxen bestehen}
BEGIN
 DrawFirstOfTwoBoxes(x1,y1,x2,y2,Text1,Text2,s1,s2,s3,menu);
 FirstOfTwoBoxes:=AskFirstOfTwoBoxes(x1,y1,Text1,Text2,menu);
END;

PROCEDURE Help;
BEGIN
 OkBox((GetMaxX-300) SHR 1,MeldungY,(GetMaxX-300) SHR 1+300,MeldungY+60,'ok',
       'To resize the box: press the left',
       'button and drag. Press the right',
       'button to save a file; ESC quits.',Abfrage);
END;







PROCEDURE DisplayPCXagain; FORWARD;

CONST MaxSize=65520;
      transparent=0;  {Farbe fÅr durchsichtig = 0 per Definition!}
      {Farben fÅr Text-Selektionsboxen:}
      ChoseColor=blue shl 4 + white;   {wei·e Schrift auf blauem Hintergrund}

      Kopf=50; {size of sprite header}
TYPE spritetyp= record case Integer of
      0:(
         Zeiger_auf_Plane:Array[0..3] OF Word;   {These... }
         Breite_in_4er_Gruppen:WORD;             {...data  }
         Hoehe_in_Zeilen:WORD;                   {...use   }
         Translate:Array[1..4] OF Byte;          {...all   }
         SpriteLength:WORD;                      {...in all}
         Dummy:Array[1..10] OF Word;
         Kennung:ARRAY[1..2] OF CHAR;
         Version:BYTE;
         Modus:BYTE;
         ZeigerL,ZeigerR,ZeigerO,ZeigerU:Word;   {"Head" bytes!}
         Data:Array[0..MaxSize-Kopf] OF Byte;
        );
      1:(
         readin:Array[0..MaxSize] OF Byte;
        )
     END;

TYPE WorkAreaTyp=ARRAY[0..MaxSize] OF BYTE;
     PWorkAreaTyp=^WorkAreaTyp;
VAR WorkArea:RECORD
              SizeX,SizeY:WORD;  {Grî·e in x- und y-Richtung}
              MaxUsedX,MaxUsedY:INTEGER;
              data:PWorkAreaTyp; {Zeiger auf Datenarray}
             END;

PROCEDURE SaveActualColors;
{ in: ActualColors = abzuspeichernde 256-Farbenpalette}
{     FileNameLang = Name der abzuspeichernden Datei; die Extension}
{                    mu· allerdings noch auf ".PAL" gebracht werden}
{out: Palette wurde unter dem entsprechenden Namen abgespeichert}
VAR f:FILE;
    D:DirStr;
    N:NameStr;
    E:ExtStr;
BEGIN
 FSplit(FileNameLang,D,N,E);
 Assign(f,D+N+'.PAL');
 ReWrite(f,1);
 BlockWrite(f,ActualColors,SizeOf(ActualColors));
 Close(f)
END;

PROCEDURE SpeichereHintergrund; {PIC's}
{ in: Filenamelang = Name der zu schreibenden Datei}
{     oldName* = alte Dateinamen}
{     Workarea^.[] = zu schreibende Daten}
{out: Falls Sprite nicht erstellt werden konnte, wurden die alten}
{     Dateinamen fÅr Filename* wieder eingesetzt!}
{rem: Der Inhalt der Workarea wird in die Datei Filenamelang }
{     geschrieben; der Dateiname wurde bereits auf Erîffenbar-}
{     keit geprÅft, ebenso, da· die Workarea nicht leer ist!  }
CONST PICHeader:STRING[3]='PIC'; {Kennung in Bilderdateien}
VAR f:File;
    s:String[20];
    i:BYTE;
    t,x,y:WORD;
    picture:Bild;
    pp:POINTER;
    pplen:WORD;
    attr:BYTE;
BEGIN
 IF MaxAvail<4*SizeOf(BitMap)
  THEN BEGIN
        attr:=TextAttr; TextColor(White); TextBackground(Blue);
        GotoXY(10,5);
        WRITE('Not enough heap memory to complete action!');
        GotoXY(10,6);
        WRITE(' needed memory   : ',4*SizeOf(BitMap):7,' bytes          ');
        GotoXY(10,7);
        WRITE(' available memory: ',MaxAvail:7,' bytes           ');
        Rahmen(9,4,52,8);
        TextAttr:=attr;
        ch:=ReadKey;
        Exit;
       END;
 Assign(f,Filenamelang);
 Rewrite(f,1);
 BlockWrite(f,PICHeader[1],Length(PICHeader));

 {Bilddaten zusammenstellen:}
 FOR i:=0 TO 3 DO New(picture[i]);
 FOR y:=0 TO YMAX DO
  FOR x:=0 TO XMAX SHR 2 DO
   BEGIN
    t:=y*LINESIZE;
    picture[0]^[t+x]:=Workarea.data^[y*WorkArea.SizeX +x shl 2 +0];
    picture[1]^[t+x]:=Workarea.data^[y*WorkArea.SizeX +x shl 2 +1];
    picture[2]^[t+x]:=Workarea.data^[y*WorkArea.SizeX +x shl 2 +2];
    picture[3]^[t+x]:=Workarea.data^[y*WorkArea.SizeX +x shl 2 +3];
   END;
 FOR i:=0 TO 3 DO BlockWrite(f,picture[i]^,PAGESIZE);
 Close(f);

 FOR i:=0 TO 3 DO Dispose(picture[i]);
 IF NOT PalEqual(ActualColors,DefaultColors)
  THEN BEGIN
        SaveActualColors;
        attr:=TextAttr; TextColor(White); TextBackground(Blue);
        GotoXY(10,5);
        WRITE(' The actually used colors differ from the ');
        GotoXY(10,6);
        WRITE(' VGA''s default color palette. Therefore,  ');
        GotoXY(10,7);
        WRITE(' the palette has been saved to disk, too! ');
        Rahmen(9,4,52,8);
        TextAttr:=attr;
        ch:=ReadKey;
       END;
END;


PROCEDURE SpeichereSprite; {COD's}
{ in: Filenamelang = Name der zu schreibenden Datei}
{     oldName* = alte Dateinamen}
{out: Falls Sprite nicht erstellt werden konnte, wurden die alten}
{     Dateinamen fÅr Filename* wieder eingesetzt!}
{rem: Der Inhalt der Workarea wird in die Datei Filenamelang }
{     geschrieben; der Dateiname wurde bereits auf Erîffenbar-}
{     keit geprÅft, ebenso, da· die Workarea nicht leer ist!  }
LABEL quit;
VAR f:File;
    i,j,offset,Plane_Groesse:WORD;
    Gesamtgroesse:LONGINT;
    temp,p:Byte;
    links,rechts,oben,unten:Integer;
    fertig_li,fertig_re,fertig_ob,fertig_un:Boolean;
    Sprite:^spritetyp;  {Hier steht das eigentliche Sprite drinnen}
    s:String[20];
    s1,s2:STRING[5];
    pp:POINTER;
    pplen:WORD;
    attr:BYTE;
    ch:CHAR;
BEGIN
 IF MaxAvail<SizeOf(Sprite^)
  THEN BEGIN
        attr:=TextAttr; TextColor(White); TextBackground(Blue);
        GotoXY(10,5);
        WRITE('Not enough heap memory to complete action!');
        GotoXY(10,6);
        WRITE(' needed memory   : ',SizeOf(Sprite^):7,' bytes          ');
        GotoXY(10,7);
        WRITE(' available memory: ',MaxAvail:7,' bytes           ');
        Rahmen(9,4,52,8);
        TextAttr:=attr;
        ch:=ReadKey;
        Exit
       END;
 New(Sprite);
 FillChar(Sprite^.Readin,SizeOf(Sprite^.Readin),0);
 WITH Sprite^ DO
  BEGIN
   Translate[1]:=1; Translate[2]:=2; Translate[3]:=4; Translate[4]:=8;
   Kennung[1]:='K'; Kennung[2]:='R';
   Version:=1;
   Modus:=0;
   FOR i:=1 TO 10 DO dummy[i]:=0; {Dummywerte auf 0 setzen}
   Hoehe_in_Zeilen:=Succ(WorkArea.MaxUsedY);   {Y-Werte reichen von 0..MaxY}
   Breite_in_4er_Gruppen:=Succ(WorkArea.MaxUsedX shr 2); {0..3->1, 4..7->2, ...}
   {Anzahl Bytes pro Plane:}
   Plane_Groesse:=Hoehe_in_Zeilen*Breite_in_4er_Gruppen;

   {Indizes fÅr Grenz- & Planedaten:}
   ZeigerL:=Kopf; {FÑngt beim 1.Datenbyte an}
   ZeigerR:=ZeigerL+ (Hoehe_in_Zeilen*2);
   ZeigerO:=ZeigerR+ (Hoehe_in_Zeilen*2);
   ZeigerU:=ZeigerO+ (Breite_in_4er_Gruppen*4 *2);
   Zeiger_auf_Plane[0] :=ZeigerU+ (Breite_in_4er_Gruppen*4 *2);
   Zeiger_auf_Plane[1] :=Zeiger_auf_Plane[0]+ Plane_Groesse;
   Zeiger_auf_Plane[2] :=Zeiger_auf_Plane[1]+ Plane_Groesse;
   Zeiger_auf_Plane[3] :=Zeiger_auf_Plane[2]+ Plane_Groesse;

   {Das Sprite besteht aus: "Kopf" Bytes an Zeigern & speziellen Infos,}
   {4 Tabellen mit Planedaten, 2 Tabellen mit X-Grenzen (Wîrter!),     }
   {2 Tabellen mit Y-Grenzen (Wîrter, fÅr jeden X-Wert einen!)         }
   Gesamtgroesse:=LONGINT(Kopf)+(Plane_Groesse*4)+
                  (Hoehe_in_Zeilen*2)*2+
                  (Breite_in_4er_Gruppen*4 *2)*2;

   IF Gesamtgroesse>SizeOf(SpriteTyp)
    THEN BEGIN
          Str(Gesamtgroesse:5,s1);
          Str(SizeOf(SpriteTyp):5,s2);
          Write(#7);
          OkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,'ok',
                'Sprite would be to big!',
                '(is:'+s1+', max:'+s2+')','',Abfrage);
          Filenamelang:=oldNamelang; Filenamekurz:=oldNamekurz;
          goto quit;
         END;

   SpriteLength:=Gesamtgroesse;

   {Jetzt die eigentlichen Spritedaten berechnen:}
   offset:=0;
   FOR j:=0 TO WorkArea.MaxUsedY DO
     FOR i:=0 TO Pred(Breite_in_4er_Gruppen) DO
      BEGIN
       FOR p:=0 TO 3 DO
         Readin[Zeiger_auf_Plane[p]+offset]:=
          Workarea.data^[j*WorkArea.SizeX +(i shl 2)+p];
       inc(offset);
      END;

   {Nun die X-Grenzdaten fÅr jede Zeile:}
   offset:=0;
   FOR j:=0 TO WorkArea.MaxUsedY DO
    BEGIN
     links:=0;
     rechts:=WorkArea.MaxUsedX;
     fertig_li:=false; fertig_re:=false;
     REPEAT
      if (not fertig_li and (WorkArea.data^[j*WorkArea.SizeX +links]=0))
       THEN inc(links) ELSE fertig_li:=true;
      if (not fertig_re and (WorkArea.data^[j*WorkArea.SizeX +rechts]=0))
       THEN dec(rechts) ELSE fertig_re:=true;
      if links>rechts THEN BEGIN fertig_li:=true; fertig_re:=true END;
     UNTIL fertig_li and fertig_re;
     if links>rechts
      THEN BEGIN {Leerzeile, Sentinelwerte eintragen}
            readin[ZeigerL+offset]:=lo(+16000);
            readin[Succ(ZeigerL+offset)]:=hi(+16000);
            readin[ZeigerR+offset]:=lo(-16000);
            readin[Succ(ZeigerR+offset)]:=hi(-16000)
           END
      ELSE BEGIN {normale Zeile, Grenzen eintragen}
            readin[ZeigerL+offset]:=lo(links);
            readin[Succ(ZeigerL+offset)]:=hi(links);
            readin[ZeigerR+offset]:=lo(rechts);
            readin[Succ(ZeigerR+offset)]:=hi(rechts)
           END;
     inc(offset,2)  {GrenzeintrÑge sind Wîrter!}
    END;

   {Dasselbe fÅr die Grenzdaten jeder Spalte:}
   offset:=0;
   FOR i:=0 TO Pred(Breite_in_4er_Gruppen shl 2) DO
    BEGIN
     oben :=0;
     unten:=WorkArea.MaxUsedY;
     fertig_ob:=false; fertig_un:=false;
     REPEAT
      if (not fertig_ob and (Workarea.data^[oben*WorkArea.SizeX +i]=0))
       THEN inc(oben) ELSE fertig_ob:=true;
      if (not fertig_un and (Workarea.data^[unten*WorkArea.SizeX +i]=0))
       THEN dec(unten) ELSE fertig_un:=true;
      if oben>unten THEN BEGIN fertig_ob:=true; fertig_un:=true END;
     UNTIL fertig_ob and fertig_un;
     if oben>unten
      THEN BEGIN {Leerspalte, Sentinelwerte eintragen}
            readin[ZeigerO+offset]:=lo(+16000);
            readin[Succ(ZeigerO+offset)]:=hi(+16000);
            readin[ZeigerU+offset]:=lo(-16000);
            readin[Succ(ZeigerU+offset)]:=hi(-16000)
           END
      ELSE BEGIN {normale Spalte, Grenzen eintragen}
            readin[ZeigerO+offset]:=lo(oben);
            readin[Succ(ZeigerO+offset)]:=hi(oben);
            readin[ZeigerU+offset]:=lo(unten);
            readin[Succ(ZeigerU+offset)]:=hi(unten)
           END;
     inc(offset,2)  {GrenzeintrÑge sind Wîrter!}
    END;

  END; {of with}

 {Nun die Daten auf Disk schreiben:}
 Assign(f,Filenamelang);
 Rewrite(f,1);
 BlockWrite(f,sprite^.readin,Gesamtgroesse);
 Close(f);
 IF NOT PalEqual(ActualColors,DefaultColors)
  THEN BEGIN
        SaveActualColors;
        attr:=TextAttr; TextColor(White); TextBackground(Blue);
        GotoXY(10,5);
        WRITE(' The actually used colors differ from the ');
        GotoXY(10,6);
        WRITE(' VGA''s default color palette. Therefore,  ');
        GotoXY(10,7);
        WRITE(' the palette has been saved to disk, too! ');
        Rahmen(9,4,52,8);
        TextAttr:=attr;
        ch:=ReadKey;
       END;

quit:;
 Dispose(Sprite);
END;

FUNCTION gueltig(VAR P:InputString; Ext:ExtStr):Boolean;
{ in: P = vollstÑndiger Dateiname}
{     Ext = gewÅnschte Defaultextension, falls P selber keine hat}
{out: TRUE/FALSE, wenn unter dem angegebenen Namen eine Datei angelegt}
{     werden kann und deren Endung "Ext" ist}
{     P = vollstÑndiger Dateiname, um "Ext" erweitert, wenn keine Ex- }
{     tension angegeben wurde, evtl. Leerzeichen wurden entfernt      }
{rem: Eine schon bestehende Datei gleichen Namens wird Åberschrieben! }
{     P mu· in Gro·schrift sein!}
VAR i:Byte;
    D: DirStr;
    N: NameStr;
    E: ExtStr;

     FUNCTION eroeffenbar(P:PathStr):Boolean;
     VAR f:File;
         temp:Boolean;
     BEGIN
      assign(f,P);
      {$I-}
      rewrite(f);
      {$I+}
      temp:=ioresult=0;
      if temp THEN close(f);
      eroeffenbar:=temp
     END;

BEGIN
 WHILE (P[1]=' ') DO delete(P,1,1);
 WHILE (P[Length(P)]=' ') DO delete(P,Length(P),1);
 IF POS(' ',P)>0
  THEN BEGIN
        gueltig:=FALSE;
        exit
       END;

 FSplit(P, D, N, E);
 IF E='' THEN E:=Ext;
 P := D + N + E;

 if (n='')              {Kein Namen angegeben?}
  or (pos('*',p)>0)     {keine Wildcards erlaubt}
  or (pos('?',p)>0)
  or (pos(':',N+E)>0)   {LW-Angaben sind nur im Pfad erlaubt}
  or (E<>Ext)           {nur "Ext" als Endung erlaubt}
  or ( (pos(':',D)>0) and (pos(':',D)<>2) )   {":" mu· an 2.Position sein}
  or (not eroeffenbar(P))
 THEN BEGIN gueltig:=false; exit END
 ELSE gueltig:=true
END;

PROCEDURE Speichern;
VAR Breite_in_4er_Gruppen:WORD;
    Plane_Groesse,Gesamtgroesse:LONGINT;
    s1,s2:STRING[10];
    x,y:WORD;
    c:BYTE;

    name:TPath;
    error:BOOLEAN;
    oldInt24h:POINTER;

    FUNCTION HoleFileNamen(Ext:ExtStr):BOOLEAN;
    { in: Ext = erwartete Extension (COD oder PIC)}
    CONST x1=4; y1=4; inlen=67; {Koordinaten fÅr Eingabebox}
    VAR temp:InputString;
        abbruch:Boolean;
        size:word;
        attr:Byte;
        i:Integer;
        ch:Char;
        oldNamelang,oldNamekurz,
        P: PathStr;
        D: DirStr;
        N: NameStr;
        E: ExtStr;
    BEGIN
     {evtl. alten Filenamen aufheben}
     oldNamelang:=Filenamelang; oldNamekurz:=Filenamekurz;

     ClrScr;

     GotoXY(x1,y1-2);
     WRITE('Please give a name (*.'+Ext+') for your sprite file; <ESC> to cancel');
     GotoXY(1,y1+6);
     WRITELN('Use the following keys to edit your input:'); WRITELN;
     WRITELN('HOME/END            : move cursor to the start/end of line');
     WRITELN('LEFT/RIGHT          : move cursor one char');
     WRITELN('^LEFT/^RIGHT, ^A/^F : move cursor one word');
     WRITELN;
     WRITELN('INS, ^V             : toggle insert/overwrite mode');
     WRITELN('UP/DOWN, ^E/^X      : review the last (up to 30) input lines');
     WRITELN;
     WRITELN('^T : delete word                  DEL, ^G : delete char under cursor');
     WRITELN('^K : delete to end of line        BSPC,^H : backspace');
     WRITELN('^Y : delete whole input line      ESC     : cancel input');

     attr:=textattr; textattr:=ChoseColor;

      {Defaultwert fÅr Namen aus Filenamelang bestimmen:}
      IF Filenamelang<>''
       THEN BEGIN {dafÅr sorgen, da· evtl. Extension = Ext ist}
             FSplit(Filenamelang,D,N,E);
             temp:=D+N+'.'+Ext
            END
       ELSE temp:='';

      abbruch:=false;         {hei·t: behalte die letzten gemachten Eingaben}
      GotoXY(x1,y1+1);        {= 1.Position in der Eingabetextbox}
      BoxGetString(temp,inlen,abbruch,'enter filename:');
      textattr:=attr;
      IF abbruch
       THEN BEGIN {ESC gedrÅckt}
             Window(1,y1+3,80,25); ClrScr; Window(1,1,80,25);
             GotoXY(x1,y1+4);
             WRITE('You didn''t choose a file!  <any key>');
             ch:=readkey; while keypressed do ch:=readkey;
            END
       ELSE BEGIN {Dateinamen ausprobieren}
             FOR i:=1 TO Length(temp) DO
              CASE temp[i] OF
               'Ñ':temp[i]:='é';
               'î':temp[i]:='ô';
               'Å':temp[i]:='ö'
               ELSE temp[i]:=upcase(temp[i])
              END;

             if not gueltig(temp,'.'+Ext)
              THEN BEGIN {ungÅltiger Dateiname}
                    Window(1,y1+3,80,25); ClrScr; Window(1,1,80,25);
                    GotoXY(x1,y1+4);
                    ClrEol; WRITELN('*** Error! Couldn''t open file with name:');
                    ClrEol; WRITELN;
                    ClrEol; WRITELN(temp);
                    ClrEol; WRITELN;
                    ClrEol; WRITE('(invalid access path or filename)!  <any key>');
                    ch:=readkey; while keypressed do ch:=readkey;
                    abbruch:=true;  {Ist auch als Abbruch zu bewerten!}
                   END
              ELSE BEGIN {gÅltiger Name, in Filename_* Åbernehmen}
                    P:=temp;
                    FSplit(P,D,N,E);
                    Filenamelang:=P;
                    Filenamekurz:=N+E;
                   END;
            END;
     HoleFileNamen:=NOT abbruch;
    END;

BEGIN
 WITH oldMouse DO
  BEGIN
   IF (breite=320) AND (hoehe=200)
    THEN BEGIN
          IF breite*hoehe>MaxAvail
           THEN BEGIN
                 Str(breite*hoehe:7,s1);
                 Str(MaxAvail:7,s2);
                 OkBox((GetMaxX-200) SHR 1,MeldungY,(GetMaxX-200) SHR 1+200,MeldungY+60,'ok',
                       'Not enough heap memory:',
                       'needed: '+s1,
                       'max   : '+s2,Abfrage);
                 exit;
                END
	   ELSE BEGIN
                 {nun loslegen: Speicher reservieren und Grafik auslesen}
                 GetMem(WorkArea.data,breite*hoehe);
                 WorkArea.SizeX:=breite;
                 WorkArea.SizeY:=hoehe;
                 WorkArea.MaxUsedX:=-1;
                 WorkArea.MaxUsedY:=-1;
                 FOR y:=0 TO hoehe-1 DO
	          BEGIN
                   FOR x:=0 TO breite-1 DO
	            BEGIN
                     c:=GetPixel(x+oldX,y+oldY);
                     WorkArea.data^[y*breite+x]:=c;
                     IF c<>0
	              THEN BEGIN
                            WorkArea.MaxUsedY:=y;
                            IF x>WorkArea.MaxUsedX
                             THEN WorkArea.MaxUsedX:=x
                           END;
                    END;
                  END;

                 IF (WorkArea.MaxUsedX=0) AND (WorkArea.MaxUsedY=0) AND
                    (WorkArea.data^[0]=transparent)
                  THEN BEGIN {Workarea leer!}
                        ErrBeep;
                        OkBox((GetMaxX-200) SHR 1,MeldungY,
                              (GetMaxX-200) SHR 1+200,MeldungY+60,'ok',
                              'Workarea is empty;',
                              'nothing to do!',
                              '',Abfrage);
                        exit
                       END;


                 GetBigPalette(actualColors); {aktuelle Farbpalette merken}

                 RestoreCRTmode;

                 IF HoleFileNamen('PIC')
                  THEN BEGIN
                        SpeichereHintergrund;  {Eigentliche Daten berechnen & schreiben}
                       END;
                 FreeMem(WorkArea.data,breite*hoehe);

                 SetGraphMode(GetGraphMode);
                 DisplayPCXagain;
                END; {of ELSE breite*hoehe<=MaxAvail}

         END {of IF (breite=320) AND (hoehe=200) }
    ELSE BEGIN
          Breite_in_4er_Gruppen:=Succ((breite-1) shr 2); {0..3->1, 4..7->2, ...}
          {Anzahl Bytes pro Plane:}
          Plane_Groesse:=LONGINT(hoehe)*Breite_in_4er_Gruppen;
          Gesamtgroesse:=LONGINT(Kopf)+(Plane_Groesse*4)+
                         (hoehe*2)*2+
                         (Breite_in_4er_Gruppen*4 *2)*2;

          IF Gesamtgroesse>SizeOf(SpriteTyp)
           THEN BEGIN
                 Str(Gesamtgroesse:7,s1);
                 Str(SizeOf(SpriteTyp):7,s2);
                 OkBox((GetMaxX-200) SHR 1,MeldungY,(GetMaxX-200) SHR 1+200,MeldungY+60,'ok',
                       'Sprite would be to big:',
                       'needed: '+s1,
                       'max   : '+s2,Abfrage);
                 exit;
                END;

          IF breite*hoehe>SizeOf(WorkAreaTyp)
           THEN BEGIN
                 Str(breite*hoehe:7,s1);
                 Str(SizeOf(WorkAreaTyp):7,s2);
                 OkBox((GetMaxX-200) SHR 1,MeldungY,(GetMaxX-200) SHR 1+200,MeldungY+60,'ok',
                       'Sprite would be to big:',
                       'needed: '+s1,
                       'max   : '+s2,Abfrage);
                 exit;
                END;

          IF breite*hoehe>MaxAvail
           THEN BEGIN
                 Str(breite*hoehe:7,s1);
                 Str(MaxAvail:7,s2);
                 OkBox((GetMaxX-200) SHR 1,MeldungY,(GetMaxX-200) SHR 1+200,MeldungY+60,'ok',
                       'Not enough heap memory:',
                       'needed: '+s1,
                       'max   : '+s2,Abfrage);
                 exit;
                END;

          {nun loslegen: Speicher reservieren und Grafik auslesen}
          GetMem(WorkArea.data,breite*hoehe);
          WorkArea.SizeX:=breite;
          WorkArea.SizeY:=hoehe;
          WorkArea.MaxUsedX:=-1;
          WorkArea.MaxUsedY:=-1;
          FOR y:=0 TO hoehe-1 DO
	   BEGIN
            FOR x:=0 TO breite-1 DO
	     BEGIN
              c:=GetPixel(x+oldX,y+oldY);
              WorkArea.data^[y*breite+x]:=c;
              IF c<>0
	       THEN BEGIN
                     WorkArea.MaxUsedY:=y;
                     IF x>WorkArea.MaxUsedX
                      THEN WorkArea.MaxUsedX:=x
                    END;
             END;
           END;

          IF (WorkArea.MaxUsedX=0) AND (WorkArea.MaxUsedY=0) AND
             (WorkArea.data^[0]=transparent)
           THEN BEGIN {Workarea leer!}
                 ErrBeep;
                 OkBox((GetMaxX-200) SHR 1,MeldungY,(GetMaxX-200) SHR 1+200,MeldungY+60,'ok',
                       'Workarea is empty;',
                       'nothing to do!',
                       '',Abfrage);
                 exit
                END;


          GetBigPalette(actualColors); {aktuelle Farbpalette merken}

          RestoreCRTmode;
          
          IF HoleFileNamen('COD')
           THEN BEGIN
                 SpeichereSprite;  {Eigentliche Daten berechnen & schreiben}
                END;
          FreeMem(WorkArea.data,breite*hoehe);

          SetGraphMode(GetGraphMode);
          DisplayPCXagain;
         END;
  END;
END;

{------------------- PCX-Routinen --------------------}

CONST MaxLineWidth=1023; {max. X-Koord. einer Zeile}
      ErrWrongPCXVersion=1;
      BufSize=2048;      {E/A-Puffergrî·e fÅr schnelleren Filezugriff}

VAR OnePCXline:ARRAY[0..3,0..MaxLineWidth] OF BYTE;
type TPCXHeader=Record
                 Manufacturer,Version,Encoding,BitsPerPixel:BYTE;
                 xmin,ymin,xmax,ymax,hres,vres:INTEGER;
                 palette:ARRAY[0..15,0..2] OF BYTE;
                 Reserved,NPlanes:BYTE;
                 BytesPerLine,paletteinfo:INTEGER;
                 Filler:ARRAY[0..57] OF BYTE;
                END;
CONST RLEbyte :BYTE=0;    {Anfangswerte so wÑhlen, da· beim ersten  }
      ReadByte:BYTE=0;    {Zugriff ein Block von der Diskette einge-}
      Index:WORD=BufSize; {lesen werden wird!}
      FileDone:BOOLEAN=FALSE;
VAR Buffer:ARRAY[1..BufSize] OF BYTE;
    Header:TPCXHeader;
    PCXname:PathStr;
    MaxZeile:INTEGER;
    AnzColors:LONGINT;
    fin:FILE;
    Tag:BYTE;
    Pal256:ARRAY[0..255,0..2] OF BYTE;
    p:POINTER;

PROCEDURE ErrorMsg(s:STRING);
BEGIN
 WRITELN('Error: ',s);
 Halt
END;

FUNCTION GetByte(VAR fin:file):BYTE;
VAR n:BYTE;

 PROCEDURE GetNextBlock;
 VAR temp:WORD;
 BEGIN
  IF NOT EOF(fin)
   THEN BEGIN
         blockread(fin,Buffer,BufSize,temp);
         Index:=1
        END
   ELSE FileDone:=true;
 END;

 FUNCTION GetCh:BYTE;
 BEGIN
  IF NOT FileDone
   THEN BEGIN
         IF Index=BufSize
          THEN GetNextBlock
          ELSE Inc(Index);
         GetCh:=Buffer[Index]
        END
   ELSE GetCh:=0;
 END;

BEGIN
 IF RLEbyte>0
  THEN BEGIN
        GetByte:=ReadByte;
        Dec(RLEbyte);
        exit
       END;
 n:=GetCh;
 IF n AND $C0 = $C0
  THEN BEGIN {Run Length Encoded}
        ReadByte:=GetCh;
        RLEbyte:=n AND $3f -1
       END
  ELSE BEGIN {normales Databyte}
        ReadByte:=n;
        RLEbyte:=0
       END;
 GetByte:=ReadByte
END;

PROCEDURE ReadPCXHeader(name:PathStr; VAR Header:TPCXHeader; VAR fin:FILE);
{ in: name = Name der PCX-Datei}
{out: Header = erste 128 Bytes der PCX-Datei}
{     fin = zum lesen geîffnete PCX-Datei}
VAR temp:INTEGER;
BEGIN
 {$I-}
 Assign(fin,name); Reset(fin,1); blockread(fin,Header,128);
 {$I+}
 Error:=IOResult;
 IF Error<>0
  THEN BEGIN
        {$I-} Close(fin); {$I+}
        temp:=IOResult;
        exit
       END;
 If (Header.version>5) or (Header.encoding>1)
  THEN Error:=ErrWrongPCXVersion;
END;

PROCEDURE DisplayPCXdata(VAR Header:TPCXHeader; MaxZeile:INTEGER;
                         VAR fin:FILE);
{ in: Header   = erste 128 Bytes der PCX-Datei}
{     MaxZeile = letzte auszulesende Zeile aus der PCX-Datei}
{     fin = zum lesen geîffnete PCX-Datei}
{out: fin = geschlossene Datei}
{rem: PCX-File wurde auf dem Schirm dargestellt; Grafikmodus & Palette}
{     mÅssen bereits gesetzt sein}
LABEL break1;
CONST Einsen:ARRAY[1..8] OF BYTE=(1,3,7,15,31,63,127,255);
VAR i,j,k,l,x,px:INTEGER;
    p:POINTER;
    steps,Maske,cutoff:BYTE;
    c:LONGINT;
BEGIN
 {$I-} Seek(fin,128); {$I+}
 IF IOResult<>0 THEN exit;
 FOR l:=0 TO MaxZeile DO
  BEGIN
   FOR j:=0 TO Header.NPlanes-1 DO
    BEGIN
     FOR i:=0 TO Header.BytesPerLine-1 DO
      OnePCXline[j,i]:=GetByte(fin)  {*ganze* Zeile aus Datei holen}
    END;

   steps:=(8 DIV Header.BitsPerPixel);   {Anzahl Pixel pro Byte}
   Maske:=Einsen[Header.BitsPerPixel];   {Maske zur Isolierung eines Punktes}
   FOR x:=0 TO Header.BytesPerLine-1 DO
    BEGIN
     FOR j:=steps-1 DOWNTO 0 DO
      BEGIN
       {berechne c:=Bits der hîchsten Plane||Bits der nÑchsten Plane||etc}
       {Beispiel: normales 16 Farbenbild (4 Planes, 1 Bit je Plane):}
       {c:=1Bit von Plane3||1Bit von Plane2||1Bit von Plane1||1Bit von Plane0}
       {Beispiel: 24Bit-Farbbild (3 Planes, 8 Bit je Plane):}
       {c:=8Bit von Plane2||8Bit von Plane1||8Bit von Plane0}
       c:=0;
       cutoff:=j*Header.BitsPerPixel; {zur Ausmaskierung der relavanten Bits}
       FOR k:=Header.NPlanes-1 DOWNTO 0 DO
        c:=(c SHL Header.BitsPerPixel)+((OnePCXline[k,x] SHR cutoff) AND Maske);
       px:=x*Steps+Pred(steps-j)*Header.BitsPerPixel;
       IF px>GetMaxX THEN goto break1; {Bild ist horizontal zu gro·}
       PutPixel(px,l,c);
      END;
    END;
   break1:;

  END; {of FOR l}

 Close(fin);
END;

PROCEDURE DisplayPCXagain;
BEGIN
 RLEbyte :=0;
 ReadByte:=0;
 Index:=BufSize;
 FileDone:=FALSE;
 IF AnzColors=256
  THEN BEGIN {Farbpalette steht am Ende der Datei}
        FOR i:=0 TO AnzColors-1 DO
	 BEGIN
          ActualColors[i].red  :=Pal256[i][0] SHR 2;
          ActualColors[i].green:=Pal256[i][1] SHR 2;
          ActualColors[i].blue :=Pal256[i][2] SHR 2;
         END;
         SetPalette(ActualColors);
       END
  ELSE IF AnzColors<=16
        THEN FOR i:=0 TO AnzColors-1 DO
              SetRGBPalette(i,Header.Palette[i][0] SHR 2,
                              Header.Palette[i][1] SHR 2,
                              Header.Palette[i][2] SHR 2);
 GetBigPalette(ActualColors);
 Assign(fin,PCXname); Reset(fin,1);
 DisplayPCXdata(Header,MaxZeile,fin);
END;

{------------------- Hauptprogramm -------------------}

BEGIN
 IF ParamCount<>1
  THEN BEGIN
        WRITELN;
        WRITELN('PCX2COD converter, V0.9·   --by Kai Rohrbacher  (c) 1993');
        WRITELN('Converts PCX-files into *.COD or *.PIC files.');
        WRITELN;
        WRITELN('Call PCX2COD in the following way:');
        WRITELN;
        WRITELN(ParamStr(0)+' pcxfile.pcx');
        WRITELN;
        WRITELN('Use the mouse and the left button to select the part of'+
                ' the picture');
        WRITELN('you want to convert, then press <Return> to save it.');
        Halt
       END;
 PCXname:=ParamStr(1);

 IF InstallUserDriver('SVGA256',@DetectVGA256)<0 {RegisterBGIDriver geht leider nicht!}
  THEN ErrorMsg('Graphic error: '+GraphErrorMsg(GraphResult));

 ReadPCXHeader(PCXname,Header,fin);
 IF Error<>0
  THEN ErrorMsg('Couldn''t find file '+PCXname);
 AnzColors:=1 SHL (Header.BitsPerPixel*Header.NPlanes);
 IF AnzColors=256
  THEN BEGIN {Farbpalette steht am Ende der Datei}
        Seek(fin,FileSize(fin)-769);
        BlockRead(fin,Tag,1);
        IF Tag<>$0C
	 THEN BEGIN
               Close(fin);
               ErrorMsg('No true 256-color-PCX!');
              END
         ELSE BEGIN
               BlockRead(fin,Pal256,SizeOf(Pal256));
              END
       END;

 Init;

 {Farbpaletten: im PCX sind die RGB-Werte immer 8 Bit breit; der }
 {256-Farbenmodus verwendet aber nur 6 Bit, deshalb wird um 2 Bit}
 {rechts verschoben!}
 IF AnzColors=256
  THEN BEGIN {Farbpalette steht am Ende der Datei}
        FOR i:=0 TO AnzColors-1 DO
	 BEGIN
          ActualColors[i].red  :=Pal256[i][0] SHR 2;
          ActualColors[i].green:=Pal256[i][1] SHR 2;
          ActualColors[i].blue :=Pal256[i][2] SHR 2;
         END;
        SetPalette(ActualColors);
       END
  ELSE IF AnzColors<=16
        THEN FOR i:=0 TO AnzColors-1 DO
              SetRGBPalette(i,Header.Palette[i][0] SHR 2,
                              Header.Palette[i][1] SHR 2,
                              Header.Palette[i][2] SHR 2);

 GetBigPalette(ActualColors);

 MaxZeile:=Header.ymax-Header.ymin;
 IF MaxZeile>GetMaxY
  THEN MaxZeile:=GetMaxY;
 DisplayPCXdata(Header,MaxZeile,fin);

 DrawMaus; {...und anzeigen}
 EnableMouse;

 repeat
  IF KeyPressed
   THEN BEGIN
         ch:=ReadKey; Shift:=(mem[$0:$417] AND 3)<>0;
         IF ch=#0
          THEN Wahl:=ORD(ReadKey) SHL 8  {Funktionstasten -> >256}
          ELSE Wahl:=ORD(ch);
         CASE Wahl OF
          $3B00: Event:=EventHelp;                {F1   = Hilfe}
          13:    Event:=EventSpeichern;           {CR   = File speichern}
          $1B,$4400: Event:=EventQuit;            {ESC,F10 = Beenden}
          else Event:=EventError;
         END;
        END;

  IF Event=EventNone  {keine Taste gedrÅckt, aber vielleicht Mausaktion?}
   THEN IF MouseUpdate
          THEN BEGIN {Mausaktion}
                {N.B.: soll ein Event jetzt noch nachtrÑglich "gelîscht"  }
                {werden, so mu· es auf "EventMouseMoved" gesetzt werden,  }
                {nicht aber auf "EventNone", denn es ist ja was mit der }
                {Maus passiert, (sie wurde zumindest bewegt oder geclickt)}
                {WÅrde man dies ignorieren, so wÅrde die Maus nicht mehr  }
                {"enabled" werden!}
                Event:=MouseEvent(menu); 
               END;

  IF Event<>EventNone
   THEN UnDrawMaus; {alten Bildschirminhalt unter Mauscursor restaurieren}

  CASE Event OF
   EventHelp       : Help;
   EventSpeichern  : Speichern;
   EventNone:;
   EventError      : ErrBeep;
   EventMouseMoved : UpdateBox;
   EventQuit : BEGIN  {Bei "Quit" lieber nochmal rÅckfragen}
                IF FirstOfTwoBoxes(MeldungX,MeldungY,
                                   MeldungX+220,MeldungY+60,
                                   'yes','no',
                                   '','Really quit?','',
                                   alternative)
                        THEN Event:=EventEndProgram
                        ELSE Event:=EventMouseMoved
               END

   else ErrBeep;
  END;

  IF Event<>EventNone
   THEN BEGIN  {Mauszeiger wurde gelîscht, jetzt wieder neuzeichnen}
         DrawMaus;
         ClearMouse; {Mausereignis abgearbeitet}
        END;

  IF Event<>EventEndProgram THEN Event:=EventNone;
 until Event=EventEndProgram; {Ende = F10 + BestÑtigung}

 restorecrtmode;
 SwapVectors;

 regs.ax := 12;
 regs.cx := 0;
 intr($33,regs); {Mousecallback de-installieren}


END.

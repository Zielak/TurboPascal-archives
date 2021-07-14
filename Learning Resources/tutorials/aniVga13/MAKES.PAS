{$UNDEF StackCheck}
{$DEFINE test}

{$IFDEF test}
  {$A+,B-,D+,E-,F-,G-,I+,L+,N-,O-,R+,S+,V+,X-}
  {$M 16384,0,655360}
{$ELSE}
  {$A+,B-,D+,E-,F-,G-,I-,L+,N-,O-,R-,S-,V-,X-}
  {$M 16384,150000,655360}
{$ENDIF}

PROGRAM MakeSprite;
{Zweck    : Erstellung von *.COD und *.PIC Dateien fÅr ANIVGA        }
{Autor    : Kai Rohrbacher    }
{Sprache  : TurboPascal 6.0   }
{Datum    : MÑrz 1993         }
{Anmerkung: Hat manchmal Probleme bei der Mausinitialisierung - keine}
{           Ahnung warum!}

{Erweiterungen um ein Tool:}
{ ein Event dafÅr definieren}
{ in "ToolTyp" mitaufnehmen }
{ in "Menu[]" aufnehmen (vor dem Sentineleintrag natÅrlich)}
{ DrawTool* Routine fÅr Icondarstellung einfÅgen (inkl. FORWARD)}
{ DrawWorkArea* Routine einfÅhren, die Objekt lîschen, zeichnen & speichern kann}
{ Tooltyp in ClearOldObject(), DrawNewObject() und StoreObject() einfÅgen}
{ in WorkAreaAction() 2x einfÅgen: temporÑres Objekt zeichnen, Objekt abschlie·en}
{ in SelectNewTool() und ShowActualTool() einfÅgen}
{ im Hauptprogramm bei Event-Abfrage berÅcksichtigen}
{ Wenn es den Inhalt der Workarea Ñndert, dann WorkAreaMaxUsedX|Y Ñndern}

USES Dos,Graph,crt,Dateien,Eingaben,Compression;
const Titel1='MakeSprite V2.2 (c) - by Kai Rohrbacher';
      GetMaxX=639;
      GetMaxY=399; {da Graph.GetMaxY hier noch nicht zur VerfÅgung steht!}
      Menumax=10;              {Anzahl EintrÑge im Hauptmenu}
      WorkBreite=320; {Breite der Workarea}
      WorkHoehe=200;
      WorkStartX= 4;  WorkEndX=WorkStartX+Pred(WorkBreite);
      WorkStartY=35;  WorkEndY=WorkStartY+Pred(WorkHoehe);
      PaletteX=WorkStartX+WorkBreite+4; {Koord. fÅr Palette}
      PaletteY=30;
      PalHoehe=15;    {Abmessungen einer Palettenkachel}
      PalBreite=18;
      MeldungX=390; MeldungY=GetMaxY-95;{Koordinaten fÅr Meldungen}
      InfoX=WorkStartX;                 {dto., fÅr Sprite-Info}
      InfoY=WorkEndy+10;
      ToolsX=10; ToolsY=WorkEndY+65;    {dto., fÅr Toolboxen  }
      zoom:BYTE=2;    {Vergrî·erungsfaktor}
      StartVirtualX:INTEGER=0; {Verschiebung des Workarea-Inhaltes}
      StartVirtualY:INTEGER=0;
      MenuStartX=2; MenuStartY=GetMaxY-20; {Menu-Startkoordinaten}

      CursorMaxX=11;  {max. Abmessungen des Mauscursors}
      CursorMaxY=13;
      MausMinX=0;     {Koordinatenbereich fÅr Maus}
      MausMinY=20;
      MausMaxX=GetMaxX-CursorMaxX;
      MausMaxY=GetMaxY-CursorMaxY;

      MaxSpriteBreite=316; {sollte Vielfaches von 4 sein}
      MaxSpriteHoehe =200;
      Datenbytes=MaxSpriteHoehe*Succ(Pred(MaxSpriteBreite) div 4)*4;

      Kopf=50; {Grî·e des folgenden Spriteheaders in Bytes (ohne Data-Feld):}
      VID640x400x256=1;
      VID640x480x256=2;
      transparent=0;  {Farbe fÅr durchsichtig = 0 per Definition!}

      {Farben fÅr Text-Selektionsboxen:}
      ChoseColor=blue shl 4 + white;   {wei·e Schrift auf blauem Hintergrund}

TYPE spritetyp= record case Integer of
      0:(
         Zeiger_auf_Plane:Array[0..3] OF Word;   {Diese...}
         Breite_in_4er_Gruppen:WORD;             {...Daten}
         Hoehe_in_Zeilen:WORD;                   {...brauchen}
         Translate:Array[1..4] OF Byte;          {...alles}
         SpriteLength:WORD;
         Dummy:Array[1..10] OF Word;             {...zusammen}
         Kennung:ARRAY[1..2] OF CHAR;
         Version:BYTE;
         Modus:BYTE;
         ZeigerL,ZeigerR,ZeigerO,ZeigerU:Word;   {"Kopf" Bytes!}
         Data:Array[1..Datenbytes
                       +(WorkBreite*2)*2
                       +(WorkHoehe *2)*2] OF Byte;
        );
      1:(
         readin:Array[0..(Datenbytes-1)  {max. Grî·e der Planedaten}
                      +(WorkBreite*2)*2  {dto., Y-Grenzen (2 Wort-Tabellen)}
                      +(WorkHoehe *2)*2  {dto., X-Gr. (auch WorteintrÑge)}
                      +Kopf] OF Byte;    {Zeiger am Anfang, immer!}
        )
     END;
     {Datentyp zur ReprÑsentation der WorkArea; Achtung: WorkArea[y,x],}
     {nicht WorkArea[x,y]!}
     WorkAreatyp= record case Integer of
      0:(data:ARRAY[0..WorkBreite*WorkHoehe-1] OF BYTE);
      1:(feld:ARRAY[0..WorkHoehe-1,0..WorkBreite-1] OF BYTE);
     END;

     Farbeck=RECORD
              x1,y1,x2,y2:Integer;
             END;

     BildTyp=(cod,pic,none);
     ActionTyp=(clear,draw,store);

     ToolTyp=(Punkt,Rechteck,Ellipse_,FRechteck,FEllipse,Linie,FuellEimer,Kopie);
     ObjektTyp=RECORD
                stage:BYTE;
                StartX,StartY,LastX,LastY:INTEGER;
                actX,actY:INTEGER; {Hilfskoordinaten, nur fÅr "Kopie"-Tool}
                Typ:ToolTyp;
                Aligned:BOOLEAN;
               END;
     ButtonStringTyp=STRING[8];  {Meldung in Clickboxen}

CONST aktuellesTool:ToolTyp=Punkt; {aktuell gewÑhltes Tool}
      aktuelleFarbe:BYTE=White;    {aktuelle Zeichenfarbe }
      Objekt:ObjektTyp=(
       stage:0;  {Objekt noch nicht begonnen, Rest uninteressant!}
       StartX:0; StartY:0; LastX:0; LastY:0;
       actX:0; actY:0;
       Typ:Punkt;
       Aligned:FALSE
       );

VAR CRTAddress,      {Adresse des CRT-Ports, $3B4/$3D4 fuer monochrom/Farbe}
    StatusReg:WORD;  {dto., fuer Statusregister, $3BA/$3DA}
    Shift:BOOLEAN;   {gibt wieder, ob wÑhrend Auswertung Shift gedrÅckt war}
    BestWhite,       {Beste NÑherungen der angeg. Farben}
    BestBlack,
    BestCyan,
    BestLightGray,
    BestDarkGray:BYTE;
    DisplayMode:BYTE;

{---------Menu-Felder---------}
CONST EventNone=0;                 {gar nix}
      EventError=1;                {Fehler }
      EventQuit=2;                 {Programm vielleicht beenden}
      EventScrollLeft=3;           {Scroll nach links }
      EventScrollRight=4;          {Scroll nach rechts}
      EventScrollUp=5;             {Scroll nach oben  }
      EventScrollDown=6;           {Scroll nach unten }
      EventZoomin=7;               {Workareainhalt vergrî·ern}
      EventZoomout=8;              {dto., verkleinern}
      EventHelp=9;                 {Hilfe}
      EventLadeSprite=10;          {Sprite laden}
      EventLadePalette=11;         {Palette laden}
      EventResetColors=12;         {Defaultpalette}
      EventLadeHintergrund=13;     {Hintergrundbild laden}
      EventMapPalette=14;          {Workareainhalt auf Palette matchen}
      EventMapToBIOSPalette=15;    {dto., aber auf Standardfarbenpalette}
      EventInWorkArea=16;          {Maus in Workarea}
      EventMouseMoved=17;          {Maus wurde bewegt}
      EventSelectColor=18;         {Farbe wird ausgewÑhlt}
      EventToolPixel=19;           {Tool fÅr Punkte selektiert}
      EventToolLine=20;            {dto., fÅr Linien}
      EventToolRectangle=21;       {dto., fÅr Quadrate+Rechtecke}
      EventToolEllipse=22;         {dto., fÅr Kreise+Ellipsen}
      EventToolBar=23;             {dto., fÅr ausgefÅllte Quadrate+Rechtecke}
      EventToolDisc=24;            {dto., fÅr ausgefÅllte Kreise+Ellipsen}
      EventToolFill=25;            {dto., fÅr FÅllfunktion}
      EventToolCopy=26;            {dto., fÅr Ausschnittskopien}
      EventBlinkColor=27;          {Eine Farbe blinken lassen}
      EventChangeColor=28;         {Farbe austauschen}
      EventShowBorder=29;          {Spritegrenzen zeigen}
      EventSpeichereSprite=30;     {Sprite abspeichern}
      EventSpeichereHintergrund=31;{Hintergrund abspeichern}
      EventSpeicherePalette=32;    {Palette abspeichern}
      EventRotateLeft=33;          {Workareainhalt um 1 nach links rotieren}
      EventRotateRight=34;         {dto., rechts}
      EventRotateUp=35;            {dto., nach oben}
      EventRotateDown=36;          {dto., nach unten}
      EventMirrorHorizontal=37;    {horizontal spiegeln}
      EventMirrorVertical=38;      {vertikal spiegeln}
      EventObenLinks=39;           {verschiebt Sprite soweit wie mîglich links hoch}
      EventEraseWorkarea=40;       {Workarea vollstÑndig lîschen}
      EventEndProgram=41;          {Programm tatsÑchlich beenden}

VAR globalI:BYTE;

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
     boxes=ARRAY[1..32] OF box;  {alle Menufelder zusammen}

PROCEDURE Dummy; FAR; BEGIN END;
PROCEDURE DrawToolPixels; FAR; FORWARD;
PROCEDURE DrawToolLines; FAR; FORWARD;
PROCEDURE DrawToolRectangles; FAR; FORWARD;
PROCEDURE DrawToolEllipses; FAR; FORWARD;
PROCEDURE DrawToolBars; FAR; FORWARD;
PROCEDURE DrawToolDiscs; FAR; FORWARD;
PROCEDURE DrawToolFill; FAR; FORWARD;
PROCEDURE DrawToolCopy; FAR; FORWARD;

PROCEDURE DrawFunctionkey; FAR; FORWARD;
PROCEDURE DrawBoxBorders; FAR; FORWARD;
PROCEDURE DrawBoxBlinkColor; FAR; FORWARD;
PROCEDURE DrawBoxChangeColor; FAR; FORWARD;
PROCEDURE DrawBoxRotateLeft; FAR; FORWARD;
PROCEDURE DrawBoxRotateRight; FAR; FORWARD;
PROCEDURE DrawBoxRotateUp; FAR; FORWARD;
PROCEDURE DrawBoxRotateDown; FAR; FORWARD;
PROCEDURE DrawBoxMirrorHorizontal; FAR; FORWARD;
PROCEDURE DrawBoxMirrorVertical; FAR; FORWARD;
PROCEDURE DrawBoxObenLinks; FAR; FORWARD;

CONST ToolBoxWidth=45;
      BoxWidth=63;
      Menu:boxes=(
 {F1}  (x1:MenuStartX+ 0*BoxWidth+8-1;           y1:MenuStartY-1;
        x2:MenuStartX+ 0*BoxWidth+8+BoxWidth-14; y2:MenuStartY+18;
        Name1:'Help'; Name2:'';
        Show :DrawFunctionkey;
        Event:EventHelp;
        Click:TRUE;
        Paint:TRUE),
 {F2}  (x1:MenuStartX+ 1*BoxWidth+8-1;           y1:MenuStartY-1;
        x2:MenuStartX+ 1*BoxWidth+8+BoxWidth-14; y2:MenuStartY+18;
        Name1:'Save';Name2:'*.COD';
        Show :DrawFunctionkey;
        Event:EventSpeichereSprite;
        Click:TRUE;
        Paint:TRUE),
 {F3}  (x1:MenuStartX+ 2*BoxWidth+8-1;           y1:MenuStartY-1;
        x2:MenuStartX+ 2*BoxWidth+8+BoxWidth-14; y2:MenuStartY+18;
        Name1:'Load';Name2:'*.COD';
        Show :DrawFunctionkey;
        Event:EventLadeSprite;
        Click:TRUE;
        Paint:TRUE),
 {F4}  (x1:MenuStartX+ 3*BoxWidth+8-1;           y1:MenuStartY-1;
        x2:MenuStartX+ 3*BoxWidth+8+BoxWidth-14; y2:MenuStartY+18;
        Name1:'Save';Name2:'*.PAL';
        Show :DrawFunctionkey;
        Event:EventSpeicherePalette;
        Click:TRUE;
        Paint:TRUE),
 {F5}  (x1:MenuStartX+ 4*BoxWidth+8-1;           y1:MenuStartY-1;
        x2:MenuStartX+ 4*BoxWidth+8+BoxWidth-14; y2:MenuStartY+18;
        Name1:'Load';Name2:'*.PAL';
        Show :DrawFunctionkey;
        Event:EventLadePalette;
        Click:TRUE;
        Paint:TRUE),
 {F6}  (x1:MenuStartX+ 5*BoxWidth+8-1;           y1:MenuStartY-1;
        x2:MenuStartX+ 5*BoxWidth+8+BoxWidth-14; y2:MenuStartY+18;
        Name1:'Save';Name2:'*.PIC';
        Show :DrawFunctionkey;
        Event:EventSpeichereHintergrund;
        Click:TRUE;
        Paint:TRUE),
 {F7}  (x1:MenuStartX+ 6*BoxWidth+8-1;           y1:MenuStartY-1;
        x2:MenuStartX+ 6*BoxWidth+8+BoxWidth-14; y2:MenuStartY+18;
        Name1:'Load';Name2:'*.PIC';
        Show :DrawFunctionkey;
        Event:EventLadeHintergrund;
        Click:TRUE;
        Paint:TRUE),
 {F8}  (x1:MenuStartX+ 7*BoxWidth+8-1;           y1:MenuStartY-1;
        x2:MenuStartX+ 7*BoxWidth+8+BoxWidth-14; y2:MenuStartY+18;
        Name1:'Clear';Name2:'Screen';
        Show :DrawFunctionkey;
        Event:EventEraseWorkarea;
        Click:TRUE;
        Paint:TRUE),
 {F9}  (x1:MenuStartX+ 8*BoxWidth+8-1;           y1:MenuStartY-1;
        x2:MenuStartX+ 8*BoxWidth+8+BoxWidth-14; y2:MenuStartY+18;
        Name1:'MapPal';Name2:'to Pal';
        Show :DrawFunctionkey;
        Event:EventMapPalette;
        Click:TRUE;
        Paint:TRUE),
 {F10} (x1:MenuStartX+ 9*BoxWidth+8-1;           y1:MenuStartY-1;
        x2:MenuStartX+ 9*BoxWidth+8+BoxWidth-14; y2:MenuStartY+18;
        Name1:'QUIT';Name2:'';
        Show :DrawFunctionkey;
        Event:EventQuit;
        Click:TRUE;
        Paint:TRUE),

 {Jetzt die Toolboxen:}
 {Punkte:}
       (x1:ToolsX+0*ToolBoxWidth;      y1:ToolsY;
        x2:ToolsX+1*ToolBoxWidth-5;    y2:ToolsY+32;
        Name1:'';Name2:'';
        Show :DrawToolPixels;
        Event:EventToolPixel;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Linien:}
       (x1:ToolsX+1*ToolBoxWidth;      y1:ToolsY;
        x2:ToolsX+2*ToolBoxWidth-5;    y2:ToolsY+32;
        Name1:'';Name2:'';
        Show :DrawToolLines;
        Event:EventToolLine;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Rechtecke&Quadrate:}
       (x1:ToolsX+2*ToolBoxWidth;      y1:ToolsY;
        x2:ToolsX+3*ToolBoxWidth-5;    y2:ToolsY+32;
        Name1:'';Name2:'';
        Show :DrawToolRectangles;
        Event:EventToolRectangle;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Kreise&Ellipsen:}
       (x1:ToolsX+3*ToolBoxWidth;      y1:ToolsY;
        x2:ToolsX+4*ToolBoxWidth-5;    y2:ToolsY+32;
        Name1:'';Name2:'';
        Show :DrawToolEllipses;
        Event:EventToolEllipse;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {FÅlltool:}
       (x1:ToolsX+0*ToolBoxWidth;      y1:ToolsY+37;
        x2:ToolsX+1*ToolBoxWidth-5;    y2:ToolsY+37+32;
        Name1:'';Name2:'';
        Show :DrawToolFill;
        Event:EventToolFill;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {ausgefÅllte Rechtecke&Quadrate:}
       (x1:ToolsX+2*ToolBoxWidth;      y1:ToolsY+37;
        x2:ToolsX+3*ToolBoxWidth-5;    y2:ToolsY+37+32;
        Name1:'';Name2:'';
        Show :DrawToolBars;
        Event:EventToolBar;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {ausgefÅllte Kreise&Ellipsen:}
       (x1:ToolsX+3*ToolBoxWidth;      y1:ToolsY+37;
        x2:ToolsX+4*ToolBoxWidth-5;    y2:ToolsY+37+32;
        Name1:'';Name2:'';
        Show :DrawToolDiscs;
        Event:EventToolDisc;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Kopie anfertigen:}
       (x1:ToolsX+1*ToolBoxWidth;      y1:ToolsY+37;
        x2:ToolsX+2*ToolBoxWidth-5;    y2:ToolsY+37+32;
        Name1:'';Name2:'';
        Show :DrawToolCopy;
        Event:EventToolCopy;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}


 {---Jetzt die Funktionsbuttons---}

 {Grenzen anzeigen:}
       (x1:ToolsX+8*ToolBoxWidth;      y1:ToolsY+37;
        x2:ToolsX+9*ToolBoxWidth-5;    y2:ToolsY+37+32;
        Name1:'';Name2:'';
        Show :DrawBoxBorders;
        Event:EventShowBorder;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Farbe blinken lassen:}
       (x1:ToolsX+4*ToolBoxWidth;      y1:ToolsY+37;
        x2:ToolsX+5*ToolBoxWidth-5;    y2:ToolsY+37+32;
        Name1:'';Name2:'';
        Show :DrawBoxBlinkColor;
        Event:EventBlinkColor;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Farben austauschen:}
       (x1:ToolsX+4*ToolBoxWidth;      y1:ToolsY;
        x2:ToolsX+5*ToolBoxWidth-5;    y2:ToolsY+32;
        Name1:'';Name2:'';
        Show :DrawBoxChangeColor;
        Event:EventChangeColor;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Workareainhalt um 1 Spalte nach links rotieren:}
       (x1:ToolsX+5*ToolBoxWidth;      y1:ToolsY;
        x2:ToolsX+6*ToolBoxWidth-5;    y2:ToolsY+32;
        Name1:'';Name2:'';
        Show :DrawBoxRotateLeft;
        Event:EventRotateLeft;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Workareainhalt um 1 Spalte nach rechts rotieren:}
       (x1:ToolsX+6*ToolBoxWidth;      y1:ToolsY;
        x2:ToolsX+7*ToolBoxWidth-5;    y2:ToolsY+32;
        Name1:'';Name2:'';
        Show :DrawBoxRotateRight;
        Event:EventRotateRight;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Workareainhalt um 1 Spalte nach oben rotieren:}
       (x1:ToolsX+5*ToolBoxWidth;      y1:ToolsY+37;
        x2:ToolsX+6*ToolBoxWidth-5;    y2:ToolsY+37+32;
        Name1:'';Name2:'';
        Show :DrawBoxRotateUp;
        Event:EventRotateUp;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Workareainhalt um 1 Spalte nach unten rotieren:}
       (x1:ToolsX+6*ToolBoxWidth;      y1:ToolsY+37;
        x2:ToolsX+7*ToolBoxWidth-5;    y2:ToolsY+37+32;
        Name1:'';Name2:'';
        Show :DrawBoxRotateDown;
        Event:EventRotateDown;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Workareainhalt horizontal spiegeln:}
       (x1:ToolsX+7*ToolBoxWidth;      y1:ToolsY;
        x2:ToolsX+8*ToolBoxWidth-5;    y2:ToolsY+32;
        Name1:'';Name2:'';
        Show :DrawBoxMirrorHorizontal;
        Event:EventMirrorHorizontal;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Workareainhalt vertikal spiegeln:}
       (x1:ToolsX+7*ToolBoxWidth;      y1:ToolsY+37;
        x2:ToolsX+8*ToolBoxWidth-5;    y2:ToolsY+37+32;
        Name1:'';Name2:'';
        Show :DrawBoxMirrorVertical;
        Event:EventMirrorVertical;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Workareainhalt nach links oben schieben:}
       (x1:ToolsX+8*ToolBoxWidth;      y1:ToolsY;
        x2:ToolsX+9*ToolBoxWidth-5;    y2:ToolsY+32;
        Name1:'';Name2:'';
        Show :DrawBoxObenLinks;
        Event:EventObenLinks;
        Click:TRUE;     {Anclicken nîtig}
        Paint:TRUE),    {wird gezeichnet}

 {Workarea kann auch als "Menubox" realisiert werden:}
       (x1:WorkStartX;    y1:WorkStartY;
        x2:WorkEndX;      y2:WorkEndY;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventInWorkArea;
        Click:FALSE;    {kein Anclicken nîtig}
        Paint:FALSE),   {...wird aber nicht gezeichnet}

 {Palettenbereich kann auch als "Menubox" realisiert werden:}
       (x1:PaletteX+25;                y1:PaletteY+10;
        x2:PaletteX+25+16*PalBreite-3; y2:PaletteY+10+16*PalHoehe-3;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventSelectColor;
        Click:TRUE;     {Anclicken nîtig}
        Paint:FALSE),   {...wird aber nicht gezeichnet}

 {gesamter Mausbereich kann auch als "Menubox" realisiert werden:}
       (x1:MausMinX;    y1:MausMinY;
        x2:MausMaxX;    y2:MausMaxY;
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
        Paint:TRUE)
      );

VAR event:BYTE;

{FÅr alle folgenden Draw* -Routinen gilt: beim Aufruf steht in "globalI" }
{der Index der darzustellenden Menubox und diese ist wirklich zu zeichnen}

PROCEDURE DrawBasicBox;
{zeichnet eine "nackte" Box}
BEGIN
 WITH Menu[globalI] DO
  BEGIN
   SetFillStyle(SolidFill,BestLightGray);
   Bar(x1,y1,x2,y2);
   SetFillStyle(SolidFill,BestWhite);
   Bar(x1,y1,x2-1,y1+1);
   Bar(x1,y1,x1+1,y2-1);
   SetFillStyle(SolidFill,BestDarkGray);
   Bar(x1,y2-1,x2,y2);
   Bar(x2-1,y1,x2,y2);
  END;
END;

PROCEDURE DrawToolPixels;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetFillStyle(SolidFill,BestBlack);
   Bar(x1+4,y1+4,x1+4+2,y1+4+2);
   Bar(x1+8,y1+15,x1+8+2,y1+15+2);
   Bar(x1+5,y2-9,x1+5+2,y2-9+2);
   Bar(x2-8,y2-7,x2-8+2,y2-7+2);
   Bar(x1+17,y2-13,x1+17+2,y2-13+2);
   Bar(x2-15,y1+8,x2-15+2,y1+8+2);
   SetFillStyle(SolidFill,BestCyan);
   Bar(x1+9,y1+4,x1+9+2,y1+4+2);
   Bar(x1+15,y1+5,x1+15+2,y1+5+2);
   Bar(x2-5,y2-9,x2-5+2,y2-9+2);
   Bar(x2-13,y2-6,x2-13+2,y2-6+2);
   Bar(x2-12,y1+12,x2-12+2,y1+12+2);
  END;
END;

PROCEDURE DrawToolLines;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetLineStyle(SolidLn,0,ThickWidth);
   SetColor(BestBlack);
   Line(x1+4,y2-8,x2-4,y1+12);
   SetColor(BestDarkGray);
   Line(x1+8,y1+5,x2-6,y2-7);
   SetColor(BestCyan);
   Line(x1+4,y1+5,x1+10,y2-3);
   SetLineStyle(SolidLn,0,NormWidth);
  END;
END;

PROCEDURE DrawToolRectangles;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetFillStyle(SolidFill,BestBlack);
   Bar(x1+ 4,y1+12,x1+20,y1+13);
   Bar(x1+20,y1+12,x1+21,y1+27);
   Bar(x1+20,y1+27,x1+ 4,y1+26);
   Bar(x1+ 4,y1+27,x1+ 5,y1+12);

   SetFillStyle(SolidFill,BestCyan);
   Bar(x1+ 8,y1+11,x1+ 9,y1+ 6);
   Bar(x1+ 8,y1+ 6,x2- 4,y1+ 7);
   Bar(x2- 4,y1+ 6,x2- 5,y2-12);
   Bar(x2- 4,y2-12,x1+22,y2-13);
  END;
END;

PROCEDURE DrawToolEllipses;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetColor(BestCyan);
   Ellipse(x1+22,y1+14,273,160,13,6);
   Ellipse(x1+22,y1+14,273,160,14,7);
   SetColor(BestBlack);
   Circle(x1+13,y2-13, 8);
   Circle(x1+13,y2-13, 8+1);
  END;
END;

PROCEDURE DrawToolBars;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetFillStyle(SolidFill,BestCyan);
   Bar(x1+ 8,y1+ 6,x2- 4,y2-13);
   SetFillStyle(SolidFill,BestBlack);
   Bar(x1+ 4,y1+12,x1+20,y1+27);
  END;
END;

PROCEDURE DrawToolDiscs;
VAR i:WORD;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetColor(BestCyan);
   SetFillStyle(SolidFill,BestBlack);
   FOR i:=1 TO 7 DO
    Ellipse(x1+22,y1+14,273,160,7+i,i);
   Line(x1+22-14,y1+14,x1+22+14,y1+14);
   SetColor(BestBlack);
   PieSlice(x1+13,y2-13,0,360, 8);
   PieSlice(x1+13,y2-13,0,360, 8+1);
  END;
END;

PROCEDURE DrawToolFill;
CONST width=7;
      height=12;
VAR i,tx,ty:WORD;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   tx:=x1+11; ty:=y1+16;
   SetColor(BestWhite);
   FOR i:=1 TO width DO Line(tx+i,ty-i,tx+height+i,ty+height-i);
   SetColor(BestBlack);
   Line(tx+0,ty-0,tx+succ(width),ty-succ(width));
   SetLineStyle(SolidLn,0,ThickWidth);
   Line(tx+0,ty-0,tx+height-1,ty+height-1);
   Line(tx+succ(width),ty-succ(width),
        tx+height+width,ty+height-succ(width)-1);
   Line(tx+height,ty+height-1,tx+height+width,ty+height-succ(width));
   SetLineStyle(SolidLn,0,NormWidth);
   Circle(tx +width+1, ty,2);
   Line(tx +width+1,ty,tx +width+1,ty-10);
   Line(tx +width+7,ty-3,tx +width+7,ty-10-3);
   Line(tx +width+1,ty-10,tx +width+7,ty-10-3);
   SetColor(BestCyan);
   Line(tx,ty-2,tx,ty+height);
   Line(tx-1,ty-1,tx-1,ty+height-2);
   Line(tx-1,ty+2,tx-1,ty+height-4);
   Line(tx-1,ty-1,tx+1,ty-2);
  END;
END;

PROCEDURE DrawToolCopy;
CONST
 IconMaxX=23;
 IconMaxY=21;
 dx=10; dy=3;
 s=Black;
 w=White;
 c=Cyan;
 t=255; {transparent}
 IconBorder:ARRAY[0..IconMaxY,0..IconMaxX] OF BYTE=
 (
   {0|0|0|0|0|0|0|0|0|0|1|1|1|1|1|1|1|1|1|1|2|2|2|2}
   {0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5|6|7|8|9|0|1|2|3}

   (t,t,t,t,t,t,t,t,t,t,t,t,t,s,s,s,s,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,t,s,c,c,c,c,s,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,s,c,c,s,s,c,c,s,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,s,c,s,t,t,s,c,s,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,s,c,s,t,t,s,c,s,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,s,c,s,t,s,c,s,t,s,s,s,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,s,c,s,s,c,s,t,s,c,c,c,s,t),
   (t,t,t,t,t,t,t,t,t,t,t,t,s,c,c,s,t,s,c,s,s,c,c,s),
   (t,t,t,t,t,t,t,t,t,t,t,t,s,w,s,t,s,c,s,t,t,s,c,s),
   (t,t,t,t,t,t,t,t,t,t,t,t,s,w,s,s,c,s,t,t,t,s,c,s),
   (t,t,t,t,t,t,t,t,t,t,s,s,w,w,w,w,c,s,s,s,s,c,c,s),
   (t,t,t,t,t,t,t,t,s,s,w,w,s,w,s,s,s,c,c,c,c,c,s,t),
   (t,t,t,t,t,t,s,s,w,w,w,w,w,s,s,t,t,s,s,s,s,s,t,t),
   (t,t,t,t,s,s,w,w,w,w,s,w,w,s,t,t,t,t,t,t,t,t,t,t),
   (t,t,s,s,w,w,w,w,w,s,w,w,s,t,t,t,t,t,t,t,t,t,t,t),
   (t,s,w,w,w,w,w,s,s,w,w,w,s,t,t,t,t,t,t,t,t,t,t,t),
   (s,w,w,w,w,s,s,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (s,w,w,s,s,t,t,s,w,w,w,s,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,s,s,t,t,t,t,s,w,w,s,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,s,w,w,w,s,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,s,w,w,s,t,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,s,s,s,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t)
 );
VAR x,y:WORD;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetColor(BestCyan);
   Rectangle(x1+dx-6,y1+dy+16,x1+dx+16,y1+dy+26);
   FOR y:=0 TO IconMaxY DO
    FOR x:=0 TO IconMaxX DO
     CASE IconBorder[y,x] OF
      t:BEGIN END;
      s:PutPixel(x1+x+dx,y1+y+dy,BestBlack);
      w:PutPixel(x1+x+dx,y1+y+dy,BestWhite);
      c:PutPixel(x1+x+dx,y1+y+dy,BestCyan);
     END;
  END;
END;

{Folgende Menuboxen sind keine "Tools" in obigem Sinne, sondern Funktions-}
{buttons:}

PROCEDURE DrawFunctionkey;
VAR s:STRING[3];
BEGIN
 WITH Menu[globalI] DO
  BEGIN
   SetFillStyle(SolidFill,BestCyan);
   IF (x1<x2) AND (Paint) THEN
    BEGIN
     SetColor(BestWhite);
     OutTextXY(x1-8,y1+1,'F');
     STR(globalI MOD 10,s);
     OutTextXY(x1-8,y1+1+10,s);
     Bar(x1,y1,x2,y2);
     SetColor(BestBlack);
     OutTextXY(x1+1,y1+1,Name1);
     OutTextXY(x1+1,y1+1+10,Name2);
    END;
  END;
END;

PROCEDURE DrawBoxBorders;
CONST
 IconMaxX=35;
 IconMaxY=26;
 dx=3; dy=3;
 s=Black;
 w=White;
 c=Cyan;
 d=DarkGray;
 g=LightGray;
 t=255; {transparent}
 IconBorder:ARRAY[0..IconMaxY,0..IconMaxX] OF BYTE=
 (
   {0|0|0|0|0|0|0|0|0|0|1|1|1|1|1|1|1|1|1|1|2|2|2|2|2|2|2|2|2|2|3|3|3|3|3|3}
   {0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5}

   (t,t,t,t,t,t,t,t,t,t,t,t,t,s,s,s,s,s,s,s,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,s,s,c,c,c,c,c,c,g,s,s,t,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,s,c,c,w,w,w,w,w,c,c,c,g,s,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,s,c,c,w,w,c,c,c,c,c,c,c,c,d,s,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,s,c,w,w,c,g,d,d,d,g,c,c,c,g,s,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,s,c,w,w,c,g,d,s,s,s,d,g,c,c,c,d,s,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,s,c,w,w,c,g,s,t,t,t,s,d,c,c,c,d,s,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,s,g,c,c,g,d,s,t,t,t,t,s,c,c,c,d,s,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,s,d,d,d,s,t,t,t,t,t,s,c,c,c,d,s,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,s,t,t,t,s,s,s,t,t,t,t,t,t,s,c,c,c,d,s,t,t,t,t,s,t,t,t,t,t,t),
   (t,t,t,t,t,s,s,t,t,t,t,t,t,t,t,t,t,s,s,c,c,c,g,d,s,t,t,t,t,s,s,t,t,t,t,t),
   (t,t,t,t,s,w,s,s,s,s,t,t,t,t,t,t,s,c,c,c,c,c,d,s,t,t,s,s,s,s,w,s,t,t,t,t),
   (t,t,t,s,w,w,w,w,w,s,t,t,t,t,t,s,c,c,c,c,c,g,d,s,t,t,s,w,w,w,w,w,s,t,t,t),
   (t,t,s,w,w,w,w,w,w,s,t,t,t,t,s,c,c,w,c,c,g,d,s,t,t,t,s,w,w,w,w,w,w,s,t,t),
   (t,s,w,w,w,w,w,w,w,s,t,t,t,s,c,c,w,c,c,g,d,s,t,t,t,t,s,w,w,w,w,w,w,w,s,t),
   (t,t,s,w,w,w,w,w,w,s,t,t,t,s,c,w,w,c,g,d,s,t,t,t,t,t,s,w,w,w,w,w,w,s,t,t),
   (t,t,t,s,w,w,w,w,w,s,t,t,t,s,c,w,c,g,d,s,t,t,t,t,t,t,s,w,w,w,w,w,s,t,t,t),
   (t,t,t,t,s,w,s,s,s,s,t,t,t,s,c,c,c,c,d,s,t,t,t,t,t,t,s,s,s,s,w,s,t,t,t,t),
   (t,t,t,t,t,s,s,t,t,t,t,t,t,s,g,c,c,g,d,s,t,t,t,t,t,t,t,t,t,s,s,t,t,t,t,t),
   (t,t,t,t,t,t,s,t,t,t,t,t,t,t,s,d,d,d,s,t,t,t,t,t,t,t,t,t,t,s,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,s,s,s,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,s,s,s,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,t,t,t,s,c,c,g,s,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,t,t,t,s,c,w,c,s,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,t,t,t,s,g,c,g,s,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,s,s,s,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t)
 );
VAR x,y:WORD;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   FOR y:=0 TO IconMaxY DO
    FOR x:=0 TO IconMaxX DO
     CASE IconBorder[y,x] OF
      t:BEGIN END;
      s:PutPixel(x1+x+dx,y1+y+dy,BestBlack);
      w:PutPixel(x1+x+dx,y1+y+dy,BestWhite);
      c:PutPixel(x1+x+dx,y1+y+dy,BestCyan);
      d:PutPixel(x1+x+dx,y1+y+dy,BestDarkGray);
      g:PutPixel(x1+x+dx,y1+y+dy,BestLightGray);
     END;
  END;
END;

PROCEDURE DrawBoxBlinkColor;
CONST
 IconMaxX=35;
 IconMaxY=16;
 dx=2; dy=8;
 s=Black;
 w=White;
 d=DarkGray;
 t=255; {transparent}
 IconBorder:ARRAY[0..IconMaxY,0..IconMaxX] OF BYTE=
 (
   {0|0|0|0|0|0|0|0|0|0|1|1|1|1|1|1|1|1|1|1|2|2|2|2|2|2|2|2|2|2|3|3|3|3|3|3}
   {0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5}

   (t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,s,t,t,t,t,t,t,s,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,s,t,t,t,t,s,t,t,t,t,s,t,t,t,t,t,s,t,t,t),
   (t,d,d,d,d,d,d,t,t,t,t,t,t,t,t,t,t,s,t,t,t,t,t,t,t,t,t,t,t,t,t,s,t,t,t,t),
   (t,d,d,d,d,d,d,t,t,t,t,t,t,t,t,t,t,t,s,t,t,t,s,s,s,s,s,t,t,t,s,t,t,t,t,t),
   (t,d,d,d,d,d,d,t,t,t,t,s,t,t,t,t,t,t,t,t,s,s,w,w,w,w,w,s,s,t,t,t,t,t,t,t),
   (t,d,d,d,d,d,d,t,t,t,t,s,s,t,t,t,t,t,t,t,s,w,s,s,w,w,w,w,s,t,t,t,t,t,t,t),
   (t,d,d,d,d,d,d,t,s,s,s,s,w,s,t,t,s,t,t,s,w,s,s,w,w,w,w,w,w,s,t,t,t,t,s,s),
   (t,d,d,d,d,d,d,t,s,w,w,w,w,w,s,t,t,s,t,s,w,s,s,w,w,w,w,w,w,s,t,t,s,s,t,t),
   (t,d,d,d,d,d,d,t,s,w,w,w,w,w,w,s,t,t,t,t,s,w,w,w,w,w,w,w,s,t,t,t,t,t,t,t),
   (t,d,d,d,d,d,d,t,s,w,w,w,w,w,w,w,s,t,t,t,s,w,w,w,w,w,w,w,s,t,t,t,t,t,t,t),
   (t,d,d,d,d,d,d,t,s,w,w,w,w,w,w,s,t,t,s,t,t,s,w,w,w,w,w,s,t,t,s,t,t,t,t,t),
   (t,d,d,d,d,d,d,t,s,w,w,w,w,w,s,t,s,s,t,t,t,t,s,s,s,w,s,t,t,t,t,s,s,t,t,t),
   (t,d,d,d,d,d,d,t,s,s,s,s,w,s,t,t,t,t,t,t,t,t,s,w,w,s,s,t,t,t,t,t,t,t,t,t),
   (t,d,d,d,d,d,d,t,t,t,t,s,s,t,t,t,t,t,t,t,t,t,s,s,s,s,s,t,t,t,t,t,t,t,t,t),
   (t,d,d,d,d,d,d,t,t,t,t,s,t,t,t,t,t,t,t,t,t,t,s,s,s,w,s,t,t,t,t,t,t,t,t,t),
   (t,d,d,d,d,d,d,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,s,w,w,s,s,t,t,t,t,t,t,t,t,t),
   (t,d,d,d,d,d,d,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,s,s,s,t,t,t,t,t,t,t,t,t,t)
 );
VAR x,y:WORD;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   FOR y:=0 TO IconMaxY DO
    FOR x:=0 TO IconMaxX DO
     CASE IconBorder[y,x] OF
      t:BEGIN END;
      s:PutPixel(x1+x+dx,y1+y+dy,BestBlack);
      w:PutPixel(x1+x+dx,y1+y+dy,BestWhite);
      d:PutPixel(x1+x+dx,y1+y+dy,BestDarkGray);
     END;
  END;
END;

PROCEDURE DrawBoxChangeColor;
CONST
 IconMaxX=26;
 IconMaxY=16;
 dx=7; dy=8;
 s=Black;
 w=White;
 d=DarkGray;
 c=Cyan;
 t=255; {transparent}
 IconBorder:ARRAY[0..IconMaxY,0..IconMaxX] OF BYTE=
 (
   {0|0|0|0|0|0|0|0|0|0|1|1|1|1|1|1|1|1|1|1|2|2|2|2|2|2|2|2|2|2|3|3|3|3|3|3}
   {0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5}

   (t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t),
   (d,d,d,d,d,d,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,t,t,t,s,t,t,t,t,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,t,t,t,s,s,t,t,t,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,s,s,s,s,w,s,t,t,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,s,w,w,w,w,w,s,t,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,s,w,w,w,w,w,w,s,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,s,w,w,w,w,w,w,w,s,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,s,w,w,w,w,w,w,s,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,s,w,w,w,w,w,s,t,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,s,s,s,s,w,s,t,t,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,t,t,t,s,s,t,t,t,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,t,t,t,s,t,t,t,t,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,c,c,c,c,c,c),
   (d,d,d,d,d,d,t,t,t,t,t,t,t,t,t,t,t,t,t,t,t,c,c,c,c,c,c)
 );
VAR x,y:WORD;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   FOR y:=0 TO IconMaxY DO
    FOR x:=0 TO IconMaxX DO
     CASE IconBorder[y,x] OF
      t:BEGIN END;
      s:PutPixel(x1+x+dx,y1+y+dy,BestBlack);
      w:PutPixel(x1+x+dx,y1+y+dy,BestWhite);
      d:PutPixel(x1+x+dx,y1+y+dy,BestDarkGray);
      c:PutPixel(x1+x+dx,y1+y+dy,BestCyan);
     END;
  END;
END;

PROCEDURE DrawBoxRotateLeft;
VAR miX,miY:INTEGER;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetColor(BestBlack);
   miX:=(x1+x2) SHR 1; miY:=(y1+y2) SHR 1;
   Ellipse(miX,miY, 0,360, 13,5);
   Ellipse(miX,miY, 0,360, 13-1,5-1);
   Line(miX-3,miY+4,miX+3,miY+4-3);
   Line(miX-2,miY+4,miX+4,miY+4-3);
   Line(miX-3,miY+5,miX+3,miY+5+3);
   Line(miX-2,miY+5,miX+4,miY+5+3);
  END;
END;

PROCEDURE DrawBoxRotateRight;
VAR miX,miY:INTEGER;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetColor(BestBlack);
   miX:=(x1+x2) SHR 1; miY:=(y1+y2) SHR 1;
   Ellipse(miX,miY, 0,360, 13,5);
   Ellipse(miX,miY, 0,360, 13-1,5-1);
   Line(miX-3,miY+4-3,miX+3,miY+4);
   Line(miX-2,miY+4-3,miX+4,miY+4);
   Line(miX-3,miY+5+3,miX+3,miY+5);
   Line(miX-2,miY+5+3,miX+4,miY+5);
  END;
END;

PROCEDURE DrawBoxRotateUp;
VAR miX,miY:INTEGER;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetColor(BestBlack);
   miX:=(x1+x2) SHR 1; miY:=(y1+y2) SHR 1;
   Ellipse((x1+x2) SHR 1,(y1+y2) SHR 1, 0,360, 7,12);
   Ellipse((x1+x2) SHR 1,(y1+y2) SHR 1, 0,360, 7-1,12-1);
   Line(miX-7-4,miY+3,miX-7-1,miY-2);
   Line(miX-7-4,miY+2,miX-7-1,miY-1);
   Line(miX-7+5,miY+3,miX-7+2,miY-2);
   Line(miX-7+5,miY+2,miX-7+2,miY-1);
  END;
END;

PROCEDURE DrawBoxRotateDown;
VAR miX,miY:INTEGER;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetColor(BestBlack);
   miX:=(x1+x2) SHR 1; miY:=(y1+y2) SHR 1;
   Ellipse((x1+x2) SHR 1,(y1+y2) SHR 1, 0,360, 7,12);
   Ellipse((x1+x2) SHR 1,(y1+y2) SHR 1, 0,360, 7-1,12-1);
   Line(miX-7-4,miY-2,miX-7-1,miY+3);
   Line(miX-7-4,miY-1,miX-7-1,miY+2);
   Line(miX-7+5,miY-2,miX-7+2,miY+3);
   Line(miX-7+5,miY-1,miX-7+2,miY+2);
  END;
END;

PROCEDURE DrawBoxMirrorHorizontal;
CONST
 IconMaxX=25;
 IconMaxY=8;
 dx=7; dy=3;
 s=Black;
 w=White;
 t=255; {transparent}
 IconBorder:ARRAY[0..IconMaxY,0..IconMaxX] OF BYTE=
 (
   {0|0|0|0|0|0|0|0|0|0|1|1|1|1|1|1|1|1|1|1|2|2|2|2|2|2}
   {0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5|6|7|8|9|0|1|2|3|4|5}

   (t,s,t,t,t,t,s,t,t,t,t,t,t,t,t,t,s,t,t,t,t,s,t,t,t,t),
   (s,s,t,t,t,t,s,s,t,t,t,t,t,t,t,s,s,t,t,t,t,s,s,t,t,t),
   (w,s,s,s,s,s,s,w,s,t,t,t,t,t,s,w,s,s,s,s,s,s,w,s,t,t),
   (w,w,w,w,w,w,w,w,w,s,t,t,t,s,w,w,w,w,w,w,w,w,w,w,s,t),
   (w,w,w,w,w,w,w,w,w,w,s,t,s,w,w,w,w,w,w,w,w,w,w,w,w,s),
   (w,w,w,w,w,w,w,w,w,s,t,t,t,s,w,w,w,w,w,w,w,w,w,w,s,t),
   (w,s,s,s,s,s,s,w,s,t,t,t,t,t,s,w,s,s,s,s,s,s,w,s,t,t),
   (s,s,t,t,t,t,s,s,t,t,t,t,t,t,t,s,s,t,t,t,t,s,s,t,t,t),
   (t,s,t,t,t,t,s,t,t,t,t,t,t,t,t,t,s,t,t,t,t,s,t,t,t,t)
 );
VAR x,y:WORD;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetColor(BestBlack);
   Line(x1+dx,y1+dy+9,x1+dx+19,y1+dy);
   Line(x1+dx,y1+dy+9+18,x1+dx+19,y1+dy+18);
   Line(x1+dx,y1+dy+9,x1+dx,y1+dy+9+18);
   Line(x1+dx+19,y1+dy,x1+dx+19,y1+dy+18);
   FOR y:=0 TO IconMaxY DO
    FOR x:=0 TO IconMaxX DO
     CASE IconBorder[y,x] OF
      t:BEGIN END;
      s:PutPixel(x1+x+dx+1,y1+y+dy+9,BestBlack);
      w:PutPixel(x1+x+dx+1,y1+y+dy+9,BestWhite);
     END;
  END;
END;

PROCEDURE DrawBoxMirrorVertical;
CONST
 IconMaxX=8;
 IconMaxY=21;
 dx=4; dy=5;
 s=Black;
 w=White;
 t=255; {transparent}
 IconBorder:ARRAY[0..IconMaxY,0..IconMaxX] OF BYTE=
 (
   {0|1|2|3|4|5|6|7|8}

   (t,t,t,t,s,t,t,t,t),
   (t,t,t,s,w,s,t,t,t),
   (t,t,s,w,w,w,s,t,t),
   (t,s,w,w,w,w,w,s,t),
   (s,s,s,w,w,w,s,s,s),
   (t,t,s,w,w,w,s,t,t),
   (t,t,s,w,w,w,s,t,t),
   (t,t,s,w,w,w,s,t,t),
   (t,t,s,w,w,w,s,t,t),
   (s,s,s,w,w,w,s,s,s),
   (t,s,w,w,w,w,w,s,t),
   (t,t,s,w,w,w,s,t,t),
   (t,t,t,s,w,s,t,t,t),
   (t,t,t,t,s,t,t,t,t),
   (t,t,t,t,t,t,t,t,t),
   (t,t,t,t,s,t,t,t,t),
   (t,t,t,s,w,s,t,t,t),
   (t,t,s,w,w,w,s,t,t),
   (t,s,w,w,w,w,w,s,t),
   (s,s,s,w,w,w,s,s,s),
   (t,t,s,w,w,w,s,t,t),
   (t,t,s,w,w,w,s,t,t)
 );
VAR x,y:WORD;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetColor(BestBlack);
   Line(x1+dx+11,y1+dy+11,x1+dx+32,y1+dy+11);
   Line(x1+dx,y1+dy+22,x1+dx+21,y1+dy+22);
   Line(x1+dx,y1+dy+22,x1+dx+11,y1+dy+11);
   Line(x1+dx+21,y1+dy+22,x1+dx+32,y1+dy+11);
   FOR y:=0 TO IconMaxY DO
    FOR x:=0 TO IconMaxX DO
     CASE IconBorder[y,x] OF
      t:BEGIN END;
      s:PutPixel(x1+x+dx+12,y1+y+dy,BestBlack);
      w:PutPixel(x1+x+dx+12,y1+y+dy,BestWhite);
     END;
  END;
END;

PROCEDURE DrawBoxObenLinks;
CONST
 IconMaxX=7;
 IconMaxY=6;
 dx=4; dy=3;
 s=Black;
 w=White;
 t=255; {transparent}
 IconBorder:ARRAY[0..IconMaxY,0..IconMaxX] OF BYTE=
 (
   {0|1|2|3|4|5|6|7}

   (s,s,s,s,s,s,s,t),
   (s,w,w,w,w,s,t,t),
   (s,w,w,w,w,w,s,t),
   (s,w,w,w,w,w,w,s),
   (s,s,w,w,w,w,s,t),
   (s,t,s,w,w,s,t,t),
   (t,t,t,s,s,t,t,t)
 );
VAR x,y:WORD;
BEGIN
 DrawBasicBox;
 WITH Menu[globalI] DO
  BEGIN
   SetColor(BestBlack);
   Line(x1+dx,y1+dy,x1+dx+30,y1+dy);
   Line(x1+dx,y1+dy,x1+dx,y1+dy+25);
   Rectangle(x1+dx+3,y1+dy+3,x1+dx+3+9,y1+dy+3+8);
   Rectangle(x1+dx+3+18,y1+dy+3+15,x1+dx+3+18+9,y1+dy+3+15+8);
   FOR y:=0 TO IconMaxY DO
    FOR x:=0 TO IconMaxX DO
     CASE IconBorder[y,x] OF
      t:BEGIN END;
      s:PutPixel(x1+x+dx+14,y1+y+dy+12,BestBlack);
      w:PutPixel(x1+x+dx+14,y1+y+dy+12,BestWhite);
     END;
  END;
END;

{----------Maus-Routinen----------}
CONST MouseMoved=1;
      LeftButtonPressed=2;
      LeftButtonReleased=4;
      RightButtonPressed=8;
      RightButtonReleased=16;
      w=White;
      b=Black;
      t=255; {durchsichtig}
      SuppressMouse:BOOLEAN=FALSE;
TYPE  MausCursor=RECORD
       data:ARRAY[0..CursorMaxY,0..CursorMaxX] OF BYTE;
       hotX,hotY:BYTE;
      END;

CONST CursorPfeil:MausCursor=
      ( data:(
        (w,b,t,t,t,t,t,t,t,t,t,t),
        (w,w,b,t,t,t,t,t,t,t,t,t),
        (w,w,w,w,b,t,t,t,t,t,t,t),
        (w,w,w,w,w,b,t,t,t,t,t,t),
        (w,w,w,w,w,w,w,b,t,t,t,t),
        (w,w,w,w,w,w,w,w,b,t,t,t),
        (w,w,w,w,w,w,w,w,w,w,b,t),
        (w,w,w,w,w,w,w,w,w,w,w,b),
        (w,w,w,t,w,w,w,b,t,t,t,t),
        (w,w,t,t,t,w,w,w,b,t,t,t),
        (t,t,t,t,t,w,w,w,b,t,t,t),
        (t,t,t,t,t,t,w,w,w,b,t,t),
        (t,t,t,t,t,t,w,w,w,b,t,t),
        (t,t,t,t,t,t,t,w,w,t,t,t));
        hotx:0; hoty:0);

      CursorKreuz:MausCursor=
      ( data:(
        (t,t,t,t,w,t,t,t,t,t,t,t),
        (t,t,t,t,w,t,t,t,t,t,t,t),
        (t,t,t,t,w,t,t,t,t,t,t,t),
        (t,t,t,t,t,t,t,t,t,t,t,t),
        (w,w,w,t,t,t,w,w,w,t,t,t),
        (t,t,t,t,t,t,t,t,t,t,t,t),
        (t,t,t,t,w,t,t,t,t,t,t,t),
        (t,t,t,t,w,t,t,t,t,t,t,t),
        (t,t,t,t,w,t,t,t,t,t,t,t),
        (t,t,t,t,t,t,t,t,t,t,t,t),
        (t,t,t,t,t,t,t,t,t,t,t,t),
        (t,t,t,t,t,t,t,t,t,t,t,t),
        (t,t,t,t,t,t,t,t,t,t,t,t),
        (t,t,t,t,t,t,t,t,t,t,t,t));
        hotx:4; hoty:4);

VAR   Aufrufmaske,Maustasten:WORD;
      MausX,MausY,MausAbsX,MausAbsY:INTEGER;
      mouseX2,mouseY2:INTEGER; {interne Mauskoordinaten}
      MouseMemSize:WORD;       {Grî·e des MouseMem-Speichers}
      oldMouse:RECORD
                MouseMem:POINTER; {Speicher fÅr Mauscursordaten}
                oldX,oldY:WORD;   {alte Mauskoordinaten}
               END;
      MouseUpdate:BOOLEAN;
      LeftButton,RightButton:BOOLEAN;
      regs:REGISTERS;

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

FUNCTION InWorkArea:BOOLEAN;
{ in: MausX,MausY = momentane Mauskoordinaten}
{     WorkStartX|Y, WorkEndX|Y = Koord. der Workarea}
{out: TRUE|FALSE, wenn Mauscursor in Workarea}
BEGIN
 InWorkArea:=(WorkStartX<=MausX) AND (MausX<=WorkEndX) AND
             (WorkStartY<=MausY) AND (MausY<=WorkEndY)
END;

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
          IF NOT Shift THEN MouseEvent:=Event
          ELSE CASE Event OF
                EventMapPalette :MouseEvent:=EventMapToBIOSPalette;
                EventLadePalette:MouseEvent:=EventResetColors;
                else MouseEvent:=Event
               END;

          exit
         END
    ELSE INC(i)
   END;
 MouseEvent:=EventNone;
END;

PROCEDURE DrawMaus(VAR Cursor:MausCursor);
{ in: Cursor = aktueller, anzuzeigender Mauscursor}
{     MausX,MausY = Koordinaten fÅr Mauscursor}
{     oldMouse.MouseMem^ = Platz fÅr Grafikausschnitt unter Mauscursor}
{out: oldMouse.* = gerettete Grafikdaten}
{rem: Der Speicherplatz MouseMem^ mu· bereits reserviert worden sein  }
{     Obwohl die Routine "Cursor" nicht verÑndert, wird als VAR-Para- }
{     meter Åbergeben, da dann nur ein Zeiger Åbergeben wird!}
VAR i,j,xr,yr:WORD;
BEGIN
 WITH Cursor DO
  BEGIN
   xr:=max(MausX-hotx,0); yr:=max(MausY-hoty,0); {nur Onscreen-Teile retten!}
   GetImage(xr,yr,xr+CursorMaxX,yr+CursorMaxY,oldMouse.MouseMem^);
   oldMouse.oldx:=xr; oldMouse.oldY:=yr;
   FOR i:=0 TO CursorMaxX DO
    FOR j:=0 TO CursorMaxY DO
     IF data[j,i]=Black THEN PutPixel(xr+i,yr+j,BestBlack)
     ELSE IF data[j,i]=White THEN PutPixel(xr+i,yr+j,BestWhite)
  END;
END;

PROCEDURE UnDrawMaus;
{ in: oldMouse.* = zu restaurierende Grafikdaten}
BEGIN
 WITH oldMouse DO PutImage(oldX,oldY,MouseMem^,NormalPut)
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
  MOV MausX,CX
  MOV MausY,DX
  MOV MausAbsX,SI
  MOV MausAbsY,DI

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
  CMP AX,MausMaxX*2  {mouseX2:=min(MausMaxX*2,mouseX2)}
  JLE @noBig1
  MOV AX,MausMaxX*2
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
  CMP AX,MausMaxY*2  {mouseY2:=min(MausMaxY*2,mouseY2)}
  JLE @noBig2
  MOV AX,MausMaxY*2
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
   mov dx,MausMaxX*2
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
   mov dx,MausMaxY*2
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
      EventCancel=103;
      FarbenWahl:ARRAY[1..4] OF box=(
 {Cancel/Workarea/Palettenbereich-Abfrage:}

       {"Nein"-Box:}
       (x1:0; y1:0; x2:0; y2:0;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventCancel;
        Click:TRUE;
        Paint:FALSE),

       {Workarea:}
       (x1:WorkStartX;    y1:WorkStartY;
        x2:WorkEndX-1;    y2:WorkEndY-1;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventInWorkArea;
        Click:FALSE;    {Anclicken nicht nîtig}
        Paint:FALSE),   {...wird aber nicht gezeichnet}

       {Palettenbereich:}
       (x1:PaletteX+25;                y1:PaletteY+10;
        x2:PaletteX+25+16*PalBreite-3; y2:PaletteY+10+16*PalHoehe-3;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventSelectColor;
        Click:TRUE;     {Anclicken nîtig}
        Paint:FALSE),   {...wird aber nicht gezeichnet}

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
 DrawMaus(CursorPfeil);
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
                DrawMaus(CursorPfeil);
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

 DrawMaus(CursorPfeil);
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
                DrawMaus(CursorPfeil);
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

{-----Hintergrundbildspeicher: -----------}
CONST XMAX=319; {Abmessungen einer Hintergrunddatei}
      YMAX=199;
      LINESIZE=(XMAX+1) DIV 4;    {Groesse einer Zeile=80 Bytes}
      PAGESIZE=(YMAX+1)*LINESIZE; {200 Zeilen zu je 320/4 Bytes}
TYPE bitmap=ARRAY[0..PAGESIZE-1] OF BYTE;
     bitmapPtr=^bitmap;
     bild=ARRAY[0..3] OF bitmapPtr;
VAR  WorkArea:^WorkAreatyp;
CONST WorkAreaMaxUsedX:INTEGER=0; {Hilfsvariablen fÅr schnelleres Zeichnen:}
      WorkAreaMaxUsedY:INTEGER=0; {welches sind die Extremkoord. des Bildes}

{-----Fehlerbehandlung: ------------------}
CONST {Fehlercodes des Animationspaketes: }
      ErrNone=0;
      ErrNotEnoughMemory=1;
      ErrFileIO=2;
      ErrInvalidSpriteNumber=3;
      ErrNoSprite=4;
      ErrInvalidPageNumber=5;
      ErrNoVGA=6;
      ErrNoPicture=7;
      ErrInvalidPercentage=8;
      ErrNoTile=9;
      ErrInvalidTileNumber=10;
      ErrInvalidCoordinates=11;
      ErrBackgroundToBig=12;
      ErrInvalidMode=13;
      ErrInvalidSpriteLoadNumber=14;
      ErrNoPalette=15;
      ErrPaletteWontFit=16;

      Error:BYTE=ErrNone;

FUNCTION GetErrorMessage:STRING;
{ in: Error = Nummer des aufgetretenen Fehlers}
{out: den Fehler in Worten}
BEGIN
 CASE Error OF
  ErrNone:GetErrorMessage:='No Error';
  ErrNotEnoughMemory:GetErrorMessage:='Not enough memory available on heap';
  ErrFileIO:GetErrorMessage:='I/O-error with file';
  ErrInvalidSpriteNumber:GetErrorMessage:='Invalid sprite number used';
  ErrNoSprite:GetErrorMessage:='No (or corrupted) sprite file';
  ErrInvalidPageNumber:GetErrorMessage:='Invalid page number used';
  ErrNoVGA:GetErrorMessage:='No VGA-card found';
  ErrNoPicture:GetErrorMessage:='No (or corrupted) picture file';
  ErrInvalidPercentage:GetErrorMessage:='Percentage value must be 0..100';
  ErrNoTile:GetErrorMessage:='No (or corrupted) tile/sprite file';
  ErrInvalidTileNumber:GetErrorMessage:='Invalid tile number used';
  ErrInvalidCoordinates:GetErrorMessage:='Invalid coordinates used';
  ErrBackgroundToBig:GetErrorMessage:='Background too big for tile-buffer';
  ErrInvalidMode:GetErrorMessage:='Only STATIC or SCROLLING allowed here';
  ErrInvalidSpriteLoadNumber:GetErrorMessage:='Invalid spriteload number used';
  ErrNoPalette:GetErrorMessage:='No (or corrupted) palette file';
  ErrPaletteWontFit:GetErrorMessage:='Palette indexes must be <256';
  ELSE GetErrorMessage:='Unknown error';
 END;
END;

{-----Palette: --------------------------}
TYPE PaletteEntry=RECORD red,green,blue:BYTE END;
     BigPalette=ARRAY[0..255] OF PaletteEntry;
     PalettePtr=^BigPalette;
     SmallPalette=ARRAY[0..15] OF BYTE;
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
VAR ActualColors,             {aktuelle Farben}
    ZielPalette  :BigPalette; {Zielfarben fÅr MapPalette(), mÅssen im}
                              {Datensegment liegen!}

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

FUNCTION LoadPalette(name:String; number:BYTE; VAR pal:BigPalette):WORD;
{ in: name   = Name des zu ladenden Palette-Files (Typ: "*.PAL" )}
{     number = Nummer, die die erste Farbe aus diesem File bekommen soll  }
{     ActualColors = gerade aktuelle Farbpalette}
{out: Anzahl der aus dem File gelesenen Farben (0 = Fehler trat auf)      }
{     pal = aus dem File gelesene Farbpalette, evtl. ergaenzt}
{rem: Alle nicht ueberschriebenen Farben werden in "pal" auf die Werte der}
{     gerade aktuellen Farben "ActualColors" gesetzt; die Palette wurde   }
{     nur geladen, nicht gesetzt!}
LABEL quitloop;
VAR len:LONGINT;
    f:FileOfByte;
    i,count:WORD;
    TempPal:BigPalette;
    flag:BOOLEAN;
BEGIN
 count:=0;  {Zahl der bisher eingelesenen PaletteneintrÑge}
 _assign(f,name);
 {$I-} _reset(f); {$I+}
 if (ioresult<>0) OR (CompressError<>CompressErr_NoError)
  THEN BEGIN  {Datei existiert nicht oder nicht unter diesem Pfad}
        Error:=ErrFileIO;
        LoadPalette:=0; exit
       END;
 len:=_filesize(f);  {Dateilaenge ermitteln}
 if (len mod 3<>0) OR (len>3*256) OR (len<3)
  THEN BEGIN
        Error:=ErrNoPalette;
        goto quitloop;
       END;
 IF len+number*3>3*256
  THEN BEGIN
        Error:=ErrPaletteWontFit;
        goto quitloop;
       END;

 TempPal:=ActualColors; {temporaere Palette mit aktuellen Farben vorbesetzen}
 {$I-}
  _blockread(f,TempPal[number],len);
 {$I+}

  IF (ioresult<>0) OR (CompressError<>CompressErr_NoError)
   THEN BEGIN
         Error:=ErrFileIO;
         goto quitloop;
        END;

  flag:=FALSE;
  FOR i:=number TO Pred(number+(len DIV 3))
   DO flag:=flag OR (TempPal[i].red>63)
                 OR (TempPal[i].green>63)
                 OR (TempPal[i].blue>63);
  IF flag
   THEN BEGIN
         Error:=ErrNoPalette;
         goto quitloop;
        END;

  {Alles ging gut: Palette zurueckgeben}
  pal:=TempPal;
  count:=len DIV 3;

quitloop: ;
 _close(f);
 LoadPalette:=count
END;

PROCEDURE SavePalette(name:String; VAR pal:BigPalette);
{ in: name   = Name des zu speichernden Palette-Files (Typ: "*.PAL" )}
{     pal = (teilweise) abzuspeichernde Farbpalette}
{out: - }
{rem: Palette "pal" wurde unter dem Namen "name" auf Disk abgespeichert}
VAR f:FileOfByte;
    fehler:BYTE;
BEGIN
 _assign(f,name);
 {$I-} _rewrite(f); {$I+}
 fehler:=IOResult;
 {$I-} _blockwrite(f,pal[0],SizeOf(pal)); {$I+}
 fehler:=IOResult OR fehler;
 {$I-} _close(f);
 fehler:=IOResult OR fehler OR CompressError;
 if (fehler<>0)
  THEN BEGIN  {Datei konnte nicht geschrieben werden}
        Error:=ErrFileIO;
        exit
       END;
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


{---------------------------------------------}
var n,x,y,button:integer;
    s:String[5];
    Farbplatz:Farbeck;
    ch,ch2:Char;
    buttonzahl,i,j:Integer;
    FarbenStartX,FarbenStartY,FarbenHoehegesamt,
    Koordmeldx,Koordmeldy,        {Koordinaten fÅr X/Y-Angabe}
    FilenameStartX,FilenameStartY:Integer; {dto., fÅr Filename}
    PalnameStartX ,PalnameStartY :Integer; {dto., fÅr Filename}
    Filenamelang,Filenamekurz: PathStr; {Dateinamen mit/ohne Pfadangabe}
    Palnamelang ,Palnamekurz : PathStr; {Palettennnamen m/o Pfadangabe }
    Wahl:WORD;


PROCEDURE FindWorkAreaMaxUsed;
{ in: Workarea^.* = aktuelle Grafikdaten}
{out: WorkAreaMaxUsedX|Y = benutzte Extremkoordinaten}
LABEL break1;
VAR x,y:INTEGER;
    flag:BOOLEAN;
BEGIN
 WorkAreaMaxUsedX:=0; WorkAreaMaxUsedY:=0;

 {max. benutzte Zeile suchen:}
 FOR y:=WorkHoehe-1 DOWNTO 0 DO
  BEGIN {Zeilen von unten nach oben durchsuchen}
   FOR x:=WorkBreite-1 DOWNTO 0 DO {Spalten von rechts nach links durchsuchen}
    IF Workarea^.feld[y,x]<>transparent
     THEN BEGIN {gesetzten Punkt gefunden!}
           WorkAreaMaxUsedY:=y;
           WorkAreaMaxUsedX:=max(WorkAreaMaxUsedX,x);
           goto break1
          END
  END;
 break1:;

 {nun noch max. benutzte Spalte suchen: Zeilen WorkHoehe-1..y sind bereits}
 {durchsucht, deren Maximum steht in WorkAreaMaxUsedX!}
 IF WorkAreaMaxUsedX=WorkBreite-1 THEN exit; 
 FOR y:=y-1 DOWNTO 0 DO
  BEGIN
   x:=pred(WorkBreite); {von rechts nach links durchsehen}
   WHILE x>WorkAreaMaxUsedX DO  {nur echte neue Maxima suchen!}
    BEGIN
     IF Workarea^.feld[y,x]<>transparent
      THEN WorkAreaMaxUsedX:=max(WorkAreaMaxUsedX,x) {damit terminiert WHILE!}
      ELSE dec(x)
    END;
  END;

END;


PROCEDURE ErrBeep;
BEGIN
 sound(100); delay(300); nosound;
END;

function DetectVGA256 : Integer; FAR;
begin
  DetectVGA256 := 0
end;

PROCEDURE init640x4_0x256;
VAR Gd,Gm  : integer;
    Fehler : integer;
    Size   : LongInt;
BEGIN
 Gd := InstallUserDriver('SVGA256',@DetectVGA256);
 Gm := DisplayMode; {VID640x400x256 oder VID640x480x256}
 InitGraph(Gd, gm ,'');
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

 setgraphmode(DisplayMode);
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

PROCEDURE Absolute2WorkArea(VAR rx,ry:INTEGER);
{ in: MausX|Y = momentane Mauskoordinaten, innerhalb der Workarea}
{     WorkStartX|Y = Startkoord. der Workarea}
{     StartVirtualX|Y = aktuelle Verschiebung des Workareabeginns}
{     zoom = momentan gesetzter Zoomfaktor}
{out: rx,ry = Mauskoordinaten relativ bzgl. der Workarea}
BEGIN
 rx:=(MausX-WorkStartX) DIV zoom +StartVirtualX;
 ry:=(MausY-WorkStartY) DIV zoom +StartVirtualY
END;

PROCEDURE WorkArea2Absolute(rx,ry:INTEGER; VAR ax,ay:INTEGER);
{ in: rx,ry = umzurechnende Workarea-Koordinaten}
{     WorkStartX|Y = Startkoord. der Workarea}
{     StartVirtualX|Y = aktuelle Verschiebung des Workareabeginns}
{     zoom = momentan gesetzter Zoomfaktor}
{out: ax,ay = absolute (=Bildschrm-)Koordinaten von rx,ry}
BEGIN
 ax:=(rx-StartVirtualX)*zoom +WorkStartX;
 ay:=(ry-StartVirtualY)*zoom +WorkStartY;
END;

PROCEDURE AdjustMouse;
{ in: MausX,MausY = aktuelle Mauskoordinaten}
{     zoom = aktueller Zoomfaktor}
{     WorkStartX|Y, WorkEndX|Y = WorkArea-Begrenzungen}
{out: MausX,MausY wurden so justiert, da· sie nur in einem Raster der }
{     Breite und Hîhe "zoom" bewegt werden kînnen und dabei so genau  }
{     wie mîglich in die Mitte eines solchen Rasterpunktes gesetzt    }
{     wurden; fiele der so generierte Punkt au·erhalb der WorkArea,   }
{     so wird ein Kompromi· gefunden, so da· er wieder innerhalb liegt}
{     Vorher wird die Maus bereits so justiert, da· sie nicht aus dem }
{     Raster [0..319,0..199] fÑllt (ist durch das scrollen mîglich)!  }
{rem: Diese Routine sollte nur gerufen werden, wenn MausX|Y innerhalb }
{     der Workarea liegen}
VAR rx,ry:INTEGER;
BEGIN
 IF NOT InWorkArea THEN exit;

 Absolute2Workarea(rx,ry);  {relative Koordinaten ermitteln}
 rx:=min(rx,WorkBreite-1);  {diese mÅssen im Bereich [0..319,0..199]}
 ry:=min(ry,WorkHoehe-1);   {liegen!}
 Workarea2Absolute(rx,ry,MausX,MausY); {in absolute Koord. zurÅckrechnen}

 MausX:=MausX-((MausX-WorkStartX) MOD zoom);
 IF MausX+zoom SHR 1>WorkEndX
  THEN BEGIN {Punktmitte wÑre au·erhalb}
        MausX:=MausX+ (WorkEndX-MausX) SHR 1
       END
  ELSE INC(MausX,zoom SHR 1);

 MausY:=MausY-((MausY-WorkStartY) MOD zoom);
 IF MausY+zoom SHR 1>WorkEndY
  THEN BEGIN {Punktmitte wÑre au·erhalb}
        MausY:=MausY+ (WorkEndY-MausY) SHR 1
       END
  ELSE INC(MausY,zoom SHR 1);
END;

PROCEDURE UmrandeWorkarea(xstep,ystep:WORD);
{ in: WorkStartX|Y,WorkEndX|Y = zu umrandendes Rechteck}
{     xstep,ystep = Schrittweite fÅr Markierungen}
{     zoom = aktueller Zoomfaktor}
{out: - }
{rem: evtl. alte Markierungen werden mit schwarz gelîscht bevor die neuen}
{     Markierungen in wei· aufgebracht werden}
VAR i:WORD;
    b:BYTE;
BEGIN
 b:=BestWhite;
 SetColor(BestBlack);
 Rectangle(WorkStartX-2,WorkStartY-2,WorkEndX+2,WorkEndY+2);
 SetColor(b);
 Rectangle(WorkStartX-1,WorkStartY-1,WorkEndX+1,WorkEndY+1);

 i:=WorkStartX + zoom SHR 1;
 WHILE i<=WorkEndX DO
  BEGIN
   putpixel(i,WorkStartY-2,b);
   putpixel(i,WorkEndY  +2,b);
   inc(i,xstep*zoom);
  END;

 j:=WorkStartY + zoom SHR 1;
 WHILE j<=WorkEndY DO
  BEGIN
   putpixel(WorkStartX-2,j,b);
   putpixel(WorkEndX  +2,j,b);
   inc(j,ystep*zoom);
  END;
END;

PROCEDURE ShowActualTool;
{ in: aktuellesTool = aktuell selektiertes Tool}
{out: - }
{rem: aktuelles Tool wurde am Bildschirm ausgegeben}
VAR s:STRING[40];
BEGIN
 SetFillStyle(SolidFill,BestBlack);
 Bar(InfoX+WorkBreite-202,InfoY+25,InfoX+WorkBreite-10,InfoY+33);
 CASE aktuellesTool OF
  Punkt: s:='pixel';
  Rechteck: s:='rectangle';
  Ellipse_: s:='ellipse';
  FRechteck: s:='bar';
  FEllipse: s:='disc';
  Linie: s:='line';
  FuellEimer: s:='floodfill';
  Kopie: s:='duplicate';
  else s:='';
 END;
 SetColor(BestWhite);
 OutTextXY(InfoX+WorkBreite-202,InfoY+25,'selected tool: '+s);
END;

PROCEDURE ShowActualColor;
{ in: aktuelleFarbe = aktuell gewÑhlte Farbe}
{out: - }
{rem: aktuelle Zeichenfarbe wurde am Bildschirm ausgegeben}
VAR s:STRING[3];
BEGIN
 SetFillStyle(SolidFill,BestBlack);
 Bar(InfoX+WorkBreite-202,InfoY+10,InfoX+WorkBreite-17,InfoY+18);
 Str(aktuelleFarbe:2,s);
 SetColor(BestWhite);
 OutTextXY(InfoX+WorkBreite-202,InfoY+10,'drawing color:');
 SetFillStyle(SolidFill,aktuelleFarbe);
 Str(aktuelleFarbe:3,s);
 Bar(InfoX+WorkBreite-106+24,InfoY+10,InfoX+WorkBreite-106+38,InfoY+18);
 OutTextXY(InfoX+WorkBreite-106+42,InfoY+10,'('+s+')');
END;
 
PROCEDURE ShowZoom;
{ in: zoom = aktueller Zoomfaktor}
{out: - }
{rem: aktueller Zoomfaktor wurde am Bildschirm ausgegeben}
{     Dies geschieht sowohl numerisch als auch als Skalierung entlang}
{     der Workarea}
VAR s:STRING[3];
BEGIN
 SetFillStyle(SolidFill,BestBlack);
 Bar(InfoX+WorkBreite-130,InfoY,InfoX+WorkBreite-57,InfoY+8);
 SetColor(BestWhite);
 Str(zoom:3,s); OutTextXY(InfoX+WorkBreite-130,InfoY,'zoom:'+s);
 UmrandeWorkarea(8,8);
END;

PROCEDURE ShowOffset;
{ in: StartVirtualX|Y = aktuelle Ausschnittverschiebung}
{out: - }
{rem: aktueller Verschiebung wurde am Bildschirm ausgegeben}
VAR s:STRING[3];
BEGIN
 SetFillStyle(SolidFill,BestBlack);
 Bar(InfoX,InfoY+30,InfoX+95,InfoY+48);
 SetColor(BestWhite);
 Str(StartVirtualX:3,s); OutTextXY(InfoX,InfoY+30,'offset X:'+s);
 Str(StartVirtualY:3,s); OutTextXY(InfoX,InfoY+40,'offset Y:'+s);
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
 AdjustMouse;
 Absolute2WorkArea(relX,relY); {relative Koord. berechnen}
 SetFillStyle(SolidFill,BestBlack);
 Bar(InfoX,InfoY,InfoX+80,InfoY+29);
 SetColor(BestWhite);
 Str(relX:3,s); OutTextXY(InfoX,InfoY,'X:'+s);
 Str(relY:3,s); OutTextXY(InfoX,InfoY+10,'Y:'+s);
 b:=Workarea^.feld[relY,relX]; {Farbe des Punktes}
 Str(b:3,s);
 OutTextXY(InfoX,InfoY+20,'C:');
 SetFillStyle(SolidFill,b); Bar(InfoX+24,InfoY+20,InfoX+38,InfoY+28);
 OutTextXY(InfoX+42,InfoY+20,'('+s+')');
END;

PROCEDURE ShowFilename;
{ in: Filename* = relevante Daten/Koordinaten}
{out: - }
{rem: Filenamekurz wurde angezeigt}
BEGIN
 SetFillStyle(SolidFill,BestBlack);
 Bar(FilenameStartX,FilenameStartY,
     FilenameStartX+12*8,FilenameStartY+7);
 SetColor(BestWhite);
 OutTextXY(FilenameStartX,FilenameStartY,Filenamekurz);
END;

PROCEDURE UpdateWorkArea(vonX,vonY,bisX,bisY:INTEGER; fill:BOOLEAN);
{ in: vonX|Y, bisX|Y = zu restaurierender Workareaausschnitt in relativen}
{                      Koordinaten}
{     StartVirtualX|Y= aktuelle Ausschnittverschiebung}
{     zoom = aktueller Zoomfaktor}
{     WorkAreaMaxUsedX|Y = grî·te derzeit benutzte Koordinaten}
{     Workarea = Bildschirminhalt}
{     fill = TRUE, falls der nicht spezifizierte Workarea-Inhalt gelîscht}
{            werden soll}
{out: - }
{rem: spezifizierter Bildschirminhalt wurde restauriert}
{     vonX<=bisX, vonY<=bisY, d.h.: Punkte mÅssen geordnet sein!}
LABEL skipx,skipy;
VAR x,y,x1,y1,lowX,lowY,highX,highY:INTEGER;
    i:BYTE;
BEGIN
 IF fill
  THEN BEGIN
        SetFillStyle(SolidFill,BestBlack);
        Bar(WorkStartX,WorkStartY,WorkEndX,WorkEndY);
       END;

 lowX :=max(StartVirtualX,vonX);
 highX:=min(WorkAreaMaxUsedX,bisX);
 lowY :=max(StartVirtualY,vonY);
 highY:=min(WorkAreaMaxUsedY,bisY);
 IF zoom=1
  THEN FOR y:=lowY TO highY DO
        FOR x:=lowX TO highX DO
         PutPixel(x-StartVirtualX+WorkStartX,
                  y-StartVirtualY+WorkStartY,
                  WorkArea^.feld[y,x])
  ELSE BEGIN  {Zoomfaktor berÅcksichtigen}
        FOR y:=lowY TO highY DO
         BEGIN
          FOR x:=lowX TO highX DO
	   BEGIN
            x1:=(x -StartVirtualX)*zoom +WorkStartX;
            IF x1>WorkEndx THEN goto skipx;
            y1:=(y -StartVirtualY)*zoom +WorkStartY;
            IF y1>WorkEndY THEN goto skipy;
            SetFillStyle(SolidFill,WorkArea^.feld[y,x]);
            Bar(x1,y1,
                min(x1+pred(zoom),WorkEndX),min(y1+pred(zoom),WorkEndY));
           END; {of FOR x}
          skipx:;
         END; {of FOR y}
        skipy:;
       END; {of ELSE}
END;

PROCEDURE DrawWorkAreaPixel(X,Y:INTEGER; Farbe:BYTE; Art:ActionTyp;
                            check:BOOLEAN);
{ in: X,Y = zu zeichnender Punkt (relative Koord.) }
{     Farbe = Zeichenfarbe }
{     Art = STORE, falls Linie in Workarea[] eingetragen werden soll}
{           DRAW , falls Linie gezeichnet werden soll}
{           CLEAR, falls Linie gelîscht werden soll (dann: Farbe uninteressant)}
{     Check = TRUE, falls WorkAreaMaxUsedX|Y neuberechnet werden sollen}
{             (ZÑhlt eh nur, wenn Art=STORE ist!)}
{     zoom = aktueller Zoomfaktor}
{out: WorkAreaMaxUsedX|Y = evtl. neue Extremkoordinaten}
{rem: Es wird explizit geprÅft, da· die Punkte onscreen sind!}
VAR x1,y1:INTEGER;
BEGIN
 IF (X<StartVirtualX) OR (X>WorkBreite-1) OR (Y<StartVirtualY) OR (Y>WorkHoehe-1) THEN exit;
 IF Art=store
  THEN BEGIN
        Workarea^.feld[y,x]:=Farbe;
        IF Check
         THEN BEGIN
               IF Farbe<>transparent
	        THEN BEGIN {benutzte Workarea-FlÑche grî·er geworden?}
                      WorkAreaMaxUsedX:=max(X,WorkAreaMaxUsedX);
                      WorkAreaMaxUsedY:=max(Y,WorkAreaMaxUsedY);
                     END
                ELSE FindWorkAreaMaxUsed;
              END;
        exit
       END;
 IF zoom=1
  THEN BEGIN
        IF Art=draw THEN PutPixel(x-StartVirtualX+WorkStartX,
                                  y-StartVirtualY+WorkStartY,Farbe)
        ELSE {IF Art=clear THEN} PutPixel(x-StartVirtualX+WorkStartX,
                                          y-StartVirtualY+WorkStartY,
                                          Workarea^.feld[y,x])
       END

  ELSE BEGIN  {Zoomfaktor berÅcksichtigen}
        x1:=(x -StartVirtualX)*zoom +WorkStartX;
        IF x1>WorkEndx THEN exit;
        y1:=(y -StartVirtualY)*zoom +WorkStartY;
        IF y1>WorkEndY THEN exit;
        IF Art=draw THEN SetFillStyle(SolidFill,Farbe)
        ELSE {IF Art=clear THEN} SetFillStyle(SolidFill,Workarea^.feld[y,x]);
        Bar(x1,y1,min(x1+pred(zoom),WorkEndX),min(y1+pred(zoom),WorkEndY));
       END; {of ELSE}
END;

PROCEDURE DrawWorkAreaLine(x1,y1,x2,y2:INTEGER; Farbe:BYTE; Art:ActionTyp;
                           check:BOOLEAN);
{ in: (x1,y1),(x2,y2) = Start- und Endpunkt der zu zeichnenden Linie,}
{                       in relativen (=Workarea-)Koordinaten         }
{     Farbe = Zeichenfarbe fÅr Zeile}
{     Art = STORE, falls Linie in Workarea[] eingetragen werden soll}
{           DRAW , falls Linie gezeichnet werden soll}
{           CLEAR, falls Linie gelîscht werden soll (dann: Farbe uninteressant)}
{     Check = TRUE, falls WorkAreaMaxUsedX|Y neuberechnet werden sollen}
{             (ZÑhlt eh nur, wenn Art=STORE ist!)}
{     Workarea = aktuelle Grafikdaten}
{out: Linie wurde gezeichnet _oder_ in Workarea eingetragen oder gelîscht}
{     WorkAreaMaxUsedX|Y = neue Extremkoordinaten (nur wenn Art=1)}
{rem: stinknormaler Bresenham-Algorithmus!}
{     Die Åbergebenen Koordinaten mÅssen relative Koord. sein!}
VAR x,y,z,dx,dy,dz,i,maxDelta:INTEGER;

  PROCEDURE DrawWorkAreaPixel(X,Y:INTEGER; Farbe:BYTE);
  { in: X,Y = zu zeichnender Punkt (relative Koord.) }
  {     Farbe = Zeichenfarbe }
  {     zoom = aktueller Zoomfaktor}
  {out: - }
  {rem: Das ist eine etwas schnellere Variante als die gleichnamige obige,}
  {     da sie nur _zeichnen_ mu·!}
  VAR x1,y1:INTEGER;
  BEGIN
   IF (X<StartVirtualX) OR (X>WorkBreite-1) OR (Y<StartVirtualY) OR (Y>WorkHoehe-1) THEN exit;
   IF zoom=1
    THEN PutPixel(x-StartVirtualX+WorkStartX,y-StartVirtualY+WorkStartY,Farbe)
    ELSE BEGIN  {Zoomfaktor berÅcksichtigen}
          x1:=(x -StartVirtualX)*zoom +WorkStartX;
          IF x1>WorkEndx THEN exit;
          y1:=(y -StartVirtualY)*zoom +WorkStartY;
          IF y1>WorkEndY THEN exit;
          SetFillStyle(SolidFill,Farbe);
          Bar(x1,y1,min(x1+pred(zoom),WorkEndX),min(y1+pred(zoom),WorkEndY));
         END; {of ELSE}
  END;

BEGIN
 dx:=abs(x1-x2); dy:=abs(y1-y2);
 IF x1<x2  {Punkte nach x-Koordinate sortieren}
  THEN BEGIN
        x:=x1; y:=y1;
        IF y>y2 THEN z:=-1 ELSE z:=+1  {Y-Ri. von y zu y2 >0 oder <0 ?}
       END
  ELSE BEGIN
        x:=x2; y:=y2;
        IF y>y1 THEN z:=-1 ELSE z:=+1  {dto.: z=Schrittgrî·e in Y-Ri. }
       END;
 IF Art=store THEN Workarea^.feld[y,x]:=Farbe        {Startpunkt setzen}
 ELSE IF Art=draw THEN DrawWorkAreaPixel(x,y,Farbe)  {Startpunkt zeichnen}
 ELSE {IF Art=clear THEN} DrawWorkAreaPixel(x,y,Workarea^.feld[y,x]);
 IF dx>dy THEN maxDelta:=dx ELSE maxDelta:=dy;
 IF (dx=0) OR (dy=0)  {horizontale oder vertikale Linie?}
  THEN FOR i:=1 TO maxDelta DO {ja, schneller Sonderfall}
	BEGIN
         IF dx<>0 THEN inc(x) ELSE inc(y,z);
         IF Art=store THEN Workarea^.feld[y,x]:=Farbe
         ELSE IF Art=draw THEN DrawWorkAreaPixel(x,y,Farbe)
         ELSE {IF Art=clear THEN} DrawWorkAreaPixel(x,y,Workarea^.feld[y,x]);
        END
  ELSE BEGIN
        dz:=maxDelta SHR 1;
        FOR i:=1 TO maxDelta DO
	 BEGIN
          IF dz<dx  THEN BEGIN inc(dz,dy); inc(x,1) END; {horiz. Segment}
          IF dz>=dx THEN BEGIN dec(dz,dx); inc(y,z) END; {vert.  Segment}
          IF Art=store THEN Workarea^.feld[y,x]:=Farbe
          ELSE IF Art=draw THEN DrawWorkAreaPixel(x,y,Farbe)
          ELSE {IF Art=clear THEN} DrawWorkAreaPixel(x,y,Workarea^.feld[y,x]);
         END;
       END;

 IF (Art=store) 
  THEN BEGIN {evtl. neue Extremkoord. setzen}
        IF Check
         THEN BEGIN
               IF (Farbe<>transparent)
	        THEN BEGIN
                      WorkAreaMaxUsedX:=max(WorkAreaMaxUsedX,max(x1,x2));
                      WorkAreaMaxUsedY:=max(WorkAreaMaxUsedY,max(y1,y2))
                     END
                ELSE FindWorkAreaMaxUsed;
              END;
       END;
END;

PROCEDURE DrawWorkAreaRectangle(x1,y1,x2,y2:INTEGER; Farbe:BYTE; Art:ActionTyp);
{ in: (x1,y1),(x2,y2) = Start- und Endpunkt des zu zeichnenden Rechtecks    }
{                       (oder Quadrats) in relativen (=Workarea-)Koordinaten}
{     Farbe = Zeichenfarbe fÅr Rechteck/Quadrat}
{     Art = STORE, falls Rechteck in Workarea[] eingetragen werden soll}
{           DRAW , falls Rechteck gezeichnet werden soll}
{           CLEAR, falls Rechteck gelîscht werden soll (dann: Farbe uninteressant)}
{     Workarea = aktuelle Grafikdaten}
{out: Rechteck wurde gezeichnet _oder_ in Workarea eingetragen oder gelîscht}
{     WorkAreaMaxUsedX|Y = neue Extremkoordinaten (nur wenn Art=1)}
{rem: Die Åbergebenen Koordinaten mÅssen relative Koord. sein!}
{     Die Entscheidung, ob ein Rechteck oder ein Quadrat gezeichnet wird, wurde}
{     bereits vor dem Aufruf entschieden und geclippt!}
BEGIN
 DrawWorkAreaLine(x1,y1,x2,y1,Farbe,Art,FALSE);  {Rechteck/Quadrat aus Linien}
 DrawWorkAreaLine(x2,y1,x2,y2,Farbe,Art,FALSE);  {zusammensetzen}
 DrawWorkAreaLine(x2,y2,x1,y2,Farbe,Art,FALSE);
 DrawWorkAreaLine(x1,y2,x1,y1,Farbe,Art,FALSE);
 IF Art=STORE THEN FindWorkAreaMaxUsed;
END;

PROCEDURE DrawWorkAreaEllipse(x1,y1,x2,y2:INTEGER; Farbe:BYTE; Art:ActionTyp);
{ in: (x1,y1) = Kreismittelpunkt bzw. Ellipsenmittelpunkt}
{     (x2,y2) = Randpunkt des Kreises bzw.: Eckpunkt des der Ellipse umschrie-}
{               benen Rechtecks, so da· Halbachsen a:=|x2-x1|, b:=|y2-y1| sind}
{     Farbe = Zeichenfarbe fÅr Kreis/Ellipse }
{     Art = STORE, falls Kreis/Ellipse in Workarea[] eingetragen werden soll}
{           DRAW , falls Kreis/Ellipse gezeichnet werden soll}
{           CLEAR, falls Kreis/Ellipse gelîscht werden soll (dann: Farbe uninteressant)}
{     Workarea = aktuelle Grafikdaten}
{     Objekt.aligned = TRUE|FALSE fÅr: Kreis|Ellipse}
{out: Kreis/Ellipse wurde gezeichnet _oder_ in Workarea eingetragen oder gelîscht}
{     WorkAreaMaxUsedX|Y = neue Extremkoordinaten (nur wenn Art=1)}
{rem: Die Åbergebenen Koordinaten mÅssen relative Koord. sein!}
VAR a,b,r,rq,x,y,u1,u2,u3,u4,v1,v2,v3,v4:INTEGER;
BEGIN
 IF Objekt.aligned
  THEN BEGIN {Kreis}
        rq:=sqr(x2-x1)+sqr(y2-y1);
        r:=TRUNC(sqrt(rq)+1);
        FOR y:=0 TO TRUNC(r/sqrt(2)) DO
         BEGIN
          x:=TRUNC(sqrt(rq-sqr(y)));
          u1:=x1-x; v1:=y1-y;
          u2:=x1+x; v2:=y1+y;
          u3:=x1-y; v3:=y1-x;
          u4:=x1+y; v4:=y1+x;
          DrawWorkAreaPixel(u1,v1,Farbe,Art,FALSE);
          DrawWorkAreaPixel(u1,v2,Farbe,Art,FALSE);
          DrawWorkAreaPixel(u2,v1,Farbe,Art,FALSE);
          DrawWorkAreaPixel(u2,v2,Farbe,Art,FALSE);
          DrawWorkAreaPixel(u3,v3,Farbe,Art,FALSE);
          DrawWorkAreaPixel(u3,v4,Farbe,Art,FALSE);
          DrawWorkAreaPixel(u4,v3,Farbe,Art,FALSE);
          DrawWorkAreaPixel(u4,v4,Farbe,Art,FALSE);
         END;
        IF Art=STORE THEN FindWorkAreaMaxUsed;
       END
  ELSE BEGIN {Ellipse}
        a:=abs(x2-x1); b:=abs(y2-y1); {Halbachsen berechnen}
        IF (a=0) OR (b=0)
	 THEN BEGIN {Sonderfall: Ellipse entartet zum Strich oder Punkt}
               IF a=0
                THEN DrawWorkAreaLine(x1,min(max(y1-(y2-y1),0),WorkHoehe-1),
                                      x2,y2,Farbe,Art,TRUE)
                ELSE DrawWorkAreaLine(min(max(x1-(x2-x1),0),WorkBreite-1),
                                      y1,x2,y2,Farbe,Art,TRUE);
               exit;
              END;
         {Punkte in x-Ri. durchgehen und y berechnen}
         FOR x:=0 TO a DO  {Ellipsengleichung x˝/a˝ + y˝/b˝ =1}
	  BEGIN            {nach y auflîsen!}
           y:=round(sqrt(1.0-sqr(x/a))*b);
           u1:=x1-x; v1:=y1-y;
           u2:=x1+x; v2:=y1+y;
           DrawWorkAreaPixel(u1,v1,Farbe,Art,FALSE);
           DrawWorkAreaPixel(u1,v2,Farbe,Art,FALSE);
           DrawWorkAreaPixel(u2,v1,Farbe,Art,FALSE);
           DrawWorkAreaPixel(u2,v2,Farbe,Art,FALSE);
          END;
         {Punkte in y-Ri. durchgehen und x berechnen}
         FOR y:=0 TO b DO  {Ellipsengleichung x˝/a˝ + y˝/b˝ =1}
	  BEGIN            {nach x auflîsen!}
           x:=round(sqrt(1.0-sqr(y/b))*a);
           u1:=x1-x; v1:=y1-y;
           u2:=x1+x; v2:=y1+y;
           DrawWorkAreaPixel(u1,v1,Farbe,Art,FALSE);
           DrawWorkAreaPixel(u1,v2,Farbe,Art,FALSE);
           DrawWorkAreaPixel(u2,v1,Farbe,Art,FALSE);
           DrawWorkAreaPixel(u2,v2,Farbe,Art,FALSE);
          END;
        IF Art=STORE THEN FindWorkAreaMaxUsed;
       END;
END;

PROCEDURE DrawWorkAreaBar(x1,y1,x2,y2:INTEGER; Farbe:BYTE; Art:ActionTyp);
{ in: (x1,y1),(x2,y2) = Start- und Endpunkt des zu zeichnenden ausgefÅllten}
{                       Rechtecks (oder Quadrats) in relativen (=Workarea-)}
{                       Koordinaten}
{     Farbe = Zeichenfarbe fÅr Rechteck/Quadrat}
{     Art = STORE, falls Rechteck in Workarea[] eingetragen werden soll}
{           DRAW , falls Rechteck gezeichnet werden soll}
{           CLEAR, falls Rechteck gelîscht werden soll (dann: Farbe uninteressant)}
{     Workarea = aktuelle Grafikdaten}
{out: Rechteck wurde gezeichnet _oder_ in Workarea eingetragen oder gelîscht}
{     WorkAreaMaxUsedX|Y = neue Extremkoordinaten (nur wenn Art=1)}
{rem: Die Åbergebenen Koordinaten mÅssen relative Koord. sein!}
{     Die Entscheidung, ob ein Rechteck oder ein Quadrat gezeichnet wird, wurde}
{     bereits vor dem Aufruf entschieden und geclippt!}
VAR y:WORD;
BEGIN
 FOR y:=min(y1,y2) TO max(y1,y2) DO   {Rechteck/Quadrat aus Linien bilden}
  DrawWorkAreaLine(x1,y,x2,y,Farbe,Art,FALSE);
 IF Art=STORE THEN FindWorkAreaMaxUsed;
END;

PROCEDURE DrawWorkAreaDisc(x1,y1,x2,y2:INTEGER; Farbe:BYTE; Art:ActionTyp);
{ in: (x1,y1) = Scheibenmittelpunkt bzw. Ellipsenmittelpunkt}
{     (x2,y2) = Randpunkt der Scheibe bzw.: Eckpunkt des der Ellipse umschrie-}
{               benen Rechtecks, so da· Halbachsen a:=|x2-x1|, b:=|y2-y1| sind}
{     Farbe = Zeichenfarbe fÅr Scheibe/Ellipse }
{     Art = STORE, falls Scheibe/Ellipse in Workarea[] eingetragen werden soll}
{           DRAW , falls Scheibe/Ellipse gezeichnet werden soll}
{           CLEAR, falls Scheibe/Ellipse gelîscht werden soll (dann: Farbe uninteressant)}
{     Workarea = aktuelle Grafikdaten}
{     Objekt.aligned = TRUE|FALSE fÅr: Scheibe|ausgefÅllte Ellipse}
{out: Scheibe/Ellipse wurde gezeichnet _oder_ in Workarea eingetragen oder gelîscht}
{     WorkAreaMaxUsedX|Y = neue Extremkoordinaten (nur wenn Art=1)}
{rem: Die Åbergebenen Koordinaten mÅssen relative Koord. sein!}
VAR a,b,rq,x,y,u1,u2,u3,u4,v1,v2,v3,v4:INTEGER;
BEGIN
 IF Objekt.aligned
  THEN BEGIN {Scheibe}
        rq:=sqr(x2-x1)+sqr(y2-y1);
        FOR y:=0 TO ROUND(sqrt(rq/2)) DO
         BEGIN
          x:=TRUNC(sqrt(rq-sqr(y)));
          u1:=max(x1-x,0);            v1:=max(y1-y,0);
          u2:=min(x1+x,WorkBreite-1); v2:=min(y1+y,WorkHoehe-1);
          u3:=max(x1-y,0);            v3:=max(y1-x,0);
          u4:=min(x1+y,WorkBreite-1); v4:=min(y1+x,WorkHoehe-1);
          DrawWorkAreaLine(u1,v1,u2,v1,Farbe,Art,FALSE);
          DrawWorkAreaLine(u1,v2,u2,v2,Farbe,Art,FALSE);
          DrawWorkAreaLine(u3,v3,u4,v3,Farbe,Art,FALSE);
          DrawWorkAreaLine(u3,v4,u4,v4,Farbe,Art,FALSE);
         END;
        IF Art=STORE THEN FindWorkAreaMaxUsed;
       END
  ELSE BEGIN {Ellipse}
        a:=abs(x2-x1); b:=abs(y2-y1); {Halbachsen berechnen}
        IF (a=0) OR (b=0)
	 THEN BEGIN {Sonderfall: Ellipse entartet zum Strich oder Punkt}
               IF a=0
                THEN DrawWorkAreaLine(x1,min(max(y1-(y2-y1),0),WorkHoehe-1),
                                      x2,y2,Farbe,Art,TRUE)
                ELSE DrawWorkAreaLine(min(max(x1-(x2-x1),0),WorkBreite-1),
                                      y1,x2,y2,Farbe,Art,TRUE);
               exit;
              END;
         {Punkte in y-Ri. durchgehen und x berechnen}
         FOR y:=0 TO b DO  {Ellipsengleichung x˝/a˝ + y˝/b˝ =1}
	  BEGIN            {nach x auflîsen!}
           x:=trunc(sqrt(1.0-sqr(y/b))*a);
           u1:=max(x1-x,0);            v1:=max(y1-y,0);
           u2:=min(x1+x,WorkBreite-1); v2:=min(y1+y,WorkHoehe-1);
           DrawWorkAreaLine(u1,v1,u2,v1,Farbe,Art,FALSE);
           DrawWorkAreaLine(u1,v2,u2,v2,Farbe,Art,FALSE);
          END;
        IF Art=STORE THEN FindWorkAreaMaxUsed;
       END;
END;

PROCEDURE DrawWorkAreaFill(x1,y1:INTEGER; Farbe:BYTE; Art:ActionTyp);
{ in: (x1,y1) = Startpunkt, von dem aus gefÅllt werden soll}
{     Farbe = FÅllfarbe}
{     Art = STORE, falls FÅllgebiet in Workarea[] eingetragen werden soll}
{           DRAW , falls FÅllgebiet gezeichnet werden soll}
{           CLEAR, falls FÅllgebiet gelîscht werden soll (dann: Farbe uninteressant)}
{     Workarea = aktuelle Grafikdaten}
{out: Workarea wurde von (x1,y1) ausgehend "geflutet" _oder_ in Workarea eingetragen}
{     oder gelîscht}
{     WorkAreaMaxUsedX|Y = neue Extremkoordinaten (nur wenn Art=1)}
{rem: Die Åbergebenen Koordinaten mÅssen relative Koord. sein!}
VAR aufFarbe:BYTE;
    tempArea:^WorkAreaTyp;

 PROCEDURE RecursiveFill(x,y:WORD);
 { in: (x,y)=Ausgangspunkt fÅr das FÅllen}
 {     aufFarbe=Farbe, die Åberschrieben werden darf}
 {     Farbe=FÅllfarbe}
 {     Art=DRAW oder STORE}
 {     tempArea=Kopie der Workarea}
 {out: Alle von (x,y) aus erreichbaren Pixel der Farbe "aufFarbe" wurden}
 {     mit der Farbe "Farbe" Åberschrieben}
 {rem: Der Alg. sucht die lÑngste horizontale Linie, die er durchgehend }
 {     zeichnen kann und ruft sich rekursiv fÅr die dadurch entstehenden}
 {     oberen und unteren HÑlften auf}
 VAR i,StartX,EndX:INTEGER;
 BEGIN
  IF tempArea^.feld[y,x]<>aufFarbe THEN exit; {Abbruch der Rekursion}
  StartX:=x; EndX:=x;
  WHILE (EndX<=WorkBreite-1) AND
        ( (EndX=WorkBreite-1) OR (tempArea^.feld[y,EndX+1]=aufFarbe))
   DO inc(EndX);     {boolesche Kurzschlu·auswertung wichtig!}
  IF EndX=WorkBreite THEN dec(EndX);
  {damit: EndX=letztes X, das gefÅllt werden darf}
  WHILE (StartX>=0) AND
        ( (StartX=0) OR (tempArea^.feld[y,StartX-1]=aufFarbe))
   DO dec(StartX);   {boolesche Kurzschlu·auswertung wichtig!}
  IF StartX=-1 THEN inc(StartX);
  {damit: StartX=erstes X, das gefÅllt werden darf}

  DrawWorkAreaLine(StartX,y,EndX,y,Farbe,Art,FALSE); {diese Linie zeichnen}
  FOR i:=StartX TO EndX DO tempArea^.feld[y,i]:=Farbe; {und merken!}

  IF y>0  {obere HÑlfte abarbeiten}
   THEN FOR i:=StartX TO EndX DO RecursiveFill(i,pred(y));
  IF y<WorkHoehe-1  {untere HÑlfte abarbeiten}
   THEN FOR i:=StartX TO EndX DO RecursiveFill(i,succ(y));
 END;

BEGIN
 IF (Art=DRAW) OR (Art=STORE)
  THEN BEGIN
        aufFarbe:=WorkArea^.feld[y1,x1]; {auf welcher Farbe soll gefÅllt werden?}
        IF aufFarbe<>Farbe
	 THEN BEGIN
               New(tempArea); Move(WorkArea^,tempArea^,SizeOf(WorkArea^));
               RecursiveFill(x1,y1); {na dann mach mal!}
               IF Art=STORE
                THEN BEGIN
                      Move(tempArea^,WorkArea^,SizeOf(WorkArea^));
                      FindWorkAreaMaxUsed
                     END;
               Dispose(tempArea);
              END;
       END
  ELSE {IF Art=CLEAR THEN}
       BEGIN
        UpdateWorkArea(StartVirtualX,StartVirtualY,
                       WorkAreaMaxUsedX,WorkAreaMaxUsedY,TRUE);
       END;
END;

PROCEDURE DrawWorkAreaCopy(x1,y1,x2,y2,x3,y3:INTEGER; Art:ActionTyp);
{ in: (x1,y1),(x2,y2) = Start- und Endpunkt des zu zeichnenden Bereichs}
{     (x3,y3)         = Zielpunkt dafÅr (nur fÅr stage=2)}
{                       (alles in relativen (=Workarea-)Koordinaten) }
{     Art = STORE, falls Bereich in Workarea[] eingetragen werden soll}
{           DRAW , falls Bereich gezeichnet werden soll}
{           CLEAR, falls Bereich gelîscht werden soll  }
{     Workarea = aktuelle Grafikdaten }
{     Objekt.stage = aktueller Zustand (1 oder 2)}
{out: Bereich wurde gezeichnet _oder_ in Workarea eingetragen oder gelîscht}
{     WorkAreaMaxUsedX|Y = neue Extremkoordinaten (nur wenn Art=STORE)}
{rem: Die Åbergebenen Koordinaten mÅssen relative Koord. sein!}
{     Punkte der Farbe "transparent" werden als durchsichtig behandelt!}
VAR x,y:WORD;
    farbe:BYTE;
BEGIN
 IF x1>x2 THEN BEGIN x:=x1; x1:=x2; x2:=x END;
 IF y1>y2 THEN BEGIN y:=y1; y1:=y2; y2:=y END;
 IF (Art=DRAW) OR (Art=CLEAR)
  THEN BEGIN
        IF Objekt.stage=1
	 THEN BEGIN {gepunktete Box aufspannen}
               farbe:=BestWhite;
               FOR x:=x1 TO x2 DO
		BEGIN
                 DrawWorkAreaPixel(x,y1,farbe,Art,FALSE);
                 DrawWorkAreaPixel(x,y2,farbe,Art,FALSE);
                 IF farbe=BestWhite
                  THEN farbe:=BestBlack
                  ELSE farbe:=BestWhite
                END;
               farbe:=BestBlack;
               FOR y:=SUCC(y1) TO PRED(y2) DO
		BEGIN
                 DrawWorkAreaPixel(x1,y,farbe,Art,FALSE);
                 DrawWorkAreaPixel(x2,y,farbe,Art,FALSE);
                 IF farbe=BestWhite
                  THEN farbe:=BestBlack
                  ELSE farbe:=BestWhite
                END;
              END
	 ELSE BEGIN {Bereich (x1,y1)-(x2,y2) nach (x3,y3) kopieren oder lîschen}
               FOR y:=y1 TO y2 DO
                FOR x:=x1 TO x2 DO
                 IF WorkArea^.feld[y,x]<>transparent
                  THEN DrawWorkAreaPixel(x3+(x-x1),y3+(y-y1),
                                         WorkArea^.feld[y,x],Art,FALSE)
              END;
       END
  ELSE BEGIN {Art=Store (AND stage=2)}
        FOR y:=y1 TO y2 DO
         FOR x:=x1 TO x2 DO
          IF WorkArea^.feld[y,x]<>transparent
           THEN DrawWorkAreaPixel(x3+(x-x1),y3+(y-y1),
                                  WorkArea^.feld[y,x],STORE,FALSE);
        FindWorkAreaMaxUsed;
       END;
END;


FUNCTION sign(a:INTEGER):INTEGER;
BEGIN
 IF a<0 THEN sign:=-1
 ELSE IF a>0 THEN sign:=+1
 ELSE sign:=0
END;

PROCEDURE ClearOldObject;
{ in: Objekt.Typ = zu restaurierender Typ}
{     Objekt.StartX,StartY,LastX,LastY = Start-/Endpunkte der Maus fÅr}
{                                        dieses Objekt}
{out: - }
CONST DontCare=0;
VAR tempX,tempY:INTEGER;
BEGIN
 WITH Objekt DO
  BEGIN
   IF stage=0 THEN exit; {kein Objekt begonnen, also nichts zum lîschen!}
   CASE Typ OF
    Punkt:DrawWorkAreaPixel(StartX,StartY,DontCare,CLEAR,FALSE);
    Linie:DrawWorkAreaLine(StartX,StartY,LastX,LastY,DontCare,CLEAR,FALSE);
    Rechteck:DrawWorkAreaRectangle(StartX,StartY,LastX,LastY,DontCare,CLEAR);
    Ellipse_:DrawWorkAreaEllipse(StartX,StartY,LastX,LastY,DontCare,CLEAR);
    FRechteck:DrawWorkAreaBar(StartX,StartY,LastX,LastY,DontCare,CLEAR);
    FEllipse:DrawWorkAreaDisc(StartX,StartY,LastX,LastY,DontCare,CLEAR);
    FuellEimer:DrawWorkAreaFill(LastX,LastY,DontCare,CLEAR);
    Kopie:DrawWorkAreaCopy(StartX,StartY,LastX,LastY,actX,actY,CLEAR);
    else ErrBeep;
   END; {of CASE}
  END; {of WITH}
END;

PROCEDURE DrawNewObject;
{ in: Objekt.Typ = zu zeichnender Typ}
{     Objekt.StartX,StartY,LastX,LastY = Start-/Endpunkte der Maus fÅr}
{                                        dieses Objekt}
{     Objekt.Farbe = Zeichenfarbe}
{out: - }
{rem: Aktuelles Objekt wurde im Bereich der Workarea gezeichnet, ohne }
{     aber in die Workarea[] aufgenommen worden zu sein}
VAR tempX,tempY:INTEGER;
BEGIN
 WITH Objekt DO
  BEGIN
   IF stage=0 THEN exit; {kein Objekt begonnen, also nichts zum zeichnen!}
   CASE Typ OF
    Punkt:DrawWorkAreaPixel(StartX,StartY,aktuelleFarbe,DRAW,FALSE);
    Linie:DrawWorkAreaLine(StartX,StartY,LastX,LastY,aktuelleFarbe,DRAW,FALSE);
    Rechteck:DrawWorkAreaRectangle(StartX,StartY,LastX,LastY,aktuelleFarbe,DRAW);
    Ellipse_:DrawWorkAreaEllipse(StartX,StartY,LastX,LastY,aktuelleFarbe,DRAW);
    FRechteck:DrawWorkAreaBar(StartX,StartY,LastX,LastY,aktuelleFarbe,DRAW);
    FEllipse:DrawWorkAreaDisc(StartX,StartY,LastX,LastY,aktuelleFarbe,DRAW);
    FuellEimer:DrawWorkAreaFill(LastX,LastY,aktuelleFarbe,DRAW);
    Kopie:DrawWorkAreaCopy(StartX,StartY,LastX,LastY,actX,actY,DRAW);
    else ErrBeep;
   END; {of CASE}
  END; {of WITH}
END;

PROCEDURE StoreObject;
{ in: Objekt.Typ = zu zeichnender Typ}
{     Objekt.StartX,StartY,LastX,LastY = Start-/Endpunkte der Maus fÅr}
{                                        dieses Objekt}
{     Objekt.Farbe = Zeichenfarbe}
{out: - }
{rem: Objekt wurde in Workarea[] Åbernommen; es ist dabei unerheblich,}
{     ob das Objekt auf dem Schirm sichtbar ist oder nicht (natÅrlich }
{     sollte es sichtbar sein, um den Benutzer nicht zu verwirren,    }
{     aber es ist eben nicht zwingend erforderlich)}
VAR tempX,tempY:INTEGER;
BEGIN
 WITH Objekt DO
  BEGIN
   CASE Typ OF
    Punkt:DrawWorkAreaPixel(StartX,StartY,aktuelleFarbe,STORE,TRUE);
    Linie:DrawWorkAreaLine(StartX,StartY,LastX,LastY,aktuelleFarbe,STORE,TRUE);
    Rechteck:DrawWorkAreaRectangle(StartX,StartY,LastX,LastY,aktuelleFarbe,STORE);
    Ellipse_:DrawWorkAreaEllipse(StartX,StartY,LastX,LastY,aktuelleFarbe,STORE);
    FRechteck:DrawWorkAreaBar(StartX,StartY,LastX,LastY,aktuelleFarbe,STORE);
    FEllipse:DrawWorkAreaDisc(StartX,StartY,LastX,LastY,aktuelleFarbe,STORE);
    FuellEimer:DrawWorkAreaFill(LastX,LastY,aktuelleFarbe,STORE);
    Kopie:DrawWorkAreaCopy(StartX,StartY,LastX,LastY,actX,actY,STORE);
    else ErrBeep;
   END; {of CASE}

   stage:=0; {Objekt beendet}
  END; {of WITH}
END;

PROCEDURE ShowPalName;
{ in: Palnamekurz = Palettenname}
{     ActualColors = aktuelle Farben}
{out: - }
BEGIN
 SetFillStyle(SolidFill,BestBlack);
 Bar(PalnameStartX,PalnameStartY,PalnameStartX+(18 SHL 3),PalnameStartY+8);
 IF PalEqual(ActualColors,DefaultColors)
  THEN BEGIN {Standardpalette}
        SetColor(BestWhite);
        OutTextXY(PalnameStartX,PalnameStartY,'(Default palette)');
       END
  ELSE BEGIN {Palette wurde geladen, also darstellen!}
        SetColor(BestWhite);
        OutTextXY(PalnameStartX,PalnameStartY,Palnamekurz);
       END;
END;

PROCEDURE RestoreScreen;
{ in: WorkArea = Spritedaten bzw. Bilddaten}
{     WorkAreaMaxUsedX|Y = vom Bild benutzte Extremkoordinaten}
{out: Grafikbildschirm wurde restauriert}
VAR s:STRING[5];

 PROCEDURE MenuZeigen;
 VAR s:STRING[3];
 BEGIN
  globalI:=1;
  WHILE (menu[globalI].x1<menu[globalI].x2) AND (menu[globalI].Paint) DO
   BEGIN
    menu[globalI].Show;
    INC(globalI)
   END;
 END;

 PROCEDURE WorkAreaDarstellen;
 BEGIN
  UpdateWorkArea(StartVirtualX,StartVirtualY,
                 WorkAreaMaxUsedX,WorkAreaMaxUsedY,FALSE);
  DrawNewObject;
  ShowFilename;
 END;

 PROCEDURE PaletteZeigen;
 VAR x,y:WORD;
     s:STRING[3];
     i:BYTE;
 BEGIN
  SetColor(BestWhite);
  FOR i:=0 TO 15 DO
   BEGIN
    STR(i:2,s);
    OutTextXY(PaletteX+25+i*PalBreite,PaletteY,s);
    STR(i*16:3,s);
    OutTextXY(PaletteX,PaletteY+10+3+i*PalHoehe,s);
   END;
  FOR y:=0 TO 15 DO
   BEGIN
    FOR x:=0 TO 15 DO
     BEGIN
      SetFillStyle(SolidFill,y*16+x);
      Bar(PaletteX+25+x*PalBreite,PaletteY+10+y*PalHoehe,
          PaletteX+25+succ(x)*PalBreite-3,PaletteY+10+succ(y)*PalHoehe-3);
     END;
   END;
 END;


BEGIN
 SetPalette(ActualColors);  {aktuelle Farben wieder einsetzen}
 SetFillStyle(SolidFill,BestBlack);
 Bar(0,0,GetMaxX,GetMaxY);

 MenuZeigen;
 PaletteZeigen;
 IF InWorkArea THEN ShowCursorDaten;

 UmrandeWorkarea(8,8);
 ShowFileName;
 WorkAreaDarstellen;

 ShowZoom;
 ShowActualColor;
 ShowOffset;
 ShowActualTool;

 DrawNewObject; 
 ShowPalName;

 SetColor(BestWhite);
 SetTextStyle(DefaultFont,HorizDir,2);
 OutTextXY(0,0,Titel1);
 SetTextStyle(DefaultFont,HorizDir,1);

END;

PROCEDURE loescheWorkarea;
VAR i:Integer;
BEGIN
 SetColor(BestBlack);
 FOR i:=WorkStartY TO WorkEndY DO line(WorkStartX,i,WorkEndX,i);
END;

PROCEDURE ChangeDir(pfad:TPath);
{ in: pfad = vollstÑndiger MSDos-Filename}
{out: - }
{rem: Es wurde in den in "pfad" genannten Pfad gewechselt}
VAR D:DirStr;
    N:NameStr;
    E:ExtStr;
BEGIN
 FSplit(pfad,D,N,E);
 IF D[length(d)]='\' THEN Delete(D,length(D),1);
 ChDir(D);
 GetDir(0,pfad);
END;

PROCEDURE ladeSprite;
{ in: Workarea^ = alte Grafikdaten (uninteressant, wenn Shift=FALSE)}
{     Shift = TRUE|FALSE fÅr: alten Inhalt Åberlagern/lîschen}
{out: Filenamelang = gewÑhlter Dateiname mit Pfadangabe}
{     Filenamekurz = dto., nur Name+Extension}
{     WorkArea = Bild der geladenen Datei    }
{     WorkAreaMaxUsedX|Y = Extremkoordinaten }
VAR s,name:String;
    Pfad:TPath;
    Dirname : DirStr;
    Filename: NameStr;
    Extname : ExtStr;
    fehler:Boolean;
    GrafikBild:Pointer;
    Size,i,offset,vonwo:Word;
    zeile,spalte,startx,endx:INTEGER;
    plane:BYTE;
    sprite:^spritetyp;  {Hier steht das eigentliche Sprite drinnen}

    FUNCTION Spritedatenlesen(name:String):Boolean;
    { in: "name" ist der vollstÑndige Name des einzulesenden Sprites   }
    {out: Die globale Variable "sprite^" enthÑlt die Daten des Sprites }
    {     Ist "name" kein 256-Farben-Sprite oder zu gro·, um in der    }
    {     Workarea bearbeitet zu werden, so wird "FALSE" zurÅckgegeben,}
    {     anderenfalls "TRUE"                                          }
    {rem: Das Sprite wird NICHT dargestellt, sondern nur eingelesen!   }
    VAR f:FileOfByte;
        size:longint;
        i,j:Word;

        PROCEDURE FehlerMeldung(s:String);
        VAR ch:char;
        BEGIN
         WRITELN(#7);
         WRITE(s+' <any key>');
         ch:=readkey;
         while keypressed do ch:=readkey
        END;

    BEGIN
     _assign(f,name);
     {$I-}
     _reset(f); size:=_FileSize(f);
     {$I+}
     if (ioresult<>0) OR (CompressError<>CompressErr_NoError)
      THEN BEGIN
            FehlerMeldung('I/O-error while trying to open file!');
            Spritedatenlesen:=false;
            exit
           END;
     if size>SizeOF(sprite^.readin)
      THEN BEGIN
            FehlerMeldung('File too big!');
            _close(f);
            Spritedatenlesen:=false;
            exit
           END;
     if size<Kopf
      THEN BEGIN
            FehlerMeldung('File to small to be a sprite file!');
            Spritedatenlesen:=false;
            exit
           END;

     _blockread(f,sprite^.readin,size);
     _close(f); WRITELN;

     WITH Sprite^ DO
      BEGIN  {Jetzt kommt die FehlerprÅfung:}
       IF (Kennung[1]<>'K') or (Kennung[2]<>'R')   {Kennung muss "KR" sein}
        or (SpriteLength<>size)                    {Groesse muss stimmen}
        or (Zeiger_auf_Plane[1]-Zeiger_auf_Plane[0]<>  {Planegrî·e mu· mit}
            Breite_in_4er_Gruppen*Hoehe_in_Zeilen) {Abmessungen Åbereinstimmen}
        or (ZeigerR-ZeigerL<>Hoehe_in_Zeilen*2)  {X-Grenztabellengrî·e auch}
        or (ZeigerU-ZeigerO<>Breite_in_4er_Gruppen*8)  {dto., fÅr Y-Gr.tab.}
        or (Translate[1]<>1)    {die 4 Translate-EintrÑge im Spriteheader}
        or (Translate[2]<>2)    {mÅssen die ersten 4 Zweierpotenzwerte haben}
        or (Translate[3]<>4)
        or (Translate[4]<>8)
         THEN BEGIN
               FehlerMeldung('This is no 256-color-sprite!');
               Spritedatenlesen:=false;
               exit
              END;

       IF (Hoehe_in_Zeilen>Workhoehe) or
          (Breite_in_4er_Gruppen*4>WorkBreite)
        THEN BEGIN
              FehlerMeldung('Sprite to big to fit into workarea!');
              Spritedatenlesen:=false;
              exit
             END;
      END;

     Spritedatenlesen:=true
    END;

BEGIN
 RestoreCRTMode;
 ClrScr;

 GotoXY(20,1);
 WRITE('Select your *.COD-file to load with the cursor keys,');
 GotoXY(20,2);
 WRITE('PageUP/PageDOWN, HOME/END and CR; <ESC> to cancel:');
 GetDir(0,Pfad);
 name:=ChooseSingleFile(20,4,20,Pfad,'*.COD',fehler);
 IF name<>'' THEN ChangeDir(name);
 IF fehler THEN
  BEGIN
   setgraphmode(DisplayMode);
   RestoreScreen;
   write(#7);
   OkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,'ok',
         '*** I/O-error! ***',
         'Couldn''t open file/device',name,Abfrage);
  END
 ELSE IF name=''
  THEN BEGIN {nichts ausgewÑhlt (ESC gedrÅckt)}
        setgraphmode(DisplayMode);
        RestoreScreen;
       END
 ELSE BEGIN {Spritedaten lesen}
       New(sprite);
       IF Spritedatenlesen(name)  {ok, Daten einlesen und prÅfen}
        THEN BEGIN
              Filenamelang:=name;
              FSplit(Filenamelang, Dirname, Filename, Extname);
              Filenamekurz:=Filename+Extname;

              {Jetzt Spritedaten nach WorkArea decodieren:}
              IF NOT Shift
               THEN FillChar(WorkArea^,SizeOf(WorkArea^),transparent);
              WITH sprite^ DO
	       BEGIN
                FOR zeile:=0 TO Pred(Hoehe_in_Zeilen) DO
		 BEGIN
                  startx:=zeigerL+zeile shl 1;
                  endx  :=zeigerR+zeile shl 1;
                  FOR spalte:=readin[succ(startx)] shl 8 +readin[startx]
                   TO readin[succ(endx)] shl 8 +readin[endx] DO
		   BEGIN
                    plane:=spalte and 3;
                    offset:=spalte shr 2 +zeile*Breite_in_4er_Gruppen;
                    vonwo:=Zeiger_auf_Plane[plane];
                    IF readin[vonwo+offset]<>transparent
                     THEN WorkArea^.feld[zeile,spalte]:=readin[vonwo+offset]
                   END;
                 END;
             (* Folgende Zuweisungen wÑren zu ungenau, da Sprites    *)
             (* in X-Richtung immer als Vielfaches von 4 gespeichert *)
             (* werden: *)
                (*
                WorkAreaMaxUsedX:=min(Breite_in_4er_Gruppen*4-1,XMAX);
                WorkAreaMaxUsedY:=pred(Hoehe_in_Zeilen);
                *)
                FindWorkAreaMaxUsed; (* ...deshalb lieber so! *)
               END;

              setgraphmode(DisplayMode);
              RestoreScreen;
             END
        ELSE BEGIN {keine oder fehlerhafte *.COD-Datei}
              Filenamelang:=''; Filenamekurz:='';
              setgraphmode(DisplayMode);
              RestoreScreen;
             END;
       Dispose(sprite);
      END;
END;

PROCEDURE ladePalette;
{ in: -}
{out: Palnamelang = gewÑhlter Dateiname mit Pfadangabe}
{     Palnamekurz = dto., nur Name+Extension}
{rem: Ist die geladene Palette gleich der Standardpalette, so werden}
{     Palname* auf '' gesetzt}
VAR s,name:String;
    Pfad:TPath;
    Dirname : DirStr;
    Filename: NameStr;
    Extname : ExtStr;
    fehler:Boolean;
    neuPal:BigPalette;
    i:WORD;

        PROCEDURE FehlerMeldung(s:String);
        VAR ch:char;
        BEGIN
         WRITELN(#7);
         WRITE(s+' <any key>');
         ch:=readkey;
         while keypressed do ch:=readkey
        END;

BEGIN
 RestoreCRTMode;
 ClrScr;

 GotoXY(20,1);
 WRITE('Select your *.PAL-file to load with the cursor keys,');
 GotoXY(20,2);
 WRITE('PageUP/PageDOWN, HOME/END and CR; <ESC> to cancel:');
 GetDir(0,Pfad);
 name:=ChooseSingleFile(20,4,20,Pfad,'*.PAL',fehler);
 IF name<>'' THEN ChangeDir(name);
 IF fehler THEN
  BEGIN
   setgraphmode(DisplayMode);
   RestoreScreen;
   write(#7);
   OkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,'ok',
         '*** I/O-error! ***',
         'Couldn''t open file/device',name,Abfrage);
  END
 ELSE IF name=''
  THEN BEGIN {nichts ausgewÑhlt (ESC gedrÅckt)}
        setgraphmode(DisplayMode);
        RestoreScreen;
       END
 ELSE IF LoadPalette(name,0,neuPal)<>0  {ok, Daten einlesen und prÅfen}
       THEN BEGIN
             Palnamelang:=name;
             FSplit(Palnamelang, Dirname, Filename, Extname);
             Palnamekurz:=Filename+Extname;

             setgraphmode(DisplayMode);
             ActualColors:=neuPal;
             SetPalette(ActualColors);
             IF PalEqual(ActualColors,DefaultColors)
	      THEN BEGIN  {geladene Palette = Standardpalette?}
                    Palnamelang:='';
                    Palnamekurz:='';
                   END;
             RestoreScreen;

            END
       ELSE BEGIN {keine oder fehlerhafte *.PAL-Datei}
             FehlerMeldung('Couldn''t read *.PAL-file!');
             Palnamelang:=''; Palnamekurz:='';
             setgraphmode(DisplayMode);
             RestoreScreen;
            END;
END;

FUNCTION SelectZielPalette:BOOLEAN;
{ in: -}
{out: Palnamelang = gewÑhlter Dateiname mit Pfadangabe}
{     Palnamekurz = dto., nur Name+Extension}
{     ZielPalette  = geladene Palette}
{     TRUE|FALSE, falls Palette geladen|nicht geladen wurde}
{rem: Ist die geladene Palette gleich der Standardpalette, so werden}
{     Palname* auf '' gesetzt}
VAR s,name:String;
    Pfad:TPath;
    Dirname : DirStr;
    Filename: NameStr;
    Extname : ExtStr;
    fehler:Boolean;
    neuPal:BigPalette;
    i:WORD;

        PROCEDURE FehlerMeldung(s:String);
        VAR ch:char;
        BEGIN
         WRITELN(#7);
         WRITE(s+' <any key>');
         ch:=readkey;
         while keypressed do ch:=readkey
        END;

BEGIN
 RestoreCRTMode;
 ClrScr;

 GotoXY(20,1);
 WRITE('Select the destination palette to map to with the cursor');
 GotoXY(20,2);
 WRITE('keys, PageUP/PageDOWN, HOME/END and CR; <ESC> to cancel:');
 GetDir(0,Pfad);
 name:=ChooseSingleFile(20,4,20,Pfad,'*.PAL',fehler);
 IF name<>'' THEN ChangeDir(name);
 IF fehler THEN
  BEGIN
   SelectZielPalette:=FALSE;
   setgraphmode(DisplayMode);
   RestoreScreen;
   write(#7);
   OkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,'ok',
         '*** I/O-error! ***',
         'Couldn''t open file/device',name,Abfrage);
  END
 ELSE IF name=''
  THEN BEGIN {nichts ausgewÑhlt (ESC gedrÅckt)}
        SelectZielPalette:=FALSE;
        setgraphmode(DisplayMode);
        RestoreScreen;
       END
 ELSE IF LoadPalette(name,0,neuPal)<>0  {ok, Daten einlesen und prÅfen}
       THEN BEGIN
             SelectZielPalette:=TRUE;
             Palnamelang:=name;
             FSplit(Palnamelang, Dirname, Filename, Extname);
             Palnamekurz:=Filename+Extname;
             ZielPalette:=neuPal;

             IF PalEqual(ActualColors,DefaultColors)
	      THEN BEGIN  {geladene Palette = Standardpalette?}
                    Palnamelang:='';
                    Palnamekurz:='';
                   END;

             setgraphmode(DisplayMode);
             RestoreScreen;
            END
       ELSE BEGIN {keine oder fehlerhafte *.PAL-Datei}
             SelectZielPalette:=FALSE;
             FehlerMeldung('Couldn''t read *.PAL-file!');
             Palnamelang:=''; Palnamekurz:='';
             setgraphmode(DisplayMode);
             RestoreScreen;
            END;
END;

PROCEDURE ladeHintergrund;
{ in: -}
{out: Filenamelang = gewÑhlter Dateiname mit Pfadangabe}
{     Filenamekurz = dto., nur Name+Extension}
{     WorkArea = Bitmaps der geladenen Datei  }
{     WorkAreaMaxUsedX|Y = max. benutzte Koordinaten}
VAR s,name:String;
    Pfad:TPath;
    Dirname : DirStr;
    Filename: NameStr;
    Extname : ExtStr;
    fehler:Boolean;
    GrafikBild:Pointer;
    Size,i,t,x,y:Word;
    picture:Bild;

  FUNCTION LoadPage(name:STRING):BOOLEAN;
  { in: name = Filename fuer das zu ladende Bild}
  {out: pic  = Bitmaps des Bildes }
  {     TRUE/FALSE fÅr Bild konnte geladen/nicht geladen werden}
  CONST PICHeader:STRING[3]='PIC'; {Kennung in Bilderdateien}
  VAR f:FileOfByte;
      i:BYTE;
      fehler:BOOLEAN;
      s:STRING[3];
      x,y:WORD;

    PROCEDURE FehlerMeldung(s:String);
    VAR ch:char;
    BEGIN
     WRITELN(#7);
     WRITE(s+' <any key>');
     ch:=readkey;
     while keypressed do ch:=readkey
    END;

  BEGIN
   {$I-}
   _Assign(f,name);
   fehler:=(IOResult<>0) OR (CompressError<>CompressErr_NoError);
   _Reset(f);
   fehler:=(IOResult<>0) OR fehler OR (CompressError<>CompressErr_NoError);
   s[0]:=PICHeader[0];
   _BlockRead(f,s[1],Length(PICHeader));
   fehler:=(IOResult<>0) OR fehler OR (CompressError<>CompressErr_NoError);
   {$I+}
   IF fehler
    THEN BEGIN
          {$I-} _Close(f); {$I+}
          Error:=ErrFileIO;
          FehlerMeldung(GetErrorMessage);
          LoadPage:=FALSE;
          exit
         END
    ELSE IF (_FileSize(f)<>4*PAGESIZE+Length(PICHeader)) OR (s<>PICHeader)
    THEN BEGIN
          {$I-} _Close(f); {$I+}
          Error:=ErrNoPicture;
          FehlerMeldung(GetErrorMessage);
          LoadPage:=FALSE;
          exit
         END;
   FOR i:=0 TO 3 DO
    BEGIN
     {$I-}
     _BlockRead(f,picture[i]^,PAGESIZE);
     {$I+}
     fehler:=(IOResult<>0) OR fehler OR (CompressError<>CompressErr_NoError)
    END;
   {$I-}
   _Close(f);
   {$I+}
   fehler:=(IOResult<>0) OR fehler OR (CompressError<>CompressErr_NoError);
   IF fehler THEN Error:=ErrFileIO;
   IF fehler THEN FehlerMeldung(GetErrorMessage);

   LoadPage:=Error=ErrNone
  END;

BEGIN
 RestoreCRTMode;
 ClrScr;

 GotoXY(20,1);
 WRITE('Select your *.PIC-file to load with the cursor keys,');
 GotoXY(20,2);
 WRITE('PageUP/PageDOWN, HOME/END and CR; <ESC> to cancel:');
 GetDir(0,Pfad);
 name:=ChooseSingleFile(20,4,20,Pfad,'*.PIC',fehler);
 IF name<>'' THEN ChangeDir(name);
 IF fehler THEN
  BEGIN
   setgraphmode(DisplayMode);
   RestoreScreen;
   write(#7);
   OkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,'ok',
         '*** I/O-error! ***',
         'Couldn''t open file/device',name,Abfrage);
  END
 ELSE IF name=''
  THEN BEGIN {nichts ausgewÑhlt (ESC gedrÅckt)}
        setgraphmode(DisplayMode);
        RestoreScreen;
       END
 ELSE BEGIN {Bild laden}
       FOR i:=0 TO 3 DO New(picture[i]);

       IF LoadPage(name)  {ok, Daten einlesen und prÅfen}
        THEN BEGIN
              Filenamelang:=name;
              FSplit(Filenamelang, Dirname, Filename, Extname);
              Filenamekurz:=Filename+Extname;
              {Bilddaten nach Array WorkArea decodieren:}
              FOR y:=0 TO YMAX DO
               FOR x:=0 TO XMAX SHR 2 DO
		BEGIN
                 t:=y*LINESIZE;
                 WorkArea^.feld[y,x shl 2+0]:=picture[0]^[t+x];
                 WorkArea^.feld[y,x shl 2+1]:=picture[1]^[t+x];
                 WorkArea^.feld[y,x shl 2+2]:=picture[2]^[t+x];
                 WorkArea^.feld[y,x shl 2+3]:=picture[3]^[t+x]
                END;

              FindWorkAreaMaxUsed;
              setgraphmode(DisplayMode);
              RestoreScreen;
             END
        ELSE BEGIN {keine oder fehlerhafte *.COD-Datei}
              Filenamelang:=''; Filenamekurz:='';
              setgraphmode(DisplayMode);
              RestoreScreen;
             END;
        FOR i:=0 TO 3 DO Dispose(picture[i]);
       END;
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


PROCEDURE speichereSprite;
{ in: Filenamelang = Defaultwert fÅr Spritenamen}
{     Workarea^ = abzuspeichernde Daten}
{     WorkAreaMaxUsedX|Y = max. benutzte Extremkoordinaten}
{     ActualColors = gerade gesetzte Farben}
{     DefaultColors = Standardfarben des BIOS-256-Farbenmodus}
{out: Auf Disk wurde der Inhalt der Workarea als Sprite abgelegt }
{     Filename* = neue Filenamen}
{rem: Falls die Workarea leer war oder <ESC> gedrÅckt wurde, dann}
{     wurde keine Datei angelegt}
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

    PROCEDURE schreibe_Daten;
    { in: Filenamelang = Name der zu schreibenden Datei}
    {     oldName* = alte Dateinamen}
    {out: Falls Sprite nicht erstellt werden konnte, wurden die alten}
    {     Dateinamen fÅr Filename* wieder eingesetzt!}
    {rem: Der Inhalt der Workarea wird in die Datei Filenamelang }
    {     geschrieben; der Dateiname wurde bereits auf Erîffenbar-}
    {     keit geprÅft, ebenso, da· die Workarea nicht leer ist!  }
    LABEL quit;
    VAR f:FileOfByte;
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
    BEGIN
     SetColor(BestWhite); s:='just a moment...';
     pplen:=ImageSize(MeldungX+50,MeldungY,
                      MeldungX+50+length(s) SHL 3,MeldungY+9);
     GetMem(pp,pplen);
     GetImage(MeldungX+50,MeldungY,
              MeldungX+50+length(s) SHL 3,MeldungY+9,pp^);
     OutTextXY(MeldungX+50,MeldungY,s);

     New(Sprite);
     WITH Sprite^ DO
      BEGIN
       Translate[1]:=1; Translate[2]:=2; Translate[3]:=4; Translate[4]:=8;
       Kennung[1]:='K'; Kennung[2]:='R';
       Version:=1;
       Modus:=0;
       FOR i:=1 TO 10 DO dummy[i]:=0; {Dummywerte auf 0 setzen}
       Hoehe_in_Zeilen:=Succ(WorkAreaMaxUsedY);   {Y-Werte reichen von 0..MaxY}
       Breite_in_4er_Gruppen:=Succ(WorkAreaMaxUsedX shr 2); {0..3->1, 4..7->2, ...}
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
       FOR j:=0 TO WorkAreaMaxUsedY DO
         FOR i:=0 TO Pred(Breite_in_4er_Gruppen) DO
          BEGIN
           FOR p:=0 TO 3 DO
             Readin[Zeiger_auf_Plane[p]+offset]:=
              Workarea^.feld[j,(i shl 2)+p];
           inc(offset);
          END;

       {Nun die X-Grenzdaten fÅr jede Zeile:}
       offset:=0;
       FOR j:=0 TO WorkAreaMaxUsedY DO
        BEGIN
         links:=0;
         rechts:=WorkAreaMaxUsedX; (* Pred(Breite_in_4er_Gruppen shl 2); *)
         fertig_li:=false; fertig_re:=false;
         REPEAT
          if (not fertig_li and (WorkArea^.feld[j,links]=0))
           THEN inc(links) ELSE fertig_li:=true;
          if (not fertig_re and (WorkArea^.feld[j,rechts]=0))
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
         unten:=WorkAreaMaxUsedY;
         fertig_ob:=false; fertig_un:=false;
         REPEAT
          if (not fertig_ob and (Workarea^.feld[oben,i]=0))
           THEN inc(oben) ELSE fertig_ob:=true;
          if (not fertig_un and (Workarea^.feld[unten,i]=0))
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
     _assign(f,Filenamelang);
     _rewrite(f);
     _blockwrite(f,sprite^.readin,Gesamtgroesse);
     _close(f);
quit:;
     Dispose(Sprite);
     PutImage(MeldungX+50,MeldungY,pp^,NormalPut);
     Dispose(pp);
     ShowFilename;
    END;

BEGIN
 IF (WorkAreaMaxUsedX=0) AND (WorkAreaMaxUsedY=0) AND
    (Workarea^.feld[0,0]=transparent)
  THEN BEGIN {Workarea leer!}
        ErrBeep;
        exit
       END;

 {evtl. alten Filenamen aufheben}
 oldNamelang:=Filenamelang; oldNamekurz:=Filenamekurz;

 RestoreCRTMode;
 ClrScr;

 GotoXY(x1,y1-2);
 WRITE('Please give a name (*.COD) for your sprite file; <ESC> to cancel');
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
   THEN BEGIN {dafÅr sorgen, da· evtl. Extension '.COD' lautet}
         FSplit(Filenamelang,D,N,E);
         temp:=D+N+'.COD'
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

         if not gueltig(temp,'.COD')
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

 setgraphmode(DisplayMode);
 RestoreScreen;

 IF not abbruch
  THEN BEGIN
        schreibe_Daten;  {Eigentliche Daten berechnen & schreiben}
        IF NOT PalEqual(ActualColors,DefaultColors)
         THEN OkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,'ok',
                    'The active palette differs',
                    'from the standard palette;',
                    'don''t forget to save it!'
                    ,Abfrage);
       END;
END;

PROCEDURE speicherePalette;
{ in: Palnamelang = Defaultwert fÅr Palettedaten}
{out: Auf Disk wurde der Inhalt der gerade aktuellen Palette "ActualColors"}
{     abgelegt }
{     Palname* = neue Palettennamen}
{rem: Falls <ESC> gedrÅckt wurde, dann wurde keine Datei angelegt}
CONST x1=4; y1=4; inlen=67; {Koordinaten fÅr Eingabebox}
VAR temp:InputString;
    abbruch:Boolean;
    size:word;
    attr:Byte;
    i:Integer;
    ch:Char;
    oldPalNamelang,oldPalNamekurz,
    P: PathStr;
    D: DirStr;
    N: NameStr;
    E: ExtStr;

BEGIN
 {evtl. alten Filenamen aufheben}
 oldPalNamelang:=Palnamelang; oldPalNamekurz:=Palnamekurz;

 RestoreCRTMode;
 ClrScr;

 GotoXY(x1,y1-2);
 WRITE('Please give a name (*.PAL) for your palette file; <ESC> to cancel');
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

  {Defaultwert fÅr Namen aus Palnamelang bestimmen:}
  IF PalNamelang<>''
   THEN BEGIN {dafÅr sorgen, da· evtl. Extension '.PAL' lautet}
         FSplit(PalNamelang,D,N,E);
         temp:=D+N+'.PAL'
        END
   ELSE temp:='';

  abbruch:=false;         {hei·t: behalte die letzten 30 gemachten Eingaben}
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

         if not gueltig(temp,'.PAL')
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
          ELSE BEGIN {gÅltiger Name, in PalName_* Åbernehmen}
                P:=temp;
                FSplit(P,D,N,E);
                PalNamelang:=P;
                PalNamekurz:=N+E;
               END;
        END;

 setgraphmode(DisplayMode);
 RestoreScreen;

 IF not abbruch
  THEN SavePalette(PalNamelang,ActualColors); {Eigentliche Daten schreiben}
END;


PROCEDURE speichereHintergrund;
{ in: Filenamelang = Defaultwert fÅr Hintergrunddaten}
{     Workarea^ = abzuspeichernde Daten}
{     WorkAreaMaxUsedX|Y = max. benutzte Extremkoordinaten}
{     ActualColors = gerade gesetzte Farben}
{     DefaultColors = Standardfarben des BIOS-256-Farbenmodus}
{out: Auf Disk wurde der Inhalt der Workarea als Bild abgelegt }
{     Filename* = neue Filenamen}
{rem: Falls die Workarea leer war oder <ESC> gedrÅckt wurde, dann}
{     wurde keine Datei angelegt}
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

    PROCEDURE SavePage;
    { in: Filenamelang = Name der zu schreibenden Datei}
    {     oldName* = alte Dateinamen}
    {     Workarea^.[] = zu schreibende Daten}
    {out: Falls Sprite nicht erstellt werden konnte, wurden die alten}
    {     Dateinamen fÅr Filename* wieder eingesetzt!}
    {rem: Der Inhalt der Workarea wird in die Datei Filenamelang }
    {     geschrieben; der Dateiname wurde bereits auf Erîffenbar-}
    {     keit geprÅft, ebenso, da· die Workarea nicht leer ist!  }
    CONST PICHeader:STRING[3]='PIC'; {Kennung in Bilderdateien}
    VAR f:FileOfByte;
        s:String[20];
        i:BYTE;
        t,x,y:WORD;
        picture:Bild;
        pp:POINTER;
        pplen:WORD;
    BEGIN
     SetColor(BestWhite); s:='just a moment...';
     pplen:=ImageSize(MeldungX+50,MeldungY,
                      MeldungX+50+length(s) SHL 3,MeldungY+9);
     GetMem(pp,pplen);
     GetImage(MeldungX+50,MeldungY,
              MeldungX+50+length(s) SHL 3,MeldungY+9,pp^);
     OutTextXY(MeldungX+50,MeldungY,s);

     _Assign(f,Filenamelang);
     _Rewrite(f);
     _BlockWrite(f,PICHeader[1],Length(PICHeader));

     {Bilddaten zusammenstellen:}
     FOR i:=0 TO 3 DO New(picture[i]);
     FOR y:=0 TO YMAX DO
      FOR x:=0 TO XMAX SHR 2 DO
       BEGIN
        t:=y*LINESIZE;
        picture[0]^[t+x]:=Workarea^.feld[y,x shl 2 +0];
        picture[1]^[t+x]:=Workarea^.feld[y,x shl 2 +1];
        picture[2]^[t+x]:=Workarea^.feld[y,x shl 2 +2];
        picture[3]^[t+x]:=Workarea^.feld[y,x shl 2 +3];
       END;
     FOR i:=0 TO 3 DO _BlockWrite(f,picture[i]^,PAGESIZE);
     _Close(f);

     FOR i:=0 TO 3 DO Dispose(picture[i]);
     PutImage(MeldungX+50,MeldungY,pp^,NormalPut);
     Dispose(pp);
     ShowFilename;
    END;

BEGIN
 IF (WorkAreaMaxUsedX=0) AND (WorkAreaMaxUsedY=0) AND
    (Workarea^.feld[0,0]=transparent)
  THEN BEGIN {Workarea leer!}
        ErrBeep;
        exit
       END;

 {evtl. alten Filenamen aufheben}
 oldNamelang:=Filenamelang; oldNamekurz:=Filenamekurz;

 RestoreCRTMode;
 ClrScr;

 GotoXY(x1,y1-2);
 WRITE('Please give a name (*.PIC) for your picture file; <ESC> to cancel');
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
   THEN BEGIN {dafÅr sorgen, da· evtl. Extension '.PIC' lautet}
         FSplit(Filenamelang,D,N,E);
         temp:=D+N+'.PIC'
        END
   ELSE temp:='';

  abbruch:=false;         {hei·t: behalte die letzten 30 gemachten Eingaben}
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

         if not gueltig(temp,'.PIC')
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

 setgraphmode(DisplayMode);
 RestoreScreen;

 IF not abbruch
  THEN BEGIN
        SavePage;  {Eigentliche Daten berechnen & schreiben}
        IF NOT PalEqual(ActualColors,DefaultColors)
         THEN OkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,'ok',
                    'The active palette differs',
                    'from the standard palette;',
                    'don''t forget to save it!'
                    ,Abfrage);
       END;
END;

PROCEDURE ResetColors;
{ in: DefaultColors = zu setzende Standardpalette}
{out: ActualColors = Standardfarben}
{     Palname* = ''}
BEGIN
 ActualColors:=DefaultColors;
 Palnamelang:=''; Palnamekurz:=''; {geladene Palette invalidieren}
 RestoreScreen; {neue Farben sichtbar machen, Menufarben & -namen anpassen}
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
 DisplayMode:=VID640x400x256; {Defaultmodus}
 IF ParamCount=1  {...kann durch /480 Åberschrieben werden}
  THEN IF ParamStr(1)='/480'
        THEN DisplayMode:=VID640x480x256;

 init640x4_0x256;

 WITH oldMouse DO
  BEGIN
   MouseMemSize:=ImageSize(0,0,CursorMaxX,CursorMaxY);
   GetMem(MouseMem,MouseMemSize);
  END;
 Event:=EventNone;

 New(WorkArea);
 FillChar(WorkArea^,SizeOf(WorkArea^),transparent);
 Filenamelang:=''; Filenamekurz:='';
 Palnamelang:='';  Palnamekurz:='';
 FarbenStartX:=5;
 FarbenHoehegesamt:=20;
 FarbenStartY:=getmaxy-FarbenHoehegesamt-1;
 Koordmeldx:=FarbenStartX+265;
 Koordmeldy:=FarbenStartY-1;
 FilenameStartX:=(WorkEndX-WorkStartX-12*8) div 2+WorkStartX;
 FilenameStartY:=WorkStartY-10;
 PalnameStartX:=(25+15*PalBreite-12*8) div 2 +PaletteX;
 PalnameStartY:=PaletteY-10;
 RestoreScreen;
END;

PROCEDURE Help;
VAR ch:CHAR;
BEGIN
 RestoreCRTMode;
 TextColor(White); TextBackGround(Blue);
 ClrScr;

 WRITELN('Help');
 WRITELN('ƒƒƒƒ');
 WRITELN('Besides the functions indicated by the function keys at the'+
         ' lower screen boun-');
 WRITELN('dary, you have the following options:');
 WRITELN;
 WRITELN(' "+", "-" = zoom in/out the workarea');
 WRITELN(' Shift-F3 = load sprite without erasing the workarea previously');
 WRITELN(' Shift-F5 = reset palette to default color palette');
 WRITELN(' Shift-F7 = load picture without erasing the workarea previously');
 WRITELN(' Shift-F9 = remap object''s colors to default color palette');
 WRITELN;
 WRITELN(' Use the cursor keys to scroll the graphic contents around'+
         ' (if it doesn''t fit');
 WRITELN(' on the screen because of zooming); use SHIFT in addition to'+
         ' scroll pixelwise.');
 WRITELN(' Similar, pressing SHIFT while clicking at one of the rotate'+
         ' buttons will');
 WRITELN(' rotate the screen by one pixel only.');
 WRITELN;
 WRITELN(' Hold down SHIFT while clicking in the workarea for aligned'+
         ' objects (circles');
 WRITELN(' instead of ellipses, etc.).');
 WRITELN;
 WRITELN(' Clicking at the "move to origin" button with Shift will scroll'+
         ' the workarea to');
 WRITELN(' point (0,0) instead');

 GotoXY(1,25); TextColor(Yellow);
 WRITE('[press any key]');
 WHILE KeyPressed DO ch:=ReadKey;
 ch:=ReadKey;
 WHILE KeyPressed DO ch:=ReadKey;

 TextColor(White); TextBackGround(Black);
 setgraphmode(DisplayMode);
 RestoreScreen;
END;

PROCEDURE MapPalette;
{ in: ZielPalette   = Zielfarben, auf die gemappt werden soll   }
{     ActualColors  = aktuelle Farben, die gemappt werden sollen}
{     WorkArea      = umzumappende Daten}
{out: WorkArea      = neue Grafikdaten, auf DefaultColors approximiert }
{     WorkAreaMaxUsedX|Y = evtl. neue Extremkoordinaten}
{rem: Die Farben wurden mit einer "Minimum-square-error"-Routine so gut}
{     wie mîglich auf die Farben "ZielPalette" abgebildet, wodurch sich}
{     die Daten natÅrlich Ñndern!}
{     Grafikmodus mu· gesetzt sein!}
{     Routine sollte nur aufgerufen werden, wenn Workarea nicht leer ist!}
VAR LookUp:ARRAY[0..255] OF BYTE;

  FUNCTION MapToDefaultColors(Color:BYTE):BYTE; ASSEMBLER;
  { in: Color = Farbnummer des 256 Farbmodus, die approximiert werden soll}
  {     ActualColors = gerade gesetzte 256 Farben}
  {     DefaultColors= Tabelle der Defaultfarben der 16 (256) Farbmodi}
  {out: Defaultfarbe des 256 Farbmodus, die am ehesten der uebergebenen   }
  {     Farbe entspricht}
  ASM
    MOV BL,Color
    XOR BH,BH
    MOV SI,BX
    SHL SI,1
    ADD SI,BX
    ADD SI,OFFSET ActualColors
    MOV BX,[SI]
    MOV DH,[SI+2]    {BL/BH/DH = aktuelle Farbe, RGB}

    PUSH BP
    MOV DI,65535     {DI=bisher gefundenes minimales Fehlerquadrat}
    MOV CX,255
    MOV SI,OFFSET ZielPalette    {DS:SI = Zeiger auf DefaultColors}

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

BEGIN
 IF PalEqual(ZielPalette,ActualColors)
  THEN BEGIN {aktuelle Farben = Zielfarben, also kein Mapping nîtig}
        ErrBeep;
        exit
       END
  ELSE BEGIN
        {Farbumsetztabelle bestimmen:}
        FOR i:=0 TO 255 DO LookUp[i]:=MapToDefaultColors(i);
        {Grafikdaten umsetzen:}
        FOR y:=0 TO YMAX DO
         FOR x:=0 TO XMAX DO
          WorkArea^.feld[y,x]:=LookUp[WorkArea^.feld[y,x]];
        {énderungen anzeigen: Zielfarben setzen und Grafik zeigen}
        ActualColors:=ZielPalette;
        IF PalEqual(ActualColors,DefaultColors)
	 THEN BEGIN {Bei Defaultfarbenpalette dies auch melden}
               Palnamekurz:='';
               Palnamelang:=''
              END;

        FindWorkAreaMaxUsed; {evtl. haben sich die Extremkoord. geÑndert}
        RestoreScreen; {neue Farben sichtbar machen, Menufarben & -namen anpassen}
       END;
END;

PROCEDURE MapToBIOSPalette;
{ in: ZielPalette   = Zielfarben, auf die gemappt werden soll   }
{     ActualColors  = aktuelle Farben, die gemappt werden sollen}
{     WorkArea      = umzumappende Daten}
{out: WorkArea      = neue Grafikdaten, auf DefaultColors approximiert }
{     WorkAreaMaxUSedX|Y = evtl. neue Extremkoordinaten}
{rem: Die Farben wurden mit einer "Minimum-square-error"-Routine so gut}
{     wie mîglich auf die Defaultfarben "DefaultColors" abgebildet, wo-}
{     durch sich die Daten natÅrlich Ñndern!}
{     Grafikmodus mu· gesetzt sein!}
BEGIN
 ZielPalette:=DefaultColors;
 MapPalette
END;


PROCEDURE SelectColor;
{ in: MausX,MausY = aktuelle Mauskoordinaten, irgendwo im Palettenbereich}
{out: aktuelleFarbe=gewÑhlte Farbe, falls gÅltige Farbe angeclickt wurde }
{rem: aktuelle Farbe wird zugleich im dafÅr reservierten Feld angezeigt  }
VAR i,j:BYTE;
BEGIN
 i:=(MausX-PaletteX-25) DIV PalBreite;
 IF i<>(MausX-PaletteX-25+3) DIV PalBreite
  THEN exit; {knapp daneben ist auch vorbei: zwischen 2 Farben geclickt!}
 j:=(MausY-PaletteY-10) DIV PalHoehe;
 IF j<>(MausY-PaletteY-10+3) DIV PalHoehe
  THEN exit; {dto.}

 aktuelleFarbe:=j SHL 4 + i; {=j*16+i}
 ShowActualColor
END;


PROCEDURE ScrollLeft(amount:INTEGER);
BEGIN
 IF StartVirtualX>0
  THEN BEGIN
        StartVirtualX:=max(0,StartVirtualX-amount);
        {nur Workarea updaten - geht schneller als "RestoreScreen()"!}
        UpdateWorkArea(StartVirtualX,StartVirtualY,
                       WorkAreaMaxUsedX,WorkAreaMaxUsedY,TRUE);
        DrawNewObject; {evtl. Objekt neuzeichnen}
        ShowOffset;
       END
  ELSE ErrBeep
END;

PROCEDURE ScrollRight(amount:INTEGER);
BEGIN
 IF StartVirtualX<XMAX
  THEN BEGIN
        StartVirtualX:=min(XMAX,StartVirtualX+amount);
        {nur Workarea updaten - geht schneller als "RestoreScreen()"!}
        UpdateWorkArea(StartVirtualX,StartVirtualY,
                       WorkAreaMaxUsedX,WorkAreaMaxUsedY,TRUE);
        DrawNewObject; {evtl. Objekt neuzeichnen}
        ShowOffset;
       END
  ELSE ErrBeep
END;

PROCEDURE ScrollUp(amount:INTEGER);
BEGIN
 IF StartVirtualY>0
  THEN BEGIN
        StartVirtualY:=max(0,StartVirtualY-amount);
        {nur Workarea updaten - geht schneller als "RestoreScreen()"!}
        UpdateWorkArea(StartVirtualX,StartVirtualY,
                       WorkAreaMaxUsedX,WorkAreaMaxUsedY,TRUE);
        DrawNewObject; {evtl. Objekt neuzeichnen}
        ShowOffset;
       END
  ELSE ErrBeep
END;

PROCEDURE ScrollDown(amount:INTEGER);
BEGIN
 IF StartVirtualY<YMAX
  THEN BEGIN
        StartVirtualY:=min(YMAX,StartVirtualY+amount);
        {nur Workarea updaten - geht schneller als "RestoreScreen()"!}
        UpdateWorkArea(StartVirtualX,StartVirtualY,
                       WorkAreaMaxUsedX,WorkAreaMaxUsedY,TRUE);
        DrawNewObject; {evtl. Objekt neuzeichnen}
        ShowOffset;
       END
  ELSE ErrBeep
END;

PROCEDURE GotoUpLeft;
{ in: StartVirtualX|Y = momentaner sichtbarer Beginn der Workarea}
{     WorkAreaMaxUsedX|Y = max. benutzte Koordinaten}
{out: StartVirtualX|Y = 0}
{rem: sichtbarer Workarea-Ausschnitt wurde zurÅckgesetzt auf 0,0 }
BEGIN
 IF (StartVirtualX<>0) OR (StartVirtualY<>0)
  THEN BEGIN
        StartVirtualX:=0;
        StartVirtualY:=0;
        {nur Workarea updaten - geht schneller als "RestoreScreen()"!}
        UpdateWorkArea(StartVirtualX,StartVirtualY,
                       WorkAreaMaxUsedX,WorkAreaMaxUsedY,TRUE);
        DrawNewObject; {evtl. Objekt neuzeichnen}
        ShowOffset;
       END
END;

PROCEDURE WorkAreaAction;
{ in: Maus befindet sich in WorkArea}
{     MausX|Y = aktuelle Mauskoordinaten (bereits bzgl. Zooming justiert)}
{     LeftButton, RightButton = MausbuttonzustÑnde}
{     Objekt  = aktuelles Zeichenobjekt }
{     aktuelleFarbe = aktuelle Zeichenfarbe}
{     aktuellesTool = aktuelles Tool }
{     Workarea = aktuelle Grafikdaten}
{out: Workarea = evtl. verÑnderte Grafikdaten}
{     Objekt = evtl. verÑnderte Grafikdaten}
{rem: Maus ist noch abgeschaltet!}
VAR dx,dy,diff:INTEGER;
BEGIN
 WITH Objekt DO
  BEGIN
   IF (stage<>0) AND (RightButton)
    THEN BEGIN {Abbruch der begonnenen Aktion}
          ClearOldObject;
          stage:=0; {damit existiert kein Objekt mehr}
          exit
         END;

   IF (stage=0) AND (aktuellesTool=Punkt) AND
      ( LeftButton OR LeftButtonStillPressed )
    THEN BEGIN {einfachster Fall: einfach einen Punkt setzen}
          Absolute2WorkArea(StartX,StartY); {aktuelle relative Koord. holen}

          (* Die folgenden Zeilen wÑren ein schnellerer (aber konzeptionell  *)
          (* unschîner) Ersatz fÅr die Zeilen ab "Typ:=..." bis "StoreObject"*)
          (* (jeweils einschlie·lich). Dies wÑre deshalb mîglich, weil einen *)
          (* Punkt zu setzen eine "unteilbare" Aktion darstellt, die nicht   *)
          (* Åber mehrere Hauptprogrammzyklen verschliffen ist! *)
          (*
          Workarea^.feld[StartY,StartX]:=aktuelleFarbe; {Punkt setzen}
          IF aktuelleFarbe<>transparent
	   THEN BEGIN {benutzte Workarea-FlÑche grî·er geworden?}
                 WorkAreaMaxUsedX:=max(StartX,WorkAreaMaxUsedX);
                 WorkAreaMaxUsedY:=max(StartY,WorkAreaMaxUsedY);
                END
           ELSE FindWorkAreaMaxUsed;
          {nur diesen einen (logischen) Punkt auf dem Schirm neuzeichnen:}
          UpdateWorkArea(StartX,StartY,StartX,StartY,FALSE);
          *)
          Stage:=1;
          Typ  :=aktuellesTool; {=Punkt}
          DrawNewObject;
          StoreObject;
          exit
         END;

   IF (stage<>0) AND (NOT LeftButton)
    THEN BEGIN {temporÑres Objekt zeichnen}
          CASE Typ OF
           {Punkt:DrawNewObject}
	   Linie:BEGIN
                  ClearOldObject;
                  Absolute2WorkArea(LastX,LastY); {wo steht der Mauscursor?}
                  IF aligned
		   THEN BEGIN {nur horiz., vert. oder diagonale Zeilen!}
                         dx:=abs(LastX-StartX); dy:=abs(LastY-StartY);
                         {Anhand der Steigung entscheiden, was fÅr eine}
                         {Ausrichtung erfolgen soll: 0..0.5=horizontal,}
                         {0.5..2 = diagonal, 2..?? = vertikal}
                         IF dx>2*dy THEN LastY:=StartY      {horizontal}
                         ELSE IF dy>2*dx THEN LastX:=StartX {vertikal}
			 ELSE BEGIN
                               {Diagonale, dafÅr wird aber auch das Vorzeichen}
                               {der Steigung benîtigt!}
                               diff:=min(dx,dy);
                               LastX:=StartX+sign(LastX-StartX)*diff;
                               LastY:=StartY+sign(LastY-StartY)*diff
                              END;
                        END;
                  DrawNewObject;
                 END;
           Rechteck:BEGIN  {Quadrate auch!}
                     ClearOldObject;
                     Absolute2WorkArea(LastX,LastY);
                     IF aligned
                      THEN BEGIN {Quadrat!}
                            dx:=abs(LastX-StartX); dy:=abs(LastY-StartY);
                            diff:=min(dx,dy);
                            LastX:=StartX+sign(LastX-StartX)*diff;
                            LastY:=StartY+sign(LastY-StartY)*diff;
                           END;
                     DrawNewObject;
                    END;
           Ellipse_:BEGIN
                     ClearOldObject;
                     Absolute2WorkArea(LastX,LastY);
                     DrawNewObject;
                    END;
           FRechteck:BEGIN  {gefÅllte Quadrate auch!}
                      ClearOldObject;
                      Absolute2WorkArea(LastX,LastY);
                      IF aligned
                       THEN BEGIN {Quadrat!}
                             dx:=abs(LastX-StartX); dy:=abs(LastY-StartY);
                             diff:=min(dx,dy);
                             LastX:=StartX+sign(LastX-StartX)*diff;
                             LastY:=StartY+sign(LastY-StartY)*diff;
                            END;
                      DrawNewObject;
                     END;
           FEllipse:BEGIN
                     ClearOldObject;
                     Absolute2WorkArea(LastX,LastY);
                     DrawNewObject;
                    END;
	   FuellEimer:BEGIN
                       ClearOldObject;
                       Absolute2WorkArea(LastX,LastY);
                       DrawNewObject;
                      END;
	   Kopie:BEGIN
                  ClearOldObject;
                  IF stage=1
                   THEN Absolute2WorkArea(LastX,LastY)
                   ELSE Absolute2WorkArea(actX,actY);  {stage=2!}
                  DrawNewObject
                 END;
           else ErrBeep;
          END; {of CASE}
         END;

   {------- neues Objekt beginnen? -------}

   IF LeftButton
    THEN BEGIN {Zustandswechsel des Objekts!}
          IF stage=0 THEN
           BEGIN {neues Objekt beginnen}
            stage:=1; {=begonnen, aber noch nicht fertig}
            Absolute2Workarea(StartX,StartY); {Startpunkt merken}
            LastX:=StartX; LastY:=StartY;     {Endpunkt = Startpunkt}
            Typ:=aktuellesTool;
            IF Shift THEN aligned:=TRUE ELSE aligned:=FALSE;

            {Sonderbehandlung FÅlleimer: schon beim ersten Anclicken aktiv!}
            IF Typ=FuellEimer THEN DrawWorkAreaFill(LastX,LastY,aktuelleFarbe,DRAW);

           END
          ELSE IF stage=1 THEN
	   BEGIN {begonnenes Objekt abschlie·en?}
            CASE Typ OF
	     Linie,
             Rechteck,
             Ellipse_,
             FRechteck,
             FEllipse,
             FuellEimer: StoreObject;
             Kopie: BEGIN
                     ClearOldObject;
                     stage:=2;
                    END;
            END;
           END
          ELSE {IF stage=2 THEN}
	   BEGIN {dto.}
            IF Typ=Kopie THEN StoreObject
           END;
         END;
  END; {of WITH}
END;

PROCEDURE Zoomin;
{ in: zoom = momentaner Vergrî·erungsfaktor}
{out: zoom = neuer Vergrî·erungsfaktor     }
{rem: Bildschirminhalt wurde vergrî·ert    }
CONST MaxZoom=30;
BEGIN
 IF zoom<MaxZoom
  THEN BEGIN
        inc(zoom);
        {nur Workarea updaten - geht schneller als "RestoreScreen()"!}
        UpdateWorkArea(StartVirtualX,StartVirtualY,
                       WorkAreaMaxUsedX,WorkAreaMaxUsedY,TRUE);
        DrawNewObject; {evtl. Objekt wieder auf den Schirm bringen}
        ShowZoom;
       END
  ELSE ErrBeep
END;

PROCEDURE Zoomout;
{ in: zoom = momentaner Vergrî·erungsfaktor}
{out: zoom = neuer Vergrî·erungsfaktor     }
{rem: Bildschirminhalt wurde verkleinert   }
BEGIN
 IF zoom>1
  THEN BEGIN
        dec(zoom);
        {nur Workarea updaten - geht schneller als "RestoreScreen()"!}
        UpdateWorkArea(StartVirtualX,StartVirtualY,
                       WorkAreaMaxUsedX,WorkAreaMaxUsedY,TRUE);
        DrawNewObject; {evtl. Objekt wieder auf den Schirm bringen}
        ShowZoom;
       END
  ELSE ErrBeep
END;


PROCEDURE SelectNewTool;
{ in: Event=eines der EventTool* Events}
{out: aktuellesTool = neues, selektiertes Tool}
BEGIN
 CASE Event OF
  EventToolPixel:BEGIN
                  IF aktuellesTool=Punkt THEN exit; {nix zu tun!}
                  ClearOldObject;  {evtl. altes Objekt lîschen}
                  Objekt.stage:=0; {intern natÅrlich auch}
                  aktuellesTool:=Punkt;
                  ShowActualTool;  {neues Tool anzeigen}
                 END;
  EventToolLine :BEGIN
                  IF aktuellesTool=Linie THEN exit;
                  ClearOldObject;
                  Objekt.stage:=0;
                  aktuellesTool:=Linie;
                  ShowActualTool;
                 END;
  EventToolRectangle:BEGIN
                      IF aktuellesTool=Rechteck THEN exit;
                      ClearOldObject;
                      Objekt.stage:=0;
                      aktuellesTool:=Rechteck;
                      ShowActualTool;
                     END;
  EventToolEllipse:BEGIN
                    IF aktuellesTool=Ellipse_ THEN exit;
                    ClearOldObject;
                    Objekt.stage:=0;
                    aktuellesTool:=Ellipse_;
                    ShowActualTool;
                   END;
  EventToolBar:BEGIN
                IF aktuellesTool=FRechteck THEN exit;
                ClearOldObject;
                Objekt.stage:=0;
                aktuellesTool:=FRechteck;
                ShowActualTool;
               END;
  EventToolDisc: BEGIN
                  IF aktuellesTool=FEllipse THEN exit;
                  ClearOldObject;
                  Objekt.stage:=0;
                  aktuellesTool:=FEllipse;
                  ShowActualTool;
                 END;
  EventToolFill: BEGIN
                  IF aktuellesTool=FuellEimer THEN exit;
                  ClearOldObject;
                  Objekt.stage:=0;
                  aktuellesTool:=FuellEimer;
                  ShowActualTool;
                 END;
  EventToolCopy: BEGIN
                  IF aktuellesTool=Kopie THEN exit;
                  ClearOldObject;
                  Objekt.stage:=0;
                  aktuellesTool:=Kopie;
                  ShowActualTool;
                 END;
  else ErrBeep;
 END;
END;

PROCEDURE ShowBorder(Shift:BOOLEAN);
{ in: Workarea = aktuelle Grafikdaten}
{     WorkAreaMaxUsedX|Y = aktuelle Extremkoordinaten}
{     Shift = TRUE fÅr: auch transparentes Spriteinneres blinken lassen}
{out: - }
{rem: Grenzdaten wurden blinkend angezeigt}
TYPE Punkt=Record
            x,y:Word;
           END;
CONST DontCare=0;
VAR punkte:Array[1..2*WorkBreite+2*WorkHoehe] OF Punkt;
    Zeilen_Grenze_links,Zeilen_Grenze_rechts:Array[0..WorkHoehe-1] OF INTEGER;
    p_zahl,Anzahl,i,j,k,links,rechts,oben,unten,MinX,MaxX,MinY,MaxY:Integer;
    fertig_li,fertig_re,fertig_ob,fertig_un:Boolean;
    farbe:Byte;
    s1,s2:STRING[5];

BEGIN
 IF (WorkAreaMaxUsedX=0) AND (WorkAreaMaxUsedY=0) AND
    (Workarea^.feld[0,0]=transparent)
  THEN BEGIN {leere Workarea, also nichts da zum anzeigen!}
        ErrBeep;  {Ist aber nur notwendiges Kriterium, nicht hinreichend!}
        exit      {(Da gesamtes Sprite ja offscreen sein kann!}
       END;
 p_zahl:=0; MaxX:=0; MaxY:=0; MinX:=MaxInt; MinY:=MaxInt;

 {Nun die X-Grenzdaten fÅr jede Zeile:}
 FOR j:=0 TO WorkAreaMaxUsedY DO
  BEGIN
   links:=0; rechts:=WorkAreaMaxUsedX;
   fertig_li:=false; fertig_re:=false;
   REPEAT
    if (not fertig_li and (Workarea^.feld[j,links]=transparent))
     THEN inc(links) ELSE fertig_li:=true;
    if (not fertig_re and (Workarea^.feld[j,rechts]=transparent))
     THEN dec(rechts) ELSE fertig_re:=true;
    if links>rechts THEN BEGIN fertig_li:=true; fertig_re:=true END;
   UNTIL fertig_li and fertig_re;
   Zeilen_Grenze_links[j] :=links;
   Zeilen_Grenze_rechts[j]:=rechts;
   if (links<=rechts)
    THEN BEGIN {normale Zeile, Grenzen eintragen}
          inc(p_zahl);
          punkte[p_zahl].x:=links;  punkte[p_zahl].y:=j;
          inc(p_zahl);
          punkte[p_zahl].x:=rechts; punkte[p_zahl].y:=j;
          IF links <MinX THEN MinX:=links;
          IF rechts>MaxX THEN MaxX:=rechts
         END;
  END;

 IF Shift
  THEN Anzahl:=p_zahl SHR 1;  {fÅr Transparentes reichen die Zeilendaten aus!}

 {Dasselbe fÅr die Grenzdaten jeder Spalte:}
 FOR i:=0 TO WorkAreaMaxusedX DO
  BEGIN
   oben :=0; unten:=WorkAreaMaxUsedY;
   fertig_ob:=false; fertig_un:=false;
   REPEAT
    if (not fertig_ob and (Workarea^.feld[oben,i]=transparent))
     THEN inc(oben) ELSE fertig_ob:=true;
    if (not fertig_un and (Workarea^.feld[unten,i]=transparent))
     THEN dec(unten) ELSE fertig_un:=true;
    if oben>unten THEN BEGIN fertig_ob:=true; fertig_un:=true END;
   UNTIL fertig_ob and fertig_un;
   if (oben<=unten)
    THEN BEGIN {normale Spalte, Grenzen eintragen}
          inc(p_zahl);
          punkte[p_zahl].x:=i;  punkte[p_zahl].y:=oben;
          inc(p_zahl);
          punkte[p_zahl].x:=i; punkte[p_zahl].y:=unten;
          IF oben <MinY THEN MinY:=oben;
          IF unten>MaxY THEN MaxY:=unten
         END;
  END;

 IF p_zahl=0
  THEN BEGIN
        ErrBeep;
        exit
       END

  ELSE BEGIN {Punkte blinken lassen}
        STR(WorkAreaMaxUsedX:3,s1);
        STR(WorkAreaMaxUsedY:3,s2);
        DrawOkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,'ok',
                  'used width : 0..'+s1,
                  'used height: 0..'+s2,'',Abfrage);
        DrawMaus(CursorPfeil);
        Event:=EventNone;
        {Maus freigeben:}
        ClearMouse;

        i:=0; farbe:=BestWhite;
        REPEAT
         i:=succ(i) mod 100;  {Jedes 100. Mal anzeigen reicht}
         delay(10);           {*10ms = Blinkfrequenz von 1Hz }
         if i=0 THEN BEGIN
                      UndrawMaus;
                      IF Shift
                       THEN FOR j:=1 TO Anzahl DO
                             FOR k:=punkte[j SHL 1-1].x TO punkte[j SHL 1].x DO
                              IF Workarea^.feld[punkte[j SHL 1].y,k]=transparent
                               THEN DrawWorkAreaPixel(k,punkte[j SHL 1].y,
                                                      farbe,DRAW,FALSE);
                       FOR j:=1 TO p_zahl DO
                        DrawWorkAreaPixel(punkte[j].x,punkte[j].y,
                                          farbe,DRAW,FALSE);
                      DrawMaus(CursorPfeil);
                      if farbe=BestWhite
                       THEN farbe:=BestBlack {Farbe alternieren lassen}
                       ELSE farbe:=BestWhite
                     END;

         IF MouseUpdate
          THEN BEGIN
                UndrawMaus;
                Event:=MouseEvent(abfrage);
                IF (Event=EventNone)
	         THEN BEGIN {das war nichts, nochmal!}
                       DrawMaus(CursorPfeil);
                       ClearMouse
                      END;
               END;
        UNTIL Event<>EventNone;
        UndrawMaus;
       END;

 {alten Inhalt wiederherstellen:}
 IF Shift
  THEN FOR j:=1 TO Anzahl DO
        FOR k:=punkte[j SHL 1-1].x TO punkte[j SHL 1].x DO
         IF Workarea^.feld[punkte[j SHL 1].y,k]=transparent
          THEN DrawWorkAreaPixel(k,punkte[j SHL 1].y,
                                 DontCare,CLEAR,FALSE);
 FOR j:=1 TO p_zahl DO
  DrawWorkAreaPixel(punkte[j].x,punkte[j].y,
                    DontCare,CLEAR,FALSE);

 {alte Grafik wiederherstellen:}
 PutImage(MeldungX,MeldungY,oldGraph^,NormalPut);
 FreeMem(oldGraph,oldGraphSize);
END;

PROCEDURE BlinkColor;
{ in: Workarea^ = aktuelle Grafikdaten}
{     StartVirtualX|Y = Anfangskoordinaten der Bildschirmanzeige der Workarea}
{     zoom = momentan gesetzter Vergrî·erungsfaktor}
{     FarbWahl = Menu fÅr Cancel/Workarea/Palettenbereich-Abfrage}
{     Abfrage = Menu fÅr Ok-Abfrage}
{out: - }
{ren: Der Benutzer wird nach einer Farbe gefragt und diese wird blinkend}
{     hervorgehoben}
LABEL nochmal;
VAR BlinkFarbe,farbe:BYTE;
    i,j,maxY,maxX:INTEGER;
    outer:BOOLEAN;
BEGIN
 DrawOkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,
           'cancel',
           'Click at the color you want',
           'to be shown blinking','',
           FarbenWahl);
 DrawMaus(CursorPfeil);
 Event:=EventNone;
 {Maus freigeben:}
 ClearMouse;
 REPEAT
  IF MouseUpdate
   THEN BEGIN
         UndrawMaus;
         {evtl. Cursordaten lîschen:}
         IF NOT InWorkArea
          THEN BEGIN {evtentuelle Cursordaten vom Bildschirm lîschen}
                SetFillStyle(SolidFill,BestBlack);
                Bar(InfoX,InfoY,InfoX+80,InfoY+29);
               END;
         Event:=MouseEvent(FarbenWahl);
         IF Event=EventSelectColor
	  THEN BEGIN {Maus im Palettenbereich geclickt}
                i:=(MausX-PaletteX-25) DIV PalBreite;
                IF i<>(MausX-PaletteX-25+3) DIV PalBreite
                 THEN BEGIN {zwischen 2 Farben geclickt!}
                       ErrBeep;
                       Event:=EventNone;
                       goto nochmal;
                      END;
                j:=(MausY-PaletteY-10) DIV PalHoehe;
                IF j<>(MausY-PaletteY-10+3) DIV PalHoehe
                 THEN BEGIN {dto.}
                       ErrBeep;
                       Event:=EventNone;
                       goto nochmal;
                      END;
                BlinkFarbe:=j SHL 4 + i; {=j*16+i}
                nochmal:;
               END
         ELSE IF Event=EventInWorkArea
	  THEN BEGIN {Maus in Workarea geclickt}
                ShowCursorDaten; {zeige an, wo/auf was der Cursor steht}
                IF LeftButton
                 THEN BEGIN
                       Absolute2WorkArea(i,j);
                       BlinkFarbe:=Workarea^.feld[j,i]
                      END
		 ELSE Event:=EventNone;  {Button war nicht gedrÅckt}
               END;
         IF (InWorkArea) AND (zoom=1)
          THEN DrawMaus(CursorKreuz)
          ELSE DrawMaus(CursorPfeil);
         IF Event=EventNone THEN ClearMouse  {auf nÑchstes Mausevent warten}
        END;
 UNTIL Event<>EventNone;

 UndrawMaus;
 {alte Grafik wiederherstellen:}
 PutImage(MeldungX,MeldungY,oldGraph^,NormalPut);
 FreeMem(oldGraph,oldGraphSize);

 {Hier: entweder ist Event=EventCancel oder BlinkFarbe ist die selektierte Farbe}
 IF Event=EventCancel THEN exit;


 DrawOkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,
           'ok',
           'Seen enough?','','',
           Abfrage);
 DrawMaus(CursorPfeil);
 Event:=EventNone;
 {Maus freigeben:}
 ClearMouse;

 i:=0; farbe:=BestWhite;
 {berechne "EndVirtualX|Y", d.h.: die max. angezeigten Koordinaten}
 maxY:=min(WorkHoehe-1, StartVirtualY+(WorkHoehe  DIV zoom));
 maxX:=min(WorkBreite-1,StartVirtualX+(WorkBreite DIV zoom));
 REPEAT
  i:=succ(i) mod 200; {Jedes 200. Mal anzeigen reicht}
  delay(5);           {*5ms = Blinkfrequenz von 1Hz }
  if i=0 THEN BEGIN
               UndrawMaus;
               {Bei langdauernden Aufgaben wÑre der Mauscursor lÑngere Zeit}
               {nicht sichtbar; da sich au·erhalb der Workarea nichts tut, }
               {kînnen wir ihn aber dort auch wÑhrend der Aktion sichtbar  }
               {machen: }
               outer:=NOT InWorkArea;
               IF outer THEN DrawMaus(CursorPfeil);
               FOR j:=StartVirtualY TO maxY DO
                FOR i:=StartVirtualX TO maxX DO
                 IF Workarea^.feld[j,i]=BlinkFarbe
                  THEN DrawWorkAreaPixel(i,j,farbe,DRAW,FALSE);
               IF outer THEN UndrawMaus;
               IF (InWorkArea) AND (zoom=1)
                THEN DrawMaus(CursorKreuz)
                ELSE DrawMaus(CursorPfeil);
               if farbe=BestWhite
                THEN farbe:=BestBlack {Farbe alternieren lassen}
                ELSE farbe:=BestWhite
              END;

  IF MouseUpdate
   THEN BEGIN
         UndrawMaus;
         Event:=MouseEvent(Abfrage);
         IF (Event=EventNone)
	  THEN BEGIN {das war nichts, nochmal!}
               IF (InWorkArea) AND (zoom=1)
                THEN DrawMaus(CursorKreuz)
                ELSE DrawMaus(CursorPfeil);
                ClearMouse
               END;
        END;
 UNTIL Event<>EventNone;

 UndrawMaus;
 {Cursordaten vom Bildschirm lîschen}
 SetFillStyle(SolidFill,BestBlack);
 Bar(InfoX,InfoY,InfoX+80,InfoY+29);
 UpdateWorkArea(StartVirtualX,StartVirtualY,maxX,maxY,TRUE);
 DrawNewObject; {evtl. begonnenes Objet zeigen}

 {alte Grafik wiederherstellen:}
 PutImage(MeldungX,MeldungY,oldGraph^,NormalPut);
 FreeMem(oldGraph,oldGraphSize);
END;

PROCEDURE ChangeColor;
{ in: Workarea^ = aktuelle Grafikdaten}
{     StartVirtualX|Y = Anfangskoordinaten der Bildschirmanzeige der Workarea}
{     zoom = momentan gesetzter Vergrî·erungsfaktor}
{     FarbWahl = Menu fÅr Cancel/Workarea/Palettenbereich-Abfrage}
{     Abfrage = Menu fÅr Ok-Abfrage}
{out: Workarae^ neue Grafikdaten}
{ren: Der Benutzer wird nach zwei Farben gefragt; die erste wird dann gegen}
{     die zweite ersetzt}
LABEL nochmal1,nochmal2;
VAR farbe,alteFarbe,neueFarbe:BYTE;
    alteFarbeS:STRING[3];
    i,j,maxY,maxX:INTEGER;
    outer:BOOLEAN;
BEGIN
 DrawOkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,
           'cancel',
           'Click at the color you',
           'want to replace','',
           FarbenWahl);
 DrawMaus(CursorPfeil);
 Event:=EventNone;
 {Maus freigeben:}
 ClearMouse;

 REPEAT
  IF MouseUpdate
   THEN BEGIN
         UndrawMaus;
         {evtl. Cursordaten lîschen:}
         IF NOT InWorkArea
          THEN BEGIN {evtentuelle Cursordaten vom Bildschirm lîschen}
                SetFillStyle(SolidFill,BestBlack);
                Bar(InfoX,InfoY,InfoX+80,InfoY+29);
               END;
         Event:=MouseEvent(FarbenWahl);
         IF Event=EventSelectColor
	  THEN BEGIN {Maus im Palettenbereich geclickt}
                i:=(MausX-PaletteX-25) DIV PalBreite;
                IF i<>(MausX-PaletteX-25+3) DIV PalBreite
                 THEN BEGIN {zwischen 2 Farben geclickt!}
                       ErrBeep;
                       Event:=EventNone;
                       goto nochmal1;
                      END;
                j:=(MausY-PaletteY-10) DIV PalHoehe;
                IF j<>(MausY-PaletteY-10+3) DIV PalHoehe
                 THEN BEGIN {dto.}
                       ErrBeep;
                       Event:=EventNone;
                       goto nochmal1;
                      END;
                alteFarbe:=j SHL 4 + i; {=j*16+i}
                nochmal1:;
               END
         ELSE IF Event=EventInWorkArea
	  THEN BEGIN {Maus in Workarea geclickt}
                ShowCursorDaten; {zeige an, wo/auf was der Cursor steht}
                IF LeftButton
                 THEN BEGIN
                       Absolute2WorkArea(i,j);
                       alteFarbe:=Workarea^.feld[j,i]
                      END
		 ELSE Event:=EventNone;
               END;
         IF (InWorkArea) AND (zoom=1)
          THEN DrawMaus(CursorKreuz)
          ELSE DrawMaus(CursorPfeil);
         IF Event=EventNone THEN ClearMouse
        END;
 UNTIL Event<>EventNone;

 UndrawMaus;
 {alte Grafik wiederherstellen:}
 PutImage(MeldungX,MeldungY,oldGraph^,NormalPut);
 FreeMem(oldGraph,oldGraphSize);

 {Hier: entweder ist Event=EventCancel oder alteFarbe ist die selektierte Farbe}
 IF Event=EventCancel THEN exit;

 STR(alteFarbe:3,alteFarbeS);
 {--------- jetzt dasselbe nochmal, fÅr die neue Farbe: ---------}
 DrawOkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,
           'cancel',
           'Now select the new color',
           'for color '+alteFarbeS,'',
           FarbenWahl);
 DrawMaus(CursorPfeil);
 Event:=EventNone;
 {Maus freigeben:}
 ClearMouse;

 REPEAT
  IF MouseUpdate
   THEN BEGIN
         UndrawMaus;
         {evtl. Cursordaten lîschen:}
         IF NOT InWorkArea
          THEN BEGIN {evtentuelle Cursordaten vom Bildschirm lîschen}
                SetFillStyle(SolidFill,BestBlack);
                Bar(InfoX,InfoY,InfoX+80,InfoY+29);
               END;
         Event:=MouseEvent(FarbenWahl);
         IF Event=EventSelectColor
	  THEN BEGIN {Maus im Palettenbereich geclickt}
                i:=(MausX-PaletteX-25) DIV PalBreite;
                IF i<>(MausX-PaletteX-25+3) DIV PalBreite
                 THEN BEGIN {zwischen 2 Farben geclickt!}
                       ErrBeep;
                       Event:=EventNone;
                       goto nochmal2;
                      END;
                j:=(MausY-PaletteY-10) DIV PalHoehe;
                IF j<>(MausY-PaletteY-10+3) DIV PalHoehe
                 THEN BEGIN {dto.}
                       ErrBeep;
                       Event:=EventNone;
                       goto nochmal2;
                      END;
                neueFarbe:=j SHL 4 + i; {=j*16+i}
                nochmal2:;
               END
         ELSE IF Event=EventInWorkArea
	  THEN BEGIN {Maus in Workarea geclickt}
                ShowCursorDaten; {zeige an, wo/auf was der Cursor steht}
                IF LeftButton
                 THEN BEGIN
                       Absolute2WorkArea(i,j);
                       neueFarbe:=Workarea^.feld[j,i]
                      END
		 ELSE Event:=EventNone
               END;
         IF (InWorkArea) AND (zoom=1)
          THEN DrawMaus(CursorKreuz)
          ELSE DrawMaus(CursorPfeil);
         IF Event=EventNone THEN ClearMouse
        END;
 UNTIL Event<>EventNone;

 UndrawMaus;
 {alte Grafik wiederherstellen:}
 PutImage(MeldungX,MeldungY,oldGraph^,NormalPut);
 FreeMem(oldGraph,oldGraphSize);

 {Hier: entweder ist Event=EventCancel oder neueFarbe ist die selektierte Farbe}
 IF Event=EventCancel THEN exit;


 {-------jetzt: alteFarbe=zu ersetzende Farbe, neueFarbe=Ersatz dafÅr -------}
 IF alteFarbe=neueFarbe
  THEN BEGIN
        ErrBeep;
        OkBox(MeldungX,MeldungY,MeldungX+220,MeldungY+60,
              'ok',
              'You chose the same color',
              'twice, so there is nothing',
              'to change!',
              Abfrage);
       END
  ELSE BEGIN {Farbe austauschen!}
        FOR j:=0 TO WorkHoehe-1 DO
         FOR i:=0 TO WorkBreite-1 DO
          IF Workarea^.feld[j,i]=alteFarbe THEN Workarea^.feld[j,i]:=neueFarbe;
        IF (alteFarbe=transparent) OR (neueFarbe=transparent)
         THEN FindWorkAreaMaxUSed;
        maxY:=min(WorkHoehe-1, StartVirtualY+(WorkHoehe  DIV zoom));
        maxX:=min(WorkBreite-1,StartVirtualX+(WorkBreite DIV zoom));
        UpdateWorkArea(StartVirtualX,StartVirtualY,maxX,maxY,TRUE);
        DrawNewObject; {evtl. begonnenes Objet zeigen}
       END;
END;

PROCEDURE PaletteChange;
{ in: MausX,MausY = irgendwo im Palettenbereich}
{out: - }
{rem: Die vom Benutzer angewÑhlte Farbe wurde evtl. geÑndert}
LABEL nope;
CONST StartX=MeldungX;  {li. obere Ecke der Meldungsbox}
      StartY=MeldungY;
      EndX=StartX+220;
      EndY=StartY+65;
      sx=25;       {Grî·e einer Menubox}
      sy=15;
      ProbeX1=StartX+10;   {Koord. fÅr Anzeige der gewÑhlten Farbe}
      ProbeX2=ProbeX1+39;
      ProbeY1=StartY+12;
      ProbeY2=ProbeY1+36;
      EventIncRed=104;
      EventDecRed=105;
      EventIncGreen=106;
      EventDecGreen=107;
      EventIncBlue=108;
      EventDecBlue=109;
      PalMenu:ARRAY[1..11] OF box=(
 {Ok/Cancel/Workarea/Palettenbereich/inc&dec fÅr R,G,B:}

       {"Ok"-Box:}
       (x1:StartX+150; y1:StartY+5; x2:StartX+150+55; y2:StartY+5+sy;
        Name1:'  ok  ';Name2:'';
        Show :Dummy;
        Event:EventYes;
        Click:TRUE;
        Paint:TRUE),

       {"Cancel"-Box:}
       (x1:StartX+150; y1:StartY+25; x2:StartX+150+55; y2:StartY+25+sy;
        Name1:'cancel';Name2:'';
        Show :Dummy;
        Event:EventCancel;
        Click:TRUE;
        Paint:TRUE),

       {"Rot-"-Box:}
       (x1:StartX+60; y1:StartY+5; x2:StartX+60+sx; y2:StartY+5+sy;
        Name1:'R-';Name2:'';
        Show :Dummy;
        Event:EventDecRed;
        Click:TRUE;
        Paint:TRUE),

       {"Rot+"-Box:}
       (x1:StartX+90; y1:StartY+5; x2:StartX+90+sx; y2:StartY+5+sy;
        Name1:'R+';Name2:'';
        Show :Dummy;
        Event:EventIncRed;
        Click:TRUE;
        Paint:TRUE),


       {"GrÅn-"-Box:}
       (x1:StartX+60; y1:StartY+25; x2:StartX+60+sx; y2:StartY+25+sy;
        Name1:'G-';Name2:'';
        Show :Dummy;
        Event:EventDecGreen;
        Click:TRUE;
        Paint:TRUE),

       {"GrÅn+"-Box:}
       (x1:StartX+90; y1:StartY+25; x2:StartX+90+sx; y2:StartY+25+sy;
        Name1:'G+';Name2:'';
        Show :Dummy;
        Event:EventIncGreen;
        Click:TRUE;
        Paint:TRUE),


       {"Blau-"-Box:}
       (x1:StartX+60; y1:StartY+45; x2:StartX+60+sx; y2:StartY+45+sy;
        Name1:'B-';Name2:'';
        Show :Dummy;
        Event:EventDecBlue;
        Click:TRUE;
        Paint:TRUE),

       {"Blau+"-Box:}
       (x1:StartX+90; y1:StartY+45; x2:StartX+90+sx; y2:StartY+45+sy;
        Name1:'B+';Name2:'';
        Show :Dummy;
        Event:EventIncBlue;
        Click:TRUE;
        Paint:TRUE),

       {Workarea:}
       (x1:WorkStartX;    y1:WorkStartY;
        x2:WorkEndX-1;    y2:WorkEndY-1;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventInWorkArea;
        Click:FALSE;    {Anclicken nicht nîtig}
        Paint:FALSE),   {...wird aber nicht gezeichnet}

       {Palettenbereich:}
       (x1:PaletteX+25;                y1:PaletteY+10;
        x2:PaletteX+25+16*PalBreite-3; y2:PaletteY+10+16*PalHoehe-3;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventSelectColor;
        Click:TRUE;     {Anclicken nîtig}
        Paint:FALSE),   {...wird aber nicht gezeichnet}

       {Sentinelwert, da x1>x2!}
       (x1:1; y1:0; x2:0; y2:0;
        Name1:'';Name2:'';
        Show :Dummy;
        Event:EventNone;
        Click:TRUE;
        Paint:FALSE)
      );

VAR FarbeZumAendern,Farbe,temp:BYTE;
    i,j:INTEGER;
    ch:CHAR;
    mymenu:ARRAY[1..10] OF box ABSOLUTE menu;
    ColorName:STRING[5];
    cred,cgreen,cblue,
    oldred,oldgreen,oldblue:BYTE;
    total,change:BOOLEAN;

  PROCEDURE zeichneMenu2;
  {rem: zeichnet die verÑnderlichen Menudinge}
  BEGIN
   SetFillStyle(SolidFill,FarbeZumAendern);
   Bar(ProbeX1+1,ProbeY1+1,ProbeX2-1,ProbeY2-1);

   SetFillStyle(SolidFill,BestLightGray);
   Bar(StartX+90+sx+5,StartY+5+4,StartX+90+sx+5+18,StartY+45+4+9);
   SetColor(BestBlack);
   Str(cred  :2,s); OutTextXY(StartX+90+sx+5,StartY+5+4,s);
   Str(cgreen:2,s); OutTextXY(StartX+90+sx+5,StartY+25+4,s);
   Str(cblue :2,s); OutTextXY(StartX+90+sx+5,StartY+45+4,s);
  END;

  PROCEDURE zeichneMenu1;
  {rem: zeichnet die unverÑnderlichen _und_ die verÑnderlichen Menudinge}
  VAR i:INTEGER;
      s:STRING[3];
  BEGIN
   SetFillStyle(SolidFill,BestLightGray);
   Bar(StartX,StartY,EndX,EndY);
   SetFillStyle(SolidFill,BestWhite);
   Bar(StartX,StartY,EndX-1,StartY+1);
   Bar(StartX,StartY,StartX+1,EndY-1);
   SetFillStyle(SolidFill,BestDarkGray);
   Bar(StartX,EndY-1,EndX,EndY);
   Bar(EndX-1,StartY,EndX,EndY);

   i:=1;
   WHILE PalMenu[i].x1<=PalMenu[i].x2 DO
    BEGIN
     WITH PalMenu[i] DO
      BEGIN
       IF Paint
        THEN BEGIN
              SetFillStyle(SolidFill,BestLightGray);
              Bar(x1,y1,x2,y2);
              SetFillStyle(SolidFill,BestWhite);
              Bar(x1,y1,x2-1,y1+1);
              Bar(x1,y1,x1+1,y2-1);
              SetFillStyle(SolidFill,BestDarkGray);
              Bar(x1,y2-1,x2,y2);
              Bar(x2-1,y1,x2,y2);
              SetColor(BestBlack);
              IF Name1<>'' THEN OutTextXY(x1+5,y1+4,Name1);
             END;
      END; {of WITH}
     inc(i);
    END; {of WHILE}

   SetColor(BestBlack);
   Rectangle(ProbeX1,ProbeY1,ProbeX2,ProbeY2);
   SetColor(BestBlack);
   OutTextXY(ProbeX1,ProbeY2+3,ColorName);

   zeichneMenu2;
  END;

BEGIN
 i:=(MausX-PaletteX-25) DIV PalBreite;
 IF i<>(MausX-PaletteX-25+3) DIV PalBreite
  THEN exit; {knapp daneben ist auch vorbei: zwischen 2 Farben geclickt!}
 j:=(MausY-PaletteY-10) DIV PalHoehe;
 IF j<>(MausY-PaletteY-10+3) DIV PalHoehe
  THEN exit; {dto.}

 FarbeZumAendern:=j SHL 4 + i; {=j*16+i}
 WITH ActualColors[FarbeZumAendern] DO
  BEGIN
   cred:=red; cgreen:=green; cblue:=blue;
  END;
 Str(FarbeZumAendern:3,ColorName); ColorName:='C:'+ColorName;

 oldred:=cred; oldgreen:=cgreen; oldblue:=cblue; {alte Farben fÅr "CANCEL"!}
 {alte Grafik sichern:}
 oldGraphSize:=ImageSize(StartX,StartY,EndX,EndY);
 GetMem(oldGraph,oldGraphSize);
 GetImage(StartX,StartY,EndX,EndY,oldGraph^);


 zeichneMenu1;

 DrawMaus(CursorPfeil);
 Event:=EventNone;
 {Maus freigeben:}
 ClearMouse;

 total:=FALSE;   {wird wahr, wenn min. eine Menufarbe verÑndert wurde}
 REPEAT
  IF MouseUpdate
   THEN BEGIN
         UndrawMaus;
         IF NOT InWorkArea
          THEN BEGIN {evtentuelle Cursordaten vom Bildschirm lîschen}
                SetFillStyle(SolidFill,BestBlack);
                Bar(InfoX,InfoY,InfoX+80,InfoY+29);
               END;
         Event:=MouseEvent(PalMenu);
         IF Event=EventNone THEN Event:=EventMouseMoved;
        END
   ELSE IF (KeyPressed) THEN
        BEGIN
         WHILE KeyPressed DO ch:=Upcase(ReadKey);
         IF ch='O' THEN Event:=EventYes          {okay?}
         ELSE IF ch='C' THEN Event:=EventCancel; {cancel?}
        END;

  CASE Event OF
   EventIncRed  :IF cred  <63 THEN Inc(cred);
   EventIncGreen:IF cgreen<63 THEN Inc(cgreen);
   EventIncBlue :IF cblue <63 THEN Inc(cblue);
   EventDecRed  :IF cred  >0  THEN Dec(cred);
   EventDecGreen:IF cgreen>0  THEN Dec(cgreen);
   EventDecBlue :IF cblue >0  THEN Dec(cblue);
   EventCancel  :BEGIN {alte Farben wiederherstellen}
                  cred:=oldred; cgreen:=oldgreen; cblue:=oldblue
                 END;
   EventSelectColor:
                 BEGIN
                  i:=(MausX-PaletteX-25) DIV PalBreite;
                  IF i<>(MausX-PaletteX-25+3) DIV PalBreite
                   THEN goto nope; {knapp daneben ist auch vorbei: zwischen 2 Farben geclickt!}
                  j:=(MausY-PaletteY-10) DIV PalHoehe;
                  IF j<>(MausY-PaletteY-10+3) DIV PalHoehe
                   THEN goto nope; {dto.}

                  temp:=j SHL 4 + i; {=j*16+i}
                  IF temp<>FarbeZumAendern
                   THEN WITH ActualColors[temp] DO
                    BEGIN {andere Farbe Åbernehmen}
                     cred:=red; cgreen:=green; cblue:=blue
                    END
                   ELSE ErrBeep;

                  nope:;
                 END;
   EventInWorkArea:
                 BEGIN
                  ShowCursorDaten; {zeige an, wo/auf was der Cursor steht}
                  IF LeftButton
                   THEN BEGIN
                         Absolute2Workarea(i,j);
                         temp:=Workarea^.feld[j,i];
                         IF temp<>FarbeZumAendern
                          THEN WITH ActualColors[temp] DO
                           BEGIN {andere Farbe Åbernehmen}
                            cred:=red; cgreen:=green; cblue:=blue
                           END
                          ELSE ErrBeep;
                        END
                 END;
  END;

  WITH ActualColors[FarbeZumAendern] DO
   BEGIN
    IF (cred<>red) OR (cgreen<>green) OR (cblue<>blue)
     THEN BEGIN {Farbe wurde verÑndert}
           SetPaletteEntry(FarbeZumAendern,cred,cgreen,cblue); {sichtbar machen}
           red:=cred;     {énderung in aktueller Farbpalette vermerken}
           green:=cgreen;
           blue:=cblue;

           {nun evtl. neue Menufarben berechnen:}
           change:=FALSE;
           temp:=BestFit(White);
           IF temp<>BestWhite THEN BEGIN BestWhite:=temp; change:=TRUE END;
           temp:=BestFit(Black);
           IF temp<>BestBlack THEN BEGIN BestBlack:=temp; change:=TRUE END;
           temp:=BestFit(Cyan);
           IF temp<>BestCyan THEN BEGIN BestCyan:=temp; change:=TRUE END;
           temp:=BestFit(LightGray);
           IF temp<>BestLightGray THEN BEGIN BestLightGray:=temp; change:=TRUE END;
           temp:=BestFit(DarkGray);
           IF temp<>BestDarkGray THEN BEGIN BestDarkGray:=temp; change:=TRUE END;

           IF change           {falls verÑnderte Farbe eine der verwendeten}
            THEN zeichneMenu1  {Menufarben ist, dann ein "gro·es" Update   }
            ELSE zeichneMenu2; {durchfÅhren, sonst ein "kleines"}
           total:=total OR change; {fÅr Abschlu· merken}
          END;
   END;

  IF (Event<>EventNone)
   THEN BEGIN
         IF (Event<>EventYes) AND (Event<>EventCancel)
          THEN Event:=EventNone;
         IF (InWorkArea) AND (zoom=1)
          THEN DrawMaus(CursorKreuz)
          ELSE DrawMaus(CursorPfeil);
         ClearMouse;
        END;
 UNTIL (Event=EventYes) OR (Event=EventCancel);

 UndrawMaus;
 {alte Grafik wiederherstellen:}
 PutImage(StartX,StartY,oldGraph^,NormalPut);
 FreeMem(oldGraph,oldGraphSize);

 IF PalEqual(ActualColors,DefaultColors)
  THEN BEGIN
        IF Palnamekurz<>''
	 THEN BEGIN
               Palnamelang:=''; Palnamekurz:='';
              END;
       END;
 ShowPalName;
 IF total THEN RestoreScreen; {neue Menufarben Åberall Ñndern!}
END;

PROCEDURE RotateLeft(amount:WORD);
{ in: Workarea^ = aktuelle Grafikdaten}
{     StartVirtualX|Y = aktuelle Anfangskoord. des sichtbaren Ausschnittes}
{     WorkHoehe, WorkBreite = Abmessungen der Workarea}
{     zoom = aktueller Vergrî·erungsfaktor}
{     amount = #Spalten, um die rotiert werden soll: 1..WorkBreite-1}
{out: Workarea^ = neue Grafikdaten}
{     WorkAreaMaxUsedX|Y = neue Extremkoordinaten}
{rem: Workarea-Inhalt wurde um 1 Spalte nach links rotiert}
VAR maxX,maxY,y:INTEGER;
    p1,p2:POINTER;
    tempArea:^WorkAreaTyp;
    size:WORD;
BEGIN
 New(tempArea);
 FOR y:=0 TO WorkHoehe-1 DO
  move(Workarea^.feld[y,0],tempArea^.feld[y,0],amount);
 p1:=@Workarea^.feld[0,amount];
 p2:=@Workarea^.feld[0,0];
 size:=WorkHoehe*WorkBreite -amount;
 ASM
   MOV CX,size
   LES DI,p2
   LDS SI,p1
   CLD
   REP MOVSB
   MOV AX,SEG @DATA
   MOV DS,AX
 END;
 FOR y:=0 TO WorkHoehe-1 DO
  move(tempArea^.feld[y,0],Workarea^.feld[y,WorkBreite-amount],amount);
 Dispose(tempArea);

 FindWorkAreaMaxUsed;
 maxY:=min(WorkHoehe-1, StartVirtualY+(WorkHoehe  DIV zoom));
 maxX:=min(WorkBreite-1,StartVirtualX+(WorkBreite DIV zoom));
 UpdateWorkArea(StartVirtualX,StartVirtualY,maxX,maxY,TRUE);
 DrawNewObject; {evtl. begonnenes Objet zeigen}
END;

PROCEDURE RotateRight(amount:WORD);
{ in: Workarea^ = aktuelle Grafikdaten}
{     StartVirtualX|Y = aktuelle Anfangskoord. des sichtbaren Ausschnittes}
{     WorkHoehe, WorkBreite = Abmessungen der Workarea}
{     zoom = aktueller Vergrî·erungsfaktor}
{     amount = #Spalten, um die rotiert werden soll: 1..WorkBreite-1}
{out: Workarea^ = neue Grafikdaten}
{     WorkAreaMaxUsedX|Y = neue Extremkoordinaten}
{rem: Workarea-Inhalt wurde um 1 Spalte nach rechts rotiert}
VAR maxX,maxY,y:INTEGER;
    p1,p2:POINTER;
    tempArea:^WorkAreaTyp;
    size:WORD;
BEGIN
 New(tempArea);
 FOR y:=0 TO WorkHoehe-1 DO
  move(Workarea^.feld[y,WorkBreite-amount],tempArea^.feld[y,0],amount);
 p1:=@Workarea^.feld[WorkHoehe-1,WorkBreite-1-amount];
 p2:=@Workarea^.feld[WorkHoehe-1,WorkBreite-1];
 size:=WorkHoehe*WorkBreite -amount;
 ASM
   MOV CX,size
   LES DI,p2
   LDS SI,p1
   STD
   REP MOVSB
   CLD
   MOV AX,SEG @DATA
   MOV DS,AX
 END;
 FOR y:=0 TO WorkHoehe-1 DO
  move(tempArea^.feld[y,0],Workarea^.feld[y,0],amount);
 Dispose(tempArea);

 FindWorkAreaMaxUsed;
 maxY:=min(WorkHoehe-1, StartVirtualY+(WorkHoehe  DIV zoom));
 maxX:=min(WorkBreite-1,StartVirtualX+(WorkBreite DIV zoom));
 UpdateWorkArea(StartVirtualX,StartVirtualY,maxX,maxY,TRUE);
 DrawNewObject; {evtl. begonnenes Objet zeigen}
END;

PROCEDURE RotateUp(amount:WORD);
{ in: Workarea^ = aktuelle Grafikdaten}
{     StartVirtualX|Y = aktuelle Anfangskoord. des sichtbaren Ausschnittes}
{     WorkHoehe, WorkBreite = Abmessungen der Workarea}
{     zoom = aktueller Vergrî·erungsfaktor}
{     amount = #Zeilen, um die rotiert werden soll: 1..WorkHoehe-1}
{out: Workarea^ = neue Grafikdaten}
{     WorkAreaMaxUsedX|Y = neue Extremkoordinaten}
{rem: Workarea-Inhalt wurde um 1 Zeile nach oben rotiert}
VAR maxX,maxY,y:INTEGER;
    p1,p2:POINTER;
    tempArea:^WorkAreaTyp;
    size:WORD;
BEGIN
 New(tempArea);
 move(Workarea^.feld[0,0],tempArea^.feld[0,0],WorkBreite*amount);
 p1:=@Workarea^.feld[amount,0];
 p2:=@Workarea^.feld[0,0];
 size:=(WorkHoehe-amount)*WorkBreite;
 ASM
   MOV CX,size
   LES DI,p2
   LDS SI,p1
   CLD
   REP MOVSB
   MOV AX,SEG @DATA
   MOV DS,AX
 END;
 move(tempArea^.feld[0,0],Workarea^.feld[WorkHoehe-amount,0],WorkBreite*amount);
 Dispose(tempArea);

 FindWorkAreaMaxUsed;
 maxY:=min(WorkHoehe-1, StartVirtualY+(WorkHoehe  DIV zoom));
 maxX:=min(WorkBreite-1,StartVirtualX+(WorkBreite DIV zoom));
 UpdateWorkArea(StartVirtualX,StartVirtualY,maxX,maxY,TRUE);
 DrawNewObject; {evtl. begonnenes Objet zeigen}
END;

PROCEDURE RotateDown(amount:WORD);
{ in: Workarea^ = aktuelle Grafikdaten}
{     StartVirtualX|Y = aktuelle Anfangskoord. des sichtbaren Ausschnittes}
{     WorkHoehe, WorkBreite = Abmessungen der Workarea}
{     zoom = aktueller Vergrî·erungsfaktor}
{     amount = #Zeilen, um die rotiert werden soll: 1..WorkHoehe-1}
{out: Workarea^ = neue Grafikdaten}
{     WorkAreaMaxUsedX|Y = neue Extremkoordinaten}
{rem: Workarea-Inhalt wurde um 1 Zeile nach unten rotiert}
VAR maxX,maxY,y:INTEGER;
    p1,p2:POINTER;
    tempArea:^WorkAreaTyp;
    size:WORD;
BEGIN
 New(tempArea);
 move(Workarea^.feld[WorkHoehe-amount,0],tempArea^.feld[0,0],WorkBreite*amount);
 p1:=@Workarea^.feld[WorkHoehe-1-amount,WorkBreite-1];
 p2:=@Workarea^.feld[WorkHoehe-1  ,WorkBreite-1];
 size:=(WorkHoehe-amount)*WorkBreite;
 ASM
   MOV CX,size
   LES DI,p2
   LDS SI,p1
   STD
   REP MOVSB
   CLD
   MOV AX,SEG @DATA
   MOV DS,AX
 END;
 move(tempArea^.feld[0,0],Workarea^.feld[0,0],WorkBreite*amount);
 Dispose(tempArea);

 FindWorkAreaMaxUsed;
 maxY:=min(WorkHoehe-1, StartVirtualY+(WorkHoehe  DIV zoom));
 maxX:=min(WorkBreite-1,StartVirtualX+(WorkBreite DIV zoom));
 UpdateWorkArea(StartVirtualX,StartVirtualY,maxX,maxY,TRUE);
 DrawNewObject; {evtl. begonnenes Objet zeigen}
END;

PROCEDURE MirrorHorizontal;
{ in: Workarea^ = aktuelle Grafikdaten}
{     StartVirtualX|Y = aktuelle Anfangskoord. des sichtbaren Ausschnittes}
{     WorkHoehe, WorkBreite = Abmessungen der Workarea}
{     zoom = aktueller Vergrî·erungsfaktor}
{out: Workarea^ = neue Grafikdaten}
{rem: Inhalt der Workarea wurde horizontal gespiegelt}
VAR maxX,maxY,x,y:INTEGER;
    temp:BYTE;
BEGIN
 IF (WorkAreaMaxUsedX=0) AND (WorkAreaMaxUsedY=0) AND
    (Workarea^.feld[0,0]=transparent)
  THEN BEGIN {Workarea leer!}
        ErrBeep;
        exit
       END;

 FOR y:=0 TO WorkAreaMaxUsedY DO
  FOR x:=0 TO min(WorkAreaMaxUsedX,(WorkBreite-1) SHR 1) DO
   BEGIN {Punkte einer Zeile austauschen}
    temp:=Workarea^.feld[y,x];
    Workarea^.feld[y,x]:=Workarea^.feld[y,WorkBreite-1-x];
    Workarea^.feld[y,WorkBreite-1-x]:=temp
   END;

 FindWorkAreaMaxUsed;
 maxY:=min(WorkHoehe-1, StartVirtualY+(WorkHoehe  DIV zoom));
 maxX:=min(WorkBreite-1,StartVirtualX+(WorkBreite DIV zoom));
 UpdateWorkArea(StartVirtualX,StartVirtualY,maxX,maxY,TRUE);
 DrawNewObject; {evtl. begonnenes Objet zeigen}
END;

PROCEDURE MirrorVertical;
{ in: Workarea^ = aktuelle Grafikdaten}
{     StartVirtualX|Y = aktuelle Anfangskoord. des sichtbaren Ausschnittes}
{     WorkHoehe, WorkBreite = Abmessungen der Workarea}
{     zoom = aktueller Vergrî·erungsfaktor}
{out: Workarea^ = neue Grafikdaten}
{rem: Inhalt der Workarea wurde vertikal gespiegelt}
VAR maxX,maxY,x,y:INTEGER;
    temp:BYTE;
BEGIN
 IF (WorkAreaMaxUsedX=0) AND (WorkAreaMaxUsedY=0) AND
    (Workarea^.feld[0,0]=transparent)
  THEN BEGIN {Workarea leer!}
        ErrBeep;
        exit
       END;

 FOR x:=0 TO WorkAreaMaxUsedX DO
  FOR y:=0 TO min(WorkAreaMaxUsedY,(WorkHoehe-1) SHR 1) DO
   BEGIN {Punkte einer Spalte austauschen}
    temp:=Workarea^.feld[y,x];
    Workarea^.feld[y,x]:=Workarea^.feld[WorkHoehe-1-y,x];
    Workarea^.feld[WorkHoehe-1-y,x]:=temp
   END;

 FindWorkAreaMaxUsed;
 maxY:=min(WorkHoehe-1, StartVirtualY+(WorkHoehe  DIV zoom));
 maxX:=min(WorkBreite-1,StartVirtualX+(WorkBreite DIV zoom));
 UpdateWorkArea(StartVirtualX,StartVirtualY,maxX,maxY,TRUE);
 DrawNewObject; {evtl. begonnenes Objet zeigen}
END;

PROCEDURE ObenLinks;
{ in: Workarea^ = aktuelle Grafikdaten}
{     StartVirtualX|Y = aktuelle Anfangskoord. des sichtbaren Ausschnittes}
{     WorkHoehe, WorkBreite = Abmessungen der Workarea}
{     zoom = aktueller Vergrî·erungsfaktor}
{out: Workarea^ = neue Grafikdaten}
{rem: Inhalt der Workarea wurde soweit wie mîglich nach links oben geschoben}
VAR minX,minY,maxX,maxY,x,y:INTEGER;
    tempArea:^WorkAreaTyp;
BEGIN
 IF (WorkAreaMaxUsedX=0) AND (WorkAreaMaxUsedY=0) AND
    (Workarea^.feld[0,0]=transparent)
  THEN BEGIN {Workarea leer!}
        ErrBeep;
        exit
       END;

 minX:=WorkAreaMaxUsedX;
 FOR y:=WorkAreaMaxUsedY DOWNTO 0 DO
  FOR x:=minX DOWNTO 0 DO
   IF Workarea^.feld[y,x]<>transparent
    THEN minX:=x;   {minimales X dieser Zeile bestimmen}

 minY:=WorkAreaMaxUsedY;
 FOR x:=WorkAreaMaxUsedX DOWNTO 0 DO
  FOR y:=minY DOWNTO 0 DO
   IF Workarea^.feld[y,x]<>transparent
    THEN minY:=y;   {minimales Y dieser Spalte bestimmen}

 IF (minX<>0) OR (minY<>0)
  THEN BEGIN {Inhalt hochschieben:}
        New(tempArea);
        Move(WorkArea^,tempArea^,SizeOf(WorkArea^));
        FillChar(WorkArea^,SizeOf(WorkArea^),transparent);
        FOR y:=minY TO WorkAreaMaxUsedY DO
         FOR x:=minX TO WorkAreaMaxUsedX DO
          Workarea^.feld[y-minY,x-minX]:=tempArea^.feld[y,x];
        Dispose(tempArea);
       END;

 FindWorkAreaMaxUsed;
 maxY:=min(WorkHoehe-1, StartVirtualY+(WorkHoehe  DIV zoom));
 maxX:=min(WorkBreite-1,StartVirtualX+(WorkBreite DIV zoom));
 UpdateWorkArea(StartVirtualX,StartVirtualY,maxX,maxY,TRUE);
 DrawNewObject; {evtl. begonnenes Objet zeigen}
END;


BEGIN
 init;

 DrawMaus(CursorPfeil); {...und anzeigen}
 EnableMouse;

 repeat
  IF KeyPressed
   THEN BEGIN
         ch:=ReadKey; Shift:=(mem[$0:$417] AND 3)<>0;
         IF ch=#0
          THEN Wahl:=ORD(ReadKey) SHL 8  {Funktionstasten -> >256}
          ELSE Wahl:=ORD(ch);
         CASE Wahl OF
          $4B00: Event:=EventScrollLeft;          {"<-" = Scroll nach links }
          $4D00: Event:=EventScrollRight;         {"->" = Scroll nach rechts}
          $4800: Event:=EventScrollUp;            {UP   = Scroll nach oben  }
          $5000: Event:=EventScrollDown;          {DOWN = Scroll nach unten }
          $2B  : Event:=EventZoomin;              {"+"  = vergrî·ern}
          $2D  : Event:=EventZoomout;             {"-"  = verkleinern}
          $3B00: Event:=EventHelp;                {F1   = Hilfe}
          $3C00: Event:=EventSpeichereSprite;     {F2   = Sprite speichern}
          $3D00,
          $5600: Event:=EventLadeSprite;          {(Sh-)F3 = Sprite laden}
          $3E00: Event:=EventSpeicherePalette;    {F4   = Palette speichern}
          $3F00: Event:=EventLadePalette;         {F5   = Palette laden}
          $5800: Event:=EventResetColors;         {Sh-F5= Defaultpalette}
          $4000: Event:=EventSpeichereHintergrund;{F6   = Bild speichern}
          $4100: Event:=EventLadeHintergrund;     {F7 = Hintergrundbild laden}
          $4200: Event:=EventEraseWorkarea;       {F8   = Workarea lîschen}
          $4300: BEGIN                            {F9 = Palette auf Palette mappen }
                  IF (WorkAreaMaxUsedX<>0) OR
                     (WorkAreaMaxUsedY<>0)     {Workarea nicht leer? }
                   THEN BEGIN
                         IF SelectZielPalette  {Zielpalette auswÑhlen}
                          THEN Event:=EventMapPalette
                        END
                   ELSE Event:=EventError
                 END;
          $5C00: Event:=EventMapToBIOSPAlette;    {Sh-F9 = Palette auf BIOS-Defaultfarben mappen}
          $4400: Event:=EventQuit;                {F10 = Beenden}
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

                {Folgende Mausaktionen mÅssen genauer untersucht werden,}
                {ob sie im geg. Kontext zulÑssig sind:}
                IF Event=EventMapPalette
                 THEN BEGIN  {Palette auf Palette mappen}
                       IF (WorkAreaMaxUsedX<>0) OR
                          (WorkAreaMaxUsedY<>0)    {Workarea nicht leer? }
                        THEN BEGIN
                              IF SelectZielPalette {Zielpalette auswÑhlen}
                               THEN Event:=EventMapPalette
                             END
                        ELSE Event:=EventError
                      END
               END;

  IF Event<>EventNone
   THEN UnDrawMaus; {alten Bildschirminhalt unter Mauscursor restaurieren}

  CASE Event OF
   EventScrollLeft : BEGIN
                      IF Shift
                       THEN ScrollLeft(1)
                       ELSE ScrollLeft(max(1,(WorkBreite DIV zoom) SHR 2));
                      IF InWorkArea   {evtl. geriete die Maus sonst nÑmlich}
                       THEN BEGIN     {au·erhalb des Bereiches XÓ[0..319]  }
                             AdjustMouse; {deshalb Maus nachjustieren}
                             ShowCursorDaten
                            END;
                     END;
   EventScrollRight: BEGIN
                      IF Shift
                       THEN ScrollRight(1)
                       ELSE ScrollRight(max(1,(WorkBreite DIV zoom) SHR 2));
                      IF InWorkArea   {evtl. geriete die Maus sonst nÑmlich}
                       THEN BEGIN     {au·erhalb des Bereiches XÓ[0..319]  }
                             AdjustMouse; {deshalb Maus nachjustieren}
                             ShowCursorDaten
                            END;
                     END;
   EventScrollUp   : BEGIN
                      IF Shift
                       THEN ScrollUp(1) 
                       ELSE ScrollUp(max(1,(WorkBreite DIV zoom) SHR 2));
                      IF InWorkArea   {evtl. geriete die Maus sonst nÑmlich}
                       THEN BEGIN     {au·erhalb des Bereiches XÓ[0..319]  }
                             AdjustMouse; {deshalb Maus nachjustieren}
                             ShowCursorDaten
                            END;
                     END;
   EventScrollDown : BEGIN
                      IF Shift
                       THEN ScrollDown(1) 
                       ELSE ScrollDown(max(1,(WorkBreite DIV zoom) SHR 2));
                      IF InWorkArea   {evtl. geriete die Maus sonst nÑmlich}
                       THEN BEGIN     {au·erhalb des Bereiches XÓ[0..319]  }
                             AdjustMouse; {deshalb Maus nachjustieren}
                             ShowCursorDaten
                            END;
                     END;
   EventZoomin     : BEGIN
                      Zoomin;
                      IF InWorkArea       {zoomen verÑndert Punktkoord.,}
                       THEN BEGIN
                             AdjustMouse; {deshalb Maus nachjustieren}
                             ShowCursorDaten
                            END;
                     END;
   EventZoomout    : BEGIN
                      Zoomout;
                      IF InWorkArea       {zoomen verÑndert Punktkoord.,}
                       THEN BEGIN
                             AdjustMouse; {deshalb Maus nachjustieren}
                             ShowCursorDaten
                            END;
                     END;
   EventHelp       : Help;
   EventSpeichereSprite: speichereSprite;
   EventLadeSprite : ladeSprite;
   EventSpeicherePalette: speicherePalette;
   EventLadePalette: ladePalette;
   EventResetColors: ResetColors;
   EventSpeichereHintergrund: SpeichereHintergrund;
   EventLadeHintergrund: ladeHintergrund;
   EventMapPalette: MapPalette;
   EventMapToBIOSPalette:MapToBIOSPalette;
   EventNone:;
   EventError      : ErrBeep;
   EventInWorkArea : BEGIN
                      AdjustMouse;
                      ShowCursorDaten;
                      WorkAreaAction; {Aktion innerhalb der Workarea?}
                     END;
   EventMouseMoved:;
   EventSelectColor: IF LeftButton
                      THEN SelectColor    {linker Button = Farbe wÑhlen}
                      ELSE PaletteChange; {recher Button = Farbe Ñndern}
   EventShowBorder : ShowBorder(Shift);
   EventBlinkColor : BlinkColor;
   EventChangeColor: ChangeColor;
   EventRotateLeft : IF Shift
                      THEN RotateLeft(1)
                      ELSE RotateLeft(max(1,(WorkBreite DIV zoom) SHR 2));
   EventRotateRight: IF Shift
                      THEN RotateRight(1)
                      ELSE RotateRight(max(1,(WorkBreite DIV zoom) SHR 2));
   EventRotateUp   : IF Shift
                      THEN RotateUp(1)
                      ELSE RotateUp(max(1,(WorkBreite DIV zoom) SHR 2));
   EventRotateDown : IF Shift
                      THEN RotateDown(1)
                      ELSE RotateDown(max(1,(WorkBreite DIV zoom) SHR 2));
   EventMirrorHorizontal: MirrorHorizontal;
   EventMirrorVertical  : MirrorVertical;
   EventObenLinks  : IF Shift
                      THEN GotoUpLeft {mit Shift: gehe in die linke obere Ecke}
                      ELSE ObenLinks; {ohne: verschiebe Inhalt in li. ob. Ecke}

   EventToolPixel,
   EventToolLine,
   EventToolRectangle,
   EventToolEllipse,
   EventToolBar,
   EventToolDisc,
   EventToolFill,
   EventToolCopy: SelectNewTool;

   EventEraseWorkarea: BEGIN {Bei "Lîschen" lieber nochmal rÅckfragen}
                        ErrBeep;
                        IF FirstOfTwoBoxes(MeldungX,MeldungY,
                                           MeldungX+220,MeldungY+60,
                                           'yes','no',
                                           'DO YOU REALLY WANT',
                                           'TO ERASE THE WORKAREA?','',
                                           alternative)
                         THEN BEGIN
                               FillChar(WorkArea^,SizeOf(WorkArea^),transparent);
                               WorkAreaMaxUsedX:=0; WorkAreaMaxUsedY:=0;
                               UpdateWorkArea(StartVirtualX,StartVirtualY,
                                              WorkAreaMaxUsedX,WorkAreaMaxUsedY,TRUE);
                               DrawNewObject; {evtl. Objekt neuzeichnen}
                              END;
                        Event:=EventMouseMoved;
                       END;


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
         IF NOT InWorkArea
          THEN BEGIN {evtentuelle Cursordaten vom Bildschirm lîschen}
                SetFillStyle(SolidFill,BestBlack);
                Bar(InfoX,InfoY,InfoX+80,InfoY+29);
               END;

         IF (InWorkArea) AND (zoom=1)
          THEN DrawMaus(CursorKreuz)
          ELSE DrawMaus(CursorPfeil);

         ClearMouse; {Mausereignis abgearbeitet}
        END;

  IF Event<>EventEndProgram THEN Event:=EventNone;
 until Event=EventEndProgram; {Ende = F10 + BestÑtigung}

 SetPalette(DefaultColors);
 restorecrtmode;
 SwapVectors;

 regs.ax := 12;
 regs.cx := 0;
 intr($33,regs); {Mousecallback de-installieren}

END.

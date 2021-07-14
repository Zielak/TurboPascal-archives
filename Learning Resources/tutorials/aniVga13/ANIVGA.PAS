{$A+,B-,D+,L+,N-,E-,O-,R-,S-,V-,G-,F-,I-,X-}
{$M 16384,0,655360}
{$UNDEF IOcheck}

{Programmtool zur Realisierung schneller Animationen auf der VGA-Grafik-    }
{karte von: Kai Rohrbacher, 1988-1993, Turbo-Pascal 6.0                     }

{ Features:                                                                 }

{ - flickerfreie Animation durch page-flipping, Auswertung von Retrace-     }
{   signalen und Verwendung eines speziellen VGA-256-Farbengrafikmodus      }
{ - Spritebewegung pixelweise (und nicht nur byteweise) mîglich             }
{ - beliebiges Hintergrundbild, vor der die Animation geschieht             }
{ - Animationen kînnen auf ein Bildschirmfenster begrenzt werden            }
{ - volle UnterstÅtzung der 256-Farbmîglichkeiten der VGA-Karte             }
{ - verschiedene Spritedarstellungsmîglichkeiten:                           }
{   - Sprites kînnen pixelweise als durchsichtig gegenÅber dem Hintergrund  }
{     deklariert werden                                                     }
{   - Sprites kînnen ihre Farbe in AbhÑngigkeit ihres momentanen Hinter-    }
{     grundes verÑndern ("Schattenfunktion")                                }
{ - Routine zur exakten Feststellung der Kollision zweier Sprites           }
{ - Sprites werden beim Verschwinden an einer der Bildschirmgrenzen korrekt }
{   abgeschnitten                                                           }
{ - Verwaltung von bis zu 32767 verschiedenen Sprites (Voreinstellung: 1000)}
{ - gleichzeitige Darstellung von bis zu 32767 Sprites (Voreinstellung: 500)}
{ - maximale Spritegrî·e 64k                                                }
{ - maximaler Umfang aller Sprites zusammen nur durch Hauptspeicher begrenzt}
{ - arbeitet mit virtuellen Koordinaten im Bereich -16000..+16000, daher    }
{   einfaches horizontales und vertikales Scrolling mîglich                 }
{ - Scrollbares Hintergrundbild ebenfalls unterstÅtzt                       }
{ - EinschrÑnkung der Animation auf ein Window ist mîglich                  }
{ - viele unterstÅtzende Routinen: zeichnen von Linien (mit eingebautem     }
{   Clipping-Algorithmus), Punkten und Grafik-Text (dto.), automatische Ver-}
{   waltungs des Heaps zum Speichern/Laden von Sprites, Hintergrundbildern, }
{   éndern von Spritedarstellungsmodi wÑhrend der Laufzeit, Geschwindig-    }
{   keitsanpassung an unterschiedlich schnelle Rechner, ...                 }

UNIT ANIVGA;
INTERFACE

USES CRT,DOS,Compression;

CONST ANIVGAVersion=12; {Versionsnummer}
      NMAX=499;
      XMAX=319;
      YMAX=199;
      LoadMAX=1000;  {max. Anzahl an gleichzeitig geladenenen Sprites}
      LINESIZE=(XMAX+1) DIV 4;    {Grî·e einer Zeile = 80 Bytes}
      PAGESIZE=(YMAX+1)*LINESIZE; {200 Zeilen zu je 320/4 Bytes}
      BACKGNDPAGE=2;
      SCROLLPAGE=3;

      STATIC=0;      {Konstanten fÅr Hintergrundart}
      SCROLLING=1;

      MaxTiles=10000;   {max. Anzahl an Hintergrund-Kacheln}
      StartVirtualX:INTEGER=0;  {obere linke Bildschirmecke}
      StartVirtualY:INTEGER=0;

      {unterstÅtzte Darstellungsmodi der Sprites: }
      Display_NORMAL=0;   {normal  : durchsichtig fÅr Farbe 0}
      Display_FAST  =1;   {schnell : keine HintergrundberÅcksichtigung}
      Display_SHADOW=2;   {Schatten: Farbumsetzung anhand des Hintergrundes}
      Display_SHADOWEXACT=3; {Farbe 0 ist auch fÅr Schatten durchsichtig}
      Display_UNKNOWN=255;{Fehlerwert}

      {Fehlercodes des Animationspaketes: }
      Err_None=0;
      Err_NotEnoughMemory=1;
      Err_FileIO=2;
      Err_InvalidSpriteNumber=3;
      Err_NoSprite=4;
      Err_InvalidPageNumber=5;
      Err_NoVGA=6;
      Err_NoPicture=7;
      Err_InvalidPercentage=8;
      Err_NoTile=9;
      Err_InvalidTileNumber=10;
      Err_InvalidCoordinates=11;
      Err_BackgroundToBig=12;
      Err_InvalidMode=13;
      Err_InvalidSpriteLoadNumber=14;
      Err_NoPalette=15;
      Err_PaletteWontFit=16;
      Err_InvalidFade=17;
      Err_NoFont=18;
      Err_EMSError=19;

CONST MaxFontHeight=16;
      MaxFontWidth=15;
      TagMonoFont=0;
      TagColorFont=1;
      TagProportional=$80;
TYPE  MonoFontChar=ARRAY[0..MaxFontHeight-1] OF WORD;
      MonoFont=ARRAY[0..255] OF MonoFontchar;
      ColorFontChar=ARRAY[0..MaxFontHeight-1] OF ARRAY[0..MaxFontWidth-1] OF BYTE;
      ColorFont=ARRAY[0..255] OF ColorFontchar;
      FontOrient=(horizontal,vertical);    {mîgliche Textausgaberichtungen}
CONST GraphTextOrientation:FontOrient=horizontal; {aktuelle Ausgaberichtung}
      GraphTextColor:BYTE=white;           {aktuelle Textausgabefarben}
      GraphTextBackground:BYTE=white;
      CurrentFont:POINTER=NIL;             {Zeiger auf aktuellen Font}
      UpdateOuterArea:BYTE=2;              {Ñu·eren Hintergrund updaten}
      WinClip:BOOLEAN=FALSE;               {Pixel auf Fenster clippen?}
VAR   FontHeight,
      FontWidth,
      FontType,
      FontProportion:BYTE;
      FontWidthTable:ARRAY[0..255] OF BYTE;

TYPE Table=ARRAY[0..NMAX] OF INTEGER;
     ColorTable=ARRAY[0..255] OF BYTE;

TYPE PaletteEntry=RECORD red,green,blue:BYTE END;
     Palette=ARRAY[0..255] OF PaletteEntry;
     PalettePtr=^Palette;

CONST DefaultColors:Palette=       {Defaultfarben-Palette des 256-Farbmodus}
 (                                 {ausgelesen mithilfe des BIOS-Aufrufs:  }
  (red:  0; green:  0; blue:  0),  { MOV AX,1017h ;lese Palettenregister}
  (red:  0; green:  0; blue: 42),  { XOR BX,BX    ;von Farbe 0 an }
  (red:  0; green: 42; blue:  0),  { MOV CX,100h  ;alle 256 Farben}
  (red:  0; green: 42; blue: 42),  { LES DX,Ziel  ;nach ES:DX }
  (red: 42; green:  0; blue:  0),  { INT 10h }
  (red: 42; green:  0; blue: 42),  {Achtung! Die Werte kînn(t)en nur dann  }
  (red: 42; green: 21; blue:  0),  {ausgelesen werden, wenn der Grafikmodus}
  (red: 42; green: 42; blue: 42),  {bereits aktiv ist, deshalb wurden sie  }
  (red: 21; green: 21; blue: 21),  {hier "statisch" aufgenommen!}
  (red: 21; green: 21; blue: 63),
  (red: 21; green: 63; blue: 21),
  (red: 21; green: 63; blue: 63),
  (red: 63; green: 21; blue: 21),
  (red: 63; green: 21; blue: 63),
  (red: 63; green: 63; blue: 21),
  (red: 63; green: 63; blue: 63),
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

VAR Error:BYTE; {globale Fehlervariable}
    SpriteN:Table;
    SpriteX:Table;
    SpriteY:Table;
    NextSprite:ARRAY[0..LoadMAX] OF WORD;
    PAGE,PAGEADR,SCROLLADR,BACKGNDADR:WORD;
    Color:BYTE;           {Zeichenfarbe fÅr Linien}
    ActualColors:Palette; {aktuelle Farbpalette}
    was_cut:BOOLEAN;      {TRUE/FALSE, falls "GetImage" clippen mu·te   }
    left_cut,             {Var., die durch "GetImage" gesetzt werden und}
    right_cut,            {bei "was_cut"=TRUE darÅber Auskunft geben,   }
    top_cut,              {wo und wieviel des Bildes abgeschnitten      }
    bottom_cut:WORD;      {werden mu·te                                 }

    WinXMIN,WinYMIN,WinXMAX,WinYMAX,WinWidth,WinHeight:WORD;

    BackgroundMode:BYTE;
    BackTile:ARRAY[0..MaxTiles] OF BYTE;    {Kachelnspeicher}
    XTiles,YTiles:INTEGER;                  {Breite,Hîhe des def. Bereiches }
    BackX1,BackY1,BackX2,BackY2:INTEGER;    {Koordinaten des def. Bereiches }

CONST   Fade_Squares =0;
        Fade_Moiree1 =1;
        Fade_Moiree2 =2;
        Fade_Moiree3 =3;
        Fade_Moiree4 =4;
        Fade_Moiree5 =5;
        Fade_Moiree6 =6;
        Fade_Moiree7 =7;
        Fade_Moiree8 =8;
        Fade_Moiree9 =9;
        Fade_Moiree10=10;
        Fade_Moiree11=11;
        Fade_Moiree12=12;
        Fade_Moiree13=13;
        Fade_Moiree14=14;
        Fade_SweepInFromTop=15;
        Fade_SweepInFromBottom=16;
        Fade_SweepInFromLeft=17;
        Fade_SweepInFromRight=18;
        Fade_ScrollInFromTop=19;
        Fade_ScrollInFromBottom=20;
        Fade_ScrollInFromLeft=21;
        Fade_ScrollInFromRight=22;
        Fade_Circles =23;
        Fade_Moiree15=24;

{---- fÅr EMS-Routinen ----}

CONST BACKTAB:ARRAY[0..3] OF WORD=(0,PAGESIZE,2*PAGESIZE,3*PAGESIZE);
TYPE Puffer=ARRAY[0..4*PAGESIZE-1 +15] OF BYTE; {Puffer fÅr eine Seite}
VAR  buf:^Puffer; {Zeiger darauf}

Const EMSInt = $67;   {fÅr EMS benutzter Interrupt}
      USEEMS = TRUE;  {bei FALSE: keine Nutzung von vorhandenem EMS,}
                      {bei TRUE : Nutzung, wenn vorhanden}

Var EMSError:BYTE;    {<>0 hei·t: es trat ein Fehler auf }
    BackgroundEMSHandle:WORD;   {Zugriffshandle auf allozierten EMS-Block}
    EMSused:BOOLEAN;  {zeigt an, ob tatsÑchlich EMS verwendet wird}

 PROCEDURE ShadowTab;
 PROCEDURE SetShadowTab(brightness:BYTE);
 PROCEDURE SetPalette(pal:Palette; update:BOOLEAN);
 PROCEDURE GetPalette(VAR pal:Palette);
 PROCEDURE FadeToPalette(destPal:Palette; AnzSteps:WORD);
 FUNCTION LoadPalette(name:String; number:BYTE; VAR pal:Palette):WORD;
 PROCEDURE EnsureEMSConsistency(EMSHandle:WORD);
 PROCEDURE SetCycleTime(milliseconds:WORD);
 PROCEDURE SetSpriteCycle(nr,len:WORD);
 FUNCTION GetImage(x1,y1,x2,y2:INTEGER; pa:WORD):POINTER;
 PROCEDURE PutImage(x,y:INTEGER; p:POINTER; pa:WORD);
 PROCEDURE FreeImageMem(p:POINTER);
 PROCEDURE InitGraph;
 PROCEDURE Screen(pa:WORD);
 PROCEDURE Line(x1,y1,x2,y2:INTEGER; pa:WORD);
 PROCEDURE BackgroundLine(x1,y1,x2,y2:INTEGER);
 FUNCTION GetPixel(x,y:INTEGER):BYTE;
 FUNCTION BackgroundGetPixel(x,y:INTEGER):BYTE;
 FUNCTION PageGetPixel(x,y:INTEGER; pa:WORD):BYTE;
 PROCEDURE PutPixel(x,y:INTEGER; color:Byte);
 PROCEDURE BackgroundPutPixel(x,y:INTEGER; color:Byte);
 PROCEDURE PagePutPixel(x,y:INTEGER; color:BYTE; pa:WORD);
 PROCEDURE LoadFont(s:STRING);
 FUNCTION OutTextLength(s:STRING):WORD;
 PROCEDURE OutTextXY(x,y:INTEGER; pa:WORD; s:STRING);
 PROCEDURE BackgroundOutTextXY(x,y:INTEGER; s:STRING);
 PROCEDURE MakeTextSprite(s:STRING; nr:WORD);
 FUNCTION Hitdetect(s1,s2:INTEGER):BOOLEAN;
 PROCEDURE SetSplitIndex(number:INTEGER);
 FUNCTION GetSplitIndex:INTEGER;
 PROCEDURE SetAnimateWindow(x1,y1,x2,y2:INTEGER);
 PROCEDURE Animate;
 PROCEDURE FreeSpriteMem(number:WORD);
 FUNCTION LoadSprite(name:String; number:WORD):WORD;
 FUNCTION LoadTile(name:STRING; number:BYTE):WORD;
 PROCEDURE SetBackgroundScrollRange(x1,y1,x2,y2:INTEGER);
 PROCEDURE SetBackgroundMode(mode:BYTE);
 PROCEDURE MakeTileArea(FirstTile:BYTE; TileWidth,TileHeight:INTEGER);
 PROCEDURE PutTile(x,y:INTEGER; TileNr:BYTE);
 FUNCTION GetTile(x,y:INTEGER):BYTE;
 PROCEDURE SetOffscreenTile(TileNr:BYTE);
 PROCEDURE SetModeByte(Sp:WORD; M:BYTE);
 FUNCTION GetModeByte(Sp:WORD):BYTE;
 PROCEDURE FillPage(pa:WORD; color:Byte);
 PROCEDURE FillBackground(color:BYTE);
 PROCEDURE GetBackgroundFromPage(pa:WORD);
 PROCEDURE WritePage(name:STRING; pa:WORD);
 PROCEDURE LoadPage(name:STRING; pa:WORD);
 PROCEDURE WriteBackgroundPage(name:STRING);
 PROCEDURE LoadBackgroundPage(name:STRING);
 PROCEDURE FadeIn(pa,ti,style:WORD);
 PROCEDURE CopyVRAMtoVRAM(source,dest:POINTER; len:WORD);
 PROCEDURE IntroScroll(n,wait:WORD);
 PROCEDURE InitRoutines;
 PROCEDURE CloseRoutines;
 FUNCTION GetErrorMessage:STRING;
 FUNCTION FindFile(P:PathStr):PathStr;

{--------------------------------------------------------------------------}

IMPLEMENTATION

CONST ANIVGAVersionS:STRING[11]='AniVGA V1.2'; {Versionsnummer}
      StartIndex=0;
      EndIndex=StartIndex+3;
      {Offsetadressen der Grafikseiten (in Segment $A000):}
      Offset_Adr:Array[StartIndex..EndIndex] OF WORD=($0000,$3E80,$7D00,$BB80);
      {Segmentadressen der Grafikseiten (bei Offset = 0) :}
      Segment_Adr:ARRAY[StartIndex..EndIndex] OF WORD=($A000,$A3E8,$A7D0,$ABB8);

      {Sprite(header)aufbau:  }

      {0..1   DW Plane_0_Daten}
      {2..3   DW Plane_1_Daten}
      {4..5   DW Plane_2_Daten}
      {6..7   DW Plane_3_Daten}
      {8..9   DW Breite (in 4er-Gruppen)}
      {10..11 DW Hîhe in Zeilen}
      {12..15 DB 1,2,4,8      ; Translate-Tabelle fÅr Port-Ansteuerung}
      {16..17 DW SpriteLength ; LÑnge der Spritedatei}
      {                       ; jetzt fÅr temporÑre Variablen reservierter}
      {                       ; Bereich:}
      {18..19 DW ?            ; licutoff_      | hit1xfirst}
      {20..21 DW ?            ; zeilenadr      | hit1yfirst}
      {22..23 DW ?            ; bildx          | hit2xfirst}
      {24..25 DW ?            ; yoffset_       | hit2yfirst}
      {26..27 DW ?            ; end_min_start  | ueberlappx_1}
      {28..29 DW ?            ; WinXMIN_       | ueberlappy_1}
      {30..31 DW ?            ; WinXMAX_       | x1}
      {32..33 DW ?            ; WinYMIN_       | x2}
      {34..35 DW ?            ;                | y1}
      {36..37 DW ?            ;                | y2}
      {38..39 DB 'K','R'      ; Kennung als Sprite}
      {40     DB 1            ; Versionsnummer}
      {41     DB 0            ; Modusnummer fÅr Sprite}
      {42..43 DW linke_Begrenzungen }
      {44..45 DW rechte_Begrenzungen}
      {46..47 DW obere_Begrenzungen }
      {48..49 DW untere_Begrenzungen}
      {50..?? DB Daten}

      {zum Bsp.:  xxrxxxxx, mit: r=rot=40, g=grÅn=45, b=blau=35, x=wei·=30}
      {           xrgrxxxx}
      {           rbgbrxxx}

      {Adressen von wichtigen Werten innerhalb des Spriteheaders:}
      Left=42;
      Right=44;
      Top=46;
      Bottom=48;
      Breite=8;
      Hoehe=10;
      Translate=12;
      SpriteLength=16;
      Kennung=38;
      Version=40;
      Modus=41;

      {Adressen der temporÑren Variablen fÅr die Zeichenroutinen:}
      licutoff_=18;
      zeilenadr=20;
      bildx=22;
      yoffset_=24;
      end_min_start=26;
      WinXMIN_=28;
      WinXMAX_=30;
      WinYMIN_=32;

      {Adressen der temporÑren Variablen fÅr die KollisionsprÅfroutine:}
      hit1xfirst=18;
      hit1yfirst=20;
      hit2xfirst=22;
      hit2yfirst=24;
      ueberlappx_1=26;
      ueberlappy_1=28;
      x1=30;
      x2=32;
      y1=34;
      y2=36;

      TranslateTab:ARRAY[0..3] OF BYTE=(1,2,4,8); {FÅr Maskenadressierung}
      PICHeader:STRING[3]='PIC'; {Kennung in Bilderdateien}
      Schatten :BYTE=70;         {Default-Helligkeit von Schatten}

TYPE SpriteHeader= RECORD
                    Zeiger_auf_Plane:Array[0..3] OF Word;
                    Breite_in_4er_Gruppen:WORD;
                    Hoehe_in_Zeilen:WORD;
                    Translate:Array[1..4] OF Byte;
                    SpriteLength:WORD;
                    Dummy:Array[1..10] OF Word;
                    Kennung:ARRAY[1..2] OF CHAR;
                    Version:BYTE;
                    Modus:BYTE;
                    ZeigerL,ZeigerR,ZeigerO,ZeigerU:Word;
                   END;

CONST Kopf=SizeOf(SpriteHeader);
      FontMask:ARRAY[0..MaxFontWidth-1] OF WORD=
       ($4000,$2000,$1000,$800,$400,$200,$100,$80,$40,$20,$10,8,4,2,1);
      internalFont:ARRAY[0..255,0..5] OF BYTE= {verwendeter Zeichensatz:  }
     ((  0,  0,  0,  0,  0,  0), {#0}          {selbstgestrickter 6x6 Font}
      (  0, 54,  0, 62, 28,  0), {#1}
      ( 62, 42, 62, 34, 54, 62), {#2}
      (  0, 20, 62, 62, 28,  8), {#3}
      (  0,  8, 28, 62, 28,  8), {#4}
      (  8, 28, 54, 62,  8, 28), {#5}
      (  8, 28, 62, 62,  8, 28), {#6}
      (  0,  8, 54, 54,  8,  0), {#7}
      ( 62, 54, 42, 42, 54, 62), {#8}
      (  0, 28, 50, 38, 28,  0), {#9}
      ( 62, 34, 42, 42, 34, 62), {#10}
      ( 14,  6,  8, 28, 34, 28), {#11}
      ( 28, 34, 28,  8, 62,  8), {#12}
      ( 14, 10,  8,  8, 56, 56), {#13}
      (  0, 30, 18, 30, 18, 54), {#14}
      (  0,  8, 42, 20, 42,  8), {#15}
      (  0, 32, 56, 62, 56, 32), {#16}
      (  0,  2, 14, 62, 14,  2), {#17}
      (  8, 28, 42, 42, 28,  8), {#18}
      (  0, 54, 54, 54,  0, 54), {#19}
      (  0, 30, 42, 26, 10, 10), {#20}
      (  6,  8,  4, 10, 36, 24), {#21}
      (  0,  0,  0,  0, 62, 62), {#22}
      (  8, 28,  8, 28,  8, 62), {#23}
      (  0,  8, 28, 62,  8,  8), {#24}
      (  0,  8,  8, 62, 28,  8), {#25}
      (  0,  8,  4, 62,  4,  8), {#26}
      (  0,  8, 16, 62, 16,  8), {#27}
      (  0,  0, 48, 62,  0,  0), {#28}
      (  0,  0, 20, 62, 20,  0), {#29}
      (  0,  0,  0,  8, 28, 62), {#30}
      (  0,  0, 62, 28,  8,  0), {#31}
      (  0,  0,  0,  0,  0,  0), { }
      (  0, 12, 12, 12,  0, 12), {!}
      (  0, 20, 20,  0,  0,  0), {"}
      (  0, 20, 62, 20, 62, 20), {#}
      (  8, 30, 40, 28, 10, 60), { $}
      (  0, 50,  4,  8, 16, 38), {%}
      (  0, 28, 54, 28, 38, 26), {&}
      (  0,  4,  8,  0,  0,  0), {'}
      (  0, 28, 48, 48, 48, 28), {(}
      (  0, 56, 12, 12, 12, 56), {)}
      (  0, 20,  8, 62,  8, 20), {*}
      (  0,  0,  8, 62,  8,  0), {+}
      (  0,  0,  0,  8,  8, 16), {,}
      (  0,  0,  0, 62,  0,  0), {-}
      (  0,  0,  0,  0, 12,  0), {.}
      (  1,  2,  4,  8, 16, 32), {/}
      (  0, 28, 38, 42, 50, 28), {0}
      (  0, 12, 28, 12, 12, 30), {1}
      (  0, 60,  6, 28, 48, 62), {2}
      (  0, 60,  6, 28,  6, 60), {3}
      (  0, 48, 52, 62, 12, 12), {4}
      (  0, 62, 48, 60,  6, 60), {5}
      (  0, 62, 32, 62, 34, 62), {6}
      (  0, 62,  6, 12, 24, 24), {7}
      (  0, 28, 54, 28, 54, 28), {8}
      (  0, 28, 34, 30,  2, 28), {9}
      (  0,  0,  8,  0,  8,  0), {:}
      (  0,  0,  8,  0,  8, 16), {;}
      (  0,  6, 12, 24, 12,  6), {<}
      (  0,  0, 62,  0, 62,  0), {=}
      (  0, 24, 12,  6, 12, 24), {>}
      ( 28, 34,  4,  8,  0,  8), {?}
      (  0, 28, 34, 46, 32, 30), {@}
      (  0, 28, 50, 62, 50, 50), {A}
      (  0, 60, 50, 60, 50, 60), {B}
      (  0, 30, 48, 48, 48, 30), {C}
      (  0, 60, 54, 50, 54, 60), {D}
      (  0, 62, 48, 60, 48, 62), {E}
      (  0, 62, 48, 60, 48, 48), {F}
      (  0, 30, 48, 54, 50, 30), {G}
      (  0, 50, 50, 62, 50, 50), {H}
      (  0, 30, 12, 12, 12, 30), {I}
      (  0, 62,  2,  2, 50, 28), {J}
      (  0, 50, 52, 56, 52, 50), {K}
      (  0, 48, 48, 48, 48, 62), {L}
      (  0, 34, 54, 42, 34, 34), {M}
      (  0, 34, 50, 42, 38, 34), {N}
      (  0, 28, 50, 50, 50, 28), {O}
      (  0, 60, 50, 60, 48, 48), {P}
      (  0, 24, 52, 52, 52, 26), {Q}
      (  0, 60, 34, 60, 52, 50), {R}
      (  0, 62, 48, 62,  6, 62), {S}
      (  0, 62, 24, 24, 24, 24), {T}
      (  0, 50, 50, 50, 50, 62), {U}
      (  0, 50, 50, 50, 50, 12), {V}
      (  0, 34, 34, 42, 62, 20), {W}
      (  0, 34, 54, 28, 54, 34), {X}
      (  0, 50, 50, 28, 12, 12), {Y}
      (  0, 62,  6, 28, 48, 62), {Z}
      (  0, 30, 24, 24, 24, 30), {[}
      ( 32, 16,  8,  4,  2,  1), {\}
      (  0, 30,  6,  6,  6, 30), {]}
      (  8, 20, 34,  0,  0,  0), {^}
      (  0,  0,  0,  0,  0, 62), {_}
      ( 16,  8,  0,  0,  0,  0), {`}
      (  0,  0, 28, 50, 50, 30), {a}
      (  0, 32, 60, 34, 34, 60), {b}
      (  0,  0, 30, 48, 48, 30), {c}
      (  0,  2, 30, 34, 34, 30), {d}
      (  0,  0, 28, 62, 32, 28), {e}
      (  0,  6,  8, 30,  8,  8), {f}
      (  0, 28, 34, 30,  2, 28), {g}
      (  0, 48, 60, 50, 50, 50), {h}
      ( 12,  0, 12, 12, 12, 12), {i}
      (  6,  0,  6,  6, 54, 28), {j}
      (  0, 48, 52, 56, 54, 54), {k}
      (  0, 24, 24, 24, 24, 14), {l}
      (  0,  0, 52, 62, 42, 34), {m}
      (  0,  0, 60, 50, 50, 50), {n}
      (  0,  0, 28, 50, 50, 28), {o}
      (  0,  0, 60, 50, 60, 48), {p}
      (  0,  0, 28, 38, 30,  6), {q}
      (  0,  0, 44, 26, 24, 24), {r}
      (  0, 14, 16, 12, 34, 28), {s}
      (  0, 24, 62, 24, 26, 12), {t}
      (  0,  0, 50, 50, 50, 30), {u}
      (  0,  0, 50, 50, 50, 28), {v}
      (  0,  0, 34, 42, 42, 28), {w}
      (  0,  0, 54, 24, 12, 54), {x}
      (  0,  0, 50, 62,  2, 28), {y}
      (  0,  0, 60, 12, 48, 62), {z}
      (  0, 14, 24, 48, 24, 14),(*{*)
      (  0,  4,  4,  0,  4,  4), {|}
      (  0, 56, 12,  6, 12, 56),(*}*)
      (  0, 26, 36,  0,  0,  0), {~}
      (  0,  8, 20, 34, 62,  0), {#127}
      ( 28, 50, 32, 50, 28, 48), {#128}
      (  0, 50,  0, 50, 50, 30), {#129}
      (  6,  8, 28, 62, 32, 28), {#130}
      (  4, 10,  0, 30, 49, 31), {#131}
      ( 26,  0, 28, 50, 50, 30), {#132}
      ( 12,  2, 28, 34, 34, 30), {#133}
      (  4, 10,  4, 28, 50, 30), {#134}
      (  0, 30, 48, 30,  4, 24), {#135}
      ( 28,  0, 28, 62, 48, 28), {#136}
      ( 20,  0, 28, 62, 32, 28), {#137}
      ( 12,  2, 28, 62, 48, 28), {#138}
      ( 26,  0, 12, 12, 12, 12), {#139}
      ( 12, 18,  0, 12, 12, 12), {#140}
      ( 24,  4,  0, 12, 12, 12), {#141}
      ( 50,  0, 28, 50, 62, 50), {#142}
      ( 12,  0, 28, 50, 62, 50), {#143}
      ( 28, 62, 48, 60, 48, 62), {#144}
      (  0, 52, 10, 28, 40, 22), {#145}
      (  0, 14, 20, 62, 36, 38), {#146}
      (  8, 20,  0, 28, 50, 28), {#147}
      ( 20,  0, 28, 50, 50, 28), {#148}
      ( 24,  4,  0, 28, 50, 28), {#149}
      (  8, 20,  0, 50, 50, 30), {#150}
      ( 24,  4,  0, 50, 50, 30), {#151}
      ( 20,  0, 50, 62,  2, 28), {#152}
      ( 20,  0, 28, 50, 50, 28), {#153}
      ( 50,  0, 50, 50, 50, 62), {#154}
      (  4, 30, 32, 32, 30,  4), {#155}
      ( 12, 18, 56, 16, 34, 62), {#156}
      ( 54,  8, 62,  8, 62,  8), {#157}
      ( 48, 40, 52, 46, 36, 38), {#158}
      ( 12, 10, 24, 12, 40, 24), {#159}
      ( 12, 16,  0, 28, 34, 30), {#160}
      ( 12, 16,  0,  8,  8,  8), {#161}
      ( 12, 16,  0, 28, 50, 28), {#162}
      ( 12, 16,  0, 50, 50, 30), {#163}
      ( 26, 36,  0, 44, 18, 18), {#164}
      ( 26, 36,  0, 50, 42, 38), {#165}
      ( 28, 36, 26,  0, 62,  0), {#166}
      ( 28, 34, 28,  0, 62,  0), {#167}
      (  8,  0,  8, 16, 34, 28), {#168}
      (  0,  0, 63, 48,  0,  0), {#169}
      (  0,  0, 63,  3,  0,  0), {#170}
      ( 18, 20,  8, 16, 42, 10), {#171}
      ( 18, 20,  8, 20, 38,  2), {#172}
      ( 12,  0, 12, 12, 12,  0), {#173}
      ( 10, 20, 40, 20, 10,  0), {#174}
      ( 40, 20, 10, 20, 40,  0), {#175}
      ( 21, 42, 21, 42, 21, 42), {#176}
      ( 63, 63, 63, 63, 63, 63), {#177}
      ( 42, 21, 42, 21, 42, 21), {#178}
      (  4,  4,  4,  4,  4,  4), {#179}
      (  4,  4,  4, 60,  4,  4), {#180}
      (  4,  4, 60,  4, 60,  4), {#181}
      ( 10, 10, 10, 58, 10, 10), {#182}
      (  0,  0,  0, 62, 10, 10), {#183}
      (  0,  0, 60,  4, 60,  4), {#184}
      ( 10, 10, 58,  2, 58, 10), {#185}
      ( 10, 10, 10, 10, 10, 10), {#186}
      (  0,  0, 62,  2, 58, 10), {#187}
      ( 10, 10, 58,  2, 62,  0), {#188}
      ( 10, 10, 10, 62,  0,  0), {#189}
      (  4,  4, 60,  4, 60,  0), {#190}
      (  0,  0,  0, 60,  4,  4), {#191}
      (  4,  4,  4,  7,  0,  0), {#192}
      (  4,  4,  4, 63,  0,  0), {#193}
      (  0,  0,  0, 63,  4,  4), {#194}
      (  4,  4,  4,  7,  4,  4), {#195}
      (  0,  0,  0, 63,  0,  0), {#196}
      (  4,  4,  4, 63,  4,  4), {#197}
      (  4,  4,  7,  4,  7,  4), {#198}
      ( 10, 10, 10, 11, 10, 10), {#199}
      ( 10, 10, 11,  8, 15,  0), {#200}
      (  0,  0, 15,  8, 11, 10), {#201}
      ( 10, 10, 59,  0, 63,  0), {#202}
      (  0,  0, 63,  0, 59, 10), {#203}
      ( 10, 10, 11,  8, 11, 10), {#204}
      (  0,  0, 63,  0, 63,  0), {#205}
      ( 10, 10, 59,  0, 59, 10), {#206}
      (  4,  4, 63,  0, 63,  0), {#207}
      ( 10, 10, 10, 63,  0,  0), {#208}
      (  0,  0, 63,  0, 63,  4), {#209}
      (  0,  0,  0, 63, 10, 10), {#210}
      ( 10, 10, 10, 15,  0,  0), {#211}
      (  4,  4,  7,  4,  7,  0), {#212}
      (  0,  0,  7,  4,  7,  4), {#213}
      (  0,  0,  0, 15, 10, 10), {#214}
      ( 10, 10, 10, 63, 10, 10), {#215}
      (  4,  4, 63,  4, 63,  4), {#216}
      (  4,  4,  4, 60,  0,  0), {#217}
      (  0,  0,  7,  4,  4,  4), {#218}
      ( 63, 63, 63, 63, 63, 63), {#219}
      (  0,  0,  0, 63, 63, 63), {#220}
      ( 48, 48, 48, 48, 48, 48), {#221}
      (  3,  3,  3,  3,  3,  3), {#222}
      ( 63, 63, 63,  0,  0,  0), {#223}
      (  0,  0, 26, 36, 36, 26), {#224}
      (  0, 28, 38, 44, 34, 44), {#225}
      (  0, 62, 34, 32, 32, 32), {#226}
      (  0,  0, 62, 20, 20, 20), {#227}
      ( 62, 18,  8, 16, 34, 62), {#228}
      (  0,  0, 30, 36, 36, 24), {#229}
      (  0, 18, 18, 30, 16, 48), {#230}
      (  0,  0, 26, 44,  8,  8), {#231}
      (  0, 62,  8, 20,  8, 62), {#232}
      (  0, 28, 34, 62, 34, 28), {#233}
      (  0, 28, 34, 34, 20, 54), {#234}
      ( 14, 16,  8, 28, 34, 28), {#235}
      (  0,  0, 20, 42, 20,  0), {#236}
      (  0,  2, 20, 42, 20, 32), {#237}
      (  0, 30, 32, 62, 32, 30), {#238}
      (  0,  0, 28, 34, 34, 34), {#239}
      (  0, 62,  0, 62,  0, 62), {#240}
      (  0,  8, 28,  8,  0, 62), {#241}
      ( 16,  8,  4,  8, 16, 62), {#242}
      (  4,  8, 16,  8,  4, 62), {#243}
      (  4, 10,  8,  8,  8,  8), {#244}
      (  8,  8,  8,  8, 40, 16), {#245}
      (  0,  8,  0, 62,  0,  8), {#246}
      ( 26, 36,  0, 26, 36,  0), {#247}
      ( 24, 36, 24,  0,  0,  0), {#248}
      (  0,  0,  0, 12,  0,  0), {#249}
      (  0,  0,  0,  4,  0,  0), {#250}
      ( 15,  8,  8, 40, 24,  8), {#251}
      ( 44, 18, 18,  0,  0,  0), {#252}
      ( 56,  4, 24, 32, 60,  0), {#253}
      (  0,  0, 28, 28,  0,  0), {#254}
      (  0,  0,  0,  0,  0,  0));{#255}

VAR Steigung:BYTE;        {entscheidet, welcher Alg. Anwendung findet}
    DY_mal2,DY_m_DX_mal2:INTEGER;
    oldMode:byte;
    regs:registers;

    IsAT:BYTE;
    TimeFlag:BYTE;
    CycleTime:LONGINT;

    SPRITEAD  :ARRAY[0..LoadMAX] OF WORD;     {normalisierte Segmentadressen}
    SPRITEPTR :ARRAY[0..LoadMAX] OF POINTER;  {vollstÑndige 32-Bit-Zeiger   }
    SPRITESIZE:ARRAY[0..LoadMAX] OF WORD;     {allozierte Spritegrî·e}

    CRTAddress, StatusReg : WORD;

    WinLowerRight,WinXMINdiv4,WinYMIN_mul_LINESIZE,
    WinYMINmLINESIZEaWinXMINdiv4:WORD;
    WinWidthDiv4:BYTE;
    BWinXMIN,BWinYMIN,BWinXMAX,BWinYMAX,BWinLowerRight,
    BWinYMIN_mul_LINESIZE:WORD; {Backups von Win* Variablen}

    SplitIndex,SplitIndex_mal2:INTEGER; {Splitpunkt fÅr Sprites & Clipping}


{-----------------------------------------------------}

PROCEDURE ShadowTab; ASSEMBLER;
{Pseudoprozedur, um Daten der Farbumsetztabelle im Codesegment }
{unterzubringen, AUF KEINEN FALL AUFRUFEN!!!                   }
{Defaultwerte entsprechen Abdunkelung auf 70% des Farb-Helligkeitswerts}
ASM
   DB 254,104,120,124,112,108,114, 24, 20,128,144,  3,136,  5,140,  7
   DB 254,254, 17, 17, 18, 19, 20, 20, 21,  8, 23, 24, 24, 25, 26,  7
   DB   1,  1,107,108,  5,108,109,  4,  4,  4,  6,  6,116,116,117,  2
   DB   2,  2,123,124,  3,124,125,  1,152,155,156,156,  5,156,156,157
   DB 160,163,164,164,164,164,164,165,168,171,172,172,  3,172,172,173
   DB  24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24
   DB  24, 24, 24, 24, 24, 24, 24, 24,176,177,178,179,180,181,182,183
   DB 184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199
   DB 200,201,203,204,204,204,205,207,208,209,211,212,212,212,213,215
   DB 216,217,219,220,220,220,221,223,246,227,228,228,228,228,228,229
   DB 234,235,236,236,236,236,236,237,242,243,244,244,244,244,244,245
   DB 254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254
   DB 254,254,254,254,254,254,254,254, 17, 17, 17, 17, 17, 17, 17, 17
   DB  17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17
   DB  17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17
   DB  17, 17, 17, 17, 17, 17, 17, 17,254,254,254,254,254,254,254,  7
END;

PROCEDURE CS_TranslateTab; ASSEMBLER;
{kleine Pseudoprozedur, um die Umsetztabelle fÅr die Bitmaske auch im}
{Codesegment zu haben}
ASM
 DB 1,2,4,8
END;

PROCEDURE SetShadowTab(brightness:BYTE);
{ in: brightness = gewÅnschte Helligkeit der Farben im Schattenbereich, }
{                  in Prozent zu der Helligkeit ihrer Originalfarben    }
{out: ShadowTab  = (NÑherungs-)Farbtabelle fÅr gewÅnschte Abdunkelung   }
{     Schatten   = neue Helligkeit (Schatten ist globale Variable!)     }
{rem: Defaultwert in ShadowTab ist 70% Helligkeit der Ursprungsfarben!  }
{     Diese Routine dauert ihre Zeit (ca. 4 sec auf 8MHz-AT!)           }

VAR neue_Tabelle:ColorTable;
    p1:POINTER;

BEGIN
 IF (brightness<0) OR (brightness>100)
  THEN BEGIN
        Error:=Err_InvalidPercentage;
        exit
       END;
 p1:=@neue_Tabelle; {Trick, da der Assembler nicht mit dem SS-Segment klarkommt}
 ASM
   MOV CX,256 {Ñu·erer SchleifenzÑhler}
   LES DI,p1  {ES:DI = ^neue_Tabelle[i] }
   MOV SI,OFFSET ActualColors {DS:SI = ^ActualColors[]}

 @outerloop:
   LODSB          {AL = tempColors[i].red}
   MUL brightness {wird Åber Stack adressiert!}
   MOV DL,100
   DIV DL         {AL = tempColors[i].red * brightness DIV 100}
   MOV BL,AL      {BL := AL = neuer Rotanteil}

   LODSB          {dto., fÅr grÅn}
   MUL brightness
   MOV DL,100
   DIV DL
   MOV BH,AL      {...nach BH}

   LODSB          {dto., fÅr blau}
   MUL brightness
   MOV DL,100
   DIV DL
   MOV DH,AL      {...nach DH}

     {BL / BH / DH = RGB-Anteile der Farbe, fÅr die eine NÑherung zu finden ist}
     PUSH CX
     PUSH SI
     PUSH DI
     PUSH BP

     MOV DI,65535 {bisher gefundenes minimales Fehlerquadrat}
     MOV CX,256   {alle 256 Default-Farben durchsehen}
     MOV SI,OFFSET ActualColors  {DS:SI = ^ActualColors[]}
    @searchloop:
     MOV AL,BL    {Differenz im Rotanteil berechnen}
     SUB AL,[SI]
     JL @noNewMin {neue Farbe darf nicht heller sein!}
     MUL AL       {Fehlerquadrat berechnen}
     MOV BP,AX

     MOV AL,BH    {dto., fÅr GrÅnanteil}
     SUB AL,[SI+1]
     JL @noNewMin
     MUL AL
     ADD BP,AX
     JC @noNewMin {mordsmÑ·ige Abweichungen sofort ignorieren}

     MOV AL,DH    {dto., fÅr Blauanteil}
     SUB AL,[SI+2]
     JL @noNewMin
     MUL AL
     ADD AX,BP
     JC @noNewMin

     CMP AX,DI      {bessere Approximation gefunden?}
     JAE @noNewMin  {nein}
     MOV DI,AX      {ja, Fehlerquadrat und Farbe merken}
     MOV DL,CL
     OR DI,DI       {Fehlerquadrat = 0?}
     JZ @ColorDone  {ja, bessere NÑherung kînnen wir nicht mehr finden!}

    @noNewMin:
     ADD SI,3
     LOOP @searchloop

       CMP DI,65535   {keine Farbe gefunden?}
       JNE @ColorDone {doch, fertig!}
       MOV CX,256     {nein, also nochmal suchen}
       MOV SI,OFFSET ActualColors  {DS:SI = ^ActualColors[]}
      @searchloop2:
       LODSB
       SUB AL,BL      {Diff ˜Ò2^6 -> Quadrat ˜Ò2^12 -> 3 * Quadrat < MaxInt}
       IMUL AL        {also kein Overflow mîglich}
       MOV BP,AX

       LODSB          {dto., fÅr GrÅnanteil}
       SUB AL,BH
       IMUL AL
       ADD BP,AX

       LODSB          {dto., fÅr Blauanteil}
       SUB AL,DH
       IMUL AL
       ADD AX,BP

       CMP AX,DI      {bessere Approximation gefunden?}
       JAE @noNewMin2 {nein}
       MOV DI,AX      {ja, Fehlerquadrat und Farbe merken}
       MOV DL,CL

      @noNewMin2:
       LOOP @searchloop2


    @ColorDone:     {100h - DL = gefundene optimale Farbe}
     POP BP
     POP DI         {ES:DI = ^neue_Tabelle[i] }
     POP SI         {DS:SI = ^ActualColors[i] }
     POP CX

   MOV AL,DL      {in neue_Tabelle[i] eintragen}
   NEG AL         {AL = 100h - DL = beste NÑherung}
   STOSB

   DEC CX         {Ersatz fÅr "LOOP @outerloop"; nÑchste Farbe!}
   JCXZ @fertig
   JMP @outerloop
  @fertig:

 END; {of ASM}
 MOVE(neue_Tabelle,@ShadowTab^,256); {Farbtabelle Åbernehmen}
 Schatten:=brightness
END;

PROCEDURE SetPalette(pal:Palette; update:BOOLEAN);
{ in: pal = Zeiger auf zu setzende Palette }
{     update = TRUE/FALSE fÅr: ShadowTab neu/nicht neu berechnen}
{out: ActualColors = aktuelle Farbpalette  }
{rem: Palette wurde Åbernommen und evtl. ShadowTab neuberechnet }
BEGIN
 IF @pal<>@ActualColors
  THEN ActualColors:=pal;  {Farbpalette in ActualColors Åbernehmen}
 ASM
   MOV SI,OFFSET ActualColors  {DS:SI = ^ActualColors[]}

   CLI

    mov dx,StatusReg
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

   MOV CX,256/2
  @L1:
   LODSW
   OUT DX,AL
   MOV AL,AH
   OUT DX,AL
   LODSW
   OUT DX,AL
   MOV AL,AH
   OUT DX,AL
   LODSW
   OUT DX,AL
   MOV AL,AH
   OUT DX,AL
   LOOP @L1

   STI
 END; {of ASM}
 IF update THEN SetShadowTab(Schatten)
END;

PROCEDURE GetPalette(VAR pal:Palette); ASSEMBLER;
{ in: pal = Zeiger auf Palette-Speicher}
{out: pal = momentan aktuelle Palette  }
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

PROCEDURE FadeToPalette(destPal:Palette; AnzSteps:WORD);
{ in: ActualColors = aktuell gesetzte Farbpalette}
{     destPal  = Zielpalette}
{     AnzSteps = Zwischenschrittanzahl}
{out: ActualColors = destPal}
{rem: Die Prozedur blendet von ActualColors zu destPal Åber, und zwar}
{     in AnzSteps Schritten}
{     Das Palettesetzen wird auf den vertikalen Retrace synchronisiert,}
{     so da· ein Zwischenschritt mindestens 1/70 sec benîtigt}
VAR oldColors,pal:Palette;
    i,steps:INTEGER;
    s,d:POINTER;
BEGIN
 dec(anzsteps);
 IF anzsteps<1
  THEN steps:=1
  ELSE steps:=anzsteps; {steps ins selbe Segment wie pal bringen}
 oldColors:=ActualColors;
 pal:=destpal;    {pal und oldColors ins selbe Segment bringen}
 s:=@pal; d:=@ActualColors;
 FOR i:=0 TO steps-1 DO
  BEGIN
   {jetzt per Assembler folgende Sequenz berechnen:}
   { FOR c:=0 TO 255 DO  }
   {  BEGIN              }
   {   ActualColors[c].red:=LONGINT(pal[c].red-oldColors[c].red)*i }
   {    DIV steps+ oldColors[c].red;                               }
   {   ActualColors[c].green:=LONGINT(pal[c].green-oldColors[c].green)*i }
   {     DIV steps+ oldColors[c].green;  }
   {   ActualColors[c].blue:=LONGINT(pal[c].blue-oldColors[c].blue)*i }
   {     DIV steps+ oldColors[c].blue; }
   {  END;  }

   ASM
    LES DI,d  {ES:DI = Zeiger auf ActualColors-Tabelle}
    LDS SI,s  {DS:SI = Zeiger auf pal-Tabelle}
    MOV BX,OFFSET oldColors-OFFSET pal -1  {DS:SI+BX+1 = Zeiger auf oldColors}

    MOV CX,256
   @docolor:
    XOR AH,AH
    LODSB           {AX := pal[c].red}
    SUB AL,[SI+BX]  
    SBB AH,0        {AX := pal[c].red - oldColors[c].red = delta}
    IMUL i          {DX:AX := delta * i}
    IDIV steps      {AX := delta * i/steps}
    ADD AL,[SI+BX]  {AX := delta * i/steps + oldColors[c].red}
    STOSB

    {dto. fÅr grÅn}
    XOR AH,AH
    LODSB
    SUB AL,[SI+BX]
    SBB AH,0
    IMUL i
    IDIV steps
    ADD AL,[SI+BX]
    STOSB

    {dto. fÅr blau}
    XOR AH,AH
    LODSB
    SUB AL,[SI+BX]
    SBB AH,0
    IMUL i
    IDIV steps
    ADD AL,[SI+BX]
    STOSB

    LOOP @docolor

    MOV AX,SEG @DATA
    MOV DS,AX
   END;
   SetPalette(ActualColors,FALSE)
  END;
 SetPalette(pal,TRUE)
END;

FUNCTION LoadPalette(name:String; number:BYTE; VAR pal:Palette):WORD;
{ in: name   = Name des zu ladenden Palette-Files (Typ: "*.PAL" )}
{     number = Nummer, die die erste Farbe aus diesem File bekommen soll  }
{     ActualColors = gerade aktuelle Farbpalette}
{out: Anzahl der aus dem File gelesenen Farben (0 = Fehler trat auf)      }
{     pal = aus dem File gelesene Farbpalette, evtl. ergÑnzt}
{rem: Alle nicht Åberschriebenen Farben werden in "pal" auf die Werte der }
{     gerade aktuellen Farben "ActualColors" gesetzt; die Palette wurde   }
{     nur geladen, nicht gesetzt!}
LABEL quitloop;
VAR len:LONGINT;
    f:FileOfByte;
    i,count:WORD;
    TempPal:Palette;
    flag:BOOLEAN;
    tempName:STRING;
BEGIN
 count:=0;  {Zahl der bisher eingelesenen PaletteneintrÑge}
 tempName:=FindFile(name);
 IF tempName<>'' THEN name:=tempName;
 _assign(f,name);
 {$I-} _reset(f); {$IFDEF IOcheck} {$I+} {$ENDIF}
 if (ioresult<>0) OR (CompressError<>CompressErr_NoError)
  THEN BEGIN  {Datei existiert nicht oder nicht unter diesem Pfad}
        Error:=Err_FileIO;
        CompressError:=CompressErr_NoError;
        LoadPalette:=0; exit
       END;
 len:=_filesize(f);  {DateilÑnge ermitteln}
 if (len mod 3<>0) OR (len>3*256) OR (len<3)
  THEN BEGIN
        Error:=Err_NoPalette;
        goto quitloop;
       END;
 IF len+number*3>3*256
  THEN BEGIN
        Error:=Err_PaletteWontFit;
        goto quitloop;
       END;

 TempPal:=ActualColors; {temporÑre Palette mit aktuellen Farben vorbesetzen}
 {$I-}
  _blockread(f,TempPal[number],len);
 {$IFDEF IOcheck} {$I+} {$ENDIF}

  IF (ioresult<>0) OR (CompressError<>CompressErr_NoError)
   THEN BEGIN
         Error:=Err_FileIO;
         CompressError:=CompressErr_NoError;
         goto quitloop;
        END;

  flag:=FALSE;
  FOR i:=number TO Pred(number+(len DIV 3))
   DO flag:=flag OR (TempPal[i].red>63)
                 OR (TempPal[i].green>63)
                 OR (TempPal[i].blue>63);
  IF flag
   THEN BEGIN
         Error:=Err_NoPalette;
         goto quitloop;
        END;

  {Alles ging gut: Palette zurÅckgeben}
  pal:=TempPal;
  count:=len DIV 3;

quitloop: ;
 _close(f);
 LoadPalette:=count
END;

{Nun folgen die CodestÅcke, die Verwendung finden, um ein Sprite auf den }
{Schirm zu bringen; die Schnittstelle ist fÅr alle gleich:               }
{ in: CX    = Anzahl Bytes, die von...                                   }
{     DS:SI = (Zeiger auf Quelladresse) nach...                          }
{     ES:BX = (Zeiger auf Zieladresse) zu bringen sind;                  }
{     DI    = Bitplane (0..3) (=X-Koordinate AND 3)                      }
{     Die Bitmaske fÅr den richtigen Schreibe-Planezugriff wurde bereits }
{     gesetzt, eine evtl. nîtige Leseplane dagegen nicht!                }
{     Die Routinen kînnen sicher sein, da· CX<>0 ist                     }
{rem: Jede dieser Routinen MUSS EXAKT 16 Bytes lang und VOLL RELOKATIBEL }
{     sein, sowie die Register BP,DS,ES unverÑndert lassen!!!!!!!!!!!!!  }
{     Au·erdem mÅssen die einzelnen Routinen zur Unterscheidbarkeit in   }
{     ihren ersten zwei Bytes paarweise verschieden sein!                }

PROCEDURE Modus0; ASSEMBLER;
{Modus 0 betrachtet die Farbe 0 als durchsichtig fÅr den Hintergrund}
ASM
   INC CX
   STC                {BX so verringern, da· es zusammen mit SI zugleich}
   SBB BX,SI          {als Zielindex verwendet werden kann}
 @L1:
   LODSB              {Spritebyte holen }
   OR AL,AL           {ist es gleich 0? }
   LOOPZ @L1          {ja, nichts zu tun}
   JCXZ @L2           {alle Bytes durch?}
   MOV ES:[BX+SI],AL  {nein, Åbertragen }
   JMP @L1 {short}    {nÑchstes Byte    }
 @L2:
END;

PROCEDURE Modus1; ASSEMBLER;
{Modus 1 schreibt die Daten sofort ohne weitere Untersuchung auf den Schirm}
ASM
   MOV DI,BX          {DI setzen, damit Stringbefehle verwendet werden kînnen}
   XOR AX,AX          {AX := 0 setzen}
   SHR CX,1           {Anzahl zu Åbertragender Wîrter}
   REP MOVSW          {Daten auf einen Satz Åbertragen}
   ADC CX,AX          {noch ein einzelnes Byte Åbrig? }
   REP MOVSB
   MOV AX,AX          {4 FÅllbytes; schneller als 4 NOPs}
   MOV AX,AX
END;

PROCEDURE Modus2Work; ASSEMBLER;
{Fortsetzung von Modus2 - all das, was nicht mehr in 16 Bytes unterzubringen}
{war, kommt hierher}
ASM
   OUT DX,AX          {Lesezugriff auf passende Plane ermîglichen}

   PUSH DS            {DS zeigt noch auf Spritedaten, mu· aber auf }
                      {Hintergrund zeigen!                         }
   MOV AX,ES          {DS:SI := ES:DI  (Quellzeiger:=Zielzeiger)   }
   MOV DS,AX
   MOV SI,DI
   MOV BX,OFFSET ShadowTab   {Zeiger auf Farbumsetztabelle setzen  }

 @L4:
   LODSB              {Hintergrundfarbe holen...  }
   SEGCS XLAT         {...mit Farbtabelle umsetzen}
   STOSB              {...und auf aktueller Seite darstellen}
   LOOP @L4

   POP DS
END;

PROCEDURE Modus2; ASSEMBLER;
{Modus 2 ist fÅr "Schatten" und Ñhnliches gedacht: hierbei werden die   }
{eigentlichen Spritedaten ignoriert und stattdessen die Hintergrunddaten}
{gelesen, die sich an der Spriteposition befinden und deren Farbwerte   }
{gegen die der Farbtabelle "ShadowTab" ersetzt (um bspw. Schatten zu    }
{erzeugen, mÅ·te diese Tabelle zu jeder Farbe eine dunklere enthalten)  }
ASM
   MOV AX,DI          {Bitplane fÅr Lesezugriff nach AX bringen}
   MOV DI,BX          {fÅr Stringbefehle die Zieladresse nach DI bringen}
   MOV AH,AL          {Bitplane ins Highbyte bringen}
   MOV AL,4
   MOV DX,3CEh
   MOV SI,OFFSET Modus2Work  {fieser Trick: "CALL Modus2Work" wÅrde (da re- }
   CALL SI                   {lativ codiert) zu falscher Adresse verzweigen!}
END;

PROCEDURE Modus3Work; ASSEMBLER;
{Fortsetzung von Modus3 - all das, was nicht mehr in 16 Bytes unterzubringen}
{war, kommt hierher}
ASM
   STC           
   SBB BX,SI      {Quell-/Zieldaten beide mit nur 1 Indexregister ansprechen}
   MOV DX,BP      {BP-Register retten}
   MOV BP,BX
   MOV BX,OFFSET ShadowTab   {Zeiger auf Farbumsetztabelle setzen }

 @L1:
   LODSB              {Spritedatum holen...  }
   OR AL,AL           { (Farbe 0 ignorieren, da "durchsichtig") }
   LOOPZ @L1
   JCXZ @L2
   MOV AL,ES:[BP+SI]  {Hintergrundfarbe holen...  }
   SEGCS XLAT         {...mit Farbtabelle umsetzen}
   MOV ES:[BP+SI],AL  {...und auf aktueller Seite darstellen}
   JMP @L1
 @L2:
   MOV BP,DX          {alten Inhalt von BP wiederherstellen}
END;

PROCEDURE Modus3; ASSEMBLER;
{Modus 3 ist ebenfalls fÅr "Schatten" gedacht: hierbei werden alle Sprite-   }
{punkte, deren Farbe <>0 ist berÅcksichtigt: die Hintergrundfarbe, die sich  }
{unter diesen Punkten befindet, wird gegen den korrespondierenden Farbwert   }
{aus der Tabelle "ShadowTab" ersetzt.                                        }
{In anderen Worten: dieser Modus entspricht dem Modus 2, mit dem Unterschied,}
{da· die Spritefarbe 0 als fÅr den Schatten durchsichtig betrachtet wird!    }
ASM
   MOV DX,3CEh        {Zugriff auf Leseplane vorbereiten:}
   MOV AX,DI          
   MOV AH,AL          {Leseplane nach AH bringen}
   MOV AL,4
   OUT DX,AX          {Lesezugriff auf passende Plane ermîglichen}
   INC CX             {Anzahl Bytes um 1 erhîhen (wg. LODSB) }
   MOV AX,OFFSET Modus3Work  {Trick damit Code relokatibel wird!}
   CALL AX
END;

PROCEDURE Adressen; ASSEMBLER;
{Tabelle der Startadressen der 3 Routinen im Codesegment}
ASM
   DW OFFSET Modus0
   DW OFFSET Modus1
   DW OFFSET Modus2
   DW OFFSET Modus3
END;


PROCEDURE GADR; ASSEMBLER;
{Tabelle der Grafikzeilen-Startadressen (Offset-Anteil)}
ASM
   DW $0000,$0050,$00A0,$00F0,$0140,$0190,$01E0,$0230
   DW $0280,$02D0,$0320,$0370,$03C0,$0410,$0460,$04B0
   DW $0500,$0550,$05A0,$05F0,$0640,$0690,$06E0,$0730
   DW $0780,$07D0,$0820,$0870,$08C0,$0910,$0960,$09B0
   DW $0A00,$0A50,$0AA0,$0AF0,$0B40,$0B90,$0BE0,$0C30
   DW $0C80,$0CD0,$0D20,$0D70,$0DC0,$0E10,$0E60,$0EB0
   DW $0F00,$0F50,$0FA0,$0FF0,$1040,$1090,$10E0,$1130
   DW $1180,$11D0,$1220,$1270,$12C0,$1310,$1360,$13B0
   DW $1400,$1450,$14A0,$14F0,$1540,$1590,$15E0,$1630
   DW $1680,$16D0,$1720,$1770,$17C0,$1810,$1860,$18B0
   DW $1900,$1950,$19A0,$19F0,$1A40,$1A90,$1AE0,$1B30
   DW $1B80,$1BD0,$1C20,$1C70,$1CC0,$1D10,$1D60,$1DB0
   DW $1E00,$1E50,$1EA0,$1EF0,$1F40,$1F90,$1FE0,$2030
   DW $2080,$20D0,$2120,$2170,$21C0,$2210,$2260,$22B0
   DW $2300,$2350,$23A0,$23F0,$2440,$2490,$24E0,$2530
   DW $2580,$25D0,$2620,$2670,$26C0,$2710,$2760,$27B0
   DW $2800,$2850,$28A0,$28F0,$2940,$2990,$29E0,$2A30
   DW $2A80,$2AD0,$2B20,$2B70,$2BC0,$2C10,$2C60,$2CB0
   DW $2D00,$2D50,$2DA0,$2DF0,$2E40,$2E90,$2EE0,$2F30
   DW $2F80,$2FD0,$3020,$3070,$30C0,$3110,$3160,$31B0
   DW $3200,$3250,$32A0,$32F0,$3340,$3390,$33E0,$3430
   DW $3480,$34D0,$3520,$3570,$35C0,$3610,$3660,$36B0
   DW $3700,$3750,$37A0,$37F0,$3840,$3890,$38E0,$3930
   DW $3980,$39D0,$3A20,$3A70,$3AC0,$3B10,$3B60,$3BB0
   DW $3C00,$3C50,$3CA0,$3CF0,$3D40,$3D90,$3DE0,$3E30
   DW $3E80
END;

FUNCTION EMSinstalled(VAR PageFrameSeg:WORD):Boolean;
{ in: - }
{out: PageFrameSeg = Segmentadresse des EMS-Puffers}
{     TRUE/FALSE fÅr: EMS installiert/nicht installiert}
{     Error, EMSError = evtl. Fehlercode}
{rem: FÅr USEEMS=FALSE wird immer FALSE zurÅckgegeben  }
TYPE Tag=ARRAY[1..8] OF CHAR;
VAR p:POINTER;
Begin
 EMSError:=0;
 IF NOT USEEMS
  THEN BEGIN
        EMSinstalled:=FALSE;
        exit
       END;
 GetIntVec(EMSInt,p);
 IF Tag(Ptr(SEG(p^),$A)^)='EMMXXXX0'
  THEN BEGIN {EMS-Handler vorhanden, aber bitte mind. V3.2:}
        WITH Regs DO
         BEGIN
          AH:=$46; Intr(EMSInt,Regs); {Versionscode holen}
          EMSInstalled:=AL>=$32;      {Version >= 3.2 ?  }

          AH:=$41; Intr(EMSInt,Regs); {BX=Segmentadresse, AH=evtl. Fehler}
          PageFrameSeg:=BX;
          EmsError:=AH;
          IF EmsError<>0 THEN Error:=Err_EMSError;
         END;
       END
  ELSE EMSInstalled:=FALSE
End;

FUNCTION EMSPagesAvailable:WORD;
{ in: - }
{out: liefert Anzahl verfÅgbarer EMS Seiten (a 16K zurÅck)}
{     Error, EMSError = evtl. Fehlercode}
{rem: nur aufrufen, wenn EMSinstalled = TRUE!}
BEGIN
 WITH Regs DO
  BEGIN
   AH:=$42; Intr(EMSInt,Regs); {bestimme Anzahl freie Seiten}
   EMSPagesAvailable:=BX;
   EmsError := AH;
   IF EmsError<>0 THEN Error:=Err_EMSError;
  END;
END;

FUNCTION EMSAllocate(pages:Word):WORD;
{ in: pages = #zu belegende EMS-Seiten}
{out: Handle auf diesen EMS-Bereich}
{     Error, EMSError = evtl. Fehlercode}
{rem: pages darf die PagesAvail-Anzahl nicht Åberschreiten!}
BEGIN
 With Regs do
  BEGIN
   AH:=$43;
   BX:=pages;
   Intr(EMSInt,Regs);
   EmsError    := AH;
   IF EmsError<>0 THEN Error:=Err_EMSError;
   EMSAllocate := DX;
  END;
END;

Procedure EMSSwapPageIn(EMSHandle, LogicNr,PhysicalNr:Word);
{ in: EMSHandle  = Handle eines allozierten EMS-Blocks}
{     LogicNr    = logische Seite innerhalb dieses EMS-Blockes}
{     PhysicalNr = physikalische Seite des EMS-Frames (=0..3) }
{out: Error, EMSError = evtl. Fehlercode}
{rem: Mapped die logische Seite "LogicNr" des EMS-Bereichs, der mit dem}
{     Handle "EMSHandle" alloziert wurde, in die physikalische Seite   }
{     "PhysicalNr"}
{     Zugriff ist anschlie·end Åber MEM[BACKGNDADR:PhysicalNr*$4000] }
{     mîglich}
{     PhysicalNr = 0..3}
{     LogicNr    = 0..allozierte Pageanzahl-1}
BEGIN
 With Regs do
  BEGIN
   AH:=$44; DX:=EMSHandle; BX:=LogicNr; AL:=PhysicalNr;
   Intr(EMSInt,Regs);
   EmsError := AH;
   IF EmsError<>0 THEN Error:=Err_EMSError;
  END;
END;

PROCEDURE EMSFillFrame(EMSHandle:WORD);
{ in: EMSHandle = Handle auf 4 Seiten gro·en EMS-Bereich}
{out: EMS-Frame-Puffer wurde mit den ersten 4 Seiten gefÅllt}
{     Error, EMSError = evtl. Fehlercode}
CONST a:ARRAY[0..7] OF WORD=(0,0,1,1,2,2,3,3);
BEGIN
 With Regs do
  BEGIN
   AX:=$5000; DX:=EMSHandle; CX:=4;
   DS:=Seg(a); SI:=Ofs(a);
   Intr(EMSInt,Regs);
   EmsError := AH;
   IF EmsError<>0 THEN Error:=Err_EMSError;
  END;
END;

PROCEDURE EMSRelease(handle:WORD);
{ in: handle = Handle des freizugebenden EMS-Blockes}
{out: Error, EMSError = evtl. Fehlercode}
{rem: EMS-Block wurde freigegeben}
BEGIN
 With Regs do
  BEGIN
   AH:=$45;
   DX:=handle;
   Intr(EMSInt,Regs);
   EmsError:=AH;
   IF EmsError<>0 THEN Error:=Err_EMSError;
  END;
END;

FUNCTION EMSIsHardwareEMS:BOOLEAN;
{ in: - }
{out: FALSE, wenn EMS nur emuliert wird}
{     Error, EMSError = evtl. Fehlercode}
{rem: Die PrÅfung wird wie in der LIM4.0-Spezifikation empfohlen dadurch}
{     durchgefÅhrt, da· eine logische Seite unter allen physikalischen  }
{     Seiten eingeblendet wird}
CONST a:ARRAY[0..7] OF WORD=(0,0,0,1,0,2,0,3);
VAR SegAdr,handle:WORD;
    mirror:BOOLEAN;
BEGIN
 IF NOT(EMSInstalled(SegAdr)) OR (EMSPagesAvailable<1)
  THEN EMSIsHardwareEMS:=TRUE  {irgendne bessere Idee?}
  ELSE BEGIN
        handle:=EMSAllocate(1);
        With Regs do
         BEGIN {log. Seite 0 in alle 4 physikalischen Seiten einblenden}
          AX:=$5000; DX:=handle; CX:=4;
          DS:=Seg(a); SI:=Ofs(a);
          Intr(EMSInt,Regs);
          EmsError := AH;
          IF EmsError<>0 THEN Error:=Err_EMSError;
         END;
        MEM[SegAdr:16383]:=0;
        mirror:=(MEM[SegAdr:1*16384+16383] OR
                 MEM[SegAdr:2*16384+16383] OR
                 MEM[SegAdr:3*16384+16383])=0;
        MEM[SegAdr:16383]:=$FF;
        mirror:=mirror AND
                ((MEM[SegAdr:1*16384+16383] AND
                  MEM[SegAdr:2*16384+16383] AND
                  MEM[SegAdr:3*16384+16383])=$FF);
        EMSRelease(handle);
        EMSIsHardWareEMS:=mirror
       END;
END;

PROCEDURE EnsureEMSConsistency(EMSHandle:WORD);
{ in: EMSused = TRUE}
{     EMSHandle = Handle fÅr allozierten EMS-Block}
{     BACKGNDADR:0 = Start des EMS-Frames}
{out: Der EMS-Frame enthÑlt die gewÅnschten 64K Daten}
BEGIN
 EMSFillFrame(EMSHandle); {Zugriff auf EMS vorbereiten}
END;

FUNCTION AT:BOOLEAN;
{ in: - }
{out: TRUE/FALSE, wenn die Maschine (mindestens) ein AT ist}
BEGIN
 AT:=MEM[$F000:$FFFE]=$FC
END;


PROCEDURE SetCycleTime(milliseconds:WORD);
{ in: Mindestzeit eines Animationszyklus in Millisekunden}
{out: CycleTime := dieser Wert in Mikrosekunden}
{     TimeFlag  := $80}
{rem: FÅr den ersten Animationszyklus nach Aufruf dieser Routine }
{     gilt wg. TimeFlag := $80 die Zeitbedingung noch nicht!     }
{     Schaltet der Benutzer (durch Angabe von milliseconds=0) die}
{     ZeitÅberwachung explizit ab, so wird das durch IsAT := $80,}
{     d.h.: "Rechner ist ein PC" vorgetÑuscht. Sonst ist IsAT = 0}
BEGIN
 TimeFlag:=$80;
 CycleTime:=LONGINT(milliseconds)*LONGINT(1000);
 IF (milliseconds<>0) AND AT
  THEN IsAT:=0     {ja, ZeitÅberwachung soll benutzt werden  }
  ELSE IsAT:=$80   {nein, keine mîglich oder nicht gewÅnscht }
END;

PROCEDURE SetSpriteCycle(nr,len:WORD);
{ in: nr  = Spriteladenummer des ersten Sprites des Zyklus      }
{     len = LÑnge des zu definierenden Spritezyklus             }
{out: NextSprite[nr] bis NextSprite[nr+len-1] wurden so gesetzt,}
{     da· sie im Ring aufeinander zeigen, d.h.: sie bilden      }
{     einen Spritezyklus}
{rem: Soll der Zyklus aus nicht direkt aufeinanderfolgenden     }
{     (physikalischen) Sprites gebildet werden, so mÅssen die   }
{     entsprechenden EintrÑge in NextSprite[] manuell gemacht   }
{     werden }
{     Diese Routine verwendet SpriteLADEnummern!}
VAR i:WORD;
BEGIN
 IF (nr<1) OR (nr+len-1>LoadMAX)
  THEN Error:=Err_InvalidSpriteLoadNumber
  ELSE BEGIN
        FOR i:=nr TO nr+len-2 DO NextSprite[i]:=SUCC(i);
        NextSprite[PRED(nr+len)]:=nr  {letztes Sprite zeigt auf erstes}
       END;
END;


FUNCTION GetImage(x1,y1,x2,y2:INTEGER; pa:WORD):POINTER;
{ in: (x1,y1) = linke obere Ecke des zu sichernden Bildausschnittes       }
{     (x2,y2) = rechte untere Ecke dazu (alles virtuelle Koordinaten!)    }
{     pa      = Grafikseite, von der der Ausschnitt zu sichern ist (0..3) }
{     StartVirtualX,StartVirtualY = linke obere Bildschirmecke            }
{out: Zeiger auf Heapbereich, der den kopierten Bildausschnitt enthÑlt    }
{     left_cut= evtl. nîtiger linker Cutoff des Bildausschnittes (gibt an,}
{               um wieviel Punkte der Ausschnitt links au·erhalb des      }
{               Bildschirm ragte)                                         }
{     right_cut, top_cut, bottom_cut = dto., fÅr andere RÑnder            }
{     was_cut = TRUE/FALSE, falls ein zurechtstutzen des Bildausschnittes }
{               nîtig war/nicht nîtig war                                 }
{rem: Der benîtigte Speicher wird von der Routine automatisch reserviert  }
{     Sollte dies nicht mîglich sein (oder liegt der Bildausschnitt gÑnz- }
{     lich au·erhalb des sichtbaren Bereichs), so wird NIL zurÅckgegeben! }
{     Nur wenn "was_cut" TRUE ist, sind die Werte der globalen "..._cut"  }
{     Variablen <>0 gesetzt worden, d.h.: ist der Ausschnitt _ganz_ au·er-}
{     halb des Bildes (also zurÅckgegebener Zeiger=NIL), dann liefert die }
{     Routine trotzdem "was_cut"=FALSE!}
VAR len,breite,hoehe,StartAdr,actualAdr,SegmAdr:WORD;
    p:POINTER;
BEGIN
 was_cut:=FALSE; left_cut:=0; right_cut:=0; top_cut:=0; bottom_cut:=0;
 dec(x1,StartVirtualX);   {Bildschirmkoordinaten berechnen}
 dec(y1,StartVirtualY);
 IF (x1>XMAX) or (y1>YMAX) or (x2<0) or (y2<0) or (x1>x2) or (y1>y2)
  THEN BEGIN  {Bildausschnitt nicht auf dem Bildschirm}
        GetImage:=NIL;
        exit
       END;
 {Ausschnitt auf Bildschirm zurechtklippen:}
 IF x1<0 THEN BEGIN left_cut :=-x1; x1:=0; was_cut:=TRUE END;
 IF y1<0 THEN BEGIN top_cut:=-y1; y1:=0; was_cut:=TRUE END;
 IF x2>XMAX THEN BEGIN right_cut :=x2-XMAX; x2:=XMAX; was_cut:=TRUE END;
 IF y2>YMAX THEN BEGIN bottom_cut:=y2-YMAX; y2:=YMAX; was_cut:=TRUE END;

 breite:=SUCC(x2-x1); hoehe:=SUCC(y2-y1);
 len:=breite*hoehe+2*2; {1 Pixel = 1 Byte; dazu: 2 Wîrter fÅr breite & hoehe}
 IF len>MaxAvail
  THEN BEGIN
        Error:=Err_NotEnoughMemory;
        GetImage:=NIL;
        exit
       END;
 IF (pa<0) OR (pa>SCROLLPAGE)  {Seitennummer mu· 0..3 sein}
  THEN BEGIN
        Error:=Err_InvalidPageNumber;
        GetImage:=NIL;
        exit
       END
  ELSE SegmAdr:=Segment_Adr[pa];
 GetMem(p,len);         {Speicher auf dem Heap besorgen}
 IF pa<>BACKGNDPAGE
  THEN ASM {VRAM nach RAM}
        CLD
        LES DI,p        {ES:DI = Zeiger auf den besorgten Speicher}
        MOV AX,breite
        STOSW           {Breite zuerst ablegen...}
        MOV AX,hoehe
        STOSW           {...gefolgt von der Hîhe, danach dann die Daten}

        MOV BX,AX       {BX := hoehe (fÅr spÑter) }
        MOV SI,y1
        SHL SI,1
        MOV SI,CS:[OFFSET gadr + SI]   {SI := y1 * LINESIZE}
        MOV AX,x1
        MOV DL,AL
        SHR AX,1
        SHR AX,1
        ADD SI,AX       {SI := Offsetanteil der Startadresse}
        MOV StartAdr,SI
        MOV actualAdr,SI
        AND DL,3
        MOV AH,DL
        MOV AL,4
        MOV DX,3CEh
        OUT DX,AX       {Startplane anwÑhlen}
        MOV DS,SegmAdr

        {DS:SI = Zeiger auf erstes zu speicherndes Byte; ES:DI = Zieladr. dafÅr}
        {AH = Startplane, AL = 4, BX = abzuarbeitende Zeilenanzahl}

        MOV DX,breite
        ADD DX,3
        SHR DX,1
        SHR DX,1        {DX = Anzahl zu sichernde Bytes je Zeile}

      @L1:
        MOV CX,DX       {Daten einer Zeile abspeichern}
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        MOV SI,actualAdr  {Quellzeiger um 1 Grafikzeile weitersetzen}
        ADD SI,LINESIZE
        MOV actualAdr,SI
        DEC BX          {ZeilenzÑhler verringern}
        JNE @L1

        INC AH          {nÑchste Plane anwÑhlen}
        CMP AH,4
        JNE @nowrap1    {wrap in den Bitplanes bedeutet: Startadresse}
        MOV AH,0        {um 1 Adresse weitersetzen! }
        INC StartAdr
      @nowrap1:
        MOV DX,3CEh
        OUT DX,AX
        MOV BX,hoehe
        MOV DX,breite
        INC DX
        INC DX
        SHR DX,1
        SHR DX,1
        MOV SI,StartAdr
        MOV actualAdr,SI

      @L2:
        MOV CX,DX
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        MOV SI,actualAdr
        ADD SI,LINESIZE
        MOV actualAdr,SI
        DEC BX
        JNE @L2

        INC AH
        CMP AH,4
        JNE @nowrap2
        MOV AH,0
        INC StartAdr
      @nowrap2:
        MOV DX,3CEh
        OUT DX,AX
        MOV BX,hoehe
        MOV DX,breite
        INC DX
        SHR DX,1
        SHR DX,1
        MOV SI,StartAdr
        MOV actualAdr,SI

      @L3:
        MOV CX,DX
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        MOV SI,actualAdr
        ADD SI,LINESIZE
        MOV actualAdr,SI
        DEC BX
        JNE @L3

        INC AH
        CMP AH,4
        JNE @nowrap3
        MOV AH,0
        INC StartAdr
      @nowrap3:
        MOV DX,3CEh
        OUT DX,AX
        MOV BX,hoehe
        MOV DX,breite
        SHR DX,1
        SHR DX,1
        MOV SI,StartAdr
        MOV actualAdr,SI

      @L4:
        MOV CX,DX
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        MOV SI,actualAdr
        ADD SI,LINESIZE
        MOV actualAdr,SI
        DEC BX
        JNE @L4

        MOV AX,SEG @DATA
        MOV DS,AX
       END
  ELSE BEGIN
        IF EMSused
         THEN EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}
       ASM {RAM nach RAM}
        CLD
        LES DI,p        {ES:DI = Zeiger auf den besorgten Speicher}
        MOV AX,breite
        STOSW           {Breite zuerst ablegen...}
        MOV AX,hoehe
        STOSW           {...gefolgt von der Hîhe, danach dann die Daten}

        MOV DX,AX       {DX := hoehe (fÅr spÑter) }
        MOV SI,y1
        SHL SI,1
        MOV SI,CS:[OFFSET gadr + SI]   {SI := y1 * LINESIZE}
        MOV AX,x1
        MOV BL,AL
        SHR AX,1
        SHR AX,1
        ADD SI,AX       {SI := Offsetanteil der Startadresse}
        AND BX,3
        MOV AH,BL
        SHL BX,1
        ADD SI,[OFFSET BACKTab + BX]  {Startplane anwÑhlen}
        MOV StartAdr,SI
        MOV actualAdr,SI
        MOV DS,SegmAdr
        MOV BX,DX

        {DS:SI = Zeiger auf erstes zu speicherndes Byte; ES:DI = Zieladr. dafÅr}
        {AH = Startplane, BX = abzuarbeitende Zeilenanzahl}

        MOV DX,breite
        ADD DX,3
        SHR DX,1
        SHR DX,1        {DX = Anzahl zu sichernde Bytes je Zeile}

      @L1:
        MOV CX,DX       {Daten einer Zeile abspeichern}
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        MOV SI,actualAdr  {Quellzeiger um 1 Grafikzeile weitersetzen}
        ADD SI,LINESIZE
        MOV actualAdr,SI
        DEC BX          {ZeilenzÑhler verringern}
        JNE @L1

        INC AH          {nÑchste Plane anwÑhlen}
        ADD StartAdr,PAGESIZE
        CMP AH,4
        JNE @nowrap1    {wrap in den Bitplanes bedeutet: Startadresse}
        MOV AH,0        {um 1 Adresse weitersetzen! }
        SUB StartAdr,4*PAGESIZE -1
      @nowrap1:
        MOV BX,hoehe
        MOV DX,breite
        INC DX
        INC DX
        SHR DX,1
        SHR DX,1
        MOV SI,StartAdr
        MOV actualAdr,SI

      @L2:
        MOV CX,DX
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        MOV SI,actualAdr
        ADD SI,LINESIZE
        MOV actualAdr,SI
        DEC BX
        JNE @L2

        INC AH
        ADD StartAdr,PAGESIZE
        CMP AH,4
        JNE @nowrap2
        MOV AH,0
        SUB StartAdr,4*PAGESIZE -1
      @nowrap2:
        MOV BX,hoehe
        MOV DX,breite
        INC DX
        SHR DX,1
        SHR DX,1
        MOV SI,StartAdr
        MOV actualAdr,SI

      @L3:
        MOV CX,DX
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        MOV SI,actualAdr
        ADD SI,LINESIZE
        MOV actualAdr,SI
        DEC BX
        JNE @L3

        INC AH
        ADD StartAdr,PAGESIZE
        CMP AH,4
        JNE @nowrap3
        MOV AH,0
        SUB StartAdr,4*PAGESIZE -1
      @nowrap3:
        MOV BX,hoehe
        MOV DX,breite
        SHR DX,1
        SHR DX,1
        MOV SI,StartAdr
        MOV actualAdr,SI

      @L4:
        MOV CX,DX
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        MOV SI,actualAdr
        ADD SI,LINESIZE
        MOV actualAdr,SI
        DEC BX
        JNE @L4

        MOV AX,SEG @DATA
        MOV DS,AX
       END;
       END;
 GetImage:=p
END;

PROCEDURE PutImage(x,y:INTEGER; p:POINTER; pa:WORD);
{ in: (x,y) = linke obere Ecke des Zieles (in virtuellen Koordinaten)   }
{     p     = Zeiger auf (durch GetImage erstellten) Bildausschnitt     }
{     pa    = Grafikseite, in die der Bildausschnitt kopiert werden soll}
{     StartVirtualX,StartVirtualY = linke obere Bildschirmecke          }
{out: - }
{rem: Der Bildausschnitt wurde zur Bildschirmdarstellung zurechtgeklippt}
{     Bei öbergabe von NIL als Zeiger stellt die Routine gar nichts dar }
{     Dies hilft fÅr eine direkte öbernahme der von GetImage gelieferten}
{     Werte!}
VAR breite,hoehe,SegmAdr,actualAdr,StartAdr,breite1,breite2,breite3,breite4,
    licut_div4,topcut,pl_adr1,pl_adr2,pl_adr3,pl_adr4:WORD;
    licutoff,temp:INTEGER;
BEGIN
 IF p=NIL THEN exit;
 dec(x,StartVirtualX);   {Bildschirmkoordinaten berechnen}
 dec(y,StartVirtualY);
 IF (x>XMAX) or (y>YMAX) THEN exit;
 IF (pa<0) OR (pa>SCROLLPAGE)
  THEN BEGIN
        Error:=Err_InvalidPageNumber;
        exit
       END
  ELSE SegmAdr:=Segment_Adr[pa];
 breite:=MEMW[SEG(p^):OFS(p^)];
 hoehe :=MEMW[SEG(p^):OFS(p^)+2];
 IF (x+breite<=0) or (y+hoehe<=0) THEN exit;
 IF x<0 THEN BEGIN licutoff:=-x; x:=0 END
        ELSE licutoff:=0;
 IF y<0 THEN BEGIN
              topcut:=-y;
              y:=0
             END
        ELSE topcut:=0;

 breite1:=(breite + 3) shr 2;  {Breite einer Zeile fÅr die erste, zweite,}
 breite2:=(breite + 2) shr 2;  {dritte und vierte Bitplane}
 breite3:=(breite + 1) shr 2;
 breite4:=(breite + 0) shr 2;

 {Anfangsadressen der 4 Bitplanes berechnen; dabei evtl. linken cutoff mit}
 {einbeziehen (plus 4 Bytes zum Åberspringen von "breite" und "hoehe"     }
 licut_div4:=licutoff shr 2;
 pl_adr1:=4 +licut_div4 +topcut*breite1;
 pl_adr2:=4 +licut_div4 +topcut*breite2 +hoehe*breite1;
 pl_adr3:=4 +licut_div4 +topcut*breite3 +hoehe*(breite1+breite2);
 pl_adr4:=4 +licut_div4 +topcut*breite4 +hoehe*(breite1+breite2+breite3);

 {licutoff mod 4 gibt an, in welcher Reihenfolge die Punkte aus dem Heap  }
 {gelesen werden mÅssen: 0 = Planereihenfolge (1,2,3,4); 1=(2,3,4,1);     }
 {2=(3,4,1,2); 3=(4,1,2,3); zu beachten ist, da· die Breiten der einzelnen}
 {Bitplanetabellen natÅrlich mit diesen verbunden bleibt und deshalb      }
 {mitgetauscht werden mu·!}
 ASM
    CLD
    MOV AX,licutoff
    AND AL,3
    OR AL,AL
    JE @no_exchange
    CMP AL,1
    JNE @L10

    MOV AX,pl_adr2     {Verschiebung um 1 Bit: }
    MOV BX,pl_adr3     {AX = Plane2, BX = Plane3, CX = Plane4, DX = Plane1}
    MOV CX,pl_adr4
    MOV DX,pl_adr1     {wrap-around, deshalb: Adresse um 1 erhîhen, was   }
    INC DX             {einer Weitersetzung um 4 Bildpunkte entspricht    }
    MOV pl_adr1,AX     {(z.B.: Pixel (1,5,9,...),(2,6,10,...),(3,7,11,...)}
    MOV pl_adr2,BX     {und (0,4,8,...); letztere Bitplane wird um 1 Byte }
    MOV pl_adr3,CX     {weitergesetzt: liefert (richtige) (4,8,12,...)    }
    MOV pl_adr4,DX     {(Planes abwechselnd von oben nach unten lesen!)   }
    MOV AX,breite2     {Jetzt Planebreiten: }
    MOV BX,breite3     {AX = Plane2, BX = Plane3, CX = Plane4, DX = Plane1}
    MOV CX,breite4
    MOV DX,breite1
    JMP @store

  @L10:
    CMP AL,2
    JNE @L20

    MOV AX,pl_adr3     {Verschiebung um 2 Bit: }
    MOV BX,pl_adr4     {AX = Plane3, BX = Plane4, CX = Plane1, DX = Plane2}
    MOV CX,pl_adr1
    INC CX
    MOV DX,pl_adr2
    INC DX
    MOV pl_adr1,AX
    MOV pl_adr2,BX
    MOV pl_adr3,CX
    MOV pl_adr4,DX
    MOV AX,breite3     {dto. fÅr Planebreiten: }
    MOV BX,breite4     {AX = Plane3, BX = Plane4, CX = Plane1, DX = Plane2}
    MOV CX,breite1
    MOV DX,breite2
    JMP @store
  @L20:
    MOV AX,pl_adr4     {Verschiebung um 3 Bit: }
    MOV BX,pl_adr1     {AX = Plane4, BX = Plane1, CX = Plane2, DX = Plane3}
    INC BX
    MOV CX,pl_adr2
    INC CX
    MOV DX,pl_adr3
    INC DX
    MOV pl_adr1,AX
    MOV pl_adr2,BX
    MOV pl_adr3,CX
    MOV pl_adr4,DX
    MOV AX,breite4     {dto. fÅr Planebreiten: }
    MOV BX,breite1     {AX = Plane4, BX = Plane1, CX = Plane2, DX = Plane3}
    MOV CX,breite2
    MOV DX,breite3
  @store:
    MOV breite1,AX
    MOV breite2,BX
    MOV breite3,CX
    MOV breite4,DX

  @no_exchange:        {jetzt gilt: (pl_adr?,breite?) enthalten die Source-}
                       {Bitplanes/-breiten in der richtigen Reihenfolge    }

    MOV AX,topcut
    SUB hoehe,AX       {Hîhe um evtl. oberen cutoff korrigieren}
    MOV AX,licutoff
    SUB breite,AX      {dto. fÅr Breite und linken cutoff}

    MOV AX,x           {falls Ausschnitt Åber rechten Bildschirmrand}
    ADD AX,breite      {ragen wÅrde: rechten cutoff bestimmen       }
    SUB AX,XMAX+1
    JLE @no_recutoff
    SUB breite,AX      {AX Punkte rechts abschneiden}
  @no_recutoff:

    MOV AX,y           {genau dasselbe fÅr unteren Bildschirmrand}
    ADD AX,hoehe
    SUB AX,YMAX+1
    JLE @no_bocutoff
    SUB hoehe,AX       {AX Zeilen unten abschneiden}
  @no_bocutoff:
 END;

 IF pa<>BACKGNDPAGE
  THEN ASM {RAM nach VRAM}
        LDS SI,p
        ADD pl_adr2,SI     {Offsetanteil des Zeigers zu den Planeadr. addieren}
        ADD pl_adr3,SI
        ADD pl_adr4,SI

        ADD SI,pl_adr1     {breite, hoehe und Teile oberhalb des Bildschirms}
        MOV ES,SegmAdr

        MOV DI,y
        SHL DI,1
        MOV DI,CS:[OFFSET gadr + DI]  {DI := y * LINESIZE}
        MOV AX,x
        MOV BL,AL
        SHR AX,1
        SHR AX,1
        ADD DI,AX         {DI := y * LINESIZE + (x DIV 4)}
        MOV StartAdr,DI
        MOV actualAdr,DI

        AND BX,3          {Startplane := x mod 3}
        MOV AH,CS:[OFFSET CS_TranslateTab + BX]
        MOV AL,2
        MOV DX,3C4h
        OUT DX,AX         {als Schreibplane anwÑhlen}

        MOV DX,hoehe
        MOV DI,actualAdr

        {DS:SI = Zeiger auf Daten, ES:DI = Zieladresse dafÅr auf dem Schirm,}
        {AH = Bitmaske fÅr Zugriff, AL = 2 }
        MOV BX,breite
        ADD BX,3
        SHR BX,1
        SHR BX,1
        mov cx,bx
      @L1:
        push si
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        pop si
        mov cx,bx
        add si,breite1
        MOV DI,actualAdr
        ADD DI,LINESIZE
        MOV actualAdr,DI
        DEC DX
        JNE @L1


        SHL AH,1          {nÑchste Bitplane anwÑhlen; bei einem wrap von}
        CMP AH,16         {Bitplane 3 zu Bitplane 0 mu· dabei die Start-}
        JNE @nowrap1      {adresse um 1 Byte weitergesetzt werden       }
        MOV AH,1
        INC StartAdr
      @nowrap1:
        MOV DX,3C4h
        OUT DX,AX
        MOV SI,pl_adr2
        MOV DI,StartAdr
        MOV actualAdr,DI
        MOV DX,hoehe
        MOV BX,breite
        INC BX
        INC BX
        SHR BX,1
        SHR BX,1
        mov cx,bx
      @L2:
        push si
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        pop si
        mov cx,bx
        add si,breite2
        MOV DI,actualAdr
        ADD DI,LINESIZE
        MOV actualAdr,DI
        DEC DX
        JNE @L2


        SHL AH,1
        CMP AH,16
        JNE @nowrap2
        MOV AH,1
        INC StartAdr
      @nowrap2:
        MOV DX,3C4h
        OUT DX,AX
        MOV SI,pl_adr3
        MOV DI,StartAdr
        MOV actualAdr,DI
        MOV DX,hoehe
        MOV BX,breite
        INC BX
        SHR BX,1
        SHR BX,1
        mov cx,bx
      @L3:
        push si
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        pop si
        mov cx,bx
        add si,breite3
        MOV DI,actualAdr
        ADD DI,LINESIZE
        MOV actualAdr,DI
        DEC DX
        JNE @L3


        SHL AH,1
        CMP AH,16
        JNE @nowrap3
        MOV AH,1
        INC StartAdr
      @nowrap3:
        MOV DX,3C4h
        OUT DX,AX
        MOV SI,pl_adr4
        MOV DI,StartAdr
        MOV actualAdr,DI
        MOV DX,hoehe
        MOV BX,breite
        SHR BX,1
        SHR BX,1
        mov cx,bx
      @L4:
        push si
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        pop si
        mov cx,bx
        add si,breite4
        MOV DI,actualAdr
        ADD DI,LINESIZE
        MOV actualAdr,DI
        DEC DX
        JNE @L4

        MOV AX,SEG @DATA
        MOV DS,AX
       END
  ELSE BEGIN
        IF EMSused
         THEN EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}
       ASM {RAM nach RAM}
        MOV AX,DS
        MOV ES,AX         {ES := altes Datensegment}

        LDS SI,p
        ADD pl_adr2,SI    {Offsetanteil des Zeigers zu den Planeadr. addieren}
        ADD pl_adr3,SI
        ADD pl_adr4,SI

        ADD SI,pl_adr1    {breite, hoehe und Teile oberhalb des Bildschirms}

        MOV DI,y
        SHL DI,1
        MOV DI,CS:[OFFSET gadr + DI]  {DI := y * LINESIZE}
        MOV AX,x
        MOV BL,AL
        SHR AX,1
        SHR AX,1
        ADD DI,AX         {DI := y * LINESIZE + (x DIV 4)}

        AND BX,3          {Startplane := x mod 3}
        MOV AL,BL         {Kopie davon nach AL}
        SHL BX,1
        ADD DI,ES:[OFFSET BACKTab + BX]  {als Schreibplane anwÑhlen}
        MOV StartAdr,DI
        MOV actualAdr,DI

        MOV DX,hoehe
        MOV DI,actualAdr
        MOV ES,SegmAdr

        {DS:SI = Zeiger auf Daten, ES:DI = Zieladresse dafÅr auf dem Schirm,}
        {AL = Startplane}
        MOV BX,breite
        ADD BX,3
        SHR BX,1
        SHR BX,1
        mov cx,bx
      @L1:
        push si
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        pop si
        mov cx,bx
        add si,breite1
        MOV DI,actualAdr
        ADD DI,LINESIZE
        MOV actualAdr,DI
        DEC DX
        JNE @L1


        INC AL                {nÑchste Bitplane anwÑhlen; bei einem wrap von}
        ADD StartAdr,PAGESIZE {Bitplane 3 zu Bitplane 0 mu· dabei die Start-}
        AND AL,3              {adresse um 1 Byte weitergesetzt werden       }
        JNE @nowrap1
        SUB StartAdr,4*PAGESIZE-1
      @nowrap1:
        MOV SI,pl_adr2
        MOV DI,StartAdr
        MOV actualAdr,DI
        MOV DX,hoehe
        MOV BX,breite
        INC BX
        INC BX
        SHR BX,1
        SHR BX,1
        mov cx,bx
      @L2:
        push si
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        pop si
        mov cx,bx
        add si,breite2
        MOV DI,actualAdr
        ADD DI,LINESIZE
        MOV actualAdr,DI
        DEC DX
        JNE @L2


        INC AL                {nÑchste Bitplane anwÑhlen; bei einem wrap von}
        ADD StartAdr,PAGESIZE {Bitplane 3 zu Bitplane 0 mu· dabei die Start-}
        AND AL,3              {adresse um 1 Byte weitergesetzt werden       }
        JNE @nowrap2
        SUB StartAdr,4*PAGESIZE-1
      @nowrap2:
        MOV SI,pl_adr3
        MOV DI,StartAdr
        MOV actualAdr,DI
        MOV DX,hoehe
        MOV BX,breite
        INC BX
        SHR BX,1
        SHR BX,1
        mov cx,bx
      @L3:
        push si
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        pop si
        mov cx,bx
        add si,breite3
        MOV DI,actualAdr
        ADD DI,LINESIZE
        MOV actualAdr,DI
        DEC DX
        JNE @L3


        INC AL                {nÑchste Bitplane anwÑhlen; bei einem wrap von}
        ADD StartAdr,PAGESIZE {Bitplane 3 zu Bitplane 0 mu· dabei die Start-}
        AND AL,3              {adresse um 1 Byte weitergesetzt werden       }
        JNE @nowrap3
        SUB StartAdr,4*PAGESIZE-1
      @nowrap3:
        MOV SI,pl_adr4
        MOV DI,StartAdr
        MOV actualAdr,DI
        MOV DX,hoehe
        MOV BX,breite
        SHR BX,1
        SHR BX,1
        mov cx,bx
      @L4:
        push si
        SHR CX,1        {schneller als "REP MOVSB"}
        REP MOVSW
        ADC CX,CX
        REP MOVSB
        pop si
        mov cx,bx
        add si,breite4
        MOV DI,actualAdr
        ADD DI,LINESIZE
        MOV actualAdr,DI
        DEC DX
        JNE @L4

        MOV AX,SEG @DATA
        MOV DS,AX
       END
       END;
END;

PROCEDURE FreeImageMem(p:POINTER);
{ in: p = Zeiger auf per GetImage() gespeichertes Bild}
{out: - }
{rem: Der fÅr das Bild reservierte Heap-Speicher wurde freigegeben}
BEGIN
 IF p<>NIL THEN FreeMem(p,MEMW[Seg(p^):Ofs(p^)]*MEMW[Seg(p^):Ofs(p^)+2] + 2*2)
END;

PROCEDURE Screen(pa:WORD);
{ in: pa = anzuzeigende Bildschirmseite (0..1) }
{out: - }
{rem: Es wurde auf die Darstellung der Grafikseite pa umgeschaltet     }
{     Dabei wurde NICHT auf irgendwelche Retrace-Signale synchronisiert}
{     Sinnvoll sind nur die Seiten 0 oder 1, es findet aber keine      }
{     öberprÅfung statt!}
BEGIN
 ASM
    MOV DX,CRTAddress        {CRT-Controller}
    MOV AL,$0D               {LB-Startadress-Register}
    CLI                      {Darf keinenfalls unterbrochen werden!}
    OUT DX,AL
    INC DX
                             {Realisiere "AX := Offset_Adr[pa]":}
    MOV BX,pa
    MOV SI,BX
    AND SI,3                 {Pagewert * 2 (da WorteintrÑge!)}
    SHL SI,1                 {dazu Startadresse des Feldes addieren}
    ADD SI,OFFSET Offset_Adr-StartIndex*2  {evtl. Verschiebung korrigieren}
    LODSW                    {und Wert holen}
    OUT DX,AL                {LB der neuen Startadresse setzen}
    DEC DX
    MOV AL,$0C
    OUT DX,AL
    INC DX
    MOV AL,AH                {HB der neuen Startadresse setzen}
    OUT DX,AL
    STI
 END;
END;

PROCEDURE InitGraph;
{ in: PAGE = aktuelle Grafikseite}
{out: - }
{rem: Schaltet die VGA-Karte in den 320x200x256x4-Modus; ACHTUNG!    }
{     Dieser Modus ist verschieden vom Modus $13 der VGA!!!          }
{     Dabei wird auf die Darstellung der Seite 1-PAGE geschaltet     }
{     Es werden die Defaultfarben des Modus $13 gesetzt!             }
BEGIN
 ASM
    MOV AX,0013h   {Mit BIOS Grafikmodus $13 (=320x200x256) setzen   }
    INT 10h        
    MOV DX,03C4h   {im Sequenzer das Speichermodusregister auswÑhlen }
    MOV AL,04      
    OUT DX,AL      
    INC DX         {Daten Åber das zugehîrige Datenregister lesen    }
    IN  AL,DX      
    AND AL,0F7h    {Bit 3 := 0: 4 Planes nicht chainen}
    OR  AL,04      {Bit 2 := 1: kein odd/even-Mechan. }
    OUT DX,AL      {Neuen Wert wirksam machen}
    MOV DX,03C4h   {S.o.: Sequenzerregister2 (=Map-Maske) wÑhlen,... }
    MOV AL,02      
    OUT DX,AL      
    INC DX
    MOV AL,0Fh     {...und Zugriff auf alle 4 Bitmaps erlauben       }
    OUT DX,AL      
    MOV AX,0A000h  {Ab Segment A000h nun 8000h logische Wîrter =     }
    MOV ES,AX      {4*8000h physikalische Wîrter (wg. den 4 Bit-     }
    SUB DI,DI      {planes) auf 0 setzen                             }
    MOV AX,DI      
    MOV CX,8000h   
    CLD
    REP STOSW

    MOV DX,CRTAddress  {im CRT-Controller das underline-location- }
    MOV AL,14h         {Register auswÑhlen, den Wert aus dem      }
    OUT DX,AL          {zugehîrigen Datenregister auslesen:       }
    INC DX
    IN  AL,DX
    AND AL,0BFh    {Bit 6:=0: keine Doppelwortadressierung von}
    OUT DX,AL      {Daten im Bildschirmspeicher durchfÅhren}
    DEC DX         
    MOV AL,17h     {Mode-control-Register auswÑhlen  }
    OUT DX,AL      
    INC DX
    IN  AL,DX
    OR  AL,40h     {Bit 6 := 1: Adressierung des Speichers=lineares Bitfeld}
    OUT DX,AL      
 END;
 Screen(1-PAGE);   {sichtbar ist immer die nichtaktuelle Grafikseite}
 SetPalette(DefaultColors,FALSE)  {Standardpalette setzen, sicher ist sicher}
END;


VAR d,dp,dq,WindowY2:INTEGER;
PROCEDURE BackgroundLine(x1,y1,x2,y2:INTEGER);
{ in: x1,y1,x2,y2 = Koordinaten zweier Punkte, }
{     Color       = Farbe (0..255)             }
{     StartVirtualX,StartVirtualY = linke obere Bildschirmecke}
{     WinClip     = TRUE, wenn Linie auf Win* Fenster geclippt werden soll }
{     WinXMIN,WinXMAX,WinYMIN,WinYMAX = Fenster fÅr evtl. Clipping}
{out: - }
{rem: Es wurde eine Linie von den VIRTUELLEN Punkten (x1,y1) nach (x2,y2)  }
{     in der Farbe COLOR gezeichnet; die Routine fÅhrt dabei selber die    }
{     Umrechnung der angeg. Koordinaten in absolute Bildschirmkoordinaten  }
{     sowie evtl. notwendige Clipping-Schritte aus.                        }
{     Die Linie wird NICHT automatisch in den Hintergrund Åbernommen,      }
{     d.h.: sie ist nur fÅr einen Animationszyklus sichtbar (soll sie      }
{     permanent bleiben, so mu· sie in den Hintergrund gezeichnet werden!)}
{     (Deshalb ist es sinnvoll, diese Routine NACH Aufruf von ANIMATE aus- }
{     zufÅhren, da die gezeichnete Linie sonst sofort wieder verschwindet) }
CONST CodeLinks =$7;  {%0111}
      CodeRechts=$B;  {%1011}
      CodeOben  =$D;  {%1101}
      CodeUnten =$E;  {%1110}
BEGIN
  IF EMSused
   THEN EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}

  {zuerst Linie auf sichtbaren Bereich zurechtklippen; dazu Sutherland-}
  {Cohen-Algorithmus verwenden: 4 Bit-Code fÅr links|rechts|oben|unten}
  ASM
     CLD
     XOR BX,BX
     MOV SI,XMAX
     XOR DI,DI
     MOV AX,YMAX
     CMP WinClip,FALSE
     JE @Start
     MOV BX,WinXMIN
     MOV SI,WinXMAX
     MOV DI,WinYMIN
     MOV AX,WinYMAX
   @Start:
     MOV WindowY2,AX
     {BX|SI|DI|WindowY2 = WinXMIN|WinXMAX|WinYMIN|WinYMAX bzw. 0|XMAX|0|YMAX}

     MOV CL,$F         {mit %1111 anfangen}
     MOV AX,x2
     SUB AX,StartVirtualX   {x2 in absolute Koordinaten umrechnen}
     MOV x2,AX
     CMP AX,BX         {x2 < WindowX1 ?}
     JL @GC1Punkt2     {ja, Flag fÅr "Punkt links vom Fenster" belassen}
     AND CL,CodeLinks  {nein, Flag rÅcksetzen}
   @GC1Punkt2:
     CMP AX,SI         {x2 > WindowX2 ?}
     JG @GC2Punkt2     {ja, Flag fÅr "Punkt rechts vom Fenster" belassen}
     AND CL,CodeRechts {nein, Flag rÅcksetzen}
   @GC2Punkt2:
     MOV AX,y2
     SUB AX,StartVirtualY   {y2 in absolute Koordinaten umrechnen}
     MOV y2,AX
     CMP AX,DI         {y2 < WindowY1 ?}
     JL @GC3Punkt2     {ja, Flag fÅr "Punkt oberhalb des Fensters" bel.}
     AND CL,CodeOben   {nein, Flag rÅcksetzen}
   @GC3Punkt2:
     CMP AX,WindowY2   {y2 > WindowY2 ?}
     JG @GC4Punkt2     {ja, Flag fÅr "Punkt unterhalb des Fensters" bel.}
     AND CL,CodeUnten
   @GC4Punkt2:         {CL enthÑlt jetzt den Gebietscode fÅr Punkt 2}

     MOV AX,x1
     SUB AX,StartVirtualX   {x1 in absolute Koordinaten umrechnen}
     MOV x1,AX
     MOV AX,y1
     SUB AX,StartVirtualY   {y1 in absolute Koordinaten umrechnen}
     MOV y1,AX

   @Punkt1:
     MOV CH,$F         {mit %1111 anfangen}
     MOV AX,x1
     CMP AX,BX         {x1 < WindowX1 ?}
     JL @GC1Punkt1     {ja, Flag fÅr "Punkt links vom Fenster" belassen}
     AND CH,CodeLinks  {nein, Flag rÅcksetzen}
   @GC1Punkt1:
     CMP AX,SI         {x1 > WindowX2 ?}
     JG @GC2Punkt1     {ja, Flag fÅr "Punkt rechts vom Fenster" belassen}
     AND CH,CodeRechts {nein, Flag rÅcksetzen}
   @GC2Punkt1:
     MOV AX,y1
     CMP AX,DI         {y1 < WindowY1 ?}
     JL @GC3Punkt1     {ja, Flag fÅr "Punkt oberhalb des Fensters" bel.}
     AND CH,CodeOben   {nein, Flag rÅcksetzen}
   @GC3Punkt1:
     CMP AX,WindowY2   {y1 > WindowY2 ?}
     JG @GC4Punkt1     {ja, Flag fÅr "Punkt unterhalb des Fensters" bel.}
     AND CH,CodeUnten
   @GC4Punkt1:         {CH enthÑlt jetzt den Gebietscode fÅr Punkt 1}

   {CL enthÑlt den Gebietscode fÅr Punkt 2, CH den fÅr Punkt 1}

     MOV AX,CX
     AND AL,AH         {Code1 AND Code2 <> 0 ?}
     JNZ @LineReady    {ja, Linie ganz au·erhalb des Windows}
     MOV AX,CX
     OR AL,AH          {Code1 OR Code2 = 0 ?}
     JZ @DrawLine      {ja, Linie ganz innerhalb des Windows}

   {Nun eigentliches Clipping vornehmen: }
     MOV AX,CX
     OR AH,AH          {Code1 =0 ?}
     JNZ @CL3          {nein, alles ok}
     MOV AX,x1         {ja, Punkte vertauschen!}
     XCHG AX,x2
     MOV x1,AX
     MOV AX,y1
     XCHG AX,y2
     MOV y1,AX
     XCHG CL,CH
   @CL3:
     MOV AX,x2
     SUB AX,x1        
     MOV dp,AX        {dp := x2 - x1}
     MOV AX,y2
     SUB AX,y1        
     MOV dq,AX        {dq := y2 - y1}

     MOV AL,CH        {AL := Code1}
     TEST AL,NOT CodeLinks     {Punkt1 links des Windows?}
     JZ @CL4                   {nein}
     {ja, neue Koordinaten berechnen:}
     { y1 := y1 + (y2 - y1) / (x2 - x1) * (WindowX1 - X1) }
     { und x1 := WindowX1}
     MOV AX,BX
     SUB AX,x1        {AX := WindowX1-x1}
     IMUL dq
     IDIV dp
     ADD y1,AX
     MOV x1,BX
     JMP @Punkt1

   @CL4:
     TEST AL,NOT CodeRechts    {Punkt1 rechts des Windows?}
     JZ @CL5                   {nein}
     {ja, berechne:}
     { y1 := y1 + (y2 - y1) / (x2 - x1) * (WindowX2 - X1), x1 := WindowX2}
     MOV AX,SI  {SI = WindowX2}
     SUB AX,x1
     IMUL dq
     IDIV dp
     ADD y1,AX
     MOV x1,SI
     JMP @Punkt1

   @CL5:
     TEST AL,NOT CodeOben      {Punkt1 oberhalb des Windows?}
     JZ @CL6                   {nein}
     {ja, berechne:}
     { x1 := x1 + (x2 - x1) / (y2 - y1) * (WindowY1 - y1), y1 := WindowY1 }
     MOV AX,DI  {DI = WindowY1}
     SUB AX,y1
     IMUL dp
     IDIV dq
     ADD x1,AX
     MOV y1,DI
     JMP @Punkt1

   @CL6:
     TEST AL,NOT CodeUnten     {Punkt unterhalb des Windows?}
     JZ @Punkt1                {nein}
     {ja, berechne:}
     { x1 := x1 + (x2 - x1) / (y2 - y1) * (WindowY2 - y1), y1 := WindowY2 }
     MOV AX,WindowY2
     PUSH AX
     SUB AX,y1
     IMUL dp
     IDIV dq
     ADD x1,AX
     POP AX
     MOV y1,AX
     JMP @Punkt1

   {Hier gilt: die beiden Punkte wurden auf den sichtbaren Bereich zurecht-}
   {gestutzt; sollte die Gerade keinen sichtbaren Teil besitzen, so wurde  }
   {direkt zu @LineReady verzweigt! }
   @DrawLine:
     MOV DX,x1
     SUB DX,x2
     JGE @posdx
     NEG DX
   @posdx:
     MOV AX,y1
     SUB AX,y2
     JGE @posdy
     NEG AX
   @posdy:
     {AX = neues deltaY, DX = neues deltaX}
     XOR CX,CX
     CMP AX,DX
     JBE @noswap1
     XCHG AX,DX
     INC CX
   @noswap1:
     {AX = deltaY, DX = deltaX (fÅr CX=0), AX = deltaX, DX = deltaY (fÅr CX=1)}
     SHL AX,1
     MOV dp,AX
     SUB AX,DX
     MOV d,AX
     SUB AX,DX
     MOV dq,AX

     JCXZ @then
     JMP @else

   @then:
     MOV CX,x2
     MOV AX,x1
     MOV DX,y1
     MOV BX,y2
     CMP AX,CX
     JBE @noswap2
     XCHG AX,CX
     XCHG DX,BX
   @noswap2:
     {AX = neues X1, CX = neues X2, DX = neues Y1, BX = neues Y2}
     SUB CX,AX
     INC CX  {CX := x2 - x1 + 1 }
     MOV SI,LINESIZE
     CMP DX,BX
     JBE @okay1
     NEG SI
   @okay1:
     {SI = ÒLINESIZE, CX = #Pixel, AX = X1, DX = Y1}
     MOV DI,DX
     SHL DI,1
     MOV DI,CS:[OFFSET gadr + DI]   {DI := y1 * LINESIZE}
     MOV BL,AL
     SHR AX,1
     SHR AX,1
     ADD DI,AX       {DI := y1 * LINESIZE + (x1 DIV 4) }

     AND BX,3        {BX := (x1 AND 4) }
     SHL BX,1        {*2, da WorteintrÑge}
     ADD DI,[OFFSET BACKTab + BX]  {Maske fÅr Zugriff holen: BX * 16000}

     MOV BL,BACKGNDPAGE   {BH = 0 -> BX = Zeichenseite}
     SHL BX,1
     MOV ES,[BX + OFFSET Segment_Adr -StartIndex*2] {ES:DI=Zeiger auf 1.Punkt}

     MOV AL,Color
     MOV DX,d
     MOV BX,dq

   @loop1:
     MOV ES:[DI],AL
     ADD DI,PAGESIZE
     JC @wrap1
     CMP DI,4*PAGESIZE
     JB @nowrap1
   @wrap1:
     SUB DI,4*PAGESIZE-1  {wieder in Plane0, aber 1 Byte weiter}
   @nowrap1:  {AL = Farbe, SI = ÒLINESIZE, ES:DI=Zeiger auf 1.Punkt}
              {BX = dq, DX = d}
     OR DX,DX
     JGE @newline
     ADD DX,dp
     LOOP @loop1
     JMP @raus

   @newline:
     ADD DI,SI
     ADD DX,BX
     LOOP @loop1
     JMP @raus


   @else:
     MOV CX,y2
     MOV AX,y1
     MOV DX,x1
     MOV BX,x2
     CMP AX,CX
     JBE @noswap3
     XCHG AX,CX
     XCHG DX,BX
   @noswap3:
     {AX = neues Y1, BX = neues X2, CX = neues Y2, DX = neues X1}
     SUB CX,AX
     INC CX
     MOV SI,PAGESIZE
     CMP DX,BX
     JBE @okay2
     NEG SI
   @okay2:
     {SI = ÒPAGESIZE, CX = #Pixel, DX = X1, AX = Y1}
     MOV DI,AX
     SHL DI,1
     MOV DI,CS:[OFFSET gadr + DI]   {DI := y1 * LINESIZE}
     MOV BL,DL
     SHR DX,1
     SHR DX,1
     ADD DI,DX       {DI := y1 * LINESIZE + (x1 DIV 4) }

     AND BX,3        {BX := (x1 AND 4) }
     SHL BX,1        {*2, da WorteintrÑge}
     ADD DI,[OFFSET BACKTab + BX]  {Maske fÅr Zugriff holen: BX * 16000}

     MOV BL,BACKGNDPAGE   {BH = 0 -> BX = Zeichenseite}
     SHL BX,1
     MOV ES,[BX + OFFSET Segment_Adr -StartIndex*2] {ES:DI=Zeiger auf 1.Punkt}

     MOV AL,Color
     MOV DX,d
     MOV BX,dq

   @loop2:
     MOV ES:[DI],AL
     ADD DI,LINESIZE
     OR DX,DX
     JGE @newcolumn
     ADD DX,dp
     LOOP @loop2
     JMP @raus

   @newcolumn:
     OR SI,SI
     JGE @plus
     {Inkrement SI<0, auf underflow prÅfen:}
     ADD DI,SI
     JC @nowrap2
     ADD DI,4*PAGESIZE-1
     JMP @nowrap2
   @plus:
     {Inkrement SI>0, auf overflow & >= 4*PAGESIZE prÅfen}
     ADD DI,SI
     JC @wrap2
     CMP DI,4*PAGESIZE
     JB @nowrap2
   @wrap2:
     SUB DI,4*PAGESIZE-1
   @nowrap2:
     ADD DX,BX
     LOOP @loop2
     JMP @raus

   @raus:
   @LineReady:
  END;
END;

PROCEDURE Line(x1,y1,x2,y2:INTEGER; pa:WORD);
{ in: x1,y1,x2,y2 = Koordinaten zweier Punkte, }
{     Color       = Farbe (0..255)             }
{     StartVirtualX,StartVirtualY = linke obere Bildschirmecke         }
{     pa          = Grafikseite, auf der gezeichnet werden soll (0..3) }
{     WinClip     = TRUE, wenn Linie auf Win* Fenster geclippt werden soll }
{     WinXMIN,WinXMAX,WinYMIN,WinYMAX = Fenster fÅr evtl. Clipping}
{out: - }
{rem: Es wurde eine Linie von den VIRTUELLEN Punkten (x1,y1) nach (x2,y2)  }
{     in der Farbe COLOR gezeichnet; die Routine fÅhrt dabei selber die    }
{     Umrechnung der angeg. Koordinaten in absolute Bildschirmkoordinaten  }
{     sowie evtl. notwendige Clipping-Schritte aus.                        }
{     Die Linie wird NICHT automatisch in den Hintergrund Åbernommen,      }
{     d.h.: sie ist nur fÅr einen Animationszyklus sichtbar (soll sie      }
{     permanent bleiben, so mu· sie in den Hintergrund gezeichnet werden!)}
{     (Deshalb ist es sinnvoll, diese Routine NACH Aufruf von ANIMATE aus- }
{     zufÅhren, da die gezeichnete Linie sonst sofort wieder verschwindet) }
CONST CodeLinks =$7;  {%0111}
      CodeRechts=$B;  {%1011}
      CodeOben  =$D;  {%1101}
      CodeUnten =$E;  {%1110}
BEGIN
 IF (pa<0) OR (pa>SCROLLPAGE)
  THEN Error:=Err_InvalidPageNumber
 ELSE IF pa=BACKGNDPAGE
  THEN BackgroundLine(x1,y1,x2,y2)
  ELSE
  {zuerst Linie auf sichtbaren Bereich zurechtklippen; dazu Sutherland-}
  {Cohen-Algorithmus verwenden: 4 Bit-Code fÅr links|rechts|oben|unten}
  ASM
     CLD
     XOR BX,BX
     MOV SI,XMAX
     XOR DI,DI
     MOV AX,YMAX
     CMP WinClip,FALSE
     JE @Start
     MOV BX,WinXMIN
     MOV SI,WinXMAX
     MOV DI,WinYMIN
     MOV AX,WinYMAX
   @Start:
     MOV WindowY2,AX
     {BX|SI|DI|WindowY2 = WinXMIN|WinXMAX|WinYMIN|WinYMAX bzw. 0|XMAX|0|YMAX}

     MOV CL,$F         {mit %1111 anfangen}
     MOV AX,x2
     SUB AX,StartVirtualX   {x2 in absolute Koordinaten umrechnen}
     MOV x2,AX
     CMP AX,BX         {x2 < WindowX1 ?}
     JL @GC1Punkt2     {ja, Flag fÅr "Punkt links vom Fenster" belassen}
     AND CL,CodeLinks  {nein, Flag rÅcksetzen}
   @GC1Punkt2:
     CMP AX,SI         {x2 > WindowX2 ?}
     JG @GC2Punkt2     {ja, Flag fÅr "Punkt rechts vom Fenster" belassen}
     AND CL,CodeRechts {nein, Flag rÅcksetzen}
   @GC2Punkt2:
     MOV AX,y2
     SUB AX,StartVirtualY   {y2 in absolute Koordinaten umrechnen}
     MOV y2,AX
     CMP AX,DI         {y2 < WindowY1 ?}
     JL @GC3Punkt2     {ja, Flag fÅr "Punkt oberhalb des Fensters" bel.}
     AND CL,CodeOben   {nein, Flag rÅcksetzen}
   @GC3Punkt2:
     CMP AX,WindowY2   {y2 > WindowY2 ?}
     JG @GC4Punkt2     {ja, Flag fÅr "Punkt unterhalb des Fensters" bel.}
     AND CL,CodeUnten
   @GC4Punkt2:         {CL enthÑlt jetzt den Gebietscode fÅr Punkt 2}

     MOV AX,x1
     SUB AX,StartVirtualX   {x1 in absolute Koordinaten umrechnen}
     MOV x1,AX
     MOV AX,y1
     SUB AX,StartVirtualY   {y1 in absolute Koordinaten umrechnen}
     MOV y1,AX

   @Punkt1:
     MOV CH,$F         {mit %1111 anfangen}
     MOV AX,x1
     CMP AX,BX         {x1 < WindowX1 ?}
     JL @GC1Punkt1     {ja, Flag fÅr "Punkt links vom Fenster" belassen}
     AND CH,CodeLinks  {nein, Flag rÅcksetzen}
   @GC1Punkt1:
     CMP AX,SI         {x1 > WindowX2 ?}
     JG @GC2Punkt1     {ja, Flag fÅr "Punkt rechts vom Fenster" belassen}
     AND CH,CodeRechts {nein, Flag rÅcksetzen}
   @GC2Punkt1:
     MOV AX,y1
     CMP AX,DI         {y1 < WindowY1 ?}
     JL @GC3Punkt1     {ja, Flag fÅr "Punkt oberhalb des Fensters" bel.}
     AND CH,CodeOben   {nein, Flag rÅcksetzen}
   @GC3Punkt1:
     CMP AX,WindowY2   {y1 > WindowY2 ?}
     JG @GC4Punkt1     {ja, Flag fÅr "Punkt unterhalb des Fensters" bel.}
     AND CH,CodeUnten
   @GC4Punkt1:         {CH enthÑlt jetzt den Gebietscode fÅr Punkt 1}

   {CL enthÑlt den Gebietscode fÅr Punkt 2, CH den fÅr Punkt 1}

     MOV AX,CX
     AND AL,AH         {Code1 AND Code2 <> 0 ?}
     JNZ @LineReady    {ja, Linie ganz au·erhalb des Windows}
     MOV AX,CX
     OR AL,AH          {Code1 OR Code2 = 0 ?}
     JZ @DrawLine      {ja, Linie ganz innerhalb des Windows}

   {Nun eigentliches Clipping vornehmen: }
     MOV AX,CX
     OR AH,AH          {Code1 =0 ?}
     JNZ @CL3          {nein, alles ok}
     MOV AX,x1         {ja, Punkte vertauschen!}
     XCHG AX,x2
     MOV x1,AX
     MOV AX,y1
     XCHG AX,y2
     MOV y1,AX
     XCHG CL,CH
   @CL3:
     MOV AX,x2
     SUB AX,x1        
     MOV dp,AX        {dp := x2 - x1}
     MOV AX,y2
     SUB AX,y1        
     MOV dq,AX        {dq := y2 - y1}

     MOV AL,CH        {AL := Code1}
     TEST AL,NOT CodeLinks     {Punkt1 links des Windows?}
     JZ @CL4                   {nein}
     {ja, neue Koordinaten berechnen:}
     { y1 := y1 + (y2 - y1) / (x2 - x1) * (WindowX1 - X1) }
     { und x1 := WindowX1}
     MOV AX,BX
     SUB AX,x1        {AX := WindowX1-x1}
     IMUL dq
     IDIV dp
     ADD y1,AX
     MOV x1,BX
     JMP @Punkt1

   @CL4:
     TEST AL,NOT CodeRechts    {Punkt1 rechts des Windows?}
     JZ @CL5                   {nein}
     {ja, berechne:}
     { y1 := y1 + (y2 - y1) / (x2 - x1) * (WindowX2 - X1), x1 := WindowX2}
     MOV AX,SI  {SI = WindowX2}
     SUB AX,x1
     IMUL dq
     IDIV dp
     ADD y1,AX
     MOV x1,SI
     JMP @Punkt1

   @CL5:
     TEST AL,NOT CodeOben      {Punkt1 oberhalb des Windows?}
     JZ @CL6                   {nein}
     {ja, berechne:}
     { x1 := x1 + (x2 - x1) / (y2 - y1) * (WindowY1 - y1), y1 := WindowY1 }
     MOV AX,DI  {DI = WindowY1}
     SUB AX,y1
     IMUL dp
     IDIV dq
     ADD x1,AX
     MOV y1,DI
     JMP @Punkt1

   @CL6:
     TEST AL,NOT CodeUnten     {Punkt unterhalb des Windows?}
     JZ @Punkt1                {nein}
     {ja, berechne:}
     { x1 := x1 + (x2 - x1) / (y2 - y1) * (WindowY2 - y1), y1 := WindowY2 }
     MOV AX,WindowY2
     PUSH AX
     SUB AX,y1
     IMUL dp
     IDIV dq
     ADD x1,AX
     POP AX
     MOV y1,AX
     JMP @Punkt1

   {Hier gilt: die beiden Punkte wurden auf den sichtbaren Bereich zurecht-}
   {gestutzt; sollte die Gerade keinen sichtbaren Teil besitzen, so wurde  }
   {direkt zu @LineReady verzweigt! }
   @DrawLine:
     PUSH BP
     MOV Steigung,0  {Flag zurÅcksetzen}
     MOV CX,x2
     SUB CX,x1       {Punkt1 rechts von Punkt2 ?}
     JGE @posDX      {nein}
     NEG CX          {ja, Punkte vertauschen}
     MOV AX,x1
     XCHG AX,x2
     MOV x1,AX
     MOV AX,y1
     XCHG AX,y2
     MOV y1,AX

   @posDX:
     MOV DI,y1
     SHL DI,1
     MOV DI,CS:[OFFSET gadr + DI]   {DI := y1 * LINESIZE}
     MOV AX,x1
     MOV BL,AL
     SHR AX,1
     SHR AX,1
     ADD DI,AX       {DI := y1 * LINESIZE + (x1 DIV 4) }

     AND BX,3        {BX := (x1 AND 4) }
     MOV DH,[OFFSET TranslateTab + BX]  {Maske fÅr VRAM-Zugriff holen}
     MOV DL,2

     MOV BX,pa       {BX = Zeichenseite}
     SHL BX,1
     MOV ES,[BX +OFFSET Segment_Adr -StartIndex*2]

     {ES:DI=Zeiger auf Grafikadresse von Punkt1, DX=Zugriffsmaske dafÅr}
     MOV SI,LINESIZE
     MOV BX,y2
     SUB BX,y1       {Punkt1 unterhalb von Punkt2 ?}
     JG @posDY       {nein}
     NEG BX          {ja, deltaY und Zeileninkrement negieren}
     NEG SI

   @posDY:
     CMP BX,CX       {deltaY > deltaX ?}
     JLE @flach      {nein: geringe Steigung, <=1 }
     XCHG BX,CX      {ja, deltas vertauschen und Flag setzen}
     MOV Steigung,1

   {Jetzt Bresenham-Parameter berechnen: 2 * DY, 2 * DY - DX, 2 * (DY - DX) }
   @flach:
     SHL BX,1
     MOV DY_mal2,BX
     SUB BX,CX
     MOV BP,BX       {BP := 2 * DY - DX}
     SUB BX,CX
     MOV DY_m_DX_mal2,BX
     INC CX          {CX := Anzahl Pixel}
     MOV BL,Color
     MOV BH,1
     CMP Steigung,0  {steile Linie?}
     JNZ @high1      {ja}

   @low1:            {nein}
     MOV AX,3C4h
     XCHG AX,DX
     OUT DX,AX       {richtige Bitplane anwÑhlen}
     MOV DX,AX       {Maske wieder nach DX retten}
     MOV AL,BL       {Farbe fÅr Punkt holen}
     STOSB           {Punkt setzen}
     SHL DH,1        {Maske fÅr nÑchsten Punkt berechnen     }
     CMP DH,16       {noch mit derselben Adresse ansprechbar?}
     JE @nextbyte1   {nein, Adr. mu·(te) um 1 erhîht werden  }
     DEC DI          {ja, Erhîhung von DI rÅckgÑngig machen  }
   @low1b:
     OR BP,BP
     JGE @low2
     ADD BP,DY_mal2
     LOOP @low1
     JMP @raus
   @nextbyte1:
     MOV DH,BH       {Maske auf 1 zurÅcksetzen}
     JMP @low1b      {Rest wie gehabt}

   @low2:
     ADD BP,DY_m_DX_mal2
     ADD DI,SI
     LOOP @low1
     JMP @raus


   @high1:
     MOV AX,3C4h
     XCHG AX,DX
     OUT DX,AX
     MOV DX,AX
     MOV AL,BL
   @high1b:
     OR BP,BP
     JGE @high2
     ADD BP,DY_mal2
     MOV ES:[DI],AL
     ADD DI,SI
     LOOP @high1b
     JMP @raus

   @high2:
     ADD BP,DY_m_DX_mal2
     SHL DH,1
     CMP DH,16
     JE @nextbyte2
     MOV ES:[DI],AL
     ADD DI,SI
     LOOP @high1
     JMP @raus
   @nextbyte2:
     MOV DH,BH
     STOSB
     ADD DI,SI
     LOOP @high1

   @raus:
     POP BP
   @LineReady:
  END;
END;

FUNCTION GetPixel(x,y:INTEGER):BYTE; ASSEMBLER;
{ in: x,y    = VIRTUELLE Punktkoordinaten des auszulesenden Punktes}
{     PAGEADR= Grafikseite(nsegment), aus der gelesen werden soll  }
{     StartVirtualX, StartVirtualY = linke obere Bildschirmecke    }
{out: Farbe des Punktes}
{rem: Liegt der Punkt au·erhalb des sichtbaren Bereichs, so wird   }
{     "0" als Ergebniswert zurÅckgeliefert}
{     Achtung! Da PAGEADR immer die nichtsichtbare Grafikseite     }
{     bezeichnet, liest diese Routine auch von dort die Punkte ein!}
ASM
 XOR AL,AL              {AL mit 0 vorbesetzen}
 MOV DI,y
 SUB DI,StartVirtualY   {y in absolute Koordinaten umrechnen}
 JS @offscrn
 CMP DI,YMAX
 JG @offscrn
 MOV BX,x
 SUB BX,StartVirtualX   {x in absolute Koordinaten umrechnen}
 JS @offscrn
 CMP BX,XMAX
 JG @offscrn
 SHL DI,1
 MOV DI,CS:[OFFSET gadr + DI]
 {DI = Y * LINESIZE, BX = X, Koordinaten zulÑssig}
 MOV AX,BX
 SHR AX,1
 SHR AX,1
 ADD DI,AX    {DI = Y * LINESIZE + (X SHR 2) }
 AND BL,3     {BL = X MOD 4 = Leseplane}
 MOV AL,4
 MOV AH,BL
 MOV DX,3CEh

 MOV ES,PAGEADR
 CLI
 OUT DX,AX
 MOV AL,ES:[DI]
 STI
@offscrn:
END;


FUNCTION BackgroundGetPixel(x,y:INTEGER):BYTE; ASSEMBLER;
{ in: x,y   = VIRTUELLE Punktkoordinaten des auszulesenden Punktes}
{     StartVirtualX, StartVirtualY = linke obere Bildschirmecke   }
{out: Farbe des Punktes der Hintergrundseite}
{rem: Liegt der Punkt au·erhalb des sichtbaren Bereichs, so wird  }
{     "0" als Ergebniswert zurÅckgeliefert}
{     Da als Hintergrundseite BACKGNDADR verwendet wird, ist die  }
{     Routine nur fÅr den Hintergrundmodus STATIC sinnvoll!       }
{     Falls EMS verwendet wird, so mu· die aufrufende Routine     }
{     sicherstellen, da· im EMS-Pageframe die benîtigten Daten    }
{     stehen (per "IF EMSused THEN EnsureEMSConsistency()" Aufruf)}
ASM
 XOR AL,AL              {AL mit 0 vorbesetzen}
 MOV DI,y
 SUB DI,StartVirtualY   {y in absolute Koordinaten umrechnen}
 JS @offscrn
 CMP DI,YMAX
 JG @offscrn
 MOV BX,x
 SUB BX,StartVirtualX   {x in absolute Koordinaten umrechnen}
 JS @offscrn
 CMP BX,XMAX
 JG @offscrn
 SHL DI,1
 MOV DI,CS:[OFFSET gadr + DI]
 {DI = Y * LINESIZE, BX = X, Koordinaten zulÑssig}
 MOV AX,BX
 SHR AX,1
 SHR AX,1
 ADD DI,AX    {DI = Y * LINESIZE + (X SHR 2) }
 AND BX,3     {BX := (x1 AND 4) }
 SHL BX,1     {*2, da WorteintrÑge}
 ADD DI,[OFFSET BACKTab + BX]  {Maske fÅr Zugriff holen: BX * 16000}
 MOV ES,BACKGNDADR
 MOV AL,ES:[DI]
@offscrn:
END;

FUNCTION PageGetPixel(x,y:INTEGER; pa:WORD):BYTE; ASSEMBLER;
{ in: x,y   = VIRTUELLE Punktkoordinaten des auszulesenden Punktes}
{     pa    = Grafikseite (0..3), von der der Punkt ausgelesen    }
{             werden soll}
{     StartVirtualX, StartVirtualY = linke obere Bildschirmecke   }
{out: Farbe des Punktes der Hintergrundseite}
{rem: Liegt der Punkt au·erhalb des sichtbaren Bereichs, so wird  }
{     "0" als Ergebniswert zurÅckgeliefert}
{     Soll von der gerade SICHTBAREN Seite gelesen werden, so ist }
{     beim Aufruf als Seite "1-PAGE" anzugeben!                   }
{     Sinnvolle Werte fÅr "pa" sind nur 0 und 1 (und evtl. BACK-  }
{     GNDPAGE, wenn der Hintergrundmodus STATIC benutzt wird), es }
{     findet jedoch keine öberprÅfung statt!}
ASM
 CMP pa,BACKGNDPAGE
 JNE @doit
 PUSH x
 PUSH y
 CALL BackgroundGetPixel
 JMP @offscrn

@doit:
 XOR AL,AL              {AL mit 0 vorbesetzen}
 MOV DI,y
 SUB DI,StartVirtualY   {y in absolute Koordinaten umrechnen}
 JS @offscrn
 CMP DI,YMAX
 JG @offscrn
 MOV BX,x
 SUB BX,StartVirtualX   {x in absolute Koordinaten umrechnen}
 JS @offscrn
 CMP BX,XMAX
 JG @offscrn
 SHL DI,1
 MOV DI,CS:[OFFSET gadr + DI]
 {DI = Y * LINESIZE, BX = X, Koordinaten zulÑssig}
 MOV AX,BX
 SHR AX,1
 SHR AX,1
 ADD DI,AX    {DI = Y * LINESIZE + (X SHR 2) }
 AND BX,3     {BL = X MOD 4 = Leseplane; BH = 0}
 MOV AL,4
 MOV AH,BL
 MOV BX,pa    {BX = Grafikseite}
 AND BX,3     {nur Seiten 0..3}
 SHL BX,1
 MOV ES,[BX +OFFSET Segment_Adr-StartIndex*2]

 CLI
 MOV DX,3CEh
 OUT DX,AX
 MOV AL,ES:[DI]
 STI
@offscrn:
END;


PROCEDURE PutPixel(x,y:INTEGER; color:Byte); ASSEMBLER;
{ in: x,y    = VIRTUELLE Punktkoordinaten des zu zeichnenden Punktes}
{     color  = Farbwert fÅr den zu zeichnenden Punkt}
{     1-PAGE = Grafikseite, auf der gezeichnet werden soll}
{     StartVirtualX, StartVirtualY = linke obere Bildschirmecke}
{     WinClip= TRUE, wenn Linie auf Win* Fenster geclippt werden soll}
{     WinXMIN,WinXMAX,WinYMIN,WinYMAX = Fenster fÅr evtl. Clipping}
{out: - }
{rem: Der Punkt (x,y) wurde in absolute Bildschirmkoordinaten umgerechnet  }
{     und gezeichnet (sofern er auf dem sichtbaren Bildschirmfenster liegt)}
{     Der Punkt wird NICHT automatisch in den Hintergrundspeicher Åber-    }
{     nommen, d.h.: er ist nur einen Animationszyklus lang sichtbar!       }
{     (Deshalb ist es sinnvoll, diese Routine NACH Aufruf von ANIMATE aus- }
{     zufÅhren, da der gezeichnete Punkt sonst sofort wieder verschwindet) }
ASM
 CMP WinClip,TRUE
 JE @goClip

 MOV DI,y
 SUB DI,StartVirtualY   {y in absolute Koordinaten umrechnen}
 JS @offscrn
 CMP DI,YMAX
 JG @offscrn
 MOV BX,x
 SUB BX,StartVirtualX   {x in absolute Koordinaten umrechnen}
 JS @offscrn
 CMP BX,XMAX
 JG @offscrn
 SHL DI,1
 MOV DI,CS:[OFFSET gadr + DI]
 {DI = Y * LINESIZE, BX = X, Koordinaten zulÑssig}
 MOV AX,BX
 SHR AX,1
 SHR AX,1
 ADD DI,AX    {DI = Y * LINESIZE + (X SHR 2) }
 AND BX,3
 MOV AH,[OFFSET TranslateTab + BX]
 MOV AL,2
 MOV DX,3C4h

 MOV BX,1     {ES := Segment_Adr[1-PAGE], denn 1-PAGE = sichtbare Seite}
 SUB BX,PAGE
 SHL BX,1
 MOV ES,[BX +OFFSET Segment_Adr-StartIndex*2]

 CLI
 OUT DX,AX
 MOV AL,color
 MOV ES:[DI],AL  {ab 386 schneller als STOSB!}
 STI
 JMP @ende

@goClip: {hierher, wenn Clipping auf Fenster}
 MOV DI,y
 SUB DI,StartVirtualY   {y in absolute Koordinaten umrechnen}
 CMP DI,WinYMIN
 JL @offscrn
 CMP DI,WinYMAX
 JG @offscrn
 MOV BX,x
 SUB BX,StartVirtualX   {x in absolute Koordinaten umrechnen}
 CMP BX,WinXMIN
 JL @offscrn
 CMP BX,WinXMAX
 JG @offscrn
 SHL DI,1
 MOV DI,CS:[OFFSET gadr + DI]
 {DI = Y * LINESIZE, BX = X, Koordinaten zulÑssig}
 MOV AX,BX
 SHR AX,1
 SHR AX,1
 ADD DI,AX    {DI = Y * LINESIZE + (X SHR 2) }
 AND BX,3
 MOV AH,[OFFSET TranslateTab + BX]
 MOV AL,2
 MOV DX,3C4h

 MOV BX,1     {ES := Segment_Adr[1-PAGE], denn 1-PAGE = sichtbare Seite}
 SUB BX,PAGE
 SHL BX,1
 MOV ES,[BX +OFFSET Segment_Adr-StartIndex*2]

 CLI
 OUT DX,AX
 MOV AL,color
 MOV ES:[DI],AL  {ab 386 schneller als STOSB!}
 STI
@offscrn:
@ende:
END;

PROCEDURE BackgroundPutPixel(x,y:INTEGER; color:Byte); ASSEMBLER;
{ in: x,y   = VIRTUELLE Punktkoordinaten des zu zeichnenden Punktes}
{     color = Farbwert fÅr den zu zeichnenden Punkt}
{     StartVirtualX, StartVirtualY = linke obere Bildschirmecke}
{     WinClip=TRUE, wenn Linie auf Win* Fenster geclippt werden soll}
{     WinXMIN,WinXMAX,WinYMIN,WinYMAX = Fenster fÅr evtl. Clipping}
{out: - }
{rem: Der Punkt (x,y) wurde in absolute Bildschirmkoordinaten umgerechnet und}
{     in den Hintergrund gezeichnet (sofern er im sichtbaren Bereich liegt)  }
{     Der Punkt wird NICHT sofort sichtbar, sondern erst nach einem Anima-   }
{     tionszyklus (dann aber permanent) (Deshalb ist es sinnvoll, diese Rou- }
{     tine VOR dem Aufruf von ANIMATE auszufÅhren, so da· evtl. énderungen   }
{     des Hintergrundes "sofort" sichtbar werden!)                           }
{     Da als Hintergrundseite BACKGNDADR verwendet wird, ist die Verwendung  }
{     der Routine nur fÅr den Hintergrundmodus STATIC sinnvoll!}
{     Falls EMS verwendet wird, so mu· die aufrufende Routine     }
{     sicherstellen, da· im EMS-Pageframe die benîtigten Daten    }
{     stehen (per "IF EMSused THEN EnsureEMSConsistency()" Aufruf)}
ASM
 CMP WinClip,TRUE
 JE @goClip

 MOV DI,y
 SUB DI,StartVirtualY   {y in absolute Koordinaten umrechnen}
 JS @offscrn
 CMP DI,YMAX
 JG @offscrn
 MOV BX,x
 SUB BX,StartVirtualX   {x in absolute Koordinaten umrechnen}
 JS @offscrn
 CMP BX,XMAX
 JG @offscrn
 SHL DI,1
 MOV DI,CS:[OFFSET gadr + DI]
 {DI = Y * LINESIZE, BX = X, Koordinaten zulÑssig}
 MOV AX,BX
 SHR AX,1
 SHR AX,1
 ADD DI,AX    {DI = Y * LINESIZE + (X SHR 2) }
 AND BX,3     {BX := (x1 AND 4) }
 SHL BX,1     {*2, da WorteintrÑge}
 ADD DI,[OFFSET BACKTab + BX]  {Maske fÅr Zugriff holen: BX * 16000}
 MOV ES,BACKGNDADR
 MOV AL,color
 MOV ES:[DI],AL  {ab 386 schneller als STOSB!}
 JMP @ende

@goClip: {hierher, wenn Clipping auf Fenster}
 MOV DI,y
 SUB DI,StartVirtualY   {y in absolute Koordinaten umrechnen}
 CMP DI,WinYMIN
 JL @offscrn
 CMP DI,WinYMAX
 JG @offscrn
 MOV BX,x
 SUB BX,StartVirtualX   {x in absolute Koordinaten umrechnen}
 CMP BX,WinXMIN
 JL @offscrn
 CMP BX,WinXMAX
 JG @offscrn
 SHL DI,1
 MOV DI,CS:[OFFSET gadr + DI]
 {DI = Y * LINESIZE, BX = X, Koordinaten zulÑssig}
 MOV AX,BX
 SHR AX,1
 SHR AX,1
 ADD DI,AX    {DI = Y * LINESIZE + (X SHR 2) }
 AND BX,3     {BX := (x1 AND 4) }
 SHL BX,1     {*2, da WorteintrÑge}
 ADD DI,[OFFSET BACKTab + BX]  {Maske fÅr Zugriff holen: BX * 16000}
 MOV ES,BACKGNDADR
 MOV AL,color
 MOV ES:[DI],AL  {ab 386 schneller als STOSB!}
@offscrn:
@ende:
END;

PROCEDURE PagePutPixel(x,y:INTEGER; color:BYTE; pa:WORD); ASSEMBLER;
{ in: x,y    = VIRTUELLE Punktkoordinaten des zu zeichnenden Punktes}
{     color  = Farbwert fÅr den zu zeichnenden Punkt}
{     pa     = Grafikseite (0..3), auf der gezeichnet werden soll   }
{     PAGEADR= Grafikseite(nsegment), auf der gezeichnet werden soll}
{     StartVirtualX, StartVirtualY = linke obere Bildschirmecke}
{     WinClip= TRUE, wenn Linie auf Win* Fenster geclippt werden soll}
{     WinXMIN,WinXMAX,WinYMIN,WinYMAX = Fenster fÅr evtl. Clipping}
{out: - }
{rem: Der Punkt (x,y) wurde in absolute Bildschirmkoordinaten umgerechnet  }
{     und gezeichnet (sofern er auf dem sichtbaren Bildschirmfenster liegt)}
{     Soll auf die gerade SICHTBARE Seite gezeichnet werden, so ist}
{     beim Aufruf als Seite "1-PAGE" anzugeben!                    }
{     Auch hier gilt, da· der gezeichnete Punkt NICHT automatisch  }
{     in den Hintergrundspeicher Åbernommen wird, d.h.: er ist nur }
{     bis zum nÑchsten Animationszyklus (= Aufruf von ANIMATE)     }
{     sichtbar! (Deshalb ist es sinnvoll, diese Routine NACH Aufruf}
{     von ANIMATE auszufÅhren, da der gezeichnete Punkt sonst so-  }
{     fort wieder verschwindet!)                                   }
{     Sinnvolle Werte fÅr "pa" sind nur 0 und 1 (und evtl. BACK-   }
{     GNDPAGE, wenn der Hintergrundmodus STATIC benutzt wird), es  }
{     findet jedoch keine öberprÅfung statt!}
ASM
 CMP pa,BACKGNDPAGE
 JNE @doit
 PUSH x
 PUSH y
 PUSH WORD PTR color
 CALL BackgroundPutPixel
 JMP @offscrn

@doit:
 CMP WinClip,TRUE
 JE @goClip

 MOV DI,y
 SUB DI,StartVirtualY   {y in absolute Koordinaten umrechnen}
 JS @offscrn
 CMP DI,YMAX
 JG @offscrn
 MOV BX,x
 SUB BX,StartVirtualX   {x in absolute Koordinaten umrechnen}
 JS @offscrn
 CMP BX,XMAX
 JG @offscrn
 SHL DI,1
 MOV DI,CS:[OFFSET gadr + DI]
 {DI = Y * LINESIZE, BX = X, Koordinaten zulÑssig}
 MOV AX,BX
 SHR AX,1
 SHR AX,1
 ADD DI,AX    {DI = Y * LINESIZE + (X SHR 2) }
 AND BX,3
 MOV AH,[OFFSET TranslateTab + BX]
 MOV AL,2
 MOV DX,3C4h
 MOV BX,pa    {BX = Grafikseite}
 SHL BX,1
 MOV ES,[BX +OFFSET Segment_Adr+StartIndex*2]

 CLI
 OUT DX,AX
 MOV AL,color
 MOV ES:[DI],AL  {ab 386 schneller als STOSB!}
 STI
 JMP @ende

@goClip: {hierher, wenn Clipping auf Fenster}
 MOV DI,y
 SUB DI,StartVirtualY   {y in absolute Koordinaten umrechnen}
 CMP DI,WinYMIN
 JL @offscrn
 CMP DI,WinYMAX
 JG @offscrn
 MOV BX,x
 SUB BX,StartVirtualX   {x in absolute Koordinaten umrechnen}
 CMP BX,WinXMIN
 JL @offscrn
 CMP BX,WinXMAX
 JG @offscrn
 SHL DI,1
 MOV DI,CS:[OFFSET gadr + DI]
 {DI = Y * LINESIZE, BX = X, Koordinaten zulÑssig}
 MOV AX,BX
 SHR AX,1
 SHR AX,1
 ADD DI,AX    {DI = Y * LINESIZE + (X SHR 2) }
 AND BX,3
 MOV AH,[OFFSET TranslateTab + BX]
 MOV AL,2
 MOV DX,3C4h
 MOV BX,pa    {BX = Grafikseite}
 SHL BX,1
 MOV ES,[BX +OFFSET Segment_Adr+StartIndex*2]

 CLI
 OUT DX,AX
 MOV AL,color
 MOV ES:[DI],AL  {ab 386 schneller als STOSB!}
 STI
@offscrn:
@ende:
END;

PROCEDURE LoadFont(s:STRING);
{ in: s = Name der zu ladenden Fontdatei, '' fÅr: interner Font}
{     FontType = Typ des aktuellen Fonts}
{out: CurrentFont=Zeiger auf neuen Font }
{     FontType = Typ des geladenen Fonts}
{     FontHeight=dessen Hîhe in Zeilen  }
{     FontWidth =dessen Breite in Pixeln}
{     FontProportion = TagProportional, falls Proportionalschrift}
{     FontWidthTable[] = Fontweite fÅr jeden Buchstaben}
{rem: Da initial "ResetToInternalFont" aufgerufen wurde, hat FontType}
{     bei Aufruf dieser Routine _immer_ einen definierten Wert!      }

    PROCEDURE ResetToInternalFont;
    VAR i,j:BYTE;
    BEGIN
     IF CurrentFont<>NIL  {allererster Aufruf?}
      THEN BEGIN {nein!}
            IF FontType=TagMonoFont
             THEN FreeMem(CurrentFont,SizeOf(MonoFont))
            ELSE IF FontType=TagColorFont
             THEN FreeMem(CurrentFont,SizeOf(ColorFont))
           END;
     IF MaxAvail<SizeOf(MonoFont)
      THEN BEGIN {nicht mal genug Speicher fÅr internen Font!}
            Error:=Err_NotEnoughMemory;
            exit
           END;
     GetMem(CurrentFont,SizeOf(MonoFont));
     FontType:=TagMonoFont;
     FontWidth:=6;
     FontHeight:=6;
     FontProportion:=0;
     FillChar(FontWidthTable,SizeOf(FontWidthTable),FontWidth);
     FOR i:=0 TO 255 DO
      FOR j:=0 TO FontHeight-1 DO
       MonoFont(CurrentFont^)[i][j]:=internalFont[i][j]
    END;

VAR f:FileOfByte;
CONST Tag:STRING='FNT';
VAR Header:STRING[3];
    size,i,j:WORD;
    newFontWidth,newFontHeight,newFontType,newFontProp:BYTE;
    tempName:STRING;
BEGIN
 IF s=''
  THEN BEGIN {umschalten auf internen Font}
        ResetToInternalFont;
        exit
       END;

 tempName:=FindFile(s);
 IF tempName<>'' THEN s:=tempName;

 {Fontdatei îffnen und Header auslesen:}
 _Assign(f,s);
 {$I-}
 _Reset(f);
 Header[0]:=CHAR(Length(Tag));
 _BlockRead(f,Header[1],Length(Tag));
 _BlockRead(f,newFontWidth,1);
 _BlockRead(f,newFontHeight,1);
 _BlockRead(f,newFontType,1);
 {$IFDEF IOcheck} {$I+} {$ENDIF}

 IF (IOresult<>0) OR (CompressError<>CompressErr_NoError)
  THEN BEGIN
        {$I-}
        _Close(f);
        {$IFDEF IOcheck} {$I+} {$ENDIF}
        Error:=Err_FileIO;
        CompressError:=CompressErr_NoError;
        exit;
       END;

 newFontProp:=newFontType AND TagProportional; {<>0, falls proportional}
 newFontType:=newFontType AND Pred(TagProportional);

 size:=Length(Tag)+3; {LÑnge des Headers}
 IF newFontType=TagMonoFont
  THEN inc(size,((newFontWidth+7) SHR 3)*newFontHeight SHL 8)
  ELSE inc(size,newFontWidth*newFontHeight SHL 8); {256 Zeichen}

 IF newFontProp=TagProportional THEN inc(size,256); {Fontweiten}

 IF (Header<>Tag) OR
    ( (newFontType<>TagMonoFont) AND (newFontType<>TagColorFont) ) OR
    (newFontWidth>MaxFontWidth) OR
    (newFontHeight>MaxFontHeight) OR
    (_FileSize(f)<>size)
  THEN BEGIN {kein FONT-File}
        Error:=Err_NoFont;
        {$I-}
        _Close(f);
        {$IFDEF IOcheck} {$I+} {$ENDIF}
        CompressError:=CompressErr_NoError;
        exit
       END;

 IF newFontType=TagMonoFont
  THEN size:=SizeOf(MonoFont)
  ELSE size:=SizeOf(ColorFont);

 {Nun alten Speicher freigeben und neuen besorgen:}
 IF FontType<>newFontType
  THEN BEGIN {nur nîtig, wenn alter und neuer Font verschieden sind}
        IF FontType=TagMonoFont THEN FreeMem(CurrentFont,SizeOf(MonoFont))
        ELSE {FontType=TagColorFont} FreeMem(CurrentFont,SizeOf(ColorFont));
        IF MaxAvail<size
         THEN BEGIN {nicht genug Speicher}
               Error:=Err_NotEnoughMemory;
               ResetToInternalFont;
               {$I-}
               _Close(f);
               {$IFDEF IOcheck} {$I+} {$ENDIF}
               exit
              END;
        GetMem(CurrentFont,size)
       END;

 FontWidth     :=newFontWidth;
 FontHeight    :=newFontHeight;
 FontType      :=newFontType;
 FontProportion:=newFontProp;

 IF FontType=TagMonoFont
  THEN BEGIN
        FOR i:=0 TO 255 DO
         BEGIN
          Fillchar(MonoFont (CurrentFont^)[i],SizeOf(MonoFontChar),0);
          FOR j:=0 TO FontHeight-1 DO
           {$I-}
           _BlockRead(f,MonoFont(CurrentFont^)[i][j],(FontWidth+7) SHR 3);
           {$IFDEF IOcheck} {$I+} {$ENDIF}
         END;
       END
  ELSE FOR i:=0 TO 255 DO
        FOR j:=0 TO FontHeight-1 DO
         {$I-}
         _BlockRead(f,ColorFont(CurrentFont^)[i][j],FontWidth);
         {$IFDEF IOcheck} {$I+} {$ENDIF}
 {$I-}
 IF FontProportion=TagProportional
  THEN _BlockRead(F,FontWidthTable,SizeOf(FontWidthTable))
  ELSE FillChar(FontWidthTable,SizeOf(FontWidthTable),FontWidth);
 _Close(f);
 {$IFDEF IOcheck} {$I+} {$ENDIF}
 CompressError:=CompressErr_NoError;  {evtl. Compress-Fehler zurÅcksetzen}
END;

FUNCTION OutTextLength(s:STRING):WORD;
{ in: s = Textstring}
{     Font* = Fontbeschreibungsdaten}
{out: Breite des auszugebenden Textes in _Pixeln_; hierbei werden}
{     Proportionalfonts korrekt behandelt}
VAR i:BYTE;
    temp:WORD;
BEGIN
 IF FontProportion=TagProportional
  THEN BEGIN
        temp:=0;
        FOR i:=1 TO length(s) DO inc(temp,FontWidthTable[BYTE(s[i])]);
       END
  ELSE temp:=FontWidth*length(s);
 OutTextLength:=temp
END;

PROCEDURE OutTextXY(x,y:INTEGER; pa:WORD; s:STRING);
{ in: (x,y)  = (virtuelle) Startkoordinaten des auszugebenden Textes}
{     s      = auszugebender Textstring                             }
{     pa     = Grafikseite, auf der der Text ausgegeben werden soll }
{     GraphTextColor=Textfarbe                                      }
{     GraphTextBackground=Farbe fÅr Texthintergrund;ist dieser Wert }
{            =GraphTextColor, so werden nur die Textpixel gezeichnet}
{             und die umgebenden Pixel unverÑndert gelassen (=nor-  }
{             males Verhalten von TurboPascal's OutText-Routinen!)  }
{     GraphTextOrientation="vertical" oder "horizontal"             }
{     StartVirtualX,StartVirtualY = linke obere Bildschirmecke      }
{     Font* = Fontbeschreibungsdaten}
{out: Text wurde auf dem Bildschirm ausgegeben                      }
VAR offs,z,bit,i,CharWidth:BYTE;
    data1:MonoFontchar;
    data2:ColorFontChar;
    b:WORD;
BEGIN
 IF (pa<0) OR (pa>SCROLLPAGE)
  THEN BEGIN
        Error:=Err_InvalidPageNumber;
        exit
       END;
 IF (pa=BACKGNDPAGE) AND EMSused
  THEN EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}
 offs:=MaxFontWidth-FontWidth;
 IF (FontType=TagMonoFont)
  THEN FOR i:=1 TO Length(s) DO
        BEGIN
         data1:=MonoFont(CurrentFont^)[BYTE(s[i])];
         CharWidth:=FontWidthTable[BYTE(s[i])];
         FOR z:=0 TO FontHeight-1 DO
          BEGIN
           b:=WORD(data1[z]);
           FOR bit:=0 TO CharWidth-1 DO
            IF b and FontMask[bit+offs]<>0
             THEN PagePutPixel(x+bit,y+z,GraphTextColor,pa)
             ELSE IF (GraphTextColor<>GraphTextBackground)
                   THEN PagePutPixel(x+bit,y+z,GraphTextBackground,pa);
          END;
         IF GraphTextOrientation=horizontal
          THEN INC(x,CharWidth)
          ELSE INC(y,FontHeight);
        END
  ELSE FOR i:=1 TO Length(s) DO
        BEGIN
         data2:=ColorFont(CurrentFont^)[BYTE(s[i])];
         CharWidth:=FontWidthTable[BYTE(s[i])];
         FOR z:=0 TO FontHeight-1 DO
          FOR bit:=0 TO CharWidth-1 DO
           BEGIN
            b:=data2[z][bit];
            IF b<>0 THEN PagePutPixel(x+bit,y+z,b,pa)
            ELSE IF (GraphTextColor<>GraphTextBackground)
                   THEN PagePutPixel(x+bit,y+z,GraphTextBackground,pa);
           END;
         IF GraphTextOrientation=horizontal
          THEN INC(x,CharWidth)
          ELSE INC(y,FontHeight);
        END
END;

PROCEDURE BackgroundOutTextXY(x,y:INTEGER; s:STRING);
{rem: Wie OutTextXY(), aber es wird in den Hintergrund geschrieben und}
{     nicht in die durch PAGEADR spezifizierte Seite!                 }
{     Da als Hintergrundseite BACKGNDADR verwendet wird, ist die      }
{     Routine nur fÅr den Hintergrundmodus STATIC sinnvoll!}
VAR offs,z,bit,i,CharWidth:BYTE;
    data1:MonoFontchar;
    data2:ColorFontChar;
    b:WORD;
BEGIN
 IF EMSused
  THEN EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}
 offs:=MaxFontWidth-FontWidth;
 IF (FontType=TagMonoFont)
  THEN FOR i:=1 TO Length(s) DO
        BEGIN
         data1:=MonoFont(CurrentFont^)[BYTE(s[i])];
         CharWidth:=FontWidthTable[BYTE(s[i])];
         FOR z:=0 TO FontHeight-1 DO
          BEGIN
           b:=WORD(data1[z]);
           FOR bit:=0 TO CharWidth-1 DO
            IF b and FontMask[bit+offs]<>0
             THEN BackgroundPutPixel(x+bit,y+z,GraphTextColor)
             ELSE IF (GraphTextColor<>GraphTextBackground)
                   THEN BackgroundPutPixel(x+bit,y+z,GraphTextBackground);
          END;
         IF GraphTextOrientation=horizontal
          THEN INC(x,CharWidth)
          ELSE INC(y,FontHeight);
        END
  ELSE FOR i:=1 TO Length(s) DO
        BEGIN
         data2:=ColorFont(CurrentFont^)[BYTE(s[i])];
         CharWidth:=FontWidthTable[BYTE(s[i])];
         FOR z:=0 TO FontHeight-1 DO
          FOR bit:=0 TO CharWidth-1 DO
           BEGIN
            b:=data2[z][bit];
            IF b<>0 THEN BackgroundPutPixel(x+bit,y+z,b)
            ELSE IF (GraphTextColor<>GraphTextBackground)
                   THEN BackgroundPutPixel(x+bit,y+z,GraphTextBackground);
           END;
         IF GraphTextOrientation=horizontal
          THEN INC(x,CharWidth)
          ELSE INC(y,FontHeight);
        END
END;

PROCEDURE MakeTextSprite(s:STRING; nr:WORD);
{ in: s  = in ein Sprite umzuwandelnder Text}
{     nr = SpriteLADEnummer fÅr das zu generierende Sprite}
{     Font*, CurrentFont = aktueller Font}
{     GraphTextOrientation = Fontausrichtung}
{out: Sprite?[nr] wurde so definiert, da· es den Textinhalt von "s" als}
{     Sprite enthÑlt}
{rem: Die Routine verhÑlt sich wie LoadSprite()}
CONST DefaultHeader:SpriteHeader=
       (Zeiger_auf_Plane:(0,0,0,0);
        Breite_in_4er_Gruppen:0;
        Hoehe_in_Zeilen:0;
        Translate:(1,2,4,8);
        SpriteLength:0;
        Dummy:(0,0,0,0,0,0,0,0,0,0);
        Kennung:'KR';
        Version:1;
        Modus:Display_NORMAL;
        ZeigerL:0;
        ZeigerR:0;
        ZeigerO:0;
        ZeigerU:0
       );
VAR header:SpriteHeader;
    p1,p2:POINTER;
    segm,offs,b:WORD;
    x,y,i:INTEGER;
    z,wert,bit,CharWidth:BYTE;
    data1:MonoFontchar;
    data2:ColorFontChar;
BEGIN
 IF (nr=0) or (nr>LoadMAX)
  THEN BEGIN
        Error:=Err_InvalidSpritenumber;
        Exit
       END;
 header:=DefaultHeader; {Schablone Åbernehmen}
 WITH header DO
  BEGIN
   IF GraphTextOrientation=horizontal
    THEN BEGIN {Sprite ist nur 1 Charzelle hoch}
          Hoehe_in_Zeilen:=FontHeight;
          Breite_in_4er_Gruppen:=(OutTextLength(s)+3) SHR 2
         END
    ELSE BEGIN {Sprite ist nur 1 Charzelle breit}
          Hoehe_in_Zeilen:=FontHeight*Length(s);
          Breite_in_4er_Gruppen:=(FontWidth+3) SHR 2
         END;
   SpriteLength:=Kopf+  {Spriteheader-Grî·e}
                 2*(2*Hoehe_in_Zeilen)+  {li. & re. Begrenzungen}
                 2*(2*4*Breite_in_4er_Gruppen)+  {ob. & un. Begrenzungen}
                 Breite_in_4er_Gruppen*4*Hoehe_in_Zeilen;  {Data}
   IF (Breite_in_4er_Gruppen*Hoehe_in_Zeilen=0)
      OR (SpriteLength>65521-15) {GetMem-Obergrenze=65521}
    THEN BEGIN
          Error:=Err_NoSprite;
          Exit
         END;
   {noch genug Platz da?}
   IF (Header.SpriteLength+15>MaxAvail+SPRITESIZE[nr])
    THEN BEGIN
          Error:=Err_NotEnoughMemory;
          Exit
         END
    ELSE FreeSpriteMem(nr);  {evtl. alten Speicher freigeben}

   getmem(p1,Header.SpriteLength+15);       {genug Platz reservieren}
   SPRITESIZE[nr]:=Header.SpriteLength+15;
   SPRITEPTR [nr]:=p1;
   IF (LONGINT(p1) mod 16)=0
    THEN p2:=p1                             {p2 auf Segmentgrenze bringen}
    ELSE LONGINT(p2):=LONGINT(p1) + (16-LONGINT(p1) mod 16);
   segm:=LONGINT(p2) SHR 16 +(LONGINT(p2) AND 65535) SHR 4;
   SPRITEAD[nr]:=segm;

   ZeigerL:=Kopf;
   ZeigerR:=ZeigerL+Hoehe_in_Zeilen*2;
   ZeigerO:=ZeigerR+Hoehe_in_Zeilen*2;
   ZeigerU:=ZeigerO+(Breite_in_4er_Gruppen*4)*2;
   FOR i:=0 TO 3 DO
    Zeiger_auf_Plane[i]:=ZeigerU+(Breite_in_4er_Gruppen*4)*2+
                         i*Breite_in_4er_Gruppen*Hoehe_in_Zeilen;
   FOR i:=0 TO Hoehe_in_Zeilen-1 DO
    BEGIN
     MEMW[segm:ZeigerL +i SHL 1]:=+16000;
     MEMW[segm:ZeigerR +i SHL 1]:=WORD(-16000);
    END;
   FOR i:=0 TO Breite_in_4er_Gruppen*4-1 DO
    BEGIN
     MEMW[segm:ZeigerO +i SHL 1]:=+16000;
     MEMW[segm:ZeigerU +i SHL 1]:=WORD(-16000);
    END;

   MOVE(Header,p2^,Kopf);  {Spriteheader auf Heap bringen}

   {jetzt Spritedaten berechnen: dazu Pixel in Speicher "zeichnen"}
   offs:=MaxFontWidth-FontWidth; x:=0; y:=0;
   IF (FontType=TagMonoFont)
    THEN FOR i:=1 TO Length(s) DO
          BEGIN
           data1:=MonoFont(CurrentFont^)[BYTE(s[i])];
           CharWidth:=FontWidthTable[BYTE(s[i])];
           FOR z:=0 TO FontHeight-1 DO
            BEGIN
             b:=WORD(data1[z]);
             FOR bit:=0 TO CharWidth-1 DO
              BEGIN
               IF b and FontMask[bit+offs]<>0
                THEN wert:=GraphTextColor
                ELSE IF (GraphTextColor<>GraphTextBackground)
                      THEN wert:=GraphTextBackground
                      ELSE wert:=0;
        {Punkt (a,b) -> b*Breite_in_4er_Gruppen+(x div 4) auf Plane x mod 4}
               MEM[segm:Zeiger_auf_Plane[(x+bit) AND 3]+
                        (y+z)*Breite_in_4er_Gruppen+
                        (x+bit) SHR 2]:=wert;
               IF wert<>0
	        THEN BEGIN {Grenzen evtl. neu berechnen}
                      IF x+bit<INTEGER(MEMW[segm:ZeigerL +(y+z) SHL 1])
                       THEN MEMW[segm:ZeigerL +(y+z) SHL 1]:=x+bit;
                      IF x+bit>INTEGER(MEMW[segm:ZeigerR +(y+z) SHL 1])
                       THEN MEMW[segm:ZeigerR +(y+z) SHL 1]:=x+bit;
                      IF y+z<INTEGER(MEMW[segm:ZeigerO +(x+bit) SHL 1])
                       THEN MEMW[segm:ZeigerO +(x+bit) SHL 1]:=y+z;
                      IF y+z>INTEGER(MEMW[segm:ZeigerU +(x+bit) SHL 1])
                       THEN MEMW[segm:ZeigerU +(x+bit) SHL 1]:=y+z;
                     END;
              END;
            END;
           IF GraphTextOrientation=horizontal
            THEN INC(x,CharWidth)
            ELSE INC(y,FontHeight);
          END
    ELSE FOR i:=1 TO Length(s) DO
          BEGIN
           data2:=ColorFont(CurrentFont^)[BYTE(s[i])];
           CharWidth:=FontWidthTable[BYTE(s[i])];
           FOR z:=0 TO FontHeight-1 DO
            FOR bit:=0 TO CharWidth-1 DO
             BEGIN
              b:=data2[z][bit];
              IF b<>0 THEN wert:=b
              ELSE IF (GraphTextColor<>GraphTextBackground)
                    THEN wert:=GraphTextBackground
                    ELSE wert:=0;
       {Punkt (a,b) -> b*Breite_in_4er_Gruppen+(x div 4) auf Plane x mod 4}
              MEM[segm:Zeiger_auf_Plane[(x+bit) AND 3]+
                       (y+z)*Breite_in_4er_Gruppen+
                       (x+bit) SHR 2]:=wert;

              IF wert<>0
	       THEN BEGIN {Grenzen evtl. neu berechnen}
                     IF x+bit<INTEGER(MEMW[segm:ZeigerL +(y+z) SHL 1])
                      THEN MEMW[segm:ZeigerL +(y+z) SHL 1]:=x+bit;
                     IF x+bit>INTEGER(MEMW[segm:ZeigerR +(y+z) SHL 1])
                      THEN MEMW[segm:ZeigerR +(y+z) SHL 1]:=x+bit;
                     IF y+z<INTEGER(MEMW[segm:ZeigerO +(x+bit) SHL 1])
                      THEN MEMW[segm:ZeigerO +(x+bit) SHL 1]:=y+z;
                     IF y+z>INTEGER(MEMW[segm:ZeigerU +(x+bit) SHL 1])
                      THEN MEMW[segm:ZeigerU +(x+bit) SHL 1]:=y+z;
                    END;
             END;
           IF GraphTextOrientation=horizontal
            THEN INC(x,CharWidth)
            ELSE INC(y,FontHeight);
          END

  END; {of WITH}

END;

FUNCTION Hitdetect(s1,s2:INTEGER):BOOLEAN; ASSEMBLER;
{ in: s1,s2 = Spritepositionsnummern zweier Sprites}
{     SpriteN[s1],SpriteX[s1],SpriteY[s1] = Spritedaten von Sprite s1    }
{     SpriteN[s2],SpriteX[s2],SpriteY[s2] = Spritedaten von Sprite s2    }
{out: TRUE/FALSE fÅr "Sprites kollidieren"/"Sprites kollidieren nicht"   }
{rem: Diese öberprÅfung geschieht punktgenau und ist unabhÑngig davon,   }
{     ob die Sprites z.Z. gerade sichtbar sind oder nicht.               }
{     Inaktive Sprites (SpriteN[s?]=0) kînnen nicht miteinander kollid.  }
{     Ein Sprite kann nicht mit sich selbst kollidieren (s1=s2 -> FALSE) }
ASM
     MOV SI,s1               {1.Parameter s1 vom Stack holen}
     MOV DI,s2               {2.Parameter s2 vom Stack holen}
     CMP SI,DI
     JE  @NOHIT1             {Sprite kann sich nicht selbst treffen}
     SHL SI,1
     mov cx,[SI + OFFSET SpriteN]
     jcxz @NOHIT1            {Sprite <>0, d.h.: Åberhaupt aktiv?}
     SHL DI,1
     MOV BX,[DI + OFFSET SpriteN]
     OR  BX,BX               {dto. fÅr anderes Sprite}
     JNE @PRUEF2
   @NOHIT1:
     JMP @NOHIT7             {inaktive Sprites kînnen auch nicht}
                             {kollidieren -> FALSE zurÅckgeben  }
{hier: SI (DI) = Zeiger auf 1. (2.) Sprite in ?WRTD[..] ,}
{      CX (BX) = Spritenummer von Sprite 1 (2)           }
{(etwas spÑter wird dann DS (ES) = Segment der Spr.daten von Spr.1 (2) )}
   @PRUEF2:
     MOV AX,[SI + OFFSET SpriteY]
     MOV DX,[DI + OFFSET SpriteY]
     mov si,[SI + OFFSET SpriteX]  {SI = x1}
     mov di,[DI + OFFSET SpriteX]  {DI = x2}
     shl bx,1                      {BX = Spritenummer2 * 2}
     mov es,[BX + OFFSET SPRITEAD] {ES = Segment der Spritedaten2}
     mov bx,cx                     {(CX = Spritenummer1)}
     shl bx,1                      {BX = Spritenummer1 * 2}
     MOV ds,[BX + OFFSET SPRITEAD]

     mov [y1],ax
     mov [y2],dx
     sub dx,ax
     mov CS:WORD PTR @y2_y1+1,dx
     mov [x1],si
     mov [x2],di
     mov dx,di
     sub dx,si
     mov CS:WORD PTR @x2_x1+1,dx
     mov ax,es:[Left]              {AX = Zeiger auf linke Randdaten}
     mov CS:WORD PTR @lirand2+1,ax
     mov ax,es:[Right]             {AX = Zeiger auf rechte Randdaten}
     mov CS:WORD PTR @rerand2+1,ax
     mov ax,es:[Top]               {AX = Zeiger auf obere Randdaten}
     mov CS:WORD PTR @orand2+1,ax
     mov ax,es:[Bottom]            {AX = Zeiger auf untere Randdaten}
     mov CS:WORD PTR @urand2+1,ax
     mov ax,es:[Breite]            {AX = max. Breite in 4er-Gruppen}
     shl al,1
     shl al,1
     mov CS:WORD PTR @breite2+1,ax {*4 = Breite in Punkten}
     mov ax,es:[Hoehe]
     mov CS:WORD PTR @hoehe2+1,ax  {Hîhe von Sprite2 in Punkten}

     MOV AX,[Left]                 {AX = Zeiger auf linke Randdaten}
     MOV CS:WORD PTR @LIRAND1+1,AX
     MOV AX,[Right]                {AX = Zeiger auf rechte Randdaten}
     MOV CS:WORD PTR @RERAND1+1,AX
     MOV AX,[Top]                  {AX = Zeiger auf obere Randdaten}
     MOV CS:WORD PTR @ORAND1+1,AX
     MOV AX,[Bottom]               {AX = Zeiger auf untere Randdaten}
     MOV CS:WORD PTR @URAND1+1,AX
     MOV BX,[Breite]               {BX = max. Breite in 4er-Gruppen}
     SHL BX,1
     SHL BX,1                      {*4 = Breite in Punkten}
     MOV CS:WORD PTR @BREITE1+2,BX

     lea bx,[si+bx-1]              {BX := x1 + breite1 - 1  (=x1last)}
   @breite2:
     mov bp,1234h                  {Dummywert}
     mov cx,bp                     {CX = breite2 brauchen wir spÑter nochmal}
     lea bp,[di+bp-1]              {BP := x2 + breite2 - 1  (=x2last)}
     cmp bx,bp
     jle @noex1
     mov bp,bx
   @noex1:                         {hier: BP = max(x1last,x2last)  (=maxx)}
     cmp si,di
     jle @X1_klgl_X2
     xchg si,di
   @X1_klgl_X2:                    {hier: SI = min(x1,x2)  (=minx)}
     stc
     sbb si,bp                     {SI := minx - maxx - 1 = - (maxx - minx + 1)}
   @breite1:
     add cx,1234h                  {(Dummywert)  CX := breite1 + breite2}
     add cx,si                     {CX := breite1 + breite2 - (maxx - minx + 1)}
     dec cx {CX := breite1 + breite2 - (maxx - minx + 1) - 1 (=ueberlappx - 1)}
     js @NOHIT2                    {kein Treffer, wenn ueberlappx <= 0}
     mov [ueberlappx_1],cx

     mov ax,[Hoehe]
     mov bx,ax                     {BX := hoehe1}
     mov di,[y1]                   {DI := y1}
     add ax,di                     {AX := y1 + hoehe1}
     dec ax                        {AX := y1 + hoehe1 - 1  (=y1last)}
   @hoehe2:
     mov si,1234h
     mov dx,[y2]
     add dx,si                     {DX := y2 + hoehe2}
     dec dx                        {DX := y2 + hoehe2 - 1  (=y2last)}
     cmp ax,dx
     jge @noex2
     mov ax,dx
   @noex2:                         {hier: AX = max(y1last,y2last)  (=maxy)}
     mov dx,[y2]
     cmp di,dx                     {(DI = y1)}
     jle @noex3
     mov di,dx
   @noex3:                         {hier: DI = min(y1,y2)  (=miny)}
     sub di,ax                     {DI := miny - maxy = - (maxy - miny)}
     lea ax,[bx+si-2]              {AX := hoehe1 + hoehe2 - 2}
     add ax,di {AX := hoehe1 + hoehe2 - (maxy - miny + 1) - 1 (=ueberlappy - 1)}
     js @NOHIT2                    {kein Treffer, wenn ueberlappy <= 0}
     mov [ueberlappy_1],ax

{hier: AX = ueberlappy - 1, CX = ueberlappx - 1}
   @x2_x1:
     mov dx,1234h                  {Dummywert}
     xor bx,bx                     {ab jetzt: BX = 0 !}
     or dx,dx
     js @X2_X1_kl_0                {if x2 - x1 >= 0 then...}
     mov [hit2xfirst],bx           {...hit2xfirst := 0}
     mov [hit1xfirst],dx           {...hit1xfirst := x2 - x1}
     jmp @Yhits    {SHORT}

{Sprungleiste fÅr NOHIT (pa·t hier gut hin)}
   @NOHIT2:
     JMP @NOHIT7

{jetzt wieder normales Programm}
   @X2_X1_kl_0:                    {else (x2 - x1 < 0)...}
     mov [hit1xfirst],bx           {...hit1xfirst := 0}
     neg dx                        {DX := x1 - x2}
     mov [hit2xfirst],dx           {...hit2xfirst := x1 - x2}

   @Yhits:                         {hier: AX = ueberlappy - 1}
   @y2_y1:
     mov dx,1234h                  {Dummywert}
     or dx,dx
     js @Y2_Y1_kl_0                {if y2 - y1 >= 0 then...}
     mov [hit2yfirst],bx           {...hit2yfirst := 0}
     mov [hit1yfirst],dx           {...hit1yfirst := y2 - y1}
     jmp @iterate  {SHORT}
   @Y2_Y1_kl_0:                    {else (y2 - y1 < 0)...}
     mov [hit1yfirst],bx           {...hit1yfirst := 0}
     neg dx                        {DX := y1 - y2}
     mov [hit2yfirst],dx           {...hit2yfirst := y1 - y2}

{Nun werden iterativ die Åberlappenden Zeilen und Spalten exakt geprÅft}
   @iterate:
     mov cx,[ueberlappy_1]         {Anzahl der zu vergleichenden Zeilen -1}
     shl cx,1                      {*2, da Word-Werte!}
   @lirand1:
     mov si,1234h                  {Dummywert}
   @lirand2:
     mov di,1234h                  {Dummywert}
   @rerand1:
     mov bx,1234h                  {Dummywert}
   @rerand2:
     mov bp,1234h                  {Dummywert}
     sub bx,si                     {BX := rerand1 - lirand1}
     sub bp,di                     {BP := rerand2 - lirand2}
     mov ax,[hit1yfirst]
     shl ax,1
     add si,ax                  {SI := 1.Zeile, in der Sp.1 mit Sp.2 Åberlappt}
     mov ax,[hit2yfirst]
     shl ax,1
     add di,ax                  {DI := 1.Zeile, in der Sp.2 mit Sp.1 Åberlappt}
     add si,cx                  {dto., letzte Zeile}
     add di,cx
   @one_line:
     mov ax,[si]                   {DS:AX := x1li[Zeile]}
     mov dx,es:[di]                {ES:DX := x2li[Zeile]}
     add ax,[x1]                   {AX := x1li[Zeile] + x1  (=c)}
     add dx,[x2]                   {DX := x2li[Zeile] + x2  (=d)}
     cmp ax,dx
     jge @C_grgl_D
     mov ax,dx
   @C_grgl_D:                      {hier: AX = max(c,d)}
     mov cx,[si+bx]                {DS:CX := x1re[Zeile]}
     mov dx,es:[di+bp]             {ES:DX := x2re[Zeile]}
     add cx,[x1]                   {CX := x1re[Zeile] + x1  (=a)}
     add dx,[x2]                   {DX := x2re[Zeile] + x2  (=b)}
     cmp cx,dx
     jle @A_klgl_B
     mov cx,dx
   @A_klgl_B:                      {hier: CX = min(a,b)}
     cmp cx,ax                     {min(a,b) >= max(c,d) ?}
     jge @found_Xhit               {ja: Treffer in X-Richtung gefunden!}
     dec si                        {nÑchste Zeile (-> Word-Werte!)}
     dec si
     dec di
     dec di
     dec WORD PTR [ueberlappy_1]
     jns @one_line
{kein Treffer in X-Richtung -> Åberhaupt kein Treffer!}
     jmp @NOHIT7

{ansonsten: Treffer in X-Ri., jetzt noch Y-Ri. prÅfen (analog zu oben) und  }
{"Treffer!" nur dann ausgeben, falls auch mind. 1 Treffer in Y-Ri. existiert}
   @found_Xhit:
     mov cx,[ueberlappx_1]         {Anzahl der zu vergleichenden Spalten -1}
     shl cx,1                      {*2, da Word-Werte!}
   @orand1:
     mov si,1234h                  {Dummywert}
   @orand2:
     mov di,1234h                  {Dummywert}
   @urand1:
     mov bx,1234h                  {Dummywert}
   @urand2:
     mov bp,1234h                  {Dummywert}
     sub bx,si                     {BX := urand1 - orand1}
     sub bp,di                     {BP := urand2 - orand2}
     mov ax,[hit1xfirst]
     shl ax,1                      {*2, da Word-Werte!}
     add si,ax                     {SI := orand1 + 2 * hit1xfirst}
     mov ax,[hit2xfirst]
     shl ax,1                      {*2, da Word-Werte!}
     add di,ax                     {DI := orand2 + 2 * hit2xfirst}
     add si,cx
     add di,cx
   @one_column: mov ax,[si]        {AX := y1ob[Spalte]}
     cmp ax,16000                  {Dummywert fÅr "leere Spalte"?}
     je @next_column               {ja, also sicherlich kein Treffer}
     mov dx,es:[di]                {DX := y2ob[Spalte]}
     cmp dx,16000                  {auch 2.Sprite prÅfen: "leere Spalte"?}
     je @next_column               {ja, kein Treffer}
     add ax,[y1]                   {AX := y1ob + y1  (=c)}
     add dx,[y2]                   {DX := y2ob + y2  (=d)}
     cmp ax,dx
     jge @C_grgl_D2
     mov ax,dx
   @C_grgl_D2:                     {hier: AX = max(c,d)}
     mov cx,[si+bx]                {DS:CX := y1un[Spalte]}
     mov dx,es:[di+bp]             {ES:DX := y2un[Spalte]}
     add cx,[y1]                   {CX := y1un + y1  (=a)}
     add dx,[y2]                   {DX := y2un + y2  (=b)}
     cmp cx,dx
     jle @A_klgl_B2
     mov cx,dx
   @A_klgl_B2:                     {hier: CX = min(a,b)}
     cmp cx,ax                     {min(a,b) >= max(c,d) ?}
     jge @HIT2                     {ja: Treffer gefunden!}
   @next_column:
     dec si                        {nein, nÑchste Spalte (-> Word-Werte!)}
     dec si
     dec di
     dec di
     dec WORD PTR [ueberlappx_1]
     jns @one_column

   @NOHIT7:
     XOR AX,AX                     {als Ergebnis 0 = FALSE zurÅckgeben}
     JMP @TREFF_END  {SHORT}
   @HIT2:
     MOV AX,1                      {als Ergebnis 1 = TRUE zurÅckgeben}

   @TREFF_END:
   {$IFOPT G+}
     mov bp,sp                     {nur nîtig fÅr Compilerschalter G+!}
   {$ENDIF}
     mov dx,seg @DATA              {sonst wird BP von TP wiederhergestellt}
     mov ds,dx
END;

PROCEDURE SetSplitIndex(number:INTEGER);
{ in: number = Index-Nummer des Sprites, bis zu dem die Sprites nicht}
{              auf das Animationsfenster zurechtgeklippt werden}
{out: - }
{rem: Nach Aufruf dieser Routine werden SpriteN[0..number] nicht- und}
{     SpriteN[number+1..NMAX] auf das Animationsfenster zurechtgeclipt}
{     Ist number <0 oder >NMAX, so werden alle Sprites geclipt!}
BEGIN
 IF number>NMAX THEN number:=-1;
 SplitIndex:=number;
 SplitIndex_mal2:=number*2
END;

FUNCTION GetSplitIndex:INTEGER;
{ in: - }
{out: Momentan gesetzter Wert fÅr SplitIndex}
BEGIN
 GetSplitIndex:=SplitIndex
END;

PROCEDURE SetAnimateWindow(x1,y1,x2,y2:INTEGER);
{ in: (x1,y1) = linke obere Ecke des zu setzenden Animationsbereiches}
{     (x2,y2) = dto., rechte untere Ecke}
{out: Win* wurden entsprechend neugesetzt}
{     BWin* = Backups der wichtigsten Werte}
{rem: Die Punkte mÅssen in absoluten Koordinaten angegeben werden}
{     Das Fenster mu· eine Mindestgrî·e von 32x32 Punkten haben, }
{     x1 und x2-x1+1 mÅssen Vielfache von 4 sein (oder werden darauf gebracht)!}
BEGIN
 x1:=x1 AND $FFFC;  {x1 auf Vielfaches von 4 bringen}
 WinXMIN:=x1; WinXMINdiv4:=x1 SHR 2;
 WinYMIN:=y1; WinYMIN_mul_LINESIZE:=y1*LINESIZE;
 WinYMINmLINESIZEaWinXMINdiv4:=WinYMIN_mul_LINESIZE+WinXMINdiv4;
 WinWidth :=succ(x2-x1) AND $FFFC;  {Weite auf Vielfaches von 4 bringen}
 WinHeight:=succ(y2-y1);
 WinXMAX:=WinXMIN+WinWidth-1;
 WinYMAX:=WinYMIN+WinHeight-1;
 WinWidthDiv4:=WinWidth SHR 2;
 WinLowerRight:=(XMAX-WinXMAX) SHR 2 + (YMAX-WinYMAX)*LINESIZE;
 IF (WinXMIN<0) OR (WinYMIN<0) OR (WinWidth<32) OR (WinHeight<32) OR
    (WinXMAX>XMAX) OR (WinYMAX>YMAX)
  THEN Error:=Err_InvalidCoordinates;

 BWinXMIN:=WinXMIN; {Backups anlegen}
 BWinYMIN:=WinYMIN;
 BWinXMAX:=WinXMAX;
 BWinYMAX:=WinYMAX;
 BWinLowerRight:=WinLowerRight;
 BWinYMIN_mul_LINESIZE:=WinYMIN_mul_LINESIZE
END;
                                     
PROCEDURE Animate;
{ in: PAGEADR = aktuelle Grafikseite(nadresse),auf der gezeichnet werden soll}
{     BACKGNDADR = Hintergrundseite(nadresse) }
{     BACKGROUNDMODE = STATIC/SCROLLING fÅr festen/scrollbaren Hintergrund}
{     SpriteN[] = Spritenummern der darzustellenden Sprites }
{     SpriteX[],SpriteY[] = deren zugehîrigen (virtuellen) Koordinaten}
{     StartVirtualX,StartVirtualY = obere linke Bildschirmecke  }
{     (PAGE = aktuell dargestellte Grafikseite) }
{     Win* = Abmessungen des Hintergrundwindows }
{out: PAGE = 0/1, wenn PAGE vorher 1/0 war }
{     PAGEADR = neue, aktuelle Grafikseite(nadresse) }
{rem: Animate lîscht den Inhalt der alten Grafik (mithilfe der Hintergrund-  }
{     seite), zeichnet alle sichtbaren Sprites, synchronisiert auf das dis-  }
{     playenable-Signal und schaltet dann auf die so fertiggestellte Seite um}
VAR leftcut,rightcut,topcut,bottomcut:WORD;
    {x,y,} xtil,ytil,actindex:INTEGER;

    KachelnWegLinks,KachelnWegOben,
    innerTilesX,innerTilesY,
    stepX1,stepX2,
    Xoffscreen,Yoffscreen,
    counter,
    Korrektur,
    BytesPerPlane,LINESIZE_sub_BytesPerPlane,
    leftcutDIV4,
    tempActIndex,tempDI,tempXtil,tempYtil,{tempX,tempY,}
    oldActIndex,oldDI,
    StartWritePlane,StartLesePlane: INTEGER;
BEGIN
 IF EMSused AND (BackgroundMode=STATIC)
  THEN EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}
 ASM
    CLD
    {zuerst das Hintergrundbild auf die aktuelle Seite kopieren:}
    CMP BackgroundMode,STATIC   {welcher Hintergrundmodus?}
    JE @static_bckgnd
    JMP @scrolling_bckgnd

  @static_bckgnd:
    MOV BX,WinHeight
    MOV DX,WinWidth
    MOV SI,WinYMINmLINESIZEaWinXMINdiv4  {1.Start/Zieladresse}
    MOV DI,SI

    MOV ES,PAGEADR              {Grafikseite mit Hintergrundmuster fÅllen}
    CMP UpdateOuterArea,0       {Ñu·eren Hintergrund updaten?}
    MOV DS,BACKGNDADR

    je @skip_outer
    {inneren und Ñu·eren Hintergrund zugleich erledigen}
    xor si,si
    xor di,di

    mov ax,0102h
    mov dx,3c4h
    mov bx,pagesize/2
    out dx,ax {Schreibplane 0}
    mov cx,bx
    rep movsw
    mov ah,2
    out dx,ax {Schreibplane 1}
    mov cx,bx
    xor di,di
    rep movsw
    mov ah,4
    out dx,ax {Schreibplane 2}
    mov cx,bx
    xor di,di
    rep movsw
    mov ah,8
    out dx,ax {Schreibplane 3}
    mov cx,bx
    xor di,di
    rep movsw
    mov ax,seg @data
    mov ds,ax
    dec UpdateOuterArea
    jmp @sprites_zeichnen
   @skip_outer:  {nur Inneres zeichnen}

    PUSH BP

    CMP DX,XMAX+1               {Fenster durchgehend von links nach rechts?}
    JNE @innen

    MOV AX,0102h
    MOV DX,3C4h
    SHL BX,1                    {ja, kann mit einem REP MOVSB erledigt werden}
    MOV BX,CS:[OFFSET gadr + BX]   {BX := WinHeight * LINESIZE}
    MOV BP,PAGESIZE
    SUB BP,BX

    OUT DX,AX  {Schreibplane 0 anwÑhlen}
    MOV CX,BX
    SHR CX,1
    REP MOVSW
    ADC CX,CX
    REP MOVSB
    SUB DI,BX  {DI zurÅckstellen}
    ADD SI,BP  {SI auf nÑchste "Plane" setzen}

    MOV AH,2
    OUT DX,AX  {Schreibplane 1 anwÑhlen}
    MOV CX,BX
    SHR CX,1
    REP MOVSW
    ADC CX,CX
    REP MOVSB
    SUB DI,BX  {DI zurÅckstellen}
    ADD SI,BP  {SI auf nÑchste "Plane" setzen}

    MOV AH,4
    OUT DX,AX  {Schreibplane 2 anwÑhlen}
    MOV CX,BX
    SHR CX,1
    REP MOVSW
    ADC CX,CX
    REP MOVSB
    SUB DI,BX  {DI zurÅckstellen}
    ADD SI,BP  {SI auf nÑchste "Plane" setzen}

    MOV AH,8
    OUT DX,AX  {Schreibplane 3 anwÑhlen}
    MOV CX,BX
    SHR CX,1
    REP MOVSW
    ADC CX,CX
    REP MOVSB

    jmp @end_static

  @innen:
    SHR DX,1
    SHR DX,1                    {DX := Bytes je Zeile}
    MOV BP,LINESIZE
    SUB BP,DX                   {BP := Offset zur nÑchsten Zeile}
    MOV BH,DL
    XOR CH,CH

    MOV AX,0102h
    MOV DX,3C4h
    OUT DX,AX    {Schreibplane 0 anwÑhlen}

    MOV AH,BL

    PUSH SI
    PUSH DI
  @loop_innen1:
    MOV CL,BH
    SHR CX,1
    REP MOVSW
    ADC CX,CX
    REP MOVSB                   {eine Zeile Åbertragen}
    ADD SI,BP                   {auf nÑchste Zeile positionieren}
    ADD DI,BP
    DEC BL                      {eine Zeile fertig}
    JNZ @loop_innen1
    POP DI
    POP SI

    ADD SI,PAGESIZE
    PUSH SI
    PUSH DI
    MOV BL,AH
    MOV AH,02h
    OUT DX,AX
    MOV AH,BL
  @loop_innen2:
    MOV CL,BH
    SHR CX,1
    REP MOVSW
    ADC CX,CX
    REP MOVSB                   {eine Zeile Åbertragen}
    ADD SI,BP                   {auf nÑchste Zeile positionieren}
    ADD DI,BP
    DEC BL                      {eine Zeile fertig}
    JNZ @loop_innen2
    POP DI
    POP SI

    ADD SI,PAGESIZE
    PUSH SI
    PUSH DI
    MOV BL,AH
    MOV AH,04h
    OUT DX,AX
    MOV AH,BL
  @loop_innen3:
    MOV CL,BH
    SHR CX,1
    REP MOVSW
    ADC CX,CX
    REP MOVSB                   {eine Zeile Åbertragen}
    ADD SI,BP                   {auf nÑchste Zeile positionieren}
    ADD DI,BP
    DEC BL                      {eine Zeile fertig}
    JNZ @loop_innen3
    POP DI
    POP SI

    ADD SI,PAGESIZE
    MOV BL,AH
    MOV AH,08h
    OUT DX,AX
    MOV AH,BL
  @loop_innen4:
    MOV CL,BH
    SHR CX,1
    REP MOVSW
    ADC CX,CX
    REP MOVSB                   {eine Zeile Åbertragen}
    ADD SI,BP                   {auf nÑchste Zeile positionieren}
    ADD DI,BP
    DEC BL                      {eine Zeile fertig}
    JNZ @loop_innen4

  @end_static:
    POP BP
    MOV AX,SEG @DATA
    MOV DS,AX

    JMP @Sprites_zeichnen

  {---------------------------------}

  @scrolling_bckgnd:      {ab hier: Hintergrund aus Kacheln zusammensetzen}

   {mÅssen wir das éu·ere um das Animationswindow neuzeichnen?}
    cmp UpdateOuterArea,0
    je @old_scrolling_bckgnd
    {ja, aber vielleicht gar nichts zum zeichnen da?:}
    mov bx,WinHeight
    dec bx
    mov bh,bl
    mov bl,WinWidthDiv4
    mov ax,WinYMINmLINESIZEaWinXMINdiv4
    {BL=WinWidthDiv4, BH=WinHeight-1, AX=WinYMIN*LINESIZE+WinXMIN DIV 4}
    or ax,ax      {linke obere Ecke des Windows = Punkt (0,0)?}
    jne @do_outer {nein: Ñu·erer Rand zu zeichnen}
    cmp bx,YMAX SHL 8 +LINESIZE  {rechte untere Ecke = Punkt (XMAX,YMAX)?}
    je @old_scrolling_bckgnd  {ja, also kein Ñu·erer Rand zu zeichnen}

  @do_outer: {jetzt Ñu·eren Rand zeichnen}
    {…ÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕª Einteilung des Ñu·eren Randes in 3 Regionen}
    {∫1111111111111111∫ }
    {∫1111111111111111∫ }
    {∫111⁄ƒƒƒƒƒƒƒø2222∫ }
    {∫222≥       ≥2222∫ }
    {∫222≥       ≥2222∫ }
    {∫222¿ƒƒƒƒƒƒƒŸ3333∫ }
    {∫3333333333333333∫ }
    {∫3333333333333333∫ }
    {»ÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕÕº }

    {BL=WinWidthDiv4, BH=WinHeight-1, AX=WinYMIN*LINESIZE+WinXMIN DIV 4}
    push bp
    push WinLowerRight
    mov bp,ax
    mov es,PAGEADR
    mov ds,BACKGNDADR
    mov dx,3C4h
    mov ax,0102h {Schreibplane 0}
    out dx,ax
    xor si,si   {Region 1 beginnt bei Offset 0}
    xor di,di
    mov cx,bp
    shr cx,1
    rep movsw
    adc cx,cx
    rep movsb

    mov ah,2    {Schreibplane 1}
    out dx,ax
    mov si,1*PAGESIZE
    xor di,di
    mov cx,bp
    shr cx,1
    rep movsw
    adc cx,cx
    rep movsb

    mov ah,4    {Schreibplane 2}
    out dx,ax
    mov si,2*PAGESIZE
    xor di,di
    mov cx,bp
    shr cx,1
    rep movsw
    adc cx,cx
    rep movsb

    mov ah,8    {Schreibplane 3}
    out dx,ax
    mov si,3*PAGESIZE
    xor di,di
    mov cx,bp
    shr cx,1
    rep movsw
    adc cx,cx
    rep movsb

    mov ah,1
    out dx,ax

    mov al,bl
    cbw       {AX:=WinWidth DIV 4; geht, weil WinWidth DIV 4 < 128 !}
    mov dl,LINESIZE
    sub dl,al {DL:=LINESIZE-WinWidth DIV 4}
    jz @region3 {Fenster geht von links nach rechts durch?}
    mov dh,bh {DH:=WinHeight-1}
    or dh,dh
    jz @region3 {Fenster nur 1 Zeile hoch?}
    xor ch,ch
    mov bx,ax
    add di,ax
    mov si,di {Zieladresse=Startadresse wg. Speicherlayout}

    mov bp,di
    push dx
  @region2a:
    {DL = Breite einer Zeile des Animationsfensters}
    {DH = WinHeight-1}
    {BX = WinWidth DIV 4 = Breite des Animations-Fensters DIV 4}
    {CX:=Breite einer Zeile vom rechten Rand des Animationsfensters zum}
    {linken Rand des Animationsfensters in der nÑchsten Zeile:}
    mov cl,dl  {ch=0}
    shr cx,1
    rep movsw
    adc cx,cx
    rep movsb
    add si,bx
    add di,bx
    dec dh
    jnz @region2a

    mov ax,0202h
    mov dx,3c4h
    out dx,ax
    pop dx
    push dx
    mov si,bp {SI=DI=BP fÅr Plane #0, SI=DI+1*PAGESIZE fÅr Plane #1, etc.}
    add si,1*PAGESIZE
    mov di,bp
  @region2b:
    mov cl,dl  {ch=0}
    shr cx,1
    rep movsw
    adc cx,cx
    rep movsb
    add si,bx
    add di,bx
    dec dh
    jnz @region2b

    mov ah,04h
    mov dx,3c4h
    out dx,ax
    pop dx
    push dx
    mov si,bp
    add si,2*PAGESIZE
    mov di,bp
  @region2c:
    mov cl,dl  {ch=0}
    shr cx,1
    rep movsw
    adc cx,cx
    rep movsb
    add si,bx
    add di,bx
    dec dh
    jnz @region2c

    mov ah,08h
    mov dx,3c4h
    out dx,ax
    pop dx
    mov si,bp
    add si,3*PAGESIZE
    mov di,bp
  @region2d:
    mov cl,dl  {ch=0}
    shr cx,1
    rep movsw
    adc cx,cx
    rep movsb
    add si,bx
    add di,bx
    dec dh
    jnz @region2d


  @region3:
    pop cx  {CX:=WinLowerRight}
    jcxz @endregion3 {keine Region 3 zum zeichnen}
    mov bx,cx  {Kopie davon nach BX}
    mov si,PAGESIZE
    sub si,cx  {Startadresse von Region 3}
    mov di,si  {Zieladresse:=Startadresse (geht wg. Speicherlayout!)}
    mov bp,di  {Zieladresse merken }
    mov ax,0102h
    mov dx,3c4h
    out dx,ax
    shr cx,1
    rep movsw
    adc cx,cx
    rep movsb

    mov ah,2
    out dx,ax
    mov cx,bx
    mov di,bp
    sub si,cx  {SI auf alten Wert zurÅck- und dann eine "Seite" weitersetzen}
    add si,PAGESIZE
    shr cx,1
    rep movsw
    adc cx,cx
    rep movsb

    mov ah,4
    out dx,ax
    mov cx,bx
    mov di,bp
    sub si,cx  {SI auf alten Wert zurÅck- und dann eine "Seite" weitersetzen}
    add si,PAGESIZE
    shr cx,1
    rep movsw
    adc cx,cx
    rep movsb

    mov ah,8
    out dx,ax
    mov cx,bx
    mov di,bp
    sub si,cx  {SI auf alten Wert zurÅck- und dann eine "Seite" weitersetzen}
    add si,PAGESIZE
    shr cx,1
    rep movsw
    adc cx,cx
    rep movsb

  @endregion3:
    pop bp
    mov ax,seg @data
    mov ds,ax
    dec UpdateOuterArea  {UpdateOuterArea rÅcksetzen}

  @old_scrolling_bckgnd:

  MOV DI,$F  {hÑufig benutzte Konstanten}
  MOV CX,4

 {#Kacheln, die links _echt_ weggeschnitten sind:}
 {IF StartVirtualX+WinXMIN-BackX1<0
   THEN KachelnWegLinks:=(StartVirtualX+WinXMIN-BackX1-15) DIV 16
   ELSE KachelnWegLinks:=(StartVirtualX+WinXMIN-BackX1) DIV 16;}
  MOV AX,StartVirtualX
  ADD AX,WinXMIN
  SUB AX,BackX1
  MOV BX,AX     {BX = StartVirtualX + WinXMIN - BackX1}
  SAR AX,CL
  MOV KachelnWegLinks,AX

 {Punkte, die der 1. (teilweise) sichtbaren Kachel links weggeschnitten sind:}
 {eigentlich: leftcut := ((StartVirtualX + WinXMIN - BackX1) MOD 16) AND $F  }
 {aber das ist Ñquivalent zu:}
 {leftcut := (StartVirtualX + WinXMIN - BackX1) AND $F}
 {das "AND $F" ist wg. evtl. underflow <0}
  AND BX,DI
  MOV leftcut,BX

  MOV AX,BX
  SHR AX,1
  SHR AX,1
  MOV leftcutDIV4,AX

 {Start-Leseplane links geschnittener Kacheln berechnen: leftcut AND 3}
 { Dann wird die zugehîrige Maske daraus errechnet }
  MOV AH,BL      {BL = leftcut}
  AND AH,3
  MOV AL,4
  MOV StartLesePlane,AX   {mu· im Stacksegment liegen!}

 {dto., fÅr letzte (teilweise) sichtbare Kachel rechts}
 {eigentlich: rightcut := (16 - leftcut - (WinWidth MOD 16)) AND $F, aber s.o.!}
 {rightcut := (16 - leftcut - WinWidth) AND $F}
 {das "AND $F" ist wg. evtl. underflow <0}
  NEG BX     {BX=-leftcut}
  MOV SI,WinWidth
  MOV AX,16
  ADD AX,BX
  SUB AX,SI
  AND AX,DI  {AX = (16 - leftcut - WinWidth) AND $F}
  MOV rightcut,AX

 {#_ganzer_ Kacheln im Inneren des Windows je Zeile:}
 {innerTilesX:=(WinWidth - (-rightcut AND $F) - (-leftcut AND $F)) SHR 4;}
  NEG AX
  AND AX,DI
  AND BX,DI
  SUB SI,AX
  SUB SI,BX
  SHR SI,CL
  MOV innerTilesX,SI

 {stepX1=Additionsfaktor, um von rechtester (evtl. nur teilweise) sichtbaren}
 {       Kachel einer Zeile zur 1. _links nicht geschnittenen_ Kachel der   }
 {       nÑchsten Zeile zu kommen}
 {stepX2=dto., aber zur 1. (evtl. nur teilweise) sichtbaren Kachel der      }
 {       nÑchsten Zeile}
 {stepX1 := XTiles -(innerTilesX);}
 {stepX2 := stepX1;}
 {IF leftcut<>0 THEN dec(stepX2)} {stepX2 = XTiles -(innerTiles + (leftcut<>0))}
  MOV DX,XTiles
  MOV AX,DX
  SUB AX,SI
  MOV stepX1,AX
  OR BX,BX      {fÅr den geg. Bereich gilt: leftcut = 0 <-> -leftcut and $F=0}
  JE @nodec
  DEC AX
 @nodec:
  MOV stepX2,AX


 {Start-Writeplane links nicht geschnittener Kacheln berechnen:}
 { (WinXMIN - leftcut) AND 3, wird hier berechnet per }
 { (WinXMIN - (leftcut AND $F) AND 3}
 { Dann wird die zugehîrige Maske daraus errechnet }
  ADD BX,WinXMIN
  AND BX,3
  MOV AH,CS:[OFFSET CS_TranslateTab +BX]
  MOV AL,2
  MOV StartWritePlane,AX  {mu· im Stacksegment liegen!}


 {nun analog fÅr Y-Richtung:}
 {IF StartVirtualY+WinYMIN-BackY1<0
  THEN KachelnWegOben := (StartVirtualY + WinYMIN - BackY1 - 15) DIV 16
  ELSE KachelnWegOben := (StartVirtualY + WinYMIN - BackY1) DIV 16;}
  MOV AX,StartVirtualY
  ADD AX,WinYMIN
  SUB AX,BackY1
  MOV BX,AX
  SAR AX,CL
  MOV KachelnWegOben,AX

 {Index der 1. (evtl. nur teilweise) sichtbaren Kachel berechnen:}
 {actIndex := KachelnWegOben * XTiles + KachelnWegLinks + 1;}
 {Die "+1" ist, da BackTile[]-ZÑhlung bei 0 beginnt, um BackTile[0]}
 {als OffscreenTile freizuhalten!}
  IMUL DX
  ADD AX,KachelnWegLinks
  INC AX
  MOV actIndex,AX

 {topcut := (StartVirtualY + WinYMIN - BackY1) AND $F;}
  AND BX,DI
  MOV topcut,BX

 {bottomcut := (16 - topcut - WinHeight) AND $F;}
  NEG BX
  MOV SI,WinHeight
  MOV AX,16
  ADD AX,BX
  SUB AX,SI
  AND AX,DI
  MOV bottomcut,AX

 {innerTilesY := (WinHeight - (-bottomcut AND $F) - (-topcut AND $F)) SHR 4;}
  NEG AX
  AND AX,DI
  AND BX,DI
  SUB SI,AX
  SUB SI,BX
  SHR SI,CL
  MOV innerTilesY,SI

  {---Jetzt zeichnen!---}

  { entfÑllt, da bereits in SetAnimateWindow() gesetzt:
  MOV AX,WinXMIN
  (* MOV x,AX *)
  MOV BX,WinYMIN
  (* MOV y,BX *)
  SHR AX,1
  SHR AX,1
  MOV WinXMINdiv4,AX
  SHL BX,1
  MOV BX,CS:[OFFSET GADR +BX]
  MOV WinYMIN_mul_LINESIZE,BX
  ADD AX,BX
  MOV WinYMINmLINESIZEaWinXMINdiv4,AX
  }

  MOV AX,KachelnWegLinks
  MOV xtil,AX
  MOV CX,AX  {CX = Kopie von KachelnWegLinks = xtil}
  MOV AX,KachelnWegOben
  MOV ytil,AX

  MOV ES,PAGEADR  {ein fÅr allemal!}
  MOV BX,leftcut
  {Hier gilt: AX = ytil, BX = Leftcut, CX = xtil, ES = ^Grafiksegment}
  TEST BL,3      {leftcut MOD 4 = 0 ?}
  JZ @useMode1   {ja, Writemode1 nutzbar}
  JMP @useMode0  {nein, Writemode0 verwenden}

 @useMode1:
  {Wenn Fensterbreite Vielfaches von 4, leftcut mod 4=0 und linke Fenstergrenze}
  {auf Vielfaches von 4 fÑllt (dann ist damit auch rightcut mod 4=0) und       }
  {durchgehend Writemode1 anwendbar!}
  MOV AX,4105h   {Writemode1 einschalten}
  MOV DX,3CEh
  OUT DX,AX
  MOV AX,0F02h   {alle 4 Planes gleichzeitig ansprechen}
  MOV DX,3C4h
  OUT DX,AX

  CMP topcut,0      {IF ytil Ó [0..YTiles(          }
  JE @m1SkipTopRow  { THEN DX = Yoffscreen := $FFFF }
  MOV AX,ytil       { ELSE DX = Yoffscreen := $0000 }
  CWD
  SUB AX,YTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  MOV Yoffscreen,DX

  MOV AX,WinXMINdiv4  {AX =richtiger Wert, falls gesprungen wird!}
  OR BX,BX   {BX=leftcut}
  JZ @m1SkipTopLeftCorner

  MOV SI,actIndex     {IF (xtil < 0) OR (xtil >= XTiles) OR Yoffscreen }
  AND SI,DX           { THEN SI := 0 }
  JZ @m1go1           { ELSE SI := actIndex }
  MOV AX,CX  {CX = xtil}
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX

 @m1go1:
    {PROCEDURE DrawUpperLeftTile mit WriteMode1: }
    { in: WinXMIN,WinYMIN = Bildschirmkoordinaten}
    {     ES = ^Grafiksegment}
    {     SI = Kachelindex   }
    {     BX = leftcut       }
    {     CX = xtil          }
    {     leftcut MOD 4 = 0  }
    {     topcut, Win*, SCROLLADR,...}
    {out: ES = ^Grafiksegment}
    {rem: WriteMode1 ist bereits gesetzt und bleibt gesetzt}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }

    MOV SI,topcut  {Dazu kommen die oben abgeschnittenen Zeilen:}
    MOV CX,16      {fÅr jede Zeile 4 Bytes}
    SUB CX,SI      {CX := 16 - topcut = zu zeichnende Zeilen}
    SHL SI,1
    SHL SI,1
    ADD SI,AX      {SI = Zeiger auf erste zu kopierende Tile*zeile*}

    MOV AX,BX      {BX = leftcut}
    SHR AX,1       {SI um linken cutoff weitersetzen = leftcut DIV 4}
    SHR AX,1
    ADD SI,AX      {SI = Zeiger auf erstes zu kopierendes Tile*byte*}

    MOV DI,WinYMINmLINESIZEaWinXMINdiv4 {ES:DI = Zieladresse}
    MOV DS,SCROLLADR  {DS:SI = Quelladresse}
    {Jetzt wird keine Variable aus dem Stack mehr gebraucht: BP kann}
    {verwendet werden!}
    PUSH BP        {wird beim Verlassen der Prozedur gebraucht!}
    MOV BP,16      {BP := (16 - leftcut) DIV 4 = Bytes je Kachelzeile}
    SUB BP,BX
    SHR BP,1
    SHR BP,1

    MOV AX,LINESIZE  {ist eine Konstante}
    SUB AX,BP
    MOV DX,4
    SUB DX,BP
    MOV BX,CX      {CX = Zeilenanzahl}

   @m1eineZeile4a1:
    MOV CX,BP
    REP MOVSB
    ADD DI,AX
    ADD SI,DX
    DEC BX
    JNZ @m1eineZeile4a1

    POP BP
    MOV AX,SEG @DATA
    MOV DS,AX

  {Auf nÑchste Kachel rechts davon positionieren:}
  INC actIndex
  INC xtil

  MOV AX,WinXMIN
  ADD AX,16
  SUB AX,leftcut
  (* MOV x,AX *)
  SHR AX,1
  SHR AX,1
 @m1SkipTopLeftCorner:
  ADD AX,WinYMIN_mul_LINESIZE
  MOV DI,AX   {ES:DI = ^Zieladresse}

  {Nun innerTilesX nur oben geschnittene Kacheln zeichnen:}
  MOV AX,innerTilesX
  OR AX,AX
  JBE @m1UpperInnerTilesDone
  MOV counter,AX

  MOV BX,16        {Korrekturfaktor, um DI eine Kachelzeile hoch und eine}
  SUB BX,topcut    {Kachelspalte weiterzusetzen}
  SHL BX,1
  MOV BX,CS:[OFFSET GADR +BX]
  NEG BX
  ADD BX,4         {BX := -(16 - topcut) * LINESIZE + 4}

 @m1repeat1:
  MOV SI,actIndex   {IF (xtil < 0) OR (xtil >= XTiles) OR Yoffscreen }
  AND SI,Yoffscreen { THEN SI := 0        }
  JZ @m1go2         { ELSE SI := actIndex }
  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m1go2:
    {PROCEDURE DrawUpperInnerTile mit WriteMode1: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     BX = Zeilenkorrektur}
    {     leftcut MOD 4 = 0   }
    {     topcut, Win*, SCROLLADR,...}
    {out: ES:DI = ^Zieladresse der nÑchsten Kachel rechts davon}
    {rem: WriteMode1 ist bereits gesetzt und bleibt gesetzt}
    {     BX wird nicht verÑndert}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }

    MOV SI,topcut  {Dazu kommen die oben abgeschnittenen Zeilen:}
    MOV CX,16      {fÅr jede Zeile 4 Bytes}
    SUB CX,SI      {CX := 16 - topcut = zu zeichnende Zeilen}
    SHL SI,1
    SHL SI,1
    ADD SI,AX      {SI = Zeiger auf erste zu kopierende Tile*zeile*}

    MOV DX,DS
    MOV DS,SCROLLADR
    MOV AX,LINESIZE-4

   @m1eineZeile4b1:
    MOVSB
    MOVSB
    MOVSB
    MOVSB
    ADD DI,AX
    LOOP @m1eineZeile4b1

    {DI = ^Start der Zeile unterhalb der Kachel, jetzt auf Start der nÑchsten}
    {Kachel setzen:}
    {⁄ƒ¬ƒ¬ƒ¬ƒø    ⁄ƒ¬ƒ¬ƒ¬ƒø‹ }
    {√ƒ≈ƒ≈ƒ≈ƒ¥ ƒ> √ƒ≈ƒ≈ƒ≈ƒ¥  }
    {¿ƒ¡ƒ¡ƒ¡ƒŸ    ¿ƒ¡ƒ¡ƒ¡ƒŸ  }
    { ﬂ                      }
    MOV DS,DX         {kein POP BP nîtig}
    ADD DI,BX

  {Auf nÑchste Kachel rechts davon positionieren:}
  INC actIndex
  INC xtil
  (* MOV AX,16 *)
  (* ADD x,AX *)
  DEC counter
  JNZ @m1repeat1

 @m1UpperInnerTilesDone:
  {ES:DI = ^erste Zeile der rechten oberen Eckkachel}
  CMP rightcut,0
  JE @m1SkipTopRightCorner

  MOV SI,actIndex   {IF (xtil < 0) OR (xtil >= XTiles) OR Yoffscreen }
  AND SI,Yoffscreen { THEN SI := 0        }
  JZ @m1go3         { ELSE SI := actIndex }
  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m1go3:
    {PROCEDURE DrawUpperRightTile mit WriteMode1: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     rightcut MOD 4 = 0  }
    {     topcut, Win*, SCROLLADR,...}
    {out: ES = ^Grafiksegment }
    {rem: WriteMode1 ist bereits gesetzt und bleibt gesetzt}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }

    MOV SI,topcut  {Dazu kommen die oben abgeschnittenen Zeilen:}
    MOV CX,16      {fÅr jede Zeile 4 Bytes}
    SUB CX,SI      {CX := 16 - topcut = zu zeichnende Zeilen}
    SHL SI,1
    SHL SI,1
    ADD SI,AX      {SI = Zeiger auf erste zu kopierende Tile*zeile*}

    MOV AX,rightcut
    MOV DS,SCROLLADR  {DS:SI = Quelladresse}
    {Jetzt wird keine Variable aus dem Stack mehr gebraucht: BP kann}
    {verwendet werden!}
    PUSH BP        {wird beim Verlassen der Prozedur gebraucht!}
    MOV BP,16      {BP := (16 - rightcut) DIV 4 = Bytes je Kachelzeile}
    SUB BP,AX
    SHR BP,1
    SHR BP,1

    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP
    MOV BX,CX      {BX := zu zeichnende Zeilen}

   @m1eineZeile4c1:
    MOV CX,BP
    REP MOVSB
    ADD DI,AX
    ADD SI,DX
    DEC BX
    JNZ @m1eineZeile4c1

    POP BP
    MOV AX,SEG @DATA
    MOV DS,AX

 @m1SkipTopRightCorner:
  {Auf erste linke Kachel positionieren, die oben nicht mehr geschnitten ist:}
  MOV AX,stepx2
  ADD actIndex,AX
  (* MOV AX,WinXMIN *)
  (* MOV x,AX *)
  MOV AX,KachelnWegLinks
  MOV xtil,AX
  INC ytil

 @m1SkipTopRow:
  MOV AX,topcut  {IF topcut = 0 }
  NEG AX         { THEN AX = y := WinYMIN}
  JZ @m1l1       { ELSE AX = y := WinYMIN + (16 - topcut)}
  ADD AX,16
 @m1l1:
  ADD AX,WinYMIN
  (* MOV y,AX *)

  MOV DI,AX      {DI := y * LINESIZE +X DIV 4}
  SHL DI,1
  MOV DI,CS:[OFFSET GADR +DI]
  ADD DI,WinXMINdiv4
  {ES:DI = ^Zieladresse der 1.Kachel der 1.oben nicht geschnittenen Kachelzeile}

  CMP leftcut,0
  JZ @m1SkipLeftColumn

  MOV DX,16
  SUB DX,leftcut
  SHR DX,1
  SHR DX,1
  MOV AX,LINESIZE
  SUB AX,DX   {Korrekturfaktor fÅr AX}
  MOV LINESIZE_sub_BytesPerPlane,AX
  MOV BytesPerPlane,DX  {Bytes zu moven}

  MOV AX,innerTilesY
  OR AX,AX
  JBE @m1LeftLoopDone
  MOV counter,AX

  PUSH actIndex
  (* PUSH y *)
  PUSH ytil
  PUSH DI

  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  MOV Xoffscreen,DX  {ist fÅr Kachelspalte konstant}
  MOV BX,BytesPerPlane

 @m1repeat5:
  MOV SI,actIndex
  AND SI,Xoffscreen
  JZ @m1go11
  MOV AX,ytil
  CWD
  SUB AX,YTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m1go11:
    {PROCEDURE DrawLeftTile mit WriteMode1: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     BX = BytesPerPlane  }
    {     leftcut MOD 4 = 0   }
    {     LINESIZE_sub_BytesPerPlane}
    {     leftcutDIV4, Win*, SCROLLADR,...}
    {out: ES:DI = ^Zieladresse der nÑchsten Kachel darunter}
    {rem: WriteMode1 ist bereits gesetzt und bleibt gesetzt }
    {     BX wird nicht verÑndert}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }
    MOV SI,AX

    ADD SI,leftcutDIV4
    MOV AX,LINESIZE_sub_BytesPerPlane
    MOV DX,4

    SUB DX,BX
    MOV DS,SCROLLADR

    MOV CX,BX   {1.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX   {ES:DI = ^nÑchste Kachel}

    MOV CX,BX   {2.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {3.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {4.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {5.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {6.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {7.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {8.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {9.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {10.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {11.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {12.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {13.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {14.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {15.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {16.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV AX,SEG @DATA
    MOV DS,AX

  {NÑchste Kachel; DI steht schon richtig:}
  MOV AX,XTiles
  ADD actIndex,AX
  (* MOV AX,16 *)
  (* ADD y,AX *)
  INC ytil

  DEC counter
  JNZ @m1repeat5

  POP DI
  POP ytil
  (* POP y *)
  POP actIndex

 @m1LeftLoopDone:
  INC actIndex
  ADD DI,BytesPerPlane
  INC xtil
  (* MOV AX,16 *)
  (* SUB AX,leftcut *)
  (* ADD x,AX *)

 @m1SkipLeftColumn:
  {ES:DI = ^Zieladresse der ersten inneren Kachel (immer noch)}

  MOV AX,innerTilesY   {gibt's Åberhaupt innere Kacheln?}
  OR AX,AX
  JBE @m1SkipInnerTiles
  CMP innerTilesX,0
  JB @m1SkipInnerTiles

  MOV counter,AX
  MOV AX,actIndex     {Kopien der aktuellen Werte anlegen}
  MOV tempActIndex,AX
  (* MOV AX,x *)
  (* MOV tempX,AX *)
  MOV AX,xtil
  MOV tempXtil,AX
  (* MOV AX,y *)
  (* MOV tempY,AX *)
  MOV AX,ytil
  MOV tempYtil,AX
  MOV tempDI,DI

  CMP rightcut,0
  JE @m1SkipRightColumn

  MOV DX,16
  SUB DX,rightcut
  SHR DX,1
  SHR DX,1
  MOV BytesPerPlane,DX
  MOV AX,LINESIZE
  SUB AX,DX
  MOV LINESIZE_sub_BytesPerPlane,AX

  MOV AX,innerTilesX
  ADD xtil,AX
  ADD actIndex,AX
  MOV CL,2
  SHL AX,CL
  ADD DI,AX  {ES:DI = ^erste rechte Randkachel, die oben nicht geschnitten ist}
  (* SHL AX,CL *)
  (* ADD x,AX *)

  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  MOV Xoffscreen,DX
  MOV BX,BytesPerPlane

 @m1repeat6:
  MOV SI,actIndex
  AND SI,Xoffscreen
  JZ @m1go12
  MOV AX,ytil
  CWD
  SUB AX,YTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m1go12:
    {PROCEDURE DrawRightTile mit WriteMode1: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     BX = BytesPerPlane  }
    {     rightcut MOD 4 = 0  }
    {     innerTilesY >= 1    }
    {     LINESIZE_sub_BytesPerPlane}
    {     SCROLLADR,...}
    {out: ES:DI = ^Zieladresse der nÑchsten Kachel darunter}
    {rem: WriteMode1 ist bereits gesetzt und bleibt gesetzt }
    {     BX wird nicht verÑndert}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }
    MOV SI,AX

    MOV AX,LINESIZE_sub_BytesPerPlane
    MOV DX,4

    SUB DX,BX
    MOV DS,SCROLLADR

    MOV CX,BX   {1.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX   {ES:DI = ^nÑchste Kachel}

    MOV CX,BX   {2.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {3.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {4.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {5.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {6.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {7.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {8.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX   {9.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {10.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {11.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {12.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {13.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {14.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {15.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BX  {16.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV AX,SEG @DATA
    MOV DS,AX

  {NÑchste Kachel; DI steht schon richtig:}
  MOV AX,XTiles
  ADD actIndex,AX
  (* MOV AX,16 *)
  (* ADD y,AX *)
  INC ytil

  DEC counter
  JNZ @m1repeat6

  MOV DI,tempDI
  MOV AX,tempActIndex
  MOV actIndex,AX
  (* MOV AX,tempX *)
  (* MOV x,tempX *)
  MOV AX,tempXtil
  MOV xtil,AX
  (* MOV AX,tempY *)
  (* MOV y,AX *)
  MOV AX,tempYtil
  MOV ytil,AX

 @m1RightLoopDone:
 @m1SkipRightColumn:
  {ES:DI = ^Zieladresse der ersten inneren Kachel (immer noch)}
  {innerTilesX >= 0, innerTilesX >= 1 -> es reichte, innerTilesX=0 zu prÅfen:}

  CMP innerTilesX,0    {IF (innerTilesX <= 0) OR (innerTilesY <= 0) THEN skip}
  JBE @m1SkipInnerTiles  {Falls keine inneren Kachel existieren, dann ist  }
                         {stattdessen bereits auf erste links nicht ge-    }
                         {schnittene Kachel der untersten Kachelzeile pos. }


  {Nun "FOR x:=1 TO innerTilesX DO FOR y:=1 TO innerTilesY DO .." realisieren}
  MOV oldDI,DI        {temporÑre Kopien von DI und actIndex anlegen}
  MOV BX,actIndex     {BX entspricht "oldActIndex"}

  MOV AX,innerTilesX
  MOV counter,AX  {ZÑhler fÅr X-Richtung}
  MOV CL,6

 @m1xloop:
  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  MOV Xoffscreen,DX  {ist fÅr Kachelspalte konstant}

  MOV AX,innerTilesY
  MOV CH,AL          {CH dient als ZÑhler fÅr Y-Richtung}


 @m1yloop:
  MOV SI,BX          {SI = temp. actIndex}
  AND SI,Xoffscreen
  JZ @m1go5
  MOV AX,ytil
  CWD
  SUB AX,YTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m1go5:
    {PROCEDURE DrawInnerTile mit WriteMode1: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     CL = 6              }
    {     SCROLLADR}
    {out: ES:DI = ^Zieladresse der nÑchsten Kachel darunter}
    {     CL = 6}
    {rem: WriteMode1 ist bereits gesetzt und bleibt gesetzt }
    {     CH, BX dÅrfen nicht verÑndert werden!}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
                   {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }
    MOV SI,AX

    MOV DX,DS   {DS nach DX retten}
    MOV DS,SCROLLADR

    MOVSB       {1.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4   {ES:DI = ^nÑchste Kachel}

    MOVSB       {2.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB       {3.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB       {4.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB       {5.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB       {6.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB       {7.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB       {8.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB       {9.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB      {10.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB      {11.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB      {12.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB      {13.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB      {14.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB      {15.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4

    MOVSB      {16.Zeile}
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4


    MOV DS,DX

  {NÑchste Kachel; DI steht schon richtig:}
  ADD BX,XTiles     {temp. actIndex in nÑchste Zeile setzen}
  INC ytil
  (* MOV AX,16 *)
  (* ADD y,AX *)

  DEC CH
  JNZ @m1yloop

  {actIndex hat noch seinen alten Wert, da nur "oldActIndex" verÑndert wurde.}
  INC actIndex        {actIndex = nÑchste innere Kachel in oberster Kachelzeile}
  MOV BX,actIndex     {und als Startwert fÅr nÑchste Spalte Åbernehmen}

  MOV DI,oldDI        {ES:DI = ^innere Kachel in oberster Kachelzeile}
  ADD DI,4            {eine Kachel weitersetzen}
  MOV oldDI,DI        {und als Startwert fÅr nÑchste Spalte Åbernehmen}

  MOV AX,tempYtil
  MOV ytil,AX     {Y-Koordinate wieder auf oberste innere Kachelzeile setzen}
  (* MOV AX,oldY *)
  (* MOV y,AX *)

  INC xtil      {X-Koordinate eine Kachelspalte weitersetzen}
  (* MOV AX,16 *)
  (* ADD x,AX *)

  DEC counter
  JNZ @m1xloop

  MOV DI,tempDI       {Damit: ES:DI, actIndex, xtil, ytil, x, y zeigen wieder}
  MOV AX,tempActIndex {auf die erste, innere Kachel  (N.B.: y, ytil wurden   }
  MOV actIndex,AX     {bereits weiter oben wiederhergestellt)}
  MOV AX,tempXtil
  MOV xtil,AX
  (* MOV AX,tempX *)
  (* MOV x,AX *)

  MOV AX,innerTilesY
  MOV DX,AX     {Kopie in DX aufheben}
  ADD ytil,AX   {ytil zeigt jetzt auf unterste Kachelzeile}

  MOV CL,5
  SHL AX,CL     {dto. fÅr DI: inc(DI,16 * innerTilesY * LINESIZE) }
  MOV BX,AX
  ADD DI,CS:[OFFSET GADR +BX]
  (* SHR AX,1 *)
  (* ADD y,AX *)  {dto. fÅr y: inc(y,16 * innerTilesY) }

  MOV AX,XTiles
  MUL DX          {AX := XTiles * innerTilesY}
  ADD actIndex,AX {dto. fÅr actIndex: inc(actIndex,XTiles * innerTilesY) }

 @m1SkipInnerTiles:
  {ES:DI, actIndex, xtil, ytil, x, y zeigen auf erste innere Kachel der}
  {untersten Kachelzeile}
  CMP bottomcut,0
  JE @m1fertig

  MOV AX,ytil
  CWD
  SUB AX,YTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  MOV Yoffscreen,DX

  MOV AX,innerTilesX
  OR AX,AX
  JBE @m1LowerInnerTilesDone {stehen wir bereits auf rechter unterer Eckkachel?}
  MOV counter,AX

  {Additionsfaktor berechnen, um von unten nach oben zu kommen:}
  {⁄ƒ¬ƒ¬ƒ¬ƒø    ⁄ƒ¬ƒ¬ƒ¬ƒø‹ }
  {√ƒ≈ƒ≈ƒ≈ƒ¥ ƒ> √ƒ≈ƒ≈ƒ≈ƒ¥  }
  {¿ƒ¡ƒ¡ƒ¡ƒŸ    ¿ƒ¡ƒ¡ƒ¡ƒŸ  }
  { ﬂ                      }
  {BX := -(16 - bottomcut) * LINESIZE + 4}
  MOV BX,16
  SUB BX,bottomcut
  SHL BX,1
  MOV BX,CS:[OFFSET GADR +BX]
  NEG BX
  ADD BX,4

 @m1repeat4:
  MOV SI,actIndex
  AND SI,Yoffscreen
  JZ @m1go8

  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m1go8:
    {PROCEDURE DrawLowerInnerTile mit WriteMode1: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     BX = Korrekturfaktor fÅr Zeilenadressen }
    {     bottomcut, Win*, SCROLLADR,...}
    {out: ES:DI = ^Zieladresse der nÑchsten Kachel rechts davon}
    {     BX = Korrekturfaktor fÅr Zeilenadressen }
    {rem: WriteMode1 ist bereits gesetzt und bleibt gesetzt}
    {     DX wird nicht benutzt}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }
    MOV SI,AX

    MOV CX,16
    SUB CX,bottomcut

    MOV AX,DS   {DS nach AX retten}
    MOV DS,SCROLLADR

   @m1eineZeile4e1:
    MOVSB
    MOVSB
    MOVSB
    MOVSB
    ADD DI,LINESIZE-4
    LOOP @m1eineZeile4e1

    MOV DS,AX

    {DI = ^Start der Zeile unterhalb der Kachel, jetzt auf Start der nÑchsten}
    {Kachel setzen:}
    {⁄ƒ¬ƒ¬ƒ¬ƒø    ⁄ƒ¬ƒ¬ƒ¬ƒø‹ }
    {√ƒ≈ƒ≈ƒ≈ƒ¥ ƒ> √ƒ≈ƒ≈ƒ≈ƒ¥  }
    {¿ƒ¡ƒ¡ƒ¡ƒŸ    ¿ƒ¡ƒ¡ƒ¡ƒŸ  }
    { ﬂ                      }
    ADD DI,BX

  {Auf nÑchste Kachel rechts davon positionieren:}
  INC actIndex
  INC xtil
  (* MOV AX,16 *)
  (* ADD x,AX *)

  DEC counter
  JNZ @m1repeat4

 @m1LowerInnerTilesDone:
  {ES:DI, actIndex, xtil, ytil, x, y zeigen auf untere rechte Eckkachel}
  CMP rightcut,0
  JE @m1SkipLowerRightCorner

  PUSH DI
  MOV SI,actIndex
  AND SI,Yoffscreen
  JZ @m1go9
  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m1go9:
    {PROCEDURE DrawLowerRightTile mit WriteMode1: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     rightcut MOD 4 = 0  }
    {     rightcut, bottomcut, Win*, SCROLLADR,...}
    {out: ES = ^Grafiksegment }
    {rem: WriteMode1 ist bereits gesetzt und bleibt gesetzt}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }
    MOV SI,AX

    MOV CX,16
    SUB CX,bottomcut
    MOV BX,16
    SUB BX,rightcut
    SHR BX,1
    SHR BX,1  {BX = BytesPerPlane = (16 - rightcut) DIV 4}

    MOV DS,SCROLLADR

    MOV AX,LINESIZE
    SUB AX,BX
    MOV DX,4
    SUB DX,BX
    PUSH BP
    MOV BP,CX  {BP=ZeilenzÑhler}

   @m1eineZeile4g1:
    MOV CX,BX
    REP MOVSB
    ADD SI,DX
    ADD DI,AX
    DEC BP
    JNZ @m1eineZeile4g1

    POP BP
    MOV AX,SEG @DATA
    MOV DS,AX

  POP DI   {ES:DI etc. zeigen auf rechte untere Eckkachel}

 @m1SkipLowerRightCorner:
  CMP leftcut,0
  JE @m1fertig

  {jetzt auf linke untere Eckkachel positionieren:}
  MOV AX,innerTilesX
  INC AX
  SUB actIndex,AX  {dec(actIndex,innerTilesX + 1) }
  SUB xtil,AX      {dec(xtil,innerTilesX + 1) }
  MOV CL,2
  SHL AX,CL
  SUB DI,AX        {dec(DI,4 * (innerTilesX + 1) }
  ADD DI,leftcutDIV4 {berÅcksichtige: Eckkachel kann links geschnitten sein}
  (* MOV AX,WinXMIN *)
  (* MOV x,AX *)

  MOV SI,actIndex
  AND SI,Yoffscreen
  JZ @m1go7
  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m1go7:
    {PROCEDURE DrawLowerLeftTile mit WriteMode1: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     rightcut MOD 4 = 0  }
    {     leftcut, bottomcut, Win*, SCROLLADR,...}
    {out: (ES = ^Grafiksegment) }
    {rem: WriteMode1 ist bereits gesetzt (und bleibt gesetzt)}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }
    MOV SI,AX

    MOV AX,leftcut
    MOV BX,AX
    MOV CL,2
    SHR AX,CL
    ADD SI,AX

    MOV CX,16
    SUB CX,bottomcut

    MOV DS,SCROLLADR

    PUSH BP
    MOV BP,16
    SUB BP,BX   
    SHR BP,1
    SHR BP,1    {BP:=(16 - leftcut) DIV 4}

    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    MOV BX,CX   {BX = ZeilenzÑhler}

   @m1eineZeile4d1:
    MOV CX,BP
    REP MOVSB
    ADD SI,DX
    ADD DI,AX
    DEC BX
    JNZ @m1eineZeile4d1

    POP BP
    MOV AX,SEG @DATA
    MOV DS,AX

 @m1fertig:
  {Jetzt wieder auf WriteMode0 zurÅckschalten:}
  MOV AX,4005h
  MOV DX,3CEh
  OUT DX,AX
  JMP @Sprites_zeichnen

 {----------------------------------------------------}

 @useMode0:
  CMP topcut,0      {IF ytil Ó [0..YTiles(          }
  JE @m0SkipTopRow  { THEN DX = Yoffscreen := $FFFF }
  MOV AX,ytil       { ELSE DX = Yoffscreen := $0000 }
  CWD
  SUB AX,YTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  MOV Yoffscreen,DX

  MOV AX,WinXMINdiv4  {AX = richtiger Wert, falls gesprungen wird!}
  OR BX,BX   {BX=leftcut}
  JZ @m0SkipTopLeftCorner

  MOV SI,actIndex     {IF (xtil < 0) OR (xtil >= XTiles) OR Yoffscreen }
  AND SI,DX           { THEN SI := 0 }
  JZ @m0go1           { ELSE SI := actIndex }
  MOV AX,CX  {CX = xtil}
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX

 @m0go1:
    {PROCEDURE DrawUpperLeftTile mit WriteMode0: }
    { in: WinXMIN,WinYMIN = Bildschirmkoordinaten}
    {     ES = ^Grafiksegment}
    {     SI = Kachelindex   }
    {     BX = leftcut       }
    {     CX = xtil          }
    {     topcut, Win*, SCROLLADR,...}
    {out: ES = ^Grafiksegment}
    {rem: WriteMode0 ist bereits gesetzt und bleibt gesetzt}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }

    MOV SI,topcut  {Dazu kommen die oben abgeschnittenen Zeilen:}
    MOV CX,16      {fÅr jede Zeile 4 Bytes}
    SUB CX,SI      {CX := 16 - topcut = zu zeichnende Zeilen}
    SHL SI,1
    SHL SI,1
    ADD SI,AX      {SI = Zeiger auf erste zu kopierende Tile*zeile*}

    MOV AX,BX      {BX = leftcut}
    SHR AX,1       {SI um linken cutoff weitersetzen = leftcut DIV 4}
    SHR AX,1
    ADD SI,AX      {SI = Zeiger auf erstes zu kopierendes Tile*byte*}

    MOV DI,WinYMINmLINESIZEaWinXMINdiv4 {ES:DI = Zieladresse}
    MOV DS,SCROLLADR  {DS:SI = Quelladresse}
    {Jetzt wird keine Variable aus dem Stack mehr gebraucht: BP kann}
    {verwendet werden!}
    PUSH BP        {wird beim Verlassen der Prozedur gebraucht!}
    MOV BP,16+3    {BP:=(16 + 3 - leftcut) DIV 4 = Bytes je Kachelzeile}
    SUB BP,BX
    PUSH BP        {BP fÅr nÑchste Plane merken}
    SHR BP,1
    SHR BP,1

    MOV AH,BL      {BL = leftcut}
    AND AH,3
    MOV AL,4
    MOV DX,3CEh
    OUT DX,AX      {erste Leseplane wÑhlen}
    PUSH AX
    MOV DX,3C4h
    MOV AX,0102h
    OUT DX,AX      {Schreibplane 0 wÑhlen}

    MOV AX,LINESIZE  {ist eine Konstante}
    SUB AX,BP
    MOV DX,4
    SUB DX,BP
    MOV BX,CX      {CX = Zeilenanzahl}

    PUSH SI
    PUSH DI
    PUSH BX
   @m0eineZeile4a1:
    MOV CX,BP
    REP MOVSB
    ADD DI,AX
    ADD SI,DX
    DEC BX
    JNZ @m0eineZeile4a1
    POP BX
    POP DI
    POP SI

    MOV DX,3C4h
    MOV AX,0202h
    OUT DX,AX      {Schreibplane 1 wÑhlen}
    MOV DX,3CEh
    POP AX
    INC AH
    AND AH,3
    JNE @nowrap1a
    INC SI
   @nowrap1a:
    OUT DX,AX      {nÑchste Leseplane wÑhlen}
    POP BP         {BP = 16 + 3 - leftcut }
    DEC BP
    PUSH BP
    PUSH AX
    SHR BP,1
    SHR BP,1

    MOV AX,LINESIZE  {ist eine Konstante}
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    PUSH SI
    PUSH DI
    PUSH BX
   @m0eineZeile4a2:
    MOV CX,BP
    REP MOVSB
    ADD DI,AX
    ADD SI,DX
    DEC BX
    JNZ @m0eineZeile4a2
    POP BX
    POP DI
    POP SI

    MOV DX,3C4h
    MOV AX,0402h
    OUT DX,AX      {Schreibplane 2 wÑhlen}
    MOV DX,3CEh
    POP AX
    INC AH
    AND AH,3
    JNE @nowrap2a
    INC SI
   @nowrap2a:
    OUT DX,AX      {nÑchste Leseplane wÑhlen}
    POP BP         {BP = 16 + 2 - leftcut }
    DEC BP
    PUSH BP
    PUSH AX
    SHR BP,1
    SHR BP,1

    MOV AX,LINESIZE  {ist eine Konstante}
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    PUSH SI
    PUSH DI
    PUSH BX
   @m0eineZeile4a3:
    MOV CX,BP
    REP MOVSB
    ADD DI,AX
    ADD SI,DX
    DEC BX
    JNZ @m0eineZeile4a3
    POP BX
    POP DI
    POP SI

    MOV DX,3C4h
    MOV AX,0802h
    OUT DX,AX      {Schreibplane 3 wÑhlen}
    MOV DX,3CEh
    POP AX
    INC AH
    AND AH,3
    JNE @nowrap3a
    INC SI
   @nowrap3a:
    OUT DX,AX      {nÑchste Leseplane wÑhlen}
    POP BP         {BP = 16+ 1 - leftcut }
    DEC BP


    SHR BP,1
    SHR BP,1

    MOV AX,LINESIZE  {ist eine Konstante}
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

   @m0eineZeile4a4:
    MOV CX,BP
    REP MOVSB
    ADD DI,AX
    ADD SI,DX
    DEC BX
    JNZ @m0eineZeile4a4

    POP BP
    MOV AX,SEG @DATA
    MOV DS,AX

  {Auf nÑchste Kachel rechts davon positionieren:}
  INC actIndex
  INC xtil

  MOV AX,WinXMIN
  ADD AX,16
  SUB AX,leftcut
  (* MOV x,AX *)
  SHR AX,1
  SHR AX,1
 @m0SkipTopLeftCorner:
  ADD AX,WinYMIN_mul_LINESIZE
  MOV DI,AX   {ES:DI = ^Zieladresse}

  {Nun innerTilesX nur oben geschnittene Kacheln zeichnen:}
  MOV AX,innerTilesX
  OR AX,AX
  JBE @m0UpperInnerTilesDone
  MOV counter,AX

  MOV BX,16        {Korrekturfaktor, um DI einer Kachelzeile hoch und eine}
  SUB BX,topcut    {Kachelspalte weiterzusetzen}
  SHL BX,1
  MOV AX,CS:[OFFSET GADR +BX]
  NEG AX
  ADD AX,4
  MOV Korrektur,AX {Korrektur := -(16 - topcut) * LINESIZE + 4}

 @m0repeat1:
  MOV SI,actIndex   {IF (xtil < 0) OR (xtil >= XTiles) OR Yoffscreen }
  AND SI,Yoffscreen { THEN SI := 0        }
  JZ @m0go2         { ELSE SI := actIndex }
  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m0go2:
    {PROCEDURE DrawUpperInnerTile mit WriteMode0: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     topcut, Win*, SCROLLADR,...}
    {out: ES:DI = ^Zieladresse der nÑchsten Kachel rechts davon}
    {rem: WriteMode0 ist bereits gesetzt und bleibt gesetzt}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }

    MOV SI,topcut  {Dazu kommen die oben abgeschnittenen Zeilen:}
    MOV CX,16      {fÅr jede Zeile 4 Bytes}
    SUB CX,SI      {CX := 16 - topcut = zu zeichnende Zeilen}
    SHL SI,1
    SHL SI,1
    ADD SI,AX      {SI = Zeiger auf erste zu kopierende Tile*zeile*}

    PUSH BP        {BP retten}
    MOV DX,3C4h
    MOV AX,StartWritePlane
    OUT DX,AX      {erste Schreibplane wÑhlen}
    PUSH AX
    MOV DX,3CEh
    MOV AX,0004h
    OUT DX,AX      {Leseplane 0 wÑhlen}

    MOV DS,SCROLLADR   {jetzt frei: AX, BX, BP, DX}

    MOV BX,CX      {ZeilenzÑhlerkopie}
    MOV BP,SI      {BP = Kopie von SI}
    MOV AX,DI      {AX = Kopie von DI}
   @m0eineZeile4b1:
    MOVSW
    MOVSW
    ADD DI,LINESIZE-4
    LOOP @m0eineZeile4b1
    MOV SI,BP      {alte Werte wiederherstellen}
    MOV DI,AX
    MOV CX,BX

    MOV AX,0104h
    OUT DX,AX      {DX = 3CEh -> Leseplane 1 wÑhlen}
    MOV DX,3C4h
    POP AX
    SHL AH,1
    CMP AH,16
    JNE @nowrap1b
    MOV AH,1
    INC DI
   @nowrap1b:
    OUT DX,AX      {nÑchste Schreibplane wÑhlen}
    PUSH AX
    MOV AX,DI

   @m0eineZeile4b2:
    MOVSW
    MOVSW
    ADD DI,LINESIZE-4
    LOOP @m0eineZeile4b2
    MOV SI,BP      {alte Werte wiederherstellen}
    MOV DI,AX
    MOV CX,BX

    POP AX
    SHL AH,1
    CMP AH,16
    JNE @nowrap2b
    MOV AH,1
    INC DI
   @nowrap2b:
    OUT DX,AX      {DX = 3C4h -> nÑchste Schreibplane wÑhlen}
    PUSH AX
    MOV DX,3CEh
    MOV AX,0204h
    OUT DX,AX      {Leseplane 2 wÑhlen}
    MOV AX,DI

   @m0eineZeile4b3:
    MOVSW
    MOVSW
    ADD DI,LINESIZE-4
    LOOP @m0eineZeile4b3
    MOV SI,BP      {alte Werte wiederherstellen}
    MOV DI,AX
    MOV CX,BX

    MOV AX,0304h
    OUT DX,AX      {DX = 3CEh -> Leseplane 3 wÑhlen}
    MOV DX,3C4h
    POP AX
    SHL AH,1
    CMP AH,16
    JNE @nowrap3b
    MOV AH,1
    INC DI
   @nowrap3b:
    OUT DX,AX      {letzte Schreibplane wÑhlen: keine PUSHs mehr}

   @m0eineZeile4b4:
    MOVSW
    MOVSW
    ADD DI,LINESIZE-4
    LOOP @m0eineZeile4b4
                   {alte Werte nicht wiederherstellen}

    POP BP         {TP zufriedenstellen}
    MOV AX,SEG @Data
    MOV DS,AX

    {DI = ^Start der Zeile unterhalb der Kachel, jetzt auf Start der nÑchsten}
    {Kachel setzen:}
    {⁄ƒ¬ƒ¬ƒ¬ƒø    ⁄ƒ¬ƒ¬ƒ¬ƒø‹ }
    {√ƒ≈ƒ≈ƒ≈ƒ¥ ƒ> √ƒ≈ƒ≈ƒ≈ƒ¥  }
    {¿ƒ¡ƒ¡ƒ¡ƒŸ    ¿ƒ¡ƒ¡ƒ¡ƒŸ  }
    { ﬂ                      }
    ADD DI,Korrektur
    {-1, weil exakt einmal "inc di" ausgefÅhrt wurde!}
    DEC DI

  {Auf nÑchste Kachel rechts davon positionieren:}
  INC actIndex
  INC xtil
  (* MOV AX,16 *)
  (* ADD x,AX *)
  DEC counter
  JNZ @m0repeat1

 @m0UpperInnerTilesDone:
  {ES:DI = ^erste Zeile der rechten oberen Eckkachel}
  CMP rightcut,0
  JE @m0SkipTopRightCorner

  MOV SI,actIndex   {IF (xtil < 0) OR (xtil >= XTiles) OR Yoffscreen }
  AND SI,Yoffscreen { THEN SI := 0        }
  JZ @m0go3         { ELSE SI := actIndex }
  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m0go3:
    {PROCEDURE DrawUpperRightTile mit WriteMode0: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     StartWritePlane = erste zu beschreibende Bitplane}
    {     topcut, rightcut, Win*, SCROLLADR,...}
    {out: ES = ^Grafiksegment }
    {rem: WriteMode0 ist bereits gesetzt und bleibt gesetzt}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }

    MOV SI,topcut  {Dazu kommen die oben abgeschnittenen Zeilen:}
    MOV CX,16      {fÅr jede Zeile 4 Bytes}
    SUB CX,SI      {CX := 16 - topcut = zu zeichnende Zeilen}
    SHL SI,1
    SHL SI,1
    ADD SI,AX      {SI = Zeiger auf erste zu kopierende Tile*zeile*}

    MOV BX,rightcut
    PUSH BP        {wird beim Verlassen der Prozedur gebraucht!}
    MOV DS,SCROLLADR  {DS:SI = Quelladresse}
    MOV DX,3C4h
    MOV AX,StartWritePlane
    OUT DX,AX
    PUSH AX
    MOV DX,3CEh
    MOV AX,0004h
    OUT DX,AX
    {Jetzt wird keine Variable aus dem Stack mehr gebraucht: BP kann}
    {verwendet werden!}
    MOV BP,16+3    {BP:=(16 + 3 - rightcut) DIV 4 = Bytes je Kachelzeile}
    SUB BP,BX
    PUSH BP
    SHR BP,1
    SHR BP,1

    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP
    MOV BX,CX      {BX := zu zeichnende Zeilen}

    PUSH BX
    PUSH SI
    PUSH DI
   @m0eineZeile4c1:
    MOV CX,BP
    REP MOVSB
    ADD DI,AX
    ADD SI,DX
    DEC BX
    JNZ @m0eineZeile4c1
    POP DI
    POP SI
    POP BX
    POP BP
    POP AX

    SHL AH,1
    CMP AH,16
    JNE @nowrap1c
    MOV AH,1
    INC DI
   @nowrap1c:
    MOV DX,3C4h
    OUT DX,AX
    PUSH AX
    MOV DX,3CEh
    MOV AX,0104h
    OUT DX,AX

    DEC BP         {BP := 16 + 2 - rightcut}
    PUSH BP
    SHR BP,1
    SHR BP,1
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    PUSH BX
    PUSH SI
    PUSH DI
   @m0eineZeile4c2:
    MOV CX,BP
    REP MOVSB
    ADD DI,AX
    ADD SI,DX
    DEC BX
    JNZ @m0eineZeile4c2
    POP DI
    POP SI
    POP BX
    POP BP
    POP AX

    SHL AH,1
    CMP AH,16
    JNE @nowrap2c
    MOV AH,1
    INC DI
   @nowrap2c:
    MOV DX,3C4h
    OUT DX,AX
    PUSH AX
    MOV DX,3CEh
    MOV AX,0204h
    OUT DX,AX

    DEC BP         {BP := 16 + 1 - rightcut}
    PUSH BP
    SHR BP,1
    SHR BP,1
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    PUSH BX
    PUSH SI
    PUSH DI
   @m0eineZeile4c3:
    MOV CX,BP
    REP MOVSB
    ADD DI,AX
    ADD SI,DX
    DEC BX
    JNZ @m0eineZeile4c3
    POP DI
    POP SI
    POP BX
    POP BP
    POP AX

    SHL AH,1
    CMP AH,16
    JNE @nowrap3c
    MOV AH,1
    INC DI
   @nowrap3c:
    MOV DX,3C4h
    OUT DX,AX

    MOV DX,3CEh
    MOV AX,0304h
    OUT DX,AX

    DEC BP         {BP := 16 + 0 - rightcut}

    SHR BP,1
    SHR BP,1
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

   @m0eineZeile4c4:
    MOV CX,BP
    REP MOVSB
    ADD DI,AX
    ADD SI,DX
    DEC BX
    JNZ @m0eineZeile4c4


    POP BP
    MOV AX,SEG @DATA
    MOV DS,AX

 @m0SkipTopRightCorner:
  {Auf erste linke Kachel positionieren, die oben nicht mehr geschnitten ist:}
  MOV AX,stepx2
  ADD actIndex,AX
  (* MOV AX,WinXMIN *)
  (* MOV x,AX *)
  MOV AX,KachelnWegLinks
  MOV xtil,AX
  INC ytil

 @m0SkipTopRow:
  MOV AX,topcut  {IF topcut = 0 }
  NEG AX         { THEN AX = y := WinYMIN}
  JZ @m0l1       { ELSE AX = y := WinYMIN + (16 - topcut)}
  ADD AX,16
 @m0l1:
  ADD AX,WinYMIN
  (* MOV y,AX *)

  MOV DI,AX      {DI := y * LINESIZE +X DIV 4}
  SHL DI,1
  MOV DI,CS:[OFFSET GADR +DI]
  ADD DI,WinXMINdiv4
  {ES:DI = ^Zieladresse der 1.Kachel der 1.oben nicht geschnittenen Kachelzeile}

  CMP leftcut,0
  JZ @m0SkipLeftColumn

  MOV DX,16+3
  SUB DX,leftcut
  SHR DX,1
  SHR DX,1
  MOV AX,LINESIZE
  SUB AX,DX   {Korrekturfaktor fÅr AX}
  MOV LINESIZE_sub_BytesPerPlane,AX
  MOV BytesPerPlane,DX  {Bytes zu moven}

  MOV AX,innerTilesY
  OR AX,AX
  JBE @m0LeftLoopDone
  MOV counter,AX

  PUSH actIndex
  (* PUSH y *)
  PUSH ytil
  PUSH DI

  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  MOV Xoffscreen,DX  {ist fÅr Kachelspalte konstant}

 @m0repeat5:
  MOV SI,actIndex
  AND SI,Xoffscreen
  JZ @m0go11
  MOV AX,ytil
  CWD
  SUB AX,YTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m0go11:
    {PROCEDURE DrawLeftTile mit WriteMode0: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     StartLesePlane = erste Bitplane, von der gelesen wird}
    {     LINESIZE_sub_BytesPerPlane, BytesPerPlane = Korrekturfaktoren}
    {     leftcut, leftcutDIV4, Win*, SCROLLADR,...}
    {out: ES:DI = ^Zieladresse der nÑchsten Kachel darunter}
    {rem: WriteMode0 ist bereits gesetzt und bleibt gesetzt }
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }
    MOV SI,AX

    PUSH BP
    ADD SI,leftcutDIV4
    MOV DX,3C4h
    MOV AX,0102h
    OUT DX,AX
    MOV DX,3CEh
    MOV AX,StartLesePlane
    OUT DX,AX
    MOV BX,AX

    MOV AX,16+3
    SUB AX,leftcut
    PUSH AX
    SHR AX,1
    SHR AX,1
    MOV BP,AX
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    MOV DS,SCROLLADR

    PUSH SI
    PUSH DI
    MOV CX,BP   {1.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX   {ES:DI = ^nÑchste Kachel}

    MOV CX,BP   {2.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {3.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {4.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {5.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {6.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {7.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {8.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {9.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {10.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {11.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {12.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {13.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {14.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {15.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {16.Zeile}
    REP MOVSB

    POP DI
    POP SI

    POP BP
    INC BH
    AND BH,3
    JNE @nowrap11a
    INC SI
   @nowrap11a:
    MOV AX,BX
    MOV DX,3CEh
    OUT DX,AX
    MOV DX,3C4h
    MOV AX,0202h
    OUT DX,AX

    DEC BP
    PUSH BP
    SHR BP,1
    SHR BP,1
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    PUSH SI
    PUSH DI
    MOV CX,BP   {1.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX   {ES:DI = ^nÑchste Kachel}

    MOV CX,BP   {2.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {3.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {4.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {5.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {6.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {7.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {8.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {9.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {10.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {11.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {12.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {13.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {14.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {15.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {16.Zeile}
    REP MOVSB

    POP DI
    POP SI

    POP BP
    INC BH
    AND BH,3
    JNE @nowrap11b
    INC SI
   @nowrap11b:
    MOV AX,BX
    MOV DX,3CEh
    OUT DX,AX
    MOV DX,3C4h
    MOV AX,0402h
    OUT DX,AX

    DEC BP
    PUSH BP
    SHR BP,1
    SHR BP,1
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    PUSH SI
    PUSH DI
    MOV CX,BP   {1.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX   {ES:DI = ^nÑchste Kachel}

    MOV CX,BP   {2.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {3.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {4.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {5.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {6.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {7.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {8.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {9.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {10.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {11.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {12.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {13.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {14.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {15.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {16.Zeile}
    REP MOVSB

    POP DI
    POP SI

    POP BP
    INC BH
    AND BH,3
    JNE @nowrap11c
    INC SI
   @nowrap11c:
    MOV AX,BX
    MOV DX,3CEh
    OUT DX,AX
    MOV DX,3C4h
    MOV AX,0802h
    OUT DX,AX

    DEC BP

    SHR BP,1
    SHR BP,1
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP



    MOV CX,BP   {1.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX   {ES:DI = ^nÑchste Kachel}

    MOV CX,BP   {2.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {3.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {4.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {5.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {6.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {7.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {8.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {9.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {10.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {11.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {12.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {13.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {14.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {15.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {16.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    POP BP
    MOV AX,SEG @DATA
    MOV DS,AX

  {NÑchste Kachel; DI steht schon richtig:}
  MOV AX,XTiles
  ADD actIndex,AX
  (* MOV AX,16 *)
  (* ADD y,AX *)
  INC ytil

  DEC counter
  JNZ @m0repeat5

  POP DI
  POP ytil
  (* POP y *)
  POP actIndex

 @m0LeftLoopDone:
  INC actIndex
  ADD DI,BytesPerPlane

  {-1, weil exakt einmal "inc di" ausgefÅhrt wurde!}
  DEC DI

  INC xtil
  (* MOV AX,16 *)
  (* SUB AX,leftcut *)
  (* ADD x,AX *)

 @m0SkipLeftColumn:
  {ES:DI = ^Zieladresse der ersten inneren Kachel (immer noch)}

  MOV AX,innerTilesY    {gibt's Åberhaupt innere Kacheln?}
  OR AX,AX
  JBE @m0SkipInnerTiles {nein}
  CMP innerTilesX,0
  JB @m0SkipInnerTiles

  MOV counter,AX
  MOV AX,actIndex     {Kopien der aktuellen Werte anlegen}
  MOV tempActIndex,AX
  (* MOV AX,x *)
  (* MOV tempX,AX *)
  MOV AX,xtil
  MOV tempXtil,AX
  (* MOV AX,y *)
  (* MOV tempY,AX *)
  MOV AX,ytil
  MOV tempYtil,AX
  MOV tempDI,DI

  CMP rightcut,0
  JE @m0SkipRightColumn

  MOV DX,16
  SUB DX,rightcut
  SHR DX,1
  SHR DX,1
  MOV BytesPerPlane,DX
  MOV AX,LINESIZE
  SUB AX,DX
  MOV LINESIZE_sub_BytesPerPlane,AX

  MOV AX,innerTilesX
  ADD xtil,AX
  ADD actIndex,AX
  MOV CL,2
  SHL AX,CL
  ADD DI,AX  {ES:DI = ^erste rechte Randkachel, die oben nicht geschnitten}
  (* SHL AX,CL *)
  (* ADD x,AX *)

  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  MOV Xoffscreen,DX

 @m0repeat6:
  MOV SI,actIndex
  AND SI,Xoffscreen
  JZ @m0go12
  MOV AX,ytil
  CWD
  SUB AX,YTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m0go12:
    {PROCEDURE DrawRightTile mit WriteMode0: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     StartWritePlane = erste zu beschreibende Bitplane}
    {     innerTilesY >= 1    }
    {     rightcut, Win*, SCROLLADR,...}
    {out: ES:DI = ^Zieladresse der nÑchsten Kachel darunter}
    {rem: WriteMode0 ist bereits gesetzt und bleibt gesetzt }
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }
    MOV SI,AX

    PUSH BP
    MOV DX,3C4h
    MOV AX,StartWritePlane
    OUT DX,AX
    MOV BX,AX
    MOV DX,3CEh
    MOV AX,0004h
    OUT DX,AX

    MOV AX,16+3
    SUB AX,rightcut
    PUSH AX
    SHR AX,1
    SHR AX,1
    MOV BP,AX
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    MOV DS,SCROLLADR

    PUSH SI
    PUSH DI
    MOV CX,BP   {1.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX   {ES:DI = ^nÑchste Kachel}

    MOV CX,BP   {2.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {3.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {4.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {5.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {6.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {7.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {8.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {9.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {10.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {11.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {12.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {13.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {14.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {15.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {16.Zeile}
    REP MOVSB

    POP DI
    POP SI

    POP BP
    SHL BH,1
    CMP BH,16
    JNE @nowrap12a
    MOV BH,1
    INC DI
   @nowrap12a:
    MOV AX,BX
    MOV DX,3C4h
    OUT DX,AX
    MOV DX,3CEh
    MOV AX,0104h
    OUT DX,AX

    DEC BP
    PUSH BP
    SHR BP,1
    SHR BP,1
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    PUSH SI
    PUSH DI
    MOV CX,BP   {1.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX   {ES:DI = ^nÑchste Kachel}

    MOV CX,BP   {2.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {3.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {4.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {5.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {6.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {7.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {8.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {9.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {10.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {11.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {12.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {13.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {14.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {15.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {16.Zeile}
    REP MOVSB

    POP DI
    POP SI

    POP BP
    SHL BH,1
    CMP BH,16
    JNE @nowrap12b
    MOV BH,1
    INC DI
   @nowrap12b:
    MOV AX,BX
    MOV DX,3C4h
    OUT DX,AX
    MOV DX,3CEh
    MOV AX,0204h
    OUT DX,AX

    DEC BP
    PUSH BP
    SHR BP,1
    SHR BP,1
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    PUSH SI
    PUSH DI
    MOV CX,BP   {1.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX   {ES:DI = ^nÑchste Kachel}

    MOV CX,BP   {2.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {3.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {4.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {5.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {6.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {7.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {8.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {9.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {10.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {11.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {12.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {13.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {14.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {15.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {16.Zeile}
    REP MOVSB

    POP DI
    POP SI

    POP BP
    SHL BH,1
    CMP BH,16
    JNE @nowrap12c
    MOV BH,1
    INC DI
   @nowrap12c:
    MOV AX,BX
    MOV DX,3C4h
    OUT DX,AX
    MOV DX,3CEh
    MOV AX,0304h
    OUT DX,AX

    DEC BP

    SHR BP,1
    SHR BP,1
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP



    MOV CX,BP   {1.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX   {ES:DI = ^nÑchste Kachel}

    MOV CX,BP   {2.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {3.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {4.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {5.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {6.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {7.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {8.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP   {9.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {10.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {11.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {12.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {13.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {14.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {15.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    MOV CX,BP  {16.Zeile}
    REP MOVSB
    ADD SI,DX
    ADD DI,AX

    DEC DI


    POP BP
    MOV AX,SEG @DATA
    MOV DS,AX

  {NÑchste Kachel; DI steht schon richtig:}
  MOV AX,XTiles
  ADD actIndex,AX
  (* MOV AX,16 *)
  (* ADD y,AX *)
  INC ytil

  DEC counter
  JNZ @m0repeat6

  MOV DI,tempDI
  MOV AX,tempActIndex
  MOV actIndex,AX
  (* MOV AX,tempX *)
  (* MOV x,tempX *)
  MOV AX,tempXtil
  MOV xtil,AX
  (* MOV AX,tempY *)
  (* MOV y,AX *)
  MOV AX,tempYtil
  MOV ytil,AX

 @m0RightLoopDone:
 @m0SkipRightColumn:
  {ES:DI = ^Zieladresse der ersten inneren Kachel (immer noch)}
  {innerTilesX >= 0, innerTilesX >= 1 -> es reichte, innerTilesX=0 zu prÅfen:}

  CMP innerTilesX,0   {IF (innerTilesX <= 0) OR (innerTilesY <= 0) THEN skip}
  JBE @m0SkipInnerTiles  {Falls keine inneren Kachel existieren, dann ist  }
                         {stattdessen bereits auf erste links nicht ge-    }
                         {schnittene Kachel der untersten Kachelzeile pos. }


  {Nun "FOR x:=1 TO innerTilesX DO FOR y:=1 TO innerTilesY DO .." realisieren}
  MOV oldDI,DI        {temporÑre Kopien von DI und actIndex anlegen}
  MOV AX,actIndex
  MOV oldActIndex,AX

  MOV AX,innerTilesX
  MOV counter,AX  {ZÑhler fÅr X-Richtung}
  MOV CL,6

 @m0xloop:
  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  MOV Xoffscreen,DX  {ist fÅr Kachelspalte konstant}

  MOV AX,innerTilesY
  MOV CH,AL  {CH dient als ZÑhler fÅr Y-Richtung}


 @m0yloop:
  MOV SI,oldActIndex {SI = temp. actIndex}
  AND SI,Xoffscreen
  JZ @m0go5
  MOV AX,ytil
  CWD
  SUB AX,YTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m0go5:
    {PROCEDURE DrawInnerTile mit WriteMode0: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     CL = 6              }
    {     SCROLLADR}
    {out: ES:DI = ^Zieladresse der nÑchsten Kachel darunter}
    {     CL = 6}
    {rem: WriteMode0 ist bereits gesetzt und bleibt gesetzt }
    {     CH wird nicht verÑndert!}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
                   {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }
    MOV SI,AX

    MOV DS,SCROLLADR

    MOV DX,3C4h
    MOV AX,StartWritePlane
    MOV BX,AX
    OUT DX,AX
    MOV DX,3CEh
    MOV AX,0004h
    OUT DX,AX

    MOVSW       {1.Zeile}
    MOVSW
    ADD DI,LINESIZE-4   {ES:DI = ^nÑchste Kachel}

    MOVSW       {2.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {3.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {4.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {5.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {6.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {7.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {8.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {9.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {10.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {11.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {12.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {13.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {14.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {15.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {16.Zeile}
    MOVSW

    SUB SI,16*4
    SUB DI,15*LINESIZE +4

    MOV AX,0104h
    OUT DX,AX      {DX = 3CEh}
    SHL BH,1
    CMP BH,16
    JNE @nowrap5a
    MOV BH,1
    INC DI
   @nowrap5a:
    MOV AX,BX
    MOV DX,3C4h
    OUT DX,AX

    MOVSW       {1.Zeile}
    MOVSW
    ADD DI,LINESIZE-4   {ES:DI = ^nÑchste Kachel}

    MOVSW       {2.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {3.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {4.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {5.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {6.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {7.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {8.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {9.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {10.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {11.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {12.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {13.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {14.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {15.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {16.Zeile}
    MOVSW

    SUB SI,16*4
    SUB DI,15*LINESIZE +4

    SHL BH,1
    CMP BH,16
    JNE @nowrap5b
    MOV BH,1
    INC DI
   @nowrap5b:
    MOV AX,BX
    OUT DX,AX      {DX = 3C4h}
    MOV DX,3CEh
    MOV AX,0204h
    OUT DX,AX

    MOVSW       {1.Zeile}
    MOVSW
    ADD DI,LINESIZE-4   {ES:DI = ^nÑchste Kachel}

    MOVSW       {2.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {3.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {4.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {5.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {6.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {7.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {8.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {9.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {10.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {11.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {12.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {13.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {14.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {15.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {16.Zeile}
    MOVSW

    SUB SI,16*4
    SUB DI,15*LINESIZE +4

    MOV AX,0304h
    OUT DX,AX      {DX = 3CEh}
    SHL BH,1
    CMP BH,16
    JNE @nowrap5c
    MOV BH,1
    INC DI
   @nowrap5c:
    MOV AX,BX
    MOV DX,3C4h
    OUT DX,AX

    MOVSW       {1.Zeile}
    MOVSW
    ADD DI,LINESIZE-4   {ES:DI = ^nÑchste Kachel}

    MOVSW       {2.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {3.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {4.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {5.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {6.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {7.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {8.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW       {9.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {10.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {11.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {12.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {13.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {14.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {15.Zeile}
    MOVSW
    ADD DI,LINESIZE-4

    MOVSW      {16.Zeile}
    MOVSW


    MOV AX,SEG @Data
    MOV DS,AX

    ADD DI,LINESIZE-4-1

  {NÑchste Kachel; DI steht schon richtig:}
  MOV AX,XTiles     {temp. actIndex in nÑchste Zeile setzen}
  ADD oldActIndex,AX
  INC ytil
  (* MOV AX,16 *)
  (* ADD y,AX *)

  DEC CH
  JNZ @m0yloop

  {actIndex hat noch seinen alten Wert, da nur oldActIndex verÑndert wurde.}
  INC actIndex        {actIndex = nÑchste innere Kachel in oberster Kachelzeile}
  MOV AX,actIndex     {und als Startwert fÅr nÑchste Spalte Åbernehmen}
  MOV oldActIndex,AX

  MOV DI,oldDI        {ES:DI = ^innere Kachel in oberster Kachelzeile}
  ADD DI,4            {eine Kachel weitersetzen}
  MOV oldDI,DI        {und als Startwert fÅr nÑchste Spalte Åbernehmen}

  MOV AX,tempYtil
  MOV ytil,AX     {Y-Koordinate wieder auf oberste innere Kachelzeile setzen}
  (* MOV AX,oldY *)
  (* MOV y,AX *)

  INC xtil      {X-Koordinate eine Kachelspalte weitersetzen}
  (* MOV AX,16 *)
  (* ADD x,AX *)

  DEC counter
  JNZ @m0xloop

  MOV DI,tempDI       {Damit: ES:DI, actIndex, xtil, ytil, x, y zeigen wieder}
  MOV AX,tempActIndex {auf die erste, innere Kachel  (N.B.: y, ytil wurden   }
  MOV actIndex,AX     {bereits weiter oben wiederhergestellt)}
  MOV AX,tempXtil
  MOV xtil,AX
  (* MOV AX,tempX *)
  (* MOV x,AX *)

  MOV AX,innerTilesY
  MOV DX,AX     {Kopie in DX aufheben}
  ADD ytil,AX   {ytil zeigt jetzt auf unterste Kachelzeile}

  MOV CL,5
  SHL AX,CL     {dto. fÅr DI: inc(DI,16 * innerTilesY * LINESIZE) }
  MOV BX,AX
  ADD DI,CS:[OFFSET GADR +BX]
  (* SHR AX,1 *)
  (* ADD y,AX *)  {dto. fÅr y: inc(y,16 * innerTilesY) }

  MOV AX,XTiles
  MUL DX          {AX := XTiles * innerTilesY}
  ADD actIndex,AX {dto. fÅr actIndex: inc(actIndex,XTiles * innerTilesY) }

 @m0SkipInnerTiles:
  {ES:DI, actIndex, xtil, ytil, x, y zeigen auf erste innere Kachel der}
  {untersten Kachelzeile}
  CMP bottomcut,0
  JE @m0fertig

  MOV AX,ytil
  CWD
  SUB AX,YTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  MOV Yoffscreen,DX

  MOV AX,innerTilesX
  OR AX,AX
  JBE @m0LowerInnerTilesDone {stehen wir bereits auf rechter unterer Eckkachel?}
  MOV counter,AX

  {Additionsfaktor berechnen, um von unten nach oben zu kommen:}
  {⁄ƒ¬ƒ¬ƒ¬ƒø    ⁄ƒ¬ƒ¬ƒ¬ƒø‹ }
  {√ƒ≈ƒ≈ƒ≈ƒ¥ ƒ> √ƒ≈ƒ≈ƒ≈ƒ¥  }
  {¿ƒ¡ƒ¡ƒ¡ƒŸ    ¿ƒ¡ƒ¡ƒ¡ƒŸ  }
  { ﬂ                      }
  {Korrektur:=-(16 - bottomcut) * LINESIZE + 4}
  MOV BX,16
  SUB BX,bottomcut
  SHL BX,1
  MOV AX,CS:[OFFSET GADR +BX]
  NEG AX
  ADD AX,4-1  {-1, weil durch Planing DI 1x erhîht wird}
  MOV Korrektur,AX

 @m0repeat4:
  MOV SI,actIndex
  AND SI,Yoffscreen
  JZ @m0go8

  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m0go8:
    {PROCEDURE DrawLowerInnerTile mit WriteMode0: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     bottomcut, Win*, SCROLLADR,...}
    {out: ES:DI = ^Zieladresse der nÑchsten Kachel rechts davon}
    {rem: WriteMode0 ist bereits gesetzt und bleibt gesetzt}
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }
    MOV SI,AX

    MOV CX,16
    SUB CX,bottomcut

    MOV DX,3CEh
    MOV AX,0004h
    OUT DX,AX
    MOV DX,3C4h
    MOV AX,StartWritePlane
    OUT DX,AX

    MOV DS,SCROLLADR

    MOV BX,CX
    PUSH SI
    PUSH DI
   @m0eineZeile4e1:
    MOVSW
    MOVSW
    ADD DI,LINESIZE-4
    LOOP @m0eineZeile4e1
    POP DI
    POP SI
    MOV CX,BX

    SHL AH,1
    CMP AH,16
    JNE @nowrap8a
    MOV AH,1
    INC DI
   @nowrap8a:
    MOV DX,3C4h
    OUT DX,AX
    MOV BX,AX
    MOV DX,3CEh
    MOV AX,0104h
    OUT DX,AX

    MOV AX,CX
    PUSH SI
    PUSH DI
   @m0eineZeile4e2:
    MOVSW
    MOVSW
    ADD DI,LINESIZE-4
    LOOP @m0eineZeile4e2
    POP DI
    POP SI
    MOV CX,AX

    MOV DX,3CEh
    MOV AX,0204h
    OUT DX,AX
    SHL BH,1
    CMP BH,16
    JNE @nowrap8b
    MOV BH,1
    INC DI
   @nowrap8b:
    MOV AX,BX
    MOV DX,3C4h
    OUT DX,AX

    MOV BX,CX
    PUSH SI
    PUSH DI
   @m0eineZeile4e3:
    MOVSW
    MOVSW
    ADD DI,LINESIZE-4
    LOOP @m0eineZeile4e3
    POP DI
    POP SI
    MOV CX,BX

    SHL AH,1
    CMP AH,16
    JNE @nowrap8c
    MOV AH,1
    INC DI
   @nowrap8c:
    MOV DX,3C4h
    OUT DX,AX
    MOV BX,AX
    MOV DX,3CEh
    MOV AX,0304h
    OUT DX,AX

   @m0eineZeile4e4:
    MOVSW
    MOVSW
    ADD DI,LINESIZE-4
    LOOP @m0eineZeile4e4


    MOV AX,SEG @Data
    MOV DS,AX

    {DI = ^Start der Zeile unterhalb der Kachel, jetzt auf Start der nÑchsten}
    {Kachel setzen:}
    {⁄ƒ¬ƒ¬ƒ¬ƒø    ⁄ƒ¬ƒ¬ƒ¬ƒø‹ }
    {√ƒ≈ƒ≈ƒ≈ƒ¥ ƒ> √ƒ≈ƒ≈ƒ≈ƒ¥  }
    {¿ƒ¡ƒ¡ƒ¡ƒŸ    ¿ƒ¡ƒ¡ƒ¡ƒŸ  }
    { ﬂ                      }
    ADD DI,Korrektur

  {Auf nÑchste Kachel rechts davon positionieren:}
  INC actIndex
  INC xtil
  (* MOV AX,16 *)
  (* ADD x,AX *)

  DEC counter
  JNZ @m0repeat4

 @m0LowerInnerTilesDone:
  {ES:DI, actIndex, xtil, ytil, x, y zeigen auf untere rechte Eckkachel}
  CMP rightcut,0
  JE @m0SkipLowerRightCorner

  PUSH DI
  MOV SI,actIndex
  AND SI,Yoffscreen
  JZ @m0go9
  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m0go9:
    {PROCEDURE DrawLowerRightTile mit WriteMode0: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     StartWritePlane = erste zu beschreibende Bitplane}
    {     rightcut MOD 4 = 0  }
    {     rightcut, bottomcut, Win*, SCROLLADR,...}
    {out: ES = ^Grafiksegment }
    {rem: WriteMode0 ist bereits gesetzt und bleibt gesetzt}
    PUSH BP
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }
    MOV SI,AX

    MOV CX,16
    SUB CX,bottomcut
    MOV BX,16+3
    SUB BX,rightcut
    PUSH BX
    SHR BX,1
    SHR BX,1  {BX = BytesPerPlane = (16 + 3 - rightcut) DIV 4}

    MOV DS,SCROLLADR

    MOV DX,3C4h
    MOV AX,StartWritePlane
    OUT DX,AX
    PUSH AX
    MOV DX,3CEh
    MOV AX,0004h
    OUT DX,AX

    MOV AX,LINESIZE
    SUB AX,BX
    MOV DX,4
    SUB DX,BX
    MOV BP,BX  {BP = Bytes je Zeile}
    MOV BL,CL  {BL = ZeilenzÑhler }
    MOV BH,CL  {Kopie nach BH}

    PUSH SI
    PUSH DI
   @m0eineZeile4g1:
    MOV CX,BP
    REP MOVSB
    ADD SI,DX
    ADD DI,AX
    DEC BL
    JNZ @m0eineZeile4g1
    POP DI
    POP SI
    MOV BL,BH

    POP AX
    SHL AH,1
    CMP AH,16
    JNE @nowrap9a
    MOV AH,1
    INC DI
   @nowrap9a:
    MOV DX,3C4h
    OUT DX,AX
    POP BP
    DEC BP
    PUSH BP
    PUSH AX
    MOV DX,3CEh
    MOV AX,0104h
    OUT DX,AX
    SHR BP,1
    SHR BP,1

    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    PUSH SI
    PUSH DI
   @m0eineZeile4g2:
    MOV CX,BP
    REP MOVSB
    ADD SI,DX
    ADD DI,AX
    DEC BL
    JNZ @m0eineZeile4g2
    POP DI
    POP SI
    MOV BL,BH

    POP AX
    SHL AH,1
    CMP AH,16
    JNE @nowrap9b
    MOV AH,1
    INC DI
   @nowrap9b:
    MOV DX,3C4h
    OUT DX,AX
    POP BP
    DEC BP
    PUSH BP
    PUSH AX
    MOV DX,3CEh
    MOV AX,0204h
    OUT DX,AX
    SHR BP,1
    SHR BP,1

    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    PUSH SI
    PUSH DI
   @m0eineZeile4g3:
    MOV CX,BP
    REP MOVSB
    ADD SI,DX
    ADD DI,AX
    DEC BL
    JNZ @m0eineZeile4g3
    POP DI
    POP SI
    MOV BL,BH

    POP AX
    SHL AH,1
    CMP AH,16
    JNE @nowrap9c
    MOV AH,1
    INC DI
   @nowrap9c:
    MOV DX,3C4h
    OUT DX,AX
    POP BP
    DEC BP
    MOV DX,3CEh
    MOV AX,0304h
    OUT DX,AX
    SHR BP,1
    SHR BP,1

    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

   @m0eineZeile4g4:
    MOV CX,BP
    REP MOVSB
    ADD SI,DX
    ADD DI,AX
    DEC BL
    JNZ @m0eineZeile4g4


    POP BP
    MOV AX,SEG @DATA
    MOV DS,AX

  POP DI   {ES:DI etc. zeigen auf rechte untere Eckkachel}

 @m0SkipLowerRightCorner:
  CMP leftcut,0
  JE @m0fertig

  {jetzt auf linke untere Eckkachel positionieren:}
  MOV AX,innerTilesX
  INC AX
  SUB actIndex,AX  {dec(actIndex,innerTilesX + 1) }
  SUB xtil,AX      {dec(xtil,innerTilesX + 1) }
  MOV CL,2
  SHL AX,CL
  SUB DI,AX        {dec(DI,4 * (innerTilesX + 1) }
  ADD DI,leftcutDIV4 {berÅcksichtige: Eckkachel kann links geschnitten sein}
  INC DI
  (* MOV AX,WinXMIN *)
  (* MOV x,AX *)

  MOV SI,actIndex
  AND SI,Yoffscreen
  JZ @m0go7
  MOV AX,xtil
  CWD
  SUB AX,XTiles
  NOT AX
  OR AX,DX
  CWD
  NOT DX
  AND SI,DX
 @m0go7:
    {PROCEDURE DrawLowerLeftTile mit WriteMode0: }
    { in: ES:DI = ^Zieladresse}
    {     SI = Kachelindex    }
    {     StartLesePlane = erste Bitplane, von der gelesen wird}
    {     rightcut MOD 4 = 0  }
    {     leftcut, bottomcut, Win*, SCROLLADR,...}
    {out: (ES = ^Grafiksegment) }
    {rem: WriteMode0 ist bereits gesetzt (und bleibt gesetzt)}
    PUSH BP
    MOV AL,[OFFSET BackTile +SI]
    XOR AH,AH      {Offsetadresse der Kachel berechnen:}
    MOV CL,6       {jede Kachel ist 64 Bytes lang, also}
    SHL AX,CL      {AX := Kachel * 64 = Kachel SHL 6   }
    MOV SI,AX

    MOV AX,leftcut
    MOV BX,AX
    MOV CL,2
    SHR AX,CL
    ADD SI,AX

    MOV CX,16
    SUB CX,bottomcut

    MOV DS,SCROLLADR

    MOV DX,3C4h
    MOV AX,0102h
    OUT DX,AX
    MOV DX,3CEh
    MOV AX,StartLesePlane
    OUT DX,AX

    MOV BP,16+3
    SUB BP,BX
    PUSH BP
    PUSH AX
    SHR BP,1
    SHR BP,1    {BP := (16 + 3 - leftcut) DIV 4}

    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP

    MOV BL,CL   {BL=ZeilenzÑhler}
    MOV BH,CL   {Kopie davon}

    PUSH SI
    PUSH DI
   @m0eineZeile4d1:
    MOV CX,BP
    REP MOVSB
    ADD SI,DX
    ADD DI,AX
    DEC BL
    JNZ @m0eineZeile4d1
    POP DI
    POP SI

    POP AX
    INC AH
    AND AH,3
    JNE @nowrap7a
    INC SI
   @nowrap7a:
    MOV DX,3CEh
    OUT DX,AX
    POP BP
    DEC BP
    PUSH BP
    PUSH AX
    MOV DX,3C4h
    MOV AX,0202h
    OUT DX,AX
    SHR BP,1
    SHR BP,1
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP
    MOV BL,BH

    PUSH SI
    PUSH DI
   @m0eineZeile4d2:
    MOV CX,BP
    REP MOVSB
    ADD SI,DX
    ADD DI,AX
    DEC BL
    JNZ @m0eineZeile4d2
    POP DI
    POP SI

    POP AX
    INC AH
    AND AH,3
    JNE @nowrap7b
    INC SI
   @nowrap7b:
    MOV DX,3CEh
    OUT DX,AX
    POP BP
    DEC BP
    PUSH BP
    PUSH AX
    MOV DX,3C4h
    MOV AX,0402h
    OUT DX,AX
    SHR BP,1
    SHR BP,1
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP
    MOV BL,BH

    PUSH SI
    PUSH DI
   @m0eineZeile4d3:
    MOV CX,BP
    REP MOVSB
    ADD SI,DX
    ADD DI,AX
    DEC BL
    JNZ @m0eineZeile4d3
    POP DI
    POP SI

    POP AX
    INC AH
    AND AH,3
    JNE @nowrap7c
    INC SI
   @nowrap7c:
    MOV DX,3CEh
    OUT DX,AX
    POP BP
    DEC BP
    MOV DX,3C4h
    MOV AX,0802h
    OUT DX,AX
    SHR BP,1
    SHR BP,1
    MOV AX,LINESIZE
    SUB AX,BP
    MOV DX,4
    SUB DX,BP
    MOV BL,BH

   @m0eineZeile4d4:
    MOV CX,BP
    REP MOVSB
    ADD SI,DX
    ADD DI,AX
    DEC BL
    JNZ @m0eineZeile4d4


    POP BP
    MOV AX,SEG @DATA
    MOV DS,AX

 @m0fertig:


  {------- ab hier: Sprites auf aktuelle Grafikseite bringen}

  @Sprites_zeichnen:
    MOV SI,NMAX*2
    PUSH BP      {BP nachher wieder poppen!}


    @zeichne:
     CMP SI,SplitIndex_mal2  {Splitpunkt?}
     JNE @SZeich

     MOV AX,WinXMIN
     {ja: Win* Werte auf gesamte FlÑche (0,0)..(XMAX,YMAX) setzen:}
     OR AX,WinYMIN
     JNZ @replace1
     CMP WinXMAX,XMAX
     JNE @replace2
     CMP WinYMAX,YMAX
     JE @replacedone
     JMP @replace3 {short}

    @replace1:
     MOV WinXMIN,0
     MOV WinYMIN,0
     MOV WinXMINdiv4,0
     MOV WinYMIN_mul_LINESIZE,0
     MOV WinYMINmLINESIZEaWinXMINdiv4,0
    @replace2:
     MOV WinXMAX,XMAX
     MOV WinWidth,XMAX+1
     MOV WinWidthDiv4,(XMAX+1)/4
    @replace3:
     MOV WinYMAX,YMAX
     MOV WinHeight,YMAX+1
     MOV WinLowerRight,0
    @replacedone:

    {DS = normales Datensegment, ES = Grafikseitensegment, }
    {SI = Spritepositionsnummer * 2                        }
    @SZeich:
      MOV BX,[SI + OFFSET SpriteN]   {BX = SpriteN[?] = Spriteladenummer}
      SHL BX,1                       {BX = Spriteladenummer * 2}

    {Jetzt: "SpriteN[?] := SpriteN[NextSprite[?]]" berechnen:}
      MOV BX,[BX + OFFSET NextSprite] {AX = NextSprite[SpriteN[?]]}
      MOV [SI + OFFSET SpriteN],BX    {als neue SpriteN[?] Åbernehmen}
      SHL BX,1


      JNZ @aktiv
      JMP @noSprite


    @aktiv:
      PUSH SI           {Spritepositionsnummer * 2 retten}

      MOV DX,[SI + OFFSET SpriteX]   {if SpriteX > xmax then skip_sprite}
      SUB DX,StartVirtualX           {virtuelle -> absolute Koordinaten }
      MOV AX,WinXMAX
      CMP DX,AX
      JLE @L0
    @ToSprite_fertig:                {Sprungleiste zu @Sprite_fertig}
      JMP @Sprite_fertig
    @L0:
      MOV CS:WORD PTR @akt_SpriteX+1,DX
      MOV DI,[SI + OFFSET SpriteY]   {DI = SpriteY_virtuell}
      SUB DI,StartVirtualY           {DI = SpriteY (absolut!)}

      PUSH AX                        {WinXMAX}
      MOV AX,WinYMIN
      MOV SI,WinXMIN
      MOV CX,WinYMAX                 {alte Win* Werte retten...}

      MOV DS,[BX + OFFSET SPRITEAD]  {!!!DS = ^Spritedaten !!!}

      MOV [WinYMIN_],AX              {...und in neues DS Åbernehmen}
      MOV [WinXMIN_],SI
      POP AX
      MOV [WinXMAX_],AX              {WinYMAX in CX halten}

      MOV AX,[Breite]                {AX = Breite in 4er-Gruppen}
      MOV CS:WORD PTR @max_Breite+1,AX
      MOV SI,AX                      {SI = dto.}
      SHL AX,1
      SHL AX,1                       {AX = max_Breite_in_Punkten}
      ADD AX,DX                      {AX = max_Breite_in_Punkten+SpriteX}
      CMP AX,[WinXMIN_]   {liegt rechtes Ende links vom Fensterrand?}
      JL @ToSprite_fertig
      MOV BX,DI                      {if SpriteY - WinYMIN >= 0 }
      SUB DI,[WinYMIN_]              { then starty := 0}
      NEG DI                         { else starty := -(SpriteY - WinYMIN)}
      MOV BP,DI
      JG @Top_cut
      XOR DI,DI
    @Top_cut:                        {DI = starty, BP = -(SpriteY - WinYMIN)}
      MOV AX,[Hoehe]                 {AX = Hoehe (in Zeilen)  }
      CMP DI,AX                      {if starty >= Hoehe then skip_sprite}
      JGE @ToSprite_fertig
      ADD BP,CX                      {BP = -(SpriteY - WinYMIN) + WinYMAX}
      SUB BP,[WinYMIN_]
      JL @ToSprite_fertig            {(etwas frei:) }
      CMP AX,BP                      {if Hoehe + SpriteY > WinYMAX  }
      JG @To_then                    { then [ endy := WinYMAX - SpriteY }
      DEC AX                         {       if endy < 0 then skip_sprite ] }
      MOV BP,AX                      { else endy := Hoehe - 1 }

    {BP = endy, SI=[@max_Breite+1] = max_Breite_in_4er_Gruppen, }
    {DI = starty, BX = SpriteY, DX=[@akt_SpriteX+1] = SpriteX,  }
    {DS = ^Spritedaten, ES = ^Grafikseite}
    @To_then:
      MOV AX,BP
      SUB BP,DI

      SHL BP,1
      MOV [End_min_Start],BP         {= (endy - starty) * 2 =Yaktuell * 2}
      ADD BX,AX
      SHL BX,1
      MOV BX,CS:[OFFSET gadr + BX] {BX =zeilenadr :=(endy + SpriteY) * LINESIZE}
      MOV [zeilenadr],BX             {auch nach [zeilenadr] }
      MOV BP,DX
      MUL SI                         {AX = endy * max_Breite_in_4er = yoffset}
      MOV [yoffset_],AX              {auch nach [yoffset_]}
      SHL DI,1                       {DI = starty * 2}
      MOV CS:WORD PTR @Starty_2+1,DI {auch nach [@Starty_2 + 1] }

      {kleiner Einschub: anhand des Modusbytes des Sprites entscheiden, ob}
      {eine andere Routine zur Darstellung des Sprites als die gerade ak- }
      {tive benîtigt wird und wenn ja, diese in Position bringen!         }
      {Verwendete Register: AX und SI                                     }
       MOV AL,[Modus]                {Modusbyte des Sprites holen}
       XOR AH,AH
       SHL AX,1
       MOV SI,AX
       MOV SI,CS:[OFFSET Adressen +SI] {Pointer auf zugehîrige Routine holen}
       MOV AX,CS:[SI]
       CMP AX,CS:[WORD PTR @Patch1]    {ist diese Routine bereits aktiv?}
       JE @no_newcode                  {ja, nix zu tun}
       PUSH DS                         {nein, kopiere die Routine an die}
       PUSH CS                         {entsprechenden Stellen}
       POP DS
       MOV [WORD PTR @Patch1],AX
       MOV [WORD PTR @Patch2],AX
       MOV [WORD PTR @Patch3],AX
       MOV [WORD PTR @Patch4],AX
       INC SI
       INC SI
       LODSW
       MOV [WORD PTR @Patch1+2],AX
       MOV [WORD PTR @Patch2+2],AX
       MOV [WORD PTR @Patch3+2],AX
       MOV [WORD PTR @Patch4+2],AX
       LODSW
       MOV [WORD PTR @Patch1+4],AX
       MOV [WORD PTR @Patch2+4],AX
       MOV [WORD PTR @Patch3+4],AX
       MOV [WORD PTR @Patch4+4],AX
       LODSW
       MOV [WORD PTR @Patch1+6],AX
       MOV [WORD PTR @Patch2+6],AX
       MOV [WORD PTR @Patch3+6],AX
       MOV [WORD PTR @Patch4+6],AX
       LODSW
       MOV [WORD PTR @Patch1+8],AX
       MOV [WORD PTR @Patch2+8],AX
       MOV [WORD PTR @Patch3+8],AX
       MOV [WORD PTR @Patch4+8],AX
       LODSW
       MOV [WORD PTR @Patch1+10],AX
       MOV [WORD PTR @Patch2+10],AX
       MOV [WORD PTR @Patch3+10],AX
       MOV [WORD PTR @Patch4+10],AX
       LODSW
       MOV [WORD PTR @Patch1+12],AX
       MOV [WORD PTR @Patch2+12],AX
       MOV [WORD PTR @Patch3+12],AX
       MOV [WORD PTR @Patch4+12],AX
       LODSW
       MOV [WORD PTR @Patch1+14],AX
       MOV [WORD PTR @Patch2+14],AX
       MOV [WORD PTR @Patch3+14],AX
       MOV [WORD PTR @Patch4+14],AX

       POP DS                          {DS wiederherstellen}
     @no_newcode:


    {(AX=)[yoffset_]         = yoffset }
    { BX = [zeilenadr]       = (endy + SpriteY) * LINESIZE}
    { CX                     = WinYMAX }
    { DI = [@Starty_2 + 1]   = starty * 2}
    {(SI = [@max_Breite + 1] = max_Breite_in_4er_) }
    { BP = [@akt_SpriteX + 1]= SpriteX}
    { DS                     = ^Spritedaten}
    { ES                     = ^Grafikseite}
    { [end_min_start]        = (endy - starty) * 2 = Yaktuell * 2}
    { [@max_Breite + 1]      = max_Breite_in_4er_Gruppen  }
    @eine_Zeile:
      MOV SI,[end_min_start]         {SI = Yaktuell * 2 }
      ADD SI,DI                      {startx := sprite[WORD PTR sprite[L] +  }
      MOV DI,SI                      {              (Yaktuell + starty) * 2] }
      ADD SI,[Left]
      MOV SI,[SI]                    {SI = startx, DI = (Yaktuell + starty) * 2}
      MOV AX,BP
      MOV DX,AX                      {AX = DX = SpriteX}
      SUB BP,[WinXMIN_]              {BP = SpriteX - WinXMIN}
      ADD AX,SI                      {AX = bildschirmstartx := SpriteX + startx }
      CMP AX,[WinXMAX_]       {if bildschirmstartx > WinXMAX then skip_zeile}
      JG @ToZeile_fertig
      MOV CX,SI                      {CX = startx}
      SUB AX,[WinXMIN_]              {licutoff_in_Punkten := startx}
      JGE @L1                        {if bildschirmstartx < WinXMIN then }
      SUB SI,AX                      { [dec(startx,bildschirmstartx - WinXMIN) }
      XOR AX,AX                      {  bildschirmstartx := WinXMIN      }
      MOV CX,BP                      {  licutoff_in_Punkten := -SpriteX] }
      NEG CX
    @L1:
      ADD AX,[WinXMIN_]              {CX = [licutoff_] = licutoff_in_Punkten, }
      MOV [licutoff_],CX             {SI = startx, AX = bildschirmstartx   }
      ADD DI,[Right]
      MOV DI,[DI]                    {DI = endx := sprite[WORD PTR sprite[R] +  }
                                     {                (Yaktuell + starty) * 2]  }
      NEG DX                         {DX = -SpriteX }
      MOV BP,DI
      SUB BP,SI                      {BP = endx - startx }
      SUB DX,DI                      {DX = -(SpriteX + endx) }
      ADD DX,[WinXMAX_]              {DX = öberhang := WinXMAX - (SpriteX + endx) }
      JNS @kein_Ueberhang_rechts
      ADD BP,DX
    @kein_Ueberhang_rechts:          {BP = sichtbare Breite dieser Zeile -1}
      OR BP,BP
      JNS @L6
    @ToZeile_fertig:
      JMP @Zeile_fertig              {if Breite <= 0 then skip_zeile }
    @L6:
      ADD BP,4

      { AX                 = bildschirmstartx}
      { BX = [zeilenadr]   = (endy + SpriteY) * LINESIZE }
      { CX = [licutoff_]   = licutoff_in_Punkten}
      {(DX                 = (negativer) öberhang (falls Wert < 0) ) }
      {(SI                 = startx) }
      {(DI                 = endx) }
      { BP                 = Breite fÅr diese Zeile in Punkten + 3 }
      { DS                 = ^Spritedaten}
      { ES                 = ^Grafikseite}
      { [@max_Breite + 1]  = max_Breite_in_4er_) }
      { [end_min_start]    = (endy - starty) * 2 =Yaktuell * 2}
      { [@Starty_2 + 1]    = starty * 2}
      { [@max_Breite + 1]  = max_Breite_in_4er_Gruppen, }
      { [@akt_SpriteX + 1] = SpriteX}
      MOV [bildx],AX                 {bildschirmstartx retten}
      MOV DX,CX                      {DX = licutoff_in_Punkten}
      MOV CX,BP
      SHR CX,1
      SHR CX,1                       {CX = Breite DIV 4}
      JCXZ @Plane1

      {SI = Quellzeiger := sprite[WORD PTR (licutoff_in_Punkten + 0 AND 3) * 2}
      {                       + (licutoff_in_Punkten + 0) DIV 4 + yoffset  }
      MOV SI,DX
      AND SI,3                       
      SHL SI,1                  {SI = ((licutoff_in_Punkten + 0) AND 3) * 2}
      MOV SI,[SI]                    
      MOV DI,DX
      SHR DI,1
      SHR DI,1
      ADD SI,DI
      ADD SI,[yoffset_]              {SI = sprite[WORD PTR (licutoff_...)]   }
                                     {     + (licutoff_in_Punkten + i) DIV 4 }
                                     {     + yoffset                         }

      {DI = Zielzeiger := (bildschirmstartx + 0) DIV 4 + zeilenadr}
      MOV DI,AX                      {DI = bildschirmstartx }
      SHR DI,1
      SHR DI,1
      ADD DI,BX
      MOV BL,AL
      AND BX,3                       {BX = (bildschirmstartx + i) AND 3 }
      MOV AH,Translate[BX]           {AH = 1,2,4,8 fÅr BX = 0,1,2,3     }
      MOV AL,2
      MOV DX,3C4h
      OUT DX,AX                      {Plane auswÑhlen}

      XCHG BX,DI
      {CX Bytes von DS:SI nach ES:BX Åbertragen }
      {Hierher kommt die Routine zur DatenÅbertragung!}
    @Patch1:
      db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    @Plane1:
      MOV DX,[bildx]
      INC DX                      {DX = bildschirmstartx+1}
      MOV BX,DX
      SHR BX,1
      SHR BX,1                    {BX = zielzeiger := (bildschirmstartx + 1) }
      ADD BX,[zeilenadr]          {                DIV 4 + zeilenadr    }
      MOV CX,BP
      DEC CX                      {CX = Breite dieser Zeile + 3 - 1 }
      SHR CX,1
      SHR CX,1                    {CX = Bytes_zu_moven fÅr i = 1 }
      JCXZ @Plane2
      MOV DI,[licutoff_]
      INC DI                      {DI = (licutoff_in_Punkten + 1) }
      MOV SI,DI
      AND SI,3
      SHL SI,1                    {SI = ((licutoff_in_Punkten + 1) AND 3) * 2}
      MOV SI,[SI]                 {SI = sprite[WORD PTR licutoff_...]     }
      SHR DI,1                    {     + (licutoff_in_Punkten + 1) DIV 4 }
      SHR DI,1                    {     + yoffset                         }
      ADD SI,DI
      ADD SI,[yoffset_]           {SI = Quellzeiger, }
                                  {DI = (licutoff_in_Punkten + 1) DIV 4 }

      MOV DI,DX                   {DI = bildschirmstartx + 1}
      AND DI,3                    {DI = (bildschirmstartx + 1) AND 3 }
      MOV AH,Translate[DI]        {Maske fÅr Portzugriff laden}
      MOV AL,2
      MOV DX,3C4h                 {Plane anwÑhlen}
      OUT DX,AX

      {Hierher kommt die Routine zur DatenÅbertragung!}
    @Patch2:
      db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    @Plane2:
      MOV DX,[bildx]
      ADD DX,2
      MOV BX,DX
      SHR BX,1
      SHR BX,1
      ADD BX,[zeilenadr]
      MOV CX,BP
      SUB CX,2
      SHR CX,1
      SHR CX,1
      JCXZ @Plane3
      MOV DI,[licutoff_]
      ADD DI,2
      MOV SI,DI
      AND SI,3
      SHL SI,1
      MOV SI,[SI]
      SHR DI,1
      SHR DI,1
      ADD SI,DI
      ADD SI,[yoffset_]

      MOV DI,DX                      {DI = bildschirmstartx + 2}
      AND DI,3                       {DI = (bildschirmstartx + 1) AND 3 }
      MOV AH,Translate[DI]
      MOV AL,2
      MOV DX,3C4h
      OUT DX,AX

      {Hierher kommt die Routine zur DatenÅbertragung!}
    @Patch3:
      db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    @Plane3:
      MOV DX,[bildx]
      ADD DX,3
      MOV BX,DX
      SHR BX,1
      SHR BX,1
      ADD BX,[zeilenadr]
      MOV CX,BP
      SUB CX,3
      SHR CX,1
      SHR CX,1
      JCXZ @Zeile_fertig
      MOV DI,[licutoff_]
      ADD DI,3
      MOV SI,DI
      AND SI,3
      SHL SI,1
      MOV SI,[SI]
      SHR DI,1
      SHR DI,1
      ADD SI,DI
      ADD SI,[yoffset_]

      MOV DI,DX                      {DI = bildschirmstartx + 3}
      AND DI,3                       {DI = (bildschirmstartx + 1) AND 3 }
      MOV AH,Translate[DI]
      MOV AL,2
      MOV DX,3C4h
      OUT DX,AX

      {Hierher kommt die Routine zur DatenÅbertragung!}
    @Patch4:
      db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

    @Zeile_fertig:
      MOV AX,[yoffset_]
    @max_Breite:
      SUB AX,1234
      MOV [yoffset_],AX
      MOV BX,[zeilenadr]
      SUB BX,LINESIZE
      MOV [zeilenadr],BX
      SUB WORD PTR [end_min_start],2
      JS @Sprite_fertig

    @Starty_2:
      MOV DI,1234
    @akt_SpriteX:
      MOV BP,1234
      JMP @eine_Zeile

    @Sprite_fertig:
      POP SI
      MOV AX,SEG @Data
      MOV DS,AX

    @noSprite:
      DEC SI
      DEC SI
      JS @fertig
      JMP @zeichne
    @fertig:

      POP BP

      {Win* Werte wieder auf alte Werte zurÅcksetzen --wenn nîtig:}
      MOV AX,SplitIndex
      CMP AX,NMAX
      JGE @skip  {IF (SplitIndex<0) OR (SplitIndex>NMAX) THEN Skip}

      MOV AX,BWinLowerRight
      MOV WinLowerRight,AX
      MOV BX,BWinXMIN
      MOV WinXMIN,BX
      MOV SI,BX           {SI := WinXMIN}
      SHR BX,1
      SHR BX,1
      MOV WinXMINdiv4,BX  {BX := WinXMIN div 4}
      MOV CX,BWinYMIN
      MOV WinYMIN,CX      {CX := WinYMIN}
      MOV AX,BWinYMIN_mul_LINESIZE
      MOV WinYMIN_mul_LINESIZE,AX
      ADD AX,BX
      MOV WinYMINmLINESIZEaWinXMINdiv4,AX
      MOV AX,BWinXMAX
      MOV WinXMAX,AX      {AX := WinXMAX}
      MOV DX,BWinYMAX
      MOV WinYMAX,DX      {DX := WinYMAX}
      SUB DX,CX
      INC DX
      MOV WinHeight,DX
      SUB AX,SI
      INC AX
      MOV WinWidth,AX
      SHR AX,1
      SHR AX,1
      MOV WinWidthDiv4,AL
    @skip:

                                 {"CX := Offset_Adr[Page]" vorbereiten:}
      MOV SI,PAGE                {Pagewert * 2 (da WorteintrÑge!)}
      MOV BX,SI                  {Pagewert in BX merken!}
      SHL SI,1                   {dazu Startadresse des Feldes addieren}
      ADD SI,OFFSET Offset_Adr-StartIndex*2  {evtl. Verschiebung korrigieren}
      LODSW                      {Realisiere "AX := Offset_Adr[Page]"}
      MOV CX,AX                  {nach CX bringen}
      MOV DI,CRTAddress          {DI := CRTAddress }

    {Die Grafikseite ist nun fertiggestellt und mu· noch angezeigt werden:}
      cli
      mov  dx,StatusReg

    {Auf "display enable"=0 (d.h.: aktiv) warten, so da· Seitenumschaltung}
    {fÅr HB/LB auf selber Seite geschieht:}

    @WaitNotHSyncLoop:
      in   al,dx
      and  al,1
      jz  @WaitNotHSyncLoop

    @WaitHSyncLoop:
      in   al,dx
      and  al,1
      jnz  @WaitHSyncLoop

      MOV DX,DI                  {DX := CRTAddress}
      MOV AL,$0D                 {LB-Startadress-Register}
      OUT DX,AL
      INC DX
                                 
      MOV AX,CX                  {AX := Offset_Adr[Page]}
      OUT DX,AL                  {LB der neuen Startadresse setzen}
      DEC DX
      MOV AL,$0C
      OUT DX,AL
      INC DX
      MOV AL,AH                  {HB der neuen Startadresse setzen}
      OUT DX,AL
      STI

      NEG BX       {neuer PAGE-Wert := 1-alter PAGE-Wert, d.h.:  }
      ADD BX,1     {IF PAGE = 0 THEN PAGE := 1 ELSE (PAGE = 1) PAGE := 0 }
      MOV PAGE,BX

      SHL BX,1     {neuer PAGEADR-Wert := Segment_Adr[PAGE] }
      ADD BX,OFFSET Segment_Adr-StartIndex*2
      MOV AX,[BX]
      MOV PAGEADR,AX

      {Jetzt ÅberprÅfen, ob gesetzte Zyklus(mindest)zeit abgelaufen ist:}
    @L10:
      MOV AL,TimeFlag   {Bit 7 = 0/1 fÅr Zeit ist abgelaufen/lÑuft noch }
      AND AL,$80
      JE @L10

      {ZeitÅberwachung fÅr nÑchsten Zyklus starten:}
      MOV AL,IsAT                 {ist das ein AT/386? ($0/$80 = ja/nein)  }
      OR AL,AL                    {Zeitmechanismus geht nur auf AT/386     }
      JNE @L11                    {anderenfalls keine ZeitÅberwachung!     }
      MOV TimeFlag,AL             {AL = 0 zugleich als Init-Wert benutzen  }
      MOV DX,WORD PTR CycleTime   {Mindestzykluszeit (in Mikrosekunden)    }
      MOV CX,WORD PTR CycleTime+2 {eintragen: CX = HIGH-Word, DX = LOW-Word}
      MOV BX,OFFSET TimeFlag      {ES:BX = Zeiger auf TimeFlag, Bit 7 = 0/1}
      MOV AX,DS                   {fÅr: Zeit lÑuft noch/ist um             }
      MOV ES,AX
      MOV AX,8300h                {ZeitÅberwachung starten}
      INT 15h
    @L11:
 END; {of ASM}
END; {of ANIMATE}

PROCEDURE FreeSpriteMem(number:WORD);
{ in: number = Ladenummer des Sprites, das freigegeben werden soll}
{out: belegter Speicher wurde freigegeben, SPRITEAD[number] auf 0 und}
{     SPRITEPTR[number] auf NIL gesetzt}
{rem: Spritenummern auf den freigegebenen Bereich sind anschlie·end}
{     natÅrlich nicht mehr erlaubt!}
{     War unter "number" kein Sprite geladen, so passiert nichts}
{     Evtl. Spritezyklen mÅssen durch entsprechend viele Aufrufe dieser}
{     Routine aufgelîst werden.}
BEGIN
 IF (number<1) OR (number>LoadMAX)
  THEN Error:=Err_InvalidSpriteLoadNumber
  ELSE IF SPRITEPTR[number]<>NIL
        THEN BEGIN
              FreeMem(SPRITEPTR[number],SPRITESIZE[number]);
              SPRITEPTR[number]:=NIL;
              SPRITESIZE[number]:=0;
              SPRITEAD[number]:=0
             END
END;

FUNCTION LoadSprite(name:String; number:WORD):WORD;
{ in: name   = Name des zu ladenden Sprite-Files (Typ: "*.COD" / "*.LIB" )}
{     number = Nummer, die das erste Sprite aus diesem File bekommen soll }
{out: Anzahl der aus dem File gelesenen Sprites (0 = Fehler trat auf)     }
{rem: Die Routine erkennt automatisch, ob es sich bei dem File um ein     }
{     zelnes Sprite oder eine ganze Spritebibliothek handelt und lÑdt     }
{     alle Spritedaten auf den Heap, und zwar derart, da· die Adresse     }
{     immer auf eine Segmentgrenze fÑllt. Diese Anfangsadressen werden    }
{     dann in der Tabelle SPRITEAD[number] abgelegt; sind mehrere Sprites }
{     in der Datei, so werden sie mit fortlaufender Nummer eingetragen,   }
{     also number+i }
LABEL quit_loop;
VAR p1,p2:Pointer;
    f:FileOfByte;
    count:WORD;
    Header:SpriteHeader;
    tempName:STRING;
BEGIN
 count:=0;  {Zahl der bisher eingelesenen Sprites}

 tempName:=FindFile(name);
 IF tempName<>'' THEN name:=tempName;

 _assign(f,name);
 {$I-} _reset(f); {$IFDEF IOcheck} {$I+} {$ENDIF}
 if (ioresult<>0) OR (CompressError<>CompressErr_NoError)
  THEN BEGIN  {Datei existiert nicht oder nicht unter diesem Pfad}
        Error:=Err_FileIO;
        CompressError:=CompressErr_NoError;
        loadSprite:=0; exit
       END;
 IF (number=0) or (number>LoadMAX)
  THEN BEGIN
        Error:=Err_InvalidSpritenumber;
        goto quit_loop;
       END;
 WHILE NOT _physicalEOF(f) DO
 BEGIN
  {ZunÑchst den Spriteheader einlesen: }
  {$I-}     {jetzt den Spriteheader viÖ BLOCKREAD auf den Heap laden}
  _blockread(f,Header,Kopf);
  {$IFDEF IOcheck} {$I+} {$ENDIF}

  IF (ioresult<>0) OR (CompressError<>CompressErr_NoError)
   THEN BEGIN
         Error:=Err_FileIO;
         CompressError:=CompressErr_NoError;
         goto quit_loop;
        END;
  IF (Header.Kennung[1]<>'K') or (Header.Kennung[2]<>'R')
   THEN BEGIN
         Error:=Err_NoSprite;
         goto quit_loop;
        END;
  {noch genug Platz da?}
  IF (Header.SpriteLength+15>MaxAvail+SPRITESIZE[number+count])
   THEN BEGIN 
         Error:=Err_NotEnoughMemory;
         goto quit_loop;
        END;

  FreeSpriteMem(number+count);  {evtl. alten Speicher freigeben}

  {Jetzt eigentliche Spritedaten einlesen: }
  getmem(p1,Header.SpriteLength+15);       {genug Platz reservieren}
  SPRITESIZE[number+count]:=Header.SpriteLength+15;
  SPRITEPTR [number+count]:=p1;
  IF (LONGINT(p1) mod 16)=0
   THEN p2:=p1                             {p2 auf Segmentgrenze bringen}
   ELSE LONGINT(p2):=LONGINT(p1) + (16-LONGINT(p1) mod 16);

  MOVE(Header,p2^,Kopf);  {Spriteheader auf Heap bringen}
  LONGINT(p1):=LONGINT(p2)+Kopf;   {zeigt genau hinter den Header}

  {$I-}     {jetzt den "Rest" des Sprites laden}
  _blockread(f,p1^,Header.SpriteLength-Kopf);
  {$IFDEF IOcheck} {$I+} {$ENDIF}
  IF (ioresult<>0) OR (CompressError<>CompressErr_NoError)
   THEN BEGIN
         Error:=Err_FileIO;
         CompressError:=CompressErr_NoError;
         goto quit_loop;
        END;

  {der Spritenummer zuordnen:}
  spritead[number+count]:=(longint(p2) shr 16)
                         +(longint(p2) and 65535) shr 4;
  INC(count);

  IF (NOT _physicalEOF(f)) AND
     ( (NOT f.komprimiert) OR (_logicalEOF(f)) )
   THEN Resync(f)
 END;

quit_loop: ;
 _close(f);
 loadSprite:=count
END;

FUNCTION LoadTile(name:STRING; number:BYTE):WORD;
{ in: name   = Name des zu ladenden Sprite-Files (Typ: "*.COD" / "*.LIB" )}
{     number = 0..255 = Tilenummer fÅr das erste Sprite der Datei         }
{out: Anzahl der aus dem File gelesenen Tiles (0 = Fehler trat auf)       }
{rem: Die Routine erkennt automatisch, ob es sich bei dem File um ein     }
{     einzelnes Sprite oder eine ganze Spritebibliothek handelt und lÑdt  }
{     alle Sprites, zerlegt diese in Tiles und legt sie in der 4.Grafik-  }
{     seite ab, beginnend mit der Åbergebenen Nummer number               }
{     Da eine Kachel 16x16 Punkte gro· ist, mÅssen die Sprites ein Viel-  }
{     faches von 16 Punkten in x- und y-Richtung sein                     }
{     EnthÑlt die Datei mehrere Tiles, so werden sie zeilenweise geladen, }
{     jede Zeile dabei in der Reihenfolge von links nach rechts           }
LABEL quit_loop;
TYPE split=RECORD loword,hiword:WORD END;
VAR p1:Pointer;
    ad,p:LONGINT;
    f:FileOfByte;
    count,ZielOfs,step,yoffset:WORD;
    pSeg,pOfs:ARRAY[0..3] OF WORD;
    Breite_in_Tiles,Hoehe_in_Tiles,x,y,i,zeilen:BYTE;
    Header:SpriteHeader;
    tempName:STRING;
BEGIN
 count:=0;  {Zahl der bisher eingelesenen Sprites}
 tempName:=FindFile(name);
 IF tempName<>'' THEN name:=tempName;
 _assign(f,name);
 {$I-} _reset(f); {$IFDEF IOcheck} {$I+} {$ENDIF}
 if (ioresult<>0) OR (CompressError<>CompressErr_NoError)
  THEN BEGIN  {Datei existiert nicht oder nicht unter diesem Pfad}
        Error:=Err_FileIO;
        CompressError:=CompressErr_NoError;
        LoadTile:=0; exit
       END;
 WHILE NOT _physicalEOF(f) DO
 BEGIN
  {ZunÑchst den Spriteheader einlesen: }
  {$I-}     {jetzt den Spriteheader viÖ BLOCKREAD auf den Heap laden}
  _blockread(f,Header,Kopf);
  {$IFDEF IOcheck} {$I+} {$ENDIF}

  IF (ioresult<>0) OR (CompressError<>CompressErr_NoError)
   THEN BEGIN
         Error:=Err_FileIO;
         CompressError:=CompressErr_NoError;
         goto quit_loop;
        END;
  IF (Header.Kennung[1]<>'K') or (Header.Kennung[2]<>'R')
   THEN BEGIN
         Error:=Err_NoTile;  {oder Err_NoSprite!}
         goto quit_loop
        END;
  IF (Header.Breite_in_4er_Gruppen MOD 4<>0) OR
     (Header.Hoehe_in_Zeilen MOD 16<>0)   {Grî·e Vielfaches von 16?}
   THEN BEGIN
         Error:=Err_NoTile;
         goto quit_loop
        END
   ELSE BEGIN {ja, Anzahl Tiles in diesem Spritefile ermitteln}
         Breite_in_Tiles:=Header.Breite_in_4er_Gruppen SHR 2;
         Hoehe_in_Tiles :=Header.Hoehe_in_Zeilen SHR 4;
         step:=Breite_in_Tiles*4; {Schrittweite beim laden}
        END;
  IF (Header.SpriteLength>MaxAvail)    {noch genug Platz da?}
   THEN BEGIN
         Error:=Err_NotEnoughMemory;
         goto quit_loop;
        END;

  {Jetzt eigentliche Spritedaten einlesen: }
  getmem(p1,Header.SpriteLength);      {genug Platz reservieren}

  {$I-}     {jetzt den "Rest" des Sprites laden}
  _blockread(f,p1^,Header.SpriteLength-Kopf);
  {$IFDEF IOcheck} {$I+} {$ENDIF}
  IF (ioresult<>0) OR (CompressError<>CompressErr_NoError)
   THEN BEGIN
         Error:=Err_FileIO;
         CompressError:=CompressErr_NoError;
         goto quit_loop;
        END;

  ad:=(LONGINT(split(p1).HiWord) SHL 4) + split(p1).LoWord - Kopf;
  FOR i:=0 TO 3 DO
   BEGIN
    p:=ad+Header.Zeiger_auf_Plane[i]; pSeg[i]:=p SHR 4; pOfs[i]:=p AND $F;
   END;

  FOR y:=0 TO Pred(Hoehe_in_Tiles) DO
   BEGIN
    yoffset:=y*Breite_in_Tiles*16*(16 DIV 4);
    FOR x:=0 TO Pred(Breite_in_Tiles) DO
     BEGIN
      IF count+number>255
       THEN BEGIN
             Error:=Err_InvalidTileNumber;
             goto quit_loop
            END;
      ZielOfs:=(number+count) SHL 6;
      FOR i:=0 TO 3 DO
       BEGIN
        PORTW[$3C4]:=(TranslateTab[i] SHL 8) + 2;
        FOR zeilen:=0 TO 15 DO
         BEGIN
          move(mem[pSeg[i]:pOfs[i] + yoffset + zeilen*step + x*(16 DIV 4)],
               mem[SCROLLADR:ZielOfs + zeilen*(16 DIV 4)],
               16 DIV 4);
         END;
       END;

      INC(count);
     END;
   END;
  FreeMem(p1,Header.SpriteLength);      {Speicher freigeben}
  IF (NOT _physicalEOF(f)) AND
     ( (NOT f.komprimiert) OR (_logicalEOF(f)) )
   THEN Resync(f)
 END;

quit_loop: ;
 _close(f);
 LoadTile:=count
END;

PROCEDURE SetBackgroundScrollRange(x1,y1,x2,y2:INTEGER);
{ in: (x1,y1) = linke obere Ecke des Bereiches (virtuelle Koord.)}
{     (x2,y2) = dto., rechte untere Ecke}
{out: (BackX1,BackY1), (BackX2,BackY2) = auf 16er Raster gerundete Koord.  }
{     XTiles, YTiles = Breite und Hîhe des gewÑhlten Bereiches in Kacheln  }
{rem: Die li. obere Ecke wird nach links oben gezogen, die re. untere nach }
{     rechts unten!}
{     Die Anwendung dieser Routine ist natÅrlich nur fÅr den Hintergrund-  }
{     modus SCROLLING sinnvoll}
BEGIN
 BackX1:=x1 AND $FFF0; BackX2:=x2 OR $F;
 BackY1:=y1 AND $FFF0; BackY2:=y2 OR $F;
 xtiles:=succ(BackX2-BackX1) shr 4;
 ytiles:=succ(BackY2-BackY1) shr 4;
 IF (xtiles OR ytiles)<=0
  THEN Error:=Err_InvalidCoordinates
 ELSE IF xtiles*ytiles>MaxTiles
  THEN Error:=Err_BackgroundToBig;
END;

PROCEDURE SetBackgroundMode(mode:BYTE);
{ in: mode = gewÅnschter Hintergrundmodus STATIC oder SCROLLING}
{out: Backgroundmode = gesetzter Modus STATIC/SCROLLING}
BEGIN
 IF (mode<>STATIC) AND (mode<>SCROLLING)
  THEN Error:=Err_InvalidMode
  ELSE Backgroundmode:=mode
END;

PROCEDURE MakeTileArea(FirstTile:BYTE; TileWidth,TileHeight:INTEGER);
{ in: FirstTile = Anfangsindex der ersten Kachel}
{     TileWidth = Breite (in Kacheln) des zu wiederholenden Rechtecks}
{     TileHeight= dto., Hîhe}
{     BackX1,BackY1,BackX2,BackY2= per SetScrollRange()-Aufruf gesetzter}
{      Hintergrundbereich}
{out: Beginnend mit Kachel FirstTile wurden die TileWidth*TileHeight }
{     nÑchsten Kacheln als sich wiederholendes Rechteck der Breite   }
{     TileWidth und Hîhe TileHeight in den Hintergrund Åbernommen.   }
{     Auf diese Art wurde der gesamte definierte Hintergrund gebildet}
{     Bspw. sorgt ein Aufruf der Form MakeTileArea(7,3,2) fÅr folgendes}
{     Layout: }
{     ⁄ƒƒ¬ƒƒ¬ƒƒ¬ƒƒ¬ƒƒ¬ƒƒ¬ƒƒ¬    }
{     ≥ 7≥ 8≥ 9≥ 7≥ 8≥ 9≥ 7≥... }
{     √ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈    }
{     ≥10≥11≥12≥10≥11≥12≥10≥... }
{     √ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈    }
{     ≥ 7≥ 8≥ 9≥ 7≥ 8≥ 9≥ 7≥... }
{     √ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈    }
{     ≥10≥11≥12≥10≥11≥12≥10≥... }
{     √ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈ƒƒ≈    }
{       .  .  .  .  .  .  .     }
{       .  .  .  .  .  .  .     }
{rem: Der Aufruf dieser Routine ist nur sinnvoll, wenn SCROLLING als}
{     Hintergrundmodus verwendet wird und SetScrollRange() aufgerufen}
{     wurde!}
VAR GY,StartRowTile,
    x,y:INTEGER;
BEGIN
  IF (TileWidth>0) AND (TileHeight>0)
   THEN BEGIN
         FOR y:=0 TO ytiles-1 DO
          BEGIN
           gy:=BackY1+(y SHL 4); {y-Koordinate fÅr diese Zeile}
           {Index der 1.Tile der aktuellen Zeile berechnen:}
           StartRowTile:=(y MOD TileHeight)*TileWidth+FirstTile;
           FOR x:=0 TO xtiles-1 DO
            PutTile(BackX1+(x SHL 4),gy,StartRowTile+(x MOD TileWidth));
          END
        END

   ELSE Error := Err_InvalidCoordinates
END;

PROCEDURE PutTile(x,y:INTEGER; TileNr:BYTE);
{ in: x,y   = virtuelle Koordinate, an die die Kachel plaziert werden soll}
{     TileNr= Nummer der zu plazierenden Kachel}
{out: - }
{rem: Der Punkt (x,y) wird zunÑchst auf 16er Raster gebracht!  }
{     Die Anwendung dieser Routine ist nur fÅr den Hintergrund-}
{     modus SCROLLING sinnvoll}
VAR index:WORD;
BEGIN
 ASM
    MOV AX,x        {berechne relativen X-Abstand vom linken Rand des}
    SUB AX,BackX1   {definierten Bereiches in "x" mittels der Formel:}
    SAR AX,1        { x := ((x AND $FFF0) - BackX1) DIV 16  (nicht:  }
    SAR AX,1        {SHR 4)!  "AND $FFF0" kann dabei entfallen, da in}
    SAR AX,1        {BackX1 die letzte Hex-Ziffer $0 ist!            }
    SAR AX,1
    MOV x,AX

    MOV AX,y        {dto. fÅr Abstand der y-Koordinate vom oberen }
    SUB AX,BackY1   {Rand: y := ((y AND $FFF0) - BackY1) DIV 16   }
    SAR AX,1
    SAR AX,1
    SAR AX,1
    SAR AX,1
    MOV y,AX
 END;

 IF (x<0) OR (x>=XTiles) OR (y<0) OR (y>=YTiles)
  THEN Error:=Err_InvalidCoordinates
  ELSE BEGIN {jede Kachelzeile ist XTiles breit, jede Kachel 16x16 Punkte}
        index:=y*XTiles+x;  {eigentlich: (x MOD XTiles)}
        BackTile[Succ(index)]:=TileNr;  {"Succ", um BackTile[0] freizuhalten}
       END;
END;

FUNCTION GetTile(x,y:INTEGER):BYTE;
{ in: x,y   = virtuelle Koordinate, von der die Kachel gelesen werden soll}
{out: Nummer der Kachel an dieser Stelle}
{rem: Der Punkt (x,y) wird zunÑchst auf 16er Raster gebracht!}
{     Liegt der Punkt au·erhalb des definierten Bereiches, so wird die}
{     Offscreen-Kachel BackTile[0] zurÅckgegeben}
BEGIN
 ASM
    MOV AX,x        {berechne relativen X-Abstand vom linken Rand des}
    SUB AX,BackX1   {definierten Bereiches in "x" mittels der Formel:}
    SAR AX,1        { x := ((x AND $FFF0) - BackX1) DIV 16  (nicht:  }
    SAR AX,1        {SHR 4)!  "AND $FFF0" kann dabei entfallen, da in}
    SAR AX,1        {BackX1 die letzte Hex-Ziffer $0 ist!            }
    SAR AX,1
    MOV x,AX

    MOV AX,y        {dto. fÅr Abstand der y-Koordinate vom oberen }
    SUB AX,BackY1   {Rand: y := ((y AND $FFF0) - BackY1) DIV 16   }
    SAR AX,1
    SAR AX,1
    SAR AX,1
    SAR AX,1
    MOV y,AX
 END;

 IF (x<0) OR (x>=XTiles) OR (y<0) OR (y>=YTiles)
  THEN GetTile:=BackTile[0]
  ELSE GetTile:=BackTile[y*XTiles+x+1]
END;

PROCEDURE SetOffscreenTile(TileNr:BYTE);
{ in: TileNr= Nummer der zu plazierenden Kachel}
{out: - }
{rem: Alle Bildschirmteile, die au·erhalb des durch SetBackground-}
{     ScrollRange definierten Bereiches liegen, erhalten TileNr als}
{     Muster zugewiesen }
{     Die Anwendung dieser Routine ist nur fÅr den Hintergrund-    }
{     modus SCROLLING sinnvoll}
BEGIN
 BackTile[0]:=TileNr
END;

PROCEDURE SetModeByte(Sp:WORD; M:BYTE);
{ in: Sp = SpriteLADEnummer, dessen Modusbyte verÑndert werden soll}
{out: M  = Methode, mit der Sp ab sofort dargestellt werden soll:   }
{          Display_NORMAL, Display_FAST, Display_SHADOW oder        }
{          Display_SHADOWEXACT                                      }
{rem: Existiert das Sprite noch nicht oder ist der Modus nicht er-  }
{     laubt, so geschieht nichts!                                   }
VAR ad:WORD;
BEGIN
 ad:=SPRITEAD[Sp];
 IF ad=0 THEN Error:=Err_InvalidSpriteNumber {Sprite mu· schon geladen sein}
 ELSE IF (M<Display_NORMAL) OR (M>Display_SHADOWEXACT)
  THEN Error:=Err_InvalidMode  {nur diese 4 Modi sind zulÑssig}
 ELSE MEM[ad:Modus]:=M
END;

FUNCTION GetModeByte(Sp:WORD):BYTE;
{ in: Sp = SpriteLADEnummer, dessen Modusbyte abgefragt werden soll}
{out: Methode, die fÅr Sp momentan gesetzt ist: Display_NORMAL,    }
{     Display_FAST, Display_SHADOW, Display_SHADOWEXACT bzw.       }
{     Display_UNKNOWN, wenn das Sprite noch nicht geladen wurde!   }
VAR ad:WORD;
BEGIN
 ad:=SPRITEAD[Sp];
 IF (ad=0)
  THEN GetModeByte:=Display_UNKNOWN     {Sprite noch nicht geladen}
  ELSE GetModeByte:=MEM[SPRITEAD[Sp]:Modus]
END;

PROCEDURE FillBackground(color:BYTE);
{ in: color = FÅllfarbe fÅr die Hintergrundseite BACKGNDPAGE         }
{     BACKGNDADR = Zeiger auf Hintergrundspeicher}
{out: Die Grafikseite BACKGNDPAGE wurde mit der Farbe "Color" gefÅllt}
{rem: Die Routine ist nur fÅr den Hintergrundmodus STATIC sinnvoll   }
BEGIN
 IF EMSused
  THEN EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}
 FillChar(MEM[BACKGNDADR:0],4*PAGESIZE,color);
END;

PROCEDURE FillPage(pa:WORD; color:BYTE);
{ in: pa    = die Seite, die gefÅllt werden soll (0..3)}
{     color = FÅllfarbe fÅr die Seite}
{out: Grafikseite "pa" wurde mit der Farbe "Color" gefÅllt}
{rem: Sinnvoll sind nur die Seiten 0,1 und BACKGNDPAGE,   }
{     jedoch ist SCROLLPAGE ebenfalls erlaubt}
BEGIN
 IF (pa<0) OR (pa>SCROLLPAGE)
  THEN Error:=Err_InvalidPageNumber
 ELSE IF pa=BACKGNDPAGE
  THEN FillBackground(color)
  ELSE BEGIN
        portw[$3C4]:=$0F02; {im Map-Mask Register alle 4 Ebenen selektieren}
        fillchar(MEM[Segment_Adr[pa]:0],PAGESIZE,Color)
       END;
END;

PROCEDURE GetBackgroundFromPage(pa:WORD);
{in : pa = 0 oder 1 }
{out: -             }
{rem: Der Hintergrundspeicher BACKGNDPAGE wird mit dem Inhalt der }
{     angegebenen Grafikseite gefÅllt.}
{     Die Routine ist nur fÅr den Hintergrundmodus STATIC sinnvoll}
VAR p:POINTER;
BEGIN
 IF (pa<>0) AND (pa<>1) AND (pa<>SCROLLPAGE)
  THEN Error:=Err_InvalidPageNumber
  ELSE BEGIN
        IF EMSused
         THEN EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}
       ASM
        MOV ES,BACKGNDADR
        MOV SI,pa
        SHL SI,1
        ADD SI,OFFSET Segment_Adr-StartIndex*2
        LODSW
        MOV DS,AX
        XOR SI,SI
        XOR DI,DI

        MOV DX,3CEh
        MOV AX,0004h  {Leseplane 0}
        MOV BX,PAGESIZE / 2

        {DS:SI = Quellzeiger, ES:DI = Zielzeiger, BX = Anzahl Worte }
        {AX = Zugriffsmaske auf Leseplane 0, DX = Registerport dafÅr}

        CLI
        OUT DX,AX {Plane 0 anwÑhlen}
        MOV CX,BX
        REP MOVSW {Planedaten speichern}
        XOR SI,SI {SI rÅcksetzen}

        INC AH    {Plane 1 anwÑhlen}
        OUT DX,AX
        MOV CX,BX
        REP MOVSW
        XOR SI,SI

        INC AH    {Plane 2 anwÑhlen}
        OUT DX,AX
        MOV CX,BX
        REP MOVSW
        XOR SI,SI

        INC AH    {Plane 3 anwÑhlen}
        OUT DX,AX
        MOV CX,BX
        REP MOVSW

        STI
        MOV AX,SEG @DATA
        MOV DS,AX
       END
       END;
END;

PROCEDURE WritePage(name:STRING; pa:WORD);
{ in: name     = Filename fÅr das abzuspeichernde Bild}
{     pa       = abzuspeichernde Seite (0..3) }
{     PAGESIZE = Grî·e einer Bitplane       }
{     PICHeader= einzutragende Kennung fÅr Bilderdateien}
{out: - }
{rem: Die Grafik auf Seite "pa" wurde in der Datei "name" als Bitmap abgelegt}
{     Diese Datei ist 4*PAGESIZE+3 = 64003 Bytes gro·: 320x200 Punkte zu je  }
{     1 Byte plus Length(PICHeader) als Kennung}
VAR f:FILE;
    i,oldMode:BYTE;
    fehler:BOOLEAN;
BEGIN
 IF (pa<0) OR (pa>SCROLLPAGE)
  THEN BEGIN
        Error:=Err_InvalidPageNumber; exit
       END;
 {$I-}
 Assign(f,name); fehler:=IOResult<>0;
 Rewrite(f,1);   fehler:=fehler OR (IOResult<>0);
 BlockWrite(f,PICHeader[1],Length(PICHeader));
 fehler:=fehler OR (IOResult<>0);
 {$IFDEF IOcheck} {$I+} {$ENDIF}
 IF fehler
  THEN BEGIN
        {$I-} Close(f); {$IFDEF IOcheck} {$I+} {$ENDIF}
        Error:=Err_FileIO; exit
       END;

 IF pa<>BACKGNDPAGE
  THEN BEGIN {VRAM nach Disk}
        port[$3ce]:=5;       {alten Lese-/Schreibmodus merken}
        oldMode:=port[$3cf];
        port[$3cf]:=$40;     {Lesemodus 0 setzen}
        FOR i:=0 TO 3 DO
         BEGIN
          portw[$3CE]:=4+(i shl 8); {Lese-Plane anwÑhlen}
          {$I-}
          BlockWrite(f,mem[Segment_Adr[pa]:0],PAGESIZE);
          {$IFDEF IOcheck} {$I+} {$ENDIF}
          fehler:=fehler OR (IOResult<>0);
         END;
         port[$3ce]:=5;       {alten Lese-/Schreibmodus setzen}
         port[$3cf]:=oldMode;
       END
  ELSE BEGIN {RAM nach Disk}
        IF EMSused
         THEN EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}
        FOR i:=0 TO 3 DO
         BEGIN
          {$I-}
          BlockWrite(f,MEM[BACKGNDADR:BACKtab[i]],PAGESIZE);
          {$IFDEF IOcheck} {$I+} {$ENDIF}
          fehler:=fehler OR (IOResult<>0);
         END
       END;
 {$I-}
 Close(f);
 {$IFDEF IOcheck} {$I+} {$ENDIF}
 fehler:=fehler OR (IOResult<>0);
 IF fehler THEN Error:=Err_FileIO
END;

PROCEDURE LoadPage(name:STRING; pa:WORD);
{ in: name     = Filename fÅr das zu ladende Bild}
{     pa       = Zielseite, in die das Bild geladen werden soll (0..3) }
{     PAGESIZE = Grî·e einer Bitplane    }
{     PICHeader= Kennung fÅr Bilderdateien }
{out: - }
{rem: Die Bitmap-Grafik in der Datei "name" wurde in die Seite "pa" geladen}
VAR f:FileOfByte;
    i,oldMode:BYTE;
    fehler:BOOLEAN;
    s:STRING[3];
    splane:WORD;
    p1,p2:POINTER;
    tempName:STRING;
TYPE tempArray=ARRAY[1..PAGESIZE] OF BYTE;
VAR  temp:^tempArray;
BEGIN
 IF (pa<0) OR (pa>SCROLLPAGE)
  THEN BEGIN
        Error:=Err_InvalidPageNumber; exit
       END;
 tempName:=FindFile(name);
 IF tempName<>'' THEN name:=tempName;
 {$I-}
 _Assign(f,name); fehler:=IOResult<>0;
 _Reset(f);       fehler:=fehler OR (IOResult<>0);
 s[0]:=PICHeader[0];
 _BlockRead(f,s[1],Length(PICHeader));
 fehler:=fehler OR (IOResult<>0) OR (CompressError<>CompressErr_NoError);
 {$IFDEF IOcheck} {$I+} {$ENDIF}
 IF fehler
  THEN BEGIN
        {$I-} _Close(f); {$IFDEF IOcheck} {$I+} {$ENDIF}
        Error:=Err_FileIO;
        CompressError:=CompressErr_NoError;
        exit
       END
  ELSE IF (_FileSize(f)<>4*PAGESIZE+Length(PICHeader)) OR (s<>PICHeader)
  THEN BEGIN
        {$I-} _Close(f); {$IFDEF IOcheck} {$I+} {$ENDIF}
        Error:=Err_NoPicture;
        exit
       END;

 IF pa<>BACKGNDPAGE
  THEN BEGIN {Disk nach VRAM}
        ASM cli END;
        port[$3ce]:=5;       {alten Lese-/Schreibmodus merken}
        oldMode:=port[$3cf];
        New(temp);
        ASM sti END;
        FOR i:=0 TO 3 DO
         BEGIN
          {$I-}
          _BlockRead(f,temp^[1],PAGESIZE);
          {$IFDEF IOcheck} {$I+} {$ENDIF}
          fehler:=fehler OR (IOResult<>0);
          splane:=2+(TranslateTab[i] shl 8); {welche Schreib-Plane}
          p1:=@temp^[1];
          p2:=ptr(Segment_Adr[pa],0);
          ASM
           cli
           mov dx,$3CE      {Schreibmodus 0 wÑhlen}
           mov ax,$4005
           out dx,ax

           mov ax,splane    {Schreibplane anwÑhlen}
           mov dx,$3C4
           out dx,ax

           les di,p2
           lds si,p1
           mov cx,PAGESIZE SHR 1
           rep movsw

           mov ax,SEG @DATA
           mov ds,ax
           sti
          END;

         END;
        portw[$3ce]:=oldMode SHL 8 + 5; {alten Lese-/Schreibmodus setzen}
        Dispose(temp);
       END
  ELSE BEGIN {Disk nach RAM}
        IF EMSused
         THEN EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}
        FOR i:=0 TO 3 DO
         BEGIN
          {$I-}
          _BlockRead(f,MEM[BACKGNDADR:BACKtab[i]],PAGESIZE);
          {$IFDEF IOcheck} {$I+} {$ENDIF}
          fehler:=fehler OR (IOResult<>0);
         END
       END;
 {$I-}
 _Close(f);
 {$IFDEF IOcheck} {$I+} {$ENDIF}
 fehler:=fehler OR (IOResult<>0) OR (CompressError<>CompressErr_NoError);
 IF fehler THEN Error:=Err_FileIO
END;

PROCEDURE WriteBackgroundPage(name:STRING);
{ in: name       = Filename fÅr das abzuspeichernde Hintergrundbild}
{     BACKGNDPAGE= abzuspeichernde Seite (=2) }
{     PAGESIZE   = Grî·e einer Bitplane     }
{     PICHeader  = einzutragende Kennung fÅr Bilderdateien}
{out: - }
{rem: Die Grafik der Hintergrundseite wurde in der Datei "name" abgelegt}
{     Diese Datei ist 4*PAGESIZE+3 = 64003 Bytes gro·: 320x200 Punkte   }
{     zu je 1 Byte plus Length(PICHeader) als Kennung}
{     Die Routine ist nur fÅr den Hintergrundmodus STATIC sinnvoll      }
BEGIN
 WritePage(name,BACKGNDPAGE)
END;

PROCEDURE LoadBackgroundPage(name:STRING);
{ in: name       = Filename fÅr das zu ladende Hintergrundbild}
{     BACKGNDPAGE= Zielseite, in die das Bild geladen werden soll (=2) }
{     PAGESIZE = Grî·e einer Bitplane    }
{     PICHeader= Kennung fÅr Bilderdateien }
{out: - }
{rem: Die Bitmap-Grafik in der Datei "name" wurde in die Hintergrundseite}
{     BACKGNDPAGE geladen}
{     Die Routine ist nur fÅr den Hintergrundmodus STATIC sinnvoll}
BEGIN
 LoadPage(name,BACKGNDPAGE)
END;

PROCEDURE FadeIn(pa,ti,style:WORD);
{ in: pa = Seite, die auf die aktuelle Seite eingeblendet werden soll}
{     ti = Zeit in Millisekunden, in der dies geschehen soll}
{     style = Algorithmus der dafÅr benutzt werden soll}
{     1-PAGE = aktuell sichtbare Seite}
{out: Error = Err_InvalidFade, falls nicht zulÑssiger Alg. gewÑhlt wurde}
{rem: Grafikmodus mu· natÅrlich bereits initialisiert worden sein}
{     Sinnvoll ist eigentlich nur pa=BACKGNDPAGE}

  PROCEDURE WipeIn(pa,time:WORD);
  { in: pa    = Seite, deren Inhalt sichtbar gemacht werden soll}
  {     time  = ungefÑhre Zeit (in Millisekunden), in der das geschehen soll}
  {     1-PAGE= (sichtbare) Grafikseite, auf die gezeichnet wird}
  {out: - }
  {rem: Der Inhalt der Seite "pa" wurde auf die Seite 1-PAGE kopiert}
  CONST hoehe =40; {Teiler von Succ(YMAX)}
        breite=40; {Teiler von Succ(XMAX)}
        br_x  =Succ(XMAX) DIV breite; {Blîcke in X-Richtung}
        br_y  =Succ(YMAX) DIV hoehe;  {Blîcke in Y-Richtung}
        n=hoehe*br_x; {Anzahl Aufrufe der Verzîgerungsschleife}
  VAR i,x,y,ploty,plotx:WORD;
      counter:WORD;
      ClockTicks:LONGINT ABSOLUTE $40:$6C;
      t:LONGINT;
      temp:REAL;
      p:POINTER;
  BEGIN
   t:=ClockTicks;
   counter:=0;
   temp:=0.0182*time/n;
   FOR i:=0 TO pred(hoehe) DO
    FOR x:=0 TO pred(br_x) DO
     BEGIN
      FOR y:=0 TO pred(br_y) DO
       BEGIN
        IF ODD(x)
         THEN ploty:=y*hoehe+i          +StartVirtualY
         ELSE ploty:=y*hoehe+(hoehe-1-i)+StartVirtualY;
        plotx:=x*breite +StartVirtualX;
        p:=GetImage(plotx,ploty,plotx+pred(breite),ploty,pa);
        PutImage(plotx,ploty,p,1-PAGE);
        FreeImageMem(p);
       END; {of FOR y}
      INC(counter);
      WHILE ClockTicks<t+counter*temp DO BEGIN END;
     END; {of FOR x}
  END;

  PROCEDURE Chaos(pa,time:WORD;m:BYTE);
  { in: pa    = Seite, deren Inhalt sichtbar gemacht werden soll}
  {     time  = ungefÑhre Zeit (in Millisekunden), in der das geschehen soll}
  {     m     = Art, wie das geschehen soll (1..14)}
  {     1-PAGE= (sichtbare) Grafikseite, auf die gezeichnet wird}
  {out: - }
  {rem: Der Inhalt der Seite "pa" wurde auf die Seite 1-PAGE kopiert}
  CONST n=Succ(XMAX)*Succ(YMAX);  {Anzahl Bildschirmpunkte}
        {gute Parameter sind z.B. Summen von Zweierpotenzen +1}
        para:ARRAY[1..14] OF WORD=
         (13477,65,337,129,257,513,769,1025,481,4097,5121,177,16385,16897);
  VAR i,k,x,y:WORD;
      counter:WORD;
      ClockTicks:LONGINT ABSOLUTE $40:$6C;
      t:LONGINT;
      temp:REAL;
      rand:WORD;
  BEGIN
   t:=ClockTicks;
   counter:=0;
   rand:=0;
   IF (m<1) OR (m>14) THEN m:=1;
   k:=para[m];
   temp:=0.0182*time/n;
   FOR i:=0 TO 65535 DO
    BEGIN
     ASM {berechne: "x := rand MOD 320" und "y := rand DIV 320"}
      XOR DX,DX
      MOV AX,rand
      MOV BX,XMAX+1
      DIV BX
      MOV y,AX
      MOV x,DX
     END;
     IF y<=YMAX
      THEN PutPixel(StartVirtualX+x,StartVirtualY+y,
                    PageGetPixel(StartVirtualX+x,StartVirtualY+y,pa));
     ASM {berechne: rand:=rand*k+1}
      MOV AX,rand
      MUL k
      INC AX
      MOV rand,AX
     END;
     INC(counter);
     WHILE ClockTicks<t+counter*temp DO BEGIN END;
    END; {of FOR i}
  END;

  PROCEDURE Chaos2(pa,time:WORD;m:BYTE);
  { in: pa    = Seite, deren Inhalt sichtbar gemacht werden soll}
  {     time  = ungefÑhre Zeit (in Millisekunden), in der das geschehen soll}
  {     m     = Art, wie das geschehen soll (1..1)}
  {     1-PAGE= (sichtbare) Grafikseite, auf die gezeichnet wird}
  {out: - }
  {rem: Der Inhalt der Seite "pa" wurde auf die Seite 1-PAGE kopiert}
  CONST n=Succ(XMAX)*Succ(YMAX);  {Anzahl Bildschirmpunkte}
        para:ARRAY[1..1] OF WORD=
         (39551);
  VAR i,k,x,y:WORD;
      counter:WORD;
      ClockTicks:LONGINT ABSOLUTE $40:$6C;
      t:LONGINT;
      temp:REAL;
      rand:WORD;
  BEGIN
   t:=ClockTicks;
   counter:=0;
   rand:=0;
   IF (m<1) OR (m>1) THEN m:=1;
   k:=para[m];
   temp:=0.0182*time/n;
   FOR i:=0 TO 65535 DO
    BEGIN
     ASM {berechne: "x:=rand MOD 320" und "y:=rand DIV 320"}
      XOR DX,DX
      MOV AX,rand
      MOV BX,XMAX+1
      DIV BX
      MOV y,AX
      MOV x,DX
     END;
     PutPixel(StartVirtualX+x,StartVirtualY+y,
              PageGetPixel(StartVirtualX+x,StartVirtualY+y,pa));
     ASM {berechne: rand:=(rand+k) MOD n}
      XOR DX,DX
      MOV AX,rand
      ADD AX,k
      JNC @normal
      ADD AX,(65536-n)  {Overflow, also korrigieren}
     @normal:
      CMP AX,n
      JB @ok
      SUB AX,n
     @ok:
      MOV rand,AX
     END;
     INC(counter);
     WHILE ClockTicks<t+counter*temp DO BEGIN END;
    END; {of FOR i}
  END;

  PROCEDURE SweepVertical(pa,time:WORD; down:BOOLEAN);
  { in: pa    = Seite, deren Inhalt sichtbar gemacht werden soll}
  {     time  = ungefÑhre Zeit (in Millisekunden), in der das geschehen soll}
  {     down  = TRUE/FALSE fÅr: von oben nach unten/umgekehrt   }
  {     1-PAGE= (sichtbare) Grafikseite, auf die gezeichnet wird}
  {out: - }
  {rem: Der Inhalt der Seite "pa" wurde auf die Seite 1-PAGE kopiert}
  CONST n=Succ(YMAX);      {Anzahl Aufrufe der Verzîgerungsschleife }
  VAR y,counter:WORD;
      ClockTicks:LONGINT ABSOLUTE $40:$6C;
      t:LONGINT;
      temp:REAL;
      oldColor,step:BYTE;
      p:POINTER;
  BEGIN
   oldColor:=Color;
   Color:=white;
   t:=ClockTicks;
   counter:=0;
   temp:=0.0182*time/n;
   IF down
    THEN FOR y:=0+StartVirtualY TO YMAX+StartVirtualY DO
          BEGIN
           Line(StartVirtualX,y,StartVirtualX+XMAX,y,1-PAGE);
           INC(counter);
           WHILE ClockTicks<t+counter*temp DO BEGIN END;
           p:=GetImage(StartVirtualX,y,StartVirtualX+XMAX,y,pa);
           PutImage(StartVirtualX,y,p,1-PAGE);
           FreeImageMem(p);
          END
    ELSE FOR y:=YMAX+StartVirtualY DOWNTO 0+StartVirtualY DO
          BEGIN
           Line(StartVirtualX,y,StartVirtualX+XMAX,y,1-PAGE);
           INC(counter);
           WHILE ClockTicks<t+counter*temp DO BEGIN END;
           p:=GetImage(StartVirtualX,y,StartVirtualX+XMAX,y,pa);
           PutImage(StartVirtualX,y,p,1-PAGE);
           FreeImageMem(p);
          END;
   Color:=oldColor
  END;

  PROCEDURE SweepHorizontal(pa,time:WORD; left_to_right:BOOLEAN);
  { in: pa    = Seite, deren Inhalt sichtbar gemacht werden soll}
  {     time  = ungefÑhre Zeit (in Millisekunden), in der das geschehen soll}
  {     left_to_right=TRUE/FALSE fÅr: von links nach rechts/umgekehrt}
  {     1-PAGE= (sichtbare) Grafikseite, auf die gezeichnet wird}
  {out: - }
  {rem: Der Inhalt der Seite "pa" wurde auf die Seite 1-PAGE kopiert}
  CONST n=Succ(XMAX);      {Anzahl Aufrufe der Verzîgerungsschleife }
  VAR x,counter:WORD;
      ClockTicks:LONGINT ABSOLUTE $40:$6C;
      t:LONGINT;
      temp:REAL;
      oldColor,step:BYTE;
      p:POINTER;
  BEGIN
   oldColor:=Color;
   Color:=white;
   t:=ClockTicks;
   counter:=0;
   temp:=0.0182*time/n;
   IF left_to_right
    THEN FOR x:=0+StartVirtualX TO XMAX+StartVirtualX DO
          BEGIN
           Line(x,StartVirtualY,x,StartVirtualY+YMAX,1-PAGE);
           INC(counter);
           WHILE ClockTicks<t+counter*temp DO BEGIN END;
           p:=GetImage(x,StartVirtualY,x,StartVirtualY+YMAX,pa);
           PutImage(x,StartVirtualY,p,1-PAGE);
           FreeImageMem(p);
          END
    ELSE FOR x:=XMAX+StartVirtualX DOWNTO 0+StartVirtualX DO
          BEGIN
           Line(x,StartVirtualY,x,StartVirtualY+YMAX,1-PAGE);
           INC(counter);
           WHILE ClockTicks<t+counter*temp DO BEGIN END;
           p:=GetImage(x,StartVirtualY,x,StartVirtualY+YMAX,pa);
           PutImage(x,StartVirtualY,p,1-PAGE);
           FreeImageMem(p);
          END;
   Color:=oldColor
  END;

  PROCEDURE ScrollVertical(pa,time:WORD; up:BOOLEAN);
  { in: pa    = Seite, deren Inhalt sichtbar gemacht werden soll}
  {     time  = ungefÑhre Zeit (in Millisekunden), in der das geschehen soll}
  {     up    = TRUE/FALSE fÅr: von unten nach oben/umgekehrt   }
  {     1-PAGE= (sichtbare) Grafikseite, auf die gezeichnet wird}
  {out: - }
  {rem: Der Inhalt der Seite "pa" wurde auf die Seite 1-PAGE kopiert}
  LABEL oneLine1,oneLine2,oneLine3,oneLine4;
  CONST n=Succ(YMAX);      {Anzahl Aufrufe der Verzîgerungsschleife }
  VAR counter:WORD;
      ClockTicks:LONGINT ABSOLUTE $40:$6C;
      t:LONGINT;
      temp:REAL;
  BEGIN
   t:=ClockTicks;
   counter:=0;
   temp:=0.0182*time/n;
   IF pa<>BACKGNDPAGE
    THEN BEGIN
          IF up
           THEN BEGIN {nach oben scrollen}
                 ASM
                   MOV DX,3C4h
                   MOV AX,0F02h  {alle 4 Planes gleichzeitig ansprechen}
                   OUT DX,AX
                   MOV DX,3CEh
                   MOV AX,4105h  {Writemode 1 setzen}
                   OUT DX,AX

                   MOV SI,1
                   SUB SI,PAGE
                   AND SI,1
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW
                   MOV ES,AX     {ES := Segment_Adr[1 - PAGE] = ^sichtbare Seite}

                   MOV SI,pa
                   AND SI,3
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW         {AX := Segment_Adr[pa] = ^Quelladresse}

                   PUSH DS
                   MOV DX,AX
                   MOV BX,YMAX*LINESIZE+(LINESIZE-1)  {DX:BX = ^Quelldaten}

                   MOV AX,YMAX   {AX = ZeilenzÑhler}

                 oneLine2:
                   STD           {rÅckwÑrts moven!}
                   MOV SI,ES     {zuerst alten Inhalt nach oben rollen:}
                   MOV DS,SI     {DS = ES = sichtbare Grafikseite}
                   MOV SI,(YMAX-1)*LINESIZE+(LINESIZE-1)  {von vorletzter Grafikzeile}
                   MOV DI,YMAX*LINESIZE+(LINESIZE-1)      {nach letzter Grafikzeile}
                   MOV CX,YMAX*LINESIZE  {199 Zeilen}
                   REP MOVSB

                   MOV DS,DX     {jetzt neue Zeile sichtbar machen:}
                   MOV SI,BX     {DS:SI = ^zu movende Zeile}
                   MOV CX,LINESIZE  {1 Zeile}
                   REP MOVSB

                   SUB BX,LINESIZE  {Quellzeiger weitersetzen}

                   {--- Einschub fÅr Zeitbedingung:}
                   PUSH AX       {alle noch relevanten Register retten}
                   PUSH BX
                   PUSH DX
                   PUSH ES
                   MOV AX,SEG @DATA {TP's Datensegment wiederherstellen}
                   MOV DS,AX
                   CLD           {sicher ist sicher!}
                 END;
                 INC(counter);
                 WHILE ClockTicks<t+counter*temp DO BEGIN END;
                 ASM;
                   POP ES
                   POP DX
                   POP BX
                   POP AX
                   {--- Einschub Ende}

                   DEC AX        {alle Zeilen durch?}
                   JNS oneLine2  {nein, nÑchste Zeile}

                   MOV DX,3CEh   {Writemode 0 wiederherstellen}
                   MOV AX,4005h
                   OUT DX,AX
                   POP DS
                 END;
                END
           ELSE BEGIN {nach unten scrollen}
                 ASM
                   MOV DX,3C4h
                   MOV AX,0F02h  {alle 4 Planes gleichzeitig ansprechen}
                   OUT DX,AX
                   MOV DX,3CEh
                   MOV AX,4105h  {Writemode 1 setzen}
                   OUT DX,AX

                   MOV SI,1
                   SUB SI,PAGE
                   AND SI,1
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW
                   MOV ES,AX     {ES := Segment_Adr[1-PAGE] = ^sichtbare Seite}

                   MOV SI,pa
                   AND SI,3
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW         {AX := Segment_Adr[pa] = ^Quelladresse}

                   PUSH DS
                   MOV DX,AX
                   MOV BX,0*LINESIZE  {DX:BX = ^Quelldaten}

                   MOV AX,YMAX   {AX = ZeilenzÑhler}

                 oneLine1:
                   MOV SI,ES     {zuerst alten Inhalt nach oben rollen:}
                   MOV DS,SI     {DS = ES = sichtbare Grafikseite}
                   MOV SI,1*LINESIZE  {von Grafikzeile 1}
                   MOV DI,0*LINESIZE  {nach Grafikzeile 0}
                   MOV CX,YMAX*LINESIZE  {199 Zeilen}
                   REP MOVSB

                   MOV DS,DX     {jetzt neue Zeile sichtbar machen:}
                   MOV SI,BX     {DS:SI = ^zu movende Zeile}
                   MOV CX,LINESIZE  {1 Zeile}
                   REP MOVSB

                   ADD BX,LINESIZE  {Quellzeiger weitersetzen}

                   {--- Einschub fÅr Zeitbedingung:}
                   PUSH AX       {alle noch relevanten Register retten}
                   PUSH BX
                   PUSH DX
                   PUSH ES
                   MOV AX,SEG @DATA {TP's Datensegment wiederherstellen}
                   MOV DS,AX
                 END;
                 INC(counter);
                 WHILE ClockTicks<t+counter*temp DO BEGIN END;
                 ASM;
                   POP ES
                   POP DX
                   POP BX
                   POP AX
                   {--- Einschub Ende}

                   DEC AX        {alle Zeilen durch?}
                   JNS oneLine1  {nein, nÑchste Zeile}

                   MOV DX,3CEh   {Writemode 0 wiederherstellen}
                   MOV AX,4005h
                   OUT DX,AX
                   POP DS
                 END;
                END;
         END

    ELSE BEGIN {pa = BACKGNDPAGE, also von RAM nach VRAM}
          IF EMSused
           THEN EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}
          IF up
           THEN BEGIN {nach oben scrollen}
                 ASM
                   MOV DX,3C4h
                   MOV AX,0F02h  {alle 4 Planes gleichzeitig ansprechen}
                   OUT DX,AX

                   MOV SI,1
                   SUB SI,PAGE
                   AND SI,1
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW
                   MOV ES,AX     {ES := Segment_Adr[1 - PAGE] = ^sichtbare Seite}

                   PUSH DS

                   MOV SI,pa
                   AND SI,3
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW         {AX := Segment_Adr[pa] = ^Quelladresse }
                                 {(fÅr pa=BACKGNDPAGE id. zu BACKGNADR)}
                   PUSH BP

                   MOV BP,AX
                   MOV BX,YMAX*LINESIZE+(LINESIZE-1)-1  {BP:BX = ^Quelldaten}

                   MOV AX,YMAX   {AX = ZeilenzÑhler}

                 oneLine4:
                   MOV SI,AX
                   MOV DX,3CEh
                   MOV AX,4105h  {Writemode 1 setzen}
                   OUT DX,AX
                   MOV AX,SI

                   STD           {rÅckwÑrts moven!}
                   MOV SI,ES     {zuerst alten Inhalt nach oben rollen:}
                   MOV DS,SI     {DS = ES = sichtbare Grafikseite}
                   MOV SI,(YMAX-1)*LINESIZE+(LINESIZE-1)  {von vorletzter Grafikzeile}
                   MOV DI,YMAX*LINESIZE+(LINESIZE-1)      {nach letzter Grafikzeile}
                   MOV CX,YMAX*LINESIZE  {199 Zeilen}
                   REP MOVSB

                   PUSH AX
                   MOV DX,3CEh   {Writemode 0 setzen}
                   MOV AX,4005h
                   OUT DX,AX

                   MOV DX,3C4h
                   MOV AX,0102h  {Writeplane 0 selektieren}
                   OUT DX,AX
                   MOV DS,BP     {jetzt neue Zeile sichtbar machen:}
                   MOV SI,BX     {DS:SI = ^zu movende Zeile}
                   DEC DI        {DI um 1 verringern wg. Wort-Zugriffen}
                   MOV CX,LINESIZE / 2  {1 Zeile}
                   REP MOVSW

                   SHL AH,1      {Writeplane 1 selektieren}
                   OUT DX,AX
                   ADD SI,PAGESIZE+LINESIZE
                   MOV CX,LINESIZE / 2 {1 Zeile}
                   ADD DI,LINESIZE
                   REP MOVSW

                   SHL AH,1      {Writeplane 2 selektieren}
                   OUT DX,AX
                   ADD SI,PAGESIZE+LINESIZE
                   MOV CX,LINESIZE / 2 {1 Zeile}
                   ADD DI,LINESIZE
                   REP MOVSW

                   SHL AH,1      {Writeplane 3 selektieren}
                   OUT DX,AX
                   ADD SI,PAGESIZE+LINESIZE
                   MOV CX,LINESIZE / 2 {1 Zeile}
                   ADD DI,LINESIZE
                   REP MOVSW

                   MOV AH,$F     {alle 4 Planes selektieren}
                   OUT DX,AX

                   SUB BX,LINESIZE  {Quellzeiger weitersetzen}
                   POP AX

                   {--- Einschub fÅr Zeitbedingung:}
                   MOV SI,BP     {temporÑres BP}
                   POP BP        {altes BP von TP}
                   PUSH AX       {alle noch relevanten Register retten}
                   PUSH BX
                   PUSH SI
                   PUSH ES
                   MOV AX,SEG @DATA {TP's Datensegment wiederherstellen}
                   MOV DS,AX
                 END;
                 INC(counter);
                 WHILE ClockTicks<t+counter*temp DO BEGIN END;
                 ASM;
                   POP ES
                   POP SI
                   POP BX
                   POP AX
                   PUSH BP
                   MOV BP,SI
                   {--- Einschub Ende}

                   DEC AX        {alle Zeilen durch?}
                   JNS oneLine4  {nein, nÑchste Zeile}

                   POP BP
                   POP DS
                 END;
                END
           ELSE BEGIN {nach unten scrollen}
                 ASM
                   MOV DX,3C4h
                   MOV AX,0F02h  {alle 4 Planes gleichzeitig ansprechen}
                   OUT DX,AX

                   MOV SI,1
                   SUB SI,PAGE
                   AND SI,1
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW
                   MOV ES,AX     {ES := Segment_Adr[1-PAGE] = ^sichtbare Seite}

                   PUSH DS

                   MOV SI,pa
                   AND SI,3
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW         {AX := Segment_Adr[pa] = ^Quelladresse }
                                 {(fÅr pa=BACKGNDPAGE id. zu BACKGNADR)}
                   PUSH BP

                   MOV BP,AX

                   MOV DX,AX
                   MOV BX,0*LINESIZE  {DX:BX = ^Quelldaten}

                   MOV AX,YMAX   {AX = ZeilenzÑhler}

                 oneLine3:
                   MOV SI,AX
                   MOV DX,3CEh
                   MOV AX,4105h  {Writemode 1 setzen}
                   OUT DX,AX
                   MOV AX,SI

                   MOV SI,ES     {zuerst alten Inhalt nach oben rollen:}
                   MOV DS,SI     {DS = ES = sichtbare Grafikseite}
                   MOV SI,1*LINESIZE  {von Grafikzeile 1}
                   MOV DI,0*LINESIZE  {nach Grafikzeile 0}
                   MOV CX,YMAX*LINESIZE  {199 Zeilen}
                   REP MOVSB

                   PUSH AX
                   MOV DX,3CEh   {Writemode 0 setzen}
                   MOV AX,4005h
                   OUT DX,AX

                   MOV DX,3C4h
                   MOV AX,0102h  {Writeplane 0 selektieren}
                   OUT DX,AX
                   MOV DS,BP     {jetzt neue Zeile sichtbar machen:}
                   MOV SI,BX     {DS:SI = ^zu movende Zeile}
                   MOV CX,LINESIZE / 2 {1 Zeile}
                   REP MOVSW

                   SHL AH,1      {Writeplane 1 selektieren}
                   OUT DX,AX
                   ADD SI,PAGESIZE-LINESIZE
                   MOV CX,LINESIZE / 2 {1 Zeile}
                   SUB DI,LINESIZE
                   REP MOVSW

                   SHL AH,1      {Writeplane 2 selektieren}
                   OUT DX,AX
                   ADD SI,PAGESIZE-LINESIZE
                   MOV CX,LINESIZE / 2  {1 Zeile}
                   SUB DI,LINESIZE
                   REP MOVSW

                   SHL AH,1      {Writeplane 3 selektieren}
                   OUT DX,AX
                   ADD SI,PAGESIZE-LINESIZE
                   MOV CX,LINESIZE / 2  {1 Zeile}
                   SUB DI,LINESIZE
                   REP MOVSW

                   MOV AH,$F     {alle 4 Planes selektieren}
                   OUT DX,AX

                   ADD BX,LINESIZE  {Quellzeiger weitersetzen}
                   POP AX

                   {--- Einschub fÅr Zeitbedingung:}
                   MOV SI,BP     {temporÑres BP}
                   POP BP        {altes BP von TP}
                   PUSH AX       {alle noch relevanten Register retten}
                   PUSH BX
                   PUSH SI
                   PUSH ES
                   MOV AX,SEG @DATA {TP's Datensegment wiederherstellen}
                   MOV DS,AX
                 END;
                 INC(counter);
                 WHILE ClockTicks<t+counter*temp DO BEGIN END;
                 ASM;
                   POP ES
                   POP SI
                   POP BX
                   POP AX
                   PUSH BP
                   MOV BP,SI
                   {--- Einschub Ende}

                   DEC AX        {alle Zeilen durch?}
                   JNS oneLine3  {nein, nÑchste Zeile}

                   MOV DX,3CEh   {Writemode 0 wiederherstellen}
                   MOV AX,4005h
                   OUT DX,AX

                   POP BP
                   POP DS
                 END;
                END;
         END;
  END;

  PROCEDURE ScrollHorizontal(pa,time:WORD; left:BOOLEAN);
  { in: pa    = Seite, deren Inhalt sichtbar gemacht werden soll}
  {     time  = ungefÑhre Zeit (in Millisekunden), in der das geschehen soll}
  {     left  = TRUE/FALSE fÅr: von links nach rechts/umgekehrt }
  {     1-PAGE= (sichtbare) Grafikseite, auf die gezeichnet wird}
  {out: - }
  {rem: Der Inhalt der Seite "pa" wurde auf die Seite 1-PAGE kopiert}
  LABEL oneColumn1,oneColumn2,oneColumn3,oneColumn4;
  CONST n=Pred(LINESIZE);      {Anzahl Aufrufe der Verzîgerungsschleife}
  VAR counter:WORD;
      ClockTicks:LONGINT ABSOLUTE $40:$6C;
      t:LONGINT;
      temp:REAL;
  BEGIN
   t:=ClockTicks;
   counter:=0;
   temp:=0.0182*time/n;
   IF pa<>BACKGNDPAGE
    THEN BEGIN
          IF left
           THEN BEGIN {nach links scrollen}
                 ASM
                   MOV DX,3C4h
                   MOV AX,0F02h  {alle 4 Planes gleichzeitig ansprechen}
                   OUT DX,AX
                   MOV DX,3CEh
                   MOV AX,4105h  {Writemode 1 setzen}
                   OUT DX,AX

                   MOV SI,1
                   SUB SI,PAGE
                   AND SI,1
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW
                   MOV ES,AX     {ES := Segment_Adr[1 - PAGE] = ^sichtbare Seite}

                   MOV SI,pa
                   AND SI,3
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW         {AX := Segment_Adr[pa] = ^Quelladresse}

                   PUSH DS
                   MOV DX,AX
                   MOV BX,0*LINESIZE+0 {DX:BX = ^Quelldaten}

                   MOV AX,LINESIZE-1   {AX = SpaltenzÑhler}

                 oneColumn2:     {alten Schirminhalt nach rechts schieben:}
                   MOV SI,ES
                   MOV DS,SI     {DS = ES = sichtbare Grafikseite}
                   MOV SI,PAGESIZE-2
                   MOV DI,PAGESIZE-1
                   MOV CX,PAGESIZE-1
                   STD
                   REP MOVSB
                   CLD

                   MOV CX,SEG @DATA
                   MOV DS,CX     {DS = ^TP Daten}
                   MOV CX,YMAX+1 {CX = ZeilenzÑhler}

                   MOV SI,AX
                   XOR DI,DI
                   MOV BX,LINESIZE-1
                   MOV DS,DX     {DS = ^Quelldaten}

                 @oneRow:        {erste Spalte erneuern:}
                   MOVSB
                   ADD SI,BX     {auf nÑchste Zeile positionieren:}
                   ADD DI,BX     {geht, weil BX + 1 = LINESIZE}
                   LOOP @oneRow

                   {--- Einschub fÅr Zeitbedingung:}
                   PUSH AX       {alle noch relevanten Register retten}
                   PUSH DX
                   PUSH ES
                   MOV AX,SEG @DATA {TP's Datensegment wiederherstellen}
                   MOV DS,AX
                 END;
                 INC(counter);
                 WHILE ClockTicks<t+counter*temp DO BEGIN END;
                 ASM;
                   POP ES
                   POP DX
                   POP AX
                   {--- Einschub Ende}

                   DEC AX        {alle Spalten durch?}
                   JNS oneColumn2  {nein, nÑchste Spalte}

                   MOV DX,3CEh   {Writemode 0 wiederherstellen}
                   MOV AX,4005h
                   OUT DX,AX
                   POP DS
                 END;
                END
           ELSE BEGIN {nach rechts scrollen}
                 ASM
                   MOV DX,3C4h
                   MOV AX,0F02h  {alle 4 Planes gleichzeitig ansprechen}
                   OUT DX,AX
                   MOV DX,3CEh
                   MOV AX,4105h  {Writemode 1 setzen}
                   OUT DX,AX

                   MOV SI,1
                   SUB SI,PAGE
                   AND SI,1
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW
                   MOV ES,AX     {ES := Segment_Adr[1 - PAGE] = ^sichtbare Seite}

                   MOV SI,pa
                   AND SI,3
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW         {AX := Segment_Adr[pa] = ^Quelladresse}

                   PUSH DS
                   MOV DX,AX
                   MOV BX,0*LINESIZE+0 {DX:BX = ^Quelldaten}

                   MOV AX,0      {AX = SpaltenzÑhler}

                 oneColumn1:     {alten Schirminhalt nach links schieben:}
                   MOV SI,ES
                   MOV DS,SI     {DS = ES = sichtbare Grafikseite}
                   MOV SI,1
                   XOR DI,DI
                   MOV CX,PAGESIZE-1
                   REP MOVSB

                   MOV CX,SEG @DATA
                   MOV DS,CX     {DS = ^TP Daten}
                   MOV CX,YMAX+1 {CX = ZeilenzÑhler}

                   MOV SI,AX
                   MOV DI,LINESIZE-1
                   MOV BX,LINESIZE-1
                   MOV DS,DX     {DS = ^Quelldaten}

                 @oneRow:        {letzte Spalte erneuern:}
                   MOVSB
                   ADD SI,BX     {auf nÑchste Zeile positionieren:}
                   ADD DI,BX     {geht, weil BX + 1 = LINESIZE}
                   LOOP @oneRow

                   {--- Einschub fÅr Zeitbedingung:}
                   PUSH AX       {alle noch relevanten Register retten}
                   PUSH DX
                   PUSH ES
                   MOV AX,SEG @DATA {TP's Datensegment wiederherstellen}
                   MOV DS,AX
                 END;
                 INC(counter);
                 WHILE ClockTicks<t+counter*temp DO BEGIN END;
                 ASM;
                   POP ES
                   POP DX
                   POP AX
                   {--- Einschub Ende}

                   INC AX        {alle Spalten durch?}
                   CMP AX,LINESIZE
                   JB oneColumn1  {nein, nÑchste Spalte}

                   MOV DX,3CEh   {Writemode 0 wiederherstellen}
                   MOV AX,4005h
                   OUT DX,AX
                   POP DS
                 END;
                END;
         END
    ELSE BEGIN {pa = BACKGNDPAGE, also von RAM nach VRAM}
          IF EMSused
           THEN EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}
          IF left
           THEN BEGIN {nach links scrollen}
                 ASM
                   MOV SI,1
                   SUB SI,PAGE
                   AND SI,1
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW
                   MOV ES,AX     {ES := Segment_Adr[1 - PAGE] = ^sichtbare Seite}

                   MOV SI,pa
                   AND SI,3
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW         {AX := Segment_Adr[pa] = ^Quelladresse}

                   PUSH DS
                   MOV DX,AX
                   MOV BX,0*LINESIZE+0 {DX:BX = ^Quelldaten}
                   MOV AX,LINESIZE-1 {Spaltenzaehler}

                 oneColumn4:     {alten Schirminhalt nach rechts schieben:}
                   MOV SI,DX
                   MOV DI,AX
                   MOV DX,3C4h
                   MOV AX,0F02h  {alle 4 Planes gleichzeitig ansprechen}
                   OUT DX,AX
                   MOV DX,3CEh
                   MOV AX,4105h  {Writemode 1 setzen}
                   OUT DX,AX
                   MOV DX,SI
                   MOV AX,DI

                   MOV SI,ES
                   MOV DS,SI     {DS = ES = sichtbare Grafikseite}
                   MOV SI,PAGESIZE-2
                   MOV DI,PAGESIZE-1
                   MOV CX,PAGESIZE-1
                   STD
                   REP MOVSB
                   CLD

                   MOV CX,SEG @DATA
                   MOV DS,CX     {DS = ^TP Daten}
                   MOV CX,YMAX+1 {CX = ZeilenzÑhler}

                   MOV SI,AX     {Spaltenzaehler}
                   XOR DI,DI
                   MOV BX,LINESIZE-1
                   MOV DS,DX     {DS = ^Quelldaten}

                   PUSH AX
                   PUSH DX
                   MOV DX,3CEh   {Writemode 0 setzen}
                   MOV AX,4005h
                   OUT DX,AX

                   MOV DX,3C4h

                 @oneRow0:       {erste Spalte erneuern:}
                   MOV AX,0802h  {Writeplane 3 selektieren}
                   OUT DX,AX
                   MOV AL,[SI +3*PAGESIZE]
                   MOV ES:[DI],AL
                   MOV AX,0402h  {Writeplane 2 selektieren}
                   OUT DX,AX
                   MOV AL,[SI +2*PAGESIZE]
                   MOV ES:[DI],AL
                   MOV AX,0202h  {Writeplane 1 selektieren}
                   OUT DX,AX
                   MOV AL,[SI +1*PAGESIZE]
                   MOV ES:[DI],AL
                   MOV AX,0102h  {Writeplane 0 selektieren}
                   OUT DX,AX
                   MOVSB
                   ADD SI,BX     {auf nÑchste Zeile positionieren:}
                   ADD DI,BX     {geht, weil BX + 1 = LINESIZE}
                   LOOP @oneRow0


                   {--- Einschub fÅr Zeitbedingung:}
                   PUSH ES       {alle noch relevanten Register retten}
                   MOV AX,SEG @DATA {TP's Datensegment wiederherstellen}
                   MOV DS,AX
                 END;
                 INC(counter);
                 WHILE ClockTicks<t+counter*temp DO BEGIN END;
                 ASM;
                   POP ES
                   {--- Einschub Ende}

                   POP DX
                   POP AX
                   DEC AX        {alle Spalten durch?}
                   JNS oneColumn4  {nein, nÑchste Spalte}

                   MOV DX,3CEh   {Writemode 0 wiederherstellen}
                   MOV AX,4005h
                   OUT DX,AX
                   POP DS
                 END;
                END
           ELSE BEGIN {nach rechts scrollen}
                 ASM
                   MOV SI,1
                   SUB SI,PAGE
                   AND SI,1
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW
                   MOV ES,AX     {ES := Segment_Adr[1 - PAGE] = ^sichtbare Seite}

                   MOV SI,pa
                   AND SI,3
                   SHL SI,1
                   ADD SI,OFFSET Segment_Adr-StartIndex*2
                   LODSW         {AX := Segment_Adr[pa] = ^Quelladresse}

                   PUSH DS
                   MOV DX,AX
                   MOV BX,0*LINESIZE+0 {DX:BX = ^Quelldaten}

                   MOV AX,0      {AX = SpaltenzÑhler}

                 oneColumn3:     {alten Schirminhalt nach links schieben:}
                   MOV SI,DX
                   MOV DI,AX
                   MOV DX,3C4h
                   MOV AX,0F02h  {alle 4 Planes gleichzeitig ansprechen}
                   OUT DX,AX
                   MOV DX,3CEh
                   MOV AX,4105h  {Writemode 1 setzen}
                   OUT DX,AX
                   MOV DX,SI
                   MOV AX,DI

                   MOV SI,ES
                   MOV DS,SI     {DS = ES = sichtbare Grafikseite}
                   MOV SI,1
                   XOR DI,DI
                   MOV CX,PAGESIZE-1
                   REP MOVSB

                   MOV CX,SEG @DATA
                   MOV DS,CX     {DS = ^TP Daten}
                   MOV CX,YMAX+1 {CX = ZeilenzÑhler}

                   MOV SI,AX
                   MOV DI,LINESIZE-1
                   MOV BX,LINESIZE-1
                   MOV DS,DX     {DS = ^Quelldaten}

                   PUSH AX
                   PUSH DX
                   MOV DX,3CEh   {Writemode 0 setzen}
                   MOV AX,4005h
                   OUT DX,AX

                   MOV DX,3C4h

                 @oneRow:        {letzte Spalte erneuern:}
                   MOV AX,0802h  {Writeplane 3 selektieren}
                   OUT DX,AX
                   MOV AL,[SI +3*PAGESIZE]
                   MOV ES:[DI],AL
                   MOV AX,0402h  {Writeplane 2 selektieren}
                   OUT DX,AX
                   MOV AL,[SI +2*PAGESIZE]
                   MOV ES:[DI],AL
                   MOV AX,0202h  {Writeplane 1 selektieren}
                   OUT DX,AX
                   MOV AL,[SI +1*PAGESIZE]
                   MOV ES:[DI],AL
                   MOV AX,0102h  {Writeplane 0 selektieren}
                   OUT DX,AX
                   MOVSB
                   ADD SI,BX     {auf nÑchste Zeile positionieren:}
                   ADD DI,BX     {geht, weil BX + 1 = LINESIZE}
                   LOOP @oneRow

                   {--- Einschub fÅr Zeitbedingung:}
                   PUSH ES       {alle noch relevanten Register retten}
                   MOV AX,SEG @DATA {TP's Datensegment wiederherstellen}
                   MOV DS,AX
                 END;
                 INC(counter);
                 WHILE ClockTicks<t+counter*temp DO BEGIN END;
                 ASM;
                   POP ES
                   {--- Einschub Ende}

                   POP DX
                   POP AX

                   INC AX        {alle Spalten durch?}
                   CMP AX,LINESIZE
                   JB oneColumn3  {nein, nÑchste Spalte}

                   MOV DX,3CEh   {Writemode 0 wiederherstellen}
                   MOV AX,4005h
                   OUT DX,AX
                   POP DS
                 END;
                END;
         END
  END;

  PROCEDURE CircleIn(pa,time:WORD);
  { in: pa    = Seite, deren Inhalt sichtbar gemacht werden soll}
  {     time  = ungefÑhre Zeit (in Millisekunden), in der das geschehen soll}
  {out: - }
  {rem: Der Inhalt der Seite "pa" wurde auf die Seite 1-PAGE kopiert}
  CONST centerX=XMAX DIV 2; {Bildschirmmitte}
        centerY=YMAX DIV 2;
        k=189;     {Anzahl Kreise := sqrt(centerX˝ + centerY˝), aufgerundet}
        adjust=0.707106781; {Kompensation in Diagonalrichtung = 1/sqrt(2) }
        n=TRUNC(k/adjust);  {Anzahl Aufrufe der Verzîgerungsschleife}
  VAR radqu,x,y,x0,y0,u1,u2,u3,u4,v1,v2,v3,v4:WORD;
      counter:WORD;
      ClockTicks:LONGINT ABSOLUTE $40:$6C;
      t:LONGINT;
      radius,temp:REAL;
  BEGIN
   t:=ClockTicks;
   counter:=0;
   temp:=0.0182*time/n;
   x0:=centerX + StartVirtualX;
   y0:=centerY + StartVirtualY;
   {FOR true_radius:=1 TO k STEP 1/adjust ist in Pascal leider nicht mîglich!}
   radius:=0.0;
   REPEAT
    radqu:=TRUNC(sqr(radius));
    FOR x:=0 TO TRUNC(radius/sqrt(2)) DO {Oktanden berechnen}
     BEGIN
      y:=TRUNC(sqrt(radqu-sqr(x))); {Satz des Pythagoras}
      u1:=x0-x; v1:=y0-y;           {Achsen- und Punktsymmetrie ausnutzen}
      u2:=x0+x; v2:=y0+y;
      u3:=x0-y; v3:=y0-x;
      u4:=x0+y; v4:=y0+x;
      PutPixel(u1,v1,PageGetPixel(u1,v1,pa));
      PutPixel(u1,v2,PageGetPixel(u1,v2,pa));
      PutPixel(u2,v1,PageGetPixel(u2,v1,pa));
      PutPixel(u2,v2,PageGetPixel(u2,v2,pa));
      PutPixel(u3,v3,PageGetPixel(u3,v3,pa));
      PutPixel(u3,v4,PageGetPixel(u3,v4,pa));
      PutPixel(u4,v3,PageGetPixel(u4,v3,pa));
      PutPixel(u4,v4,PageGetPixel(u4,v4,pa));
     END;
    radius:=radius+adjust;
    INC(counter);
    WHILE ClockTicks<t+counter*temp DO BEGIN END;
   UNTIL radius>=k;
  END;

BEGIN {of FadeIn}
 IF (pa<0) OR (pa>SCROLLPAGE)
  THEN Error:=Err_InvalidPageNumber
  ELSE CASE style OF
        Fade_Squares :WipeIn(pa,ti);
        Fade_Moiree1..Fade_Moiree14:Chaos(pa,ti,style+1-Fade_Moiree1);
        Fade_SweepInFromTop:    SweepVertical(pa,ti,TRUE);
        Fade_SweepInFromBottom: SweepVertical(pa,ti,FALSE);
        Fade_SweepInFromLeft:   SweepHorizontal(pa,ti,TRUE);
        Fade_SweepInFromRight:  SweepHorizontal(pa,ti,FALSE);
        Fade_ScrollInFromTop:   ScrollVertical(pa,ti,TRUE);
        Fade_ScrollInFromBottom:ScrollVertical(pa,ti,FALSE);
        Fade_ScrollInFromLeft:  ScrollHorizontal(pa,ti,TRUE);
        Fade_ScrollInFromRight: ScrollHorizontal(pa,ti,FALSE);
        Fade_Circles : CircleIn(pa,ti);
        Fade_Moiree15:Chaos2(pa,ti,style+1-Fade_Moiree15);
        else Error:=Err_InvalidFade
       END;
END;


PROCEDURE IntroScroll(n,wait:WORD);
{ in: n    = Anzahl Zeilen, die hochgescrollt werden sollen}
{     wait = Zeit (in ms), die nach jeder Zeile gewartet werden soll}
{rem: Das Scrollen beginnt immer auf Seite 0 (=$A000:0000)}
{     Hinterher mu· das Kommando "Screen(1-page)" ausgefÅhrt werden!}
BEGIN
 Screen(0); {auf $A000:0000 positionieren}
 ASM
    XOR SI,SI                {Adresse von Seite 0 ermitteln = $A000:0000}
    AND SI,3                 {Pagewert * 2 (da WorteintrÑge!)}
    SHL SI,1                 {dazu Startadresse des Feldes addieren}
    ADD SI,OFFSET Offset_Adr-StartIndex*2  {evtl. Verschiebung korrigieren}
    LODSW                    {und Wert holen}
    MOV BX,AX
    MOV CX,n
    MOV SI,wait

  @oneline:
    ADD BX,LINESIZE

    CLI                      {Darf keinenfalls unterbrochen werden!}
    MOV DX,StatusReg
    @WaitNotHSyncLoop:
      in   al,dx
      and  al,1
      jz  @WaitNotHSyncLoop
    @WaitHSyncLoop:
      in   al,dx
      and  al,1
      jz   @WaitHSyncLoop

    MOV DX,CRTAddress        {CRT-Controller}
    MOV AL,$0D               {LB-Startadress-Register}
    OUT DX,AL
    INC DX

    MOV AL,BL
    OUT DX,AL                {LB der neuen Startadresse setzen}
    DEC DX
    MOV AL,$0C
    OUT DX,AL
    INC DX
    MOV AL,BH                {HB der neuen Startadresse setzen}
    OUT DX,AL
    STI

    PUSH BX
    PUSH CX
    PUSH SI
    PUSH SI
    CALL CRT.Delay
    POP SI
    POP CX
    POP BX
    LOOP @oneline

 END;
END;

PROCEDURE CopyVRAMtoVRAM(source,dest:POINTER; len:WORD); ASSEMBLER;
{ in: source = Startadresse}
{     dest   = Zieladresse }
{     len    = LÑnge des zu kopierenden Bereichs}
{out: - }
{rem: Die beiden Bereiche dÅrfen sich nicht Åberlappen}
{     Es wird der WriteMode1 verwendet, weshalb die LÑnge "len" fÅr}
{     je 4 Bytes zÑhlt: bspw. wÅrde ein Aufruf der Form}
{     CopyVRAMtoVRAM(Ptr($A000,0),Ptr($A000,PAGESIZE),PAGESIZE) }
{     eine ganze Seite (4*PAGESIZE = 64000 Bytes) kopieren}
ASM
  MOV AX,4105h   {Writemode1 einschalten}
  MOV DX,3CEh
  OUT DX,AX
  MOV AX,0F02h   {alle 4 Planes gleichzeitig ansprechen}
  MOV DX,3C4h
  OUT DX,AX

  MOV BX,DS

  LES DI,dest
  LDS SI,source
  MOV CX,len
  CLD
  REP MOVSB

  MOV DS,BX

  MOV AX,4005h
  MOV DX,3CEh
  OUT DX,AX
END;


PROCEDURE InitRoutines;
{ in: USEEMS = TRUE fÅr: EMS-Speicher fÅr BACKGNDPAGE benutzen}
{out: SpriteN[],SPRITEAD[],SPRITEPTR[],SPRITESIZE[],BackTile[] wurden auf}
{     "gÑnzlich leer" initialisiert}
{     NextSprite[] wurde so gesetzt, da· jedes Sprite sein eigener}
{     Nachfolger ist}
{     PAGE, PAGEADR wurden auf die Grafikseite 0 eingestellt}
{     BACKGNDADR wurde auf die Hintergrundseite gesetzt     }
{     SCROLLADR wurde auf die scrollbare Hintergrundseite gesetzt}
{     BACKGROUNDMODE wurde auf STATIC gesetzt}
{     Als Defaulttile fÅr den scrollbaren Hintergrund wurde #0 gesetzt   }
{     StartVirtualX,StartVirtualY = 0 (d.h.: virtuelle = absolute Koord.)}
{     oldMode = alter Grafikmodus}
{     Error wurde gesetzt, falls keine VGA-Karte im System enthalten ist }
{     CycleTime = 0, d.h.: keine Mindestzeit fÅr einen Animationszyklus  }
{     Color = 15, d.h.: wei· }
{     CurrentFont = Zeiger auf internen Font}
{     FontHeight, FontWidth = Abmessungen des internen Fonts}
{     FontType = dessen Typ}
{     ActualColors = Defaultfarbpalette des Modus $13 }
{     CRTAddress = Portadresse des CRT-Adressregisters}
{     StatusReg  = Portadresse des Statusregisters    }
{     EMSused = TRUE, wenn EMS-Speicher fÅr BACKGNDPAGE alloziert wurde  }
{     BackgroundEMSHandle = Handle auf allozierten EMS-Block (wenn EMSused=TRUE)}
{     buf = Zeiger auf allozierten Heap-Block (wenn EMSused=FALSE)       }
{     Win* Koordinaten wurden auf das gesamte Animationsfenster gesetzt  }
{     SplitIndex wurde so gesetzt, da· alle Sprites auf das Animations-  }
{     fenster zurechtgeclipt werden}
{rem: Diese Prozedur sollte einmal - ganz zu Beginn - zur Initialisierung}
{     des Animationspaketes aufgerufen werden                            }
TYPE rec=RECORD lw,hw:WORD END;
VAR i,adj:WORD;

    FUNCTION IsVGA:BOOLEAN;
    BEGIN
     WITH Regs DO
      BEGIN
       AX:=$1A00;
       Intr($10,Regs);
       IsVGA:=(AL=$1A) AND    {VGA Identify-Adapter-Function unterstÅtzt?}
              ( (BL=7) OR (BL=8) )  {VGAMono oder VGAColor - Adapter}
      END;
    END;

BEGIN
 IF IsVGA THEN Error:=Err_None
          ELSE BEGIN
                Error:=Err_NoVGA;
                exit
               END;

 SetCycleTime(0);

 FillChar(SpriteN,SizeOf(SpriteN),0);
 FillChar(SPRITEAD,SizeOf(SPRITEAD),0);
 FillChar(SPRITESIZE,SizeOf(SPRITESIZE),0);
 FillChar(BackTile,SizeOf(BackTile),0);

 FOR i:=0 TO LoadMAX DO
  BEGIN
   NextSprite[i]:=i;
   SPRITEPTR[i]:=NIL
  END;

 BACKGNDADR:=Segment_Adr[BACKGNDPAGE];  {Segmentadresse der Hintergrundseite}

 PAGE:=0;   {Seite, auf der gezeichnet werden soll}
 PAGEADR:=Segment_Adr[PAGE];
 SCROLLADR:=Segment_Adr[SCROLLPAGE];
 SetBackgroundMode(STATIC);
 SetOffscreenTile(0);

 StartVirtualX:=0; StartVirtualY:=0;    {virtuelle = absolute Koordinaten}
 Color:=white;            {aktuelle Zeichenfarbe sei Wei· }
 regs.ah:=$f; intr($10,regs); oldMode:=regs.al;

 ActualColors:=DefaultColors;
 {SetShadowTab(Schatten) kann entfallen, da Defaultwerte schon gesetzt!}

 ASM  {ermitteln, ob Farb- oder Monochromdarstellung}
   MOV DX,3CCh  {Output-Register befragen:}
   IN AL,DX
   TEST AL,1    {ist es ein Farbbildschirm?}
   MOV DX,3D4h
   JNZ @L1      {ja  }
   MOV DX,3B4h  {nein}
  @L1:          {DX = 3B4h / 3D4h = CRTAddress-Register fÅr monochrom/Farbe}
   MOV CRTAddress,DX
   ADD DX,6     {DX = 3BAh / 3DAh = Status-Register fÅr monochrom/Farbe}
   MOV StatusReg,DX
 END; {of ASM}

 LoadFont('');  {internen Font laden}
 SetAnimateWindow(0,0,319,199);

 EMSused:=FALSE;

 IF EmsInstalled(BACKGNDADR) AND
    EMSIsHardWareEMS AND
    (EMSPagesAvailable>=4) AND
    (EMSError=0)
  THEN BEGIN {EMS verwenden}
        BackgroundEMSHandle:=EMSAllocate(4); {64K allozieren}
        If EmsError<>0
         THEN BEGIN {doch nicht}
               WriteLn ('EMS-Allozierungsfehler!' );
               EMSRelease(BackgroundEMSHandle);
              END
         ELSE BEGIN
               EMSused:=TRUE;
               buf:=Ptr(BACKGNDADR,0)
              END;
       END;

 IF NOT EMSused
  THEN BEGIN {kein, nicht genÅgend oder falscher EMS-Speicher, Heap benutzen:}
        New(buf)
       END
  ELSE EMSFillFrame(BackgroundEMSHandle); {Zugriff auf EMS vorbereiten}

 FillChar(buf^,SizeOf(buf^),0);
 adj:=rec(buf).lw DIV 16;
 IF (rec(buf).lw MOD 16)<>0
  THEN inc(adj); {zu aufsteigenden Adressen hin runden}
 inc(rec(buf).hw,adj);
 rec(buf).lw:=0;

 IF rec(buf).lw<>0
  THEN BEGIN
        WRITELN('Fehler: buf^ liegt nicht auf Segmentgrenze');
        Halt
       END
  ELSE BEGIN
        Segment_Adr[BACKGNDPAGE]:=rec(buf).hw;
        Offset_Adr[BACKGNDPAGE]:=0;
        BACKGNDADR:=rec(buf).hw
       END;
 SetAnimateWindow(0,0,XMAX,YMAX);
 SetSplitIndex(-1); {=alle clippen}
END;

PROCEDURE CloseRoutines;
{ in: oldMode = alter Grafikmodus, auf den zurÅckgeschaltet werden soll}
{     EMSused = wurde EMS-Speicher fÅr BACKGNDPAGE verwendet?}
{     BackgroundEMSHandle = falls ja, so ist dies das Handle darauf}
{     buf       = falls nein, dann ist dies der Pointer auf normalen Heap}
{out: - }
BEGIN
 regs.al:=oldMode; regs.ah:=0; intr($10,regs);
 IF EMSused
  THEN EMSRelease(BackgroundEMSHandle)
  ELSE Release(buf);
END;

FUNCTION GetErrorMessage:STRING;
{ in: Error = Nummer des aufgetretenen Fehlers}
{out: den Fehler in Worten}
BEGIN
 CASE Error OF
  Err_None:GetErrorMessage:='No Error';
  Err_NotEnoughMemory:GetErrorMessage:='Not enough memory available on heap';
  Err_FileIO:GetErrorMessage:='I/O-error with file';
  Err_InvalidSpriteNumber:GetErrorMessage:='Invalid sprite number used';
  Err_NoSprite:GetErrorMessage:='No (or corrupted) sprite file';
  Err_InvalidPageNumber:GetErrorMessage:='Invalid page number used';
  Err_NoVGA:GetErrorMessage:='No VGA-card found';
  Err_NoPicture:GetErrorMessage:='No (or corrupted) picture file';
  Err_InvalidPercentage:GetErrorMessage:='Percentage value must be 0..100';
  Err_NoTile:GetErrorMessage:='No (or corrupted) tile/sprite file';
  Err_InvalidTileNumber:GetErrorMessage:='Invalid tile number used';
  Err_InvalidCoordinates:GetErrorMessage:='Invalid coordinates used';
  Err_BackgroundToBig:GetErrorMessage:='Background to big for tile-buffer';
  Err_InvalidMode:GetErrorMessage:='Only STATIC or SCROLLING allowed here';
  Err_InvalidSpriteLoadNumber:GetErrorMessage:='Invalid spriteload number used';
  Err_NoPalette:GetErrorMessage:='No (or corrupted) palette file';
  Err_PaletteWontFit:GetErrorMessage:='Attempt to write beyond palette end';
  Err_InvalidFade:GetErrorMessage:='Invalid fade style used';
  Err_NoFont:GetErrorMessage:='No (or corrupted) font file';
  Err_EMSError:GetErrorMessage:='Problems with EMS memory';
  ELSE GetErrorMessage:='Unknown error';
 END;
END;

FUNCTION FindFile(P:PathStr):PathStr;
{ in: P = zu suchende Datei, mit Anfangspfad}
{out: vollstÑndiger Pfad zur Datei}
{rem: Steht die Datei nicht im angegebenen Verzeichnis, so werden alle}
{     rekursiv alle Unterverzeichnisse abgesucht.}
{     Endet die Suche auch dort ergebnislos, so wird '' zurÅckgegeben}
VAR D: DirStr;
    N: NameStr;
    E: ExtStr;
    DateiName:STRING[12];
    temp:PathStr;

 FUNCTION SearchFile(Pfad:PathStr):PathStr;
 { in: DateiName = zu suchende Datei}
 {     Pfad = Anfangssuchpfad fÅr diese Datei}
 {out: vollstÑndiger Pfad zur Datei oder '', falls Datei nicht gefunden}
 VAR Datei,Dir:SearchRec;
 BEGIN
  FindFirst(Pfad+DateiName,AnyFile,Datei);
  WHILE DosError=0 DO
   BEGIN
    IF (Datei.Attr AND Directory)<>Directory
     THEN BEGIN
           SearchFile:=Pfad+Datei.Name;
           Exit
          END;
    FindNext(Datei)
   END;

  {hierher, wenn Suche im aktuellen Verzeichnis erfolglos}
  FindFirst(Pfad+'*.*',Directory,Dir);
  WHILE DosError=0 DO
   BEGIN
    IF ((Dir.Attr AND Directory)=Directory) AND (Dir.Name[1]<>'.')
     THEN BEGIN {durchsuche nÑchstes Directory}
           temp:=SearchFile(Pfad+Dir.Name+'\');
           IF temp<>''
	    THEN BEGIN {rekursiv gefunden!}
                  SearchFile:=temp;
                  Exit
                 END;
          END;
    FindNext(Dir);
   END;
  SearchFile:='';
 END;

BEGIN
 FSplit(P,D,N,E);
 DateiName:=N+E;
 FindFile:=SearchFile(D)
END;



BEGIN

 InitRoutines;

END.

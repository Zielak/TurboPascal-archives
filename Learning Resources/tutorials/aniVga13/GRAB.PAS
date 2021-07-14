{$UNDEF Test}

{$B-,F-,I+,R-,S+,X+}

{$IFDEF Test}
 {$M 2048,0,15000}
{$ELSE}
 {$M 2048,0,0}
{$ENDIF}

PROGRAM GrabSprite;

{$IFDEF Test}
USES Graph,Dos,Crt;
{$ELSE}
USES Crt,Dos,TSR6;
{$ENDIF}
CONST maxwidth=38*4;      {Workarea; gerade so gross gewaehlt, dass die Daten}
      maxheight=maxwidth; {noch von MAKES weiterverarbeitet werden koennen}

      Datenbytes=maxheight*succ(pred(maxwidth) div 4)*4;
      Kopf=50; {Grî·e des folgenden Spriteheaders in Bytes (ohne Data-Feld):}

      BackGndMode : BOOLEAN = FALSE;  {Sprites oder Hintergrund einfangen?}

TYPE sprite_typ= record case Integer of
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
         Data:Array[1..Datenbytes] OF Byte;
        );
      1:(
         readin:Array[0..(Datenbytes-1)  {max. Grî·e der Planedaten}
                      +(maxwidth*2)*2    {dto., Y-Grenzen (2 Wort-Tabellen)}
                      +(maxheight*2)*2   {dto., X-Gr. (auch WorteintrÑge)}
                      +Kopf] OF Byte;    {Zeiger am Anfang, immer!}
        )
     END;
    PlotXYProc  =PROCEDURE (x,y:INTEGER);
    GetDotXYFunc=FUNCTION (x,y:INTEGER):BYTE;
    GraphicMode=RECORD
                 x,y:INTEGER;
                 m  :BYTE;
                 put:PlotXYProc;
                 get:GetDotXYFunc
                END;


VAR PlotXY   : PlotXYProc;
    GetDotXY : GetDotXYFunc;
    sprite   : Sprite_Typ;
    mask: BYTE;
    temp,Zugriff:BYTE;
    maxx,maxy,
    deltax,deltay,
    breite,hoehe,
    x1,y1,x2,y2,
    x1old,y1old,x2old,y2old:INTEGER;
    MB:WORD;  {zum auslesen der Mausbuttons}

    mode   : BYTE ABSOLUTE $40:$49;  {aktueller Grafikmodus}
    page   : BYTE ABSOLUTE $40:$62;  {aktuelle Grafikseite}
    pageadr: WORD; {Startadresse davon, wird aus VGA direkt ausgelesen}

    CRTAddress, {Adresse des CRT-Ports, $3B4/$3D4 fuer monochrom/Farbe}
    StatusReg:WORD;  {dto., fuer Statusregister, $3BA/$3DA}

{-----Maus: -----------------------------}
CONST NoButton=0;    {Ergebniswerte von MouseButtons fuer: kein...,}
      LeftButton=1;  {...nur der linke,}
      RightButton=2; {...nur der rechte,}
      BothButtons=3; {...beide Mausbuttons gedrueckt}
      SaveArea=1000; {benoetigter Speicher (ca.) , um Mausstatus zu retten}
VAR SaveMouseArea:ARRAY[1..SaveArea] OF BYTE;

FUNCTION InitMouse(VAR buttons:WORD):BOOLEAN; ASSEMBLER;
{ in: - }
{out: buttons = Anzahl Buttons,}
{     TRUE/FALSE fuer Maus da/nich da}
{rem: Routine muss zu Beginn aufgerufen werden!}
ASM
  XOR AX,AX
  INT $33
  LES DI,buttons
  MOV ES:[DI],BX
  NEG AX
END;

PROCEDURE ResetMouse; ASSEMBLER;
{ in: - }
{out: - }
{rem: versetzt die Maus in ihren Initialisierungszustand}
ASM
  XOR AX,AX
  INT $33
END;

FUNCTION MouseButtons:WORD; ASSEMBLER;
{ in: - }
{out: Zustand der Buttons, in Bit 0&1 codiert}
ASM
  MOV AX,3
  INT $33
  MOV AX,BX
  AND AX,3
END;

PROCEDURE GetMouseMovement(VAR deltax,deltay:INTEGER); ASSEMBLER;
{ in: - }
{out: deltax,deltay = relative Bewegung der Maus seit dem letzten Aufruf}
ASM
  MOV AX,$B
  INT $33
  LES DI,deltax
  MOV ES:[DI],CX
  LES DI,deltay
  MOV ES:[DI],DX
END;

FUNCTION MemToStoreMouseState:WORD; ASSEMBLER;
ASM
  MOV AX,$15
  INT $33
  MOV AX,BX
END;

PROCEDURE SaveMouse; ASSEMBLER;
{ in: - }
{out: - }
{rem: Mausstatus wurde in "SaveMouseArea" gerettet}
{     Dieses Feld muss gross genug sein, um diese Infos aufnehmen zu koennen}
ASM
  MOV AX,$16
  MOV DX,OFFSET SaveMouseArea
  PUSH DS
  POP ES
  INT $33
END;

PROCEDURE RestoreMouse; ASSEMBLER;
{ in: SaveMouseArea enthaelt alten Mauszustand}
{out: - }
{rem: alter Mauszustand wurde wiederhergestellt}
ASM
  MOV AX,$17
  MOV DX,OFFSET SaveMouseArea
  PUSH DS
  POP ES
  INT $33
END;

{-----Palette: --------------------------}
TYPE PaletteEntry=RECORD red,green,blue:BYTE END;
     BigPalette=ARRAY[0..255] OF PaletteEntry;
     PalettePtr=^BigPalette;
     SmallPalette=ARRAY[0..15] OF BYTE;
CONST DefaultColors:BigPalette=    {Defaultfarben-Palette des 256-Farbmodus}
 (                                 {ausgelesen mithilfe des BIOS-Aufrufs:  }
  (red:  0; green:  0; blue:  0),  { MOV AX,1017h ;lese Palettenregister}
  (red:  0; green:  0; blue: 42),  { XOR BX,BX    ;von Farbe 0 an }
  (red:  0; green: 42; blue:  0),  { MOV CX,100h  ;alle 256 Farben}
  (red:  0; green: 42; blue: 42),  { LES DX,Ziel  ;nach ES:DX }
  (red: 42; green:  0; blue:  0),  { INT 10h }
  (red: 42; green:  0; blue: 42),  {Achtung! Die Werte koenn(t)en nur dann }
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

VAR ActualColors:BigPalette;
    oldColor,newColor:PaletteEntry;
    i,b,dummy:BYTE;
    palette:SmallPalette;

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

PROCEDURE GetSmallPalette(VAR pal:SmallPalette); ASSEMBLER;
{ in: pal = Zeiger auf Palette-Speicher}
{out: pal = momentan aktueller Inhalt der 16-Farben Palette}
ASM
  cli
  mov bx,15
  les di,pal
 @L1:
  mov dx,StatusReg
  in al,dx
  mov dx,3c0h
  mov al,bl
  out dx,al
  inc dx
  in al,dx
  dec dx
  mov es:[di+bx],al
  mov dx,StatusReg
  in al,dx
  mov dx,3c0h
  mov al,20h
  out dx,al
  dec bx
  jns @L1
  sti
END;

PROCEDURE ConvertToDACValues(pal:SmallPalette; n:BYTE; VAR Colors:BigPalette);
{ in: pal   = Farbpalette}
{     n     = groesster benutzter Farbindex in "pal"}
{     Colors= aktueller Inhalt der 256 CLUT-Register als RGB-Tripel}
{out: Colors[0..n]=wirklich benutzte RGB-Tripel}
VAR i:BYTE;
    temp:BigPalette;
BEGIN
 FOR i:=0 TO n DO temp[i]:=Colors[pal[i]];
 FOR i:=0 TO n DO Colors[i]:=temp[i]
END;

{----------------------------------------}

PROCEDURE swap(VAR x,y:INTEGER);
VAR t:INTEGER;
BEGIN
 t:=x; x:=y; y:=t
END;

FUNCTION NormalMode13hGetDot(x,y:INTEGER):BYTE; FAR; ASSEMBLER;
{ in: (x,y)  = Punktkoordinaten des auszulesenden Punktes }
{out: Farbwert des Punkte Åber eine schnelle Routine      }
ASM
  cli
  mov ax,320
  mul y
  mov bx,x
  add bx,ax
  mov ax,$A000
  mov es,ax
  mov al,es:[bx]
  xor ah,ah
  sti
END;

FUNCTION CGAGetDot(x,y:INTEGER):BYTE; FAR; ASSEMBLER;
{ in: (x,y)  = Punktkoordinaten des auszulesenden Punktes }
{     mask   = Farben, die der aktive Grafikmodus unter-  }
{              stÅtzt minus 1 (als Maske fÅr AND-Befehl)  }
{     maxx   = max. X-Koordinate (319 oder 639)           }
{out: Farbwert des Punkte Åber eine schnelle Routine      }
ASM
  cli
  mov ax,0B800h {CGA-Adresse beginnt immer bei $B8000}
  mov es,ax
  mov cx,y
  mov dx,x

  xor bx,bx     {0 = Offset fÅr ungerade Zeilen}
  test cl,1     {gerade Zeile?}
  jz @evenRow   {nein}
  mov bx,2000h  {ja, Offset dafÅr laden}
@evenRow:
  shr cx,1
  mov al,80
  mul cl        {AX = (y div 2) * 80 }

  mov cx,dx
  not cl
  and cl,mask
  shl cl,1      {CL = Bitposition}

  shr dx,1
  shr dx,1
  cmp maxx,319  {eine der mittleren Auflîsungen (320x200)?}
  jbe @L1       {ja, nur durch 4 teilen}
  shr dx,1      {nein, 640x200, deshalb durch 8 teilen}
@L1:

  add ax,dx
  add bx,ax     {ES:BX = Zeiger auf Punktadresse}

  mov al,es:[bx]
  ror al,cl     {relevante Bits isolieren}
  and al,mask   {Rest lîschen}

  xor ah,ah     {sicher ist sicher!}
  sti
END;


FUNCTION EGAVGAGetDot(x,y:INTEGER):BYTE; FAR; ASSEMBLER;
{ in: (x,y)  = Punktkoordinaten des auszulesenden Punktes }
{     pageadr= Offsetadresse der aktuellen Grafikseite    }
{     mask   = Farben, die der aktive Grafikmodus unter-  }
{              stÅtzt minus 1 (als Maske fÅr AND-Befehl)  }
{              (ist fÅr diese Modi immer = $F)            }
{out: Farbwert des Punkte Åber eine schnelle Routine      }
ASM
  cli
  mov dx,3ceh
  mov al,5      {Modusregister...}
  out dx,al
  inc dx
  in al,dx      {...retten}
  push ax
  mov al,0
  out dx,al     {readmode 0 setzen}

  dec dx
  mov al,4      {map select Register...}
  out dx,al
  inc dx
  in al,dx
  push ax       {...retten}

  mov bx,x
  mov cx,bx
  and cl,7
  xor cl,7      {CL=7-(x mod 8)}
  mov ch,1
  shl ch,cl     {CH=Bitmaske}

  mov ax,80
  mul y
  shr bx,1
  shr bx,1
  shr bx,1
  add bx,ax
  add bx,pageadr
  mov ax,$A000
  mov es,ax     {ES:BX = Punktadresse}

  mov ah,3      {Startplane}
  mov dx,3cfh
@L1:
  mov al,ah
  out dx,al
  mov al,es:[bx]
  shl cl,1
  and al,ch     {Punkt gesetzt?}
  jz @L2        {nein}
  or cl,1       {ja, merken}
@L2:
  dec ah        {nÑchste Plane}
  jge @L1
  and cl,mask   {cl=Ergebnisfarbe}

  pop ax
  out dx,al     {map select Register wiederherstellen}
  dec dx
  mov al,5      {Modusregister auch}
  out dx,al
  inc dx
  pop ax
  out dx,al

  mov al,cl     {Ergebnis mu· in AX stehen}
  xor ah,ah     {sicher ist sicher!}
  sti
END;

FUNCTION BiosGetDot(x,y:INTEGER):BYTE; FAR; ASSEMBLER;
{ in: (x,y) = Punktkoordinaten des auszulesenden Punktes  }
{     page  = Grafikseite, auf der sich der Punkt befindet}
{     mask  = Farben, die der aktive Grafikmodus unter-   }
{             stÅtzt minus 1 (als Maske fÅr AND-Befehl)   }
{out: Farbwert des Punkte Åber einen BIOS-Aufruf}
ASM
  mov ah,$0D
  mov bh,page
  mov cx,x
  mov dx,y
  push ds
  push bp
  int $10
  pop bp
  pop ds
  and al,mask
END;

FUNCTION SpecialMode13hGetDot(x,y:INTEGER):BYTE; FAR;
{ in: (x,y) = Punktkoordinaten}
{out: Farbwert dieses Punktes }
{rem: Diese Routine ist ausschlie·lich fÅr den eigenen,   }
{     320x200x256x4 - Grafikmodus entwickelt, den das BIOS}
{     nicht kennt!}
VAR Offset,Adresse:Word;
    Plane,temp :Byte;
BEGIN
 ASM
    CLI
    MOV DX,CRTAddress {Bildschirmstartadresse auslesen}
    MOV AL,0Ch
    OUT DX,AL
    INC DX
    IN AL,DX
    MOV AH,AL
    DEC DX
    MOV AL,0Dh
    OUT DX,AL
    INC DX
    IN AL,DX
    MOV Adresse,AX
    STI
 END;

 Offset:=y*80+(x shr 2);
 Plane :=(x and 3);
 portw[$3CE]:=4 +(plane shl 8);
 SpecialMode13hGetDot:=mem[$A000:Adresse+Offset];
END;

PROCEDURE NormalMode13hXORDot(x,y:INTEGER); FAR; ASSEMBLER;
{ in: (x,y)  = Koordinaten des zu invertierenden Punktes}
{out: der Punkt wurde mittels einer schnellen Routine }
{     in seiner Farbe invertiert}
ASM
  cli
  mov ax,320
  mul y
  mov bx,x
  add bx,ax
  mov ax,$A000
  mov es,ax
  mov al,es:[bx]
  not al
  mov es:[bx],al
  sti
END;

PROCEDURE CGAXORDot(x,y:INTEGER); FAR; ASSEMBLER;
{ in: (x,y)  = Koordinaten des zu invertierenden Punktes}
{     mask   = Farben-1 des aktiven Grafikmodus}
{     maxx   = max. X-Koordinate (319 oder 639)}
{out: der Punkt wurde mittels einer schnellen Routine }
{     in seiner Farbe invertiert}
ASM
  cli
  mov ax,0B800h {CGA-Adresse beginnt immer bei $B8000}
  mov es,ax
  mov cx,y
  mov dx,x

  xor bx,bx     {0 = Offset fÅr ungerade Zeilen}
  test cl,1     {gerade Zeile?}
  jz @evenRow   {nein}
  mov bx,2000h  {ja, Offset dafÅr laden}
@evenRow:
  shr cx,1
  mov al,80
  mul cl        {AX = (y div 2) * 80 }

  mov cx,dx
  not cl
  cmp maxx,319  {640x200 Modus?}
  jbe @L0       {nein, Bitposition = (not(X) AND mask)*2 }
  and cl,7      {ja, Bitposition berechnet sich zu not(X MOD 7)}
  jmp @L2
@L0:
  and cl,mask
  shl cl,1
@L2:            {CL = Bitposition}

  shr dx,1
  shr dx,1
  cmp maxx,319  {eine der mittleren Auflîsungen (320x200)?}
  jbe @L1       {ja, nur durch 4 teilen}
  shr dx,1      {nein, 640x200, deshalb durch 8 teilen}
@L1:

  add ax,dx
  add bx,ax     {ES:BX = Zeiger auf Punktadresse}

  mov al,es:[bx]
  ror al,cl
  mov ah,al
  mov dl,mask
  and al,dl     {AL = gelesene Farbe}
  not al
  and al,dl     {AL = zu setzende Farbe}

  not dl
  and ah,dl
  or al,ah
  rol al,cl

  mov es:[bx],al

  sti
END;

PROCEDURE EGAVGAXORDot(x,y:INTEGER); FAR;
{ in: (x,y)  = Koordinaten des zu invertierenden Punktes}
{     pageadr= Offsetadresse der Grafikseite des Punktes}
{     mask   = Farben-1 des aktiven Grafikmodus}
{              (ist immer $F fÅr diese Modi)   }
{out: der Punkt wurde mittels einer schnellen Routine }
{     in seiner Farbe invertiert}
VAR farbe:BYTE;
BEGIN
 farbe:=NOT EGAVGAGetDot(x,y);
 ASM
  cli
  mov dx,3ceh
  mov al,5      {Modusregister...}
  out dx,al
  inc dx
  in al,dx      {...retten}
  push ax
  mov al,2
  out dx,al     {writemode 2 setzen}

  dec dx
  mov al,8      {bitmask Register...}
  out dx,al
  inc dx
  in al,dx
  push ax       {...retten}

  mov bx,x
  mov cx,bx
  and cl,7
  xor cl,7      {CL=7-(x mod 8)}
  mov al,1
  shl al,cl     {AL=Bitmaske}

  out dx,al     {setzen}

  mov ax,80
  mul y
  shr bx,1
  shr bx,1
  shr bx,1
  add bx,ax
  add bx,pageadr
  mov ax,$A000
  mov es,ax     {ES:BX = Punktadresse}

  mov al,farbe
  mov es:[bx],al

  pop ax
  mov dx,3cfh
  out dx,al     {bitmask Register wiederherstellen}
  dec dx
  mov al,5      {Modusregister auch}
  out dx,al
  inc dx
  pop ax
  out dx,al

  sti
 END;
END;

PROCEDURE BiosXORDot(x,y:INTEGER); FAR; ASSEMBLER;
{ in: (x,y) = Koordinaten des zu invertierenden Punktes}
{     page  = Grafikseite, auf der sich der Punkt befindet}
{     mask  = Farben-1 des aktiven Grafikmodus}
{out: der Punkt wurde mittels BIOS-Aufrufen in seiner Farbe invertiert}
ASM
  mov ah,$0D
  mov bh,page
  mov cx,x
  mov dx,y
  push ds
  push bp
  int $10
  pop bp
  pop ds
  not al
  and al,mask

  mov ah,$0C
  mov bh,page
  mov cx,x
  mov dx,y
  int $10
END;

PROCEDURE SpecialMode13hXORDot(x,y:INTEGER); FAR;
{ in: (x,y) = Koordinaten des zu invertierenden Punktes}
{out: der Punkt wurde in seiner Farbe invertiert}
{rem: Diese Routine ist ausschlie·lich fÅr den eigenen,   }
{     320x200x256x4 - Grafikmodus entwickelt, den das BIOS}
{     nicht kennt!}
VAR Offset,Adresse:Word;
    Plane,temp :Byte;
BEGIN
 ASM
    CLI
    MOV AX,4005h      {Writemode 0 setzen}
    MOV DX,3CEh
    OUT DX,AX

    MOV DX,CRTAddress {Bildschirmstartadresse auslesen}
    MOV AL,0Ch
    OUT DX,AL
    INC DX
    IN AL,DX
    MOV AH,AL
    DEC DX
    MOV AL,0Dh
    OUT DX,AL
    INC DX
    IN AL,DX
    MOV Adresse,AX
    STI
 END;

 Offset:=y*80+(x shr 2);
 Plane :=(x and 3);
 portw[$3CE]:=4 +(plane shl 8);
 temp:=mem[$A000:Adresse+Offset];
 portw[$3C4]:=2+(1 shl (plane+8));
 mem[$A000:Adresse+Offset]:=not temp;
END;

FUNCTION SaveMode:BYTE;
{ in: - }
{out: aktueller Schreib-/Lesemodus der Grafikkarte}
BEGIN
 ASM
    MOV DX,3CEh
    MOV AL,5
    OUT DX,AL
    INC DX
    IN AL,DX
    MOV @Result,AL
 END
END;

PROCEDURE RestoreMode(m:BYTE);
{ in: m = zu setzender Schreib-/Lesemodus}
{out: der entsprechende Modus wurde gesetzt}
BEGIN
 ASM
    MOV DX,3CEh
    MOV AL,5
    MOV AH,m
    OUT DX,AX
 END;
END;

PROCEDURE xor_line(x1,y1,x2,y2:INTEGER);
{ in: (x1,y1) = linke, obere Startecke }
{     (x2,y2) = rechte, untere Endecke }
{   ( page    = aktuelle Grafikseite ) }
{   ( mask    = Farben-1 des Grafikmodus)   }
{out: Die durch die beiden Punkte definierte}
{     Linie wurde in ihrer Farbe invertiert }
{rem: page und mask mÅssen fÅr den speziellen 320x200x256x4-Modus}
{     nicht gesetzt sein}
{     Die Linie mu· horizontal oder vertikal verlaufen}
{     Es mu· gelten: x1<=x2, y1<=y2}
VAR i:INTEGER;
BEGIN
 if y1=y2
  THEN FOR i:=x1 TO x2 DO PlotXY(i,y1)
  ELSE FOR i:=y1 TO y2 DO PlotXY(x1,i);
END;

PROCEDURE xor_box(x1,y1,x2,y2:INTEGER);
{ in: (x1,y1) = linke, obere Startecke }
{     (x2,y2) = rechte, untere Endecke }
{   ( page    = aktuelle Grafikseite ) }
{   ( mask    = Farben-1 des Grafikmodus)   }
{out: Das durch die beiden Punkte definierte}
{     Rechteck wurde farblich invertiert    }
{rem: page und mask mÅssen fÅr den speziellen 320x200x256x4-Modus}
{     nicht gesetzt sein}
{     Es mu· gelten: x1<=x2, y1<=y2}
BEGIN
 xor_line(succ(x1),y1,x2,y1);
 xor_line(x2,succ(y1),x2,y2);
 xor_line(x1,y2,pred(x2),y2);
 xor_line(x1,y1,x1,pred(y2));
END;

FUNCTION Update(VAR ch:CHAR):BOOLEAN;
{ in: ch = Ziffer als Zeichen   : '0'..'9'}
{out: ch = um 1 erhîhtes Zeichen: '1'..'0'}
{     TRUE/FALSE, falls öbertrag in nÑchsthîhere Stelle}
BEGIN
 IF ch='9'
  THEN ch:='0'
  ELSE ch:=chr(succ(ord(ch)));
 Update:=ch='0'
END;

PROCEDURE ComputeSprite;
{ in: x1,y1,x2,y2 = als Sprite zu sicherndes Bildschirmrechteck}
{     BestColor = Farbumsetztabelle    }
{   ( page    = aktuelle Grafikseite ) }
{   ( mask    = Farben-1 des Grafikmodus)   }
{out: Sprite  = berechnete Spritedaten }
{rem: Der Inhalt dieses Rechtecks wird in die Datei           }
{     "GRAB_xxx.COD" geschrieben; }
{     Der Grafikmodus mu· korrekt eingeschaltet sein, da die  }
{     Spriteinformationen direkt vom Schirm gelesen werden.   }
{     page und mask mÅssen fÅr den speziellen 320x200x256x4-  }
{     Modus nicht gesetzt sein}
VAR i,j,offset,Plane_Groesse:Word;
    temp,p:Byte;
    links,rechts,oben,unten:Integer;
    fertig_li,fertig_re,fertig_ob,fertig_un:Boolean;
BEGIN

 WITH Sprite DO
  BEGIN

   {letzte nicht ganz schwarze Zeile suchen (Workarea kann auch leer sein!)}
   MaxY:=Succ(y2);
   REPEAT
    dec(MaxY);
    temp:=0;
    FOR i:=x1 TO x2 DO temp:=temp or GetDotXY(i,MaxY);
   UNTIL (temp<>0) or (maxy<y1);
   IF maxy<y1
    THEN BEGIN
          sound(500); delay(100); nosound;
          exit
         END;

   {dto., fÅr Spalte}
   MaxX:=Succ(x2);
   REPEAT
    dec(MaxX);
    temp:=0;
    FOR i:=y1 TO MaxY DO temp:=temp or GetDotXY(MaxX,i);
   UNTIL temp<>0;

   dec(MaxX,x1); dec(MaxY,y1); {relative Positionen}

   Translate[1]:=1; Translate[2]:=2; Translate[3]:=4; Translate[4]:=8;
   Kennung[1]:='K'; Kennung[2]:='R';
   Version:=1;
   Modus:=0;
   FOR i:=1 TO 10 DO dummy[i]:=0; {Dummywerte auf 0 setzen}
   Hoehe_in_Zeilen:=Succ(MaxY);   {Y-Werte reichen von 0..MaxY}
   Breite_in_4er_Gruppen:=Succ(MaxX shr 2); {0..3->1, 4..7->2, ...}
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
   SpriteLength:=Kopf+(Plane_Groesse*4)+
                  (Hoehe_in_Zeilen*2)*2+
                  (Breite_in_4er_Gruppen*4 *2)*2;

   {Jetzt die eigentlichen Spritedaten berechnen:}
   offset:=0;
   FOR j:=y1+0 TO y1+MaxY DO
    BEGIN
     FOR i:=0 TO Pred(Breite_in_4er_Gruppen) DO
      BEGIN
       FOR p:=0 TO 3 DO
         Readin[Zeiger_auf_Plane[p]+offset]:= GetDotXY(x1+(i shl 2)+p,j);
       inc(offset);

      END;
    END;

   {Nun die X-Grenzdaten fÅr jede Zeile:}
   offset:=0;
   FOR j:=y1+0 TO y1+MaxY DO
    BEGIN
     links:=x1+0;
     rechts:=x1+Pred(Breite_in_4er_Gruppen shl 2);
     fertig_li:=false; fertig_re:=false;
     REPEAT
      if (not fertig_li and (GetDotXY(links,j)=0))
       THEN inc(links) ELSE fertig_li:=true;
      if (not fertig_re and (GetDotXY(rechts,j)=0))
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
            dec(links, x1); {relative Position bestimmen}
            dec(rechts,x1);
            readin[ZeigerL+offset]:=lo(links);
            readin[Succ(ZeigerL+offset)]:=hi(links);
            readin[ZeigerR+offset]:=lo(rechts);
            readin[Succ(ZeigerR+offset)]:=hi(rechts)
           END;
     inc(offset,2)  {GrenzeintrÑge sind Wîrter!}
    END;

   {Dasselbe fÅr die Grenzdaten jeder Spalte:}
   offset:=0;
   FOR i:=x1+0 TO x1+Pred(Breite_in_4er_Gruppen shl 2) DO
    BEGIN
     oben :=y1+0;
     unten:=y1+MaxY;
     fertig_ob:=false; fertig_un:=false;
     REPEAT
      if (not fertig_ob and (GetDotXY(i,oben)=0))
       THEN inc(oben) ELSE fertig_ob:=true;
      if (not fertig_un and (GetDotXY(i,unten)=0))
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
            dec(oben, y1);
            dec(unten,y1);
            readin[ZeigerO+offset]:=lo(oben);
            readin[Succ(ZeigerO+offset)]:=hi(oben);
            readin[ZeigerU+offset]:=lo(unten);
            readin[Succ(ZeigerU+offset)]:=hi(unten)
           END;
     inc(offset,2)  {GrenzeintrÑge sind Wîrter!}
    END;

  END; {of with}
END;

PROCEDURE WriteSpriteToDisk;
{ in: Sprite = auf Disk zu schreibendes Sprite}
{     ActualColors[0..mask] = benutzte RGB-Farben}
{out: - }
{rem: Diese Routine darf nur aufgerufen werden, wenn Dos reentrantfaehig ist!}
{     Die Filenamen werden in den Nummern "fortgeschaltet"}
CONST Filename_lang:STRING[12]='GRAB_000.COD';
      Palname_lang :STRING[12]='GRABS000.PAL';
VAR f:FILE;
    fehler:BOOLEAN;
BEGIN
 {Nun die Daten auf Disk schreiben:}
 {$I-}
 fehler:=false;
 assign(f,Filename_lang); {Spritedaten schreiben}
 fehler:=fehler or (ioresult<>0);
 IF NOT fehler THEN rewrite(f,1);
 fehler:=fehler or (ioresult<>0);
 IF NOT fehler THEN blockwrite(f,sprite.readin,sprite.SpriteLength);
 close(f);
 fehler:=fehler or (ioresult<>0);

 assign(f,Palname_lang);  {Palette schreiben}
 fehler:=fehler or (ioresult<>0);
 IF NOT fehler THEN rewrite(f,1);
 fehler:=fehler or (ioresult<>0);
 IF NOT fehler THEN blockwrite(f,ActualColors[0],Succ(WORD(mask))*3);
 close(f);
 fehler:=fehler or (ioresult<>0);
 {$I+}
 IF fehler
  THEN sound(500)
  ELSE sound(1000);
 delay(100); nosound;

 IF Update(Filename_lang[8])  {Filenamen fÅr nÑchsten Aufruf generieren}
  THEN IF Update(Filename_lang[7])
        THEN Update(Filename_lang[6]);
 IF Update(Palname_lang[8])   {Palettennamen fÅr nÑchsten Aufruf generieren}
  THEN IF Update(Palname_lang[7])
        THEN Update(Palname_lang[6]);
END;

PROCEDURE WriteBackgroundToDisk;
{ in: x1,y1,x2,y2 = als Background zu sicherndes Bildschirmrechteck}
{     ActualColors[0..mask] = benutzte RGB-Farben}
{   ( page    = aktuelle Grafikseite ) }
{out: - }
{rem: Der Inhalt dieses Rechtecks wird in die Datei            }
{     "GRAB_xxx.PIC" geschrieben, die Palette in "GRABPxxx.PAL"}
{     Der Grafikmodus mu· korrekt eingeschaltet sein, da die   }
{     Spriteinformationen direkt vom Schirm gelesen werden.    }
{     page und mask mÅssen fÅr den speziellen 320x200x256x4-   }
{     Modus nicht gesetzt sein}
CONST Filename_lang:STRING[12]='GRAB_000.PIC';
      Palname_lang :STRING[12]='GRABP000.PAL';
      PICHeader:STRING[3]='PIC'; {wird den Daten als Kennung vorausgestellt}
VAR f:file of BYTE;
    f2:FILE;
    b,plane:BYTE;
    i,j:INTEGER;
    fehler:BOOLEAN;
BEGIN
 {Nun die Daten auf Disk schreiben:}
 {$I-}
 fehler:=false;
 assign(f,Filename_lang);
 fehler:=fehler or (ioresult<>0);
 IF NOT fehler THEN rewrite(f);
 fehler:=fehler or (ioresult<>0);
 IF NOT fehler
  THEN BEGIN
        FOR i:=1 TO Length(PICHeader) DO
         WRITE(f,BYTE(PICHeader[i]));
       END;
 fehler:=fehler or (ioresult<>0);
 IF NOT fehler
  THEN FOR plane:=0 TO 3 DO
        FOR j:=y1 TO y2 DO
         FOR i:=0 TO (x2-x1) SHR 2 DO
          BEGIN
           b:=GetDotXY(x1+(i shl 2)+plane,j);
           Write(f,b)
          END;
 close(f);
 fehler:=fehler or (ioresult<>0);

 assign(f2,Palname_lang);  {Palette schreiben}
 fehler:=fehler or (ioresult<>0);
 IF NOT fehler THEN rewrite(f2,1);
 fehler:=fehler or (ioresult<>0);
 IF NOT fehler THEN blockwrite(f2,ActualColors[0],Succ(WORD(mask))*3);
 close(f2);
 fehler:=fehler or (ioresult<>0);
 {$I+}
 IF fehler
  THEN sound(500)
  ELSE sound(1000);
 delay(100); nosound;

 IF Update(Filename_lang[8])  {Filenamen fÅr nÑchsten Aufruf generieren}
  THEN IF Update(Filename_lang[7])
        THEN Update(Filename_lang[6]);
 IF Update(Palname_lang[8])   {Palettennamen fÅr nÑchsten Aufruf generieren}
  THEN IF Update(Palname_lang[7])
        THEN Update(Palname_lang[6]);
END;

{Auflistung der BIOS-Grafikmodi: MaxX,MaxY,MaxColor,XORPlotXY(),GetDotXY()}
{Adressen werden zu NIL initialisiert und bei der Installation gesetzt}
{(Textmodi/nichtunterstÅtzte Modi erhalten Åberall 0)}
CONST
 resolution:ARRAY[4..19] OF GraphicMode=(
  (x:319; y:199; m:  3; put:CGAXORDot;    get:CGAGetDot),     {Mode 4}
  (x:319; y:199; m:  3; put:CGAXORDot;    get:CGAGetDot),     {Mode 5}
  (x:639; y:199; m:  1; put:CGAXORDot;    get:CGAGetDot),     {Mode 6}
  (x:  0; y:  0; m:  0; put:BiosXORDot;   get:BiosGetDot),
  (x:  0; y:  0; m:  0; put:BiosXORDot;   get:BiosGetDot),
  (x:319; y:199; m: $F; put:BiosXORDot;   get:BiosGetDot),    {Mode 9}
  (x:639; y:199; m:  3; put:BiosXORDot;   get:BiosGetDot),    {Mode 10}
  (x:  0; y:  0; m:  0; put:BiosXORDot;   get:BiosGetDot),
  (x:  0; y:  0; m:  0; put:BiosXORDot;   get:BiosGetDot),
  (x:319; y:199; m: $F; put:EGAVGAXORDot; get:EGAVGAGetDot),  {Mode 13}
  (x:639; y:199; m: $F; put:EGAVGAXORDot; get:EGAVGAGetDot),  {Mode 14}
  (x:639; y:349; m:  3; put:EGAVGAXORDot; get:EGAVGAGetDot),  {Mode 15}
  (x:639; y:349; m: $F; put:EGAVGAXORDot; get:EGAVGAGetDot),  {Mode 16}
  (x:  0; y:  0; m:  0; put:BiosXORDot;   get:BiosGetDot),
  (x:639; y:479; m: $F; put:EGAVGAXORDot; get:EGAVGAGetDot),  {Mode 18}
  (x:319; y:199; m:$FF; put:NormalMode13hXORDot; get:NormalMode13hGetDot) {Mode 19}
  );


FUNCTION PopUp:WORD; FAR;
{ in: resolution enthaelt die richtigen Zugriffsdaten (BIOS/nicht-BIOS) }
{out: - }
{rem: Dies ist die eigentliche residente Popup-Routine, die beim betÑtigen}
{     des Hotkeys auftaucht, den Benutzer einen Bildausschnitt auswÑhlen  }
{     lÑ·t und diesen als Spritefile abspeichert!}
LABEL quit,again;
CONST BackgroundMaxX=319; {Hintergrundbildschirm = 320x200 Punkte}
      BackgroundMaxY=199;
VAR i:WORD;
    SpriteModus:BOOLEAN;
    ch:CHAR;

 PROCEDURE FlipModus;
 VAR breite,hoehe:WORD;
 BEGIN
  SpriteModus:=NOT SpriteModus;
  IF SpriteModus
   THEN BEGIN breite:=pred(maxwidth); hoehe:=pred(maxheight) END
   ELSE BEGIN breite:=BackgroundMaxX; hoehe:=BackgroundMaxY END;
  x2:=x1+breite;
  IF x2>maxx THEN BEGIN x2:=maxx; x1:=x2-breite END;
  y2:=y1+hoehe;
  IF y2>maxy THEN BEGIN y2:=maxy; y1:=y2-hoehe END;
  xor_box(x1,y1,x2,y2)
 END;

 PROCEDURE FindVGARegisters; ASSEMBLER;
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
 
BEGIN
 maxx:=resolution[mode].x; {dirty programmiert: Bereichsueberpruefung}
 maxy:=resolution[mode].y; {muss abgeschaltet sein!                  }
 mask:=resolution[mode].m;

 IF (mode<4) or (mode>19) or (maxx=0)   {nichtunterstÅtzter Modus?}
  THEN BEGIN
        sound(500); delay(500); nosound;
        exit
       END;

 FindVGARegisters;  {ermittle CRTAddress und StatusReg}

 IF (mode<4) OR (mode>6)  {fuer die CGA-Modi gibt es keine variable Startad.}
  THEN ASM {aktuelle Grafikseite ermitteln}
         CLI
         MOV DX,CRTAddress
         MOV AL,0Ch
         OUT DX,AL
         INC DX
         IN AL,DX
         MOV AH,AL
         DEC DX
         MOV AL,0DH
         OUT DX,AL
         INC DX
         IN AL,DX
         MOV pageadr,AX
         STI
       END;


 IF mask<=15
  THEN BEGIN
        GetBigPalette(ActualColors); {256 Farben der CLUT auslesen}
        GetSmallPalette(palette);    {16 Palettenfarben auslesen  }
        ConvertToDACValues(palette,mask,ActualColors) {echte Farbwerte ermitteln}
       END
  ELSE BEGIN
        GetBigPalette(ActualColors); {256 Farben auslesen}
       END;

 Zugriff:=SaveMode;  {alten Schreib-/Lesemodus retten}
 IF mode=19
  THEN BEGIN  {Spezieller, eigener Mode $13 ?}
        ASM
           CLI
           MOV DX,3C4h
           MOV AL,4
           OUT DX,AL
           INC DX
           IN AL,DX
           AND AL,0Ch
           MOV temp,AL
           STI
        END;
        IF temp=$4
         THEN BEGIN
               PlotXY  :=SpecialMode13hXORDot;  {ja, spezielle Routinen!}
               GetDotXY:=SpecialMode13hGetDot
              END
         ELSE BEGIN
               PlotXY  :=resolution[mode].put; {nein, normale Routinen}
               GetDotXY:=resolution[mode].get
              END
       END
  ELSE BEGIN
        PlotXY  :=resolution[mode].put;  {alle anderen Modi sowieso normal}
        GetDotXY:=resolution[mode].get
       END;

 x1:=0; y1:=0; x2:=maxwidth-1; y2:=maxheight-1; SpriteModus:=TRUE;
 SaveMouse; ResetMouse;
 WHILE Keypressed DO ch:=Readkey; {Tastaturpuffer lîschen}

 xor_box(x1,y1,x2,y2);
 REPEAT
  again:;  {hierher, wenn ModusÑnderung stattfand}

  IF SpriteModus
   THEN BEGIN {Spritebox zeigen}
         REPEAT

          WHILE (MouseButtons=LeftButton) AND (NOT keypressed) DO
           BEGIN {Box veraendern, wenn linker Button gedrueckt}
            GetMouseMovement(deltax,deltay);

            {rechte untere Ecke bewegen:}
            INC(deltax,x2);
            IF deltax<0 THEN deltax:=0
            ELSE IF deltax>maxx THEN deltax:=maxx;
            INC(deltay,y2);
            IF deltay<0 THEN deltay:=0
            ELSE IF deltay>maxy THEN deltay:=maxy;

            {max. Groesse nicht ueberschritten?}
            breite:=succ(deltax-x1);
            IF breite>maxwidth THEN DEC(deltax,breite-maxwidth);
            hoehe :=succ(deltay-y1);
            IF hoehe>maxheight THEN DEC(deltay,hoehe-maxheight);

            x1old:=x1; y1old:=y1; x2old:=x2; y2old:=y2;
            {min. Groesse unterschritten (= untere rechte Ecke ueber/links von}
            {oberer rechter?}
            IF breite<0 THEN swap(x1,deltax); {entsprechende Punkte vertauschen}
            IF hoehe <0 THEN swap(y1,deltay);

            IF (deltax<>x2) OR (deltay<>y2) {delta? gibt die neue untere re. Ecke an}
             THEN BEGIN
                   xor_box(x1old,y1old,x2old,y2old);
                   x2:=deltax; y2:=deltay;
                   xor_box(x1,y1,x2,y2)
                  END;
           END;

          WHILE (MouseButtons=NoButton) AND (NOT keypressed) DO
           BEGIN  {Box verschieben}
            GetMouseMovement(deltax,deltay);
            breite:=x2-x1; hoehe:=y2-y1;
            {rechte untere Ecke verschieben:}
            INC(deltax,x2);
            IF deltax<breite THEN deltax:=breite
            ELSE IF deltax>maxx THEN deltax:=maxx;
            INC(deltay,y2);
            IF deltay<hoehe THEN deltay:=hoehe
            ELSE IF deltay>maxy THEN deltay:=maxy;

            {linke obere Ecke neu berechnen:}
            x1old:=x1; y1old:=y1; x2old:=x2; y2old:=y2;
            x1:=deltax-breite; y1:=deltay-hoehe;

            IF (deltax<>x2) OR (deltay<>y2) {delta? gibt die neue untere re. Ecke an}
             THEN BEGIN
                   xor_box(x1old,y1old,x2old,y2old);
                   x2:=deltax; y2:=deltay;
                   xor_box(x1,y1,x2,y2)
                  END;
           END;

          MB:=MouseButtons;
         UNTIL (MB=RightButton) OR (MB=BothButtons) OR (keypressed);
         xor_box(x1,y1,x2,y2);

          IF keypressed
	  THEN BEGIN
                ch:=Upcase(readkey);
                IF ch=#27 THEN goto quit;  {Escape}
                IF ch=' ' THEN BEGIN FlipModus; goto again END;
               END;

         FOR i:=1 TO 10000 DO
          BEGIN {User etwas Zeit lassen, um beide Buttons "gleichzeitig" zu drÅcken}
           MB:=MB OR MouseButtons
          END;

         IF MB=BothButtons
          THEN BEGIN
                {do nothing}
               END
          ELSE BEGIN {RightButton = "Return"}
                ComputeSprite;       {"Sprite" in x1,y1,x2,y2 berechnen}
                IF Sprite.SpriteLength<>0 THEN WriteSpriteToDisk
               END;
         goto quit; {das war's!}
        END


   ELSE BEGIN {Backgroundmode}
         REPEAT
          MB:=MouseButtons;

          {Box verschieben}
          GetMouseMovement(deltax,deltay);
          {rechte untere Ecke verschieben:}
          INC(deltax,x2);
          IF deltax<BackgroundMaxX THEN deltax:=BackgroundMaxX
          ELSE IF deltax>maxx THEN deltax:=maxx;
          INC(deltay,y2);
          IF deltay<BackgroundMaxY THEN deltay:=BackgroundMaxY
          ELSE IF deltay>maxy THEN deltay:=maxy;

          {linke obere Ecke neu berechnen:}
          x1old:=x1; y1old:=y1; x2old:=x2; y2old:=y2;
          x1:=deltax-BackgroundMaxX; y1:=deltay-BackgroundMaxY;

          IF (deltax<>x2) OR (deltay<>y2) {delta? gibt die neue untere re. Ecke an}
           THEN BEGIN
                 xor_box(x1old,y1old,x2old,y2old);
                 x2:=deltax; y2:=deltay;
                 xor_box(x1,y1,x2,y2)
                END;
         UNTIL (MB=RightButton) OR (MB=BothButtons) OR keypressed;
         xor_box(x1,y1,x2,y2);

         IF keypressed
	  THEN BEGIN
                ch:=Upcase(readkey);
                IF ch=#27 THEN goto quit;  {Escape}
                IF ch=' ' THEN BEGIN FlipModus; goto again END;
               END;

         FOR i:=1 TO 10000 DO
          BEGIN {etwas Zeit lassen, um beide Buttons "gleichzeitig" zu drÅcken}
           MB:=MB OR MouseButtons
          END;

         IF MB<>RightButton
          THEN BEGIN {beide Buttons gedrÅckt}
                {do nothing}
               END
          ELSE BEGIN {RightButton = "Return"}
                WriteBackgroundToDisk
               END;
         goto quit;
        END;

UNTIL FALSE;

quit:
 RestoreMode(Zugriff);
 RestoreMouse;
 PopUp:=0;  {Null Zeichen in Tastaturpuffer ablegen}
END;

PROCEDURE Error;
BEGIN
 WRITELN('Call GrabSprite without parameters or with "BIOS" to use '+
         'INT10h-calls.'+#13+#10+
         'Program has _not_ been installed!');
 Halt
END;

PROCEDURE Init;
var i,j:word;
    IsVGA:BOOLEAN;
    s:STRING[127];
BEGIN
 ASM
  MOV AX,$1A00  {VGA Identify-Adapter-Funktion}
  INT $10
  CMP AL,$1A
  MOV AL,0
  JNE @noVGA
  CMP BL,7      {VGAMono?}
  JB @noVGA
  CMP BL,8      {VGAColor?}
  JA @noVGA
  INC AL
@noVGA:
  MOV IsVGA,AL
 END;

 IF NOT IsVGA
  THEN BEGIN
        WRITELN('*** Error: No VGA card found');
        Halt
       END;
 IF NOT InitMouse(i)
  THEN BEGIN
        WRITELN('*** Error: No mouse installed');
        Halt
       END;
 IF MemToStoreMouseState>SaveArea
  THEN BEGIN
        WRITELN('Not enough memory to save mouse state!');
        Halt
       END;
 s:='';
 IF (ParamCount>1) THEN Error;
 FOR j:=1 TO ParamCount DO
  BEGIN
   s:=ParamStr(j);
   FOR i:=1 TO Length(s) DO s[i]:=UpCase(s[i]);
   IF (s[1]='-') OR (s[1]='/') THEN Delete(s,1,1);
   IF s='BIOS'
    THEN BEGIN
          FOR i:=4 TO 19 DO
	   BEGIN
            resolution[i].put:=BiosXORDot;
            resolution[i].get:=BiosGetDot;
           END;
           WRITELN('All data will be read by using Video-BIOS INT10h');
           s:=''
         END
   ELSE Error;
  END;
END;

{$IFDEF Test}
PROCEDURE FakeInit;
var
  grDriver : Integer;
  grMode   : Integer;
  ErrCode  : Integer;
  Color    : Word;
  Pal      : PaletteType;
  lb,hb:Byte;
begin
  grDriver := VGA;
  grMode   := VGAHi;
  InitGraph(grDriver,grMode,'');
  ErrCode := GraphResult;
  if ErrCode = grOk then
    begin
      Graph.GetPalette(Pal);
      if Pal.Size <> 1 then
        for Color := Pred(Pal.Size) DOWNTO 0 do
        begin
          SetColor(Color);
          Line(0, Color, 100, Color);
        end
      else Line(0, 0, 100, 0);
    end
  else
    WriteLn('Graphics error:',GraphErrorMsg(ErrCode));

 fillchar(savemousearea,sizeof(savemousearea),0)
end;
{$ENDIF}

BEGIN
 Init;
{$IFDEF Test}
 FakeInit;
 PopUp;
 CloseGraph;
{$ELSE}
  TSRInstall('GrabSprite V2.0 (c) - by Kai Rohrbacher, 1992',
             PopUp,
             altkey+ctrlkey,
             'G');
{$ENDIF}
END.

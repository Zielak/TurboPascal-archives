{$A+,B-,D+,E+,F-,G-,I+,L+,N+,O-,R-,S-,V-,X+}
{$M 16384,0,655360}
PROGRAM WhatsNewInV12;
USES ANIVGA,CRT;
CONST FirstSpriteNumber=100;
      FireFontData='FIRE.FNT';      {path & name of the font to load}
      FireFontPal ='FIRE.PAL';      {corresponding palette}
      Tiles='WHATSNEW.LIB';         {1 black + 4 maeander tiles}
      tiles_per_row=2;              {These are the proportions of }
      tiles_per_column=2;           {the above 4 tile file: 2x2!  }
      ch:CHAR=#0; {sets ch to that value everytime the program starts}
VAR i,j,x,y,nr,oldX1,oldY1,oldX2,oldY2:INTEGER;
    tempPal,blackPal:Palette;

PROCEDURE CheckFileErr(name:STRING);
{ in: Error = error value}
{     name  = file to deal with}
{out: If there was an error with the file, the program stops in a clean way}
BEGIN
 IF Error<>Err_None
  THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file '+name+' : '+GetErrorMessage);
        halt(1)
       END;
END;

PROCEDURE ErrBeep;
BEGIN
 Sound(200); Delay(50); NoSound
END;


BEGIN
 ClrScr;
 WRITELN('Please wait while I''m loading the font '+FireFontData+' ...');
 SetBackgroundMode(scrolling);
 SetBackgroundScrollRange(-100,-100,500,300);
 MakeTileArea(1,2,2);

 {Load font and its palette}
 LoadFont(FireFontData); CheckFileErr(FireFontData);
 LoadPalette(FireFontPal,0,tempPal); CheckFileErr(FireFontPal);

 MakeTextSprite('What''s new in V1.2?',1);
 MakeTextSprite('Let''s demonstrate it!',7);

 LoadFont(''); {switch back to internal font again}

 MakeTextSprite('There are some minor changes & enhancements,',2);
 MakeTextSprite('which I won''t discuss here.',3);
 MakeTextSprite('The most eye-catching new feature is the',4);
 MakeTextSprite('possibility of an animation window, like this one.',5);
 MakeTextSprite('You may resize it any time you want to:',6);


 InitGraph;

 LoadTile(Tiles,0); {load the 5 tiles from the library file}
 IF Error<>Err_None
  THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file '+Tiles+' : '+GetErrorMessage);
        halt(1)
       END;
 SetCycleTime(40); {slow down animations}
 SetPalette(tempPal,TRUE);
 SetAnimateWindow(16,4,XMAX-4,YMAX-28);
 Color:=66;
 FillBackground(Color);

 GraphTextOrientation:=vertical;
 BackgroundOutTextXY(2,2,'WHATSNEW.EXE');
 GraphTextOrientation:=horizontal;

 {Place text sprites:}
 nr:=FirstSpriteNumber; x:=WinXMIN+7; y:=WinYMIN+150;
 SpriteN[nr]:=1; SpriteX[nr]:=x+10; SpriteY[nr]:=y;
 INC(y,MaxFontHeight); INC(nr);
 SpriteN[nr]:=2; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2); INC(nr);
 SpriteN[nr]:=3; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2+6); INC(nr);
 SpriteN[nr]:=4; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2); INC(nr);
 SpriteN[nr]:=5; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2); INC(nr);
 SpriteN[nr]:=6; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2);

 Animate;

 {scroll in text block:}
 FOR i:=1 TO 100 DO
  BEGIN
   FOR j:=FirstSpriteNumber TO nr DO DEC(SpriteY[j]);
   Animate;
  END;

 Delay(15000);
 SpriteN[FirstSpriteNumber]:=7; Animate; {show "let's.."}
 Delay(5000);

 {change size of animation window horizontally}
 oldX1:=WinXMIN; oldY1:=WinYMIN; oldX2:=WinXMAX; oldY2:=WinYMAX;
 FOR i:=1 TO 20 DO
  BEGIN
   SetAnimateWindow(oldX1+i*4,oldY1,oldX2-i*4,oldY2);
   UpdateOuterArea:=2; {to show that update}
   Delay(100);
   Animate;
  END;

 Delay(2000);
 {move text around horizontally}
 FOR i:=1 TO 100 DO
  BEGIN
   FOR j:=FirstSpriteNumber TO nr DO inc(SpriteX[j]);
   Animate
  END;
 FOR i:=1 TO 100 DO
  BEGIN
   FOR j:=FirstSpriteNumber TO nr DO dec(SpriteX[j]);
   Animate
  END;

 FOR i:=19 DOWNTO 0 DO
  BEGIN
   SetAnimateWindow(oldX1+i*4,oldY1,oldX2-i*4,oldY2);
   UpdateOuterArea:=2;
   Delay(100);
   Animate;
  END;
 SetAnimateWindow(oldX1,oldY1,oldX2,oldY2); UpdateOuterArea:=2;


 SpriteN[FirstSpriteNumber]:=1; Animate; {show "What's new"}
 Delay(2000);

 GraphTextColor:=Yellow; GraphTextBackground:=GraphTextColor;
 MakeTextSprite('- loadable fonts, monochrome or color',2); Animate;
 Delay(2000);
 MakeTextSprite('- convert textstrings to sprites (like now)',3); Animate;
 Delay(2000);
 MakeTextSprite('- optional data compression for all',4);
 MakeTextSprite('  external data files',5); Animate;
 Delay(2000);
 MakeTextSprite('- optional clipping for each individual sprite',6); Animate;
 Delay(2000);
 FOR i:=1 TO 45 DO
  BEGIN
   INC(StartVirtualY); Animate
  END;

 Delay(2000);
 MakeTextSprite('- faster than ever! (This demo is slowed down)',7);
 y:=SpriteY[nr]+FontHeight+2; INC(nr);
 SpriteN[nr]:=7; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2); INC(nr); Animate;

 Delay(2000);
 MakeTextSprite('- use the debugger (internal or external one)',8);
 MakeTextSprite('  to single-step your program in graphic mode',9);
 SpriteN[nr]:=8; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2); INC(nr);
 SpriteN[nr]:=9; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2); INC(nr); Animate;

 Delay(2000);
 MakeTextSprite('- decide yourself which text/lines/pixels shall',10);
 MakeTextSprite('  be clipped to the animation window',11);
 SpriteN[nr]:=10; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2); INC(nr);
 SpriteN[nr]:=11; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2+6); INC(nr); Animate;

 GraphTextColor:=White; GraphTextBackground:=GraphTextColor;
 Delay(2000);
 MakeTextSprite('Now try it out yourself!',12);
 MakeTextSprite('Use E to scroll around, I   i to resize',13);
 MakeTextSprite('   S D                 J K j k',14);
 MakeTextSprite('    X                   M   m',15);
 SpriteN[nr]:=12; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2+3); INC(nr);
 SpriteN[nr]:=13; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2); INC(nr);
 SpriteN[nr]:=14; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2); INC(nr);
 SpriteN[nr]:=15; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2+3); INC(nr);

 MakeTextSprite('These two sprites are not identical -find out!',16);
 SpriteN[nr]:=16; SpriteX[nr]:=x; SpriteY[nr]:=y;
 INC(y,FontHeight+2); INC(nr);
 SpriteN[0]:=16; SpriteX[0]:=x; SpriteY[0]:=y;
 SetSplitIndex(FirstSpriteNumber-1);

 GraphTextColor:=LightBlue; GraphTextBackground:=GraphTextColor;
 BackgroundOutTextXY(5,WinYMAX+50,
  'Use E,S,D,X to scroll around, I,J,K,M/i,j,k,m');
 BackgroundOutTextXY(5,WinYMAX+59,
  'to resize, <ESC> to quit.');
 UpdateOuterArea:=2;

 Animate;
 REPEAT
  if KeyPressed
   THEN BEGIN
         WHILE KeyPressed do ch:=ReadKey;
         CASE ch OF
          'e','E':dec(StartVirtualY,10);  {change position of whole scene with}
          's','S':dec(StartVirtualX,10);  {E,S,D,X}
          'd','D':inc(StartVirtualX,10);
          'x','X':inc(StartVirtualY,10);
          'i':IF (WinYMIN>0)
               THEN SetAnimateWindow(WinXMIN,WinYMIN-1,WinXMAX,WinYMAX)
               ELSE ErrBeep;
          'j':IF (WinXMIN>=4)
               THEN SetAnimateWindow(WinXMIN-4,WinYMIN,WinXMAX,WinYMAX)
               ELSE ErrBeep;
          'k':IF (WinXMAX-WinXMIN+1 > 32)
               THEN SetAnimateWindow(WinXMIN+4,WinYMIN,WinXMAX,WinYMAX)
               ELSE ErrBeep;
          'm':IF (WinYMAX-WinYMIN+1 > 32)
               THEN SetAnimateWindow(WinXMIN,WinYMIN+1,WinXMAX,WinYMAX)
               ELSE ErrBeep;
          'I':IF (WinYMAX-WinYMIN+1 > 32)
               THEN SetAnimateWindow(WinXMIN,WinYMIN,WinXMAX,WinYMAX-1)
               ELSE ErrBeep;
          'J':IF (WinXMAX-WinXMIN+1 > 32)
               THEN SetAnimateWindow(WinXMIN,WinYMIN,WinXMAX-4,WinYMAX)
               ELSE ErrBeep;
          'K':IF (WinXMAX+4<=XMAX)
               THEN SetAnimateWindow(WinXMIN,WinYMIN,WinXMAX+4,WinYMAX)
               ELSE ErrBeep;
          'M':IF (WinYMAX<YMAX)
               THEN SetAnimateWindow(WinXMIN,WinYMIN,WinXMAX,WinYMAX+1)
               ELSE ErrBeep;
         END;
         UpdateOuterArea:=2; {be extremely lazy here...}
         IF POS(ch,'IJKMijkmESDXesdx')>0 THEN Animate;
        END;

 UNTIL (ch='Q') OR (ch='q') OR (ch=#27);

 FillChar(blackPal,SizeOf(blackPal),0);
 FadeToPalette(blackPal,200);
 FOR i:=FirstSpriteNumber TO nr DO SpriteN[i]:=0;
 SpriteN[0]:=0; StartVirtualX:=0; StartVirtualY:=0;
 FillBackground(Color);
 SetBackgroundMode(STATIC);
 UpdateOuterArea:=2; Animate;
 LoadFont(FireFontData);
 x:=8; y:=5;
 BackgroundOutTextXY(x,y,'As said earlier, there are a lot of');
 BackgroundOutTextXY(x,y+FontHeight+2,'other changes :');
 BackgroundOutTextXY(x,y+2*(FontHeight+2),
 'Some bug fixes, usage of EMS for');
 BackgroundOutTextXY(x,y+3*(FontHeight+2),
 'the frame buffer, palette fade');
 BackgroundOutTextXY(x,y+4*(FontHeight+2),
 'in/out, a few minor changes to');
 BackgroundOutTextXY(x,y+5*(FontHeight+2),
 'MAKES, simplified background');
 BackgroundOutTextXY(x,y+6*(FontHeight+2),
 'tiling, etc.');
 BackgroundOutTextXY(x,y+7*(FontHeight+2),
 'Read WHATSNEW.TXT for more');
 BackgroundOutTextXY(x,y+8*(FontHeight+2),
 'information!');
 BackgroundOutTextXY(x,y+9*(FontHeight+2)+5,
 'Press any key to quit');

 Animate;

 FadeToPalette(tempPal,200);

 ch:=ReadKey;
 CloseRoutines;
END.

{$A+,B-,D+,L+,N-,E-,O-,R-,S-,V-,G-,F-,I-,X-}
{$M 16384,0,655360}
PROGRAM Example2;

{Demonstrates using scrolling backgrounds}

USES ANIVGA,CRT;
CONST TileName='tile2.COD';    {4 simple tiles}
      SpriteName='flower.COD';
      ch:Char=#0;
VAR i,j:Integer;
    temp:WORD;
    collide:BOOLEAN;

PROCEDURE Init;
BEGIN
 XTiles:=0; YTiles:=0;
 SetBackgroundMode(scrolling);
 SetOffscreenTile(3);
 SetBackgroundScrollRange(-500,-500,100,100);

 {paste tiles into this background, using circular enumeration 0,1,2,3,0,...}
 MakeTileArea(0,2,2);

 {Set SPRITEAD[10]:}
 IF loadSprite(SpriteName,10)=0
  THEN BEGIN
        WRITELN('Couldn''t access file '+SpriteName+' : '+GetErrorMessage);
       END;
END;

BEGIN
 Init;
 InitGraph;
 temp:=LoadTile(TileName,0); {load the 4 tiles & give them the numbers 0..3}
 IF Error<>Err_None
  THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file '+TileName+' : '+GetErrorMessage);
        halt(1)
       END;

 SetCycleTime(0); {animation as fast as possible}

 SpriteN[0]:=10; SpriteX[0]:=0;   SpriteY[0]:=0;
 SpriteN[5]:=10; SpriteX[5]:=100; SpriteY[5]:=100;

 WHILE keypressed DO ch:=readkey;
 Animate;
 REPEAT
  collide:=Hitdetect(0,5);
  IF collide THEN BEGIN sound(1000); delay(5); nosound END;
  if KeyPressed
   THEN BEGIN
         WHILE KeyPressed DO ch:=Upcase(ReadKey);
         CASE ch OF
          'I':dec(SpriteY[0]);  {change position of sprite with I,J,K,M}
          'J':dec(SpriteX[0]);
          'K':inc(SpriteX[0]);
          'M':inc(SpriteY[0]);
          'E':dec(StartVirtualY,10);  {change position of whole scene with}
          'S':dec(StartVirtualX,10);  {E,S,D,X}
          'D':inc(StartVirtualX,10);
          'X':inc(StartVirtualY,10);
         END;
         IF POS(ch,'IJKMESDX')>0 THEN Animate;
        END;

 UNTIL (ch='Q') OR (ch=#27);  {"Q" or ESC to quit}

 CloseRoutines;

END.

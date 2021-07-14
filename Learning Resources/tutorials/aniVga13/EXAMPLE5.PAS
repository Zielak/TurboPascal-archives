{$A+,B-,D+,L+,N-,E-,O-,R-,S-,V-,G-,F-,I-,X-}
{$M 16384,0,655360}
PROGRAM Example5;

{Demonstrates how to use an image as a scrolling background: the program will}
{load 5 tiles: a black one to be used for the surrounding image, and an image}
{2x2 tiles which is used to build the real background "image"}

{$X+} {to ignore results of functions}
USES ANIVGA,CRT;
CONST TileName1='black.COD';     {1 black tile}
      TileName2='aegypten.COD';  {4 tiles, captured from Win3.1}
      tiles_per_row=2;           {These are the proportions of }
      tiles_per_column=2;        {the above 4 tile file: 2x2!  }
      SpriteName='flower.COD';
      FlowerLoadNumber=1;        {load number for sprite}
      Flower1=0;                 {sprite number}
      Flower2=1;                 {another one  }
      ch:Char=#0;

PROCEDURE Init;
{Note that the tiles do not have to be actually loaded into memory! This}
{procedure pastes just _numbers_, not tiles - they will be loaded later!}
BEGIN
 XTiles:=0; YTiles:=0;
 SetBackgroundMode(scrolling);
 SetBackgroundScrollRange(50,50,300,100);

 {paste tiles into this background, using circular enumeration 1,2,3,4,1,...}
 MakeTileArea(1,tiles_per_row,tiles_per_column);

 {load sprite:}
 IF loadSprite(SpriteName,FlowerLoadNumber)=0
  THEN BEGIN
        WRITELN('Couldn''t access file '+SpriteName+' : '+GetErrorMessage);
        halt(1)
       END;
END;

BEGIN
 Init; {set up tile organization}
 InitGraph;
 LoadTile(TileName1,0); {load the black tile as tile #0 = surrounding pattern}
 IF Error<>Err_None
  THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file '+TileName1+' : '+GetErrorMessage);
        halt(1)
       END;
 LoadTile(TileName2,1); {load the 4 tiles as tile #1..4 = inner picture}
 IF Error<>Err_None
  THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file '+TileName2+' : '+GetErrorMessage);
        halt(1)
       END;

 SetCycleTime(0); {animation as fast as possible}

 SpriteN[Flower1]:=FlowerLoadNumber;
 SpriteX[Flower1]:=0;
 SpriteY[Flower1]:=0;
 SpriteN[Flower2]:=FlowerLoadNumber;
 SpriteX[Flower2]:=100;
 SpriteY[Flower2]:=100;

 Animate;
 REPEAT
  IF Hitdetect(Flower1,Flower2) THEN BEGIN sound(1000); delay(5); nosound END;
  if KeyPressed
   THEN BEGIN
         WHILE KeyPressed DO ch:=Upcase(ReadKey);
         CASE ch OF
          'I':dec(SpriteY[Flower1]);  {change position of sprite with I,J,K,M}
          'J':dec(SpriteX[Flower1]);
          'K':inc(SpriteX[Flower1]);
          'M':inc(SpriteY[Flower1]);
          'E':dec(StartVirtualY,10);  {change position of whole scene with}
          'S':dec(StartVirtualX,10);  {E,S,D,X}
          'D':inc(StartVirtualX,10);
          'X':inc(StartVirtualY,10);
         END;
         IF POS(ch,'IJKMESDX')>0 THEN Animate; {=only if something changed}
        END;

 UNTIL (ch='Q') OR (ch=#27);  {"Q" or ESC to quit}

 CloseRoutines;

END.

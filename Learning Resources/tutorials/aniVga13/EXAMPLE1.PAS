{$A+,B-,D+,L+,N-,E-,O-,R-,S-,V-,G-,F-,I-,X-}
{$M 16384,0,655360}
PROGRAM Example1;
USES ANIVGA,CRT;
CONST LoadNumber=42; {why not 42? - A hello to all Douglas Adam fans!}
      SpriteName='FLOWER.COD'; {Path and name of the sprite to load}
      Sprite1=0;
      Sprite2=5;
      ch:CHAR=#0; {sets ch to that value everytime the program starts}
VAR collide:BOOLEAN;

BEGIN
 IF loadSprite(SpriteName,LoadNumber)=0
  THEN BEGIN
        CloseRoutines;
        WRITELN('Error: '+GetErrorMessage); halt(1)
       END;

 InitGraph;

 Color:=66;
 BackgroundLine(0,0,XMAX,0); BackgroundLine(XMAX,0,XMAX,YMAX);
 BackgroundLine(XMAX,YMAX,0,YMAX); BackgroundLine(0,YMAX,0,0);
 BackgroundOutTextXY(100,70,'Hello world!');

 SpriteN[Sprite1]:=LoadNumber;
 SpriteX[Sprite1]:=0; SpriteY[Sprite1]:=0;

 SpriteN[Sprite2]:=LoadNumber;
 SpriteX[Sprite2]:=XMAX SHR 1; SpriteY[Sprite2]:=YMAX SHR 1;

 Animate;
 REPEAT
  collide:=Hitdetect(Sprite1,Sprite2);
  if collide THEN BEGIN Sound(1000); Delay(5); NoSound END;
  if KeyPressed
   THEN BEGIN
         WHILE KeyPressed do ch:=UpCase(ReadKey);
         CASE ch OF
          'I':DEC(SpriteY[Sprite1]);
          'J':DEC(SpriteX[Sprite1]);
          'K':INC(SpriteX[Sprite1]);
          'M':INC(SpriteY[Sprite1]);
          'E':dec(StartVirtualY,10);  {change position of whole scene with}
          'S':dec(StartVirtualX,10);  {E,S,D,X}
          'D':inc(StartVirtualX,10);
          'X':inc(StartVirtualY,10);
         END;
         IF POS(ch,'IJKMESDX')>0 THEN Animate;
        END;

 UNTIL (ch='Q') OR (ch=#27);

 CloseRoutines;
END.

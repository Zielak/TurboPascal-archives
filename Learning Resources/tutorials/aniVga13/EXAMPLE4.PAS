{$A+,B-,D+,L+,N-,E-,O-,R-,S-,V-,G-,F-,I-,X-}
{$M 16384,0,655360}
PROGRAM Example4;

{Demonstrates use of sprite cycles & SetCycleTime() to control animation speed}
{Besides that, usage of a sprite library is shown}

USES ANIVGA,CRT;
CONST LoadHantel=1;
      SpriteName='HANTEL.LIB'; {Path and name of the sprite to load}
      flip:BOOLEAN=FALSE;      {Flag for animation speed}
      ch:Char=#0;
VAR PicsLoaded:BYTE;
    i,n:WORD;

BEGIN
 PicsLoaded:=loadSprite(SpriteName,LoadHantel); {load sprites}
 IF Error<>Err_None
  THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file '+SpriteName+' : '+GetErrorMessage);
        halt(1)
       END;
 SetSpriteCycle(LoadHantel,PicsLoaded); {cycle through all images endlessly}

 InitGraph;

 FillBackground(76);

 FOR i:=1 TO 100 DO  {choose app. 100 sprites}
  BEGIN
   n:=RANDOM(NMAX)+1;
   SpriteN[n]:=LoadHantel+RANDOM(PicsLoaded);  {enter cycle somewhere}
   SpriteX[n]:=RANDOM(XMAX+1);  {use a random coordinates}
   SpriteY[n]:=RANDOM(YMAX+1)
  END;

 REPEAT
  IF KeyPressed
   THEN BEGIN
         ch:=UpCase(ReadKey);
         CASE ch OF
          'E':dec(StartVirtualY,10);  {change position of whole scene with}
          'S':dec(StartVirtualX,10);  {E,S,D,X}
          'D':inc(StartVirtualX,10);
          'X':inc(StartVirtualY,10);
          ' ':BEGIN   {toggle speed between maximum and 200ms per frame}
               flip:=NOT flip;
               IF flip
                THEN SetCycleTime(200)
                ELSE SetCycleTime(0)
              END;
         END;
        END;
  Animate;
 UNTIL (ch='Q') OR (ch=#27);

 CloseRoutines;
END.

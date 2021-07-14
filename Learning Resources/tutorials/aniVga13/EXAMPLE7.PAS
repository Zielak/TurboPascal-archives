{$A+,B-,D+,L+,N-,E-,O-,R-,S-,V-,G-,F-,I-,X-}
{$M 16384,0,655360}
PROGRAM Example7;

{Demonstrates the use of a loadable palettes: the program will load a _very_}
{strange palette (randomly generated...)}

USES ANIVGA,CRT;
CONST SpriteName='flower.COD';
      PalName='random.PAL';
      Flower=10;
      FlowerShadow=11;
      brightness:BYTE=80;

VAR ch:Char;
    i,j:Integer;
    temp:WORD;
    p1:POINTER;
    oldPal:Palette;


BEGIN

 IF (loadSprite(SpriteName,Flower)=0) OR     {load sprite 2x for different}
    (loadSprite(SpriteName,FlowerShadow)=0)  {display modes!}
  THEN BEGIN
        WRITELN('Couldn''t access file '+SpriteName+' : '+GetErrorMessage);
        halt(1)
       END;

 SetModeByte(FlowerShadow,Display_SHADOWEXACT); {set mode of shadow sprite}
 SetShadowTab(brightness);

 ch:=#0;

 InitGraph;
 IF LoadPalette(PalName,0,actualColors)=0
  THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file '+PalName+' : '+GetErrorMessage);
        Halt
       END
  ELSE SetPalette(actualColors,TRUE);

 {just to show how to change a color:}
 GetPalette(oldPal);      {read palette,   }
 oldpal[15].red:=0;       {change color(s),}
 oldpal[15].green:=63;
 oldpal[15].blue:=0;
 SetPalette(oldPal,TRUE); {show it!}

 FOR i:=15 TO 78 DO
  BEGIN {draw some colors on the screen}
   Color:=i;
   FOR j:=(i-15)*5 TO (i-15)*5+4 DO BackgroundLine(j,0,j,YMAX)
  END;

 BackgroundLine(0,0,XMAX,YMAX);

 SpriteN[0]:=Flower; SpriteX[0]:=100; SpriteY[0]:=100;
 {Use same flower for shadow zone:}
 SpriteN[1]:=FlowerShadow;
 SpriteX[1]:=SpriteX[0]+2; SpriteY[1]:=SpriteY[0]+2;

 Animate; REPEAT
  if keypressed
   THEN BEGIN
         while keypressed do ch:=upcase(readkey);
         case ch of
          'C':BEGIN
               p1:=GetImage(0,0,50,30,1-PAGE);
               PutImage(-10,-5,p1,BACKGNDPAGE);
               PutImage(-11,60,p1,BACKGNDPAGE);
               PutImage(-12,110,p1,BACKGNDPAGE);
               PutImage(-13,180,p1,BACKGNDPAGE);
               FreeImageMem(p1);
              END;
          'P':FOR i:=1 TO 1000 DO
               BackgroundPutPixel(Random(XMAX+1),Random(YMAX+1),Random(256));
          'I':BEGIN dec(SpriteY[0]); dec(SpriteY[1]) END;
          'J':BEGIN dec(SpriteX[0]); dec(SpriteX[1]) END;
          'K':BEGIN inc(SpriteX[0]); inc(SpriteX[1]) END;
          'M':BEGIN inc(SpriteY[0]); inc(SpriteY[1]) END;
          '+':IF brightness<100
               THEN BEGIN
                     inc(brightness); SetShadowTab(brightness)
                    END
               ELSE BEGIN
                     sound(500); delay(100); nosound
                    END;
          '-':IF brightness>0
               THEN BEGIN
                     dec(brightness); SetShadowTab(brightness)
                    END
               ELSE BEGIN
                     sound(500); delay(100); nosound
                    END;
         end;
         if pos(ch,'PCIJKM+-')>0 THEN Animate;
        END;

 UNTIL (ch='Q') OR (ch=#27);

 CloseRoutines;

END.

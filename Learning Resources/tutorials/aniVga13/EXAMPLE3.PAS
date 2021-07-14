{$A+,B-,D+,L+,N-,E-,O-,R-,S-,V-,G-,F-,I-,X-}
{$M 16384,0,655360}
PROGRAM Example3;

{Demonstrates usage of the Display_SHADOW and Display_SHADOWEXACT mode,     }
{GetImage(), PutImage() and SetShadowTab() }
{The same sprite is loaded twice (with different LOADnumbers) so that it can}
{be used with different display modes. The shadow zone is done by redrawing }
{the flower with display mode "Display_SHADOW" two pixels to the right and  }
{below the flower drawn with display mode "Display_NORMAL"; note that the   }
{outline of the shadow doesn't fully behave as wanted. To improve, one had  }
{to use display mode Display_SHADOWEXACT, which you may do by pressing SPACE}

USES ANIVGA,CRT;
CONST SpriteName='flower.COD';
      Flower=10;
      FlowerShadow=11;
      brightness:BYTE=80;
      ch:Char=#0;
VAR i,j:Integer;
    temp:BYTE;
    p1:POINTER;

BEGIN

 IF (loadSprite(SpriteName,Flower)=0) OR     {load sprite 2x for different}
    (loadSprite(SpriteName,FlowerShadow)=0)  {display modes!}
  THEN BEGIN
        WRITELN('Couldn''t access file '+SpriteName+' : '+GetErrorMessage);
        halt(1)
       END;

 SetModeByte(FlowerShadow,Display_SHADOW); {set mode of shadow sprite}

 SetShadowTab(brightness);
 InitGraph;

 FOR i:=15 TO 78 DO
  BEGIN {draw some colors on the screen}
   Color:=i;
   FOR j:=(i-15)*5 TO (i-15)*5+4 DO BackgroundLine(j,0,j,YMAX)
  END;

 SpriteN[0]:=Flower; SpriteX[0]:=100; SpriteY[0]:=100;
 {Use same flower for shadow zone:}
 SpriteN[1]:=FlowerShadow;
 SpriteX[1]:=SpriteX[0]+2; SpriteY[1]:=SpriteY[0]+2;

 Animate;
 REPEAT
  if keypressed
   THEN BEGIN
         while keypressed do ch:=upcase(readkey);
         case ch of
          ' ':BEGIN {toggle shadow mode}
               temp:=GetModeByte(FlowerShadow);
               IF temp=Display_SHADOW
                THEN SetModeByte(FlowerShadow,Display_SHADOWEXACT)
                ELSE SetModeByte(FlowerShadow,Display_SHADOW)
              END;
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
         if pos(ch,'PCIJKM+- ')>0 THEN Animate;
        END;

 UNTIL (ch='Q') OR (ch=#27);

 CloseRoutines;

END.

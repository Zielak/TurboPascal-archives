{$A+,B-,D+,L+,N-,E-,O-,R-,S-,V-,G-,F-,I-,X-}
{$M 16384,0,655360}
PROGRAM Example6;

{Another example how to use an image as a scrolling background; this time, }
{a 8x4 tile image will be used, but pasted to the same area as in the pre- }
{vious example!}
{Just for the case that you are bored, this example also shows how to "tie"}
{output of OutTextXY() and sprites to an absolute screen position (in      }
{scrolling mode, of course, because otherwise it would be trivial)...      }
{This time, a loadable font is used: FIRE.FNT. This is a colored font, so  }
{a palette FIRE.PAL will be loaded and activated previously.               }
{Make sure that the program can find all these files!!!                    }

{$X+} {to ignore results of functions}
USES ANIVGA,CRT;
CONST TileName1='BLACK.COD';     {1 black tile}
      TileName2='MARMOR.COD';    {32 tiles, captured from Win3.1 }
      tiles_per_row=8;           {These are the proportions of   }
      tiles_per_column=4;        {the above 4 tile file: 2x2!    }
      SpriteName='FLOWER.COD';   {You know that one by now...    }
      FontName='FIRE.FNT';       {Name of the (multicolored) font}
      FontPal ='FIRE.PAL';       {According palette for the font }
      FlowerLoadNumber=1;        {load number for sprite}
      Flower1=0;                 {sprite number}
      Flower2=1;                 {another one  }
      ch:Char=#0;

PROCEDURE Init;
BEGIN
 XTiles:=0; YTiles:=0;
 SetBackgroundMode(scrolling);
 SetBackgroundScrollRange(50,50,300,100);

 {paste tiles into this background, using circular enumeration}
 MakeTileArea(1,tiles_per_row,tiles_per_column);

 {load sprite:}
 IF loadSprite(SpriteName,FlowerLoadNumber)=0
  THEN BEGIN
        WRITELN('Couldn''t access file '+SpriteName+' : '+GetErrorMessage);
        halt(1)
       END;
END;

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

BEGIN
 Init;
 InitGraph;
 LoadFont(FontName); CheckFileErr(FontName);
 LoadPalette(FontPal,0,actualColors); CheckFileErr(FontPal);
 SetPalette(actualColors,TRUE);
 LoadTile(TileName1,0); {load the black tile as tile #0 = surrounding pattern}
 CheckFileErr(TileName1);
 LoadTile(TileName2,1); {load the 4 tiles as tile #1..4 = inner picture}
 CheckFileErr(TileName2);

 SetCycleTime(0); {animation as fast as possible}

 SpriteN[Flower1]:=FlowerLoadNumber;
 SpriteX[Flower1]:=0;
 SpriteY[Flower1]:=0;
 SpriteN[Flower2]:=FlowerLoadNumber;
 SpriteX[Flower2]:=StartVirtualX+100; {tie 2nd flower to absolute position}
 SpriteY[Flower2]:=StartVirtualY+100;

 Animate;
 OutTextXY(StartVirtualX+10,StartVirtualY+10,1-PAGE,'This text won''t scroll!');
 {show text the 1st time!}
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
         IF POS(ch,'IJKMESDX')>0
          THEN BEGIN {=only if something changed}
                SpriteX[Flower2]:=StartVirtualX+100;
                SpriteY[Flower2]:=StartVirtualY+100;
                Animate; 
                OutTextXY(StartVirtualX+10,StartVirtualY+10,1-PAGE,
                          'This text won''t scroll!')
               END
        END;

 UNTIL (ch='Q') OR (ch=#27);  {"Q" or ESC to quit}

 CloseRoutines;

END.

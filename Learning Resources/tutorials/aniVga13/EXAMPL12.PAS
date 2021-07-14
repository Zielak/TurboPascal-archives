{$A+,B-,D+,L+,N-,E-,O-,R-,S-,V-,G-,F-,I-,X+}
{$M 16384,0,655360}
PROGRAM Example12;
USES ANIVGA,CRT,DOS;
CONST FirstLoadNumber=1;
      FirstSpriteNumber=1;
      FONTDIR='FONT\'; {Path and name of the font directory}
      ch:CHAR=#0; {sets ch to that value everytime the program starts}
VAR i,x,y,nr:INTEGER;
    LastLoadNumber:BYTE;
    DirInfo:SearchRec;
    s,t:STRING;
    PalName:PathStr;
    tempPal:Palette;

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
 ClrScr;
 WRITELN('Please wait while I''m loading the fonts '+FONTDIR+'*.FNT...');
 WRITELN('Use I    to scroll the graphic screen; <ESC> to quit');
 WRITELN('   J K');
 WRITELN('    M');
 LastLoadNumber:=FirstLoadNumber;
 PalName:=''; {holds name of palette of (last) color font}

 FindFirst (FONTDIR+'*.FNT', Anyfile, DirInfo);
 IF DosError<>0
  THEN BEGIN
        WRITELN('Error: Couldn''t locate the font directory '+FONTDIR);
        Halt(1)
       END;
 WHILE(DosError = 0) do
  BEGIN
   WRITE(DirInfo.Name:20);
   LoadFont(FONTDIR+DirInfo.Name); CheckFileErr(DirInfo.Name);
   s:='Font '+DirInfo.Name;
   IF FontType=TagMonoFont
    THEN s:=s+' (mono, '
    ELSE BEGIN
          s:=s+' (color, ';
          PalName:=FONTDIR+Copy(DirInfo.Name,1,POS('.',DirInfo.Name))+'PAL';
          LoadPalette(PalName,0,tempPal); {get Palette}
          CheckFileErr(PalName);
         END;
   IF FontProportion=TagProportional
    THEN s:=s+'prop., ??x'
    ELSE BEGIN
          Str(FontWidth,t);
          s:=s+'fixed, '+t+'x'
         END;
   Str(FontHeight,t);
   s:=s+t+')';
(* IF FontType=TagMonoFont THEN MakeTextSprite('!',LastLoadNumber) ELSE *)
   MakeTextSprite(s,LastLoadNumber);
   INC(LastLoadNumber);
   FindNext (DirInfo);
  END;
 LoadFont(''); {switch back to internal font again}
 MakeTextSprite('Font (internal) (mono, fixed, 6x6)',LastLoadNumber);

 InitGraph;
 SetPalette(tempPal,TRUE);
 SetAnimateWindow(16,4,XMAX-4,YMAX-40);

 GraphTextColor:=LightBlue; GraphTextBackground:=GraphTextColor;
 BackgroundOutTextXY(5,WinYMAX+5,'Use I,J,K,M to scroll around, <ESC> quits!');
 BackgroundOutTextXY(5,WinYMAX+5+14,'(Note that if there is more than one '+
  'color font,');
 BackgroundOutTextXY(5,WinYMAX+5+14+8,' only the last one''s color palette '+
  'will be correct)');
 GraphTextOrientation:=vertical;
 BackgroundOutTextXY(0,0,'EXAMPL12.PAS');
 GraphTextOrientation:=horizontal;

 Color:=66;
 BackgroundLine(WinXMIN-1,WinYMIN-1,WinXMAX+1,WinYMIN-1);
 BackgroundLine(WinXMAX+1,WinYMIN-1,WinXMAX+1,WinYMAX+1);
 BackgroundLine(WinXMAX+1,WinYMAX+1,WinXMIN-1,WinYMAX+1);
 BackgroundLine(WinXMIN-1,WinYMAX+1,WinXMIN-1,WinYMIN-1);

 BackgroundLine(0,WinYMAX+1,XMAX,WinYMAX+1);
 BackgroundLine(0,YMAX,XMAX,YMAX);
 BackgroundLine(0,WinYMAX+1,0,YMAX);
 BackgroundLine(XMAX,WinYMAX+1,XMAX,YMAX);

 x:=WinXMIN+5;
 y:=WinYMIN+5;

 FOR i:=FirstLoadNumber TO LastLoadNumber DO
  BEGIN
   nr:=FirstSpriteNumber+(i-FirstLoadNumber);
   SpriteN[nr]:=i;
   SpriteX[nr]:=x; SpriteY[nr]:=y;
   INC(y,MaxFontHeight)
  END;

 Animate;
 REPEAT
  if KeyPressed
   THEN BEGIN
         WHILE KeyPressed do ch:=UpCase(ReadKey);
         CASE ch OF
          'I','E':dec(StartVirtualY,10);  {change position of whole scene with}
          'J','S':dec(StartVirtualX,10);  {E,S,D,X}
          'K','D':inc(StartVirtualX,10);
          'M','X':inc(StartVirtualY,10);
         END;
         IF POS(ch,'IJKMESDX')>0 THEN Animate;
        END;

 UNTIL (ch='Q') OR (ch=#27);

 CloseRoutines;
END.

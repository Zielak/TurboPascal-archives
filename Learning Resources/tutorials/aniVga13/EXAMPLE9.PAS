{$A+,B-,D+,L+,N-,E-,O-,R-,S-,V-,G-,F-,I-,X-}
{$M 16384,0,655360}
PROGRAM Example9;

{Demonstrates how to use the VGA's hardware scroll to do some nice opening}
{sequence: the program loads 4 graphic pages with data and then scrolls   }
{them by. Note that this erases the contents of the background and tile-  }
{page and thus cannot be done while using sprites in parallel!}

USES ANIVGA,CRT;
CONST Pic1='FRACTAL1.PIC';
      Pic2='FRACTAL2.PIC';
      Pic3='FRACTAL3.PIC';
      Pic4='FRACTAL4.PIC';
      PalName='FRACTAL.PAL';

VAR ch:CHAR;
BEGIN

 InitGraph;
 IF LoadPalette(PalName,0,actualColors)=0
  THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file '+PalName+' : '+GetErrorMessage);
        Halt
       END
  ELSE SetPalette(actualColors,TRUE);

 {--- Start Of Intro ---}
 Screen(0); {show page 0}

 {Load 4 pages with pics:}
 LoadPage(Pic1,0);
 LoadPage(Pic4,1);
 CopyVRAMtoVRAM(Ptr($A000,PAGESIZE),Ptr($A000,SCROLLPAGE*PAGESIZE),PAGESIZE);
 LoadPage(Pic3,1);
 CopyVRAMtoVRAM(Ptr($A000,PAGESIZE),Ptr($A000,BACKGNDPAGE*PAGESIZE),PAGESIZE);
 LoadPage(Pic2,1);

 IntroScroll(3*200,20); {scroll up 3 pages, wait 20ms}
 WHILE keypressed DO ch:=ReadKey; {wait for keypress}
 REPEAT UNTIL KeyPressed;

 Screen(1-page); {restore correct mode}
 {--- End Of Intro ---}

 {now do your animations as usual}
 {...}

 CloseRoutines;

END.

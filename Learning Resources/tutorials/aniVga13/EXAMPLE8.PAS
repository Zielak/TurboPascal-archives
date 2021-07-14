{$A+,B-,D+,L+,N-,E-,O-,R-,S-,V-,G-,F-,I-,X-}
{$M 16384,0,655360}
PROGRAM Example8;

{Demonstrates the several available fading routines: the program waits for}
{the user to press a key (A..Z without Q, ESC=quit), fills the visible    }
{page with a few thousand randomly distributed & colored points and then  }
{fades in the background page again, using the selected method.}
{To end the program, you have to press ESC! }

USES ANIVGA,CRT;

CONST ch:Char=#0;
VAR i,j:Integer;

BEGIN

 InitGraph;

 FOR i:=15 TO 78 DO
  BEGIN {draw some colors on the screen}
   Color:=i;
   FOR j:=(i-15)*5 TO (i-15)*5+4 DO BackgroundLine(j,0,j,YMAX)
  END;
 BackGroundOutTextXY(90,YMAX SHR 1,'Press a key (A..P,R..Z, ESC=quit)');

 Animate; {just to initialize pages, evtl. placed sprites, etc}
 REPEAT   {now for the opening sequence:}
  if keypressed
   THEN BEGIN
         while keypressed do ch:=upcase(readkey);
         if pos(ch,'ABCDEFGHIJKLMNOPRSTUVWXYZ')>0
          THEN BEGIN
                FillPage(1-PAGE,Black);
                FOR i:=1 TO 20000 DO
                 BEGIN
                  PutPixel(Random(Succ(XMAX)),Random(Succ(YMAX)),Random(256))
                 END;
                Delay(1000);
               END;
         case ch of
          'A':FadeIn(BACKGNDPAGE,2000,Fade_Squares);
          'B':FadeIn(BACKGNDPAGE,2000,Fade_Circles);
          'C':FadeIn(BACKGNDPAGE,2000,Fade_Moiree1);
          'D':FadeIn(BACKGNDPAGE,2000,Fade_Moiree2);
          'E':FadeIn(BACKGNDPAGE,2000,Fade_Moiree3);
          'F':FadeIn(BACKGNDPAGE,2000,Fade_Moiree4);
          'G':FadeIn(BACKGNDPAGE,2000,Fade_Moiree5);
          'H':FadeIn(BACKGNDPAGE,2000,Fade_Moiree6);
          'I':FadeIn(BACKGNDPAGE,2000,Fade_Moiree7);
          'J':FadeIn(BACKGNDPAGE,2000,Fade_Moiree8);
          'K':FadeIn(BACKGNDPAGE,2000,Fade_Moiree9);
          'L':FadeIn(BACKGNDPAGE,2000,Fade_Moiree10);
          'M':FadeIn(BACKGNDPAGE,2000,Fade_Moiree11);
          'N':FadeIn(BACKGNDPAGE,2000,Fade_Moiree12);
          'O':FadeIn(BACKGNDPAGE,2000,Fade_Moiree13);
          'P':FadeIn(BACKGNDPAGE,2000,Fade_Moiree14);
          'Q':BEGIN Sound(100); Delay(100); Nosound END;
          'R':FadeIn(BACKGNDPAGE,2000,Fade_SweepInFromLeft);
          'S':FadeIn(BACKGNDPAGE,2000,Fade_SweepInFromRight);
          'T':FadeIn(BACKGNDPAGE,2000,Fade_SweepInFromTop);
          'U':FadeIn(BACKGNDPAGE,2000,Fade_SweepInFromBottom);
          'V':FadeIn(BACKGNDPAGE,2000,Fade_ScrollInFromLeft);
          'W':FadeIn(BACKGNDPAGE,2000,Fade_ScrollInFromRight);
          'X':FadeIn(BACKGNDPAGE,2000,Fade_ScrollInFromTop);
          'Y':FadeIn(BACKGNDPAGE,2000,Fade_ScrollInFromBottom);
          'Z':FadeIn(BACKGNDPAGE,2000,Fade_Moiree15);
         end;
        END;
  {Your normal program would follow here!}
 UNTIL (ch=#27);

 CloseRoutines;

END.

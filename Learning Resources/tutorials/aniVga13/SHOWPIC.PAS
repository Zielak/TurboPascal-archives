{$A+,B-,D+,L+,N-,E-,O-,R-,S-,V-,G-,F-,I-,X+}
{$M 16384,0,655360}
PROGRAM ShowPIC;
USES ANIVGA,CRT;
BEGIN
 IF ParamCount=0
  THEN BEGIN
        WRITELN('Aehem, SIR, I need at least one filename...');
        Halt(1)
       END;
 InitGraph;
 SetBackgroundMode(STATIC);
 LoadBackgroundPage(ParamStr(1));
 IF Error<>Err_None
  THEN BEGIN
        CloseRoutines;
        WRITELN(GetErrorMessage);
       END
  ELSE BEGIN
        IF ParamCount=2
         THEN BEGIN {palette given, too}
               IF LoadPalette(ParamStr(2),0,actualColors)=0
                then BEGIN
                      CloseRoutines;
                      WRITELN('Couldn''t access file '+ParamStr(2)
                              +' : '+GetErrorMessage);
                      Halt
                     END
                ELSE SetPalette(actualColors,TRUE);
              END;
        Animate;
        WHILE KeyPressed DO ReadKey;
        ReadKey;
        CloseRoutines
       END;
END.

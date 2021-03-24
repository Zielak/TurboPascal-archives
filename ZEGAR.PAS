USES Graph, Dos, crt;

CONST
    Sx : Integer = 320;
    Sy : Integer = 240;

    DlM = 100;
    DlH = 80;
    DlS = 90;

    GM = 1;
    GH = 3;
    GS = 1;



VAR
  h, m, s, ss : Word;
  sse         : Word;
  i           : Integer;


  grDriver: Integer;
  grMode: Integer;
  ErrCode: Integer;

FUNCTION IntToStr(i:Integer):STRING;
VAR s:STRING;
BEGIN
 Str(i, s);
 IF (i<10) THEN s:='0'+s;
 IntToStr:=s;
END;


BEGIN

 grDriver :=Detect;
 InitGraph(grDriver, grMode,'C:\TP\BGI');
 ErrCode := GraphResult;
 if ErrCode = grOk then
 begin  { Do graphics }

   WHILE (PORT[$60]<>1) DO
   BEGIN

     GetTime(h, m, s, ss);
     IF (s<>sse) THEN
     BEGIN
       ClearDevice;
       SetColor(10);
       OutTextXY(560, 460, IntToStr(h)+':'+IntToStr(m)+':'+IntToStr(s));
       SetColor(7);
       SetFillStyle(1, 8);
       FillEllipse(Sx, Sy, DlM+20, DlM+20);

       FOR i:=1 TO 60 DO
       BEGIN
         IF (i MOD 5<>0) THEN SetLineStyle(0, $FF, 1) ELSE SetLineStyle(0, $FF, 3);
         SetColor(7);
         Line(Sx+Round(Sin((540-i*6)*(PI/180))*(DlM+12)), Sy+Round(Cos((540-i*6)*(PI/180))*(DlM+12)),
              Sx+Round(Sin((540-i*6)*(PI/180))*(DlM+18)), Sy+Round(Cos((540-i*6)*(PI/180))*(DlM+18)));

       END;


       sse := s;

       SetColor(15);
       SetLineStyle(0, $FF, GH);
       Line(Sx, Sy, Sx+Round(Sin((540-h*30)*(PI/180))*DlH), Sy+Round(Cos((540-h*30)*(PI/180))*DlH));

       SetColor(9);
       SetLineStyle(0, $FF, GM);
       Line(Sx, Sy, Sx+Round(Sin((540-m*6)*(PI/180))*DlM), Sy+Round(Cos((540-m*6)*(PI/180))*DlM));

       SetColor(12);
       SetLineStyle(0, $FF, GS);
       Line(Sx, Sy, Sx+Round(Sin((540-s*6)*(PI/180))*DlS), Sy+Round(Cos((540-s*6)*(PI/180))*DlS));


     END;

   END;

   CloseGraph;
 end
 else
   Writeln('Graphics error:', GraphErrorMsg(ErrCode));
   repeat until keypressed;


END.
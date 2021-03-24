{$N+}
PROGRAM Organki;
USES Crt;
CONST MaxNut=20;
     FirstK1 = 16;
     FirstK2 = 2;
     C       = 538;
     D       = 615;
VAR
 Temp  : Single;
 Temp2 : Single;
 Temp3 : Single;

 Tab:ARRAY [0..MaxNut] OF Word;

PROCEDURE Generate;
VAR i:Integer;
BEGIN
 Temp:=D;
 Temp2:=C;

 FOR i:=0 TO MaxNut DO
 BEGIN
   Temp3:=Temp+(Temp-Temp2)*65/71;
   Temp2:=Temp;Temp:=Temp3;
   Tab[i]:=Round(Temp);
 END;
END;


BEGIN
 Generate;
 REPEAT
   Sound(Tab[PORT[$60]-FirstK1]);
   IF KeyPressed THEN ReadKey;
   IF PORT[$60]>127 THEN NoSound;
 UNTIL PORT[$60]=1;
END.
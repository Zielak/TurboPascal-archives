program kolorki;

uses Crt;


var
   i,j,a : integer;
   kol : array[0..2] of integer;
   tla : array[0..2] of integer;


begin
     clrscr;
     i:=0;
     a:=0;
     kol[0]:=1;
     kol[1]:=2;
     kol[2]:=3;
     tla[0]:=2;
     tla[1]:=3;
     tla[2]:=1;
     HighVideo;
     for i:=1 to 25 do
     Begin
           for j:=1 to 25 do
           begin
           a:=a+1;
           if a>3 then a:=1;
           TextColor(kol[a]);
           TextBackground(tla[a]);
           Write('Û');
           writeln('');
           End;
     End;
     read(j);

end.



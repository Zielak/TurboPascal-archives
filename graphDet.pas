program detekcja;

uses graph,crt;

var i,x,y,maxcol : integer;
Karta, Tryb : Integer;

begin
clrscr;

{DetectGraph(Karta,Tryb);}
Karta:=9;
Tryb:=2;
InitGraph(Karta,Tryb,'c:\tp\bgi');

x:= getmaxx+1;
y:= getmaxy+1;
maxcol:=getmaxcolor+1;

CloseGraph;
writeln('Sterownik graficzny numer: ',Karta);
writeln('Tryb : ',Tryb);
writeln('Rozdzielczosc: ',x,' X ',y);
writeln('Max kolorow: ',maxcol);
repeat until keypressed;


end.
uses crt;

var arr:array[0..40,0..10] of longint;
    maxw,maxk:integer;




procedure start;
begin


repeat
if maxk>10 then begin
gotoXY(20,10);
textcolor(red);
write('Kolumna nie moze byc kolumn od 10!');
textcolor(black)
end;
gotoXY(2,5);
write('Wpisz maxymalna liczbe kolumn w tablicy: ');
read(maxk);
until maxk<=10;
gotoXY(20,10);
write('                                   ');


repeat
if maxw>40 then begin
gotoXY(20,10);
textcolor(red);
write('Kolumna nie moze byc wieksza od 40!');
textcolor(black)
end;
gotoXY(2,8);
write('Wpisz maxymalna liczbe wierszy w tablicy: ');
read(maxw);
until maxw<=40;
gotoXY(20,10);
write('                                   ');

clrscr;

end;


procedure a;
var w,k:word;
    lol:longint;
    menu:char;
begin

k:=0;
w:=0;

repeat

repeat
if w>40 then begin
gotoXY(20,5);
textcolor(red);
write('Kolumna nie moze byc wieksza od 40!');
textcolor(black)
end;
gotoXY(25,7);
write('Wpisz pozycje wiersza: ');
readln(w);
until w<=40;

gotoXY(20,3);
write('                                  ');

repeat
if k>10 then begin
gotoXY(20,5);
textcolor(red);
write('Wiersz nie moze byc wiekszy od 10!');
textcolor(black)
end;
gotoXY(25,8);
write('Wpisz pozycje kolumny: ');
readln(k);
until k<=10;

gotoXY(20,3);
write('                                  ');

gotoXY(22,9);
write('Wpisz wartosc w komorke: ');
readln(lol);

arr[k,w]:=lol;

gotoXY(22,12);
write('Wpisac kolejna komorke?');
gotoXY(22,13);
write('( spacje by zakonczyc )');

menu:=readkey;
until (Ord(menu) = 32);;

clrscr;
end;


procedure b;
var k,w:word;
begin
clrscr;

{ GORNA LEGENDA }
for k:=0 to maxk do begin
gotoXY(k*5+11,5);
writeln('|',k);
end;

{ BOCZNA LEGENDA }
for w:=0 to maxw do begin
gotoXY(12,w+6);
write('|');
gotoXY(7,w+6);
writeln(w);
end;

{ WYPELNIENIE }
for k:=0 to maxk do
    for w:=0 to maxw do begin
        gotoXY(k*5+12,w+6);
        writeln(arr[w,k]);
end;


end;





begin
TextMode(C80 + Font8x8);
textbackground(white);
textcolor(black);
clrscr;


writeln('            Program sluzy do operacji na tablicach 2-wymiarowych');
start;
a;
b;

repeat until keypressed;

end.
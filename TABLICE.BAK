program tabliceere;

uses crt;

var
ar:Array[0..100] of integer;
max:byte;
menu:integer;
key:char;


procedure zapis;
var i:integer;
int:integer;
begin
{ ILE MAX }
repeat
writeln('Wprowadz maxymalna liczbe danych do wprowadzenia w tablice');
readln(max);
until max<=100;
{ PO KOLEI }
i:=0;
repeat
write('ar[',i,'] = ');
readln(int);
ar[i]:=int;
i:=i+1;
until i>=max;
end;


procedure odczyt;
var i:byte;
begin
Writeln('[=- Wartosci w tablicy -=]');
for i:=0 to max-1 do
begin
     writeln('ar[',i,'] = ',ar[i]);
     repeat
     until keypressed;
end;
writeln;
writeln('Wcisnij klawisz aby zakonczyc');
repeat
until keypressed;

end;



procedure inwersja;
var i:byte;
begin
Writeln('[=- Wartosci w tablicy -=]');
for i:=max-1 downto 0 do
begin
     writeln('ar[',i,'] = ',ar[i]);
     delay(250);
end;
writeln;
writeln('Wcisnij klawisz aby zakonczyc');
repeat
until keypressed;

end;



procedure konkret;
var
int:integer;
war:integer;
begin
write('ar[');
read(int);
write('] = ');
read(war);
ar[int]:=war;
writeln('Zapisano!');
end;


procedure suma;
var
i:integer;
sum:integer;
begin
sum:=0;
for i:=0 to max-1 do
begin
     sum:=sum+ar[i];
end;
end;



procedure srednia;
var
i:integer;
sr:integer;
all:real;
begin
sr:=0;
for i:=0 to max-1 do
begin
     sr:=sr+ar[i];
end;
all:=sr/(max-1);
writeln('Srednia wynosi ',all:2:2);
end;








procedure koniec;
begin
writeln('Wcisnij spacje aby zakonczyc');
writeln('Jaki kolwiek inny klawisz aby powtorzyc program');





BEGIN

repeat

clrscr;

{ MENU }

writeln('wybierz funkcje..');
writeln;
writeln('____________________________________');
writeln('|                                  |');
writeln('|- 1 Wyczyszczenie tablicy i       |');
writeln('|    wprowadzenie nowych wartosci  |');
writeln('|- 2 Wyprowadzenie calej tablicy   |');
writeln('|- 3 Wyprowadzenie tablicy w       |');
writeln('|    odwrotnej kolejnosci          |');
writeln('|- 4 Nadpis konkretnej wartosci    |');
writeln('|- 5 Obliczenie sumy calej         |');
writeln('|-   tablicy                       |');
writeln('|- 6 Obliczenie sredniej calej     |');
writeln('|    tablicy                       |');
writeln('|- 7 Sprawdzenie istnienia danego  |');
writeln('|    elementu w tablicy            |');
writeln('|__________________________________|');
readln(menu);

case menu of
     1:zapis;
     2:odczyt;
     3:inwersja;
     4:konkret;
     5:suma;
     6:srednia;
     {7:szukaj;}
else
    koniec;
end;


key := Readkey;

until (Ord(key) = 32);


END.
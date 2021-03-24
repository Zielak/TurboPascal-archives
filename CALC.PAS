unit calc;

interface

var i:byte;
    c:char;

procedure menuglowne;

procedure plus;
procedure minus;
procedure dziel;
procedure mnozenie;
procedure pierwiastek;
procedure modulo;
procedure divide;
procedure kwadrat;




implementation

uses crt;

procedure menuglowne;
begin

TextMode(BW80 + Font8x8);
textcolor(yellow);
textbackground(red);

repeat
clrscr;

writeln(' ---- KALKULATOROROR -------');
writeln('|                           |');
writeln('| 1 - dodawanie       [ + ] |');
writeln('| 2 - odejmowanie     [ - ] |');
writeln('| 3 - dzielenie       [ / ] |');
writeln('| 4 - mnozenie        [ * ] |');
writeln('| 5 - pierwiastkowanie      |');
writeln('| 6 - modulo                |');
writeln('| 7 - dzielenie calkowitych |');
writeln('| 8 - potega stopnia 2      |');
writeln('|                           |');
writeln('| Q - wyjscie z programu    |');
writeln('|                           |');
writeln(' ---------------------------');

c:=readkey;

case c of
'1':plus;
'2':minus;
'3':dziel;
'4':mnozenie;
'5':pierwiastek;
'6':modulo;
'7':divide;
'8':kwadrat;
end;

until c='q';

if c='q' then halt;

end;


procedure plus;
var a,b,w:real;
begin
clrscr;
writeln(' [ DODAWANIE ]');
writeln;
write('podaj pierwsza liczbe: ');
readln(a);
write('podaj liczbe druga: ');
readln(b);
writeln;
w:=a+b;
writeln(a:2:2,' + ',b:2:2,' = ',w:2:2);

c:=readkey;

end;


procedure minus;
var a,b,w:real;
begin
clrscr;
writeln(' [ ODEJMOWANIE ]');
writeln;
write('podaj pierwsza liczbe: ');
readln(a);
write('podaj liczbe druga: ');
readln(b);
writeln;
w:=a-b;
writeln(a:2:2,' - ',b:2:2,' = ',w:2:2);

c:=readkey;

end;



procedure dziel;
var a,b,w:real;
begin
clrscr;
writeln(' [ DZIELENIE ]');
writeln;
write('podaj pierwsza liczbe: ');
readln(a);
write('podaj liczbe druga: ');
readln(b);
writeln;
w:=a/b;
writeln(a:2:2,' / ',b:2:2,' = ',w:2:2);

c:=readkey;

end;


procedure mnozenie;
var a,b,w:real;
begin
clrscr;
writeln(' [ MNOZENIE ]');
writeln;
write('podaj pierwsza liczbe: ');
readln(a);
write('podaj liczbe druga: ');
readln(b);
writeln;
w:=a*b;
writeln(a:2:2,' * ',b:2:2,' = ',w:2:2);

c:=readkey;

end;



procedure pierwiastek;
var a:real;
begin
clrscr;
writeln(' [ PIERWIASTEK ]');
writeln;
write('podaj liczbe: ');
readln(a);
writeln;
writeln('pierwiastek z ',a:2:2,' = ',sqrt(a):2:2);

c:=readkey;

end;



procedure modulo;
var a,b:longint;
begin
clrscr;
writeln(' [ MODULO ]');
writeln;
write('podaj pierwsza liczbe: ');
readln(a);
write('podaj liczbe druga: ');
readln(b);
writeln;
writeln(a,' mod ',b,' = ',a mod b);

c:=readkey;

end;



procedure divide;
var a,b:longint;
begin
clrscr;
writeln(' [ DZIELENIE CALKOWITE ]');
writeln;
write('podaj pierwsza liczbe: ');
readln(a);
write('podaj liczbe druga: ');
readln(b);
writeln;
writeln(a,' div ',b,' = ',a div b);

c:=readkey;

end;



procedure kwadrat;
var a,b,w:real;
begin
clrscr;
writeln(' [ POTEGA STOPNIA 2 ]');
writeln;
write('podaj liczbe: ');
readln(a);
writeln;
w:=a*a;
writeln(a:2:2,'^2 = ',w:2:2);

c:=readkey;

end;


END.
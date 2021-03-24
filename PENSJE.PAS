program pensjeipierdoly;

uses crt,klasa2f;

var k:char;

label 1;

begin


textmode(CO80 + font8x8);
highvideo;
textcolor(white);

1:

clrscr;
gotoxy(30,20);
writeln('[1] Pensja');
gotoxy(30,21);
writeln('[2] Dniowki');
gotoxy(30,22);
writeln('[3] Godziny');
gotoxy(30,23);
writeln('[Q] Koniec');

k:=readkey;

clrscr;

case k of
'1':pensja;
'2':dniowki;
'3':godziny;
'q':halt;
end;


goto 1;

end.
unit klasa2f;



interface

procedure pensja;
procedure dniowki;
procedure godziny;




implementation

uses crt;

procedure pensja;
var i,j:single;
begin
  write('Pytam o pensje: ');
  readln(i);
  j:=i;

  if i<800 then i:=i+100
  else
  if i<2800 then i:=i-(0.19*i)
  else i:=i-(0.25*i);
  writeln;
  writeln('Netto = ',i:2:2);
  writeln('Brutto = ',j:2:2);
  repeat until keypressed;
end;


procedure dniowki;
var d:word;
    i,j:single;
begin
  write('Pytam o stawke: ');
  readln(i);
  j:=i;
  write('Pytam o ilosc dni: ');
  readln(d);

  if d>25 then i:=(i*25*(d-25)*1.5*i)*0.8
  else i:=i*d*0.8;

  writeln;
  writeln('Dniowka brutto = ',i:2:2);
  writeln('Dniowka netto = ',j:2:2);
  repeat until keypressed;
end;


procedure godziny;
var i,j:single;
    g:word;
begin
  write('Pytam o stawke: ');
  readln(i);
  write('Pytam o ilosc godzin: ');
  readln(g);

  if g>160 then i:=(i*160)+(1.8*i*(g-160))
  else
  i:=i*g;
  j:=i-i*0.15;
  writeln;
  writeln('Brutto = ',i:2:2);
  writeln('Netto = ',j:2:2);
  repeat until keypressed;
end;


end.
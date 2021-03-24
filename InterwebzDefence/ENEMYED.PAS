program enemyed;

uses zvga,crt;


type
  (*point = record
    x,y:integer;
  end;
  poly = array[0..40] of point;

  enemypoly = record
    pol:poly;
    c,i:byte;           { kolor polygona i ilosc punktow }
  end;*)

  enemyfunc = record
    x1,y1,x2,y2,r:shortint;
    typ,c:byte;
  end;

  enemy = record
    exist:boolean;
    x,y:word;
    hp:byte;
    maxpoints:integer;
    xs,ys:single;
    {part1,part2,part3:enemypoly;}
    func1,func2,func3,func4,func5,func6:enemyfunc;
    r:byte;     { wielkosc }
  end;

  enemyfile = file of enemy;

var
  emptyp:point;
  en,epmt:enemy;
  patch,name:string;
  f0:enemyfile;
  k,b:char;    x




procedure textmodeint;
begin
HighVideo;
TextMode(C80 + Font8x8);
textcolor(black);
textbackground(white);
end;


procedure clear;
begin
clrscr;

writeln;
writeln('----- Edytor przeciwnikow do InterwebzDefence ---------');
writeln;
writeln;
end;




procedure saveit;
begin
seek(f0, 0);
write(f0, en);
writeln('Zapisano...');
delay(150);
end;







procedure clearenemy;
var i:byte;

procedure clearfunc(enf:enemyfunc);
begin
  enf.x1:=0;
  enf.x2:=0;
  enf.y1:=0;
  enf.y2:=0;
  enf.r:=0;
  enf.c:=0;
  enf.typ:=0;
end;

begin
en.hp:=0;
en.maxpoints:=0;
en.xs:=0;
en.ys:=0;
clearfunc(en.func1);
clearfunc(en.func2);
clearfunc(en.func3);
clearfunc(en.func4);
clearfunc(en.func5);
clearfunc(en.func6);
emptyp.x:=0;
emptyp.y:=0;
{
for i:=0 to 40 do begin
en.part1.pol[i]:=emptyp;
en.part2.pol[i]:=emptyp;
en.part3.pol[i]:=emptyp;
end;
en.part1.c:=0;
en.part2.c:=0;
en.part3.c:=0;
en.part1.i:=0;
en.part2.i:=0;
en.part3.i:=0;
}
end;




procedure editor;
var k,l,m:char;
    en:enemy;


  procedure drawEnemy;
  var i:byte;
      c:char;
      x,y:word;
      polyg:poly;

  procedure drawFunc(enf:enemyfunc);
  begin
    case enf.typ of
     1: box(enf.x1+x,
            enf.x2+x,
            enf.y1+y,
            enf.y2+y,
            enf.c,
            true);
     2: circlefill(enf.x1+x,
            enf.x2+y,
            enf.r,
            enf.c);
     3: elipsa(enf.x1+x,
            enf.x2+y,
            enf.y1,
            enf.y2,
            enf.c);
     4: line(enf.x1+x,
            enf.y1+y,
            enf.x2+x,
            enf.y2+y,
            enf.c);
    end;
  End;

  Begin
    x:=maxx div 2;
    y:=maxy div 2;


    drawFunc(en.func1);
    drawFunc(en.func2);
    drawFunc(en.func3);
    drawFunc(en.func4);
    drawFunc(en.func5);
    drawFunc(en.func6);

    initvga;
    cls(0);
    drawpage;


    c:=readkey;

    closevga;
    textmodeint;
    writeln('Zakonczono prezentacje...');
    delay(750);
    m:='n';
  end;



  procedure pisz(d:byte;c:string);
  begin
  write('| ',d,' ',c);
  gotoxy(67,wherey);
  writeln('|');
  end;

  procedure piszfunc(enf:enemyfunc);
  begin
    write('| func1(x1:',enf.x1
                 ,'; y1:',enf.y1
                 ,'; x2:',enf.x2
                 ,'; y2:',enf.y2
                 ,'; r:',enf.r
                 ,'; c:',enf.c
                 ,'; typ:',enf.typ
                 ,');');
  end;

  procedure piszw(i:byte);
  begin

  reset(f0);
  seek(f0, 0);
  case i of
  1:write('| hp = ',en.hp);
  2:write('| maxpoints = ',en.maxpoints);
  3:write('| xs = ',en.xs);
  4:write('| ys = ',en.ys);
  5:piszfunc(en.func1);
  6:piszfunc(en.func2);
  7:piszfunc(en.func3);
  8:piszfunc(en.func4);
  9:piszfunc(en.func5);
  10:piszfunc(en.func6);
  end;
  gotoxy(67,wherey);
  writeln('|');
  end;


  procedure funcpars(id:byte);
  var func:enemyfunc;
  begin
  writeln('jezeli dana funkcja parametru nie obsluguje wpisz 0');
  writeln;
  write('typ (1-box,2-circlefill,3-elipsa,4-line) = ');readln(func.typ);
  write('x1 = ');readln(func.x1);
  write('y1 = ');readln(func.y1);
  write('x2 = ');readln(func.x2);
  write('y2 = ');readln(func.y2);
  write('r = ');readln(func.r);
  write('c = ');readln(func.c);

  case i of
  1:en.func1:=func;
  2:en.func2:=func;
  3:en.func3:=func;
  4:en.func4:=func;
  5:en.func5:=func;
  6:en.func6:=func;
  end;

  piszw(5);
  readln;
  saveit;
  end;

  {
  procedure polypars(polt:enemypoly);
  var i:byte;
      q:char;
  begin

  writeln('Wyczyscic polygon (t/n)?');
  q:=readkey;
  if q='t' then begin
    polt.i:=0;
    polt.c:=0;
    for i:=0 to 40 do begin
      polt.pol[i].x:=0;
      polt.pol[i].y:=0;
    end;
  end
  else begin
    write('pol.c (',polt.c,') :=');
    read(polt.c);

    for i:=0 to 40 do begin
      write('pol[',i,'].x (',polt.pol[i].x,') :=');
      read(polt.pol[i].x);
      write('pol[',i,'].y (',polt.pol[i].y,') :=');
      read(polt.pol[i].y);
      if i>1 then begin
        writeln('polygon ma ',i,' punktow, koniec?');
        q:=readkey;
        if q='t' then begin
          polt.i:=i;
          exit;
        end;
      end;
    end;

  end;

  End;
  }

  procedure showedit;

  procedure piszfunc(enf:enemyfunc;id:byte);
  begin
    writeln('func',id,'(x1:',enf.x1
           ,'; y1:',enf.y1
           ,'; x2:',enf.x2
           ,'; y2:',enf.y2
           ,'; r:',enf.r
           ,'; c:',enf.c
           ,'; typ:',enf.typ
           ,');');
    funcpars(id);
  end;

  begin

  repeat

  clear;
  writeln('Przeciwnik: ',name);
  writeln;

  writeln(' ---------------------------- Parametr --------------------------- ');
  writeln('|                                                                 |');
  pisz(1,'hp-zycie');
  pisz(2,'maxpoints-Max punktow za zbicie');
  pisz(3,'xs - szybkosc x (normalnie 0)');
  pisz(4,'ys - szybkosc y (normalnie 0.2 chyba)');
  pisz(5,'func1  < czesci enemy w postaci funkcji');
  pisz(6,'func2  < pomoc w pliku "funkcje graficzne"   ');
  pisz(7,'func3  < typ: 1-box (x1,y1,x2,y2)            ');
  pisz(8,'func4  <    2-circlefill (x1,y1,r)           ');
  pisz(9,'func5  <    3-elipse (x1,y1, x2(a), y2(b))   ');
  pisz(0,'func6  <    4-line (x1,y1,x2,y2)             ');
  writeln('|                                                                 |');
  writeln('| [Q] wyjdz                                                       |');
  writeln('|                                                                 |');
  writeln(' ----------------------------------------------------------------- ');
  writeln;
  l:=readkey;

  case l of
  '1':begin write('hp (byte) = ');readln(en.hp); end;
  '2':begin write('maxpoints (integer) = ');readln(en.maxpoints); end;
  '3':begin write('xs (single (mniejsze real)) = ');readln(en.xs); end;
  '4':begin write('ys (single (mniejsze real)) = ');readln(en.ys); end;
  '5':piszfunc(en.func1,1);
  '6':piszfunc(en.func2,2);
  '7':piszfunc(en.func3,3);
  '8':piszfunc(en.func4,4);
  '9':piszfunc(en.func5,5);
  '0':piszfunc(en.func6,6);
  'q':m:='n';
  end;

  saveit;

  until m='n';

  End;


  procedure showview;
  begin
  clear;
  writeln('Przeciwnik: ',name);
  writeln;
  seek(f0, 0);
  reset(f0);
  seek(f0, 0);
  read(f0, en);
  writeln(' ---------------------------- Parametry -------------------------- ');
  writeln('|                                                                 |');
  piszw(1);
  piszw(2);
  piszw(3);
  piszw(4);
  piszw(5);
  piszw(6);
  piszw(7);
  piszw(8);
  piszw(9);
  piszw(10);
  writeln('|                                                                 |');
  writeln(' -----------------------------------------------------------------');

  while keypressed do readkey;
  m:='n';
  end;

begin

repeat

clear;
writeln('Przeciwnik: ',name);
writeln;
writeln(' ------------ EDYTOR GLOWNY ----------');
writeln('|                                     |');
writeln('| [1] Edytuj                          |');
writeln('| [2] Wyswietl parametry              |');
writeln('| [3] Prezentacja w trybie graficznym |');
writeln('| [0] Wyczysc caly plik               |');
writeln('|                                     |');
writeln(' -------------------------------------');
k:=readkey;

repeat

if k='1' then showedit
else
if k='2' then showview
else
if k='0' then begin
clear;
writeln('Przeciwnik: ',name);
writeln;
clearenemy;
writeln('Czyszczenie...');
saveit;
writeln('Wyczyszczono, wcisnij (N)...');
m:=readkey;
end
else
if k='3' then drawenemy;

until m='n';


writeln('Wroc do edytora? (t/n)');
writeln('N - zapisanie i wyjscie do menu glownego');
m:=readkey;



until m='n';

saveit;
close(f0);

end;





procedure quit;
begin
clear;
writeln('Zamykanie...');
delay(750);
halt;
end;


procedure pick;
begin
clear;
write('Wprowadz nazwe przeciwnika: ');
readln(name);

assign(f0,'F:\INTERW~1\img\'+name+'.dat');
end;

procedure load;
var tmp,j:string;
begin
pick;
seek(f0, 0);
reset(f0);
seek(f0, 0);
read(f0, en);
editor;
end;

procedure neww;
begin
pick;
rewrite(f0);
seek(f0, 0);
clearenemy;
saveit;
seek(f0, 0);
editor;
end;

procedure menu;
begin
writeln(' -----[ MENU ]----- ');
writeln('|                  |');
writeln('| [1] Nowy         |');
writeln('| [2] Laduj        |');
writeln('|                  |');
writeln('| [0] Koniec       |');
writeln('|                  |');
writeln(' ------------------');
writeln;
writeln('pliki sie beda zapisywac po wyjsciu z edycji, czyli do tego menu');
k:=readkey;
case k of
'1': neww;
'2': load;
'0': quit;
end;

end;






begin

textmodeint;

repeat

clear;
menu;





clear;

until b='n';

end.

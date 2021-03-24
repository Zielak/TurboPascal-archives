{$N+}
uses zvga,crt;

type
  enemyfunc = record
    x1,y1,x2,y2,r:shortint;
    typ,c:byte;
  end;

  enemy = record
    exist:boolean;
    x,y:single;
    hp:byte;
    maxpoints:integer;
    xs,ys:single;
    func1,func2,func3,func4,func5,func6:enemyfunc;
    r:byte;     { wielkosc }
  end;

  enemyfile = file of enemy;

var
  emptyp:point;
  en:enemy;
  patch,name:string;
  f0:enemyfile;



procedure textmodeint;
begin
HighVideo;
TextMode(C80 + Font8x8);
textcolor(black);
textbackground(white);
end;





procedure saveit;
begin
seek(f0, 0);
write(f0, en);
close(f0);
reset(f0);
seek(f0, 0);
writeln('Zapisano...');
delay(20);
end;



procedure clearenemy;
var i:byte;

 procedure clearfunc(id:byte);
 var enf:enemyfunc;
 begin
  enf.x1:=0;
  enf.x2:=0;
  enf.y1:=0;
  enf.y2:=0;
  enf.r:=0;
  enf.c:=0;
  enf.typ:=0;

  case id of
      1:begin en.func1:=enf;write('func1 ');end;
      2:begin en.func2:=enf;write('func2 ');end;
      3:begin en.func3:=enf;write('func3 ');end;
      4:begin en.func4:=enf;write('func4 ');end;
      5:begin en.func5:=enf;write('func5 ');end;
      6:begin en.func6:=enf;write('func6 ');end;
  end;
  saveit;
 end;

begin
en.exist:=false;
en.x:=0;
en.y:=0;
en.hp:=0;
en.maxpoints:=0;
en.xs:=0;
en.ys:=0;
en.r:=0;
clearfunc(1);
clearfunc(2);
clearfunc(3);
clearfunc(4);
clearfunc(5);
clearfunc(6);
emptyp.x:=0;
emptyp.y:=0;
write('calosc ');
saveit;
clrscr;
end;



procedure drawEnemy;
var i:byte;
    c:char;
    x,y,gy,gx:word;

  procedure drawFunc(id:byte);
  var enf:enemyfunc;
  begin

  case id of
      1:enf:=en.func1;
      2:enf:=en.func2;
      3:enf:=en.func3;
      4:enf:=en.func4;
      5:enf:=en.func5;
      6:enf:=en.func6;
  end;

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

initvga;

setColor(0,10,10,10);

cls(0);

x:=maxx div 2;
y:=maxy div 2;



setColor(6,20,20,20);
setColor(7,25,25,25);
setColor(8,35,35,35);
setColor(9,45,45,45);
{ PALETA PRZECIWNIKOW }
{ red }
setcolor(10,30,0 ,0 );
setcolor(11,63,0 ,0 );
setcolor(12,63,34,34);
{ orange }
setcolor(13,30,18,0 );
setcolor(14,63,40,0 );
setcolor(15,63,48,34);
{ yellow }
setcolor(16,30,30,0 );
setcolor(17,63,63,0 );
setcolor(18,63,63,34);
{ lime }
setcolor(19,18,30,0 );
setcolor(20,40,63,0 );
setcolor(21,48,63,34);
{ green }
setcolor(22,0 ,30,0 );
setcolor(23,0 ,63,0 );
setcolor(24,34,63,64);
{ bluegreen }
setcolor(25,0 ,30,18);
setcolor(26,0 ,63,40);
setcolor(27,34,63,48);
{ lightblue }
setcolor(28,0 ,30,30);
setcolor(29,0 ,63,63);
setcolor(30,34,63,63);
{ blue }
setcolor(31,0 ,0 ,30);
setcolor(32,0 ,0 ,63);
setcolor(33,34,34,63);
{ violet }
setcolor(34,18,0 ,30);
setcolor(35,40,0 ,63);
setcolor(36,48,34,63);
{ pink }
setcolor(37,30,0 ,30);
setcolor(38,63,0 ,63);
setcolor(39,63,34,63);
{ black }
setcolor(40,0 ,0 ,0 );
setcolor(41,18,18,18);
setcolor(42,30,30,30);
setcolor(43,48,48,48);
setcolor(44,63,63,63);

VGAText(20,20,29,'enemy:',0);
VGAText(70,20,29,name,0);


{ DZIALO }
gx:=160;
gy:=192;
line(gx, gy, gx+3, gy-20, 6);
line(gx+3, gy-20, gx-3, gy-20, 6);
line(gx-3, gy-20, gx, gy, 6);

circlefill(gx, gy, 9, 7);
circlefill(gx+2, gy-2, 6, 8);
circlefill(gx+4, gy-3, 4, 9);
box(gx-9, gx+9, gy+3, gy+8, 7, true);
box(gx-2, gx+9, gy+3, gy+7, 8, true);
box(gx+2, gx+9, gy+3, gy+6, 9, true);
box(gx-9, gx+9, gy+3, gy+8, 6, false);



drawFunc(1);
drawFunc(2);
drawFunc(3);
drawFunc(4);
drawFunc(5);
drawFunc(6);
box(x-en.r,x+en.r,y-en.r,y+en.r,42,false);

drawpage;


c:=readkey;

closevga;
textmodeint;
clrscr;

writeln('Zakonczono prezentacje...');
delay(750);
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
    3:write('| xs = ',en.xs:2:2);
    4:write('| ys = ',en.ys:2:2);
    5:write('| r = ',en.r);
    6:piszfunc(en.func1);
    7:piszfunc(en.func2);
    8:piszfunc(en.func3);
    9:piszfunc(en.func4);
    10:piszfunc(en.func5);
    11:piszfunc(en.func6);
  end;
  gotoxy(67,wherey);
  writeln('|');
end;







procedure editor;
var k:char;

  procedure edit;

  procedure funcpars(id:byte);
  var func:enemyfunc;
  begin
    case id of
      1:func:=en.func1;
      2:func:=en.func2;
      3:func:=en.func3;
      4:func:=en.func4;
      5:func:=en.func5;
      6:func:=en.func6;
    end;

    writeln('jezeli dana funkcja parametru nie obsluguje wpisz 0');
    writeln;
    write('typ (1-box,2-circlefill,3-elipsa,4-line) (',func.typ,')= ');readln(func.typ);
    write('x1 (',func.x1,')= ');readln(func.x1);
    write('y1 (',func.y1,')= ');readln(func.y1);
    write('x2 (',func.x2,')= ');readln(func.x2);
    write('y2 (',func.y2,')= ');readln(func.y2);
    write('r (',func.r,')= ');readln(func.r);
    write('c (',func.c,')= ');readln(func.c);

    case id of
      1:en.func1:=func;
      2:en.func2:=func;
      3:en.func3:=func;
      4:en.func4:=func;
      5:en.func5:=func;
      6:en.func6:=func;
    end;

    saveit;
  end;


  procedure piszfunc(enf:enemyfunc;id:byte);
  begin
    writeln;
    writeln('-----------------------------------');
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

  BEGIN

  repeat
  clrscr;
  write('wstepnie ');saveit;
  writeln;
  writeln('Przeciwnik: ',name);
  writeln;

  writeln(' --------------------------- Parametry --------------------------- ');
  writeln('|                                                                 |');
  writeln('| 1 hp-zycie');
  writeln('| 2 maxpoints-Max punktow za zbicie');
  writeln('| 3 xs - szybkosc x (normalnie 0)');
  writeln('| 4 ys - szybkosc y (normalnie 0.2 chyba)');
  writeln('| 5 r - bok boxa kolizji, czyli niewidzialne pudlo w ktore trafia pocisk');
  writeln('| 6 func1  < czesci enemy w postaci funkcji');
  writeln('| 7 func2  < pomoc w pliku "funkcje graficzne"   ');
  writeln('| 8 func3  < typ: 1-box (x1,y1,x2,y2)            ');
  writeln('| 9 func4  <    2-circlefill (x1,y1,r)           ');
  writeln('| 0 func5  <    3-elipse (x1,y1, x2(a), y2(b))   ');
  writeln('| - func6  <    4-line (x1,y1,x2,y2)             ');
  writeln('|                                                                 |');
  writeln('| Q wyjscie                                                       |');
  writeln('|                                                                 |');
  writeln(' ----------------------------------------------------------------- ');
  writeln;
  k:=readkey;

  case k of
  '1':begin write('hp (byte) (',en.hp,')= ');readln(en.hp);end;
  '2':begin write('maxpoints (integer) (',en.maxpoints,')= ');readln(en.maxpoints);end;
  '3':begin write('xs (real) (',en.xs:2:2,')= ');readln(en.xs);end;
  '4':begin write('ys (real) (',en.ys:2:2,')= ');readln(en.ys);end;
  '5':begin write('r (byte) (',en.r,')= ');readln(en.r);end;
  '6':piszfunc(en.func1,1);
  '7':piszfunc(en.func2,2);
  '8':piszfunc(en.func3,3);
  '9':piszfunc(en.func4,4);
  '0':piszfunc(en.func5,5);
  '-':piszfunc(en.func6,6);
  end;


  until k='q';
  write('po edycji ');saveit;

  end;


  procedure show;
  var h:char;
  begin
  clrscr;
  writeln;
  write('odswiezono, ');saveit;
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
  writeln;
  writeln('wcisnij 1 by kontynuowac');
  repeat h:=readkey until h='1';

  end;

begin

repeat

writeln(' ------------ EDYTOR GLOWNY ----------');
writeln('|                                     |');
writeln('| [1] Edytuj                          |');
writeln('| [2] Wyswietl parametry              |');
writeln('| [3] Prezentacja w trybie graficznym |');
writeln('| [0] Wyczysc caly plik               |');
writeln('|                                     |');
writeln('| [Q] Wyjscie                         |');
writeln('|                                     |');
writeln(' -------------------------------------');
k:=readkey;


case k of
'1':edit;
'2':show;
'3':drawEnemy;
'0':clearenemy;
end;

until k='q';

End;






procedure quit;
begin
writeln;
writeln('Zamykanie...');
delay(750);
halt;
end;


procedure pick;
begin
writeln;
write('Wprowadz nazwe przeciwnika: ');
readln(name);
assign(f0,'F:\INTERW~1\img\'+name+'.dat');
end;

procedure load;
begin
pick;
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
var k:char;
begin
writeln('EnemyEd v2;');
writeln;
writeln(' -----[ MENU ]----- ');
writeln('|                  |');
writeln('| [1] Nowy         |');
writeln('| [2] Laduj        |');
writeln('|                  |');
writeln('| [Q] Koniec       |');
writeln('|                  |');
writeln(' ------------------');
writeln;
writeln('pliki sa zapisywane automatycznie, po kazdej zmianie parametru');
writeln;
writeln('ostatni przeciwnik: ',name);
k:=readkey;
case k of
'1': neww;
'2': load;
'q': quit;
end;

end;













begin

textmodeint;

repeat
clrscr;
menu;
until keypressed;

end.

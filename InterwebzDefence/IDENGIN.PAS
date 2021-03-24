unit idengin;

interface

type
  point = record
    x,y:integer;
  end;

  cannon = record
    rotation:single;
    x,y:single;
    length:byte;
    {cannx,canny:integer;   { pozycja kierunkowa dziala }
    shooting:boolean;      { czy strzela }
    shootrate:word;        { szybkosc strzalu STAT }
    shoottime:word;        { czas do nast. strzalu }
  end;

  bul = record
    exist:boolean;
    rotation,x,y,spd:single;
    power:word;
    owner:char;            { p:player, e:enemy }
    r,c:byte;
  end;
  bullets=array[0..300] of bul;

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

  thing = record
    i:word;
    c:longint;
  end;
  thingR = record
    i:single;
    c:word;
  end;

  { uzywane do czyszczenia stack }
  block_rec_ptr = ^block_rec;
  block_rec = record
    next : block_rec_ptr;
    size : word;
  end;


const
ered = 11;
eorange = 14;
eyellow = 17;
elime = 20;
egreen = 23;
ebluegreen = 26;
elightgreen = 29;
eblue = 32;
eviolet = 35;
epink = 38;
eblack = 40;
filler : byte = 0;      { uzyte do czyszczenia stack }


var
{ zmienne plikowe }
patch:string;
fe:enemyfile;

x,y:integer;
key:char;
gracz:cannon;

{                    |
                     |
    PRZECIWNICY      |
                     |
                     }
enemies:array[0..20] of enemy;        { lista typow wrogow }
lvlenemies:array[1..50,0..6] of byte; { lista id 5max wrogow na kazdy poziom }
lvltypes:array[1..50] of byte;        { ilosc typow wrogow na kazdy lvl }
enemiesfreq:array[0..50,0..5] of byte;{ wartosc do funckji random dla tworzenia przeciwnikow }
eos:array[0..50] of enemy;            { enemies on stage }
eosint,maxeos:byte;

{                    |
   POCISKI           |
     PRZECIWNIKOW    |
                     |
                     }
buls:bullets;


{                    |
  ZMIENNE            |
      GRACZA         |
                     |
                     }
cann:array[0..2] of point;
shootrates,bulpower:array[0..9] of thing;
plspeed:array[0..9] of thingR;
canbuyspeed,canbuypower,canbuyplspeed:boolean;
atacked,actrate,actbul,actplspeed:byte;


{                    |
                     |
   CZYNNIKI GLOWNE   |
                     |
                     }
gameover:word;
gameoverpal:byte;
gameovered,gameovereffect:boolean;

lvltime,lvltimemax:word;{ czas na kazdy poziom }

gamestarted,            { czy gra sie rozpoczela }
playinglvl,             { czy juz gramy, strzelamy do przeciwnikow }
counting                { czy odmierza czas na poczatku poziomu }
:boolean;
countint:word;          { liczenie od 400 w dol, 200=3, 150=2, 100=1, 50=go }
lvl,hp,maxbul:byte;
score,scoretrue:longint;

showshop,
pause:boolean;
{                    |
       BONUSY        |
                     }
{ 0-bullettime 1-triplepower 2-   }
slomo,slomomax:word;

shottimes,hittimes,enemieskilled,enemieslost:integer;





{ ###  WYKAZ PALETY  ### }{
                          |
r,g,b : 0-63              |
                          |
index    info             |
________ _________________|_                          _
                                                      |
0        czarny                                       |
1-4      HUD (zmienia sie wraz z poziomem zycia)      |
5        Kursor                                       |
6-9      6 lufa, 7,8,9 odcienie kola                  |
10-44    kolory przeciwnikow                          |
45-46    kolory paska shoottime                       |
47-57    draw 3,2,1, GO!! paleta zmieniana dynamicznie|
58-60    pause menu                                   |
61-62    tlo gry                                      |
63-71    gama szarosci do shopmenu i gameover delty   |
72=73    kolor progessbaru                            |
                                                      }


(* ########################################  |
|  #                                      #  |
|  ########   PROCEDURY GRAFICZNE #########  |
|  #                                      #  |
|  ######################################## *)

procedure drawintro;
procedure welldone;

procedure drawbuffer;
procedure overeffects;

procedure setintpal;
procedure getintpal;
procedure setpalette;
procedure decpalette;
procedure incpalette;
procedure updatehudpal; { uaktualnia kolorystyke w HUD }

procedure drawhud;
procedure drawdigit(num:byte;dx,dy:word;sideleft:boolean);
procedure drawscore;
procedure drawhp;
procedure drawcur;

procedure drawpause;
procedure drawshop;
procedure drawexit;
procedure drawgameover;
procedure drawbg;

procedure shake(r:byte);

procedure drawPlayer;
{procedure showrotation;
procedure drawmousedebug;
procedure drawShotRateDebug;}

procedure drawEnemies;

procedure drawBullets;
procedure drawshoottime;

procedure drawlvl;
procedure drawlvlprogress;
procedure drawslomo;


(* ########################################  |
|  #                                      #  |
|  ######  PROCEDURY OBLICZENIOWE  ########  |
|  #                                      #  |
|  ######################################## *)

function  r2i(r:single):integer;
{procedure clear_stack;}

procedure ingame;
procedure getpause;

procedure initmenu;

procedure initgame;
procedure endgame;

procedure countDown;
procedure preparenextlvl;
procedure checklvl;

procedure addenemy(typ:byte);
procedure moveenemies;
procedure removeenemy(id:byte);
procedure checkCol;

procedure shoot;
procedure movebullets;
procedure checkbullets;
procedure removebullet(id:byte);




implementation

uses zvga,crt;




procedure drawintro;
var i:byte;g:boolean;

  procedure showimg(n:string;d:word);
  begin
    ShowBitMapImage(n,0,0);
    drawpage;
    delay(d);
    czekaj;
  end;

begin
cls(0);
vgatext(55,80,3,'[Enter] by pominac intro...',0);
drawpage;

repeat
  i:=i+1;
  if keys[28]=true then exit;
  delay(50);
until i=200;

showimg('F:\INTERW~1\img\bg.bmp',1000);
showimg('F:\INTERW~1\img\bg2.bmp',1000);
showimg('F:\INTERW~1\img\intro1.bmp',15000);
showimg('F:\INTERW~1\img\intro2.bmp',10000);
showimg('F:\INTERW~1\img\intro3.bmp',10000);
showimg('F:\INTERW~1\img\intro4.bmp',10000);
showimg('F:\INTERW~1\img\info.bmp',3000);
repeat until keys[34]=true;
delay(1000);
End;



procedure welldone;
var t,s:string;
begin
ShowBitMapImage('F:\INTERW~1\img\welldone.bmp',0,0);

  { score }
  str(score,t);
  s:='Punkty: '+t;
  VGAText(75,100-40,63,s,1);
  { przeciwnicy }
  str(enemieskilled,t);
  s:='Zabitych: '+t;
  VGAText(75,100-30,63,s,1);

  str(enemieslost,t);
  s:='Puszczonych: '+t;
  VGAText(75,100-20,63,s,1);

  str(shottimes,t);
  s:='Strzaly: '+t;
  VGAText(75,100-10,63,s,1);

  str(hittimes,t);
  s:='Trafienia: '+t;
  VGAText(75,100,63,s,1);

  str(shottimes div hittimes * 100,t);
  s:='Celnosc: '+t+'%';
  VGAText(75,100+10,63,s,1);

drawpage;
delay(7000);
end;


(*
procedure clear_stack;
var where : pointer;
    howmuch : word;
begin
where := ptr(sseg,stacklimit);
howmuch := sptr-stacklimit-14;   { leave room for the fillchar parameters }
                                 {          and return address            }
fillchar(where^,howmuch,filler);
end;
*)




procedure drawbuffer;
begin
  cls(0);
  if gameover>0 then overeffects;

  drawbg;

  drawPlayer;
  drawenemies;
  drawbullets;
  {drawmouse;
  drawMouseDebug;}

  if gameovered=false then begin
    updatehudpal;
    drawshoottime;

    drawhud;
    drawscore;
    drawhp;
    drawlvl;
    drawlvlprogress;
    drawslomo;
    if showshop=false then drawcur;
  end;

  if atacked>0 then begin
    shake(4);
    atacked:=atacked-1;
  end;

  if (pause=true) and (showshop=false) then drawpause
  else
  if showshop=true then drawshop;

  if (gameoverpal=2)and(gameoverpal=3)then drawgameover;
end;


procedure overeffects;
begin

  gameover:=gameover-1;
  if gameover=0 then
    if gameoverpal=1 then begin
      gameoverpal:=2;
      gameover:=100;
    end
    else
    if gameoverpal=2 then begin
      gameoverpal:=3;
      gameovereffect:=false;
    end;


  if gameoverpal=1 then begin
    incpalette;
    shake(6);
  end
  else if gameoverpal=2 then decpalette;

End;



procedure ingame;
var tmpstr:string;
    tmpint:integer;
begin

(*                 }
     KONIEC ?      }
   POZIOMU/GRY?    }
                   }
                  *)

  checklvl;

    {                 }
    {                 }
    {   TWORZENIE     }
    {                 }
    {                 }

  if (lvltime>0)and(playinglvl=true) then begin
    tmpint:=random(lvltypes[lvl]); { losowy przeciwnik z aktualnego poziomu }
    if random(enemiesfreq[lvl,tmpint])=0 then
      addenemy(lvlenemies[lvl,tmpint]);
  end;


  {                 }
  {                 }
  {    KALKULACJE   }
  {                 }
  {                 }

  if pause=false then begin
    { ruszanie gracza }
    {<}if (keys[75]=true) and (gracz.x>45) then gracz.x:=gracz.x-plspeed[actplspeed].i;
    {>}if (keys[77]=true) and (gracz.x<275) then gracz.x:=gracz.x+plspeed[actplspeed].i;
    if gracz.x<45 then gracz.x:=45;
    if gracz.x>275 then gracz.x:=275;
    { ruszanie gracza gora/dol }
    {^}if (keys[72]=true) and (gracz.y>125) then gracz.y:=gracz.y-plspeed[actplspeed].i;
    {_}if (keys[80]=true) and (gracz.y<192) then gracz.y:=gracz.y+plspeed[actplspeed].i;
    if gracz.y<125 then gracz.y:=125;
    if gracz.y>192 then gracz.y:=192;
    { odliczanie tylko na poczatku poziomu }
    if (counting=true) and (countint>0) then countint:=countint-1;
    { shooting gracza }
    if gracz.shooting=false then
      if (mousebtn=1) or (mousebtn=3) then shoot;

    if gracz.shoottime>0 then gracz.shoottime:=gracz.shoottime-1;
    if gracz.shoottime=0 then gracz.shooting:=false;


    moveenemies;
    movebullets;
    checkbullets;
    checkCol;

    if countint>0 then countDown;

    { bullettime }
    if (mousebtn>1) and (slomo>0) then begin
      czekaj;
      czekaj;
      slomo:=slomo-1;
    end;
  end;
End;

procedure getpause;
begin
  if keys[25]=true then begin
    if pause=true then pause:=false
    else
    if pause=false then pause:=true;

    setpalette;
    delay(500);
  end;
end;


function r2i(r:single):integer;
var s:string;
    e:integer;
    i:integer;

begin
  str(r:2:0,s);
  val(s,e,i);
  r2i:=e;
end;




procedure updatehudpal;
begin
     {   HUD  }
     setColor(1,r2i(-0.05*hp+5),hp div 15,0);
     setColor(2,r2i(-0.14*hp+14),hp div 7,0);
     setColor(3,r2i(-0.50*hp+50),r2i(hp/1.7),0);
     setColor(4,r2i(-0.45*hp+60)+20,hp div 2+20,63);
     { KURSOR }
     setColor(5,63,63,63);
end;


procedure getintpal;
var i:byte;
begin
for i:=0 to 255 do begin
  getColor(i);
  intpal[i].r:=rpal;
  intpal[i].b:=bpal;
  intpal[i].g:=gpal;
end;
End;


procedure setintpal;
var i:byte;
begin
for i:=0 to 255 do setColor(i,intpal[i].r,intpal[i].g,intpal[i].b);
End;


procedure setpalette;
var i:byte;j:word;
begin
if pause=true then begin
setColor(6,20 div 2,20 div 2,20 div 2);
setColor(7,25 div 2,25 div 2,25 div 2);
setColor(8,35 div 2,35 div 2,35 div 2);
setColor(9,45 div 2,45 div 2,45 div 2);
setcolor(45,63 div 2,20 div 2,20 div 2);
setcolor(46,50 div 2,0,0);
setColor(61,5,5,5);
setColor(62,0,5,0);
j:=lvltime div lvltimemax * 63;
setColor(72,j div 2+10,j div 2+10,j div 10);
setColor(73,j div 3+5 ,j div 3+5 ,0);
{ PALETA PRZECIWNIKOW }
{ red }
setcolor(10,30 div 2,0  ,0  );
setcolor(11,63 div 2,0  ,0  );
setcolor(12,63 div 2,34 div 2,34 div 2);
{ orange }
setcolor(13,30 div 2,18 div 2,0  );
setcolor(14,63 div 2,40 div 2,0  );
setcolor(15,63 div 2,48 div 2,34 div 2);
{ yellow }
setcolor(16,30 div 2,30 div 2,0  );
setcolor(17,63 div 2,63 div 2,0  );
setcolor(18,63 div 2,63 div 2,34 div 2);
{ lime }
setcolor(19,18 div 2,30 div 2,0  );
setcolor(20,40 div 2,63 div 2,0  );
setcolor(21,48 div 2,63 div 2,34 div 2);
{ green }
setcolor(22,0  ,30 div 2,0  );
setcolor(23,0  ,63 div 2,0  );
setcolor(24,34 div 2,63 div 2,64 div 2);
{ bluegreen }
setcolor(25,0  ,30 div 2,18 div 2);
setcolor(26,0  ,63 div 2,40 div 2);
setcolor(27,34 div 2,63 div 2,48 div 2);
{ lightblue }
setcolor(28,0  ,30 div 2,30 div 2);
setcolor(29,0  ,63 div 2,63 div 2);
setcolor(30,34 div 2,63 div 2,63 div 2);
{ blue }
setcolor(31,0  ,0  ,30 div 2);
setcolor(32,0  ,0  ,63 div 2);
setcolor(33,34 div 2,34 div 2,63 div 2);
{ violet }
setcolor(34,18 div 2,0  ,30 div 2);
setcolor(35,40 div 2,0  ,63 div 2);
setcolor(36,48 div 2,34 div 2,63 div 2);
{ pink }
setcolor(37,30 div 2,0  ,30 div 2);
setcolor(38,63 div 2,0  ,63 div 2);
setcolor(39,63 div 2,34 div 2,63 div 2);
{ black }
setcolor(40,0  ,0  ,0  );
setcolor(41,18 div 2,18 div 2,18 div 2);
setcolor(42,30 div 2,30 div 2,30 div 2);
setcolor(43,48 div 2,48 div 2,48 div 2);
setcolor(44,63 div 2,63 div 2,63 div 2);
end
else if pause=false then begin
j:=lvltime div lvltimemax * 63;
setColor(72,j div 2+10,j div 2+10,j div 10);
setColor(73,j div 3+5 ,j div 3+5 ,0);
setColor(6,20,20,20);
setColor(7,25,25,25);
setColor(8,35,35,35);
setColor(9,45,45,45);
setcolor(45,63,20,20);
setcolor(46,50,0,0);
setColor(61,15,15,15);
setColor(62,0,10,0);
{ PALETA PRZECIWNIKOW }
{ red }
setcolor(10,30,0  ,0  );
setcolor(11,63,0  ,0  );
setcolor(12,63,34,34);
{ orange }
setcolor(13,30,18,0  );
setcolor(14,63,40,0  );
setcolor(15,63,48,34);
{ yellow }
setcolor(16,30,30,0  );
setcolor(17,63,63,0  );
setcolor(18,63,63,34);
{ lime }
setcolor(19,18,30,0  );
setcolor(20,40,63,0  );
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
setcolor(34,18,0  ,30);
setcolor(35,40,0  ,63);
setcolor(36,48,34,63);
{ pink }
setcolor(37,30,0  ,30);
setcolor(38,63,0  ,63);
setcolor(39,63,34,63);
{ black }
setcolor(40,0  ,0  ,0);
setcolor(41,18,18,18);
setcolor(42,30,30,30);
setcolor(43,48,48,48);
setcolor(44,63,63,63);
end;
{ PAUSE SHOP MENU }
setColor(58,0,0,0);
setColor(59,30,30,30);
setColor(60,62,62,62);
{ GAMEOVER PALETTE }
setcolor(63,25,25,25);
setcolor(64,37,37,37);
setcolor(65,45,45,45);
setcolor(66,57,57,57);
setcolor(67,63,63,63);
setcolor(68,58,58,58);
setcolor(69,52,52,52);
setcolor(70,44,44,44);
setcolor(71,35,35,35);
end;


procedure decpalette;
var i,r,g,b:byte;
begin

for i:=0 to 62 do begin
getcolor(i);
if rpal>0 then r:=rpal-1;
if gpal>0 then g:=gpal-1;
if bpal>0 then b:=bpal-1;
setcolor(i,rpal,bpal,gpal);
end;

End;


procedure incpalette;
var i,r,g,b:byte;
begin

for i:=0 to 62 do begin
getcolor(i);
rpal:=rpal+1;
gpal:=gpal+1;
bpal:=bpal+1;
setcolor(i,rpal,bpal,gpal);
end;

End;




{ #################### }
(* PROCEDURY MALUJACE *)
{ #################### }



procedure drawhud;
begin
box(0,30,0,maxy,1,true);
box(290,maxx,0,maxy,1,true);
linev(30,0,maxy,3);
linev(290,0,maxy,3);
end;


procedure drawdigit(num:byte;dx,dy:word;sideleft:boolean);

    procedure digitbg;
    var i,j,k:byte;
    begin
      box(dx+2,dx+6,dy+2,dy+6,1,true);
      box(dx+10,dx+14,dy+2,dy+6,1,true);

    end;


    { ELEMENTY JEDNEJ CYFRY }
    procedure topl;
    begin
      lineh(dx+1,dx+3,dy,3);
      lineh(dx+2,dx+6,dy+1,3);
      pixel(dx+7,dy,3);
      lineh(dx+4,dx+6,dy,4);
    end;

    procedure topr;
    begin
      lineh(dx+9,dx+11,dy,3);
      lineh(dx+10,dx+14,dy+1,3);
      pixel(dx+15,dy,3);
      lineh(dx+12,dx+14,dy,4);
    end;

    procedure left;
    begin
      linev(dx,dy+1,dy+7,3);
      linev(dx+1,dy+5,dy+6,3);
      linev(dx+1,dy+2,dy+4,4);
    end;

    procedure mid;
    begin
      linev(dx+7,dy+2,dy+6,3);
      linev(dx+8,dy+1,dy+7,3);
      linev(dx+9,dy+5,dy+6,3);
      linev(dx+9,dy+2,dy+4,4);
    end;

    procedure righ;
    begin
      linev(dx+15,dy+2,dy+6,3);
      linev(dx+16,dy+5,dy+7,3);
      pixel(dx+16,dy+1,3);
      linev(dx+16,dy+2,dy+4,4);
    end;

    procedure botl;
    begin
      lineh(dx+2,dx+3,dy+7,3);
      lineh(dx+1,dx+6,dy+8,3);
      pixel(dx+7,dy+8,3);
      lineh(dx+4,dx+6,dy+7,4);
    end;

    procedure botr;
    begin
      lineh(dx+10,dx+11,dy+7,3);
      lineh(dx+9,dx+15,dy+8,3);
      lineh(dx+12,dx+14,dy+7,4);
    end;


begin

box(dx,dx+16,dy,dy+8,1,true);
{digitbg;}

if sideleft=false then case num of
  1: begin botl; botr; end;
  2: begin left; topl; mid;  botr; righ; end;
  3: begin left; botl; mid;  botr; righ; end;
  4: begin botl; mid;  botr; topr; end;
  5: begin left; botl; mid;  topr; righ; end;
  6: begin left; topl; botl; mid;  topr; righ; end;
  7: begin botl; botr; righ; end;
  8: begin left; topl; botl; mid;  topr; botr; righ; end;
  9: begin left; botl; mid;  topr; botr; righ; end;
  0: begin left; topl; botl; topr; botr; righ; end;
end
else
if sideleft=true then case num of
  1: begin topl; topr; end;
  2: begin left; topl; mid;  botr; righ; end;
  3: begin left; topl; mid;  topr; righ; end;
  4: begin botl; topl; mid;  topr; end;
  5: begin left; botl; mid;  topr; righ; end;
  6: begin left; botl; mid;  topr; botr; righ; end;
  7: begin left; topl; topr; end;
  8: begin left; topl; botl; mid;  topr; botr; righ; end;
  9: begin left; botl; topl; mid;  topr; righ; end;
  0: begin left; topl; botl; topr; botr; righ; end;
end;
end;


procedure drawscore;
var tmp,spaces:string[1];
    int,tmpi:integer;
    tmps:string[10];
    len,spaceb:byte;
    i:byte;
begin
  str(score, tmps);
  len:=length(tmps);
  for i:=len downto 1 do begin
      val(copy(tmps,i,1),tmpi,int);
      drawdigit(tmpi,10,100-10*i,true);
  end;
  {drawdigit(12,10,10+10*(i-1),true);}
end;


procedure drawhp;
var tmp:string[1];
    int,tmpi:integer;
    tmps:string[3];
    len:byte;
    i:byte;
    begx,begy:word;
begin
  begx:=296;
  begy:=30;
  str(hp, tmps);
  len:=length(tmps);
  if len=3 then begin
     { pierwszy znak od gory }
     val(copy(tmps,1,1),tmpi,int);
     drawdigit(tmpi,begx,begy,false);
     { DRUGI znak od gory }
     val(copy(tmps,2,1),tmpi,int);
     drawdigit(tmpi,begx,10+begy,false);
     { TRZECI znak od gory }
     val(copy(tmps,3,1),tmpi,int);
     drawdigit(tmpi,begx,20+begy,false);
  end else if len=2 then begin
     { pierwszy znak od gory }
     drawdigit(88,begx,begy,false);
     { DRUGI znak od gory }
     val(copy(tmps,1,1),tmpi,int);
     drawdigit(tmpi,begx,10+begy,false);
     { TRZECI znak od gory }
     val(copy(tmps,2,1),tmpi,int);
     drawdigit(tmpi,begx,20+begy,false);
  end else if len=1 then begin
     { pierwszy znak od gory }
     drawdigit(88,begx,begy,false);
     { DRUGI znak od gory }
     drawdigit(88,begx,10+begy,false);
     { TRZECI znak od gory }
     val(copy(tmps,1,1),tmpi,int);
     drawdigit(tmpi,begx,20+begy,false);
  end;

End;




procedure drawlvlprogress;
var s,t:string[6];
    l,p:single;
    xx:byte;
begin
  l:=lvltime/lvltimemax * 70;
  p:=-(lvltime/lvltimemax * 100)+100;
  { bg }     { y:120-190 }
  box(8,22,118,192,2,true);
  { bar }
  box(10,20,120+r2i(l),190,4,true);
  {box(6,24,maxy div 2+19, maxy,72,true);
  box(10,20,(maxy div 2+20),maxy div 2+len,73,true);
  {drawdigit(12,10,10+10*(i-1),true);}
  str(p:2:0, t);
  if p<10 then begin s:=t+'%';xx:=2; end
  else
  if p<100 then begin s:=t+'%';xx:=4; end
  else
  if p=100 then begin s:='...';xx:=4; end;
  VGAText(xx,110,3,s,0);
end;


procedure drawslomo;
var s,t:string[6];
    l,p:single;
    xx:word;
begin
  l:=slomo/slomomax * 70;
  p:=slomo/slomomax * 100;
  { bg }     { y:120-190 }
  box(298,312,118,192,4,true);
  { bar }
  box(300,310,120+r2i(l),190,2,true);
  {box(6,24,maxy div 2+19, maxy,72,true);
  box(10,20,(maxy div 2+20),maxy div 2+len,73,true);
  {drawdigit(12,10,10+10*(i-1),true);}
  str(p:2:0, t);
  if p<10 then begin s:=t+'%';xx:=282; end
  else
  if p<100 then begin s:=t+'%';xx:=284; end
  else
  if p=100 then begin s:='100';xx:=284; end;
  VGAText(xx,110,3,s,0);
end;





procedure drawcur;
var x,y:word;
begin
x:=mx;
y:=my;
pixel(x,y,5);

lineh(x-7,x-3,y-7,5);
lineh(x+3,x+7,y-7,5);

linev(x+7,y-7,y-3,5);
linev(x+7,y+3,y+7,5);

lineh(x+3,x+7,y+7,5);
lineh(x-7,x-3,y+7,5);

linev(x-7,y+3,y+7,5);
linev(x-7,y-7,y-3,5);
end;



procedure drawpause;
begin
{box(100,75,220,125,58,true);
box(101,76,219,124,59,false);
box(102,77,218,123,60,false);}
VGAText(maxx div 2 - 25,maxy div 2-11,59,'PAUZA',0);
VGAText(maxx div 2 - 23,maxy div 2-9,59,'PAUZA',0);
VGAText(maxx div 2 - 24,maxy div 2-10,60,'PAUZA',0);
end;



procedure drawshop;
var h:char;s:string;i:byte;b:boolean;

  procedure drawcirclestat(x,y,c:word;act:byte);
  begin
    circlefill(x+185,y-1,13,58);

    str(act,s);
    VGAText(x+183,y-5,65,s,0);

    box(x+165,x+205,y+5,y+12,eblack+1,true);
    str(c,s);
    VGAText(x+170,y+6,i,s,0);
  end;

  procedure drawcircleyes(x,y:word);
  begin
    circlefill(x,y,13,63);
    circlefill(x,y,12,60);
    circlefill(x,y,11,63);
    circlefill(x,y,10,58);
  end;
  procedure drawcircleno(x,y:word);
  begin
    circlefill(x,y,12,63);
    circlefill(x,y,10,58);
  end;

  procedure drawspeed(v:boolean;x,y:word);
  begin
    case v of
    true:begin
      drawcircleyes(x,y);
      VGAText(x+15,y-1,63,'1:Speed strzalu',1);
      i:=egreen+1;
      end;
    false:begin
      drawcircleno(x,y);
      VGAText(x+15,y-1,63,'1:Speed pocisku',0);
      i:=ered+1;
      end;
    end;
    line(x-4,y+6,x-8,y  ,67);
    line(x-8,y  ,x-4,y-6,67);

    line(x-3,y+6,x-7,y  ,67);
    line(x-7,y  ,x-3,y-6,67);

    line(x  ,y+6,x-4,y  ,67);
    line(x-4,y  ,x  ,y-6,67);

    line(x+1,y+6,x-3,y  ,67);
    line(x-3,y  ,x+1,y-6,67);

    line(x+4,y+6,x  ,y  ,67);
    line(x  ,y  ,x+4,y-6,67);

    line(x+5,y+6,x+1,y  ,67);
    line(x+1,y  ,x+5,y-6,67);

    line(x+6,y+4,x+3,y  ,67);
    line(x+3,y  ,x+6,y-4,67);
    line(x+6,y+4,x+6,y-4,67);




    drawcirclestat(x,y,shootrates[actrate+1].c,actrate);

  End;

  procedure drawpower(v:boolean;x,y:word);
  begin
    case v of
    true:begin
      drawcircleyes(x,y);
      VGAText(x+15,y-1,63,'2:Moc pocisku',1);
      i:=egreen+1;
      end;
    false:begin
      drawcircleno(x,y);
      VGAText(x+15,y-1,63,'2:Moc pocisku',0);
      i:=ered+1;
      end;
    end;

    drawcirclestat(x,y,bulpower[actbul+1].c,actbul);

  End;

  procedure drawplspeed(v:boolean;x,y:word);
  begin
    case v of
    true:begin
      drawcircleyes(x,y);
      VGAText(x+15,y-1,63,'3:Speed dziala',1);
      i:=egreen+1;
      end;
    false:begin
      drawcircleno(x,y);
      VGAText(x+15,y-1,63,'3:Speed dziala',0);
      i:=ered+1;
      end;
    end;

    drawcirclestat(x,y,plspeed[actplspeed+1].c,actplspeed);

  End;

begin
repeat
 circlefill(75+185,72,14,59);
 circlefill(75+185,99,14,59);
 circlefill(75+185,126,14,59);

 box(60,260,54,146,58,true);
 box(60,260,54,146,59,false);

 if hp<100 then begin
   i:=random(11);
   hp:=hp+1;
   if hp>100 then hp:=100;
   str(i,s);
   s:='Dodano '+s+' zycia';
 end else
   s:='Nie dodano zycia';
 VGAText(maxx div 2 - 25,20 ,60,s,0);
 VGAText(maxx div 2 - 25,50 ,60,'SKLEPIK',0);
 VGAText(maxx div 2 - 55,145,60,'[G] - gogogo',0);

 if (score>=shootrates[actrate+1].c)and(canbuyspeed=true) then
 drawspeed(true,75,73) else drawspeed(false,75,73);
 if (score>=bulpower[actbul+1].c)and(canbuypower) then
 drawpower(true,75,100) else drawpower(false,75,100);
 if (score>=plspeed[actplspeed+1].c)and(canbuyplspeed=true) then
 drawplspeed(true,75,127) else drawplspeed(false,75,127);

 drawpage;


 b:=false;
 repeat
   if keys[2]=true then begin h:='1'; b:=true; end;
   if keys[3]=true then begin h:='2'; b:=true; end;
   if keys[4]=true then begin h:='3'; b:=true; end;
   if keys[34]=true then begin h:='g'; b:=true; end;
 until b=true;


 case h of
 '1':if score>=shootrates[actrate+1].c then begin
      actrate:=actrate+1;
      canbuyspeed:=false;
      score:=score-shootrates[actrate].c;
      box(10,26,40,100+8,1,true);
      drawscore;
    end;
 '2':if score>=bulpower[actbul+1].c then begin
      actbul:=actbul+1;
      canbuypower:=false;
      score:=score-bulpower[actbul].c;
      box(10,26,40,100+8,1,true);
      drawscore;
    end;
 '3':if score>=plspeed[actplspeed+1].c then begin
      actplspeed:=actplspeed+1;
      canbuyplspeed:=false;
      score:=score-plspeed[actplspeed].c;
      box(10,26,40,100+8,1,true);
      drawscore;
    end;
 end;
 delay(500);

until h='g';
preparenextlvl;
End;



procedure drawexit;
begin

showbitmapimage('F:\INTERW~1\img\end.bmp',0,0);
drawpage;
delay(5000);
halt;

end;




procedure drawgameover;
var s,t:string;
begin
  VGAText(maxx div 2-70,30,66,'-=[ GAME OVER ]=-',1);


  { score }
  str(score,t);
  s:='Punkty: '+t;
  VGAText(75,100-40,63,s,1);
  { przeciwnicy }
  str(enemieskilled,t);
  s:='Zabitych: '+t;
  VGAText(75,100-30,63,s,1);

  str(enemieslost,t);
  s:='Puszczonych: '+t;
  VGAText(75,100-20,63,s,1);

  str(shottimes,t);
  s:='Strzaly: '+t;
  VGAText(75,100-10,63,s,1);

  str(hittimes,t);
  s:='Trafienia: '+t;
  VGAText(75,100,63,s,1);

  str(shottimes div hittimes * 100,t);
  s:='Celnosc: '+t+'%';
  VGAText(75,100+10,63,s,1);
end;



procedure drawbg;
var i:byte;
begin
 box(31,0,289,maxy,ered,true);
 for i:=0 to 32 do linev(i*10,0,maxy,62);
 for i:=0 to 19 do lineh(0,maxx,i*10,62);
end;



procedure drawPlayer;
var a,b:real;
    i:shortint;
begin

{ OBLICZENIA TYLKO PODCZAS GRY }
if (pause=false) and (gameovereffect=false) then begin

  a:=r2i(gracz.x)-mx;
  b:=r2i(gracz.y)-my;
  if b<>0 then
    gracz.rotation := arctan(a/b)
  else
  if a<0 then
    gracz.rotation := pi+(pi/2)
  else
    gracz.rotation := pi-(pi/2)
  ;
  { ######## RYSOWANIE DZIALA ########### }
  { kalkulacja rotacji kazdego z punktow dzialka }
  if b<0 then cann[0].x:=r2i(sin(gracz.rotation+5/30)*gracz.length)+r2i(gracz.x)
  else cann[0].x:=-r2i(sin(gracz.rotation+5/30)*gracz.length)+r2i(gracz.x);
  if b<0 then cann[0].y:=r2i(cos(gracz.rotation+5/30)*gracz.length)+r2i(gracz.y)
  else cann[0].y:=-r2i(cos(gracz.rotation+5/30)*gracz.length)+r2i(gracz.y);
  { point 2 }
  if b<0 then cann[1].x:=r2i(sin(gracz.rotation-5/30)*gracz.length)+r2i(gracz.x)
  else cann[1].x:=-r2i(sin(gracz.rotation-5/30)*gracz.length)+r2i(gracz.x);
  if b<0 then cann[1].y:=r2i(cos(gracz.rotation-5/30)*gracz.length)+r2i(gracz.y)
  else cann[1].y:=-r2i(cos(gracz.rotation-5/30)*gracz.length)+r2i(gracz.y);
  { point 3 aka bullet, kierunkowy }
  if b<0 then cann[2].x:=r2i(sin(gracz.rotation+1/30)*gracz.length)+r2i(gracz.x)
  else cann[2].x:=-r2i(sin(gracz.rotation+1/30)*gracz.length)+r2i(gracz.x);
  if b<0 then cann[2].y:=r2i(cos(gracz.rotation-1/30)*gracz.length)+r2i(gracz.y)
  else cann[2].y:=-r2i(cos(gracz.rotation-1/30)*gracz.length)+r2i(gracz.y);

end; { KONIEC WARUNKU PAUZY }

line(r2i(gracz.x), r2i(gracz.y), cann[0].x, cann[0].y, 6);
line(cann[0].x, cann[0].y, cann[1].x, cann[1].y, 6);
line(cann[1].x, cann[1].y, r2i(gracz.x), r2i(gracz.y), 6);

circlefill(r2i(gracz.x), r2i(gracz.y), 9, 7);
circlefill(r2i(gracz.x)+2, r2i(gracz.y)-2, 6, 8);
circlefill(r2i(gracz.x)+4, r2i(gracz.y)-3, 4, 9);
box(r2i(gracz.x)-9, r2i(gracz.x)+9, r2i(gracz.y)+3, {r2i(gracz.y)+8}maxy, 7, true);
box(r2i(gracz.x)-2, r2i(gracz.x)+9, r2i(gracz.y)+3, r2i(gracz.y)+7, 8, true);
box(r2i(gracz.x)+2, r2i(gracz.x)+9, r2i(gracz.y)+3, r2i(gracz.y)+6, 9, true);
box(r2i(gracz.x)-9, r2i(gracz.x)+9, r2i(gracz.y)+3, {r2i(gracz.y)+8}maxy, 6, false);

end;



procedure showrotation;
var {------------}
    tmpr:single;
    tmps:string;

begin

tmpr:=gracz.rotation;
str(tmpr:2:3,tmps);

VGAText(50,50,10,tmps,0);

end;


procedure drawmousedebug;
begin
if mousebtn=1 then box(40,50,50,60,5,true)
else
if mousebtn=2 then box(50,60,50,60,5,true)
else
if mousebtn=3 then box(40,60,50,60,5,true);
end;


procedure drawShotRateDebug;
var tmpstr:string;
begin
str(gracz.shoottime, tmpstr);
vgatext(35,10,eorange,tmpstr,0);
str(gracz.shootrate, tmpstr);
vgatext(35,20,eorange+1,tmpstr,0);
end;



procedure shoot;
var i:byte;
begin

for i:=0 to maxbul do
if buls[i].exist=false then begin
shottimes:=shottimes+1;
{ spark }
CircleFill(cann[2].x,cann[2].y,10,eblack+4);
buls[i].exist:=true;
buls[i].x:=cann[2].x;
buls[i].y:=cann[2].y;
buls[i].spd:=plspeed[actplspeed].i*3+1;
buls[i].rotation:=gracz.rotation;
buls[i].power:=bulpower[actbul].i;
buls[i].owner:='p';
buls[i].c:=eblue+1;
buls[i].r:=2;
gracz.shooting:=true;
gracz.shoottime:=gracz.shootrate;
break;
end;




end;

procedure drawshoottime;
var i:real;
    s:string;
begin

i:=gracz.shoottime / gracz.shootrate*10;
if i>0 then begin
  box(r2i(r2i(gracz.x))+12,r2i(gracz.x)+14,r2i(gracz.y)-r2i(i),r2i(gracz.y),ered,true);
  if r2i(i)>2 then linev(r2i(gracz.x)+12,r2i(gracz.y)-r2i(i),r2i(gracz.y)-2,45);
  lineh(r2i(gracz.x)+12, r2i(gracz.x)+14, r2i(gracz.y)-r2i(i),ered+1);
  lineh(r2i(gracz.x)+12, r2i(gracz.x)+14, r2i(gracz.y),46);
end;


end;




procedure drawlvl;
var s:string;
begin

drawdigit(lvl,295,2,false);

end;





procedure drawspark(x,y:word;i:byte);

  procedure drawbig;
  begin
    CircleFill(x,y,20,eblack+4);
    CircleFill(x,y,8,eyellow+1);
  end;

  procedure drawmed;
  begin
    CircleFill(x,y,14,eblack+4);
  end;

  procedure drawsmall;
  begin
    CircleFill(x,y,6,eblack+4);
  end;

begin

case i of
1:drawsmall;
2:drawmed;
3:drawbig;
end;

end;



procedure drawbullets;
var i:byte;
begin

for i:=0 to maxbul do
if (buls[i].exist=true)and(buls[i].y>=0) then
circlefill(r2i(buls[i].x),r2i(buls[i].y),buls[i].r,buls[i].c);

end;


procedure movebullets;
var i:byte;
begin

for i:=0 to maxbul do
if buls[i].exist=true then begin
  buls[i].x:=buls[i].x-buls[i].spd*sin(buls[i].rotation);
  if buls[i].x<30 then   buls[i].rotation:=-cos(buls[i].rotation);
  if buls[i].x>290 then  buls[i].rotation:=-sin(buls[i].rotation);

  buls[i].y:=buls[i].y-buls[i].spd*cos(buls[i].rotation);
end;

end;


procedure removebullet(id:byte);
var i:byte;
begin
buls[id].exist:=false;
if buls[id].y >= 0 then drawspark(r2i(buls[id].x),r2i(buls[id].y),1)
else drawspark(r2i(buls[id].x),0,1);
end;


procedure checkbullets;
var i:byte;
begin

for i:=0 to maxbul do
if (buls[i].exist=true) then
if (buls[i].y<buls[i].r+1)
or (buls[i].y>maxy-buls[i].r)
{or (buls[i].x<30+buls[i].r)
or (buls[i].x>maxx-30-buls[i].r)}
then removebullet(i);

end;




procedure drawEnemies;
var i,j:byte;
    enf:enemyfunc;
    s:string[5];
begin

  for i:=0 to maxeos do begin
    for j:=1 to 6 do begin
      case j of
        1:enf:=eos[i].func1;
        2:enf:=eos[i].func2;
        3:enf:=eos[i].func3;
        4:enf:=eos[i].func4;
        5:enf:=eos[i].func5;
        6:enf:=eos[i].func6;
      end;

      case enf.typ of
        1: box(enf.x1+r2i(eos[i].x),
            enf.x2+r2i(eos[i].x),
            enf.y1+r2i(eos[i].y),
            enf.y2+r2i(eos[i].y),
            enf.c,
            true);
        2: circlefill(enf.x1+r2i(eos[i].x),
            enf.x2+r2i(eos[i].y),
            enf.r,
            enf.c);
        3: elipsa(enf.x1+r2i(eos[i].x),
            enf.x2+r2i(eos[i].y),
            enf.y1,
            enf.y2,
            enf.c);
        4: line(enf.x1+r2i(eos[i].x),
            enf.y1+r2i(eos[i].y),
            enf.x2+r2i(eos[i].x),
            enf.y2+r2i(eos[i].y),
            enf.c);
      end;
    end;
  end;

End;







procedure initmenu;
begin

ShowBitMapImage('F:\INTERW~1\img\menu.bmp',0,0);
drawpage;
czekaj;

end;



procedure loadenemies;
var i:byte;n:string;t:string[2];ten:enemy;
begin

for i:=0 to 9 do begin
str(i+1,t);
n:='F:\INTERW~1\'+t+'.dat';
assign(fe,n);
reset(fe);
seek(fe, 0);
read(fe, ten);
enemies[i].x:=0;
enemies[i].y:=0;
enemies[i].hp:=ten.hp;
enemies[i].maxpoints:=ten.maxpoints;
enemies[i].r:=ten.r;
enemies[i].xs:=ten.xs;
enemies[i].ys:=ten.ys;
enemies[i].func1:=ten.func1;
enemies[i].func2:=ten.func2;
enemies[i].func3:=ten.func3;
enemies[i].func4:=ten.func4;
enemies[i].func5:=ten.func5;
enemies[i].func6:=ten.func6;
end;

End;




procedure initgame;
var i:byte;
begin

initmouse;
LimitX(38,282);
LimitY(7,192);


{ RESET TABLIC }
for i:=0 to maxbul do
buls[i].exist:=false;
for i:=0 to maxeos do
eos[i].exist:=false;


{ PRZECIWNICY Z PLIKOW }
loadenemies;

lvltypes[1]:=1;
lvlenemies[1,0]:=0;
enemiesfreq[1,0]:=100;

lvltypes[2]:=1;
lvlenemies[2,0]:=0;
enemiesfreq[2,0]:=90;

lvltypes[3]:=2;
lvlenemies[3,0]:=0;
lvlenemies[3,1]:=1;
enemiesfreq[3,0]:=60;
enemiesfreq[3,1]:=80;

lvltypes[4]:=3;
lvlenemies[4,0]:=0;
lvlenemies[4,1]:=1;
lvlenemies[4,2]:=2;
enemiesfreq[4,0]:=70;
enemiesfreq[4,1]:=50;
enemiesfreq[4,2]:=90;

lvltypes[5]:=3;
lvlenemies[5,0]:=0;
lvlenemies[5,1]:=2;
lvlenemies[5,2]:=3;
enemiesfreq[5,0]:=85;
enemiesfreq[5,1]:=50;
enemiesfreq[5,2]:=90;

lvltypes[6]:=2;
lvlenemies[6,0]:=1;
lvlenemies[6,1]:=4;
enemiesfreq[6,0]:=50;
enemiesfreq[6,1]:=80;

lvltypes[7]:=3;
lvlenemies[7,0]:=0;
lvlenemies[7,1]:=2;
lvlenemies[7,2]:=4;
enemiesfreq[7,0]:=50;
enemiesfreq[7,1]:=65;
enemiesfreq[7,2]:=80;

lvltypes[8]:=2;
lvlenemies[8,0]:=2;
lvlenemies[8,1]:=4;
enemiesfreq[8,0]:=50;
enemiesfreq[8,1]:=75;

lvltypes[9]:=3;
lvlenemies[9,0]:=0;
lvlenemies[9,1]:=3;
lvlenemies[9,2]:=5;
enemiesfreq[9,0]:=45;
enemiesfreq[9,1]:=70;
enemiesfreq[9,2]:=90;

lvltypes[10]:=2;
lvlenemies[10,0]:=0;
lvlenemies[10,1]:=2;
enemiesfreq[10,0]:=50;
enemiesfreq[10,1]:=50;

lvltypes[11]:=2;
lvlenemies[11,0]:=4;
lvlenemies[11,1]:=5;
enemiesfreq[11,0]:=65;
enemiesfreq[11,1]:=75;

lvltypes[12]:=3;
lvlenemies[12,0]:=3;
lvlenemies[12,1]:=5;
lvlenemies[12,2]:=6;
enemiesfreq[12,0]:=50;
enemiesfreq[12,1]:=80;
enemiesfreq[12,2]:=90;

lvltypes[13]:=2;
lvlenemies[13,0]:=4;
lvlenemies[13,1]:=6;
enemiesfreq[13,0]:=50;
enemiesfreq[13,1]:=90;

lvltypes[14]:=3;
lvlenemies[14,0]:=4;
lvlenemies[14,1]:=5;
lvlenemies[14,2]:=7;
enemiesfreq[14,0]:=80;
enemiesfreq[14,1]:=80;
enemiesfreq[14,2]:=90;

lvltypes[15]:=3;
lvlenemies[15,0]:=1;
lvlenemies[15,1]:=2;
lvlenemies[15,2]:=6;
enemiesfreq[15,0]:=60;
enemiesfreq[15,1]:=60;
enemiesfreq[15,2]:=90;

lvltypes[16]:=4;
lvlenemies[16,0]:=4;
lvlenemies[16,1]:=5;
lvlenemies[16,2]:=7;
lvlenemies[16,3]:=7;
enemiesfreq[16,0]:=80;
enemiesfreq[16,1]:=80;
enemiesfreq[16,2]:=90;
enemiesfreq[16,3]:=90;

lvltypes[17]:=3;
lvlenemies[17,0]:=3;
lvlenemies[17,1]:=5;
lvlenemies[17,2]:=7;
enemiesfreq[17,0]:=60;
enemiesfreq[17,1]:=80;
enemiesfreq[17,2]:=90;

lvltypes[18]:=3;
lvlenemies[18,0]:=2;
lvlenemies[18,1]:=3;
lvlenemies[18,2]:=8;
enemiesfreq[18,0]:=60;
enemiesfreq[18,1]:=45;
enemiesfreq[18,2]:=90;

lvltypes[19]:=3;
lvlenemies[19,0]:=4;
lvlenemies[19,1]:=5;
lvlenemies[19,2]:=7;
enemiesfreq[19,0]:=80;
enemiesfreq[19,1]:=60;
enemiesfreq[19,2]:=90;

lvltypes[20]:=4;
lvlenemies[20,0]:=1;
lvlenemies[20,1]:=2;
lvlenemies[20,2]:=6;
lvlenemies[20,3]:=0;
enemiesfreq[20,0]:=60;
enemiesfreq[20,1]:=60;
enemiesfreq[20,2]:=90;
enemiesfreq[20,3]:=70;

lvltypes[21]:=4;
lvlenemies[21,0]:=3;
lvlenemies[21,1]:=4;
lvlenemies[21,2]:=5;
lvlenemies[21,3]:=1;
enemiesfreq[21,0]:=60;
enemiesfreq[21,1]:=60;
enemiesfreq[21,2]:=90;
enemiesfreq[21,3]:=70;

lvltypes[22]:=2;
lvlenemies[22,0]:=4;
lvlenemies[22,1]:=9;
enemiesfreq[22,0]:=50;
enemiesfreq[22,1]:=90;

lvltypes[23]:=3;
lvlenemies[23,0]:=3;
lvlenemies[23,1]:=5;
lvlenemies[23,2]:=8;
enemiesfreq[23,0]:=60;
enemiesfreq[23,1]:=60;
enemiesfreq[23,2]:=90;

lvltypes[24]:=3;
lvlenemies[24,0]:=4;
lvlenemies[24,1]:=5;
lvlenemies[24,2]:=7;
enemiesfreq[24,0]:=50;
enemiesfreq[24,1]:=60;
enemiesfreq[24,2]:=70;

lvltypes[25]:=3;
lvlenemies[25,0]:=5;
lvlenemies[25,1]:=6;
lvlenemies[25,2]:=7;
enemiesfreq[25,0]:=50;
enemiesfreq[25,1]:=60;
enemiesfreq[25,2]:=70;

lvltypes[26]:=3;
lvlenemies[26,0]:=5;
lvlenemies[26,1]:=6;
lvlenemies[26,2]:=10;
enemiesfreq[26,0]:=40;
enemiesfreq[26,1]:=60;
enemiesfreq[26,2]:=80;

lvltypes[27]:=3;
lvlenemies[27,0]:=7;
lvlenemies[27,1]:=8;
lvlenemies[27,2]:=9;
enemiesfreq[27,0]:=50;
enemiesfreq[27,1]:=60;
enemiesfreq[27,2]:=80;

lvltypes[28]:=4;
lvlenemies[28,0]:=7;
lvlenemies[28,1]:=6;
lvlenemies[28,2]:=9;
lvlenemies[28,3]:=10;
enemiesfreq[28,0]:=60;
enemiesfreq[28,1]:=40;
enemiesfreq[28,2]:=80;
enemiesfreq[28,3]:=90;

lvltypes[29]:=4;
lvlenemies[29,0]:=7;
lvlenemies[29,1]:=6;
lvlenemies[29,2]:=9;
lvlenemies[29,3]:=10;
enemiesfreq[29,0]:=60;
enemiesfreq[29,1]:=40;
enemiesfreq[29,2]:=80;
enemiesfreq[29,3]:=90;

lvltypes[30]:=4;
lvlenemies[30,0]:=5;
lvlenemies[30,1]:=8;
lvlenemies[30,2]:=9;
lvlenemies[30,3]:=11;
enemiesfreq[30,0]:=55;
enemiesfreq[30,1]:=40;
enemiesfreq[30,2]:=80;
enemiesfreq[30,3]:=90;



{ TABELE STATYSTYCZNE GRACZA }
shootrates[0].i:=110;
shootrates[1].i:=100;
shootrates[2].i:=80;
shootrates[3].i:=70;
shootrates[4].i:=60;
shootrates[5].i:=50;
shootrates[6].i:=40;
shootrates[7].i:=30;
shootrates[8].i:=25;
shootrates[9].i:=20;

shootrates[0].c:=0;
shootrates[1].c:=100;
shootrates[2].c:=200;
shootrates[3].c:=400;
shootrates[4].c:=800;
shootrates[5].c:=1250;
shootrates[6].c:=2500;
shootrates[7].c:=5000;
shootrates[8].c:=10000;
shootrates[9].c:=15000;

actrate:=0;

bulpower[0].i:=1;
bulpower[1].i:=2;
bulpower[2].i:=3;
bulpower[3].i:=4;
bulpower[4].i:=6;
bulpower[5].i:=8;
bulpower[6].i:=12;
bulpower[7].i:=15;
bulpower[8].i:=20;
bulpower[9].i:=30;

bulpower[0].c:=0;
bulpower[1].c:=300;
bulpower[2].c:=800;
bulpower[3].c:=1500;
bulpower[4].c:=2800;
bulpower[5].c:=3600;
bulpower[6].c:=5000;
bulpower[7].c:=7500;
bulpower[8].c:=11000;
bulpower[9].c:=15000;

actbul:=0;

plspeed[0].i:=0.1;
plspeed[1].i:=0.22;
plspeed[2].i:=0.35;
plspeed[3].i:=0.45;
plspeed[4].i:=0.63;
plspeed[5].i:=0.85;
plspeed[6].i:=1.3;
plspeed[7].i:=1.65;
plspeed[8].i:=2.5;
plspeed[9].i:=4;

plspeed[0].c:=0;
plspeed[1].c:=100;
plspeed[2].c:=170;
plspeed[3].c:=220;
plspeed[4].c:=300;
plspeed[5].c:=400;
plspeed[6].c:=700;
plspeed[7].c:=1500;
plspeed[8].c:=3000;
plspeed[9].c:=8000;

actplspeed:=0;


(*    ZMIENNE     *)
shottimes:=0;
hittimes:=0;
enemieskilled:=0;
enemieslost:=0;
slomomax:=200;

canbuyspeed:=true;
canbuypower:=true;
canbuyplspeed:=true;
showshop:=false;
lvltime:=0;
lvltimemax:=2500;
score:=0;
scoretrue:=score;
hp:=100;
maxeos:=50;
maxbul:=200;
gracz.shootrate:=shootrates[actrate].i;

gracz.x:=160;
gracz.y:=192;
gracz.length:=20;


gameovered:=false;
gameover:=0;
gameoverpal:=0;
gameovereffect:=false;


(*   PROCEDURY    *)
setpalette;
updatehudpal;
drawhud;
drawscore;


(* CZYNNIKI GLOWNE *)
drawbuffer;
gamestarted:=true;
lvl:=0;
preparenextlvl;
end;

procedure endgame;
begin

end;


procedure beginCount;
begin
  counting:=true;
  countint:=200;
end;

procedure draw3;
var i:byte;
begin
  for i:=0 to 9 do
    setcolor(47+i,0,i*4+25,0);
  VGAText(maxx div 2-30,20,47,'########',0);
  VGAText(maxx div 2-30,28,48,'########',0);
  VGAText(maxx div 2-30,36,49,'#    ###',0);
  VGAText(maxx div 2-30,44,50,'    ### ',0);
  VGAText(maxx div 2-30,52,51,'   ###  ',0);
  VGAText(maxx div 2-30,60,52,'    ### ',0);
  VGAText(maxx div 2-30,68,53,'     ###',0);
  VGAText(maxx div 2-30,76,54,'##  ####',0);
  VGAText(maxx div 2-30,84,55,'####### ',0);
  VGAText(maxx div 2-30,92,56,' #####  ',0);
end;

procedure draw2;
begin
  VGAText(maxx div 2-30,20,47,' #####  ',0);
  VGAText(maxx div 2-30,28,48,'####### ',0);
  VGAText(maxx div 2-30,36,49,'##   ## ',0);
  VGAText(maxx div 2-30,44,50,'     ## ',0);
  VGAText(maxx div 2-30,52,51,'    ##  ',0);
  VGAText(maxx div 2-30,60,52,'   ##   ',0);
  VGAText(maxx div 2-30,68,53,'  ##    ',0);
  VGAText(maxx div 2-30,76,54,' ##    #',0);
  VGAText(maxx div 2-30,84,55,'########',0);
  VGAText(maxx div 2-30,92,56,'########',0);
end;

procedure draw1;
begin
  VGAText(maxx div 2-30,20,47,'   ##   ',0);
  VGAText(maxx div 2-30,28,48,'  ###   ',0);
  VGAText(maxx div 2-30,36,49,' ####   ',0);
  VGAText(maxx div 2-30,44,50,' ####   ',0);
  VGAText(maxx div 2-30,52,51,'   ##   ',0);
  VGAText(maxx div 2-30,60,52,'   ##   ',0);
  VGAText(maxx div 2-30,68,53,'   ##   ',0);
  VGAText(maxx div 2-30,76,54,'   ##  #',0);
  VGAText(maxx div 2-30,84,55,'   #####',0);
  VGAText(maxx div 2-30,92,56,'########',0);
end;

procedure drawgo;
begin
  VGAText(maxx div 3,20,47,' ####   #### ',0);
  VGAText(maxx div 3,28,48,'###### ######',0);
  VGAText(maxx div 3,36,49,'##   # ##  ##',0);
  VGAText(maxx div 3,44,50,'##     #    #',0);
  VGAText(maxx div 3,52,51,'##     #    #',0);
  VGAText(maxx div 3,60,52,'##     #    #',0);
  VGAText(maxx div 3,68,53,'## ### #    #',0);
  VGAText(maxx div 3,76,54,'##   # ##  ##',0);
  VGAText(maxx div 3,84,55,'###### ######',0);
  VGAText(maxx div 3,92,56,' ####   #### ',0);
end;

procedure countDown;
begin

if countint>0 then countint:=countint-1;

if (countint<200) and (countint>151) then draw3
else
if (countint<150) and (countint>101) then draw2
else
if (countint<100) and (countint>51) then draw1
else
if countint<50 then
begin
drawgo;
counting:=false;
playinglvl:=true;
end;

End;



procedure preparenextlvl;
var
i:byte;
begin

if lvl=30 then welldone;

slomo:=slomomax;
canbuyplspeed:=true;
canbuyspeed:=true;
canbuypower:=true;
lvltime:=lvltimemax;
lvl:=lvl+1;
playinglvl:=false;
pause:=false;
showshop:=false;
setpalette;
beginCount;
end;


procedure checklvl;
var i,f:byte;s:string[3];
begin

f:=0;
  { czy juz nie ma przeciwnikow }
  for i:=0 to maxeos do
    if eos[i].exist=true then f:=f+1;
{
str(f,s);
VGAText(40,20,ered,s,0);
str(lvltime,s);
VGAText(40,30,ered+1,s,0);
if playinglvl=true then VGAText(40,40,eorange,'play True',0)
else VGAText(40,40,eorange,'play False',0);
if showshop=true then VGAText(40,50,eorange+1,'shop True',0)
else VGAText(40,50,eorange+1,'shop False',0);
}

if (playinglvl=true)and(lvltime>0) then lvltime:=lvltime-1;

{sprawdz na koniec poziomu -> shopmenu }
if lvltime=0 then begin

  if f=0 then begin
    playinglvl:=false;
    pause:=true;
    setpalette;
    showshop:=true;
  end;
end;

{ sprawdz na gameover }
if hp=0 then begin
  gameovereffect:=true;
  gameovered:=true;
  gameover:=100;
  gameoverpal:=1;
end;

End;







(*                              |
                                |
       PlAYER AND ENEMIES       |
                                |
                               *)



procedure atackEnemy(eid,bid:byte);
var i:byte;
begin
if eos[eid].hp>buls[bid].power then begin
   eos[eid].hp:=eos[eid].hp-buls[bid].power;
   removebullet(bid);
end
else if eos[eid].hp=buls[bid].power then begin
   removebullet(bid);
   score:=score+eos[eid].maxpoints - r2i(eos[eid].y / 7);
   scoretrue:=scoretrue+eos[eid].maxpoints - r2i(eos[eid].y / 7);
   removeEnemy(eid);
end
else if eos[eid].hp<buls[bid].power then begin
   buls[bid].power:=buls[bid].power-eos[eid].hp;
   score:=score+eos[eid].maxpoints - r2i(eos[eid].y / 7);
   scoretrue:=scoretrue+eos[eid].maxpoints - r2i(eos[eid].y / 7);
   removeEnemy(eid);
end;
hittimes:=hittimes+1;
end;




procedure atackPlayer(i:byte;t:char);
begin
if t='e' then
  if hp>eos[i].hp then hp:=hp-eos[i].hp
  else hp:=0
else
if t='b' then
  if hp>buls[i].power then hp:=hp-buls[i].power
  else hp:=0;

if hp>0 then atacked:=6;
end;




procedure addenemy(typ:byte);
var i,j,l:byte;s:string;
    xx:word;
    fun:enemyfunc;
    b:boolean;
begin
b:=false;
randomize;
{ sprawdz wolne miejsce }
for i:=0 to maxeos do
if eos[i].exist=false then begin
  eos[i].exist:=true;
  eos[i].y:=10;
  eos[i].hp:=enemies[typ].hp;
  l:=random(2);
  if l=0 then eos[i].xs:=enemies[typ].xs
  else eos[i].xs:=-enemies[typ].xs;
  eos[i].ys:=enemies[typ].ys;
  eos[i].maxpoints:=enemies[typ].maxpoints;
  eos[i].r:=enemies[typ].r;
  eos[i].x:=random(240-enemies[i].r)+(40+enemies[i].r);     { Losuj pozycje x }
  (*repeat

    for j:=0 to maxeos do          { dla kazdego istniejacego przeciwnika }
      if (eos[j].exist=true)and(eos[j].y<=eos[j].r) then begin
        if (r2i(eos[j].x)+eos[j].r < xx+eos[i].r)or(xx+eos[i].r < r2i(eos[j].x)-eos[j].r) then
        begin b:=true;break; end;
      end
      else b:=true;
  until b=true;*)

  {eos[i].x:=xx;}
  eos[i].func1:=enemies[typ].func1;
  eos[i].func2:=enemies[typ].func2;
  eos[i].func3:=enemies[typ].func3;
  eos[i].func4:=enemies[typ].func4;
  eos[i].func5:=enemies[typ].func5;
  eos[i].func6:=enemies[typ].func6;
  break;
end;

end;



procedure moveenemies;
var i:byte;
begin

for i:=0 to maxeos do
  if eos[i].exist=true then
  begin
    if r2i(eos[i].y)+eos[i].r < maxy then
      eos[i].y:=eos[i].y+eos[i].ys
    else begin
      atackPlayer(i,'e');
      removeenemy(i);
    end;


    if (r2i(eos[i].x) < eos[i].r+30) or (eos[i].x > 290-eos[i].r) then eos[i].xs:=-eos[i].xs;
        eos[i].x:=eos[i].x+eos[i].xs;
  end;
End;




procedure checkCol;
var i,j:byte;
begin

for i:=0 to maxeos do
  if eos[i].exist=true then
    for j:=0 to maxbul do
      if (buls[j].exist=true) and (buls[j].owner='p') then
        if
        (r2i(buls[j].x) > r2i(eos[i].x-eos[i].r)) and
        (r2i(buls[j].x) < r2i(eos[i].x+eos[i].r)) and
        (r2i(buls[j].y) > r2i(eos[i].y-eos[i].r)) and
        (r2i(buls[j].y) < r2i(eos[i].y+eos[i].r)) then
          atackEnemy(i,j)
      else if (buls[j].exist=true) and (buls[j].owner='e') then
        if
        (r2i(buls[j].x) > gracz.x+10) and
        (r2i(buls[j].x) < gracz.x-10) and
        (r2i(buls[j].y) > gracz.y+10) and
        (r2i(buls[j].y) < gracz.y-10) then
        atackPlayer(j,'b');
end;




procedure removeenemy(id:byte);
var fun:enemyfunc;
begin

drawspark(r2i(eos[id].x),r2i(eos[id].y),2);

eos[id].exist:=false;
eos[id].x:=0;
eos[id].y:=0;
eos[id].maxpoints:=0;
eos[id].r:=0;
eos[id].hp:=0;
eos[id].xs:=0;
eos[id].ys:=0;
fun.typ:=0;fun.x1:=0;fun.y1:=0;fun.x2:=0;fun.y2:=0;fun.r:=0;fun.c:=0;
eos[id].func1:=fun;
eos[id].func2:=fun;
eos[id].func3:=fun;
eos[id].func4:=fun;
eos[id].func5:=fun;
eos[id].func6:=fun;

end;


procedure shake(r:byte);
var x,y:word;
    sx,sy:byte;
begin

sx:=random(r);
sy:=random(r);

for y:=maxy downto 0 do
  for x:=maxx downto 0 do
    if (x+sx >= 0) and (y+sy >= 0) then
      pixel(x+sx,y+sy,getpixel(x,y));

End;










END.

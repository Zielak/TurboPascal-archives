program sortowanieLalala;

{$N+}
uses zvga,crt;

type
paletka = record
  up,dn:boolean;
  x,y,spd:single;
  height,width:byte;
end;
ball = record
  x,y,spd:single;
  up,le:boolean;
  r:byte;
end;

var
  endgame,pikb,pukb:boolean;

  pal1,pal2:paletka;
  bal:ball;



procedure initGame;
var i:byte;
begin
initvga;
initmouse;
initkey;

setcolor(1,63,63,63);

pal1.x:=300;
pal1.y:=maxy div 2;
pal1.spd:=1.5;
pal1.height:=30;
pal1.width:=10;

pal2.x:=20;
pal2.y:=maxy div 2;
pal2.spd:=1.5;
pal2.height:=30;
pal2.width:=10;

bal.x:=maxx div 2;
bal.y:=maxy div 2;
bal.r:=10;
bal.spd:=0.5;
i:=random(1);
if i=0 then bal.up:=true else bal.up:=false;
i:=random(1);
if i=0 then bal.le:=true else bal.le:=false;
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



procedure movePaletki;
begin
if keys[72]=true then pal1.up:=true else pal1.up:=false;
if keys[80]=true then pal1.dn:=true else pal1.dn:=false;
pal1.y:=pal1.y+pal1.spd*Ord(pal1.dn)-pal1.spd*Ord(pal1.up);
if pal1.y>maxy-pal1.height then pal1.y:=maxy-pal1.height;
if pal1.y<pal1.height      then pal1.y:=pal1.height;

if keys[17]=true then pal2.up:=true else pal2.up:=false;
if keys[31]=true then pal2.dn:=true else pal2.dn:=false;
pal2.y:=pal2.y+pal2.spd*Ord(pal2.dn)-pal2.spd*Ord(pal2.up);
if pal2.y>maxy-pal2.height then pal2.y:=maxy-pal2.height;
if pal2.y<pal2.height      then pal2.y:=pal2.height;
end;


procedure pik;
begin
sound(500);
delay(100);
nosound;
end;

procedure puk;
begin
sound(300);
delay(100);
nosound;
end;

procedure moveBall;
begin              { Direction 0^> 1_> 2<_ 3<^ }
if bal.up=true then  bal.y:=bal.y-bal.spd;
if bal.up=false then bal.y:=bal.y+bal.spd;
if bal.le=true then  bal.x:=bal.x-bal.spd;
if bal.le=false then bal.x:=bal.x+bal.spd;

if bal.y>maxy-bal.r then begin
   bal.y:=maxy-bal.r;
   bal.up:=true;
   pikb:=true;
end;
if bal.y<bal.r then begin
   bal.y:=bal.r;
   bal.up:=false;
   pikb:=true;
end;
if bal.x>maxx-bal.r then begin
   bal.x:=maxx-bal.r;
   bal.le:=true;
   pukb:=true;
end;
if bal.x<bal.r then begin
   bal.x:=bal.r;
   bal.le:=false;
   pukb:=true;
end;

End;



procedure speedUp;
begin
bal.spd:=bal.spd+0.002;
end;



procedure drawPaletki;
begin
box(r2i(pal1.x)-pal1.width, r2i(pal1.x)+pal1.width, r2i(pal1.y)-pal1.height, r2i(pal1.y)+pal1.height, 1, true);
box(r2i(pal2.x)-pal2.width, r2i(pal2.x)+pal2.width, r2i(pal2.y)-pal2.height, r2i(pal2.y)+pal2.height, 1, true);
end;

procedure drawBall;
begin
box(r2i(bal.x)-bal.r, r2i(bal.x)+bal.r, r2i(bal.y)-bal.r, r2i(bal.y)+bal.r, 1, true);
end;




BEGIN

initGame;



repeat
cls(0);

{ OBLICZENIA }
movePaletki;
moveBall;
speedUp;


{ GRAFIKA }
drawPaletki;
drawBall;


drawpage;
if pikb=true then begin pik; pikb:=false; end;
if pukb=true then begin puk; pukb:=false; end;
czekaj;
if keys[1]=true then endgame:=true;
until endgame=true;

end.
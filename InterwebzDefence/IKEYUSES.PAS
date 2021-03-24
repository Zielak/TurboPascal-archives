program ikeyuses;

uses crt,zvga;

var i:byte;
    s:string;


begin


initvga;
InitKey;
InitMouse;

setcolor(0,0,0,0);
setcolor(1,50,0,0);
setcolor(2,50,50,50);

repeat

cls(0);
box(0,maxx,0,3,1,true);
for i:=0 to maxx div 2 do
linev(i*2,0,3,2);

for i:=0 to 128 do
if keys[i]=true then begin
linev(i*2,4,7,1);
str(i,s);
if i>58 then VGAText(57,8+(i-58)*3,2,s,0) else VGAText(50,8+i*3,2,s,0);
end;

drawpage;
czekaj;

until mousebtn=1;


killkey;
closevga;

end.
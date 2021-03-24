program InterwebzDefence;


uses crt,zvga,idengin; { 320x200x256 }

var q:char;
    i:byte;


BEGIN

delay(2000);

(*    INICJACJA   *)
initvga;
InitKey;
cls(0);

setintpal;

repeat
Old;

initmenu;
repeat
if keys[1]=true then drawexit;
until keys[28]=true;

delay(500);

drawintro;

initgame;


REPEAT

{VGAText(100,15,8,'3791 lines of code! :O',0);}

{                    |
                     |
  GLOWNE KALKULACJE  |
                     |
                     }
drawbuffer;                  { rysowanie calosci }
IF (gameovered=false) then begin
  getpause;                    { Pobranie pauzy }
  if pause=false then ingame;  { glowny czynnik }
end;
(*                 }
                   }
   zrzut buforu    }
                   }
                  *)
drawpage;
czekaj;




until keys[1]=true;

until keys[1]=true;

drawexit;

LimitX(0,639);
LimitY(0,399);
closevga;

end.
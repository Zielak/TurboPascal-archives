unit Mysz;
interface
uses Dos;

var Regs:registers;
    xm,ym,sxm,sym:integer;
    button:word;

function InitMouse:boolean;
procedure MShow;
procedure MHide;
procedure GetPos;
procedure GetPos13;
procedure SetPos(x,y:word);
procedure LimitX(min,max:word);
procedure LimitX13(min,max:word);
procedure LimitY(min,max:word);
procedure Old;
function inside(x1,y1,x2,y2,x,y: integer): boolean;

implementation

function InitMouse;
begin
  Regs.AX:=0;
  Intr($33,Regs);
  if Regs.AX=0 then InitMouse:=True else InitMouse:=False;
end;

procedure MShow;
begin
  Regs.AX:=1;
  Intr($33,Regs);
end;

procedure MHide;
begin
  Regs.AX:=2;
  Intr($33,Regs);
end;

procedure GetPos;
begin
  Regs.AX:=3;
  Intr($33,Regs);
  xm:=Regs.CX;
  ym:=Regs.DX;
  Button:=Regs.BX;
end;

procedure GetPos13;
begin
  Regs.AX:=3;
  Intr($33,Regs);
  xm:=Regs.CX shr 1;
  ym:=Regs.DX;
  Button:=Regs.BX;
end;

procedure SetPos(x,y:word);
begin
  Regs.AX:=4;
  Regs.CX:=x;
  Regs.DX:=y;
  Intr($33,Regs);
end;

procedure LimitX(min,max:word);
begin
  Regs.AX:=7;
  Regs.CX:=min;
  Regs.DX:=max;
  intr($33,Regs);
end;

procedure LimitX13(min,max:word);
begin
  Regs.AX:=7;
  Regs.CX:=min shl 1;
  Regs.DX:=max shl 1;
  intr($33,Regs);
end;

procedure LimitY(min,max:word);
begin
  Regs.AX:=8;
  Regs.CX:=min;
  Regs.DX:=max;
  intr($33,Regs);
end;

procedure Old;
begin
  sxm:=xm;
  sym:=ym;
end;


function inside(x1,y1,x2,y2,x,y: integer): boolean;
  begin
    inside:= (x>=x1) and (x<=x2) and
             (y>=y1) and (y<=y2);
  end;

begin
  InitMouse;
end.
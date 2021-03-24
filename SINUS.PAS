unit sinus;
interface
procedure Oblicz;
function _Sin(k:word):real;
function _Cos(k:word):real;

var sint,cost:array[0..359] of real;

implementation

procedure Oblicz;
var k:word;
begin
  for k:=0 to 359 do
  begin
    sint[k]:=sin(k*pi/180);
    cost[k]:=cos(k*pi/180);
  end;
end;

function _Sin(k:word):real;
begin
  _Sin:=sint[k];
end;

function _Cos(k:word):real;
begin
  _Cos:=cost[k];
end;

begin
  Oblicz;
end.
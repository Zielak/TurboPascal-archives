program SickRacing;

uses graph,crt;

var
grDriver: Integer;
grMode: Integer;
ErrCode: Integer;

procedure startGraph;

BEGIN
grDriver := Detect;
InitGraph(grDriver, grMode,' ');
ErrCode := GraphResult;
if ErrCode = grOk then
begin  { Do graphics }
  Line(0, 0, GetMaxX, GetMaxY);
  Readln;
  CloseGraph;
end
else Writeln('Graphics error:', GraphErrorMsg(ErrCode));
END;



BEGIN
clrscr;
startGraph;

repeat
until keypressed;

END.

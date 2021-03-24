
uses Crt;

var
  X, Y: Byte;
  Arr : array[0..2] of integer;
begin
  Arr[0]:=2;
  Arr[1]:=4;
  Arr[2]:=7;
  TextBackground(Black);   { Clear screen }
  ClrScr;
  repeat
    X := Succ(Random(80));   { Draw random windows }
    Y := Succ(Random(50));
    Window(X, Y, X + Random(10), Y + Random(8));
    TextBackground(Arr[random(3)]);   { In random colors }
    ClrScr;
  until KeyPressed;
end.


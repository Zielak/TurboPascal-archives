uses crt, grafix;

var
  i : byte;

procedure xchange (a, b : byte);                { color xchange for spheres }
var i, ar, ag, ab, br, bg, bb : byte;
begin
  for i := 32 to 63 do begin
    getcrgb (64*a+i, ar, ag, ab);
    getcrgb (64*b+i, br, bg, bb);
    setcrgb (64*b+i, ar, ag, ab);
    setcrgb (64*a+i, br, bg, bb);
  end;
  delay (250)
end;

begin
  initgraph;
  for i := 32 to 63 do begin                    { 32-dark, 63-bright }
    setcrgb (i, i, 0, 0);                       { only red component }
    setcrgb (64+i, i, i, 0);                    { red & green = yellow }
    setcrgb (128+i, 0, i, 0);                   { only green component }
  end;
  setcrgb (0, 0,0,63);                          { blue background }
  for i := 32 to 63 do begin
    circle (64, 100, 64-i, i, true);            { red sphere }
    circle (160, 100, 64-i, 64+i, true);        { yellow sphere }
    circle (320-64, 100, 64-i, 128+i, true);    { and a green one }
  end;
  randomize;
  while not keypressed do begin
    xchange (random(3), random(3))              { now xchanging colors }
  end;
  while keypressed do readkey;
  closegraph
end.

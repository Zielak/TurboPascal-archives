uses grafix;

var
  n,
  x, y : word;
  r, c : byte;
  pal  : tpal;

begin
  randomize;
  initgraph;
  for n := 1 to 1000 do begin
    x := 50 + random(maxx-100);
    y := 50 + random(maxy-100);
    r := random (50);
    c := random (maxcolor+1);
    circle (x, y, r, c, true);
    circle (x, y, r, not c, false)
  end;
  getpal (pal);
  readln;
  fadedown;
  readln;
  fadeup (pal);
  readln;
  savepcx256 ('circles.pcx', 0, 0, 320, 200);
  closegraph
end.

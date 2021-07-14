uses crt,grafix;

var
  s : string;
  x, y : word;

begin
  loadfont ('6x7.fnt', curfont, fontsize);
  setfont (curfont);
  initgraph;
  clearscreen (3);
  s := 'fncvn';
  reads (100, 100, black, white, s, 8);
  for y := 0 to maxy do
    for x := 0 to maxx do
      putpixel (x, y, random(249));
  readln;
  closegraph;
  freemem (curfont, fontsize)
end.

uses crt, grafix, gfxfont;

const
  back = black;
  text = green;

var
  c : char;
  x, y : word;

begin
  setfont(@font6x7);
  initgraph;
  x := 0;
  y := 0;
  clearscreen (back);
  for c := #0 to #255 do
    begin
      writes (x, y, text, text, c);
      inc (x, fontx);
      if x > 15*fontx then
        begin
          x := 0;
          inc (y, fonty)
        end
    end;
  while not keypressed do;
  while keypressed do readkey;
  closegraph
end.

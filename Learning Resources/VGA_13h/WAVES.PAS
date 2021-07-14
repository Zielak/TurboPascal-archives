uses crt, grafix;

var
  c : char;
  pal : tpal;

procedure setuppal;
var
  c : byte;
  r, g, b : real;
begin
  pal[0,1] := 0;
  pal[0,2] := 0;
  pal[0,3] := 0;
  pal[1,1] := 15;
  pal[1,2] := 15;
  pal[1,3] := 15;
  pal[2,1] := 31;
  pal[2,2] := 31;
  pal[2,3] := 31;
  pal[3,1] := 63;
  pal[3,2] := 63;
  pal[3,3] := 63;

  r := 63; g := 0; b := 0;
  for c := 0 to 41 do begin
    pal[4+c,1] := round(r);
    pal[4+c,2] := round(g);
    pal[4+c,3] := round(b);
    g := g + 63/42
  end;

  r := 63; g := 63; b := 0;
  for c := 0 to 41 do begin
    pal[4+42+c,1] := round(r);
    pal[4+42+c,2] := round(g);
    pal[4+42+c,3] := round(b);
    r := r - 63/42
  end;

  r := 0; g := 63; b := 0;
  for c := 0 to 41 do begin
    pal[4+2*42+c,1] := round(r);
    pal[4+2*42+c,2] := round(g);
    pal[4+2*42+c,3] := round(b);
    b := b + 63/42
  end;

  r := 0; g := 63; b := 63;
  for c := 0 to 41 do begin
    pal[4+3*42+c,1] := round(r);
    pal[4+3*42+c,2] := round(g);
    pal[4+3*42+c,3] := round(b);
    g := g - 63/42
  end;

  r := 0; g := 0; b := 63;
  for c := 0 to 41 do begin
    pal[4+4*42+c,1] := round(r);
    pal[4+4*42+c,2] := round(g);
    pal[4+4*42+c,3] := round(b);
    r := r + 63/42
  end;

  r := 63; g := 0; b := 63;
  for c := 0 to 41 do begin
    pal[4+5*42+c,1] := round(r);
    pal[4+5*42+c,2] := round(g);
    pal[4+5*42+c,3] := round(b);
    b := b - 63/42
  end;

  setpal (pal)
end;

procedure drawwaves;
var c : word;
begin
{  for c := 254-33 to 254 do
    linev (c-254+33, 0, 200, c);}
  for c := 4 to 255 do
    linev (34+c-4, 0, 200, c);
{  for c := 4 to 4+33 do
    linev (320-34+c-4, 0, 200, c);}
end;

begin
  initgraph;
  setuppal;
  drawwaves;
  repeat
    if keypressed then c := readkey
    else c := #$ff;
  until c = #27;
  savepcx256 ('waves.pcx', 0, 0, 320, 200);
  closegraph
end.

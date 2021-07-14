uses crt, grafix, gfxfont;

const
  xsz = 80;                             { x-dimension of fire array }
  ysz = 100;                            { y-dimension of fire array }
  l = 320 div xsz;                      { fire element's x-size }
  h = 200 div ysz;                      { rire element's y-size }

var
  a : array [0..xsz*ysz-1] of byte;     { array of fire elements }
  ps : pointer;                         { pointer to the virtual screen }

procedure set_fire_pal;   { sets fire palette }
var
  i : word;
begin
  { 0..15 - standard colors }
  for i := 0 to 47 do
    setcrgb (16+i, trunc({32+0.66666666*i}16+i), 0, 0); { black -> red }
  for i := 0 to 95 do
    setcrgb (16+48+i, 63, trunc(0.66666666*i), 0);      { red -> yellow }
  for i := 0 to 95 do
    setcrgb (16+48+96+i, 63, 63, trunc(0.66666666*i))   { yellow -> white }
end;

procedure new;          { calcs new bottom line }
var i : word;
begin
  for i := 0 to xsz-1 do
    a[xsz*(ysz-1)+i] := 16+random(240)
end;

procedure calc;         { calcs other lines }
var i, c : word;
begin
  for i := xsz to xsz*ysz-1 do begin
    c := (a[i]+a[i-1]+a[i+1]+a[i+xsz]) shr 2;      { standard fire }
(*    c := (a[i]{+a[i-1]}+a[i+1]+a[i+xsz]) div 3;  { fire moves to the left } *)
(*    c := (a[i]+a[i-1]{+a[i+1]}+a[i+xsz]) div 3;  { fire moves to the right }*)
    if c <> 0 then dec (c);                        { decrement intensivity }
    if c < 16 then c := 0;                         { skip standard colors }
    a[i-xsz] := c
  end;
end;

procedure out;          { outputs fire }
var x, y, k : word;
begin
  k := 0;
  x := 0; y := 0;
  for k := 0 to xsz*(ysz-3)-1 do begin          { "-3" - remove first lines }
    box (x, y, l, h, a[k], true);
    inc (x, l);
    if x >= 320 then begin
      x := 0;
      inc (y, h)
    end
  end
end;

begin
  getmem (ps, 64000);
  setactivepage (seg(ps^));     { setting active page (virtual screen) }
  clearscreen (black);
  initgraph;
  setfont (@font6x7);           { setting font }
  set_fire_pal;
  randomize;
  repeat
    new;
    calc;
    out;
    writes (125, 100, lightgreen, lightgreen, 'Fire effect');
    displaypage (seg(ps^))      { displaying virtual screen }
  until keypressed;
  while keypressed do readkey;
  closegraph;
  freemem (ps, 64000)
end.

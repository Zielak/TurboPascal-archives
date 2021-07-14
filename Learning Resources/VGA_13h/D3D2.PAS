program draw3d;

uses crt, grafix;

Var
  pbob : pointer;

type
  ptrig = ^ttrig;
  ttrig = array[-360..360] of real;
  pobj3d = ^tobj3d;
  tobj3d = record
    x1, y1, z1, x2, y2, z2 : real;
    next : pobj3d
  end;

var
  psin, pcos : ptrig;

procedure setuptrig (var psin, pcos : ptrig);
var
  i   : integer;
  rad : real;
begin
  new (psin); new (pcos);
  for i := -360 to 360 do
    begin
      rad := i*pi/180;
      psin^[i] := sin(rad);
      pcos^[i] := cos(rad)
    end
end;

procedure setupquad (var po : pobj3d; a : real);
var p1, p2 : pobj3d;
begin
  new (po);
  p2 := po;
  p1 := p2;
  p1^.x1 := -a/2;  p1^.y1 := -a/2;  p1^.z1 := 0;
  p1^.x2 := a/2;  p1^.y2 := -a/2;  p1^.z2 := 0;
  new (p2);
  p1^.next := p2;
  p1 := p2;
  p1^.x1 := a/2;  p1^.y1 := -a/2;  p1^.z1 := 0;
  p1^.x2 := a/2;  p1^.y2 := a/2;  p1^.z2 := 0;
  new (p2);
  p1^.next := p2;
  p1 := p2;
  p1^.x1 := a/2;  p1^.y1 := a/2;  p1^.z1 := 0;
  p1^.x2 := -a/2;  p1^.y2 := a/2;  p1^.z2 := 0;
  new (p2);
  p1^.next := p2;
  p1 := p2;
  p1^.x1 := -a/2;  p1^.y1 := -a/2;  p1^.z1 := 0;
  p1^.x2 := -a/2;  p1^.y2 := a/2;  p1^.z2 := 0;
  p1^.next := nil
end;

procedure rotate (var pobj : pobj3d; dx, dy, dz : integer);
var
  p : pobj3d;
  x, y, z : real;
begin
  p := pobj;
  while p <> nil do
    begin
      if dz <> 0 then
        begin
          x := p^.x1*pcos^[dz]-p^.y1*psin^[dz];
          y := p^.x1*psin^[dz]+p^.y1*pcos^[dz];
          p^.x1 := x;
          p^.y1 := y;
          x := p^.x2*pcos^[dz]-p^.y2*psin^[dz];
          y := p^.x2*psin^[dz]+p^.y2*pcos^[dz];
          p^.x2 := x;
          p^.y2 := y
        end;
      if dy <> 0 then
        begin
          z := p^.z1*pcos^[dy]-p^.x1*psin^[dy];
          x := p^.z1*psin^[dy]+p^.x1*pcos^[dy];
          p^.z1 := z;
          p^.x1 := x;
          z := p^.z2*pcos^[dy]-p^.x2*psin^[dy];
          x := p^.z2*psin^[dy]+p^.x2*pcos^[dy];
          p^.z2 := z;
          p^.x2 := x
        end;
      if dx <> 0 then
        begin
          y := p^.y1*pcos^[dx]-p^.z1*psin^[dx];
          z := p^.y1*psin^[dx]+p^.z1*pcos^[dx];
          p^.y1 := y;
          p^.z1 := z;
          y := p^.y2*pcos^[dx]-p^.z2*psin^[dx];
          z := p^.y2*psin^[dx]+p^.z2*pcos^[dx];
          p^.y2 := y;
          p^.z2 := z
        end;
      p := p^.next
    end;
end;

procedure wobj (pobj : pobj3d; x, y, z : integer; c : byte);
var
  x1, y1, x2, y2 : real;
begin
  while pobj <> nil do
    begin
      x1 := x + 256*pobj^.x1 / (z-pobj^.z1);
      y1 := y + 256*pobj^.y1 / (z-pobj^.z1);
      x2 := x + 256*pobj^.x2 / (z-pobj^.z2);
      y2 := y + 256*pobj^.y2 / (z-pobj^.z2);
      if (x1 >= 0) and (x1 <= maxx) and (y1 >= 0) and (y1 <= maxy) and
         (x2 >= 0) and (x2 <= maxx) and (y2 >= 0) and (y2 <= maxy) then
            line (round(x1), round(y1), round(x2), round(y2), c);
      pobj := pobj^.next
    end;
end;

Function ClockWize (X1,Y1, X2,Y2, X3,Y3, X4,Y4 : LongInt) : Integer;
Var
  CW : LongInt;
  Xmin, Xmax, Ymin, Ymax : Integer;
Label LEnd;
Begin
  Xmin := X1; Xmax := X1;
  If X2 < Xmin then Xmin := X2;
  If X3 < Xmin then Xmin := X3;
  If X4 < Xmin then Xmin := X4;
  If X2 > Xmax then Xmax := X2;
  If X3 > Xmax then Xmax := X3;
  If X4 > Xmax then Xmax := X4;
  Ymin := Y1; Ymax := Y1;
  If Y2 < Ymin then Ymin := Y2;
  If Y3 < Ymin then Ymin := Y3;
  If Y4 < Ymin then Ymin := Y4;
  If Y2 > Ymax then Ymax := Y2;
  If Y3 > Ymax then Ymax := Y3;
  If Y4 > Ymax then Ymax := Y4;
  If (Ymin = Ymax) or (Xmin = Xmax) then Begin
    CW := 0;
    Goto LEnd
  End;
  CW := X1*Y2-Y1*X2 + X2*Y3-Y2*X3 + X3*Y4-Y3*X4 + X4*Y1-Y4*X1;
  If CW > 0 then CW := 1 Else If CW < 0 then CW := -1;
LEnd:
  ClockWize := CW
End;

procedure fill_quad (pobj : pobj3d; x,y,z:integer; c : byte);
var
  p : array [1..4] of tpoint;
begin
  p[1].x := round( x + 256 * pobj^.x1 / (z+pobj^.z1) );
  p[1].y := round( y + 256 * pobj^.y1 / (z+pobj^.z1) );
  p[2].x := round( x + 256 * pobj^.x2 / (z+pobj^.z2) );
  p[2].y := round( y + 256 * pobj^.y2 / (z+pobj^.z2) );
  pobj := pobj^.next^.next;
  p[3].x := round( x + 256 * pobj^.x1 / (z+pobj^.z1) );
  p[3].y := round( y + 256 * pobj^.y1 / (z+pobj^.z1) );
  p[4].x := round( x + 256 * pobj^.x2 / (z+pobj^.z2) );
  p[4].y := round( y + 256 * pobj^.y2 / (z+pobj^.z2) );
  If C <> 0 then
  Case ClockWize(p[1].x,p[1].y,p[2].x,p[2].y,p[3].x,p[3].y,p[4].x,p[4].y) of
    1:texturemappoly (p[1].x,p[1].y,p[2].x,p[2].y,p[3].x,p[3].y,p[4].x,p[4].y,
                      128,128,seg(pbob^));
    -1:FillPoly (4,P,19)
  End
  Else FillPoly (4,P,0)
end;

var
  c : char;
  pquad1, pquad2, pquad3 : pobj3d;
  deg, x1, y1, z1, x2, y2, z2, x3, y3, z3 : integer;
  s2 : pointer;
  f : file;
  pal : tpal;

begin
  getmem (pbob, 128*128);
  assign (f, 'side1.cel');
  reset (f, 1); seek (f, 32);
  blockread (f, pal, sizeof(tpal));
  blockread (f, pbob^, 128*128);
  close (f);
  getmem (s2, 64000);
  setuptrig (psin, pcos);
  initgraph;

  setpal (pal);
  border (white);

  pquad1 := nil;
  setupquad (pquad1, 40);
  x1 := maxx div 4;
  y1 := maxy div 3;
  z1 := 128;
  pquad2 := nil;
  setupquad (pquad2, 40);
  x2 := maxx - x1;
  y2 := maxy div 3;
  z2 := 128;
  pquad3 := nil;
  setupquad (pquad3, 40);
  x3 := maxx div 2;
  y3 := 2*maxy div 3;
  z3 := 128;
  setactivepage (seg(s2^));
  clearscreen (0);
  displaypage (seg(s2^));
  deg := 5;
  repeat
    if keypressed then c := readkey
    else c := #$FF;
    if c = #27 then break;
    fill_quad (pquad1, x1, y1, z1, 1);
    fill_quad (pquad2, x2, y2, z2, 1);
    fill_quad (pquad3, x3, y3, z3, 1);
    displaypage (seg(s2^));
    fill_quad (pquad1, x1, y1, z1, 0);
    fill_quad (pquad2, x2, y2, z2, 0);
    fill_quad (pquad3, x3, y3, z3, 0);
    rotate (pquad1, 2*deg, 0, 0);
    rotate (pquad2, 0, deg, 0);
    rotate (pquad3, 0, 0, 3*deg);
    delay(75);
  until false;
  border (black);
  closegraph;
  freemem (s2, 64000);
  freemem (pbob, 128*128)
end.

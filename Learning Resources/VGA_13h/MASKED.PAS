uses crt, grafix;

var
  pb,
  ps : pointer;
  s,
  x  : word;
  c  : char;
  l  : longint;

begin
  loadfont ('6x7.fnt', curfont, fontsize);
  setfont (curfont);
  loadobject ('masked.vob', pb, s);
  initgraph;
  clearscreen (3);
  writes (70, 104, white, white, '<1> & <2> - move; <Esc> - Exit');
  x := 50;
  getmem (ps, 14*14+4);
  getimage (x, 100, 14, 14, ps^);
  putimagem (x, 100, pb^);
  repeat
    if keypressed then c := readkey
    else c := #$FF;
    case c of
      #27 : break;
      '1' :
        begin
          putimage (x, 100, ps^);
          if x > 5 then dec (x, 2);
          getimage (x, 100, 14, 14, ps^);
          putimagem (x, 100, pb^)
        end;
      '2' :
        begin
          putimage (x, 100, ps^);
          if x < 300 then inc (x, 2);
          getimage (x, 100, 14, 14, ps^);
          putimagem (x, 100, pb^)
        end;
    end;
  until false;
  closegraph;
  freemem (ps, 14*14+4);
  freemem (pb, s);
  freemem (curfont, fontsize);
end.

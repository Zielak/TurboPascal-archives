uses crt, grafix;

var
  s : word;
  p : pointer;
  pal : tpal;
  c : char;
  x, y : integer;

label lerr;

begin
  loadpcx256 ('grim.pcx', p, s, pal);
  if grresult <> grok then begin
    writeln ('Error in PCX-file.');
    exit
  end;
  initgraph;
  setpal (pal);
  x := 0; y := 0;
  border (green);
  putclippedimage (x, y, p^);
  repeat
    if keypressed then c := readkey
    else c := #$FF;
    case c of
      'K':
        Begin
          clearscreen (0);
          dec (x, 8);
          putclippedimage (x, y, p^);
        End;
      'M':
        Begin
          clearscreen (0);
          inc (x, 8);
          putclippedimage (x, y, p^);
        End;
      'H':
        Begin
          clearscreen (0);
          dec (y, 8);
          putclippedimage (x, y, p^);
        End;
      'P':
        Begin
          clearscreen (0);
          inc (y, 8);
          putclippedimage (x, y, p^);
        End;
      #27 : break;
    end;
  until false;
  freemem (p, s);
  while not keypressed do;
  while keypressed do readkey;
  closegraph
end.

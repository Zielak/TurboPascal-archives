uses crt,grafix,gfxfont,roller;                 { gfxfont.tpu contains font }

var c : char;

begin
  initgraph;

  curfont := @font6x7;                          { setting current font addr }
  fontx := 6; fonty := 7;                       { setting font dimensions }
  clearscreen (cyan);

  box (100, 100, 80, 40, yellow, true);         { drawing          }
  box (100, 100, 80, 40, red, false);           {         anything }
  writes (120, 120, red, lightgreen, 'Hello!'); {   to be scrolled }
  box (89, 69, 202, 102, lightmagenta, false);  { frame for scrolling area }

  writes (0, 0, white, white,
          'Press Left, Right, Up or Down to scroll box in the');
  writes (0, 8, white, white,
          'same direction or press ESC to quit.');

  c := #$FF;
  repeat
    if keypressed then c := readkey;
    if c = 'K' then
      scrollleft2 (90, 70, 200, 100);           { scrolling our area left }
    if c = 'M' then
      scrollright2 (90, 70, 200, 100);          { scrolling our area right }
    if c = 'H' then
      scrollup2 (90, 70, 200, 100);             { scrolling our area up }
    if c = 'P' then
      scrolldown2 (90, 70, 200, 100);           { scrolling our area down }
    until c = #27;
  closegraph;
end.

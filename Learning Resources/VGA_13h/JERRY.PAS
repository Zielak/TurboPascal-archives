uses crt, grafix, glib, keypres2;

const
  nlib = 'jerry.vlb';                           { library file name }
  cnt = 14;                                     { phase's count }

var
  llist : plitem;                               { list of ^ pictures info (in lib) }
  dir,                                          { direction of moving }
  faz,                                          { phase no }
  i, j  : byte;
  x  : word;                                    { x coordinate of jerry }
  pm : array [0..1,0..cnt-1] of pointer;        { pointers to phase pictures }
  s  : array [0..1,0..cnt-1] of word;           { sizes of phase pictures }
  sbk : word;                                   { size of background picture }
  bk,                                           { pointer to backgr. picture }
  pua: pointer;                                 { pointer to save area }

function ss (i : byte) : string;
var s : string;
begin
  str (i, s);
  while length(s) < 2 do s := '0'+s;
  ss := s
end;

label
  lce;
begin
  getliblist (nlib, llist);             { getting library info for each picture }
  for i := 0 to cnt-1 do                { loading pictures from library }
    begin
      loadlibobject (nlib, finditem(llist,'JRYL'+ss(i)+'.VOB')^.rel, pm[0,i], s[0,i]);
      loadlibobject (nlib, finditem(llist,'JRYR'+ss(i)+'.VOB')^.rel, pm[1,i], s[1,i])
    end;
  loadobject ('wall.vob', bk, sbk);             { load background picture }
  initgraph;
  putimage (0, 0, bk^);                         { drawing background picture }
  freemem (bk, sbk);                            { deallocating it's memory }
  lineh (10, 132, 300, lightgray);              { line - floor }
  x := maxx div 2;                              { center position of jerry }
  dir := 1;                                     { moving on the right }
  faz := 1;                                     { 1-st phase of animation }
  getmem (pua, imagesize(28,32));               { allocating memory for save area }
  getimage (x, 100, 28, 32, pua^);              { saving area under jerry }
  putimagem (x, 100, pm[dir,faz]^);             { drawing jerry's phase pic }
  j := 0;

  waitforacsreleased;
  set_handler;                                  { set keyboard handler }

  repeat

    if KeyMap[sLeft] or KeyMap[sRight] = False then
      if faz > 1 then
      Begin
        faz := {1}0;
        putimage (x, 100, pua^);
        putimagem (x, 100, pm[dir,faz]^);
        delay (100)
      End
      else if faz=0 then
      Begin
        faz := 1;
        putimage (x, 100, pua^);
        putimagem (x, 100, pm[dir,faz]^)
      End;

    if KeyMap[sSpace] and (faz = 1) then                { press space & look at eyes }
      begin
        putimagem (x, 100, pm[dir,13]^);
        delay (150);
        putimagem (x, 100, pm[dir,faz]^)
      end;

    delay (30);
      begin
          if KeyMap[sLeft] then                         { pressing left }
            begin
              if dir = 1 then                   { change direction to another }
                begin
                  dir := 0;
                  putimage (x, 100, pua^);
                end
              else                              { have a next phase of animation }
                begin
                  inc (faz);
                  if faz = 13 then faz := 2;
                  putimage (x, 100, pua^);
                  if x > 10 then dec (x, 6)
                end;
              getimage (x, 100, 28, 32, pua^);
              putimagem (x, 100, pm[dir,faz]^);
            end;
          if KeyMap[sRight] then                        { pressing right }
            begin
              if dir = 0 then                   { change direction to another }
                begin
                  dir := 1;
                  putimage (x, 100, pua^);
                end
              else                              { have a next phase of animation }
                begin
                  inc (faz);
                  if faz = 13 then faz := 2;
                  putimage (x, 100, pua^);
                  if x < 280 then inc (x, 6)
                end;
              getimage (x, 100, 28, 32, pua^);
              putimagem (x, 100, pm[dir,faz]^);
            end;
        end;
  until KeyMap[sEsc];

  remove_handler;                       { remove keyboard handler }

  closegraph;
  freemem (pua, imagesize(28,32));      { deallocating memory of save area }
  for j := 0 to 1 do
    for i := 0 to cnt-1 do
      freemem (pm[j,i], s[j,i]);        { deallocating memory of phase pics }
  dellist (llist)                       { deallocating memory of info list }
end.

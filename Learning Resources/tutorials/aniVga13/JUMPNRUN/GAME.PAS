Program Game;

{$X+}

Uses
   Anivga, Crt, Dos, Music;

Const
   Apples : Array[0..1,0..9] of Integer =((280,260,5,15,200,240,305,260,80,0),
                                          (120,90,95,70,60,5,60,35,120,0));

   TileName2    ='esp.COD';   {4 tiles}
   tiles_per_row=4;           {These are the proportions of }
   tiles_per_column=4;        {the above 4 tile file: 2x2!  }
   BlokName     = 'line.cod';
   BlokHantel   = 50;
   Blok         = 50;
   FellowName   = 'smallnumo.lib';
   FellowHantel = 30;
   Fellow       = 30;
   MaxX         = 190;
   MinX         = 10;
   Apple        = 90;
   AppleHantel  = 90;
   Spook        = 10;
   SpookHantel  = 10;

var
  PicsLoaded,
           T,
 FellowImage,   {* actual fellow image   *}
      Teller,   {* counting variable     *}
     dx_left,   {* velocity to the left  *}
    dx_right,   {* velocity to the right *}
          dy,   {* vertical velocity     *}
       score,   {* score                 *}
      OldFel,   {* old fellow image      *}
 Totalapples,   {* apples got till now   *}
       Level,   {* which level?          *}
        ydir    {* used for 'lift'       *}

                : Integer;

       Right,   {* right arrow key pressed*}
        Left,   {* left arrow key pressed *}
   FirstLeft,   {* the first time to left *}
  FirstRight,   {* the first time to right*}
        Jump,   {* jump key pressed       *}
     Jumping,   {* busy with jumping      *}
     Falling,   {* busy with falling      *}
        Stop,   {* stop program           *}
    OnGround,   {* reached the ground     *}
     NoMusic    : boolean;

    scorestr,   {* necessary for display  *}
    levelstr    {* necessary for display  *}
                : String;

          x,
          y     : real;

     OldInt9: procedure;

       ScoreScr : Pointer;
   
Procedure trapCtrlAltDel; interrupt;
begin
    case Port[$60] of
        1: Stop   := True;
       83: NoMusic:= Not NoMusic;
       75: Left   := True;
       77: Right  := True;
       29: Jump   := True;
      157: Jump   := False;
      203: Left   := False;
      205: Right  := False;

    end;

    Inline ($E4/$61/$8A/$E0/$0C/$80/     { clean up as BIOS would }
          $E6/$61/$86/$E0/$E6/$61/       { (from Ohlsen & Stoker, }
          $B0/$20/$E6/$20);              { TP Advanced Techniques) }
end;

procedure installTrap;
begin
   getintVec($09,@oldInt9);
   setintVec($09,Addr(trapCtrlAltDel));
end;

procedure uninstallTrap;
begin
   setintVec($09,@oldInt9);
end;


procedure InitBackGround;
VAR gx,gy,count:INTEGER;
    Row:WORD;
begin

 XTiles:=0; YTiles:=0;
 SetBackgroundMode(scrolling);
 SetBackgroundScrollRange(0,-250,378,550);
 {paste tiles into this background, using circular enumeration 1,2,3,4,1,...}
 count:=0; Row:=0;
 gy:=BackY1;
 REPEAT
  gx:=BackX1;
  REPEAT
   PutTile(gx,gy,succ(count + (Row MOD tiles_per_column)*tiles_per_row));
   inc(count); count:=count MOD tiles_per_row;
   inc(gx,16);
  UNTIL gx>BackX2;
  inc(Row); {or: Row:=(Row+1) MOD tiles_per_row}
  inc(gy,16);
 UNTIL gy>BackY2;

For gx:=0 to 5 Do
 begin
  Color:=gx+5;
  Line(0,gx,316,gx,PAGE);
 end;
 For gx:=0 To 5 Do
 begin
  Color:=10-gx;
  Line(0,gx+6,316,gx+6,PAGE);
 end;
 OutTextXY(5,2,PAGE,'SCORE:      LEVEL:      Made by BoeierBoyszz tm');
 ScoreScr:=GetImage(0,0,316,10,PAGE);
end;


Procedure InitSprites;
begin
  if loadpalette('standard.pal',0,actualColors)=0
  then BEGIN
        closeroutines;
        WRITELN('Couldn''t access file  : '+GetErrorMessage);
        uninstallTrap;
        halt
       END
  ELSE
   SetPalette(actualColors,TRUE);

    
  PicsLoaded:=loadSprite(BlokName,BlokHantel);
  IF Error<>Err_None
  THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file '+BlokName+' : '+GetErrorMessage);
        uninstallTrap;
        halt(1)
       END;

   for teller:=0 to 3 do
   begin
     SpriteN[Blok+teller]:= BlokHantel;
     SpriteX[Blok+teller]:= 12+teller*85;
     SpriteY[Blok+teller]:= 168;
   end;

   

   SpriteN[Blok+4]:= BlokHantel;
   SpriteX[Blok+4]:= 132;
   SpriteY[Blok+4]:= 136;

   SpriteN[Blok+5]:= BlokHantel;
   SpriteX[Blok+5]:= 32;
   SpriteY[Blok+5]:= 106;

   SpriteN[Blok+6]:= BlokHantel;
   SpriteX[Blok+6]:= 75;
   SpriteY[Blok+6]:= 78;

   for teller:=0 to 2 do
   begin
     SpriteN[Blok+7+teller]:= BlokHantel;
     SpriteX[Blok+7+teller]:= teller*85;
     SpriteY[Blok+7+teller]:= 48;
   end;

   SpriteN[Blok+10]:= BlokHantel;
   SpriteX[Blok+10]:= 0;
   SpriteY[Blok+10]:= 15;

   SpriteN[Blok+11]:= BlokHantel;
   SpriteX[Blok+11]:= 85;
   SpriteY[Blok+11]:= -15;

   PicsLoaded:=loadSprite(FellowName,FellowHantel);
   IF Error<>Err_None
   THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file smallnumo.lib : '+GetErrorMessage);
        uninstallTrap;
        halt(1)
   END;

   PicsLoaded:=loadSprite('Spook.lib',SpookHantel);
   IF Error<>Err_None
   THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file spook.cod : '+GetErrorMessage);
        uninstallTrap;
        halt(1)
   END;
   SetSpriteCycle(Spook, PicsLoaded);
   SetCycleTime(10);

   PicsLoaded:=loadSprite('quest.lib',AppleHantel);
   IF Error<>Err_None
   THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file quest.lib : '+GetErrorMessage);
        uninstallTrap;
        halt(1)
   END;

   SetSpriteCycle(Apple,Picsloaded);

   LoadTile(TileName2,1); {load the 4 tiles as tile #1..4 = inner picture}
   IF Error<>Err_None
    THEN BEGIN
        CloseRoutines;
        WRITELN('Couldn''t access file '+TileName2+' : '+GetErrorMessage);
        uninstallTrap;
        halt(1)
       END;


end;

Procedure InitVars;
begin
   TotalApples:=10;
   Level      :=1;
   dy         :=1;
   dx_left    :=0;
   dx_right   :=0;
   FellowImage:=0;
   score      :=0;
   ydir       :=2;
   Jumping    :=False;
   Falling    :=False;
   Jump       :=False;
   Stop       :=False;
   Right      :=False;
   Left       :=False;
   FirstRight :=True;
   FirstLeft  :=True;
   NoMusic    :=False;
end;


function hitground: Boolean;
begin
  OldFel:= SpriteN[Fellow];
  if OldFel>7 then
   SpriteN[Fellow]:= FellowHantel+7+2
  else
   SpriteN[Fellow]:= FellowHantel+2;

  For teller:= 50 to 62 do
    if HitDetect(Fellow,teller) then
      if (SpriteY[Fellow]+14)<SpriteY[teller] then
      begin
           SpriteN[Fellow]:= OldFel;
           hitground:= True;
           exit;
      end;
   SpriteN[Fellow]:= OldFel;
   hitground:= False;
end;


procedure CheckXY;
begin
    If Right Then
    begin
      if OnGround and Not NoMusic Then PlayMusic('O2C');

      If FirstRight Then
        begin
          FirstRight:=False;
          FellowImage:=0;
        end;
      SpriteN[Fellow]:=(FellowHantel+7) + FellowImage;
      FellowImage:=(FellowImage+1) mod 6;
    end
    else
      FirstRight:=True;

    If (Right and (dx_right<8))
      then {* fellow rechts versnellen *}
        Inc(dx_right,2);

    If Left Then
    begin
      if OnGround and Not NoMusic Then PlayMusic('O2C');
      If FirstLeft Then
      begin
        FirstLeft:=False;
        FellowImage:=0;
      end;
      SpriteN[Fellow]:=(FellowHantel) + FellowImage;
      FellowImage:=(FellowImage+1) mod 6;
    end
    else
      FirstLeft:=True;

   If Left and (dx_left<8) then {* increase fellow's speed to the left *}
         Inc(dx_left,2);


   If (not Right) then
     If (dx_right>0) then  {* reduce fellow's speed to the right*}
       Dec(dx_right,2);
   If (not Left) then
    If (dx_left>0) then    {* reduce fellow's speed to the left *}
       Dec(dx_left,2);


   if dy<=9 then
      Inc(dy);

   if not OnGround then
     if SpriteN[Fellow]< FellowHantel+7 then
       SpriteN[Fellow]:= FellowHantel+ 3
     else
       SpriteN[Fellow]:= FellowHantel +7 +3;

    if OnGround and not Right and not Left then
     if SpriteN[Fellow]< FellowHantel+7 then
       SpriteN[Fellow]:= FellowHantel+ 2
     else
       SpriteN[Fellow]:= FellowHantel +7 +2;

  
end;

procedure MoveLift;
begin
    if SpriteY[53]>168 Then ydir:=-2; {* for our nice lift *}
    if SpriteY[53]<-20 Then ydir:=2;
end;

procedure ShowScore;
begin
    PutImage(2,StartVirtualY+188,ScoreScr,1-PAGE);
    Str(score, scorestr);
    Str(level, levelstr);
    OutTextXY(50,StartVirtualY+190,1-Page,scorestr);
    OutTextXY(120,StartVirtualY+190,1-PAGE,levelstr);
end;

function HitApples:Boolean;
begin
  For teller:= 90 to 99 do
    if HitDetect(Fellow,teller) then
      begin
           SpriteN[teller]:= 0; {* erase it *}
           HitApples:= True;
           exit;
      end;
   HitApples:= False;
end;

procedure PutApples;
var
  t: Integer;
begin
  for t:=0 to 9 do
  begin
    SpriteN[Apple+t]:= AppleHantel;
    SpriteX[Apple+t]:= Apples[0,t];
    SpriteY[Apple+t]:= Apples[1,t];
  end;
end;


begin
  RandoMize;
  InstallTrap;
  InitGraph;
  InitBackGround;
  InitSprites;
  InitVars;
  PutApples;

  SpriteN[Spook]:= SpookHantel;
  SpriteX[Spook]:= 1;
  SpriteY[Spook]:= 1;
  SpriteN[Fellow]:= FellowHantel;
  SpriteX[Fellow]:= 140;
  SpriteY[Fellow]:= 100;
  falling:=true;
  animate; {* eerste keer animate doen *}
  repeat
    ShowScore;
    MoveLift;

    
    if jump and OnGround then  {* jump key pressed and on bottom *}
    begin
      OnGround:=FALSE;
      dy:=-8;
      if Not NoMusic Then PlayMusic('O4CDE');
    end;

    

    Dec(SpriteX[Fellow],dx_left);  {* do horizontal movement *}
    Inc(SpriteX[Fellow],dx_right); {* for both directions    *}
    Inc(SpriteY[Fellow],dy);       {* do vertical movement   *}
    Inc(SpriteY[53],ydir);         {* move lift              *}

    if (dy>0) and HitGround then
    begin
      OnGround:= True;
      repeat
        Dec(SpriteY[Fellow]);
      until not HitGround;
    end else
      OnGround:= False;


    CheckXY;

    if SpriteX[Fellow]<0 then SpriteX[Fellow]:=0
    else if SpriteX[Fellow]>300 then SpriteX[Fellow]:=300;

    if SpriteX[Fellow]<>SpriteX[Spook] Then
    begin
      if SpriteX[Fellow]<SpriteX[Spook] then
        Dec(SpriteX[Spook],Random(Level)+1)
      else
        Inc(SpriteX[Spook],Random(Level)+1);
    end;

    if (SpriteY[Fellow]+7)<>SpriteY[Spook] Then
    begin
      if SpriteY[Fellow]+7<SpriteY[Spook] then
        Dec(SpriteY[Spook],Random(Level)+1)
      else
        Inc(SpriteY[Spook],Random(Level)+1);
    end;

    if HitDetect(Spook, Fellow) then
    begin
        if score<10 Then
          score:=0
        else Dec(score,10);
        if Not NoMusic Then PlayMusic('O2BAGFEDCO1BAGFEDC');
        if SpriteX[Fellow]>SpriteX[Spook] then
        begin
          dx_right:=8;
          dx_left:=0;
        end
        else
        begin
          dx_left:=8;
          dx_right:=0;
        end;
    end;

    if HitApples Then
    begin
      Dec(TotalApples);
      if TotalApples=0 then
      begin
         Inc(Level);
         TotalApples:=10;
         PutApples;
         if Not NoMusic Then PlayMusicForeGround('O4CDEFGABO3CDEFGABO2CDEFGAB');
         SpriteN[Fellow]:= FellowHantel;
         SpriteX[Fellow]:= 140;
         SpriteY[Fellow]:= 100;
      end;
      if Not NoMusic Then PlayMusic('O4CDECDEGG');
      Inc(score,10);
    end;

    if (abs(StartVirtualY-SpriteY[Fellow]))<40 Then
      StartVirtualY:=SpriteY[Fellow]-40;
    if (abs(StartVirtualY+200-SpriteY[Fellow]))<70 Then
      StartVirtualY:=SpriteY[Fellow]-130;

    animate; {* laat alles maar zien *}

    if SpriteY[Fellow]>326 Then
    begin
       StartVirtualY:=SpriteY[Fellow]-576;
       SpriteY[Fellow]:=SpriteY[Fellow]-448;
    end;

 until Stop;
 CloseRoutines;
 FreeImageMem(ScoreScr);
 WriteLn('  ');
 WriteLn('Your score was ',Score);
 WriteLn;
 WriteLn('This short game was brought to you by');
 WriteLn('(c) 1992 BoeierBoyszzzz tm');
 WriteLn('Folay && Hooligan');
 Write(Chr(7));
 uninstalltrap;
end.

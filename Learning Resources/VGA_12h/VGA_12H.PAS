UNIT VGA_12h;

INTERFACE

const
  { Default Font }
  ROM8x8   : Array [0..2048] Of Byte = ( 8,{$I rom8x8.inc});
  ROM8x14  : Array [0..3584] Of Byte = (14,{$I rom8x14.inc});
  ROM8x16  : Array [0..4096] Of Byte = (16,{$I rom8x16.inc});
  Broadway : array [0..3584] Of Byte = (14,{$I broadway.inc});
  Decorate : array [0..4096] Of Byte = (16,{$I decorate.inc});

{ Mode 12h Routines }
Procedure Mode3h;
Procedure Mode12h;
Procedure ClrScr12h(Col : byte); {32 BIT !!}
Procedure Plot12h(x,y:word;Color:byte);
Procedure HLine12h(x,y,Length:word;Color:byte);
Procedure VLine12h(x,y,Length:word;Color:byte);
Procedure Block12h(x,y,Width,Height:word;Color:byte);
Procedure Frame12h(x,y,Width,Height:word;Color:byte);
Procedure Button12h(x,y,W,H:Word;Color0,Color1,Color2:byte);
Procedure SetFont12h(var FontArr : array of byte);
Procedure PutChar12h(x,y:word;cha:char;FColor,BColor:byte);
Procedure PutString12h(x,y:word;Str:String;FColor,BColor:byte);
Procedure PutCharTrans12h(x,y:word;cha:char;Color:byte);
Procedure PutStringTrans12h(x,y:word;Str:String;Color:byte);
Procedure Window12h(x,y,Width,Height:word;Color0,Color1,Color2:byte);
Procedure CloseWindow12h;
Procedure SaveScreen12h;
Procedure RestoreScreen12h;
Procedure GetRGB12h(PalNum: byte; var R,G,B: Byte);
Procedure SetRGB12h(PalNum,R,G,B: Byte);

IMPLEMENTATION

Type
    Window12hType = record
                      Width : byte;
                      Height: word;
                      VidOfs: word;
                      Plane0: pointer;
                      Plane1: pointer;
                      Plane2: pointer;
                      Plane3: pointer;
                     end;
Var
   WindowList12h     : Array [1..16] of ^Window12hType;
   LastWindow12h     : byte;
   ScreenGrab        : Array [0..3] of pointer;
   _FontSeg,_FontOfs   : word;
   _FontH : byte;

{*****************************************************************
                    GRAPHICS & TEXT ROUTINES
 *****************************************************************}

Procedure Mode3h; Assembler; {Text}
Asm
  Mov     AH,00
  Mov     AL,3h
  Int     10h
end;

Procedure Mode12h; Assembler; {640x480x16}
Asm
  Mov     AH,00
  Mov     AL,12h
  Int     10h
  mov     dx,03ceh    {Graphics Controller}
  mov     ax,0205h    {Mode Register, Write Mode 2}
  out     dx,ax
end;

Procedure ClrScr12h(Col : byte); Assembler; {32 BIT !!}
asm
  mov   es,SegA000
  mov   di,00h
  mov   al,[Col]
  mov   ah,al
  db 66h; Shl ax,16
  mov   al,[Col]
  mov   ah,al
  mov   cx,9600
  db 66h; rep stosw
end;

Procedure Plot12h(x,y:word;Color:byte); Assembler;
asm
  mov   ax,SegA000      {Calculate Offset}
  mov   es,ax
  mov   bx,[y]
  mov   di,bx
  shl   di,6            {80*y}
  shl   bx,4
  add   di,bx

  mov   cx,[x]
  mov   bx,cx
  shr   bx,3            {/8}
  add   di,bx           {80*y+ (x/8)}

  and   cx,7            {Get Bit that Changes}
  mov   ah,128
  shr   ah,cl
  mov   dx,03ceh
  mov   al,8
  out   dx,ax
  mov   dl,[es:di]
  mov   al,[Color]
  mov   [es:di],al
end;

Procedure HLine12h(x,y,Length:word;Color:byte); Assembler;
asm
  mov   bx,[x]
  mov   si,[Length]
  or    si,si           {Check if Length=0}
  jz    @D_End           {If So then jump to End}
  mov   dx,03ceh        {Graphics Controller}

  mov   ax,SegA000      {Calculate Offset}
  mov   es,ax
  mov   ax,[y]
  mov   di,ax
  shl   di,6            {80*y}
  shl   ax,4
  add   di,ax

  mov   ax,bx
  shr   ax,3            {/8}
  add   di,ax           {80*y+ (x/8)}

{di = Offset in VMem}
{Si = Length}
{bx = x}
{dx = Graphix Controller}

{ax = empty}
{cx = empty}

  mov   cx,bx           {Get StartBit}
  and   cx,07h

  mov   ax,si
  add   ax,cx
  cmp   ax,8            {Is x+Length<One Byte}
  jb    @D_One

  mov   ah,0ffh         {11111111b}
  shr   ah,cl           {BitMask}
  mov   al,8            {BitMask Register}
  out   dx,ax           {Write BitMask}
  mov   al,[es:di]
  mov   al,[Color]
  mov   [es:di],al
  inc   di

  mov   al,8            {BitMask Register}
  mov   ah,0ffh         {BitMask}
  out   dx,ax           {Write BitMask}

  mov   ax,si
  mov   ch,8
  sub   ch,cl
  mov   cl,ch
  xor   ch,ch
  sub   ax,cx
  shr   ax,3            {Length div 8}
  mov   cx,ax
  mov   al,[Color]
  rep   stosb

  mov   cx,bx           {cx:=x+Length}
  add   cx,si
  and   cx,07h          {cx and 07}
  mov   ah,0ffh
  shr   ah,cl           {BitMask}
  cmp   ah,0
  je    @D_End

  not   ah
  mov   al,8            {BitMask Register}
  out   dx,ax           {Write BitMask}
  mov   cl,[es:di]
  mov   al,[Color]
  mov   [es:di],al
  jmp   @D_End

@D_One:
  mov   ah,0ffh
  shr   ah,cl           {Left BitMask}

  add   bx,si
  dec   bx
  and   bx,07h

  mov   cx,7
  sub   cx,bx

  mov   bl,0ffh
  shl   bl,cl          {Right BitMask}

  and   ah,bl          {Full  BitMask}
  mov   al,8           {BitMask Register}
  out   dx,ax          {Write BitMask}

  mov   dl,[es:di]     {Fill Latches}
  mov   al,[Color]
  mov   [es:di],al     {Write Pixel}
@D_End:
 end;

Procedure VLine12h(x,y,Length:word;Color:byte); Assembler;
asm
  mov   ax,SegA000      {Calculate Offset}
  mov   es,ax
  mov   bx,[y]
  mov   di,bx
  shl   di,6            {80*y}
  shl   bx,4
  add   di,bx

  mov   cx,[x]
  mov   bx,cx
  shr   bx,3            {/8}
  add   di,bx           {80*y+ (x/8)}

  and   cx,7            {Get Bit that Changes}
  mov   ah,80h
  shr   ah,cl           {BitMask Value}
  mov   dx,03ceh        {Graphics Controller}
  mov   al,8            {BitMask Register}
  out   dx,ax           {BitMask Setup}
  mov   bx,[Length]
  mov   al,[Color]
@D_L:
  mov   dl,[es:di]
  mov   [es:di],al      {Put Byte at Offset}
  add   di,80
  dec   bx
  jnz   @D_L
 end;

Procedure Block12h(x,y,Width,Height:word;Color:byte); Assembler;
asm
  mov   bx,[x]
  mov   si,[Width]
  or    si,si           {Check if Length=0}
  jz    @D_End           {If So then jump to End}

  mov   ax,SegA000      {Calculate Offset}
  mov   es,ax
  mov   ax,[y]
  mov   di,ax
  shl   di,6            {80*y}
  shl   ax,4
  add   di,ax

  mov   ax,bx
  shr   ax,3            {/8}
  add   di,ax           {80*y+ (x/8)}

{di = Offset in VMem}
{Si = Length}
{bx = x}
{dx = Graphix Controller}

{ax = empty}
{cx = empty}

  mov   cx,bx           {Get StartBit}
  and   cx,07h

  mov   ax,si
  add   ax,cx
  cmp   ax,8            {Is x+Length<One Byte}
  jb    @D_One

  mov   ah,0ffh         {11111111b}
  shr   ah,cl           {BitMask}
  mov   al,8            {BitMask Register}
  mov   dx,03ceh        {Graphics Controller}
  out   dx,ax           {Write BitMask}
  push  cx
  mov   ah,[Color]
  mov   cx,[Height]
  mov   dx,di
@D_LL:                   {Draw Left of Box}
  mov   al,[es:di]
  mov   [es:di],ah
  add   di,80           {di:=di+80}
  dec   cx
  jnz   @D_LL
  mov   di,dx
  inc   di
  pop   cx

  mov   al,8            {BitMask Register}
  mov   ah,0ffh         {BitMask}
  mov   dx,03ceh        {Graphics Controller}
  out   dx,ax           {Write BitMask}

  mov   ax,si
  mov   ch,8
  sub   ch,cl
  mov   cl,ch
  xor   ch,ch
  sub   ax,cx
  shr   ax,3            {Length div 8}

  push  di
  push  bx
  mov   bx,[Height]
  mov   dx,ax
  mov   al,[Color]
@D_LC:
  mov   cx,dx
  rep   stosb
  add   di,80
  sub   di,dx
  dec   bx
  jnz   @D_LC
  pop   bx
  pop   di
  add   di,dx

  mov   cx,bx           {cx:=x+Length}
  add   cx,si
  and   cx,07h          {cx and 07}
  mov   ah,0ffh
  shr   ah,cl           {BitMask}
  cmp   ah,0
  je    @D_End

  not   ah
  mov   al,8            {BitMask Register}
  mov   dx,03ceh        {Graphics Controller}
  out   dx,ax           {Write BitMask}
  mov   cx,[Height]
  mov   al,[Color]
@D_LR:
  mov   ah,[es:di]
  mov   [es:di],al
  add   di,80
  dec   cx
  jnz   @D_LR

  jmp   @D_End

@D_One:
  mov   ah,0ffh
  shr   ah,cl           {Left BitMask}

  add   bx,si
  dec   bx
  and   bx,07h

  mov   cx,7
  sub   cx,bx

  mov   bl,0ffh
  shl   bl,cl          {Right BitMask}

  and   ah,bl          {Full  BitMask}
  mov   al,8           {BitMask Register}
  mov   dx,03ceh        {Graphics Controller}
  out   dx,ax          {Write BitMask}
  mov   cx,[Height]
  mov   al,[Color]
@D_L:
  mov   dl,[es:di]     {Fill Latches}
  mov   [es:di],al     {Write Pixel}
  add   di,80
  dec   cx
  jnz   @D_L
@D_End:
 end;

Procedure Button12h(x,y,W,H:Word;Color0,Color1,Color2:byte);
begin
  Block12h(x,y,W,H,Color1);
  HLine12h(x-1,y-1,W+2,Color2);
  VLine12h(x-1,y,H+1,Color2);
  HLine12h(x,y+H,W+1,Color0);
  VLine12h(x+W,y,H+1,Color0);
 end;


Procedure Frame12h(x,y,Width,Height:word;Color:byte);
begin
  HLine12h(x,y,Width,Color);
  VLine12h(x,y,Height,Color);
  VLine12h(x+Width-1,y,Height,Color);
  HLine12h(x,y+Height-1,Width,Color);
 end;

procedure SetFont12h(var FontArr : array of byte);
begin
  _FontH := FontArr[0];
  _FontSeg:=Seg(FontArr[1]);
  _FontOfs:=Ofs(FontArr[1]);
end;

Procedure PutChar12h(x,y:word;cha:char;FColor,BColor:byte); Assembler;
asm
  push  ds
  mov   ax,_FontSeg
  mov   ds,ax
  mov   si,_FontOfs

  xor   ax,ax
  mov   al,[cha]
  mul   _FontH

  add   si,ax
  mov   ax,SegA000      {Calculate Offset}
  mov   es,ax
  mov   di,[y]
  mov   ax,di
  shl   ax,6
  shl   di,4
  add   di,ax
  add   di,[x]

  xor   cx,cx
  mov   cl,_FontH

  mov   dx,03ceh
  mov   al,8
  mov   bh,[FColor]
  mov   bl,[BColor]
@D_L:
  mov   ah,[ds:si]
  out   dx,ax
  mov   ch,[es:di]
  mov   [es:di],bh

  xor   ah,0FFh
  out   dx,ax
  mov   ch,[es:di]
  mov   [es:di],bl

  inc   si
  add   di,80
  dec   cl
  jnz   @D_L
  pop   ds
end;

Procedure PutString12h(x,y:word;Str:String;FColor,BColor:byte);
var
   f1   : byte;
   Cha  : char;
begin
for f1:=1 to ord(Str[0]) do
 begin
   cha:=Str[f1];
   asm
     push  ds
     mov   ax,_FontSeg
     mov   ds,ax
     mov   si,_FontOfs

     xor   ax,ax
     mov   al,[cha]
     mul   _FontH

     add   si,ax
     mov   ax,SegA000      {Calculate Offset}
     mov   es,ax
     mov   di,[y]
     mov   ax,di
     shl   ax,6
     shl   di,4
     add   di,ax
     add   di,[x]

     xor   cx,cx
     mov   cl,_FontH

     mov   dx,03ceh
     mov   al,8
     mov   bh,[FColor]
     mov   bl,[BColor]
@D_L:
     mov   ah,[ds:si]
     out   dx,ax
     mov   ch,[es:di]
     mov   [es:di],bh

     xor   ah,0FFh
     out   dx,ax
     mov   ch,[es:di]
     mov   [es:di],bl

     inc   si
     add   di,80
     dec   cl
     jnz   @D_L
     pop   ds
    end;
    inc(x);
  end;{For}
end;

Procedure PutCharTrans12h(x,y:word;cha:char;Color:byte); Assembler;
asm
  push  ds
  mov   ax,_FontSeg
  mov   ds,ax
  mov   si,_FontOfs

  xor   ax,ax
  mov   al,[cha]
  mul   _FontH

  add   si,ax
  mov   ax,SegA000      {Calculate Offset}
  mov   es,ax
  mov   di,[y]
  mov   ax,di
  shl   ax,6
  shl   di,4
  add   di,ax
  add   di,[x]

  xor   cx,cx
  mov   cl,_FontH

  mov   dx,03ceh
  mov   al,8
  mov   bl,[Color]
@D_L:
  mov   ah,[ds:si]
  out   dx,ax
  mov   ah,[es:di]
  mov   [es:di],bl
  inc   si
  add   di,80
  dec   cx
  jnz   @D_L
  pop   ds
end;

Procedure PutStringTrans12h(x,y:word;Str:String;Color:byte);
var
   f1   : byte;
   Cha  : char;
begin
for f1:=1 to ord(Str[0]) do
 begin
   cha:=Str[f1];
   asm
     push  ds
     mov   ax,_FontSeg
     mov   ds,ax
     mov   si,_FontOfs

     xor   ax,ax
     mov   al,[cha]
     mul   _FontH

     add   si,ax
     mov   ax,SegA000      {Calculate Offset}
     mov   es,ax
     mov   di,[y]
     mov   ax,di
     shl   ax,6
     shl   di,4
     add   di,ax
     add   di,[x]

     xor   cx,cx
     mov   cl,_FontH

     mov   dx,03ceh
     mov   al,8
     mov   bl,[Color]
@D_L:
     mov   ah,[ds:si]
     out   dx,ax
     mov   ch,[es:di]
     mov   [es:di],bl

     inc   si
     add   di,80
     dec   cl
     jnz   @D_L
     pop   ds
    end;
    inc(x);
  end;{For}
end;

Procedure Window12h(x,y,Width,Height:word;Color0,Color1,Color2:byte);
var
   VidOfs       : word;
   ImOfs,ImSeg  : word;
   ScrW         : word;
   O0,S0,O1,S1  : word;
   O2,S2,O3,S3  : word;
begin
  if LastWindow12h<16 then
    begin
      inc(LastWindow12h);
      new(WindowList12h[LastWindow12h]);
      VidOfs:=(y shl 6)+(y shl 4)+x;
      WindowList12h[LastWindow12h]^.VidOfs:=VidOfs;
      WindowList12h[LastWindow12h]^.Width :=Width;
      WindowList12h[LastWindow12h]^.Height:=Height;
      ScrW:=Width*Height;
      GetMem(WindowList12h[LastWindow12h]^.Plane0,ScrW);
      GetMem(WindowList12h[LastWindow12h]^.Plane1,ScrW);
      GetMem(WindowList12h[LastWindow12h]^.Plane2,ScrW);
      GetMem(WindowList12h[LastWindow12h]^.Plane3,ScrW);
      S0:=Seg(WindowList12h[LastWindow12h]^.Plane0^);
      O0:=Ofs(WindowList12h[LastWindow12h]^.Plane0^);
      S1:=Seg(WindowList12h[LastWindow12h]^.Plane1^);
      O1:=Ofs(WindowList12h[LastWindow12h]^.Plane1^);
      S2:=Seg(WindowList12h[LastWindow12h]^.Plane2^);
      O2:=Ofs(WindowList12h[LastWindow12h]^.Plane2^);
      S3:=Seg(WindowList12h[LastWindow12h]^.Plane3^);
      O3:=Ofs(WindowList12h[LastWindow12h]^.Plane3^);
      ScrW:=80-Width;
      asm
        push  ds

        mov   bx,[Width]
        mov   cx,[Height]

        mov   si,[VidOfs]
        mov   ds,SegA000                 {ds:si VideoMem}
        mov   dx,03ceh                   {Graphics Controller}
        mov   ax,0005h                   {Mode Register, Write 0, Read  0}
        out   dx,ax


        mov   di,[O3]                    {Read Plane 3}
        mov   es,[S3]                    {es:di ImageOfset}
        mov   ax,0304h                   {Read Plane Select}
        out   dx,ax
        push  si                         {Save 'Start Window in VideoMem'}
        push  cx
        mov   ax,cx                      {cx=Height}
    @B3:
        mov   cx,bx                      {bx=Width}
        rep   movsb                      {Read 8 Pixels}
        add   si,[ScrW]                  {Goto Next Line by adding ScrWidth}
        dec   ax
        jnz   @B3
        pop   cx
        pop   si                         {Restore 'Start Window in VideoMem'}

        mov   di,[O2]                    {Read Plane 2}
        mov   es,[S2]                    {es:di ImageOfset}
        mov   ax,0204h                   {Read Plane Select}
        out   dx,ax
        push  si                         {Save 'Start Window in VideoMem'}
        push  cx
        mov   ax,cx                      {cx=Height}
    @B2:
        mov   cx,bx                      {bx=Width}
        rep   movsb                      {Read 8 Pixels}
        add   si,[ScrW]                  {Goto Next Line by adding ScrWidth}
        dec   ax
        jnz   @B2
        pop   cx
        pop   si                         {Restore 'Start Window in VideoMem'}


        mov   di,[O1]                    {Read Plane 1}
        mov   es,[S1]                    {es:di ImageOfset}
        mov   ax,0104h                   {Read Plane Select}
        out   dx,ax
        push  si                         {Save 'Start Window in VideoMem'}
        push  cx
        mov   ax,cx                      {cx=Height}
    @B1:
        mov   cx,bx                      {bx=Width}
        rep   movsb                      {Read 8 Pixels}
        add   si,[ScrW]                  {Goto Next Line by adding ScrWidth}
        dec   ax
        jnz   @B1
        pop   cx
        pop   si                         {Restore 'Start Window in VideoMem'}


        mov   di,[O0]                    {Read Plane 0}
        mov   es,[S0]                    {es:di ImageOfset}
        mov   ax,0004h                   {Read Plane Select}
        out   dx,ax
        mov   ax,cx                      {cx=Height}
    @B0:
        mov   cx,bx                      {bx=Width}
        rep   movsb                      {Read 8 Pixels}
        add   si,[ScrW]                  {Goto Next Line by adding ScrWidth}
        dec   ax
        jnz   @B0

        mov   ax,0205h                   {Mode Register, Write Mode 2}
        out   dx,ax
        pop   ds
       end;
     Width:=Width shl 3;
     x:=x shl 3;
     Block12h(x,y,Width,Height,Color1);
     HLine12h(x+1,y,Width-2,Color2);
     VLine12h(x,y+1,Height-2,Color2);
     HLine12h(x+1,y+Height-1,Width-1,Color0);
     VLine12h(x+width-1,y+1,Height-1,Color0);
    end;
end;

Procedure CloseWindow12h;
var
  Width,Height  : word;
  SegWin,OfsWin : word;
  OfsVid        : word;
  ScrW          : word;
  O0,S0,O1,S1   : word;
  O2,S2,O3,S3   : word;
begin
  if LastWindow12h>0 then
   begin
     Width:=WindowList12h[LastWindow12h]^.Width;
     Height:=WindowList12h[LastWindow12h]^.Height;
     OfsVid:=WindowList12h[LastWindow12h]^.VidOfs;

     S0:=Seg(WindowList12h[LastWindow12h]^.Plane0^);
     O0:=Ofs(WindowList12h[LastWindow12h]^.Plane0^);
     S1:=Seg(WindowList12h[LastWindow12h]^.Plane1^);
     O1:=Ofs(WindowList12h[LastWindow12h]^.Plane1^);
     S2:=Seg(WindowList12h[LastWindow12h]^.Plane2^);
     O2:=Ofs(WindowList12h[LastWindow12h]^.Plane2^);
     S3:=Seg(WindowList12h[LastWindow12h]^.Plane3^);
     O3:=Ofs(WindowList12h[LastWindow12h]^.Plane3^);
     ScrW:=80-Width;
     Asm
       push ds
      {GET OFFSET IN VIDEOMEM/MOUSEBACKUP}

       mov  bx,[Width]
       mov  cx,[Height]
       mov  es,SegA000
       mov  di,[OfsVid]                {es:di Start in VideoMem}
       mov  dx,03ceh                   {Graphics Controller}
       mov  ax,0805h                   {Mode Register, Write Mode 0, Read Mode1}
       out  dx,ax
       mov  ax,0007h                   {color don't care Register}
       out  dx,ax
       mov  ax,0ff08h                  {BitMask Register}
       out  dx,ax
       mov  dx,03c4h                   {Sequencer Controller}

       cli
       mov  si,[O3]
       mov  ds,[S3]                    {ds:si Start in Memory}
       mov  ax,0802h                   {Write Plane Select,Plane 3}
       out  dx,ax                      {Write Read Plane Select}
       push di                         {Save 'Start Window in VideoMem'}
       mov  ax,[Height]                {Height}
   @R3:
       mov  cx,bx                      {bx=Width}
       rep  movsb                      {Draw 8 Pixels}
       add  di,[ScrW]                  {Goto Next Line by adding ScrWidth}
       dec  ax
       jnz  @R3
       pop  di                         {Restore 'Start Window in VideoMem'}


       mov  si,[O2]
       mov  ds,[S2]                    {ds:si Start in Memory}
       mov  ax,0402h                   {Write Plane Select,Plane 2}
       out  dx,ax                      {Write Read Plane Select}
       push di                         {Save 'Start Window in VideoMem'}
       mov  ax,[Height]                {Height}
   @R2:
       mov  cx,bx                      {bx=Width}
       rep  movsb                      {Draw 8 Pixels}
       add  di,[ScrW]                  {Goto Next Line by adding ScrWidth}
       dec  ax
       jnz  @R2
       pop  di                         {Restore 'Start Window in VideoMem'}

       mov  si,[O1]
       mov  ds,[S1]                    {ds:si Start in Memory}
       mov  ax,0202h                   {Write Plane Select,Plane 1}
       out  dx,ax                      {Write Read Plane Select}
       push di                         {Save 'Start Window in VideoMem'}
       mov  ax,[Height]                {Height}
   @R1:
       mov  cx,bx                      {bx=Width}
       rep  movsb                      {Draw 8 Pixels}
       add  di,[ScrW]                  {Goto Next Line by adding ScrWidth}
       dec  ax
       jnz  @R1
       pop  di                         {Restore 'Start Window in VideoMem'}

       mov  si,[O0]
       mov  ds,[S0]                    {ds:si Start in Memory}
       mov  ax,0102h                   {Write Plane Select,Plane 2}
       out  dx,ax                      {Write Read Plane Select}
       mov  ax,[Height]                {Height}
   @R0:
       mov  cx,bx                      {bx=Width}
       rep  movsb                      {Draw 8 Pixels}
       add  di,[ScrW]                  {Goto Next Line by adding ScrWidth}
       dec  ax
       jnz  @R0

       mov  ax,0f02h                   {Set All Planes to write}
       out  dx,ax

       mov  dx,03ceh                   {Graphics Controller}
       mov  ax,0205h                   {Mode Register, Write Mode 2}
       out  dx,ax
       sti
       pop  ds
      end;
     ScrW:=Width*Height;
     FreeMem(WindowList12h[LastWindow12h]^.Plane0,ScrW);
     FreeMem(WindowList12h[LastWindow12h]^.Plane1,ScrW);
     FreeMem(WindowList12h[LastWindow12h]^.Plane2,ScrW);
     FreeMem(WindowList12h[LastWindow12h]^.Plane3,ScrW);
     Dispose(WindowList12h[LastWindow12h]);
     dec(LastWindow12h);
    end;
end;

Procedure SaveScreen12h;
var
   O0,S0,O1,S1  : word;
   O2,S2,O3,S3  : word;
begin
  GetMem(ScreenGrab[0],38592);{80*480+64*3(Palet)}
  GetMem(ScreenGrab[1],38400);{80*480}
  GetMem(ScreenGrab[2],38400);{80*480}
  GetMem(ScreenGrab[3],38400);{80*480}

  S0:=Seg(ScreenGrab[0]^);
  O0:=Ofs(ScreenGrab[0]^);

  S1:=Seg(ScreenGrab[1]^);
  O1:=Ofs(ScreenGrab[1]^);

  S2:=Seg(ScreenGrab[2]^);
  O2:=Ofs(ScreenGrab[2]^);

  S3:=Seg(ScreenGrab[3]^);
  O3:=Ofs(ScreenGrab[3]^);
  asm
    push ds

    mov  di,[O3]
    mov  es,[S3]
   {es:di          ImageOfset}
    mov  ds,SegA000
    xor  si,si
   {ds:si          VideoMem}
    mov  dx,03ceh                   {Graphics Controller}
    mov  ax,0005h                   {Mode Register, Write 0, Read  0}
    out  dx,ax
    mov  ax,0304h                   {Read Plane Select}{Plane 3}
    out  dx,ax
    mov  cx,19200
    rep  movsw

    mov  es,[S2]
    mov  di,[O2]
    xor  si,si
    dec  ah                         {Plane 2}
    out  dx,ax
    mov  cx,19200
    rep  movsw

    mov  es,[S1]
    mov  di,[O1]
    xor  si,si
    dec  ah                         {Plane 1}
    out  dx,ax
    mov  cx,19200
    rep  movsw

    mov  es,[S0]
    mov  di,[O0]
    xor  si,si
    dec  ah                         {Plane 0}
    out  dx,ax
    mov  cx,19200
    rep  movsw

    mov  dx,03ceh                   {Graphics Controller}
    mov  ax,0205h                   {Mode Register, Write Mode 2}
    out  dx,ax

    mov  dx,03c7h                   {Save Palette behind Plane 0}
    mov  al,0
    out  dx,al
    mov  dx,03c9h
    mov  cx,192                     {64 Colors RxGxB starting}
    rep  insb
    pop  ds
   end;
 end;

Procedure RestoreScreen12h;
var
   O0,S0,O1,S1  : word;
   O2,S2,O3,S3  : word;
Label
     C1,C2,rt1,rt2;
begin
  S0:=Seg(ScreenGrab[0]^);
  O0:=Ofs(ScreenGrab[0]^);

  S1:=Seg(ScreenGrab[1]^);
  O1:=Ofs(ScreenGrab[1]^);

  S2:=Seg(ScreenGrab[2]^);
  O2:=Ofs(ScreenGrab[2]^);

  S3:=Seg(ScreenGrab[3]^);
  O3:=Ofs(ScreenGrab[3]^);
  Asm
    push ds

    mov   dx,03c8h
    mov   al,0
    out   dx,al
    inc   dx
    mov   cx,192
  C1:
    out   dx,al
    dec   cx
    jnz   C1

    mov  dx,03ceh                   {Graphics Controller}
    mov  ax,0805h                   {Mode Register, Write Mode 0, Read Mode 1}
    out  dx,ax
    mov  ax,0007h                   {color don't care Register}
    out  dx,ax
    mov  ax,0ff08h                  {BitMask Register}
    out  dx,ax
    mov  dx,03c4h                   {Sequencer Controller}
   {GET OFFSET IN VIDEOMEM}
    mov  es,SegA000
    xor  di,di
   {es:di                Start in VideoMem}
    mov  si,[O3]
    mov  ds,[S3]
   {ds:si                Start in Memory}
    mov  ax,0802h                     {Write Plane Select}
    out  dx,ax
    cli
    mov  cx,19200
    rep  movsw

    xor  di,di
   {es:di                Start in VideoMem}
    mov  si,[O2]
    mov  ds,[S2]
   {ds:si                Start in Memory}
    mov  ax,0402h                     {Write Plane Select}
    out  dx,ax
    mov  cx,19200
    rep  movsw

    xor  di,di
   {es:di                Start in VideoMem}
    mov  si,[O1]
    mov  ds,[S1]
   {ds:si                Start in Memory}
    mov  ax,0202h                     {Write Plane Select}
    out  dx,ax
    mov  cx,19200
    rep  movsw

    xor  di,di
   {es:di                Start in VideoMem}
    mov  si,[O0]
    mov  ds,[S0]
   {ds:si                Start in Memory}
    mov  ax,0102h                     {Write Plane Select}
    out  dx,ax
    mov  cx,19200
    rep  movsw
    sti
    mov  ax,0f02h                  {Set All Planes to write}
    out  dx,ax

    mov  dx,03ceh                  {Graphics Controller}
    mov  ax,0205h                  {Mode Register, Write Mode 2}
    out  dx,ax

    mov   dx,03c8h
    mov   al,0
    out   dx,al
    inc   dx
    mov   cx,192
    rep   outsb
    pop  ds
   end;
  FreeMem(ScreenGrab[3],38400);{80*480}
  FreeMem(ScreenGrab[2],38400);{80*480}
  FreeMem(ScreenGrab[1],38400);{80*480}
  FreeMem(ScreenGrab[0],38592);{80*480+64*3}
 end;

PROCEDURE SetRGB12h(PalNum, R, G, B : Byte); Assembler;
ASM
    MOV AH, 10h   {funz. 10h, sub-funz. 07h}
    MOV AL, 07h   {"Get Palette Register"}
    MOV BL, PalNum
    INT 10h
    XOR BL, BL
    XCHG BH, BL   {ora BX contiene il colore}
    MOV AH, 10h   {funz. 10h, sub-funz. 10h}
    MOV AL, 10h   {"Set Color Register"}
    MOV DH, R
    MOV CH, G
    MOV CL, B
    INT 10h
END;

PROCEDURE GetRGB12h(PalNum : Byte; VAR R, G, B : Byte); Assembler;
ASM
    MOV AH, 10h   {funz. 10h, sub-funz. 07h}
    MOV AL, 07h   {"Get Palette Register"}
    MOV BL, PalNum
    INT 10h
    XOR BL, BL
    XCHG BH, BL   {ora BX contiene il colore}
    MOV AH, 10h   {funz. 10h, sub-funz. 10h}
    MOV AL, 15h   {"Get Color Register"}
    INT 10h
    LES DI, R
    MOV ES:[DI], DH
    LES DI, G
    MOV ES:[DI], CH
    LES DI, B
    MOV ES:[DI], CL
END;


begin
  LastWindow12h:=0;
  SetFont12h(ROM8x8);
end.

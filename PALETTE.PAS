{$S+,G+}

unit Palette;

{ (C) by Krzysztof Heim, last change 1996-8-27 }

interface

uses Graphic;

const FadeSpeed: Byte = 0;

type TColor = record
                Red, Green, Blue: Byte
              end;
     TPalette = array[0..255] of TColor;

procedure SetColor(Red, Green, Blue: Byte; var Color: TColor);
procedure SetPalette(Palette: TPalette; Start, Count: Word);
procedure GetPalette(var Palette: TPalette; Start, Count: Word);
 function LoadPalette(Name: string; var Palette: TPalette): Boolean;
procedure SavePalette(Name: string; var Palette: TPalette);
procedure Fade(Output: TPalette; Start, Count: Word);
procedure Color2Gray(var Palette: TPalette);
procedure ColorMixer(var Palette: TPalette; R, G, B: Byte);
 function FindColor(R, G, B: Byte; Palette: TPalette): Byte;
procedure RemapColors(A, B: TPalette; P: Pointer; S: Word);
{A - nowa paleta }

var plBlack, plWhite, plStandard: TPalette;

implementation

uses Crt;

var Work: TPalette;

procedure SetColor; assembler;
asm
  les di,Color
  mov al,Red
  stosb
  mov al,Green
  stosb
  mov al,Blue
  stosb
end;

procedure SetPalette; assembler;
asm
  push ds
  lds si,Palette
  mov ax,[Count]
  mov cx,ax
  shl cx,1
  add cx,ax
  mov ax,[Start]
  mov bx,ax
  shl bx,1
  add bx,ax
  add si,bx
  mov dx,03C8h
  out dx,al
  inc dx
  push dx
  call Return
  pop dx
  rep outsb
  pop ds
end;

procedure GetPalette; assembler;
asm
  les di,Palette
  mov ax,[Count]
  mov cx,ax
  shl cx,1
  add cx,ax
  mov ax,[Start]
  mov bx,ax
  shl bx,1
  add bx,ax
  add di,bx
  mov dx,03C7h
  out dx,al
  add dx,2
  rep insb
end;

function LoadPalette;
var F: file;
    H: array[1..8] of Char;
begin
  LoadPalette:=FALSE;
  {$I-}
  Assign(F, Name + '.PAL'); Reset(F, 1);
  {$I+}
  if IOResult > 0 then Exit;
  BlockRead(F, H, 8);
  if H <> 'Palette' + #26 then Exit;
  BlockRead(F, Palette, 768);
  Close(F);
  LoadPalette:=TRUE
end;

procedure SavePalette;
var F: file;
    H: array[1..8] of Char;
begin
  Assign(F, Name + '.PAL'); ReWrite(F, 1);
  H:='Palette' + #26;
  BlockWrite(F, H, 8);
  BlockWrite(F, Palette, 768);
  Close(F)
end;

{$F+}
function Check(A, B: Byte): Byte; assembler;
asm
  mov al,A
  cmp al,B
  je @Exit
  ja @Above
  inc al
  jmp @Exit
@Above:
  dec al
@Exit:
end;

procedure Fade;
var I, C : Byte;

begin
  GetPalette(Work, Start, Count);
  for C:=0 to 63 do begin
    for I:=Start to Start + Count - 1 do with Work[I] do begin
      Red:=Check(Red, Output[I].Red);
      Green:=Check(Green, Output[I].Green);
      Blue:=Check(Blue, Output[I].Blue)
    end;
    Delay(FadeSpeed);
    SetPalette(Work, Start, Count)
  end
end;

procedure Color2Gray; assembler;
asm
  les di,[Palette]
  mov cx,0100h
  xor bh,bh
  mov dl,3
@Loop:
  xor ah,ah
  mov al,es:[di]
  mov bl,es:[di + 1]
  add ax,bx
  mov bl,es:[di + 2]
  add ax,bx
  div dl
  stosb
  stosb
  stosb
  loop @Loop
end;

procedure ColorMixer;
var A: Byte;
begin
  if (R > 100) or (G > 100) or (B > 100) then Exit;
  for A:=0 to 255 do with Palette[A] do begin
    Red:=(Red * R) div 100;
    Green:=(Green * G) div 100;
    Blue:=(Blue * B) div 100
  end
end;

function FindColor(R, G, B: Byte; Palette: TPalette): Byte;
var I, J: Byte;
    S   : array[0..255] of Word;
    A   : Word;
begin
  for I:=0 to 255 do with Palette[I] do
    S[I]:=Abs(Red - R) + Abs(Green - G) + Abs(Blue - B);
  A:=766;
  for I:=0 to 255 do
    if S[I] < A then begin
      A:=S[I];
      J:=I;
      if A = 0 then Break
    end;
  FindColor:=J
end;

procedure RemapColors(A, B: TPalette; P: Pointer; S: Word);
var I    : Byte;
    Color: array[0..255] of Byte;
begin
  for I:=0 to 255 do
    Color[I]:=FindColor(B[I].Red, B[I].Green, B[I].Blue, A);
  asm
    les di,P
    mov cx,S
    push ds
    mov ax,ss
    mov ds,ax
    lea bx,[Color]
    xor ax,ax
  @Loop:
    mov al,es:[di]
    mov si,bx
    add si,ax
    movsb
    loop @Loop
    pop ds
  end
end;

begin
  asm
    mov ax,ds
    mov es,ax
    lea di,[plBlack]
    xor ax,ax
    mov cx,0180h
    rep stosw
    lea di,[plStandard]
    mov cx,0180h
    rep stosw
    lea di,[plWhite]
    mov ax,3F3Fh
    mov cx,0180h
    rep stosw
  end;
  SetColor( 0,  0,  0, plStandard[0]);
  SetColor( 0,  0, 42, plStandard[1]);
  SetColor( 0, 42,  0, plStandard[2]);
  SetColor( 0, 42, 42, plStandard[3]);
  SetColor(42,  0,  0, plStandard[4]);
  SetColor(42,  0, 42, plStandard[5]);
  SetColor(42, 21,  0, plStandard[6]);
  SetColor(42, 42, 42, plStandard[7]);
  SetColor(21, 21, 21, plStandard[8]);
  SetColor(21, 21, 63, plStandard[9]);
  SetColor(21, 63, 21, plStandard[10]);
  SetColor(21, 63, 63, plStandard[11]);
  SetColor(63, 21, 21, plStandard[12]);
  SetColor(63, 21, 63, plStandard[13]);
  SetColor(63, 63, 21, plStandard[14]);
  SetColor(63, 63, 63, plStandard[15]);
end.
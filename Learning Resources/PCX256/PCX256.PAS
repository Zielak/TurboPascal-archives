{$G+}
{ (c) Krzysztof Heim }

unit PCX256;

interface

uses Graphic, Palette, Sprite;

type TPCX = record
              Ready                : Boolean;
              Xp, Yp, Width, Height: Integer;
              Size                 : LongInt;
              Palette              : TPalette;
              Buffer               : ^TPointer
            end;

 function LoadPCX(Name: string; var PCX: TPCX): Boolean;
procedure DecodePCX(PCX: TPCX; Output: Pointer);
procedure Decode(Input, Output: Pointer; Size: Word);
procedure FreePCX(var PCX: TPCX);
 function PCX2Sprite(PCX: TPCX; var Sprite: TSprite): Boolean;
procedure ShiftPalette(var Palette: TPalette);

implementation

procedure ShiftPalette(var Palette: TPalette); assembler;
asm
 les di,Palette
 mov cx,768
@Loop:
 shr Byte Ptr es:[di],2
 inc di
 loop @Loop
end;

procedure FreePCX(var PCX: TPCX);
begin
  with PCX do begin
    if not Ready then Exit;
    FreeMem(Buffer, Size);
    Ready:=FALSE
  end
end;

function LoadPCX(Name: string; var PCX: TPCX): Boolean;
var F: file;
    I: Byte;
begin
  LoadPCX:=FALSE;
  FreePCX(PCX);
  with PCX do begin
    Assign(F, Name);
    {$I-}
    Reset(F, 1);
    {$I+}
    if IOResult <> 0 then Exit;
    BlockRead(F, I, 1);
    if I <> 10 then begin
      Close(F);
      Exit
    end;
    Seek(F, 3);
    BlockRead(F, I, 1);
    if I <> 8 then begin
      Close(F);
      Exit
    end;
    BlockRead(F, Xp, 2);
    BlockRead(F, Yp, 2);
    BlockRead(F, Width, 2);
    BlockRead(F, Height, 2);
    Width:=(Width - Xp) + 1;
    Height:=(Height - Yp) + 1;
    Seek(F, 128);
    Size:=FileSize(F) - 897;
    if (Size > 65535) or (Size > MaxAvail) then begin
      Close(F);
      Exit
    end;
    GetMem(Buffer, Size);
    BlockRead(F, Buffer^, Size);
    BlockRead(F, I, 1);
    if I <> 12 then begin
      Close(F);
      FreeMem(Buffer, Size);
      Exit
    end;
    BlockRead(F, Palette, 768);
    ShiftPalette(Palette);
    Close(F);
    Ready:=TRUE
  end;
  LoadPCX:=TRUE
end;

procedure DecodePCX(PCX: TPCX; Output: Pointer); assembler;
var Width: Word;
asm
  push ds
  lds si,PCX
  cmp ds:[si].(TPCX.Ready),0
  jz @Exit
  les di,Output
  mov ax,ds:[si].(TPCX.Yp)
  mov cx,320
  mul cx
  add ax,ds:[si].(TPCX.Xp)
  add di,ax
  mov ax,ds:[si].(TPCX.Width)
  mov Width,ax
  mov dx,320
  sub dx,ax
  mov cx,ds:[si].(TPCX.Height)
  lds si,ds:[si].(TPCX.Buffer)
@LoopSize:
  push cx
  xor cx,cx
  xor bx,bx
@LoopWidth:
  lodsb
  mov ah,al
  and ah,0C0h
  cmp ah,0C0h
  je @Counter
  mov cl,1
@Copy:
  add bx,cx
  rep stosb
  cmp bx,Width
  jb @LoopWidth
  pop cx
  add di,dx
  loop @LoopSize
  jmp @Exit
@Counter:
  and al,3Fh
  mov cl,al
  lodsb
  jmp @Copy
@Exit:
  pop ds
end;

procedure Decode(Input, Output: Pointer; Size: Word); assembler;
asm
  les di,Output
  push ds
  lds si,Input
  xor cx,cx
  mov bx,Size
@Loop:
  lodsb
  dec bx
  mov ah,al
  and ah,0C0h
  cmp ah,0C0h
  je @Fill
  mov cl,1
@Copy:
  rep stosb
  cmp bx,0
  jz @Exit
  jmp @Loop
@Fill:
  and al,3Fh
  mov cl,al
  lodsb
  dec bx
  jmp @Copy
@Exit:
  pop ds
end;

function PCX2Sprite(PCX: TPCX; var Sprite: TSprite): Boolean;
var I: Word;
begin
  if not PCX.Ready then Exit;
  Sprite.Width:=PCX.Width;
  Sprite.Height:=PCX.Height;
  with Sprite do begin
    I:=Width * Height;
    if I > MaxAvail then Exit;
    GetMem(Sprite, I);
    Ready:=TRUE;
    Decode(PCX.Buffer, Sprite, PCX.Size)
  end
end;

end.
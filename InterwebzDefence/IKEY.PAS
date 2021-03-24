unit ikey;
interface
var code:array[0..128] of boolean;
    Int9hSave:pointer;

procedure InitKey;
procedure KillKey;

implementation
uses Dos;

{$F+}
procedure New_Key_Int;interrupt;assembler;
asm
  sti
  in al,60h
  xor ah,ah
  {mov raw_key, ax}
  cmp ax,128
  ja @UpKey
  {Pressed}
  lea di,code
  add di,ax
  mov al,1
  mov ds:[di],al
  jmp @Endzik
@UpKey:
  sub ax,128
  lea di,code
  add di,ax
  mov al,0
  mov ds:[di],al
@Endzik:
  in al,61h
  or al, 82h
  out 61h,al
  and al,7fh
  out 61h,al
  mov al,20h
  out 20h,al
end;
{$F-}

procedure InitKey;
begin
  GetIntVec($9,Int9hSave);
  SetIntVec($9,Addr(New_key_int));
end;

procedure KillKey;
begin
  SetIntVec($9,Int9hSave);
end;

end.
Unit GLib;

Interface

Uses Grafix;

Type
{  THeader = Record
    ID    : Array [1..12] of Char;
    V, SV : Byte;
    L, H  : Word;
    Mask  : Boolean;
    Pack  : Byte;
    PSize,
    MSize : Word;
    Res   : Array [1..8] of Byte
  End;}
  TLHeader = Record
    ID    : Array[1..12] of Char;
    V, SV : Byte;
    Comm  : String[63];
    Res   : Array[1..18] of Byte
  End;
  TPHeader = Record
    Name  : String[12];
    Size,
    DT    : LongInt;
    Comm  : String[63];
    Res   : Array[1..11] of Byte
  End;
  PLItem = ^TLItem;
  TLItem = Record
    Name : String[12];
    Rel  : LongInt;
    Prev,
    Next : PLItem
  End;

Const
  LID : Array[1..12] of Char = 'GrafLibrary';
  GLOk        =  0;
  GLCreate    = -1;
  GLLFind     = -2;
  GLFFind     = -3;
  GLPFind     = -4;
  GLLRead     = -5;
  GLFRead     = -6;
  GLLWrite    = -7;
  GLFWrite    = -8;
  GLLDelete   = -9;
  GLFDelete   =-10;

Var
  GLResult : Integer;

Function CMask (Mask, Name : String) : Boolean;

Function GLError (E : Integer) : String;

Procedure CreateLib (Name, Comm : String);

Procedure GetHLib (NLib : String; Var H : TLHeader);

Procedure AddPic (NLib, NPic, Comm : String);

Procedure ExtractPic (NLib : String; Path : String; Rel : LongInt);

Procedure DeletePic (NLib : String; Rel : LongInt);

Procedure GetLibList (NLib : String; Var List : PLItem);

Procedure GetHsPic (NLib : String; Rel : LongInt;
                    Var H0 : TPHeader; Var H1 : THeader);

Function FindItem (List : PLItem; Name : String) : PLItem;

Procedure DelList (Var L : PLItem);

Procedure LoadLibObject (NLib : String; Rel : LongInt;
                         Var PBitMap : Pointer; Var Size : Word);

Implementation

Uses
  DOS, Packer;

Function GLError (E : Integer) : String;
Var
  S : String;
Begin
  Case -E of
    0 : S := 'Ok';
    1 : S := 'Can not create a new library';
    2 : S := 'Can not find a library';
    3 : S := 'Can not find a file';
    5 : S := 'Error reading library';
    6 : S := 'Error reading file';
    7 : S := 'Error writeing library';
    8 : S := 'Error writing file';
    9 : S := 'Error deleting library';
    10: S := 'Error deleting file'
  End;
  GLError := S
End;

Function UpStr (S : String) : String;
Var I : Byte;
Begin
  If S <> '' then
    For I := 1 to Length(S) do
      S[I] := UpCase(S[I]);
  UpStr := S
End;

Function CMask (Mask, Name : String) : Boolean;
Var
  I, N : Byte;
  ME, NE,
  MN, NN : String;
  P : Boolean;
Label
  L1, L2, L3;
Function DelPath (Name : String) : String;
Var
  D : DirStr;
  N : NameStr;
  E : ExtStr;
Begin
  FSplit (Name, D, N, E);
  DelPath := N+E
End;
Begin
  Name := DelPath (Name);
  Mask := DelPath (Mask);
  P := False;
  If Pos ('.', Name) = 0 then Name := Name+'.';
  If Pos ('.', Mask) = 0 then Mask := Mask+'.';
  MN := Copy (Mask, 1, Pos ('.', Mask) - 1);
  NN := Copy (Name, 1, Pos ('.', Name) - 1);
  ME := Copy (Mask, Pos ('.', Mask), Length (Mask) - Length (MN));
  NE := Copy (Name, Pos ('.', Name), Length (Name) - Length (NN));
  If (ME=NE) or (ME[1] = '*') then Goto L1;
  If Length (ME) > Length (NE) then N := Length (NE)
  Else N := Length (ME);
  If Pos ('?', ME) > 0 then
    For I := 1 to N do
      If ME[I] = '?' then ME[I] := NE[I];
  If ME = NE then Goto L1;
  If Pos ('*', ME) > 0 then
    Begin
      ME := Copy (ME, 1, Pos ('*', ME) - 1);
      If ME = NE then Goto L1;
      If Length (ME) >= Length (NE) then Goto L3;
      Repeat
        ME := ME + NE[Length(ME)+1]
      Until Length (ME) = Length (NE);
      If ME = NE then Goto L1;
    End;
  Goto L3;
L1:
  If Length (MN) > Length (NN) then N := Length (NN)
  Else N := Length (MN);
  If Pos ('?', MN) > 0 then
    For I := 1 to N do
      If MN[I] = '?' then MN[I] := NN[I];
  If MN = NN then Goto L2;
  If Pos ('*', MN) > 0 then
    Begin
      MN := Copy (MN, 1, Pos ('*', MN) - 1);
      If MN = NN then Goto L2;
      If Length (MN) >= Length (NN) then Goto L3;
      Repeat
        MN := MN + NN[Length(MN)+1]
      UntIl Length (MN) = Length (NN);
      If MN = NN then Goto L2;
    End;
  Goto L3;
L2:
  P := True;
L3:
  CMask := P
End;

Procedure CreateLib (Name, Comm : String);
Var
  H : TLHeader;
  F : File;
Begin
  GLResult := GLCreate;
  Assign (F, Name);
  {$I-} Rewrite (F, 1); {$I+}
  If IOResult <> 0 then Exit;
  Move (LID, H.ID, SizeOf(LID));
  H.Comm := Comm;
  H.V := 1; H.SV := 0;
  FillChar (H.Res, SizeOf(H.Res), $FF);
  {$I-} BlockWrite (F, H, SizeOf(H)); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (F); {$I+};
      Exit
    End;
  {$I-} Close (F); {$I+}
  If IOResult <> 0 then Exit;
  GLResult := GLOk
End;

Procedure GetHLib (NLib : String; Var H : TLHeader);
Var
  FL : File;
Begin
  Assign (FL, NLib);
  {$I-} Reset (FL, 1); {$I+}
  If IOResult <> 0 then
    Begin
      GLResult := GLLFind;
      Exit
    End;
  {$I-} BlockRead (FL, H, SizeOf(H)); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+};
      GLResult := GLLRead;
      Exit
    End;
  {$I-} Close (FL); {$I+}
  If IOResult <> 0 then GLResult := GLLRead
  Else GLResult := GLOk
End;

Procedure AddPic (NLib, NPic, Comm : String);
Const
  BS    = 16384;
Var
  H     : TPHeader;
  FL, F : File;
  PBuf  : Pointer;
  LS    : LongInt;
  RD    : Word;
  DS : DirStr; NS : NameStr; ES : ExtStr;
Begin
  Assign (FL, NLib);
  {$I-} Reset (FL, 1); {$I+}
  If IOResult <> 0 then
    Begin
      GLResult := GLLFind;
      Exit
    End;
  Assign (F, NPic);
  {$I-} Reset (F, 1); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLFFind;
      Exit
    End;
  GetFTime (F, H.DT);
  {$I-} H.Size := FileSize (F); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      {$I-} Close (F); {$I+}
      GLResult := GLFRead;
      Exit
    End;
  H.Comm := Comm;
  FSplit (NPic, DS, NS, ES);
  H.Name := UpStr(NS+ES);
  {$I-} LS := FileSize (FL); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      {$I-} Close (F); {$I+}
      GLResult := GLLRead;
      Exit
    End;
  {$I-} Seek (FL, LS); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      {$I-} Close (F); {$I+}
      GLResult := GLLRead;
      Exit
    End;
  {$I-} BlockWrite (FL, H, SizeOf(H)); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      {$I-} Close (F); {$I+}
      GLResult := GLLWrite;
      Exit
    End;
  GetMem (PBuf, BS);
  Repeat
    {$I-} BlockRead (F, PBuf^, BS, RD); {$I+}
    If IOResult <> 0 then
      Begin
        {$I-} Close (FL); {$I+}
        {$I-} Close (F); {$I+}
        GLResult := GLFRead;
        FreeMem (PBuf, BS);
        Exit
      End;
    {$I-} BlockWrite (FL, PBuf^, RD); {$I+}
    If IOResult <> 0 then
      Begin
        {$I-} Close (FL); {$I+}
        {$I-} Close (F); {$I+}
        GLResult := GLLWrite;
        FreeMem (PBuf, BS);
        Exit
      End;
  Until RD < BS;
  FreeMem (PBuf, BS);
  {$I-} Close (FL); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (F); {$I+}
      GLResult := GLLWrite;
      Exit
    End;
  {$I-} Close (F); {$I+}
  If IOResult <> 0 then
    Begin
      GLResult := GLFRead;
      Exit
    End;
  GLResult := GLOk
End;

Procedure ExtractPic (NLib : String; Path : String; Rel : LongInt);
Const
  BS = 16384;
Var
  FL, F : File;
  H     : TPHeader;
  PBuf  : Pointer;
  RD    : Word;
Begin
  Assign (FL, NLib);
  {$I-} Reset (FL, 1); {$I+}
  If IOResult <> 0 then
    Begin
      GLResult := GLLFind;
      Exit
    End;
  {$I-} Seek (FL, Rel); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLLRead;
      Exit
    End;
  {$I-} BlockRead (FL, H, SizeOf(H)); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLLRead;
      Exit
    End;
  Assign (F, Path+H.Name);
  {$I-} Rewrite (F, 1); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLFWrite;
      Exit
    End;
  GetMem (PBuf, BS);
  Repeat
    {$I-} BlockRead (FL, PBuf^, BS, RD); {$I+}
    If IOResult <> 0 then
      Begin
        {$I-} Close (FL); {$I+}
        {$I-} Close (F); {$I+}
        GLResult := GLLRead;
        FreeMem (PBuf, BS);
        Exit
      End;
    If RD > H.Size then RD := H.Size;
    Dec (H.Size, RD);
    {$I-} BlockWrite (F, PBuf^, RD); {$I+}
    If IOResult <> 0 then
      Begin
        {$I-} Close (FL); {$I+}
        {$I-} Close (F); {$I+}
        GLResult := GLFWrite;
        FreeMem (PBuf, BS);
        Exit
      End;
  Until H.Size = 0;
  FreeMem (PBuf, BS);
  SetFTime (F, H.DT);
  {$I-} Close (FL); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (F); {$I+}
      GLResult := GLLWrite;
      Exit
    End;
  {$I-} Close (F); {$I+}
  If IOResult <> 0 then
    Begin
      GLResult := GLFRead;
      Exit
    End;
  GLResult := GLOk
End;

Procedure DeletePic (NLib : String; Rel : LongInt);
Const
  BS = 16384;
Var
  FL    : File;
  H     : TPHeader;
  RD    : Word;
  RW,
  R, RE : LongInt;
  PBuf  : Pointer;
Begin
  Assign (FL, NLib);
  {$I-} Reset (FL, 1); {$I+}
  If IOResult <> 0 then
    Begin
      GLResult := GLLRead;
      Exit
    End;
  {$I-} RE := FileSize (FL); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLLRead;
      Exit
    End;
  {$I-} Seek (FL, Rel); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLLRead;
      Exit
    End;
  {$I-} BlockRead (FL, H, SizeOf(H)); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLLRead;
      Exit
    End;
  {$I-} Seek (FL, Rel+SizeOf(H)+H.Size); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLLread;
      Exit
    End;
  {$I-} R := FilePos (FL); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLLread;
      Exit
    End;
  If R = RE then
    Begin
      {$I-} Seek (FL, Rel); {$I+}
      If IOResult <> 0 then
        Begin
          {$I-} Close (FL); {$I+}
          GLResult := GLLread;
          Exit
        End;
      {$I-} Truncate (FL); {$I+}
      If IOResult <> 0 then
        Begin
          {$I-} Close (FL); {$I+}
          GLResult := GLLWrite;
          Exit
        End;
      {$I-} Close (FL); {$I+}
      If IOResult <> 0 then
        Begin
          GLResult := GLFDelete;
          Exit
        End;
      GLResult := GLOk;
      Exit
    End;
  RW := Rel;
  R := Rel+SizeOf(H)+H.Size;
  GetMem (PBuf, BS);
  Repeat
    {$I-} Seek (FL, R); {$I+}
    If IOResult <> 0 then
      Begin
        {$I-} Close (FL); {$I+}
        GLResult := GLFDelete;
        Exit
      End;
    {$I-} BlockRead (FL, PBuf^, BS, RD); {$I+}
    If IOResult <> 0 then
      Begin
        {$I-} Close (FL); {$I+}
        GLResult := GLFDelete;
        Exit
      End;
    {$I-} Seek (FL, RW); {$I+}
    If IOResult <> 0 then
      Begin
        {$I-} Close (FL); {$I+}
        GLResult := GLFDelete;
        Exit
      End;
    {$I-} BlockWrite (FL, PBuf^, RD); {$I+}
    If IOResult <> 0 then
      Begin
        {$I-} Close (FL); {$I+}
        GLResult := GLFDelete;
        Exit
      End;
    Inc (R, RD);
    Inc (RW, RD)
  Until R = RE;
  FreeMem (PBuf, BS);
  {$I-} Truncate (FL); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLFDelete;
      Exit
    End;
  {$I-} Close (FL); {$I+}
  If IOResult <> 0 then
    Begin
      GLResult := GLFDelete;
      Exit
    End;
End;

Procedure AddItem (Var L : PLItem; Name : String; Rel : LongInt);
Var
  P0, P : PLItem;
Begin
  If L = Nil then
    Begin
      New (L);
      L^.Name := Name;
      L^.Rel := Rel;
      L^.Prev := Nil;
      L^.Next := Nil
    End
  Else
    Begin
      P := L;
      While P^.Next <> Nil do
        P := P^.Next;
      New (P0);
      P^.Next := P0;
      P0^.Name := Name;
      P0^.Rel := Rel;
      P0^.Prev := P;
      P0^.Next := Nil
   End;
End;

Function FindItem (List : PLItem; Name : String) : PLItem;
Var
  P : PLItem;
Begin
  P := List;
  While (P <> Nil) and (P^.Name <> Name) do
    P := P^.Next;
  FindItem := P
End;

Procedure DelList (Var L : PLItem);
Var
  P1, P2 : PLItem;
Begin
  If L = Nil then Exit;
  P1 := L;
  Repeat
    P2 := P1^.Next;
    Dispose (P1);
    P1 := P2
  Until P1 = Nil;
  L := Nil
End;

Procedure GetLibList (NLib : String; Var List : PLItem);
Var
  FL : File;
  R,
  RE : LongInt;
  H  : TPHeader;
Begin
  Assign (FL, NLib);
  {$I-} Reset (FL, 1); {$I+}
  If IOResult <> 0 then
    Begin
      GLResult := GLLFind;
      Exit
    End;
  {$I-} RE := FileSize (FL); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLLRead;
      Exit
    End;
  R := SizeOf(TLHeader);
  {$I-} Seek (FL, R); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLLRead;
      Exit
    End;
  While R < RE do Begin
    {$I-} BlockRead (FL, H, SizeOf(H)); {$I+}
    If IOResult <> 0 then
      Begin
        {$I-} Close (FL); {$I+}
        GLResult := GLLRead;
        Exit
      End;
    AddItem (List, H.Name, R);
    Inc (R, SizeOf(H)+H.Size);
    {$I-} Seek (FL, R); {$I+}
    If IOResult <> 0 then
      Begin
        {$I-} Close (FL); {$I+}
        GLResult := GLLRead;
        Exit
      End;
  End;
  {$I-} Close (FL); {$I+}
  If IOResult <> 0 then GLResult := GLLRead
  Else GLResult := GLOk
End;

Procedure GetHsPic (NLib : String; Rel : LongInt;
                    Var H0 : TPHeader; Var H1 : THeader);
Var
  FL : File;
Begin
  Assign (FL, NLib);
  {$I-} Reset (FL, 1); {$I+}
  If IOResult <> 0 then
    Begin
      GLResult := GLLFind;
      Exit
    End;
  {$I-} Seek (FL, Rel); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLLRead;
      Exit
    End;
  {$I-} BlockRead (FL, H0, SizeOf(H0)); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLLRead;
      Exit
    End;
  {$I-} BlockRead (FL, H1, SizeOf(H1)); {$I+}
  If IOResult <> 0 then
    Begin
      {$I-} Close (FL); {$I+}
      GLResult := GLLRead;
      Exit
    End;
  {$I-} Close (FL); {$I+}
  If IOResult <> 0 then
    GLResult := GLLRead
  Else
    GLResult := GLOk
End;

Procedure LoadLibObject (NLib : String; Rel : LongInt;
                         Var PBitMap : Pointer; Var Size : Word);
Const
  ID : Array [1..12] of Char = 'EGO''S FILE. ';
Var
  F : File;
  H0: TPHeader;
  H : THeader;
  I : Byte;
  P : Pointer;
  SF : Word;
Label
  LErr;
Begin
  PBitMap := nil;
  Assign (F, NLib);
  {$i-} Reset (F, 1); {$i+}
  If IOResult <> 0 then
    Begin
LErr:
      If PBitMap <> nil then
        FreeMem (PBitMap, Size);
      PBitMap := nil;
      Size := 0;
      GLResult := GLLRead;
      Exit
    End;
  {$I-} Seek (F, Rel); {$I+}
  IF IOResult <> 0 then Goto LErr;
  {$i-} BlockRead (F, H0, SizeOf(H0)); {$i+}
  IF IOResult <> 0 then Goto LErr;
   SF := H0.Size;
  {$i-} BlockRead (F, H, SizeOf(H)); {$i+}
  If IOResult <> 0 then Goto LErr;
  For I := 1 to 12 do
    If H.ID[I] <> ID[I] then Goto LErr;
  Case H.Pack of
    $00, $FF:
      Begin
        Size := (Ord(H.Mask)+1)*H.L*H.H+4;
        GetMem (PBitMap, Size);
        Word(PBitMap^) := H.L;
        PBitMap := Ptr(Seg(PBitMap^), Ofs(PBitMap^)+2);
        Word(PBitMap^) := H.H;
        PBitMap := Ptr(Seg(PBitMap^), Ofs(PBitMap^)+2);
        {$i-} BlockRead (F, PBitMap^, Size-4); {$i+}
        PBitMap := Ptr(Seg(PBitMap^), Ofs(PBitMap^)-4);
        If IOResult <> 0 then Goto LErr;
        {$i-} Close (F); {$i+}
        If IOResult <> 0 then Goto LErr;
      End;
    $01:
      Begin
        Dec (SF, 32);
        GetMem (P, SF);
        {$I-} BlockRead (F, P^, SF); {$I+}
        If IOResult <> 0 then
          Begin FreeMem (P, SF); Goto LErr End;
        {$I-} Close (F); {$I+}
        If IOResult <> 0 then
          Begin FreeMem (P, SF); Goto LErr End;
        Size := (Ord(H.Mask)+1)*H.L*H.H+4;
        GetMem (PBitMap, Size);
        Word(PBitMap^) := H.L;
        PBitMap := Ptr(Seg(PBitMap^), Ofs(PBitMap^)+2);
        Word(PBitMap^) := H.H;
        PBitMap := Ptr(Seg(PBitMap^), Ofs(PBitMap^)+2);
        UnPack (P^, PBitMap^, H.PSize);
        If H.Mask then
          Begin
            P := Ptr(Seg(P^), Ofs(P^)+H.PSize);
            PBitMap := Ptr(Seg(PBitMap^), Ofs(PBitMap^)+H.L*H.H);
            UnPack (P^, PBitMap^, H.MSize);
            PBitMap := Ptr(Seg(PBitMap^), Ofs(PBitMap^)-H.L*H.H);
            P := Ptr(Seg(P^), Ofs(P^)-H.PSize)
          End;
        PBitMap := Ptr(Seg(PBitMap^), Ofs(PBitMap^)-4);
        FreeMem (P, SF)
      End;
  End;
  GLResult := GLOk
End;

Begin
  GLResult := GLOk
End.

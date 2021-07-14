Unit FCMouse;

Interface

Type
  MGP = Record
    M : Array [0..15] of Word;
    P : Array [0..15] of Word
  End;

Var
  MousePresent,
  MouseReversed : Boolean;

Function MouseInit (Var NB : Word) : Boolean;

Procedure SetGraphPtr (HPX, HPY : Integer; GP : MGP);

Procedure MouseShow;

Procedure MouseHide;

Procedure MouseRead (Var X, Y, BMask : Word);

Procedure MouseSetPos (X, Y : Word);

Function MouseGetB (BMask : Word; Var Count, LastX, LastY : Word) : Word;

Procedure MouseReadText (Var X, Y, BMask : Word);

Procedure MouseSetPosText (X, Y : Word);

Function MouseGetBText (BMask : Word; Var Count, LastX, LastY : Word) : Word;

Procedure MouseBox (X1, Y1, X2, Y2 : Word);

Function MousePressed : Boolean;

Implementation

Uses
  DOS;

Var
  R  :  Registers;
  MI :  Pointer;

Procedure ExBit01 (Var W : Word);
Var
  F1, F2 : Boolean;
Begin
  F1 := W and 1 = 1;
  F2 := W and 2 = 2;
  W := (W and $FFFE) or Ord(F2);
  W := (W and $FFFD) or (2*Ord(F1))
End;

Function MouseInit (Var NB : Word) : Boolean;
Begin
  If MousePresent then
    Begin
      R.AX := 0;
      Intr ($33, R);
      If R.AX = 0 then
        Begin
          NB := 0;
          MouseInit := False
        End
      Else
        Begin
          NB := R.BX;
          MouseInit := True
        End
    End
  Else
    Begin
      NB := 0;
      MouseInit := False
    End
End;

Procedure SetGraphPtr (HPX, HPY : Integer; GP : MGP);
Begin
  R.AX := 9;
  R.BX := HPX;
  R.CX := HPY;
  R.ES := Seg(GP);
  R.DX := Ofs(GP);
  Intr ($33, R)
End;

Procedure MouseShow;
Begin
  R.AX := 1;
  Intr ($33, R)
End;

Procedure MouseHide;
Begin
  R.AX := 2;
  Intr ($33, R)
End;

Procedure MouseRead (Var X, Y, BMask : Word);
Begin
  R.AX := 3;
  Intr ($33, R);
  X := R.CX;
  Y := R.DX;
  BMask := R.BX;
  If MouseReversed then ExBit01 (BMask)
End;

Procedure MouseSetPos (X, Y : Word);
Begin
  R.AX := 4;
  R.CX := X;
  R.DX := Y;
  Intr ($33, R)
End;

Function MouseGetB (BMask : Word; Var Count, LastX, LastY : Word) : Word;
Begin
  If MouseReversed then ExBit01 (BMask);
  R.AX := 5;
  R.BX := BMask;
  Intr ($33, R);
  Count := R.BX;
  LastX := R.CX;
  LastY := R.DX;
  MouseGetB := R.AX
End;

Procedure MouseReadText (Var X, Y, BMask : Word);
Begin
  MouseRead (X, Y, BMask);
  X := 1 + X div 8;
  Y := 1 + Y div 8
End;

Procedure MouseSetPosText (X, Y : Word);
Begin
  X := 8*X - 1;
  Y := 8*Y - 1;
  MouseSetPos (X, Y)
End;

Function MouseGetBText (BMask : Word; Var Count, LastX, LastY : Word) : Word;
Var W : Word;
Begin
  W := MouseGetB (BMask, Count, LastX, LastY);
  LastX := 1 + LastX div 8;
  LastY := 1 + LastY div 8;
  MouseGetBText := W
End;

Procedure MouseBox (X1, Y1, X2, Y2 : Word);
Begin
  R.AX := $0007;
  R.CX := X1;
  R.DX := X2;
  Intr ($33, R);
  R.AX := $0008;
  R.CX := Y1;
  R.DX := Y2;
  Intr ($33, R)
End;

Function MousePressed : Boolean;
Var Z, K : Word;
Begin
  MouseRead (Z, Z, K);
  MousePressed := K and 3 <> 0
End;

Begin
  MouseReversed := False;
  GetIntVec ($33, MI);
  If MI = Nil then
    MousePresent := False
  Else
    If Byte (MI^) = $CE then
      MousePresent := False
    Else
      MousePresent := True
End.

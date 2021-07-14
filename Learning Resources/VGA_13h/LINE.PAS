Uses CRT, Grafix;

Function Sgn (I : Integer) : Integer; Assembler;
Asm
  Mov   AX, I
  Or    AX, AX
  JZ    @end
  ShL   AX, 1
  JC    @1
  Mov   AX, 1
  Jmp   @end
@1:
  Mov   AX, -1
@end:
End;

Function _Abs (I : Integer) : Integer; Assembler;
Asm
  Mov   AX, I
  Test  AX, 8000h
  JZ    @end
  Neg   AX
@end:
End;

Procedure Line2 (X1, Y1, X2, Y2 : Word; C : Byte; Patt : Word);
Var
  SX, SY, M, N,
  DX1, DY1, DX2, DY2 : Integer;
  X, Y, Cnt, K, P : Integer;
Begin
  SX := X2-X1;
  SY := Y2-Y1;
  DX1 := Sgn (SX);
  DY1 := Sgn (SY);
  M := _Abs (SX);
  N := _Abs (SY);
  DX2 := DX1;
  DY2 := 0;
  If M < N then
    Begin
      M := _Abs (SY);
      N := _Abs (SX);
      DX2 := 0;
      DY2 := DY1
    End;
  X := X1;
  Y := Y1;
  K := 0;
  P := 0;
  For Cnt := M downto 0 do Begin
    If (Patt shr (15-P)) and 1 = 1 then
      PutPixel (X, Y, C);
    Inc (P); P := P and 15;
    Inc (K, N);
    If K < M then Begin
      Inc (X, DX2);
      Inc (Y, DY2)
    End
    Else Begin
      Dec (K, M);
      Inc (X, DX1);
      Inc (Y, DY1)
    End
  End
End;

Begin
  initgraph;
  line2 (0, 0, 319, 199, yellow, $2727);
  readln;
  closegraph
End.

Uses CRT, KeyPres2;

Function Hex (W : Word) : String;
Const
  HC : Array [0..15] of Char = '0123456789ABCDEF';
Begin
  Hex := HC[Hi(W) shr 4] + HC[Hi(W) and 15] +
       HC[Lo(W) shr 4] + HC[Lo(W) and 15]
End;

Var
  I, J : Byte;

Begin
  ClrScr;
  WriteLn ('Here is a keyboard map; 1 - key is pressed, 0 - is not.');
  WriteLn ('Try to hit two or more keys together. What you''ll see?');
  WriteLn ('Press [Esc] to exit.');
  WaitForACSReleased;
  Set_Handler;
  Repeat
    GotoXY (1, 5);
    For J := 0 to 7 do Begin
      For I := 0 to 15 do
        Write (Ord(KeyMap[J*16+I]):3);
      WriteLn
    End;
    WriteLn (#13#10,'KeyPressedNow=',KeyPressedNow:5);
    If KeyPressed2 then Begin
      I := ReadScan;
      WriteLn ('Key scancode: ', Hex(I));
      WriteLn ('Key symbol  : ', SymMap[I])
    End;
  Until KeyMap[sEsc];
  Remove_Handler;
End.

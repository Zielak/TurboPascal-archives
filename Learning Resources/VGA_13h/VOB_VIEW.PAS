Uses
  CRT, DOS, Grafix;

Var
  PBitMap : Pointer;
  L, H,
  Size    : Word;
  S       : SearchRec;
  C       : Char;

Label
  LH, LE;

Begin
  If ParamCount <> 1 then
    Begin
      WriteLn ('Type VOB_VIEW.EXE <VOB_FILE> <ды to view any vob-file.');
      Exit
    End;
  InitGraph;
  If GrResult <> GrOk then
    Begin
      WriteLn ('Can''t set VGA 320x200 (256 colors) mode!');
      Halt
    End;
  FindFirst (Paramstr(1), anyfile-directory-volumeid, S);
  If DOSError <> 0 then Goto LH;
  While DOSError = 0 do
    Begin
      LoadObject (S.Name, PBitMap, Size);
      If GrResult <> GrOk then
        Begin
LH:
          CloseGraph;
          WriteLn ('Can''t read the ',S.Name,' file!');
          Halt
        End;
      ClearScreen (0);
      L := Word(PBitMap^);
      H := Word(Ptr(Seg(PBitMap^),Ofs(PBitMap^)+2)^);
      PutImage ((MaxX+1-L) div 2, (MaxY+1-H) div 2, PBitMap^);
      FreeMem (PBitMap, Size);
      Repeat
        If KeyPressed then C := ReadKey
        Else C := #$FF;
        If C = #27 then Goto LE;
        If C = #0 then C := ReadKey;
        If C <> #$FF then Break
      Until False;
      FindNext (S)
    End;
LE:
  CloseGraph
End.

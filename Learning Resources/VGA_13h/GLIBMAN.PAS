Uses
  CRT, DOS, GLib, Grafix, GfxFont;

Const
  Hlp = 'Type GLIBMAN.EXE <Command> <LIB> [PIC] <ды to process a library'+
        #13#10'Commands:'+
        #13#10'  A Add picture(s) PIC to library LIB'+
        #13#10'  D Delete picture(s) PIC from library LIB'+
        #13#10'  E Extract picture(s) PIC from library LIB'+
        #13#10'  L List contents of library LIB';
  Hl2 = #13#10'  V View picture(s) PIC from library LIB';
  TxD = 'Name          Size Date     Time      Dims   Mask Picture comment';
  DExt = 'VLB';

Var
  Cm, Cmd,
  NLib, NPic  : String;
  P0, P1,
  P, List     : PLItem;
  H           : TLHeader;
  H0          : TPHeader;
  H1          : THeader;
  FCnt,BL,BH  : Word;
  Cnt         : Byte;
  SR          : SearchRec;
  Rel         : LongInt;
  F           : File;
  PBitMap     : Pointer;
  BitMapSize  : Word;
  C           : Char;

Label
  LH, LV;

Function UpStr (S : String) : String;
Var I : Byte;
Begin
  If S <> '' then
    For I := 1 to Length(S) do
      S[I] := UpCase(S[I]);
  UpStr := S
End;

Function BStr (B : Boolean) : String;
Begin
  If B then BStr := 'Yes'
  Else BStr := 'No '
End;

Function DTS (T : LongInt) : String;
Var
  DT    : DateTime;
  S0, S : String;
Begin
  UnPackTime (T, DT);
  While DT.Year > 100 do Dec (DT.Year, 100);
  S := '';
  Str (DT.Day, S0); If Length(S0) < 2 then S0 := '0'+S0;
  S := S + S0 + '-';
  Str (DT.Month, S0); If Length(S0) < 2 then S0 := '0'+S0;
  S := S + S0 + '-';
  Str (DT.Year, S0); If Length(s0) < 2 then S0 := '0'+S0;
  S := S + S0 + ' ';
  Str (DT.Hour, S0); If Length(s0) < 2 then S0 := '0'+S0;
  S := S + S0 + ':';
  Str (DT.Min, S0); If Length(s0) < 2 then S0 := '0'+S0;
  S := S + S0 + ':';
  Str (DT.Sec, S0); If Length(s0) < 2 then S0 := '0'+S0;
  S := S + S0;
  DTS := S
End;

Function Exist (Name : String) : Boolean;
Var
  F : File;
  E : Boolean;
Begin
  Assign (F, Name);
  {$i-} Reset (F, 1); {$i+}
  E := IOResult = 0;
  If E then Close (F);
  Exist := E
End;

Function GetPath (Name : String) : String;
Var
  D : DirStr;
  N : NameStr;
  E : ExtStr;
Begin
  FSplit (Name, D, N, E);
  GetPath := D
End;

Begin
  If (ParamCount = 0) or (ParamStr(1) = '/?') then
    Begin
LH:
      WriteLn (Hlp, Hl2);
      Exit
    End;
  Cmd := UpStr(ParamStr(1));
  NLib := UpStr(ParamStr(2));
  If (NLib <> '') and (Pos('.',NLib) = 0) then
    NLib := NLib+'.'+DExt;
  NPic := UpStr(ParamStr(3));
  If Cmd = 'A' then
    Begin
      If ParamCount <> 3 then Goto LH;
      If not Exist (NLib) then
        Begin
{          WriteLn ('Enter library comment: ');
          Readln (Cm);}
          Cm := '';
          CreateLib (NLib, Cm);
          If GLResult <> 0 then
            Begin
              WriteLn (GLError (GLREsult));
              Exit
            End
        End;
{      WriteLn ('Enter picture comment: ');
      Readln (Cm);}
      Cm := '';
      FindFirst (NPic, anyfile-directory-volumeid, SR);
      FCnt := 0;
      While DOSError = 0 do
        Begin
          Write (SR.Name);
          AddPic (NLib, GetPath(NPic)+SR.Name, Cm);
          GotoXY (16, WhereY);
          WriteLn (GLError (GLREsult));
          If GLResult <> GLOk then Break;
          Inc (FCnt);
          FindNext (SR)
        End;
      WriteLn (FCnt, ' file(s)');
    End;
  If Cmd = 'L' then
    Begin
      If ParamCount <> 2 then Goto LH;
      List := nil;
      GetLibList (NLib, List);
      If GLResult = 0 then
        Begin
          GetHLib (NLib, H);
          If GLResult <> GLOk then
            Begin
              WriteLn (GLError (GLResult));
              DelList (List);
              Exit
            End;
          WriteLn ('Library ',NLib,':');
          If H.Comm <> '' then WriteLn ('Library comment: ', H.Comm);
          WriteLn (TxD);
          FCnt := 0;
          Cnt := 0;
          If List <> nil then
            Begin
              P := List;
              While P <> nil do
                Begin
                  GetHsPic (NLib, P^.Rel, H0, H1);
                  If GLResult <> GLOk then
                    Begin
                      WriteLn (GLError (GLResult));
                      DelList (List);
                      Break
                    End;
                  Write (H0.Name); GotoXY (14, WhereY);
                  Write (H0.Size:5,DTS(H0.DT):18,H1.L:4,'x',H1.H);
                  GotoXY (46, WhereY); Write (BStr(H1.Mask));
                  WriteLn ('  ',Copy(H0.Comm,1,29));
                  Inc (FCnt);
                  P := P^.Next;
                  Inc (Cnt);
                  If Cnt = 20 then
                    Begin
                      Write ('Press any key to continue...');
                      While not KeyPressed do;
                      While KeyPressed do ReadKey;
                      GotoXY (1, WhereY); ClrEOL;
                      Cnt := 0
                    End
                End
            End
        End;
      DelList (List);
      WriteLn (FCnt, ' file(s)')
    End;
  If Cmd = 'E' then
    Begin
      If ParamCount <> 3 then Goto LH;
      List := nil;
      GetLibList (NLib, List);
      If GLResult = 0 then
        Begin
          GetHLib (NLib, H);
          FCnt := 0;
          P := List;
          While P <> nil do
            Begin
              If CMask (NPic, P^.Name) then
                Begin
                  Write (P^.Name);
                  ExtractPic (NLib, GetPath(NPic), P^.Rel);
                  GotoXY (16, WhereY);
                  WriteLn (GLError (GLResult));
                  Inc (FCnt)
                End;
              P := P^.Next
            End
        End;
      DelList (List);
      WriteLn (FCnt, ' file(s)');
    End;
  If Cmd = 'D' then
    Begin
      If ParamCount <> 3 then Goto LH;
      List := nil;
      GetLibList (NLib, List);
      If GLResult = 0 then
        Begin
          GetHLib (NLib, H);
          FCnt := 0;
          Rel := 0;
          P := List;
          While P <> nil do
            Begin
              If CMask (NPic, P^.Name) then
                Begin
                  Write (P^.Name);
                  DeletePic (NLib, P^.Rel-Rel);
                  If P^.Next <> nil then
                    Inc (Rel, P^.Next^.Rel-P^.Rel);
                  GotoXY (16, WhereY);
                  WriteLn (GLError (GLResult));
                  If GLResult <> GLOk then Break;
                  Inc (FCnt)
                End;
              P := P^.Next
            End
        End;
      DelList (List);
      WriteLn (FCnt, ' file(s)');
      List := nil;
      GetLibList (NLib, List);
      If GLResult = 0 then
        Begin
          If List = nil then
            Begin
              WriteLn ('Deleting empty library');
              Assign (F, NLib);
              {$I-} Erase (F); {$I+}
              If IOResult = 0 then
                WriteLn (GLError (GLOk))
              Else
                WriteLn (GLError (GLLDelete))
            End
        End
      Else
        WriteLn (GLError (GLLRead));
      DelList (List)
    End;
  If Cmd = 'V' then
    Begin
      If ParamCount <> 3 then Goto LH;
      List := nil;
      GetLibList (NLib, List);
      If GLResult = 0 then
        Begin
          GetHLib (NLib, H);
          FCnt := 0;
          P := List;
          InitGraph;
          If GrResult <> GrOk then
            Begin
              WriteLn ('Can''t set VGA 320x200 256 color video mode 13H!');
              DelList (List);
              Exit
            End;
          SetFont (@Font6x7);
          While P <> nil do
            Begin
LV:
              If CMask (NPic, P^.Name) then
                Begin
                  ClearScreen (Black);
                  LoadLibObject (NLib, P^.Rel, PBitMap, BitMapSize);
                  If GLResult <> GLOk then
                    Begin
                      CloseGraph;
                      WriteLn (GLError (GLResult));
                      DelList (List);
                      Exit
                    End;
                  BL := Word(PBitMap^);
                  BH := Word(Ptr(Seg(PBitMap^),Ofs(PBitMap^)+2)^);
                  PutImage ((MaxX+1-BL) div 2, (MaxY+1-BH) div 2, PBitMap^);
                  FreeMem (PBitMap, BitMapSize);
                  WriteS (0, 0, Black, LightCyan, P^.Name);
                  Repeat
                    If KeyPressed then C := ReadKey
                    Else C := #$FF;
                    If C In [#13,#27] then Break;
                    If C = #0 then
                      Begin
                        C := ReadKey;
                        Case C of
                          #75 :
                            Begin
                              P1 := nil;
                              P0 := List;
                              Repeat
                                While not CMask(NPic,P0^.Name) do
                                  P0 := P0^.Next;
                                If (P0 = P) then
                                  If (P1 <> nil) then
                                    Begin
                                      P := P1;
                                      Goto LV
                                    End
                                  Else Break;
                                P1 := P0;
                                P0 := P0^.Next
                              Until false
                            End;
                          #77 :
                            Begin
                              P0 := P^.Next;
                              While (P0 <> nil) and not CMask(NPic,P0^.Name) do
                                P0 := P0^.Next;
                              If P0 <> nil then Break
                            End
                        End
                      End;
                  Until False;
                  If C = #27 then Break
                End;
              P := P^.Next
            End;
          CloseGraph
        End;
      DelList (List)
    End
End.

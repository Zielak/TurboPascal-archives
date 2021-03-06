Uses CRT, DOS, Grafix, KeyPres2;

Const
  TRate = 6;            { �� ᪮�쪮 ࠧ �� ࠡ�⠥� ⠩���.          }
                        { �ᯮ������ ��� ������஢���� ����� ᭠�鸞 }
  Step = 6;             { ��� ⠭�� �� �������� }

  D = 20;               { ����থ窠 }

Type
  TTank = Object                        { ��ꥪ� ��ꥤ���� ����� � ��⮤� }
    X, Y,                               { ���न���� ⠭�� }
    DX, DY : Integer;                   { ���饭�� ��� ���न��� }
                                        { �� �������� }
    Phase : Byte;                       { ���� ��।���� ����� ���⨭�� � }
                                        { ���ࠢ����� �������� ⠭�� (㣮�) }
    Pic : Array [1..16] of Pointer;     { �����⥫� �� ���⨭�� ⠭�� }
    Back : Pointer;                     { �����⥫� �� ������� ��࠭���� 䮭� }
                                        { ��� ⠭��� }
    PX, PY,                             { ���न���� ᭠�鸞 }
    PDX, PDY : Integer;                 { ���饭�� ��� ���न��� }
                                        { �� �������� }
    PBack : Byte;                       { ���� �窨 䮭� ��� ᭠�冷� }
    Shooting : Boolean;                 { �ਧ��� ����饣� ᭠�鸞 }

    Procedure Init (FName : String; IX, IY : Word; IPhase : Byte);
    { ���樠������� ��ꥪ�: ��㧨� ���⨭��, ��⠭�������� ��砫�� }
    { ���न���� ⠭�� � ���ࠢ����� ��� �������� }

    Procedure Done;
    { �᢮������� ������ �� ���⨭�� ⠭�� }

    Procedure Draw;
    { ����� ⠭� }

    Procedure Hide;
    { ��ࠥ� ⠭� � ��࠭� }

    Procedure Move (Direction : Integer);
    { �����稢���/㬥��蠥� ���न���� ⠭��: 㢥���., �᫨ Direction=1; }
    { 㬥���., �᫨ Direction=1 }

    Procedure Rotate (Direction : Integer);
    { "�����稢���" ⠭�, ������� ����ࠢ����� �������� }

    Procedure Shoot;
    { �����⠢������ ��, �� �㦭�, � ����५� }
  End;

Var
  Old_Timer : Pointer;  { �����⥫� �� ���� ��ࠡ��稪 ����. ⠩��� }
  Time : Byte;          { ���稪 ⠩��� }
  Tank : TTank;         { ����⢥��� "⠭�" }

Procedure TTank.Init;
Const
  Num : Array [1..16] of String[2] =
    ('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16');
Var
  F : File;
  I : Byte;
Begin
  For I := 1 to 16 do Begin
    GetMem (Pic[I], 4+16*16);
    Assign (F, FName+Num[I]+'.SPR');
    Reset (F, 1);
    Word(Pic[I]^) := 16;                        { ��ਭ� ���⨭�� }
    Inc (LongInt(Pic[I]), 2);
    Word(Pic[I]^) := 16;                        { ���� ���⨭�� }
    Inc (LongInt(Pic[I]), 2);
    BlockRead (F, Pic[I]^, 16*16);
    Dec (LongInt(Pic[I]), 4);
    Close (F)
  End;
  GetMem (Back, 4+16*16);
  X := IX; Y := IY;
  Phase := IPhase;
  DX := Round(Step*Cos((Phase-1)*0.392699)); { 2*PI/16=0.392699 }
  DY := Round(Step*Sin((Phase-1)*0.392699));
  Shooting := False
End;

Procedure TTank.Done;
Var I : Byte;
Begin
  For I := 1 to 16 do
    FreeMem (Pic[I], 4+16*16);
  FreeMem (Back, 4+16*16)
End;

Procedure TTank.Draw;
Begin
  GetImage (X, Y, 16, 16, Back^);       { ���࠭��� 䮭 ��� ⠭��� }
  PutTranspImage (X, Y, Pic[Phase]^)    { ���ᮢ��� "�஧���" ⠭� }
End;

Procedure TTank.Hide;
Begin
  PutImage (X, Y, Back^)                { ����⠭����� 䮭 ��� ⠭��� }
End;

Procedure TTank.Move;
Var
  DDX, DDY : Integer;
Begin
  DDX := DX*Direction;
  DDY := DY*Direction;
  Inc (X, DDX); If (X < 0) or (X > 320-16) then Dec (X, DDX);
  Dec (Y, DDY); If (Y < 0) or (Y > 200-16) then Inc (Y, DDY)
End;

Procedure TTank.Rotate;
Begin
  Inc (Phase, Direction);
  If Phase > 16 then Dec (Phase, 16)
  Else If Phase < 1 then Inc (Phase, 16);
  DX := Round(Step*Cos((Phase-1)*0.392699));
  DY := Round(Step*Sin((Phase-1)*0.392699))
End;

Procedure TTank.Shoot;
Begin
  PX := X+8;
  PY := Y+8;                            { ��५塞 ��אַ �� ��譨 }
  PDX := DX;
  PDY := DY;                            { � ���ࠢ����� �������� ⠭�� }
  Time := 0;
  Shooting := True                      { ��� "���������" ⠩���� }
End;

Procedure New_Timer; Interrupt;
{ ���� �ࠡ��稪 ���뢠��� �� ⠩��� }
Begin
  If Time = 0 then Asm
    PushF                               { ��뢠�� � �०��� ���⮩        }
    Call DWord Ptr Old_Timer            { ���� ��ࠡ��稪 ⠩�. ���뢠��� }
  End
  Else Port[$20] := $20;                { ����� �� ��뢠��, ᮮ�頥�      }
                                        { ����஫���� ���뢠���, ��      }
                                        { ���뢠��� �� ⠩��� ��ࠡ�⠭� }

  Inc (Time);                           { �� � ���ᯥ稢��� �맮� ��ண� }
  If Time=TRate then Time := 0;         { ��ࠡ��稪� � ��ன ���⮩   }
                                        { �⮡� �� �㤨�� ���             }

  If not Tank.Shooting then Exit;       { ��� ����५� }

  If Time and 1 = 0 then Begin  { ���㥬 ᭠�� }
    Tank.PBack := GetPixel (Tank.PX, Tank.PY);
    PutPixel (Tank.PX, Tank.PY, White)
  End
  Else Begin                    { � ⥯��� ��ࠥ� � �����塞 ��� ���न���� }
    PutPixel (Tank.PX, Tank.PY, Tank.PBack);
    Inc (Tank.PX, Tank.PDX);
    Dec (Tank.PY, Tank.PDY);
    If (Tank.PX < 0) or (Tank.PX > 319) or
      (Tank.PY < 0) or (Tank.PY > 199) then
        Tank.Shooting := False          { �뫥⥫ �� �࠭��� ��࠭� }
  End
End;

Var
  S : Byte;                             { ������� ������ }
  P : Pointer;                          { �����⥫� �� 䮭���� ���⨭�� }
  Sz : Word;                            { ������ 䮭���� ���⨭�� }
  Pal : TPal;                           { ������ 䮭���� ���⨭�� }

Begin
  Tank.Init ('TANK', 160, 100, 5);      { ���樠�����㥬 ⠭� }
{  LoadPCX256 ('TOWN.PCX', P, Sz, Pal);}
  GetIntVec (8, Old_Timer);             { ����. ���� ��ண� ��ࠡ��稪�
                                        { ���뢠��� �� ⠩��� }
  SetIntVec (8, @New_Timer);
  Port[$43] := $34;                             { �᪮ਫ� ����� }
  Port[$40] := ($FFFF div TRate) and $FF;       { ⠩��� �        }
  Port[$40] := ($FFFF div TRate) shr 8;         { TRate ࠧ        }

  WaitForACSReleased;            { ���� ���᪠��� Alt,Ctrl,Shift, }
                                 { ���� �㤥�, ������� ���� }
  Set_Handler;                   { �⠢�� ��� ��ࠡ��稪 ��������୮�� }
                                 { ���뢠��� ��� ����襭�� ᪮��� }
                                 { ����� � ���������� � ��ࠡ�⪨ }
                                 { �����६����� ����⨩ ������ }

  InitGraph;
  ClearScreen (Green);
(*  SetPal (Pal);                { ��⠭����� ������� ���⨭�� }
  PutImage (0, 0, P^);           { ���㫨 ���⨭�� �� ��࠭ }
  FreeMem (P, Sz); *)            { ����� - ��६� �� �����ࠧ�� }
  Tank.Draw;                     { ���ᮢ��� ⠭� }

  Repeat
    If KeyPressed2 then S := ReadScan { ����� �-� �����, ����� ᪠���� }
    Else S := 0;

    { ���஡� ��४����� 䨣��� ᪮��� � ��ࠦ���� ⨯� }
    { "KeyMap[s*]" �� ��ࠦ���� �த� "S = s*", �� ������? }

    If {S = sUp} KeyMap[sUp] then Begin
      Tank.Hide;
      Tank.Move (1);
      Tank.Draw;
      Delay (D)
    End;
    If {S = sDown} KeyMap[sDown] then Begin
      Tank.Hide;
      Tank.Move (-1);
      Tank.Draw;
      Delay (D)
    End;
    If {S = sLeft} KeyMap[sLeft] then Begin
      Tank.Hide;
      Tank.Rotate (1);
      Tank.Draw;
      Delay (D)
    End;
    If {S = sRight} KeyMap[sRight] then Begin
      Tank.Hide;
      Tank.Rotate (-1);
      Tank.Draw;
      Delay (D)
    End;
    If {S = sSpace} KeyMap[sSpace] then Begin
      If not Tank.Shooting then
        Tank.Shoot
    End;
  Until KeyMap[sEsc];                   { ����� Escap'� }

  Remove_Handler;                       { ���㫨 ���� ��ࠡ��稪 }
                                        { ���뢠��� �� ���������� }
  SetIntVec (8, Old_Timer);             { ���㫨 ���� ��ࠡ��稪 }
                                        { ���뢠��� �� ⠩��� }

  Port[$43] := $34;                     { ���㫨 �०��� ����� }
  Port[$40] := $00;                     { ⠩��� -               }
  Port[$40] := $00;                     { 18.2 ����               }
  CloseGraph;
  Tank.Done                             { �᢮������ ������ ��। ��室�� - }
                                        { �ࠢ��� ��襣� ⮭�             }

  { ��� ���, ���� �� �� ���� ��� ��砭�!!! }
End.

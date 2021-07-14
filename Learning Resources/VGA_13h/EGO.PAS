Uses
  CRT, Grafix, FCMouse, Packer, GLib, GfxFont;

Type
  PGPic = ^TGPic;
  TGPic = Array [0..199,0..319] of Byte; { !!! [Y,X] !!! }

Const
  Dts   = 4;
  WX    = 2;
  WY    = 10;
  WH    = 24;
  WL    = 32;
  W1X   = 230;
  W1Y   = 10;
  W1L   = 80;
  W1H   = 60;
  Dcx   = 7;
  Dcy   = 5;
  WCX   = 2;
  WCY   = 143;
{  NFont = 'EGO.FNT';}
  NL    = 'EGO.VLB';
  NE    = '.VOB';

Var
  NLib,
  Name                  : String;               { имя тек. файла }
  PPic, PMask, PCP      : PGPic;                { картинка, маска и текущ. }
  HM                    : Boolean;              { наличие маски }
  CP                    : Boolean;              { текущая - картинка }
  OL, OH,                                       { размеры картинки }
  WFX, WFY              : Word;                 { координаты окна }
  Color, Back           : Byte;                 { цвета }
  MX, MY, MB            : Word;                 { коорд. мыши и сост. кл. }
  WMX, WMY              : Byte;                 { коорд. мыши в окне }
  Op                    : Byte;                 { операция }
  C                     : Char;
  S                     : String;
  SBL, SBR, SBU, SBD,
  SBLT                  : Pointer;
  W1FX, W1FY            : Word;
  LList                 : PLItem;
  CPlus                 : Byte;

Function ShiftPressed : Boolean;
Begin
  ShiftPressed := Mem[0:1047] and 3 <> 0
End;

Function UpStr (S : String) : String;
Var I : Byte;
Begin
  If S <> '' then
    For I := 1 to Length(S) do
      S[I] := UpCase(S[I]);
  UpStr := S
End;

Function NS (N : LongInt; L : Byte) : String;
Var
  S : String;
Begin
  Str (N, S);
  While Length(S) < L do S := S + ' ';
  NS := S
End;

Function Val (S : String; Var R : Word) : Boolean;
Var
  W : Word;
  E : Integer;
Begin
  System.Val (S, W, E);
  If (E = 0) and (S <> '') then R := W;
  Val := (E = 0) and (S <> '')
End;

Procedure SetDefaults;
Begin
  OL := 32; OH := 24;
  WFX := 0; WFY := 0;
  HM := False;
  Color := White;
  Back := Black;
  Name := '';
  W1FX := 0; W1FY := 0;
  CPlus := 0;
  Op := 0
End;

Procedure MMouseSetPos (X, Y : Word);
Begin
  MouseSetPos (X*2, Y)
End;

Procedure MMouseRead (Var X, Y, B : Word);
Begin
  MouseRead (X, Y, B);
  X := X div 2
End;

Function MousePressed : Boolean;
Begin
  MMouseRead (MX, MY, MB);
  MousePressed := MB and 3 > 0
End;

Function MouseIn (MX, MY, X, Y, L, H : Word) : Boolean;
Begin
  MouseIn := (X <= MX) and (MX < X+L) and (Y <= MY) and (MY < Y+H)
End;

Procedure GetCoords (MX, MY : Word; Var X, Y : Byte);
Begin
  If MouseIn (MX, MY, WX, WY, (Dts+1)*WL, (Dts+1)*WH) then
    Begin
      X := (MX-WX) div (Dts+1);
      Y := (MY-WY) div (Dts+1)
    End
  Else
    Begin
      X := $FF;
      Y := $FF
    End
End;

Procedure Clear;
Var
  I, J : Word;
Begin
  For J := 0 to OH-1 do
    For I := 0 to OL-1 do
      PCP^[J,I] := Back
End;

Procedure ClearAll;
Var
  I, J : Word;
Begin
  For J := 0 to MaxY do
    For I := 0 to MaxX do
      PCP^[J,I] := 0
End;

Procedure IncColor;
Var
  I, J : Word;
Begin
  For J := 0 to OH-1 do
    For I := 0 to OL-1 do
      Inc (PCP^[J,I])
End;

Procedure DecColor;
Var
  I, J : Word;
Begin
  For J := 0 to OH-1 do
    For I := 0 to OL-1 do
      Dec (PCP^[J,I])
End;

Procedure Fill2 (Y, X : Word; C : Byte);
Type
  SU = Array [$0000..$7CFF] of Word;
  SD = Array [$7D00..$F9FF] of Word;
Var
  PU : ^SU;
  PD : ^SD;
  P,
  CX, CY,
  SP : Word;
  CO : Byte;
Procedure Push (Rel : Word);
Begin
  If SP < $7D00 then PU^[SP] := Rel
  Else PD^[SP] := Rel;
  Inc (SP)
End;
Procedure Pop (Var Rel : Word);
Begin
  Dec (SP);
  If SP < $7D00 then Rel := PU^[SP]
  Else Rel := PD^[SP]
End;
Function CanGo (DX, DY : Integer) : Boolean;
Begin
  CanGo := (CX+DX >= 0) and (CX+DX < OL) and
           (CY+DY >= 0) and (CY+DY < OH) and
           (PCP^[CY+DY,CX+DX] = CO)
End;
Begin
  CO := PCP^[Y,X];
  If CO = C then Exit;
  New (PU); New (PD);
  SP := 0;
  CX := X; CY := Y;
  Repeat
    PCP^[CY,CX] := C;
    P := CY*320 + CX;
    If CanGo (-1, 0) then Push (P-1);
    If CanGo (1, 0) then Push (P+1);
    If CanGo (0, -1) then Push (P-320);
    If CanGo (0, 1) then Push (P+320);
    If SP = 0 then Break;
    Pop (P);
    CX := P mod 320; CY := P div 320
  Until false;
  Dispose (PD); Dispose (PU)
End;


Procedure GWin (X, Y, L, H : Word; Title : String; S : Boolean);
Const
  D   = 2;
  SD  = 6;
  FC  = LightGray;
Begin
  Box (X, Y, L, H, FC, False);
  Box (X+1, Y+1, L-2, H-2, Black, False);
  Box (X+D, Y+D, L-2*D, 8, Cyan, True);
  WriteS (X+(L-FontX*Length(Title)) div 2, Y+D+1, Black, Black, Title);
  If S then
    Begin
      Box (X+D, Y+H-D-8, L-2*D, 8, FC, True);
      Box (X+L-D-8, Y+D+8, 8, H-8-2*D, FC, True);
      PutImage (X+D, Y+H-D-8, SBL^);
      PutImage (X+L-D-2*8, Y+H-D-8, SBR^);
      PutImage (X+L-D-8, Y+D+8, SBU^);
      PutImage (X+L-D-8, Y+H-D-2*8, SBD^)
    End;
End;

Procedure WLift (X, Y, L, H : Word; P : Byte; D : Boolean);
Begin
  If L = 0 then
    If D then
      PutImage (X, Y+H*P div 100, SBLT^)
    Else
      Box (X, Y+H*P div 100, 8, 8, LightGray, True);
  If H = 0 then
    If D then
      PutImage (X+L*P div 100, Y, SBLT^)
    Else
      Box (X+L*P div 100, Y, 8, 8, LightGray, True)
End;

Procedure WSetka;
Var
  I : Word;
Begin
  For I := 0 to WL do
    LineV (WX+I*(Dts+1), WY, WH*(Dts+1)+1, 8);
  For I := 0 to WH do
    LineH (WX, WY+I*(Dts+1), WL*(Dts+1)+1, 8)
End;

Procedure WColor;
Var
  I, J : Word;
Begin
  Box (WCX-2, WCY-1, 172, 58, LightGray, False);
  For J := 0 to 1 do
    For I := 0 to 15 do
      Box (WCX+I*Dcx, WCY+J*Dcy, Dcx, Dcy, J*16+I, True);
  For J := 0 to 8 do
    For I := 0 to 23 do
      Box (WCX+I*Dcx, WCY+2*Dcy+J*Dcy, Dcx, Dcy, 32+J*24+I, True);
End;

Procedure WCC;
Const
  X = 120;
  Y = 144;
  DX = 8;
  DY = 4;
Begin
  Box (X, Y, DX+4, DY+4, LightGray, False);
  Box (X+2, Y+2, DX, DY, Color, True);
  Box (X+14, Y, DX+4, DY+4, LightGray, False);
  Box (X+14+2, Y+2, DX, DY, Back, True);
End;

Procedure WCCC (C : Byte);
Begin
  WriteS (150, 145, Black, LightGray, NS(C,3))
End;

Procedure WParams;
Const
  X = 174; Y = 0;
  L = 34; H = 46;
Begin
  Box (X, Y, L, H, LightGray, False);
  WriteS (X+2, Y+23, Cyan, Blue, 'L:'+NS(OL,3));
  WriteS (X+2, Y+30, Cyan, Blue, 'H:'+NS(OH,3));
  If HM then
    WriteS (X+2, Y+37, Cyan, Blue, 'M:Yes')
  Else
    WriteS (X+2, Y+37, Cyan, Blue, 'M:No ');
End;

Procedure WCur;
Const
  X = 174; Y = 0;
Begin
  If WMX and WMY <> $FF then
    Begin
      WriteS (X+2, Y+2, Cyan, Blue, 'X:'+NS(WFX+WMX,3));
      WriteS (X+2, Y+9, Cyan, Blue, 'Y:'+NS(WFY+WMY,3));
      WriteS (X+2, Y+16, Cyan, Blue, 'C:'+NS(PCP^[WFY+WMY,WFX+WMX],3))
    End
  Else
    Begin
      WriteS (X+2, Y+2, Cyan, Blue, 'X:   ');
      WriteS (X+2, Y+9, Cyan, Blue, 'Y:   ');
      WriteS (X+2, Y+16, Cyan, Blue, 'C:   ')
    End;
  WriteS (176, 128, Black, LightCyan, '+:'+NS(CPlus,3));
  If CPlus = 0 then
    WriteS (176, 135, Black, LightCyan, '-:'+NS(0,3))
  Else
    WriteS (176, 135, Black, LightCyan, '-:'+NS(256-CPlus,3))
End;

Procedure WPWin;
Var
  I, J : Word;
Begin
  For J := 0 to WH-1 do
    For I := 0 to WL-1 do
      If PCP^[WFY+J,WFX+I] <> $FF then
        Box (WX+I*(Dts+1)+1, WY+J*(Dts+1)+1, Dts, Dts, PCP^[WFY+J,WFX+I], True)
      Else
        Box (WX+I*(Dts+1)+1, WY+J*(Dts+1)+1, Dts, Dts, LightGray, True)
End;

Procedure W1x1;
Var
  I, J : Word;
Begin
  For J := 0 to W1H-1 do
    For I := 0 to W1L-1 do
      If PCP^[W1FY+J,W1FX+I] <> $FF then
        PutPixel (W1X+I, W1Y+J, PCP^[W1FY+J,W1FX+I])
      Else
        PutPixel (W1X+I, W1Y+J, LightGray)
End;

Procedure PCPCur;
Begin
  If PCP = PPic then
    Begin
      Box (201, 61, 14, 14, Black, False);
      Box (188, 61, 14, 14, 39, False);
    End
  Else
    Begin
      Box (188, 61, 14, 14, Black, False);
      Box (201, 61, 14, 14, 39, False);
    End;
End;

Procedure SetGP;
Const
   SmallGP : Array [0..31] of Word =
   ($3fff, $0fff, $03ff, $01ff, $03ff, $03ff, $21ff, $f1ff,
    $f9ff, $ffff, $ffff, $ffff, $ffff, $ffff, $ffff, $ffff,
    $0000, $4000, $7000, $7c00, $7000, $5800, $0c00, $0400,
    $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000);
Begin
  SetGraphPtr (0, 0, MGP(SmallGP))
End;

Procedure Init;
Var
  S : Word;
Begin
  If not MouseInit (S) then
    Begin
      WriteLn ('Can''t work without mouse!');
      Halt;
    End;
{  LoadFont (NFont, CurFont, FontSize);
  If GrResult <> GrOk then
    Begin
      WriteLn ('Font file ',NFont,' not found!');
      Halt
    End;
  SetFont (CurFont);}
  SetFont (@Font6x7);
  NLib := ParamStr (0);
  While NLib[Length(NLib)] <> '\' do Dec(NLib[0]);
  NLib := NLib + NL;
  GetLibList (NLib, LList);
  If GLResult <> 0 then
    Begin
      WriteLn ('Can''t read a '+NLib+' file!');
      Halt
    End;
  InitGraph;
  If GrResult <> GrOk then
    Begin
      WriteLn ('Can''t set a VGA 320x200 (256 colors) mode!');
      Halt
    End;
  SetGP;
  LoadLibObject (NLib, FindItem(LList,'BS_LFT.VOB')^.Rel, SBL, S);
  LoadLibObject (NLib, FindItem(LList,'BS_RGT.VOB')^.Rel, SBR, S);
  LoadLibObject (NLib, FindItem(LList,'BS_UP.VOB')^.Rel, SBU, S);
  LoadLibObject (NLib, FindItem(LList,'BS_DWN.VOB')^.Rel, SBD, S);
  LoadLibObject (NLib, FindItem(LList,'BS_LIFT.VOB')^.Rel, SBLT, S)
End;

Procedure PPack (PP : PGPic; PBuf : Pointer); Assembler;
Asm
  Push  DS
  Mov   BX, Word Ptr OH
  Mov   DX, Word Ptr OL                 { DX, BX <- OL, OH }
  Mov   AX, Word Ptr PBuf
  Mov   DI, AX
  Mov   AX, Word Ptr PBuf+2
  Mov   ES, AX                          { ES:DI = PBuf }
  Mov   AX, Word Ptr PP
  Mov   SI, AX
  Mov   AX, Word Ptr PP+2
  Mov   DS, AX                          { DS:SI = PP }
  CLD
@1:
  Push  SI
  Mov   CX, DX
  Rep   MovSB
  Pop   SI
  Add   SI, 320
  Dec   BX
  JNZ   @1
  Pop   DS
End;

Procedure PUnPack (PBuf : Pointer; PP : PGPic); Assembler;
Asm
  Push  DS
  Mov   BX, Word Ptr OH
  Mov   DX, Word Ptr OL                 { DX, BX <- OL, OH }
  Mov   AX, Word Ptr PP
  Mov   DI, AX
  Mov   AX, Word Ptr PP+2
  Mov   ES, AX                          { ES:DI = PP }
  Mov   AX, Word Ptr PBuf
  Mov   SI, AX
  Mov   AX, Word Ptr PBuf+2
  Mov   DS, AX                          { DS:SI = PBuf }
  CLD
@1:
  Push  DI
  Mov   CX, DX
  Rep   MovSB
  Pop   DI
  Add   DI, 320
  Dec   BX
  JNZ   @1
  Pop   DS
End;

Procedure SaveF;
Const
  ID : Array[1..12] of Char = 'EGO''S FILE. ';
Var
  H     : THeader;
  F     : File;
  P,
  PBuf  : Pointer;
  SP    : Word;
Begin
  Move (ID, H.ID, SizeOf(ID));
  H.V := 1; H.SV := 0;
  H.L := OL; H.H := OH;
  H.Mask := HM;
  H.Pack := 1;
  FillChar (H.Res, SizeOf(H.Res), $FF);
  GetMem (PBuf, OL*OH);
  GetMem (P, OL*OH);
  Assign (F, Name+NE);
  Rewrite (F, 1);
  BlockWrite (F, H, SizeOf(H));
  PPack (PPic, PBuf);
  H.PSize := Pack (PBuf^, P^, OL*OH);
  BlockWrite (F, P^, H.PSize);
  H.MSize := 0;
  If HM then
    Begin
      PPack (PMask, PBuf);
      H.MSize := Pack (PBuf^, P^, OL*OH);
      BlockWrite (F, P^, H.MSize)
    End;
  Seek (F, 0);
  BlockWrite (F, H, SizeOf(H));
  Close (F);
  FreeMem (P, OL*OH);
  FreeMem (PBuf, OL*OH)
End;

Procedure LoadF;
Var
  H     : THeader;
  F     : File;
  P,
  PBuf  : Pointer;
  SF    : Word;
Begin
  Assign (F, Name+NE);
  {$i-} Reset (F, 1); {$i+}
  If IOResult <> 0 then
    Begin
      GrResult := GrLoadObj;
      Exit
    End;
  BlockRead (F, H, SizeOf(H));
  OL := H.L; OH := H.H;
  HM := H.Mask;
  Case H.Pack of
    $00, $FF:
      Begin
        GetMem (PBuf, OL*OH);
        BlockRead (F, PBuf^, OL*OH);
        PUnPack (PBuf, PPic);
        If HM then
          Begin
            BlockRead (F, PBuf^, OL*OH);
            PUnPack (PBuf, PMask)
          End;
        Close (F);
        FreeMem (PBuf, OL*OH)
      End;
    $01:
      Begin
        SF := FileSize(F)-32;
        GetMem (P, SF);
        BlockRead (F, P^, SF);
        Close (F);
        GetMem (PBuf, OL*OH);
        UnPack (P^, PBuf^, H.PSize);
        PUnPack (PBuf, PPic);
        If HM then
          Begin
            P := Ptr(Seg(P^), Ofs(P^)+H.PSize);
            UnPack (P^, PBuf^, H.MSize);
            PUnPack (PBuf, PMask);
            P := Ptr(Seg(P^), Ofs(P^)-H.PSize);
          End;
        FreeMem (PBuf, OL*OH);
        FreeMem (P, SF)
      End;
  End;
  CPlus := 0;
  GrResult := GrOk
End;

Procedure SaveFile;
Var S : String;
Label LE;
Begin
  MouseHide;
  S := Name;
  ReadS (230, 180, LightGray, Black, S, 8);
  Box (230, 180, 8*FontX, FontY, Black, True);
  If S = '' then Goto LE;
  Name := Upstr(S);
  SaveF;
  GWin (0, 0, 173, 141, 'Object: '+Name, True);
LE:
  MouseShow
End;

Procedure LoadFile;
Var S : String;
Label LE;
Begin
  MouseHide;
  S := Name;
  ReadS (230, 180, LightGray, Black, S, 8);
  Box (230, 180, 8*FontX, FontY, Black, True);
  If S = '' then Goto LE;
  Name := UpStr(S);
  LoadF;
  If GrResult <> GrOk then Goto LE;
  WParams;
  PCP := PPic;
  WPWin;
  W1x1;
  PCPCur;
  GWin (0, 0, 173, 141, 'Object: '+Name, True);
  WFX := 0; WFY := 0;
  W1FX := 0; W1FY := 0;
  WPWin;
  W1x1;
  PCPCur;
LE:
  MouseShow
End;

Procedure ScrlLeft;
Begin
  If WFX = 0 then Exit;
  Dec (WFX)
End;
Procedure ScrlRight;
Begin
  If WFX+WL >= OL then Exit;
  Inc (WFX)
End;
Procedure ScrlUp;
Begin
  If WFY = 0 then Exit;
  Dec (WFY)
End;
Procedure ScrlDown;
Begin
  If WFY+WH >= OH then Exit;
  Inc (WFY)
End;

Procedure Scrl1Left;
Begin
  If W1FX = 0 then Exit;
  Dec (W1FX)
End;
Procedure Scrl1Right;
Begin
  If W1FX+W1L >= OL then Exit;
  Inc (W1FX)
End;
Procedure Scrl1Up;
Begin
  If W1FY = 0 then Exit;
  Dec (W1FY)
End;
Procedure Scrl1Down;
Begin
  If W1FY+W1H >= OH then Exit;
  Inc (W1FY)
End;

Procedure RollLeft;
Var
  W,
  I, J : Word;
Begin
  If OL or OH = 1 then Exit;
  For J := 0 to OH-1 do
    Begin
      W := PCP^[J,0];
      For I := 0 to OL-2 do
        PCP^[J,I] := PCP^[J,I+1];
      PCP^[J,OL-1] := W
    End
End;
Procedure RollRight;
Var
  W,
  I, J : Word;
Begin
  If OL or OH = 1 then Exit;
  For J := 0 to OH-1 do
    Begin
      W := PCP^[J,OL-1];
      For I := OL-1 downto 1 do
        PCP^[J,I] := PCP^[J,I-1];
      PCP^[J,0] := W
    End
End;
Procedure RollUp;
Var
  W,
  I, J : Word;
Begin
  If OL or OH = 1 then Exit;
  For I := 0 to OL-1 do
    Begin
      W := PCP^[0,I];
      For J := 0 to OH-2 do
        PCP^[J,I] := PCP^[J+1,I];
      PCP^[OH-1,I] := W
    End
End;
Procedure RollDown;
Var
  W,
  I, J : Word;
Begin
  If OL or OH = 1 then Exit;
  For I := 0 to OL-1 do
    Begin
      W := PCP^[OH-1,I];
      For J := OH-1 downto 1 do
        PCP^[J,I] := PCP^[J-1,I];
      PCP^[0,I] := W
    End
End;

Procedure MirrorH;
Var
  B       : Byte;
  I, J, K : Word;
Begin
  If OL = 1 then Exit;
  K := OL div 2;
  For J := 0 to OH-1 do
    For I := 0 to K-1 do
      Begin
        B := PCP^[J,I];
        PCP^[J,I] := PCP^[J,OL-I-1];
        PCP^[J,OL-I-1] := B
      End
End;
Procedure MirrorV;
Var
  B       : Byte;
  I, J, K : Word;
Begin
  If OH = 1 then Exit;
  K := OH div 2;
  For I := 0 to OL-1 do
    For J := 0 to K-1 do
      Begin
        B := PCP^[J,I];
        PCP^[J,I] := PCP^[OH-J-1,I];
        PCP^[OH-J-1,I] := B
      End
End;

Procedure RotateC;
Var
  P     : PGPic;
  I, J  : Word;
Begin
  If OL <> OH then Exit;
  New (P);
  Move (PCP^, P^, SizeOf(TGPic));
  For J := 0 to OH-1 do
    For I := 0 to OL-1 do
      P^[I,OH-1-J] := PCP^[J,I];
  Move (P^, PCP^, SizeOf(TGPic));
  Dispose (P)
End;
Procedure RotateUC;
Var
  P     : PGPic;
  I, J  : Word;
Begin
  If OL <> OH then Exit;
  New (P);
  Move (PCP^, P^, SizeOf(TGPic));
  For J := 0 to OH-1 do
    For I := 0 to OL-1 do
      P^[OL-1-I,J] := PCP^[J,I];
  Move (P^, PCP^, SizeOf(TGPic));
  Dispose (P)
End;

Procedure WProc;
Const
  WX = 174; WY = 47;
  L = 42; H = 81;
  NH = 3; D = 13;
  PN : Array [1..17] of String[8] =
  ('LOAD', 'SAVE', 'EXIT', 'CLEAR', 'PICTURE', 'MASK',
   'ROLL_LFT', 'ROLL_RGT', 'ROT_CW', 'ROLL_UP', 'ROLL_DWN', 'ROT_UCW',
   'MIRR_HRZ', 'MIRR_VRT', 'PENCIL', 'TOMASK', 'FILL');
Var
  I : Byte;
  P : Pointer;
  X, Y,
  S : Word;
Begin
  Box (WX, WY, L, H, LightGray, False);
  X := WX+2; Y := WY+2;
  For I := 1 to 17 do
    Begin
      LoadLibObject (NLib, FindItem(LList,PN[I]+NE)^.Rel, P, S);
      PutImage (X, Y, P^);
      FreeMem (P, S);
      Inc (X, D);
      If I mod NH = 0 then
        Begin
          X := WX+2;
          Inc (Y, D)
        End
    End
End;

Procedure ToMask;
Var
  I, J : Word;
Begin
  For J := 0 to OH-1 do
    For I := 0 to OL-1 do
      If PPic^[J,I] > 0 then
        PMask^[J,I] := 0
      Else
        PMask^[J,I] := $FF
End;

Label
  LL, LH, LM, CL, LF, SF, RL, RR, RU, RD;

Begin
  Init;
  New (PPic);
  New (PMask);
  Back := 0;
  OL := MaxX+1;
  OH := MaxY+1;
  PCP := PMask;
  Clear;
  PCP := PPic;
  Clear;
  SetDefaults;
  WProc;
  GWin (0, 0, 173, 141, 'Object: '+Name, True);
  GWin (W1X-2, W1Y-10, 92, 80, '1x1', True);
  WSetka;
  WColor;
  WPWin;
  WCC;
  WParams;
  PCPCur;
  MMouseSetPos (MaxX div 2, MaxY div 2);
  MouseShow;
  Repeat
    If KeyPressed then C := ReadKey
    Else C := #$FF;
    Case C of
      ^L: Goto RL;
      ^R: Goto RR;
      ^U: Goto RU;
      ^D: Goto RD;
      #9:
        Begin
          If PCP = PPic then PCP := PMask
          Else PCP := PPic;
          MouseHide;
          WPWin;
          W1x1;
          PCPCur;
          MouseShow
        End;
      '-' :
        Begin
          If CPlus > 0 then Dec (CPlus)
          Else CPlus := 255;
          DecColor;
          MouseHide;
          WPWin;
          W1x1;
          MouseShow
        End;
      '+' :
        Begin
          If CPlus < 255 then Inc (CPlus)
          Else CPlus := 0;
          IncColor;
          MouseHide;
          WPWin;
          W1x1;
          MouseShow
        End;
    End;
    If C In [^L,^R,^U,^D] then
      Begin
        MouseHide;
        WPWin;
        W1x1;
        MouseShow
      End;
    If C = #0 then
      Begin
        C := Readkey;
        Case C of
          #50 : Goto LM;
          #60 : Goto SF;
          #61 : Goto LF;
          #45 : Break;
          #35 : Goto LH;
          #38 : Goto LL;
          #83 : Goto CL;
        End
      End;
    WriteS (200, 150, Cyan, Blue, NS(MX,3)+':'+NS(MY,3));
    MMouseRead (MX, MY, MB);
    GetCoords (MX, MY, WMX, WMY);
    WCur;
    If MouseIn (MX, MY, WX, WY, (Dts+1)*WL, (Dts+1)*WH) and
       (MB and 4 > 0) then
        Begin
          Color := PCP^[WFY+WMY,WFX+WMX];
          WCC
        End;
    If MouseIn (MX, MY, WX, WY, (Dts+1)*WL, (Dts+1)*WH) then
      Case Op of
        0: { карандаш }
          Begin
            If PCP = PPic then
              Begin
                If MB and 1 > 0 then
                  PCP^[WFY+WMY,WFX+WMX] := Color
                Else If MB and 2 > 0 then
                  PCP^[WFY+WMY,WFX+WMX] := Back
                End
            Else
              Begin
                If MB and 1 > 0 then
                  PCP^[WFY+WMY,WFX+WMX] := $FF
                Else If MB and 2 > 0 then
                  PCP^[WFY+WMY,WFX+WMX] := 0
                End;
            If MB and 3 > 0 then
              Begin
                MouseHide;
                While MousePressed do;
                WPWin;
                W1x1;
                MouseShow
              End
          End;
        1: { заливка }
          Begin
            If MB and 3 > 0 then MouseHide;
            If PCP = PPic then
              If MB and 1 > 0 then
                Fill2 (WFY+WMY, WFX+WMX, Color)
              Else If MB and 2 > 0 then
                Fill2 (WFY+WMY, WFX+WMX, Back)
            Else
              If MB and 1 > 0 then
                Fill2 (WFY+WMY, WFX+WMX, $FF)
              Else If MB and 2 > 0 then
                Fill2 (WFY+WMY, WFX+WMX, 0);
            If MB and 3 > 0 then
              Begin
                While MousePressed do;
                WPWin;
                W1x1;
                MouseShow
              End
          End;
    End;
    If MB and 1 > 0 then
      Begin
        If MouseIn (MX, MY, 202, 101, 12, 12) then
          Begin
            Op := 0;
          End;
        If MouseIn (MX, MY, 189, 114, 12, 12) then
          Begin
            Op := 1;
          End;
        If MouseIn (MX, MY, 2, 131, 8, 8) then
          Begin
            MouseHide;
            WLift (10, 131, 145, 0, Round (100*WFX/OL), False);
            ScrlLeft;
            WPWin;
            WLift (10, 131, 145, 0, Round (100*WFX/OL), True);
            MouseShow
          End;
        If MouseIn (MX, MY, 155, 131, 8, 8) then
          Begin
            MouseHide;
            WLift (10, 131, 145, 0, Round (100*WFX/OL), False);
            ScrlRight;
            WPWin;
            WLift (10, 131, 145, 0, Round (100*WFX/OL), True);
            MouseShow
          End;
        If MouseIn (MX, MY, 163, 10, 8, 8) then
          Begin
            MouseHide;
            WLift (163, 18, 0, 105, Round (100*WFY/OH), False);
            ScrlUp;
            WPWin;
            WLift (163, 18, 0, 105, Round (100*WFY/OH), True);
            MouseShow
          End;
        If MouseIn (MX, MY, 163, 123, 8, 8) then
          Begin
            MouseHide;
            WLift (163, 18, 0, 105, Round (100*WFY/OH), False);
            ScrlDown;
            WPWin;
            WLift (163, 18, 0, 105, Round (100*WFY/OH), True);
            MouseShow
          End;
        If MouseIn (MX, MY, 230, 70, 8, 8) then
          Begin
            Scrl1Left;
            W1x1;
          End;
        If MouseIn (MX, MY, 302, 70, 8, 8) then
          Begin
            Scrl1Right;
            W1x1;
          End;
        If MouseIn (MX, MY, 310, 10, 8, 8) then
          Begin
            Scrl1Up;
            W1x1;
          End;
        If MouseIn (MX, MY, 310, 62, 8, 8) then
          Begin
            Scrl1Down;
            W1x1;
          End;
        If MouseIn (MX, MY, 174, 23, 30, 7) then
          Begin
LL:
            MouseHide;
            Str (OL, S);
            ReadS (188, 23, Cyan, Blue, S, 3);
            Val (S, OL);
            If OL = 0 then OL := 1
            Else If OL > 320 then OL := 320;
            WParams;
            MouseShow;
            If C <> #$FF then Continue
          End;
        If MouseIn (MX, MY, 174, 30, 30, 7) then
          Begin
LH:
            MouseHide;
            Str (OH, S);
            ReadS (188, 30, Cyan, Blue, S, 3);
            Val (S, OH);
            If OH = 0 then OH := 1
            Else If OH > 200 then OH := 200;
            WParams;
            MouseShow;
            If C <> #$FF then Continue
          End;
        If MouseIn (MX, MY, 174, 37, 30, 7) then
          Begin
LM:
            HM := not HM;
            MouseHide;
            While MousePressed do;
            WParams;
            MouseShow;
            If C <> #$FF then Continue
          End;
        If MouseIn (MX, MY, 175, 49, 12, 12) then
          Begin
LF:
            LoadFile;
            Continue
          End;
        If MouseIn (MX, MY, 188, 49, 12, 12) then
          Begin
SF:
            SaveFile;
            Continue
          End;
        If MouseIn (MX, MY, 201, 49, 12, 12) then
          Begin
            Break
          End;
        If MouseIn (MX, MY, 201, 75, 12, 12) then
          Begin
            RotateC;
            MouseHide;
            WPWin;
            W1x1;
            While MousePressed do;
            MouseShow
          End;
        If MouseIn (MX, MY, 201, 88, 12, 12) then
          Begin
            RotateUC;
            MouseHide;
            WPWin;
            W1x1;
            While MousePressed do;
            MouseShow
          End;
        If MouseIn (MX, MY, 188, 62, 12, 12) then
          Begin
            PCP := PPic;
            MouseHide;
            WPWin;
            W1x1;
            PCPCur;
            MouseShow
          End;
        If MouseIn (MX, MY, 201, 62, 12, 12) then
          Begin
            PCP := PMask;
            MouseHide;
            WPWin;
            W1x1;
            PCPCur;
            MouseShow
          End;
        If MouseIn (MX, MY, 175, 101, 12, 12) then
          Begin
            MouseHide;
            MirrorH;
            While MousePressed do;
            WPWin;
            W1x1;
            MouseShow;
            If C <> #$FF then Continue
          End;
        If MouseIn (MX, MY, 188, 101, 12, 12) then
          Begin
            MouseHide;
            MirrorV;
            While MousePressed do;
            WPWin;
            W1x1;
            MouseShow;
            If C <> #$FF then Continue
          End;
        If MouseIn (MX, MY, 176, 114, 12, 12) then
          Begin
            MouseHide;
            ToMask;
            While MousePressed do;
            WPWin;
            W1x1;
            MouseShow
          End
      End;
      If MouseIn (MX, MY, 175, 62, 12, 12) and MousePressed then
        Begin
CL:
          If C <> #$FF then
            If ShiftPressed then MB := 2
            Else MB := 1;
          If PCP = PMask then
            Begin
              Byte(C) := Back;
              Back := $FF
            End;
          If MB and 1 > 0 then Clear
          Else If MB and 2 > 0 then ClearAll;
          If PCP = PMask then
            Begin
              Back := Byte(C);
              C := #$FF
            End;
          MouseHide;
          WPWin;
          W1x1;
          MouseShow;
          If C <> #$FF then Continue
        End;
    If MouseIn (MX, MY, 175, 75, 12, 12) and MousePressed then
      Begin
RL:
        MouseHide;
        RollLeft;
        If MB and 1 > 0 then While MousePressed do;
        WPWin;
        W1x1;
        MouseShow;
        If C <> #$FF then Continue
      End;
    If MouseIn (MX, MY, 188, 75, 12, 12) and MousePressed then
      Begin
RR:
        MouseHide;
        RollRight;
        If MB and 1 > 0 then While MousePressed do;
        WPWin;
        W1x1;
        MouseShow;
        If C <> #$FF then Continue
      End;
    If MouseIn (MX, MY, 175, 88, 12, 12) and MousePressed then
      Begin
RU:
        MouseHide;
        RollUp;
        If MB and 1 > 0 then While MousePressed do;
        WPWin;
        W1x1;
        MouseShow;
        If C <> #$FF then Continue
      End;
    If MouseIn (MX, MY, 188, 88, 12, 12) and MousePressed then
      Begin
RD:
        MouseHide;
        RollDown;
        If MB and 1 > 0 then While MousePressed do;
        WPWin;
        W1x1;
        MouseShow;
        If C <> #$FF then Continue
      End;
    If MouseIn (MX, MY, 2, 143, 112, 10) then
      Begin
        If MB and 1 > 0 then
          Color := (MX-2) div Dcx + 16*((MY-143) div Dcy);
        If MB and 2 > 0 then
          Back := (MX-2) div Dcx + 16*((MY-143) div Dcy);
        WCCC ((MX-2) div Dcx + 16*((MY-143) div Dcy));
        If MB and 3 > 0 then
          Begin
            MouseHide; While MousePressed do;
            WCC; MouseShow;
          End;
      End;
    If MouseIn (MX, MY, 2, 153, 24*Dcx, 9*Dcy) then
      Begin
        If MB and 1 > 0 then
          Color := 32+(MX-2) div Dcx + 24*((MY-153) div Dcy);
        If MB and 2 > 0 then
          Back := 32+(MX-2) div Dcx + 24*((MY-153) div Dcy);
        WCCC (32+(MX-2) div Dcx + 24*((MY-153) div Dcy));
        If MB and 3 > 0 then
          Begin
            MouseHide; While MousePressed do;
            WCC; MouseShow;
          End;
      End;
  Until False;
  MouseHide;
  FreeMem (SBL, 68); FreeMem (SBR, 68); FreeMem (SBU, 68); FreeMem (SBD, 68);
  FreeMem (SBLT, 68);
  Dispose (PMask);
  Dispose (PPic);
{  FreeMem (CurFont, FontSize);}
  CloseGraph
End.

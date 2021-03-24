unit TBMP;

{ Unit for show Windows Bitmap files.        }
{ Now support only :                         }
{   BMP 256 colors (Not RLE)                 }
{   BMP 16  colors (Not RLE)                 }
{ image show in CURRENT screen graphics mode }

interface

const
  BmpOk           =  0;
  BmpUnknownError = -1;
  BmpFileNotFound = -2;
  BmpNotSuppRes   = -3;
  BmpNotSuppFmt   = -4;

  function ShowBitMapImage(Name : String; X, Y : Word) : Integer;

implementation

uses Crt, Dos, Graph;

type
  TPaletteEntry = record
    B: Byte;
    G: Byte;
    R: Byte;
    Flags: Byte;
  end;
  TBitmapFileHeader = record
    bfType: Word;
    bfSize: Longint;
    bfReserved1: Word;
    bfReserved2: Word;
    bfOffBits: Longint;
    biSize: Longint;
    biWidth: Longint;
    biHeight: Longint;
    biPlanes: Word;
    biBitCount: Word;
    biCompression: Longint;
    biSizeImage: Longint;
    biXPelsPerMeter: Longint;
    biYPelsPerMeter: Longint;
    biClrUsed: Longint;
    biClrImportant: Longint;
  end;

var
  BitmapName : String;
  F : File;
  bfh : TBitmapFileHeader;
  Pal256 : array[0..255] of TPaletteEntry;
  Pal16 : array[0..15] of TPaletteEntry;
  FileOpen : Boolean;
  Width_R, Width, Height : Word;
  BitCount : Word;
  Xstart, Ystart, xt, yt : Word;
  W2 : Word;

  function SwapNibble(B : Byte) : Byte;
    {-Swap the high and low nibbles of B: SwapNibble($F0) returns $0F.}
    inline(
      $58/                     {pop ax     ;AL = B}
      $88/$C4/                 {mov ah,al  ;AH = B}
      $B9/$04/$00/             {mov cx,4   ;4 bits/nibble}
                               {Start:}
      $D0/$CC/                 {ror ah,1   ;rotate rightmost bit of AH}
      $D0/$D8/                 {rcr al,1   ;into leftmost bit of AL}
      $E2/$FA);                {loop Start ;do it four times}

  function OpenFile : Boolean;
  begin
    FileOpen := False;
    OpenFile := False;
    Assign(F, BitmapName);
    Reset(F, 1);
    if IoResult <> 0 then Exit;
    FileOpen := True;
    OpenFile := True;
  end;

  function CloseFile : Boolean;
  begin
    FileOpen := False;
    CloseFile := False;
    Close(F);
    if IoResult <> 0 then Exit;
    CloseFile := True;
  end;

  function ReadBMPFileHead : Boolean;
  begin
    ReadBMPFileHead := False;
    BlockRead(F, bfh, SizeOf(bfh));
    if (IoResult <> 0) or
       (bfh.bfType <> $4D42) then Exit;
    Width := bfh.biWidth;
    Height := bfh.biHeight;
    BitCount := bfh.biBitCount;
    Width_R := Width;
    ReadBMPFileHead := True;
  end;

  function ReadPalette16 : Boolean;
  var C : Byte;
  begin
    ReadPalette16 := False;
    BlockRead(F, Pal16, SizeOf(Pal16));
    if IoResult <> 0 then Exit;
    for C := 0 to 15 do
      begin
        Pal16[C].R := Pal16[C].R shr 2;
        Pal16[C].G := Pal16[C].G shr 2;
        Pal16[C].B := Pal16[C].B shr 2;
      end;
    ReadPalette16 := True;
  end;

  function ReadPalette256 : Boolean;
  var C : Byte;
  begin
    ReadPalette256 := False;
    BlockRead(F, Pal256, SizeOf(Pal256));
    if IoResult <> 0 then Exit;
    for C := 0 to 255 do
      begin
        Pal256[C].R := Pal256[C].R shr 2;
        Pal256[C].G := Pal256[C].G shr 2;
        Pal256[C].B := Pal256[C].B shr 2;
      end;
    ReadPalette256 := True;
  end;

  procedure SetPalette256;
  const
    RED = 0;
    GREEN = 1;
    BLUE = 2;
  type
    Pal_array = array[0..255, RED..BLUE] of Byte;
  var
    Palette256 : Pal_array;
    Reg : Registers;
    i : Byte;
  begin
    for i := 0 to 255 do
      begin
        Palette256[i, RED]   := Pal256[i].R;
        Palette256[i, GREEN] := Pal256[i].G;
        Palette256[i, BLUE]  := Pal256[i].B;
      end;
    Reg.ah := $10;                { Set DAC Call }
    Reg.al := $12;                { set a block of DAC registers }
    Reg.bx := 0;                  { first DAC register number }
    Reg.cx := 255;                { number of registers to update }
    Reg.dx := Ofs(Palette256);    { offset of block }
    Reg.es := Seg(Palette256);    { segment of block }
    Intr($10, Reg);               { call interrupt }
  end;

  function SetPalette16 : Boolean;
  const
    RED = 0;
    GREEN = 1;
    BLUE = 2;
  type
    Pal_array = array[0..15, RED..BLUE] of Byte;
  var
    Palette16 : Pal_array;
    Reg : Registers;
    i : Byte;
  begin
    for i := 0 to 15 do
      begin
        Palette16[i, RED]   := Pal16[i].R;
        Palette16[i, GREEN] := Pal16[i].G;
        Palette16[i, BLUE]  := Pal16[i].B;
      end;
    Reg.ah := $10;                { Set DAC Call }
    Reg.al := $12;                { set a block of DAC registers }
    Reg.bx := 0;                  { first DAC register number }
    Reg.cx := 16;                 { number of registers to update }
    Reg.dx := Ofs(Palette16);     { offset of block }
    Reg.es := Seg(Palette16);     { segment of block }
    Intr($10, Reg);               { call interrupt }
  end;

  function ShowImage4 : Boolean;
  var
    Px, C0, C1 : Byte;
    Lin4 : array[0..1023] of Byte;
  begin
    ShowImage4 := False;
    Seek(F, bfh.bfOffBits);
    if (Width mod 8) <> 0 then
      while (Width mod 8) <> 0 do Inc(Width);

    W2 := (Width_R-1) div 2;
    for yt := Height-1 downto 0 do
      begin
        BlockRead(F, Lin4, Width div 2);
        for xt := 0 to W2 do
          begin
            Px := Lin4[xt];
            C0 := Px shr 4;
            Px := SwapNibble(Px);
            C1 := Px shr 4;
            PutPixel(Xstart+xt*2, Ystart+yt, C0);
            PutPixel(Xstart+xt*2+1, Ystart+yt, C1);
          end;
      end;
    ShowImage4 := True;
  end;

  function ShowImage8 : Boolean;
  type
    TLin = record
      X, Y : Word;
      Data : array[0..1023] of Byte;
    end;
  var
    SizeP : Word;
    Lin8 : ^TLin;
  begin
    ShowImage8 := False;
    if (Width mod 4) <> 0 then
      while (Width mod 4) <> 0 do Inc(Width);
    Seek(F, bfh.bfOffBits);
    SizeP := ImageSize(0, 0, 1028, 0);
    GetMem(Lin8, SizeP);
    Lin8^.X := Width_R-1;
    Lin8^.Y := 0;
    for yt := Height-1 downto 0 do
      begin
        BlockRead(F, Lin8^.Data, Width);
        PutImage(Xstart, Ystart+yt, Lin8^, NormalPut);
      end;
    FreeMem(Lin8, SizeP);
    ShowImage8 := True;
  end;

  procedure ShowPalette16;
  var x : Byte;
  begin
    for x := 0 to 15 do
      begin
        SetFillStyle(SolidFill, x);
        Bar(x*20, 0, (x+1)*20, 20);
      end;
  end;

  procedure ShowPalette256;
  var x, y, c : Byte;
  begin
    c := 0;
    for y := 0 to 15 do
      for x := 0 to 15 do
        begin
          SetFillStyle(SolidFill, c);
          Bar(x*20, y*20, (x+1)*20, (y+1)*20);
          Inc(c);
        end;
  end;

  procedure FadeOut16;
  var i, k : Byte;
  begin
    ReadKey;
    for k := 0 to 63 do
      begin
        for i := 0 to 15 do
          begin
            if Pal16[i].R > 0 then Dec(Pal16[i].R);
            if Pal16[i].G > 0 then Dec(Pal16[i].G);
            if Pal16[i].B > 0 then Dec(Pal16[i].B);
          end;
        SetPalette16;
        Delay(20);
      end;
  end;

  procedure FadeOut256;
  var i, k : Byte;
  begin
    ReadKey;
    for k := 0 to 63 do
      begin
        for i := 0 to 255 do
          begin
            if Pal256[i].R > 0 then Dec(Pal256[i].R);
            if Pal256[i].G > 0 then Dec(Pal256[i].G);
            if Pal256[i].B > 0 then Dec(Pal256[i].B);
          end;
        SetPalette256;
        Delay(20);
      end;
  end;

  function ShowBitMapImage(Name : String; X, Y : Word) : Integer;
  begin
    ShowBitMapImage := BmpUnknownError;
    BitmapName := Name;
    ShowBitMapImage := BmpFileNotFound;
    Xstart := X;
    Ystart := Y;
    if not OpenFile then Exit;
    if not ReadBMPFileHead then Exit;
    case BitCount of
      4 : begin
            ReadPalette16;
            SetPalette16;
            ShowImage4;
          end;
      8 : begin
            ReadPalette256;
            SetPalette256;
            ShowImage8;
          end;
    end;
    if not CloseFile then Exit;
    ShowBitMapImage := BmpOk;
  end;

end.


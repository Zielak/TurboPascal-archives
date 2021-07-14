UNIT PCX;

INTERFACE

  procedure LoadPCX(name:string;stat:boolean);
  procedure SavePCX(name:string);

IMPLEMENTATION

uses
  Crt, Dos;

const

   COMPRESS_NUM = $C0;
   MAX_BLOCK = 4096;

   RED = 0;
   GREEN = 1;
   BLUE = 2;

type
   block_array = array [0..MAX_BLOCK] of byte;
   pal_array = array [0..255, RED..BLUE] of byte;
   line_array = array [0..319] of byte;

   pcx_header = record
        Manufacturer: byte;
        Version: byte;
        Encoding: byte;
        Bits_per_pixel: byte;
        Xmin: integer;
        Ymin: integer;
        Xmax: integer;
        Ymax: integer;
        Hdpi: integer;
        Vdpi: integer;
        ColorMap: array [0..15, RED..BLUE] of byte;
        Reserved: byte;
        Nplanes: byte;
        Bytes_per_line_per_plane: integer;
        PaletteInfo: integer;
        HscreenSize: integer;
        VscreenSize: integer;
        Filler: array [74..127] of byte;
      end;
var
   ImageName: string;
   BlockFile: file;
   BlockData,BlockData_s: block_array;
   Header,header_s: pcx_header;
   Palette256,Palette256_s: pal_array;
   PCXline,PCXline_s: line_array;
   PCXfile_line:array[0..639] of byte;
   Ymax: integer;
   NextByte: integer;
   Index: integer;
   k,Data,bb: byte;
   Reg: Registers;
   Akt:word;
   l_index : word;
   linia:array[0..319] of byte;

procedure EntireVGApalette;
var
   i: integer;
begin
for i := 0 to 255 do
   begin
     Palette256 [i, RED]   := Palette256 [i, RED]   shr 2;
     Palette256 [i, GREEN] := Palette256 [i, GREEN] shr 2;
     Palette256 [i, BLUE]  := Palette256 [i, BLUE]  shr 2;
   end;
   Reg.ah := $10;
   Reg.al := $12;
   Reg.bx := 0;
   Reg.cx := 255;
   Reg.dx := ofs (Palette256);
   Reg.es := seg (Palette256);
   intr ($10, Reg);
end;

procedure ShowMCGA (Y: integer);
var
   MCGAscreen: array [0..64000] of byte absolute $A000:$0000;
begin
  Move (PCXline [0], MCGAScreen [(Y shl 8)+(Y shl 6)], 320);
end;

procedure Read256palette;
var
   i: integer;
   b: byte;

begin
  seek (BlockFile, FileSize (BlockFile) - 769);
  BlockRead (BlockFile, b, 1);
  if b <> 12 then exit;
  BlockRead (BlockFile, Palette256, 3*256);
  seek (BlockFile, 128);
end;

procedure ReadHeader;
begin
  {$I-}
  BlockRead (BlockFile, Header, 128);
  Ymax := 199;
  if Header.Version = 5 then Read256palette;
  Index := 0;
  NextByte := MAX_BLOCK;
end;

procedure ReadByte;
var
   NBR: integer;
begin
if NextByte = MAX_BLOCK then
   begin
   BlockRead (BlockFile, BlockData, MAX_BLOCK, NBR);
   NextByte := 0;
   end;
  data := BlockData [NextByte];
  inc (NextByte);
end;

procedure Read_PCX_Line;
var
   count: integer;
   bytes_per_line: integer;
begin
{$I-}
  while (Index < 320) do
  begin
    ReadByte;
    if (data and $C0) = compress_num then
      begin
        count := data and $3F;
        ReadByte;
        FillChar (PCXline [Index], count, data);
        inc (Index, count);
      end
   else
      begin
      PCXline [Index] := data;
      inc (Index);
      end;
   end;
   Index := 0;
{$I+}
end;

procedure LoadPCX (name: string;stat:boolean);
var
   k, kmax: integer;
begin
{$I-}
  ImageName := name;
  assign (BlockFile, name);
  reset (BlockFile, 1);
  if ioresult<>0 then exit;
  ReadHeader;
  if (Header.Version = 5) and (stat=true) then
    EntireVGAPalette;
  for k :=0 to 199 do
  begin
    Read_PCX_Line;
    ShowMCGA (k);
  end;
  close (BlockFile);
{$I+}
end;

{--------------------------}
procedure ReadData;
begin
  data:=linia[l_index];
  inc(l_index);
end;

procedure Write_PCX_Line(l:byte);
var
   dl,kol1,dl_wyp :byte;
   plik_linia:array[0..639] of byte;
   rozmiar : word;
{$I-}
begin
  rozmiar:=0;
  l_index:=0;
  move(mem[$0A000:l*320],linia,320);
  while L_index<320 do
  begin
    ReadData;
    kol1:=data;
    dl_wyp:=1;
    repeat
      data:=linia[L_index+dl_wyp-1];
      if data=kol1 then inc(dl_wyp);
    until (data<>kol1) or (dl_wyp=63) or (dl_wyp+L_index>318);

    if dl_wyp>1 then begin
      plik_linia[rozmiar]:=(dl_wyp) or $C0;
      inc(rozmiar);
      plik_linia[rozmiar]:=kol1;
      inc(rozmiar);
      inc(L_index,dl_wyp-1);
    end
  else
    begin
      if kol1 and $C0 = $C0 then
      begin
        plik_linia[rozmiar]:=1 or $C0;
        inc(rozmiar);
        plik_linia[rozmiar]:=kol1;
        inc(rozmiar);
      end
    else
      begin
        plik_linia[rozmiar]:=kol1;
        inc(rozmiar);
      end;
    end;
  end;
  BlockWrite(Blockfile,plik_linia,rozmiar);
{$I+}
end;


procedure WriteHeader;
var i:integer;
begin
  header_s.manufacturer:=10;
  header_s.version:=5;
  header_s.encoding:=1;
  header_s.bits_per_pixel:=8;
  header_s.XMin:=0;
  header_s.YMin:=0;
  header_s.XMax:=319;
  header_s.YMax:=199;
  header_s.Hdpi:=320;
  header_s.Vdpi:=200;
  for i:=0 to 15 do begin
    header_s.colormap[i,red]:=0;
    header_s.colormap[i,green]:=0;
    header_s.colormap[i,blue]:=0;
  end;
  header_s.reserved:=0;
  header_s.NPlanes:=1;
  header_s.bytes_per_line_per_plane:=320;
  header_s.paletteinfo:=0;
  header_s.HScreenSize:=0;
  header_s.VScreenSize:=0;
  for i:=74 to 127 do header_s.Filler[i]:=0;
  BlockWrite(BlockFile,header_s,128);
end;

procedure WriteVGAPalette;
var n_k:integer;
    b:byte;
begin
  for n_k:=0 to 255 do begin
    port[$3c7]:=n_k;
    Palette256_s[n_k,Red]:=port[$3c9];
    Palette256_s[n_k,Red]:=Palette256_s[n_k,Red] shl 2;
    Palette256_s[n_k,Green]:=port[$3c9];
    Palette256_s[n_k,Green]:=Palette256_s[n_k,Green] shl 2;
    Palette256_s[n_k,Blue]:=port[$3c9];
    Palette256_s[n_k,Blue]:=Palette256_s[n_k,Blue] shl 2;
  end;
  b:=12;
  BlockWrite(BlockFile,b,1);
  BlockWrite(BlockFile,Palette256_s,256*3);
end;

procedure SavePCX (name: string);
begin
{$I-}
  ImageName := name;
  assign (BlockFile, name);
  rewrite (BlockFile, 1);
  if ioresult<>0 then exit;
  WriteHeader;
  index:=0;
  for k :=0 to 199 do
  begin
    Write_PCX_Line(k);
  end;
  WriteVGAPalette;
  close (BlockFile);
{$I+}
end;

end.
Procedure BMPOpen (ax,ay:word; sciezka:string);
Type
 TNaglowek=
   Record
   bfType :             Word;
   bfSize :             LongInt;
   bfReserved :         LongInt;
   bfOffBits :          LongInt;
   biSize :             LongInt;
   biWidth :            LongInt;
   biHeight :           LongInt;
   biPlanes :           Word;
   biBitCount :         Word;
   biCompression :      LongInt;
   biSizeImage :        LongInt;
   biXPelsPerMeter :    LongInt;
   biYPelsPerMeter :    LongInt;
   biClrUsed :          LongInt;
   biClrImportant :     LongInt;
  End;
Var
   PlikNaglowek: file of Tnaglowek;
   Naglowek:Tnaglowek;
   bitmapa:file of byte;
   z,a:byte;
   b,g,r:byte;
   x,y:integer;
   kolor:byte;
begin
   assign (PlikNaglowek,sciezka);      {skojarzenie z plikiem}
   reset (PlikNaglowek);                     {otwarcie do odczytu}
   read (PlikNaglowek,Naglowek);      {wczytanie nag��wka   }
{-------------------------------------------------------------------}
   assign (bitmapa,sciezka);
   reset (bitmapa);
asm                                  {w��czenie trybu graficznego}
   mov ax,13h
   int 10h
end;
seek(bitmapa, sizeOf(Tnaglowek));                {pomini�cie nag��wka}
for x:=0 to Naglowek.bibitCount-1 do begin       {wczytanie palety kolor�w}
   read (bitmapa,b,g,r,z);                       {wczytanie kolor�w BGR i pomini�cie pustego bajtu(a)}
   port[$3c8]:=x;                                {port $3c8 oczekuje na sk�adowe dla koloru x}
   port[$3c9]:=r div 4;                          {przesy�amy}
   port[$3c9]:=g div 4;                          {te}
   port[$3c9]:=b div 4;                          {sk�adowe}
end;                                             {mamy gotow� palet�}
                                         
for y:=Naglowek.biHeight-1 downto 0 do           {a teraz wczytujemy kolory}
for x:=0 to Naglowek.biWidth-1 do
begin
   read (bitmapa,kolor);
   mem[$A000:y shl 8+ y shl 6 + x+ay shl 8 +ay shl 6+ax]:=kolor;
end;
readln;
asm       {powracamy do normalnego trybu tekstowego}
   mov ah,3h
   int 10h
end;
end;

Begin
  BMPOpen (30,20,'C:\beznazwy.bmp');
readln;
end.
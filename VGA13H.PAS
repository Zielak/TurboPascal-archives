{Aktualizacja z Kwiecien 1999}
{$G+}
Unit VGA13H; { 320 - 200 / 256 Colors }
interface

   Uses Crt,Dos;
   Type WartoscKoloru = Record R,G,B : Byte end;
        PaletaVGA     = Array[0..255] of WartoscKoloru ;
   Const MaxX = 319;
         MaxY = 199;
         TXTMaxX = 79;
         TXTMaxY = 29;
         Proc86  : Boolean = False;
         UstawPaleteSzybko : Boolean = True;
         Scr : Pointer = Ptr(0,0);
   Var Okno          : record x1,y1,x2,y2:integer; end;
       Tlo           : Pointer;
       DrawBase      : Word;
       VSegA         : Word;
   Procedure InicjujVGA;
   {Inicjuje tryb}
   Procedure ZamknijVGA;
   {Zamyka tryb}
   Procedure Czysc(C : byte);
   {czysci ekran}
   Procedure UstawPalete(var Paleta : PaletaVGA; Poczatek,Koniec : Byte);
   {"Reczne" ustawienie palety barw}
   Procedure PobierzPalete(Paleta : PaletaVGA);
   {Paleta barw pobrana zapisana do zmiennej Paleta i pobrana z aktualnego
   ustawienia barw przez komputer}
   Procedure CzytajPalete(var Paleta : PaletaVGA;N:String);
   {Paleta barw pobrana z pliku tekstowego}
   Procedure ZapiszPalete(Paleta:PaletaVGA; Nazwa:String);
   {Paleta barw zapisana do pliku tekstowego}
   Procedure Rotacja(var Pal:PaletaVGA;OdK,DoK:Byte;Kierunek:Boolean);
   {Plynne przechodzenie kolorow z koloru OdK do DoK}
   Procedure Pixel(X,Y: Integer; Kolor: Byte);
   {Rysowanie punktu na ekranie}
   Procedure PixelSpeed(X,Y: Integer; Kolor: Byte);
   {Szybkie rysowanie punktu na ekranie}
   Function RdPixel(X,Y: Integer):Byte;
   {Pobiera color danego punktu na ekranie}
   function RdPixelSpeed(X,Y: Integer):byte;
   {To samo co wczesniej tylko troszke szybciej}
   Procedure KwadratPusty(x1,y1,x2,y2 : Integer; Kolor : Word);
   {Rysowanie obramowan czworoscianu}
   Procedure KwadratPelny(x1,y1,x2,y2 : Integer{; Linia : Byte};color : word);
   {Rysowanie czworoscianu wypelnionego paleta barw}
   Procedure Kolo(X1,Y1,R: Integer; Kolor: Word);
   {Rysowanie kola}
   Procedure Elipsa (X,Y: Integer; A,B: Integer; Kolor: Word);
   {Rysowanie elipsy}
   Procedure PiszTextVGA(X,Y:Integer;TXT:String;Kolor:Word;Poziom:Boolean);
   {Wyswietlenie tekstu wraz z czarnym tlem}
   Procedure VGAText(X,Y: Integer; Kolor: Byte; S: string; Delta: ShortInt);
   {Wyswietlenie tekstu bez tla}
   Procedure AktywneOkno(X1,Y1,X2,Y2: Integer);
   {Ustawienie okna na ktorym wykonywane beda operacje graficzne}
   Procedure Line(X1,Y1,X2,Y2: Integer; Color: Byte);
   {Rysowanie lini ukosnych (niemozna pionowych i poziomych)}
   Procedure LineH(X1,X2,Y: Word; C:byte);
   {Rysowanie lini poziomych}
   Procedure LineV(X,Y1,Y2: Word; C:Byte);
   {Rysowanie lini pionowych}
   Procedure Bar(X1,Y1,X2,Y2: Word; Color: Byte);
   {Rysowanie czworoscianu wypelnionego jednolitym kolorem}
   Procedure Czekaj;
   {Cos jak Delay tylko bardziej plynnie}

implementation

  procedure InicjujVGA;
  var Rejestr: Registers;
  begin
    Rejestr.AX := $0013;  { MOV AX, $0013 }
    Intr($10,Rejestr);    { INT $10       }
  end;

  procedure ZamknijVGA;
  begin
    TextMode(CO80);
  end;

  procedure Czysc (C : byte); Assembler;
  Asm
     Mov   AX, VSegA
     Mov   ES, AX
     Xor   DI, DI
     CLD
     Mov   AL, C
     Mov   AH, AL
     Mov   CX, 32000
     Rep   STOSW
  End;

  procedure UstawPalete(var Paleta : PaletaVGA; Poczatek,Koniec : Byte);
       procedure Vsynch;
       Inline($BA/$3DA/  {        MOV  DX,3DAH }
              $EC/       { LOOP1: IN   AL,DX   }
              $A8/8/     {        TEST AL,8    }
              $75/$FB/   {        JNZ  LOOP1   }
              $EC/       { LOOP2: IN   AL,DX   }
              $A8/8/     {        TEST AL,8    }
              $74/$FB    {        JZ   LOOP2   }
              );
  var R  : Registers;
  begin
   if Proc86 then begin
    R.AX := $1012;
    R.BX := Poczatek;
    R.CX := Succ(Koniec - Poczatek);
    R.ES := Seg(Paleta);
    R.DX := Ofs(Paleta[Poczatek]);
    Intr($10,R);
    Exit;
   end;
  Vsynch;
  Inline($8E/$86/Paleta+2/{ MOV ES,[BP+P+2]   }
         $8A/$86/Poczatek/{ MOV AL,[BP+START] }
         $28/$E4/         { SUB AH,AH         }
         $BA/$3C8/        { MOV DX,3C8H       }
         $EE/             { OUT DX,AL         }
         $89/$C1/         { MOV CX,AX         }
         $01/$C0/         { ADD AX,AX ; START * 2 }
         $01/$C8/         { ADD AX,CX ; START * 3 }
         $03/$86/Paleta/  { ADD AX,[BP+P]     }
         $89/$C6          { MOV SI,AX         }
         );
  Inline($8A/$86/Koniec/  { MOV AL,[BP+STOP]  }
         $28/$E4/         { SUB AH,AH         }
         $40/             { INC AX            }
         $8A/$8E/Poczatek/{ MOV CL,[BP+START] }
         $28/$ED/         { SUB CH,CH         }
         $29/$C8/         { SUB AX,CX         }
         $89/$C1/         { MOV CX,AX         }
         $01/$C9/         { ADD CX,CX ; * 2   }
         $01/$C1/         { ADD CX,AX ; * 3   }
         $FC/             { CLD               }
         $BA/$3C9/        { MOV DX,3C9H       }
         $26/$F3/$6E      { REP OUTSB ES:     }
         );
  end;

  procedure PobierzPalete(Paleta : PaletaVGA);
  var R : Registers;
  begin
   R.AX := $1017;
   R.BX := 0;
   R.CX := 256;
   R.ES := Seg(Paleta);
   R.DX := Ofs(Paleta);
   Intr($10,R);
  end;
  procedure CzytajPalete(var Paleta : PaletaVGA;N:String);
  const Delim      = [#9,' '];
  var   F          : Text;
        Lin,V,Name : String;
        I,J,K,L    : Integer;
        Err        : Boolean;
  begin
   Assign(F,N);
   Reset(F);
   L := 0;
   Err := False;
   while not Eof(F) and not Err and (L < 256) do begin
      Readln(F,Lin);
      while (Length(Lin) > 0) and (Lin[1] in Delim) do Delete(Lin,1,1);
      V := '';
      while (Length(LIN) > 0) and not (Lin[1] in Delim) do begin
       V := V + LIN[1];
       DELETE(LIN,1,1);
      end;
     Val(V,I,J);
     if J <> 0 then Err := True else Paleta[L].R := I shr 2;
     while (Length(Lin) > 0) and (Lin[1] in Delim) do Delete(Lin,1,1);
     V := '';
     while (Length(Lin) > 0) and not (Lin[1] in Delim) do begin
      V := V + Lin[1];
      Delete(Lin,1,1);
     end;
     Val(V,I,J);
     if J <> 0 then Err := True else Paleta[L].G := I shr 2;
     while (Length(Lin) > 0) and (Lin[1] in Delim) do Delete(LIN,1,1);
     V := '';
     while (Length(Lin) > 0) and not (Lin[1] in Delim) do begin
      V := V + Lin[1];
      Delete(Lin,1,1);
     end;
     Val(V,I,J);
     if J <> 0 then Err := True else Paleta[L].B := I shr 2;
     Inc(L);
   end;
   Close(F);
   if not Err and (L = 256) then Name := N;
  end;
  procedure ZapiszPalete(Paleta:PaletaVGA; Nazwa:String);
  var z: Byte;
      f: Text;
      Rs,Gs,Bs: String;
  begin
   if Pos('.',Nazwa) = 0 then Nazwa:=Nazwa+ '.PAL';
   Assign(f,Nazwa);
   Rewrite(f);
   for z:= 0 to 255 do begin
      with Paleta[z] do begin
       R:=R*4;
       G:=G*4;
       B:=B*4;
       Str(R,Rs);
       Str(G,Gs);
       Str(B,Bs);
       If Length(Rs) = 3 then write(f,' ',R);
       If Length(Rs) = 2 then write(f,'  ',R);
       If Length(Rs) = 1 then write(f,'   ',R);
       If Length(Gs) = 3 then write(f,' ',G);
       If Length(Gs) = 2 then write(f,'  ',G);
       If Length(Gs) = 1 then write(f,'   ',G);
       If Length(Bs) = 3 then write(f,' ',B);
       If Length(Bs) = 2 then write(f,'  ',B);
       If Length(Bs) = 1 then write(f,'   ',B);
       writeln(f);
      end;
   end;
   Close(f);
  end;
  procedure Rotacja(var Pal:PaletaVGA;OdK,DoK:Byte;Kierunek:Boolean);
  var Col : WartoscKoloru;
  begin
   if kierunek then begin
      Col := Pal[DoK];
      Move(Pal[OdK],Pal[Succ(OdK)],SizeOf(PaletaVGA) - 3 * (256 - DoK + OdK));
      Pal[OdK] := Col;
   end else begin
      Col := Pal[OdK];
      Move(Pal[Succ(OdK)],Pal[OdK],SizeOf(PaletaVGA) - 3 * (256 - DoK + OdK));
      Pal[DoK] := Col;
   end;
   if UstawPaleteSzybko or ((DoK - OdK) < 128) then begin
      UstawPalete(Pal,OdK,DoK);
   end else begin
     UstawPalete(Pal,OdK,(DoK - OdK) shr 1);
     UstawPalete(Pal,Succ((DoK - OdK) shr 1),DoK);
   end;
  end;

  procedure Pixel(X, Y: Integer; Kolor: Byte); assembler;
  asm
    mov dx, Y
    cmp dx, okno.y1
    jl @exitproc
    cmp dx, okno.y2
    jg @exitproc
    mov di, X
    cmp di, okno.x1
    jl @exitproc
    cmp di, okno.x2
    jg @exitproc

    mov es, DrawBase
    shl dx, 6
    mov al, Kolor
    add di, dx
    shl dx, 2
    add di, dx
    mov es:[di], al
   @exitproc:
  end;

  procedure PixelSpeed(X,Y: Integer; Kolor:Byte);assembler;
  asm
    mov dx, Y
    mov es, DrawBase
    mov di, X
    shl dx, 6
    mov al, Kolor
    add di, dx
    shl dx, 2
    add di, dx
    mov es:[di], al
  end;

  function RdPixel(X,Y: Integer):Byte; assembler;
  asm
   mov dx, Y
   cmp dx, okno.y1
   jl @exitproc
   cmp dx, okno.y2
   jg @exitproc
   mov di, X
   cmp di, okno.x1
   jl @exitproc
   cmp di, okno.x2
   jg @exitproc

   mov es, DrawBase
   shl dx, 6
   add di, dx
   shl dx, 2
   add di, dx
   mov al, es:[di]
  @exitproc:
  end;

  function RdPixelSpeed(X,Y: Integer):byte; assembler;
  asm
    mov dx, Y
    mov es, DrawBase
    mov di, X
    shl dx, 6
    add di, dx
    shl dx, 2
    add di, dx
    mov al, es:[di]
  end;

  procedure KwadratPusty(x1,y1,x2,y2 : Integer; Kolor : Word);
  var i : Integer;
  begin
    for i:=x1 to x2 do Pixel(i,y1,Kolor);
    for i:=y1 to y2 do Pixel(x1,i,Kolor);
    for i:=x1 to x2 do Pixel(i,y2,Kolor);
    for i:=y1 to y2 do Pixel(x2,i,Kolor);
  end;
  {
  procedure KwadratPelny(x1,y1,x2,y2 : Integer; Linia : Byte);
  var i,j : Integer;
  begin
   case Linia of
     1: for i:=x1 to x2 do for j:=y1 to y2 do Pixel(i,j,i);
     2: for i:=x1 to x2 do for j:=y1 to y2 do Pixel(i,j,i+j);
     3: for i:=x1 to x2 do for j:=y1 to y2 do Pixel(i,j,i-j);
     4: for i:=x1 to x2 do for j:=y1 to y2 do Pixel(i,j,i*j);
     5: for i:=x1 to x2 do for j:=y1 to y2 do Pixel(i,j,i*j*i);
     6: for i:=x1 to x2 do for j:=y1 to y2 do Pixel(i,j,i*j*j);
     7: for i:=x1 to x2 do for j:=y1 to y2 do Pixel(i,j,i*j*i*j);
     8: for i:=x1 to x2 do for j:=y1 to y2 do Pixel(i,j,sqr(i)+sqr(j));
     9: for i:=x1 to x2 do for j:=y1 to y2 do Pixel(i,j,sqr(i)+sqr(j)*sqr(i)+sqr(j));
   end;
  end;
  }
  procedure KwadratPelny(x1,y1,x2,y2 : Integer;color : Word);
  var i,j : Integer;
  begin
   for i:=x1 to x2 do
    for j:=y1 to y2 do
     Pixel(i,j,color);
  end;
  procedure Kolo(X1,Y1,R: Integer; Kolor: Word); {x*x + y*y = r*r }
  var x,y,d : Integer;
  begin
   x:=0;
   y:=r;
   d:=3-2*r;
   repeat
     Pixel(x1+x,y1+y,Kolor);
     Pixel(x1+x,y1-y,Kolor);
     Pixel(x1-x,y1+y,Kolor);
     Pixel(x1-x,y1-y,Kolor);
     Pixel(x1+y,y1+x,Kolor);
     Pixel(x1+y,y1-x,Kolor);
     Pixel(x1-y,y1+x,Kolor);
     Pixel(x1-y,y1-x,Kolor);
     Inc(x);
     if d >= 0 then begin
        Dec(y);
        d:=d+2*(2*x - 2*y +1);
     end else
        d:=d+2*(2*x +1);
   until x > y;
  end;
  procedure Elipsa (X,Y: Integer; A,B: Integer; Kolor: Word);
  var StepX,StepY,i : Integer;
      K : Real;
  begin
   K:= B/A;
   for i:=0 to A - (A shr 2) do begin
    StepX:=Round(Sqrt(Sqr(A)-Sqr(i)));
    StepY:=Round(K*i);
    Pixel(X+StepX,Y+StepY,Kolor);
    Pixel(X-StepX,Y+StepY,Kolor);
    Pixel(X+StepX,Y-StepY,Kolor);
    Pixel(X-StepX,Y-StepY,Kolor);
   end;
   for i:=0 to A - (A shr 2) do begin
    StepY:=Round(K*Sqrt(Sqr(A)-Sqr(i)));
    Pixel(X+i,Y+StepY,Kolor);
    Pixel(X-i,Y+StepY,Kolor);
    Pixel(X+i,Y-StepY,Kolor);
    Pixel(X-i,Y-StepY,Kolor);
   end;
  end;
  procedure PiszTextVGA(X,Y:Integer;TXT:String;Kolor:Word;Poziom:Boolean);
  var k: Integer;
     procedure Wyswietl(x,y:Integer;Znak:Char);  {gotoxy}
     var rej,rej1: Registers;
         Litera: Longint;
     begin
      Litera:=Ord(Znak);
      with rej1 do begin
        AH:=$02;
        DH:=Y;
        DL:=X;
        BH:=0;
      end;
      Intr($10,rej1);
      with rej do begin
        AH:=$0A;
        BH:=0;
        CX:=1;
        AL:=Litera;
        BL:=Kolor;
      end;
      Intr($10,rej);
     end;
  begin
   if Poziom then begin
      for k := 1 to Length(TXT) do begin Wyswietl(X,Y,TXT[k]);
       X := X + 1; {mozna zmienic odstep}
       Y := Y;
      end;
   end else begin
      for k := 1 to Length(TXT) do begin
       Wyswietl(X,Y,TXT[k]);
       X := X;
       Y := Y + 1; {mozna zmienic odstep}
      end;
   end;
  end;

  procedure VGAText(x, y: Integer; kolor: Byte; s: string; delta: ShortInt); assembler;
  const
    segfont=$F000;
    ofsfont=$FA6E;
  var
    scrs, strs, stro: Word;
    posx, posy:       Integer;
  asm
  {SMALL CLIP}
   mov ax, y
   cmp ax, okno.y2
   jg @ExitProc
   add ax, 7
   cmp ax, okno.y1
   jl @ExitProc
   mov cx, x
   cmp cx, okno.x2
   jg @ExitProc
   les si, s
   xor ah, ah
   mov strs, es
   mov stro, si
   mov al, es:[si]
   or al, al
   je @ExitProc
   dec cx
   shl ax, 3
   add cx, ax {cx=x+length(s)*8-1}
   cmp cx, okno.x1
   jl @ExitProc
 {PRINT}
   mov es, drawbase
   xor di, di
   mov scrs, es

   mov bx, 320
   mov ax, y
   shl ax, 6
   add di, ax
   shl ax, 2
   add di, ax
   add di, x

   mov dx, bx
   sub dx, 8

   mov es, strs
   mov si, stro
   xor ch, ch
   mov cl, es:[si]
   inc stro

   mov ax, x
   mov posx, ax

  @nextchar:
   push cx

   mov es, strs
   mov si, stro
   xor ah, ah
   mov al, es:[si]
   inc si
   mov stro, si

   shl ax, 3
   mov si, ofsfont
   add si, ax
   mov bh, kolor

   mov ax, y
   mov posy, ax

   mov cx, 8
  @nextline:
   push cx
   push dx
   mov dx, posy
   cmp dx, okno.y1
   jl @noline
   cmp dx, okno.y2
   jg @noline

   mov cx, segfont
   mov es, cx
   mov al, es:[si]
   inc si
   mov es, scrs

   mov dx, posx
   mov bl, $80
  @nextpix:
   cmp dx, okno.x1
   jl @spoko
   cmp dx, okno.x2
   jg @spoko

   mov cl, al
   and cl, bl
   jz @spoko
   mov es:[di], bh
  @spoko:
   inc di

   inc dx
   shr bl, 1
   jnz @nextpix

   jmp @was_line
  @noline:
   inc si
   add di, 8
  @was_line:
   pop dx
   add di, dx

   inc posy
   pop cx
   add bh, delta
   dec cx
   jnz @nextline

   add posx, 8

   mov ax, 320*8
   sub di, ax

   add di, 8

   pop cx
   dec cx
   jnz @nextchar
  @ExitProc:
  end;

  Procedure AktywneOkno(X1,Y1,X2,Y2: Integer);
  begin
   okno.x1:=x1;
   okno.x2:=x2;
   okno.y1:=y1;
   okno.y2:=y2;
  end;

  Procedure Line(x1, y1, x2, y2:integer;color:byte); assembler;
  var wsk1, wsk2, podpr:word;
      pos:integer;
  asm
   mov ax, x1
   mov bx, x2
   cmp ax, bx
   jng @zmienx
   xchg ax, bx
 @zmienx:
   cmp bx, okno.x1
   jl @exitproc
   cmp ax, okno.x2
   jg @exitproc
   mov ax, y1
   mov bx, y2
   cmp ax, bx
   jng @zmieny
   xchg ax, bx
 @zmieny:
   cmp bx, okno.y1
   jl @exitproc
   cmp ax, okno.y2
   jg @exitproc

   mov es, drawbase
   xor di, di
   mov si, 320
   mov cx, x2
   sub cx, x1
   jz  @LiniaPionowa
   jns @nochangex
   neg cx
   mov bx, x2
   xchg bx, x1
   mov x2, bx
   mov bx, y2
   xchg bx, y1
   mov y2, bx
 @nochangex:

   mov bx, y2
   sub bx, y1
   jz @LiniaPozioma
   jns @nochangey
   neg bx
   neg si
 @nochangey:

   push si
   mov podpr, offset @RysujPozioma
   cmp bx, cx
   jle @nohorizonal
   mov podpr, offset @RysujPionowa
   xchg bx, cx
 @nohorizonal:

   shl bx, 1
   mov wsk1, bx
   sub bx, cx
   mov si, bx
   sub bx, cx
   mov wsk2, bx
   push cx
   mov ax, y1
   mov bx, x1

   mov dx, 320
   mul dx
   add ax, bx

   mov di, ax
   pop cx
   inc cx
   pop bx
   jmp podpr

 @LiniaPionowa:
   mov ax, y1
   mov bx, y2
   cmp ax, bx
   jng @nochgy
   xchg ax, bx
 @nochgy:
   cmp ax, okno.y2
   jg @exitproc
   cmp bx, okno.y1
   jl @exitproc
   mov dx, x1
   cmp dx, okno.x1
   jl @exitproc
   cmp dx, okno.x2
   jg @exitproc
   cmp ax, okno.y1
   jnl @powy1
   mov ax, okno.y1
 @powy1:
   cmp bx, okno.y2
   jng @pomy2
   mov bx, okno.y2
 @pomy2:
   mov cx, bx
   sub cx, ax
   inc cx

   shl ax, 6
   add di, ax
   shl ax, 2
   add di, ax
   add di, x1
   mov al, color
 @loopy:
   mov es:[di], al
   add di, si
   loop @loopy
   jmp @exitproc

 @LiniaPozioma:
   mov ax, y1
   cmp ax, okno.y1
   jl @exitproc
   cmp ax, okno.y2
   jg @exitproc
   mov bx, x1
   mov dx, x2
   cmp bx, okno.x2
   jg @exitproc
   cmp dx, okno.x1
   jl @exitproc

   cmp bx, okno.x1
   jnl @powx1
   mov bx, okno.x1
 @powx1:
   cmp dx, okno.x2
   jng @pomx2
   mov dx, okno.x2
 @pomx2:

   mov cx, dx
   sub cx, bx
   inc cx

   shl ax, 6
   add di, ax
   shl ax, 2
   add di, ax
   add di, bx

   mov al, color
   rep stosb
   jmp @exitproc


 @RysujPozioma:

   mov dx, x2
   sub dx, okno.x2
   jng @clip_pion_x2
   sub cx, dx
 @clip_pion_x2:
{}
   mov dx, y1
   mov pos, dx

   cmp bx, 0
   jg @yplus

   mov dx, okno.x1
   sub dx, x1
   jng @clip_pion_x1

      add di, dx
      sub cx, dx
    @tlY:
      or si, si
      jns @tpY
      add si, wsk1
      dec dx
      jnz @tlY
      jmp @clip_pion_x1

    @tpY:
      add si, wsk2
      add di, bx
      dec pos
      dec dx
      jnz @tlY

 @clip_pion_x1:
 {}
   mov dx, okno.y2
   cmp pos, dx
   jng @skipY1
 @lY:
   inc di
   or si, si
   jns @pY
   add si, wsk1
   loop @lY
   jmp @exitproc

 @pY:
   add si, wsk2
   add di, bx
   dec pos
   cmp pos, dx
   jz @tskipY
   loop @lY
   jmp @exitproc
   {}
 @tskipY:
   dec cx
   jng @exitproc
 @skipY1:
   mov dx, okno.y1
   cmp dx, pos
   jg @exitproc
   dec dx
   mov al, color
 @lYb:
   stosb
   or si, si
   jns @pYb
   add si, wsk1
   loop @lYb
   jmp @exitproc

 @pYb:
   add si, wsk2
   add di, bx
   dec pos
   cmp pos, dx
   jz @exitproc
   loop @lYb
   jmp @exitproc

 @yplus:
   mov dx, okno.x1
   sub dx, x1
   jng @clip_pion_x1T

      add di, dx
      sub cx, dx
    @tlYT:
      or si, si
      jns @tpYT
      add si, wsk1
      dec dx
      jnz @tlYT
      jmp @clip_pion_x1T

    @tpYT:
      add si, wsk2
      add di, bx
      inc pos
      dec dx
      jnz @tlYT

 @clip_pion_x1T:
 {}
   mov dx, okno.y1
   cmp pos, dx
   jnl @skipY1T
 @lYT:
   inc di
   or si, si
   jns @pYT
   add si, wsk1
   loop @lYT
   jmp @exitproc

 @pYT:
   add si, wsk2
   add di, bx
   inc pos
   cmp pos, dx
   jz @tskipYT
   loop @lYT
   jmp @exitproc
   {}
 @tskipYT:
   dec cx
   jng @exitproc
 @skipY1T:
   mov dx, okno.y2
   cmp dx, pos
   jl @exitproc
   inc dx
   mov al, color
 @lYbT:
   stosb
   or si, si
   jns @pYbT
   add si, wsk1
   loop @lYbT
   jmp @exitproc

 @pYbT:
   add si, wsk2
   add di, bx
   inc pos
   cmp pos, dx
   jz @exitproc
   loop @lYbT
   jmp @exitproc

 @RysujPionowa:
   mov dx, x1
   mov pos, dx

   cmp bx, 0
   jg @yplus2

   mov dx, y2
   sub dx, okno.y1
   jnl @clip_pion_y1
   add cx, dx
 @clip_pion_y1:

   mov dx, y1
   sub dx, okno.y2
   jng @clip_y1

      sub cx, dx
    @tlX:
      inc di
      inc pos
      add di, bx
      or si, si
      jns @tpX
      add si, wsk1
      dec di
      dec pos
      dec dx
      jnz @tlX
      jmp @clip_y1

    @tpX:
      add si, wsk2
      dec dx
      jnz @tlX

 @clip_y1:

   mov dx, okno.x1
   cmp pos, dx
   jnl @skipX1

 @lX:
   inc di
   inc pos
   add di, bx
   or si, si
   jns @pX
   add si, wsk1
   dec di
   dec pos
   loop @lX
   jmp @exitproc
 @pX:
   add si, wsk2
   cmp pos, dx
   jz @tskipX
   loop @lX

 @tskipX:
   dec cx
   jng @exitproc
 @skipX1:
   mov dx, okno.x2
   cmp dx, pos
   jl @exitproc
   inc dx
   mov al, color

 @lXb:
   stosb
   inc pos
   add di, bx
   or si, si
   jns @pXb
   add si, wsk1
   dec di
   dec pos
   loop @lXb
   jmp @exitproc
 @pXb:
   add si, wsk2
   cmp pos, dx
    jz @exitproc
   loop @lXb
   jmp @exitproc

 @yplus2:
   mov dx, y2
   sub dx, okno.y2
   jng @clip_pion_y2
   sub cx, dx
 @clip_pion_y2:

   mov dx, okno.y1
   sub dx, y1
   jng @clip_y2

      sub cx, dx
    @tlXT:
      inc di
      inc pos
      add di, bx
      or si, si
      jns @tpXT
      add si, wsk1
      dec di
      dec pos
      dec dx
      jnz @tlXT
      jmp @clip_y2

    @tpXT:
      add si, wsk2
      dec dx
      jnz @tlXT

 @clip_y2:

   mov dx, okno.x1
   cmp pos, dx
   jnl @skipX2

 @tlX2:
   inc di
   inc pos
   add di, bx
   or si, si
   jns @tpX2
   add si, wsk1
   dec di
   dec pos
   loop @tlX2
   jmp @exitproc
 @tpX2:
   add si, wsk2
   cmp pos, dx
   jz @tskipXT
   loop @tlX2

 @tskipXT:
   dec cx
   jng @exitproc
 @skipX2:
   mov dx, okno.x2
   cmp dx, pos
   jl @exitproc
   inc dx
   mov al, color

 @lXbT:
   stosb
   inc pos
   add di, bx
   or si, si
   jns @pXbT
   add si, wsk1
   dec di
   dec pos
   loop @lXbT
   jmp @exitproc
 @pXbT:
   add si, wsk2
   cmp pos, dx
   jz @exitproc
   loop @lXbT
 @exitproc:
  end;

  procedure LineH(x1, x2, y:word;c:byte);assembler;
  asm
  mov ax, y
  cmp ax, okno.y1
  jl @exitproc
  cmp ax, okno.y2
  jg @exitproc

  mov es,DrawBase

  mov ax, x1
  mov bx, x2
  cmp bx, ax
  jns @d
  xchg ax, bx
 @d:

  cmp ax, okno.x2
  jg @exitproc
  cmp bx, okno.x1
  jl @exitproc

  cmp ax, okno.x1
  jnl @xx
  mov ax, okno.x1
 @xx:
  cmp bx, okno.x2
  jng @xx2
  mov bx, okno.x2
 @xx2:

  sub bx, ax
  inc bx

  mov dx, y
  mov di, ax
  shl dx, 6
  add di,dx
  shl dx, 2
  add di,dx

  mov al, c
  mov ah, al
  mov dx, ax
  db 66h; shl ax, 16
  mov ax, dx

  mov cx, bx
  shr cx, 2
  db 66h; rep stosw

  mov cx, bx
  and cx, 3
  rep Stosb
 @exitproc:
  end;

  procedure LineV(x,y1,y2:word;c:byte);assembler;
  asm
  mov ax, x
  cmp ax, okno.x1
  jl @exitproc
  cmp ax, okno.x2
  jg @exitproc

  mov ax,DrawBase
  mov es,ax

  mov ax, y1
  mov cx, y2
  cmp cx, ax
  jns @d
  xchg ax, cx
 @d:
  cmp ax, okno.y2
  jg @exitproc
  cmp cx, okno.y1
  jl @exitproc
  cmp ax, okno.y1
  jnl @yy
  mov ax, okno.y1
 @yy:
  cmp cx, okno.y2
  jng @yy2
  mov cx, okno.y2
 @yy2:

  sub cx, ax
  inc cx

  mov di, x
  shl ax, 6
  add di, ax
  shl ax, 2
  add di, ax
  mov al, c
 @p:
  mov es:[di], al
  add di, 320
  dec cl
  jnz @p
 @exitproc:
  end;

  procedure Bar(x1, y1, x2, y2:word;color:byte);assembler;
  var counter:byte;
  asm
  mov ax, DrawBase
  mov es, ax

  mov dx, y1
  mov ax, y2
  cmp ax, dx
  jns @d
  xchg dx, ax
 @d:
  cmp ax, okno.y1
  jl @exitproc
  cmp dx, okno.y2
  jg @exitproc

  cmp dx, okno.y1
  jnl @y1
  mov dx, okno.y1
 @y1:
  cmp ax, okno.y2
  jng @y2
  mov ax, okno.y2
 @y2:

  sub ax, dx
  inc al
  mov counter, al

  shl dx, 6
  mov di, dx
  shl dx, 2
  add di, dx

  mov bx, x1
  mov cx, x2
  cmp cx, bx
  jns @d2
  xchg bx, cx
 @d2:
  cmp cx, okno.x1
  jl @exitproc
  cmp bx, okno.x2
  jg @exitproc

  cmp bx, okno.x1
  jnl @x1
  mov bx, okno.x1
 @x1:
  cmp cx, okno.x2
  jng @x2
  mov cx, okno.x2
 @x2:

  sub cx, bx
  inc cx

  mov dx, 320
  add di, bx
  sub dx, cx
  mov bx, cx

  mov al, color
  mov ah, al
  mov cx, ax
  db 66h; shl ax, 16
  mov ax, cx

 @Y:
  mov cx, bx
  shr cx, 2
  jz @pomin1
  db 66h; rep stosW
 @pomin1:
  mov cx, bx
  and cx, 3
  rep stosb
  add di, dx
  dec counter
  jnz @Y
 @exitproc:
  end;
  {
  procedure Czekaj;
  begin
    repeat
    until (port[$3DA] and 8)=8;
    repeat
    until (port[$3DA] and 8)=0;
  end;
  }
  Procedure Czekaj; Assembler;
  { This waits until you are in a Verticle Retrace ... this means that all
    screen manipulation you do only appears on screen in the next verticle
    retrace ... this removes most of the "fuzz" that you see on the screen
    when changing the pallette. It unfortunately slows down your program
    by "synching" your program with your monitor card ... it does mean
    that the program will run at almost the same speed on different
    speeds of computers which have similar monitors. In our SilkyDemo,
    we used a WaitRetrace, and it therefore runs at the same (fairly
    fast) speed when Turbo is on or off. }

    Label
    L1, L2;
    Asm
       Mov DX, 3DAH
    L1:
       In AL,DX
       And AL,08H
       JNZ L1
    L2:
       In AL,DX
       And AL,08H
       JZ  L2
    End;

begin
     Tlo:=nil;
     Scr:=Ptr(sega000,0);
     DrawBase:=sega000;
     AktywneOkno(0,0,MaxX,MaxY);
end.

{******************************************
  Modul do myszki       : 28.11.2004                    
  Ostatnia aktualizacja : 28.11.2004                    
******************************************}

UNIT MouseX;

INTERFACE

CONST M_ZADEN    =$00;
     M_LEWY     =$01;
     M_PRAWY    =$02;
     M_SRODKOWY =$04;

{******************************************}

FUNCTION  MouseInstalled:Boolean;
FUNCTION  MouseButtons:Byte;
PROCEDURE MouseXY(X, Y:Integer);
PROCEDURE MouseWhereXY(VAR X, Y:Integer);
PROCEDURE MouseButtonsXY(VAR X, Y:Integer;VAR B:Byte);
PROCEDURE MouseSetMax(X, Y:Word);
PROCEDURE MouseSetRatio(X, Y:Word);
PROCEDURE MouseRestore;
PROCEDURE MouseGet;

{******************************************}

{PAMIETA POPRZEDNIE USTAWIENIA MYSZKI}
VAR OldMaxX, OldMaxY,
   OldMinX, OldMinY  :Word;


IMPLEMENTATION


{******************************************}
{Sprawdza czy sterownik myszy jest zainstalowany}
FUNCTION MouseInstalled:Boolean;
BEGIN
 ASM
   Mov  Ax, 00h
   Int  33h
   Mov  @Result, al
 END;
END;

{******************************************}
{Ustawia polozenie myszy w X, Y}
PROCEDURE MouseXY(X, Y:Integer);ASSEMBLER;
ASM
 Mov  Ax, 04h
 Mov  Cx, X
 Mov  Dx, Y
 Int  33h
END;

{******************************************}
{Pyta o polozenie myszy, zwraca wartosci w X, Y}
PROCEDURE MouseWhereXY(VAR X, Y:Integer);
VAR X1, Y1:Integer;
BEGIN
ASM
 Mov  Ax, 03h
 Int  33h
 Mov  X1, Cx
 Mov  Y1, Dx
END;
 X:=X1;
 Y:=Y1;
END;

{******************************************}
{Pyta o wcisniete przyciski myszy}
FUNCTION MouseButtons:Byte;
BEGIN
ASM
 Mov  Ax, 03h
 Int  33h
 Mov  @Result, Bl
END;
END;

{******************************************}
{Pyta o polozenie myszy i stan przyciskow}
PROCEDURE MouseButtonsXY(VAR X, Y:Integer;VAR B:Byte);
VAR X1, Y1:Integer;
   B1:Byte;

BEGIN
ASM
 Mov  Ax, 03h
 Int  33h
 Mov  Word Ptr X1, Cx
 Mov  Word Ptr Y1, Dx
 Mov  Byte Ptr B1, Bl
END;
 X:=X1;
 Y:=Y1;
 B:=B1;
END;
{******************************************}
{Ustala maksymalny i minimalny zakres myszki}
PROCEDURE MouseSetMax(X, Y:Word);
BEGIN
 ASM
   Mov  Ax, 10h
   Mov  Cx, 0
   Mov  Dx, 0
   Mov  Si, X
   Mov  Di, Y
   Int  33h
 END;
END;
{******************************************}
PROCEDURE MouseGet;
BEGIN
 ASM
   Mov  Ax, 31h
   Int  33h
   Mov  OldMinX, Ax
   Mov  OldMaxX, Cx
   Mov  OldMinY, Bx
   Mov  OldMaxY, Dx
 END;
END;
{******************************************}
PROCEDURE MouseRestore;
BEGIN
 ASM
   Mov  Ax, 10h
   Mov  Cx, OldMinX
   Mov  Dx, OldMinY
   Mov  Si, OldMaxX
   Mov  Di, OldMaxY
   Int  33h
 END;
END;
{******************************************}
PROCEDURE MouseSetRatio(X, Y:Word);
BEGIN
 ASM
   Mov  Ax, 000Fh
   Mov  Cx, X
   Mov  Dx, Y
   Int  33h
 END;
END;
{******************************************}
END.
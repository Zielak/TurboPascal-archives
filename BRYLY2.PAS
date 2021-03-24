PROGRAM  BRYLY;
USES CRT;
VAR A,H:WORD;
    U:BYTE;
    Z:STRING[2];
     PROCEDURE SZLACZEK(Z:STRING);
     VAR I:BYTE;
          BEGIN
          FOR I:=1 TO 30 DO
          WRITE(Z);
          END;

     FUNCTION Pp(A:WORD):WORD;
              BEGIN
              Pp:=A*A;
              END;

     PROCEDURE PG(H,A:WORD);
               VAR Pg:WORD;
               BEGIN
               Pg:=2*Pp(A)+(4*H*A);
               WRITELN('POLE BRYLY WONOSI ',Pg);
               END;
     PROCEDURE VGG(H:WORD);
               VAR Vg:WORD;
               BEGIN
               Vg:=Pp(A)*H;
               WRITELN('OBJETOSC GRANIASTOSLUPA WYNOSI ',Vg);
               END;
     PROCEDURE PO(A,H:WORD);
               VAR m,j,Po:REAL;

               BEGIN
               m:=H*H+(A/2)*(A/2);
               j:=SQR(m);
               Po:=Pp(A)+(4*j*A);
               WRITELN('POLE OSTROSLUPA WYNOSI ',Po:3:2);
               END;
     PROCEDURE VO(H:WORD);
               VAR Vo:REAL;
               BEGIN
               Vo:=Pp(A)/3*H;
               WRITELN('OBJETOSC OSTROSLUPA WYNOSI ',Vo:3:2);
               END;

BEGIN
CLRSCR;
WRITELN('PODAJ ZNAK NA SZLACZEK');
READLN(Z);
CLRSCR;
GOTOXY(2,1);
SZLACZEK(Z);
GOTOXY(1,3);
WRITELN('PROGRAM LICZACY POLA I OBJETOSCI GRANIASTOSLUPOW I OSTROSLUPOW');
WRITELN('PODAJ DLUGOSC PODSTAWY');
READLN(A);
WRITELN('PODAJ WYSOKOSC BRYLY');
READLN(H);
WRITELN('1: GRANIASTOLUP');
WRITELN('2: OSTROSLUP');
WRITELN('PODAJ NUMER OPCJI');
SZLACZEK(Z);
GOTOXY(1,12);
READLN(U);
CASE U OF
1: BEGIN
   Pp(A);
   PG(H,A);
   VGG(H);
   READLN;
   END;
2: BEGIN
   Pp(A);
   PO(H,A);
   VO(H);
   READLN;
   END;


END;

END.

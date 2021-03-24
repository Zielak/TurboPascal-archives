PROGRAM lala;
USES crt;
var
   i,s,lk,li,ld,n : word;
   sr : real;

Begin
     ClrScr;
     Writeln('wprowadz ilosc dni');
     Read(n);
     s:=0;

     For i:=1 to n Do
     Begin
          Writeln('--------------------[DZIEã ',i,']-------------------------');
          Writeln('wprowadz liczbe indyk¢w');
          Read(li);
          Writeln('wprowadz liczbe kurczak¢w');
          Read(lk);
          ld:=lk+li;
          s:=s+ld;
          Writeln('dzien ',i,' liczba drobiu= ',ld,' sztuk');
     End;

     sr:=s/n;
     Writeln('');
     Writeln('srednia liczby drobiu=',sr,' sztuk');
     Writeln('koniec programu, wprowad« cokolwiek by zakoäczy†');
     Read(n);
En
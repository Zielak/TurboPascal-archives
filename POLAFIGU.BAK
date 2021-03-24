PROGRAM pola_Figur;
USES crt;
var
   menu:integer;
   naglowek:string;
   a,b, wynik :real;

begin
     clrscr;
     writeln('ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ[ POLA ]ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼');
     writeln('');
     writeln('Program oblicza pole wybranej prostej figury');
     writeln('Wybierz figure z poni¾szych');
     writeln('');
     writeln('ÚÄÄÄÄ[ Wybierz figure ]ÄÄÄÄÄ¿');
     writeln('³                           ³');
     writeln('ÃÄ[1] Kwadrat               ³');
     writeln('ÃÄ[2] Tr¢jk¥t r¢wnoboczny   ³');
     writeln('ÃÄ[3] R¢wnolegˆobok         ³');
     writeln('ÃÄ[4] Okr¥g                 ³');
     writeln('ÃÄ[5] Prostok¥t             ³');
     writeln('³                           ³');
     writeln('ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ');
     writeln('  wybierz jakikolwiek inny znak aby zakoäczy† program...');
     writeln('');
     read(menu);

     { wy˜wietlanie nagˆ¢wka }
     CASE menu OF
          1:naglowek:='Kwadrat';
          2:naglowek:='Tw¢jk¥t r¢wnoboczny';
          3:naglowek:='R¢wnolegˆobok';
          4:naglowek:='Okr¥g';
          5:naglowek:='Prostok¥t';
     END;
     IF (menu<=5) AND (menu>=1) THEN Begin
     writeln('ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');
     writeln('Û ',naglowek);
     writeln('ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');
     writeln('');
     CASE menu OF
          1:Begin
                 writeln('Wprowad« bok a');
                 read(a);
                 wynik:=a*2;
                 Writeln('Pole kwadratu = ',wynik:2:2);
          End;
          2:Begin
                 writeln('Wprowad« bok a');
                 read(a);
                 writeln('Wprowad« bok h');
                 read(b);
                 wynik:=a*b/2;
                 Writeln('Pole tr¢jk¥ta r¢wnobocznego = ',wynik:2:2);
          End;
          3:Begin
                 writeln('Wprowad« bok a');
                 read(a);
                 writeln('Wprowad« bok h');
                 read(b);
                 wynik:=a*b;
                 Writeln('Pole r¢wnolegˆoboku = ',wynik:2:2);
          End;
          4:Begin
                 writeln('Wprowad« r');
                 read(a);
                 wynik:=3.14*(a*a);
                 Writeln('Pole koˆa = ',wynik:2:2);
          End;
          5:Begin
                 writeln('Wprowad« bok a');
                 read(a);
                 writeln('Wprowad« bok b');
                 read(b);
                 wynik:=a*b;
                 Writeln('Pole prostok¥ta = ',wynik:2:2);
          End;
     End;
     End; { zakoäczenie gˆ¢wnego IF-a }
     writeln('');
     writeln('');
     writeln('Koniec programu');
     read(menu);
End.

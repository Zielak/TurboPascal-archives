program pola_Figur;

uses crt;

var
   menu,i,j           :integer;
   petla              :Char;
   a,b,c,wynik        :real;
   naglowek           :string;
   symbol             :string;


begin
     { STARTUP FUNCTIONS }
     repeat
     clrscr;
     HighVideo;





          { GRAPHIC HEAD }
          textcolor(lightred);textbackground(yellow);
          writeln('º                                                                   º');
          write('º       ');textcolor(lightgreen);write('      ÛÛÛ      ÛÛ     Û       ÛÛÛ        Û  Û       ');
          textcolor(lightred);writeln('        º');
          write('º       ');textcolor(lightgreen);write('      Û  Û    Û  Û    Û      Û   Û    Û        Û    ');
          textcolor(lightred);writeln('        º');
          write('º       ');textcolor(lightgreen);write('      ÛÛÛ     Û  Û    Û      ÛÛÛÛÛ     ÛÛ    ÛÛ     ');
          textcolor(lightred);writeln('        º');
          write('º       ');textcolor(lightgreen);write('      Û        ÛÛ     ÛÛÛÛ   Û   Û       ÛÛÛÛ       ');
          textcolor(lightred);writeln('        º');
          writeln('º                                                                   º');
          write('ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ[');textcolor(yellow);write(' POLA ');textcolor(lightred);
          write(']ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼');


          textbackground(black);
          writeln('');
          writeln('');
          writeln('');
          textcolor(white);
          writeln('Program oblicza pole wybranej prostej figury');
          writeln('oraz ryzuje ja na ekranie za pomoca wybranego symbolu.');
          writeln('');

          { WPROWADZ SYMBOL }
          writeln('Najpierw wprowadx symbol ktorym beda rysowane figury');
          writeln('');
          readln(symbol);

          { GRAFICZNE MENU }
          writeln('Wybierz figure z ponizszych');
          writeln('');
          textcolor(yellow);
          writeln('        ÚÄÄÄÄÄÄ[ Wybierz figur© ]ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿');
          writeln('        ³                                        ³');
          textcolor(yellow);write('        ÃÄ[1] ');textcolor(white);write('Kwadrat                           ');
          textcolor(yellow);
          writeln(' ³');
          textcolor(yellow);write('        ÃÄ[2] ');textcolor(white);write('Tr¢jkat r¢wnoboczny               ');
          textcolor(yellow);
          writeln(' ³');
          textcolor(yellow);write('        ÃÄ[3] ');textcolor(white);write('R¢wnoleglobok                     ');
          textcolor(yellow);
          writeln(' ³');
          textcolor(yellow);write('        ÃÄ[4] ');textcolor(white);write('Okrag                             ');
          textcolor(yellow);
          writeln(' ³');
          textcolor(yellow);write('        ÃÄ[5] ');textcolor(white);write('Prostokat                         ');
          textcolor(yellow);
          writeln(' ³');
          writeln('        ³                                        ³');
          writeln('        ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´');
          write('        ÃÄÄÄ ');textcolor(white);write('wybierz jakikolwiek inny znak      ');textcolor(yellow);writeln(' ³');
          write('        ³    ');textcolor(white);write('  aby zakonczyc program...         ');textcolor(yellow);writeln(' ³');
          writeln('        ³                                        ');
          write('        ³  ');textcolor(white);readln(menu);
          textcolor(yellow);


          { GLOWNY IFFIFIFI }

          IF (menu<=5) AND (menu>=1) THEN Begin


             { HEADER }
             CASE menu OF
                  1:naglowek:='Kwadrat';
                  2:naglowek:='Tw¢jkat r¢wnoboczny';
                  3:naglowek:='R¢wnoleglobok';
                  4:naglowek:='Okrag';
                  5:naglowek:='Prostokat';
             END;


             writeln('');
             writeln('        ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');
             write('        Û ');textcolor(lightgreen);writeln(naglowek);
             writeln('        ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ');
             writeln('');




             { OBLICZENIA }
             CASE menu OF
                  1:Begin
                         writeln('Wprowadz bok a');
                         readln(a);
                         wynik:=a*2;
                         Writeln('Pole kwadratu = ',wynik:2:2);
                  End;
                  2:Begin
                         writeln('Wprowada bok a');
                         readln(a);
                         writeln('Wprowada bok h');
                         readln(b);
                         wynik:=a*b/2;
                         Writeln('Pole tr¢jkata r¢wnobocznego = ',wynik:2:2);
                  End;
                  3:Begin
                         writeln('Wprowad« bok a');
                         readln(a);
                         writeln('Wprowad« bok h');
                         readln(b);
                         wynik:=a*b;
                         Writeln('Pole r¢wnolegloboku = ',wynik:2:2);
                  End;
                  4:Begin
                         writeln('Wprowadz r');
                         readln(a);
                         wynik:=3.14*(a*a);
                         Writeln('Pole kola = ',wynik:2:2);
                  End;
                  5:Begin
                         writeln('Wprowadz bok a');
                         readln(a);
                         writeln('Wprowadz bok b');
                         readln(b);
                         wynik:=a*b;
                         Writeln('Pole prostokata = ',wynik:2:2);
                  End;
             End;





             { RYSOWANIE }
             writeln('');
             writeln('');
             CASE menu of
                  1:Begin
                         while not i = a do Begin
                         i:=i+1;
                                while not j = a do Begin
                                j:=j+1;
                                write(symbol);
                         End;
                         writeln('');
                  End;
             End;



          End; { zakoäczenie gˆ¢wnego IF-a }
          writeln('');
          writeln('');
          writeln('Koniec programu');
          writeln('');
          writeln('Wcisnij spacje aby zakonczyc lub jakikolwiek inny znak by powtorzyc program');
          petla := Readkey;
          End;

     until (Ord(petla) = 32);

End.

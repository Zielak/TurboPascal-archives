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
          writeln('�                                                                   �');
          write('�       ');textcolor(lightgreen);write('      ���      ��     �       ���        �  �       ');
          textcolor(lightred);writeln('        �');
          write('�       ');textcolor(lightgreen);write('      �  �    �  �    �      �   �    �        �    ');
          textcolor(lightred);writeln('        �');
          write('�       ');textcolor(lightgreen);write('      ���     �  �    �      �����     ��    ��     ');
          textcolor(lightred);writeln('        �');
          write('�       ');textcolor(lightgreen);write('      �        ��     ����   �   �       ����       ');
          textcolor(lightred);writeln('        �');
          writeln('�                                                                   �');
          write('������������������������������[');textcolor(yellow);write(' POLA ');textcolor(lightred);
          write(']�����������������������������ͼ');


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
          writeln('        �������[ Wybierz figur� ]���������������Ŀ');
          writeln('        �                                        �');
          textcolor(yellow);write('        ��[1] ');textcolor(white);write('Kwadrat                           ');
          textcolor(yellow);
          writeln(' �');
          textcolor(yellow);write('        ��[2] ');textcolor(white);write('Tr�jkat r�wnoboczny               ');
          textcolor(yellow);
          writeln(' �');
          textcolor(yellow);write('        ��[3] ');textcolor(white);write('R�wnoleglobok                     ');
          textcolor(yellow);
          writeln(' �');
          textcolor(yellow);write('        ��[4] ');textcolor(white);write('Okrag                             ');
          textcolor(yellow);
          writeln(' �');
          textcolor(yellow);write('        ��[5] ');textcolor(white);write('Prostokat                         ');
          textcolor(yellow);
          writeln(' �');
          writeln('        �                                        �');
          writeln('        ����������������������������������������Ĵ');
          write('        ���� ');textcolor(white);write('wybierz jakikolwiek inny znak      ');textcolor(yellow);writeln(' �');
          write('        �    ');textcolor(white);write('  aby zakonczyc program...         ');textcolor(yellow);writeln(' �');
          writeln('        �                                        ');
          write('        �  ');textcolor(white);readln(menu);
          textcolor(yellow);


          { GLOWNY IFFIFIFI }

          IF (menu<=5) AND (menu>=1) THEN Begin


             { HEADER }
             CASE menu OF
                  1:naglowek:='Kwadrat';
                  2:naglowek:='Tw�jkat r�wnoboczny';
                  3:naglowek:='R�wnoleglobok';
                  4:naglowek:='Okrag';
                  5:naglowek:='Prostokat';
             END;


             writeln('');
             writeln('        ���������������������������');
             write('        � ');textcolor(lightgreen);writeln(naglowek);
             writeln('        ���������������������������');
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
                         Writeln('Pole tr�jkata r�wnobocznego = ',wynik:2:2);
                  End;
                  3:Begin
                         writeln('Wprowad� bok a');
                         readln(a);
                         writeln('Wprowad� bok h');
                         readln(b);
                         wynik:=a*b;
                         Writeln('Pole r�wnolegloboku = ',wynik:2:2);
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



          End; { zako�czenie g��wnego IF-a }
          writeln('');
          writeln('');
          writeln('Koniec programu');
          writeln('');
          writeln('Wcisnij spacje aby zakonczyc lub jakikolwiek inny znak by powtorzyc program');
          petla := Readkey;
          End;

     until (Ord(petla) = 32);

End.

Program emoty;
uses CRT;
var i,x,y,typ:byte;

procedure pokaz(a,x,y,typ:byte);
var j:byte;
begin
     gotoXY(x,y);
     if typ=0 then Begin
        FOR j:=1 to a do Begin
            write (';< ');
        End;
     end
     else
     Begin
          FOR j:=1 to a do begin
            write ('xD ');
          End;
     End;
end;


begin
    clrscr;
    highVideo;
    writeln('ile buziek?');
    readln(i);
    writeln('jakich buziek? (0: smutas, inny numer: smile)');
    readln(typ);
    writeln('w jakiej pozycji x?');
    readln(x);
    writeln('w jakiej pozycji y?');
    readln(y);

    clrscr;

    pokaz(i,x,y,typ);
    repeat
    until KeyPressed;
End.
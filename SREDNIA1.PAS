program srednia1;
uses crt;
var a,b,c,d : real;

begin
    ClrScr;
    writeln ('Wprowadz trzy dowolne wartosci');
    read (a,b,c);
    d:=(a+b+c)/3;
    write ('Srednia wynosi',d);

end.
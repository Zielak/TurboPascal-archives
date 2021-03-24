program pole;
uses crt;
var a,b,p : real;

Begin
     ClrScr;
     writeln('Program "pole" wynacza pole prostok¥ta \n prosz© poda† warto˜i obu bok¢w:');
     writeln('');
     writeln('Podaj bok pierwszy, "a":');
     Read(a);
     writeln('Podaj bok drugi, "b":');
     Read(b);
     p:=a*b;
     writeln('Pole prostok¥tu wynosi :');
     writeln(p);
end.
uses Crt;

var
 C: Char;

begin
     repeat
           Writeln('Wcisnij guzik...');
           C := Readkey;
           Writeln(' Wcisnales [ ', C, ' ] a jego ASCII= ', Ord(C));
     until keypressed;
end.



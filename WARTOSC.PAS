program wartosc;
var a,b : real;

begin
     read (a);
     If a=0 then writeln ('wartosc jest r¢wna 0')
        else IF a>0 then writeln ('wartosc=',a)
            else begin
                  b:=a*-1;
                  writeln ('wartosc=',b);
                  end
end.


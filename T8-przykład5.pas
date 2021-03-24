program Test1;
uses Crt;
var a,b:integer;

procedure Wartosci(x, y: integer);
begin
	x:= x+1;
	y:= y-1;
	Writeln('x = ',x);
	Writeln('y = ',y);
end;

begin;
	ClrScr;
	Readln(a,b);
	Wartosci(a,b);
	Writeln('a = ',a);
	Writeln('b = ',b);
end.

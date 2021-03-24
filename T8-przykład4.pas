program Przyklad4;
uses Crt;
var i,n:integer;

procedure Usmiechy(m:integer);
var k:integer;
begin
	ClrScr;
	Writeln ('usmiech - liczba dodatnia, smutek-liczba niedodatnia');
	Readln(k);
	ClrScr;
	GotoXY(12,24);
	if k>0 then for i:=1 to m do Write(':-)')
				 else for i:=1 to m do Write(':-(');
end;

begin
	ClrScr;
	Writeln('Podaj liczbe usmiechow lub smutkow');
	Readln(n);
	Usmiechy(n);
	Readln;
end.

program jakistam;
uses crt;
var ip,ipp,tmp,s: integer;
begin
clrscr;
ipp:=1;
ip:=0;
writeln('Podaj ile ma wypisac liczb: ');
readln(s);
write(ipp:5);
repeat
begin
tmp:=ip+ipp;
ip:=ipp;
ipp:=tmp;
write(tmp:5);
s:=s-1;
end;
until s=1;
readln;
end.
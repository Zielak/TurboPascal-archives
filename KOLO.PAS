program kolo;

uses crt;

var x,y,i,a        :real;

Begin

clrscr;
a:=1;
while (a>360) do Begin
      a:=a+1;
      x:=5*COS(a);
      y:=5*SIN(a);
      MoveTo(x,y);
      write('*');
End;

End.
Program Prostopad;
uses crt;
var a,b,h,p : real;

begin
    clrscr;
    writeln ('Program liczy pole pow. ca�kowitej prostopad�o�cianu');
    writeln ('wprowad� d�ugo�� podstawy tego prostopad�o�cianu');
    read(a);
    If a<=0 then begin writeln ('z�a warto��. podaj inn�!!!');
                       read (a);
                 end
    writeln ('wprowad� d�ugo�� d�ugo�� drugiego boku podstawy');

    If a<=0 then begin writeln ('z�a warto��. podaj inn�!!!');
                       read (b);
                 end


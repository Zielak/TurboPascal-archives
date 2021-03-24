program 1d tablice;

USES CRT;

var x:integer;
    t1: array[1..11] of float;
    t2: array[1..11] of float;



procedure wejscie(float t1, float t2)
var i:byte := 0;
begin
     writeln;
     writeln('Tablica pierwsza');
     writeln;
     for i:=1 to 11 begin
         write('t1[',i'] : ');
         readln(t1[i]);
     end;
     
     writeln;
     writeln('Tablica druga');
     writeln;
     for i:=1 to 11 begin
         write('t2[',i'] : ');
         readln(t2[i]);
     end;
end;

procedure wyjscie(txt:string, ot:real)
begin
     writeln(txt,': ',ot:2:2);
end;

function suma(float* t1, float* t2)
begin
     int i=0;
     float out=0;
     
     for(i=0; i<10; i++)begin
         out+=t1[i];
         out+=t2[i];
     }
     
     return out;
}
function roznica(float* t1, float* t2)
begin
     int i=0;
     float out=0, o1=0 ,o2=0;
     
     // suma tablic
     for(i=0; i<10; i++)begin
         o1+=t1[i];
         o2+=t2[i];
     }
     // i odejmowanie
     if(o1 > o2)begin
          out = o1 - o2;
     }elsebegin
          out = o2 - o1;
     }
     
     return out;
}


begin
     do
     begin
           system("cls"); 
           cout<<"MENU:\n\n";
           writeln(""Zadania na dwóch tablicach jedno wymiarowych\n\n";
           writeln(""1.Suma\n2.Roznica\n0.Wyjscie\n\n";
           cin>>x;
           switch x
           begin
           case 1: begin
                    wejscie(t1, t2);
                    wyjscie("Suma tablicy wynosi", suma(t1, t2));
                    break;
                   end;
           case 2: begin
                    wejscie(t1, t2);
                    wyjscie("Roznica tablicy wynosi", roznica(t1, t2));
                    break;
                   end;
           case 0: break;
                    default: writeln(""Podales zly numer!\n";
                             system("PAUSE"); break;  
           end
     writeln;
     writeln;
     system("PAUSE");
     endwhile(x!=0);
     
end.


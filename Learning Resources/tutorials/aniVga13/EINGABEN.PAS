{$UNDEF test}
{$IFDEF test}
  PROGRAM eingaben;
  {$A+,B-,D+,E-,F-,G-,I+,L+,N-,O-,R+,S+,V+,X-}
  {$M 16384,0,655360}
{$ELSE}
  unit eingaben;
  {$A+,B-,D+,E-,F-,G-,I-,L+,N-,O-,R-,S-,V-,X-}
  {$M 16384,0,655360}

{Zweck    : Stellt eine komfortable Eingaberoutine zur VerfÅgung}
{Autor    : Kai Rohrbacher    }
{Sprache  : TurboPascal 6.0   }
{Datum    : 17.09.1992        }
{Anmerkung: Arbeitet mit allen Textmodi}

INTERFACE
{$ENDIF}
USES crt,dos;

CONST MaxInput=79;
TYPE  InputString=String[MaxInput];

{$IFNDEF test}

PROCEDURE GetString(VAR InOutStr:InputString; MaxLen:Byte;
                    VAR abbruch:Boolean);
PROCEDURE BoxGetString(VAR InOutStr:InputString; MaxLen:Byte;
                    VAR abbruch:Boolean; header:InputString);

IMPLEMENTATION
{$ENDIF}

CONST StackSize=10;
      BufStart:Integer=0;
      BufEnd:Integer=0;
      StackEmpty:Boolean=true;
      InsertM:Boolean=true;
VAR Stack:Array[0..StackSize] OF InputString;
    columns:BYTE ABSOLUTE $40:$4A; {#Spalten des aktuellen Videomodus}


PROCEDURE GetString(VAR InOutStr:InputString; MaxLen:Byte;
                    VAR abbruch:Boolean);
{ in: "InOutStr" = Defaultstring fÅr Eingabe}
{     "MaxLen"  = maximale LÑnge der Eingabe}
{     "abbruch" = TRUE/FALSE fÅr: alten Eingabenstapel lîschen/nicht lîschen}
{out: "InOutStr" = eingegebener String (falls "abbruch"= FALSE)}
{     "abbruch" = TRUE/FALSE, wenn ESC/RETURN eingegeben wurde}
{     "Stack" (globale Variable!) wurde um "ActualLine" ergÑnzt, wenn die}
{     Eingabe mit RETURN beendet wurde und kein Leerstring war: diese}
{     Variable ist somit eine Art "Eingabestapel" frÅherer Eingaben}
{rem: Editiermîglichkeiten wie bei Wordstareditor, zusÑtzlich }
{     UP/DOWN fÅr die letzten "StackSize+1" Eingaben}
{     Die Eingabe beginnt an der aktuellen Cursorposition und darf }
{     den rechten Bildschirmrand nicht Åberschreiten (die Prozedur }
{     schneidet allerdings selber entsprechend ab)! Aus dem selben }
{     Grund kann eine Eingabe von vorneherein maximal "MaxInput"   }
{     Zeichen lang sein.}
CONST stop:set of char=
   ['0'..'9','A'..'Z','a'..'z','Ñ','î','Å','·','é','ô','ö'];
VAR oldx,oldy:byte;
    currentline:Integer;
    LineDone:boolean;
    temp:Integer;
    ActualLine:InputString;
    index:BYTE;
    Wahl:WORD;
    done:boolean;
    ch:char;

  PROCEDURE ShowActualLine;
  VAR i:BYTE;
  BEGIN
   GotoXY(oldx+length(ActualLine),oldy);
   FOR i:=Succ(length(ActualLine)) TO MaxLen DO WRITE(' ');
   GotoXY(oldx,oldy);
   WRITE(ActualLine)
  END;

  FUNCTION SearchForward(von:BYTE):BYTE;
  VAR max:BYTE;
  BEGIN
   max:=succ(length(ActualLine));
   WHILE (von<max) and (ActualLine[von] in stop) DO inc(von);
   if von<max THEN inc(von);
   WHILE (von<max) and NOT(ActualLine[von] in stop) DO inc(von);
   if (von>max)
    THEN SearchForward:=max
    ELSE SearchForward:=von
  END;

  FUNCTION SearchBackward(von:SHORTINT):BYTE;
  BEGIN
   Dec(von);
   WHILE (von>0) and NOT(ActualLine[von] in stop) DO dec(von);
   if von>0 THEN dec(von);
   WHILE (von>0) and (ActualLine[von] in stop) DO dec(von);
   if (von<0)
    THEN SearchBackward:=0
    ELSE SearchBackward:=Succ(von)
  END;

BEGIN {of GetString}
 oldx:=wherex; oldy:=wherey;
 IF MaxLen>columns-oldx THEN MaxLen:=columns-oldx;
 ActualLine:=copy(InOutStr,1,MaxLen);
 IF abbruch
  THEN BEGIN
        BufStart:=0; BufEnd:=0; StackEmpty:=TRUE;
       END;
 currentline:=BufEnd; LineDone:=false; abbruch:=false;
 Stack[BufEnd]:='';
 REPEAT
  ShowActualLine;
  index:=succ(length(ActualLine));
  if index>MaxLen THEN index:=MaxLen;
  done:=false;
  REPEAT
   GotoXY(pred(oldx+index),oldy);
   ch:=readkey;
   if ch>=' '
    THEN BEGIN
          if InsertM
           THEN BEGIN
                 insert(ch,ActualLine,index);
                 ActualLine:=copy(ActualLine,1,MaxLen);
                 write(copy(ActualLine,index,255));
                 if index<MaxLen THEN inc(index)
                END
           ELSE BEGIN
                 ActualLine[index]:=ch;
                 if index<=MaxLen THEN write(ch);
                 if ActualLine[0]<chr(index) THEN ActualLine[0]:=chr(index);
                 if index<MaxLen THEN inc(index)
                END;
         END
    ELSE BEGIN
          IF ch=#0
           THEN Wahl:=ORD(ReadKey) SHL 8  {Funktionstasten -> >256}
           ELSE Wahl:=ORD(ch);
          CASE Wahl OF
           $000D, {RETURN}
           $4800, {UP}
           $5000, {DOWN}
           $001B: {ESC}
                  done:=true;  {wird spÑter abgehandelt}
           $0016,
           $5200:InsertM:=not InsertM; {^V, INS}
           $4B00:if index>1 THEN dec(index); {LEFT}
           $4D00:BEGIN {RIGHT}
                  if index<=length(ActualLine) THEN inc(index);
                  if index>MaxLen THEN index:=MaxLen
                 END;
           $4700:index:=1; {HOME}
           $4F00:BEGIN {END}
                  index:=succ(length(ActualLine));
                  if index>MaxLen THEN index:=MaxLen
                 END;
           $0008:if index>1
                  THEN BEGIN {BACKSPACE, ^H}
                        dec(index);
                        delete(ActualLine,index,1);
                        ShowActualLine
                       END;
           $0007,
           $5300:if ActualLine<>''
                  THEN BEGIN {^G, DEL}
                        delete(ActualLine,index,1);
                        ShowActualLine
                       END;
           $0001,
           $7300:index:=SearchBackward(index); {^A, CTRL-LEFT}
           $0006,
           $7400:BEGIN {^F, CTRL-RIGHT}
                  index:=SearchForward(index);
                  if index>MaxLen THEN index:=MaxLen
                 END;
           $000B:BEGIN {^K}
                  delete(ActualLine,index,255);
                  ShowActualLine
                 END;
           $0014:BEGIN {^T}
                  delete(ActualLine,index,SearchForward(index)-index);
                  ShowActualLine
                 END;
           $0019:BEGIN {^Y}
                  ActualLine:=''; index:=1; ShowActualLine
                 END;
          END;
         END;
  UNTIL done;

  CASE Wahl of
   $000D:BEGIN {RETURN}
          LineDone:=true;
          IF length(ActualLine)>0
           THEN BEGIN
                 Stack[BufEnd]:=ActualLine;
                 BufEnd:=succ(BufEnd) mod succ(StackSize);
                 if BufEnd=0 THEN StackEmpty:=false;
                 if not StackEmpty
                  THEN BufStart:=succ(BufStart) mod succ(StackSize)
                END;
         END;
   $001B:abbruch:=true; {ESC}
   $4800:BEGIN {Up}
          if currentline<>BufStart
           THEN BEGIN
                 dec(currentline);
                 if currentline<0 THEN currentline:=StackSize
                END;
          ActualLine:=Stack[currentline];
         END;
   $5000:BEGIN {Down}
          if currentline<>BufEnd
           THEN currentline:=succ(currentline) mod succ(StackSize);
          ActualLine:=Stack[currentline];
         END;
  END;
 UNTIL LineDone or abbruch;
 if LineDone THEN InOutStr:=ActualLine;
END;

PROCEDURE BoxGetString(VAR InOutStr:InputString; MaxLen:Byte;
                       VAR abbruch:Boolean; header:InputString);
{ in,out,rem: wie bei GetString() auch! ZusÑtzlich:}
{ in: header = auszugebender Boxtext}
{rem: Um den Eingabebereich wird eine Box gezogen und mit einem Header }
{     versehen; dieser Header mu· natÅrlich in die Box passen!}
{     Au·erdem mu· die Box um den Eingabebereich herum passen!}
VAR oldx,oldy,i,n:BYTE;
BEGIN
 oldx:=WhereX; oldy:=WhereY;
 IF length(header)>MaxLen
  THEN Delete(header,Succ(MaxLen),length(header)-MaxLen); {evtl. kÅrzen}
 IF length(header)<MaxLen THEN header:=' '+header;
 IF length(header)<MaxLen THEN header:=header+' ';
 GotoXY(Pred(oldx),Pred(oldy));
 WRITE('…');
 n:=MaxLen-length(header);
 FOR i:=1 TO n SHR 1 DO WRITE('Õ');
 WRITE(header);
 IF odd(n) THEN WRITE('Õ');
 FOR i:=1 TO n SHR 1 DO WRITE('Õ');
 WRITE('ª');

 GotoXY(Pred(oldx),oldy);
 WRITE('∫'); FOR i:=1 TO MaxLen DO WRITE(' '); WRITE('∫');
 GotoXY(Pred(oldx),Succ(oldy));
 WRITE('»'); FOR i:=1 TO MaxLen DO WRITE('Õ'); WRITE('º');

 GotoXY(oldx,oldy);
 GetString(InOutStr,MaxLen,abbruch)
END;

{$IFDEF test}
VAR s:InputString;
    flag:BOOLEAN;
    attr:BYTE;
{$ENDIF}

BEGIN
{$IFDEF test}
 REPEAT
   ClrScr;
   GotoXY(10,12);
   s:='Default'; FLAG:=FALSE;
   attr:=TextAttr; TextColor(White); TextBackground(Blue);
   BoxGetString(s,20,FLAG,'Beliebiger Text:');
   TextAttr:=attr;
   GotoXY(1,1);
   IF FLAG
    THEN WRITELN('Abbruch!')
    ELSE WRITELN('Eingabe: ',s);
   READLN;
 UNTIL FLAG;
{$ENDIF}
END.
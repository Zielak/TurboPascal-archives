{$UNDEF test}

{$IFDEF test}
 {$A+,B-,D+,E-,F-,G-,I+,L+,N-,O-,R+,S+,V+,X-}
 {$M 16384,65536,655360}
{$ELSE}
 {$A+,B-,D+,E-,F-,G-,I-,L+,N-,O-,R-,S-,V-,X-}
 {$M 16384,65536,655360}
{$ENDIF}

PROGRAM DumpSpriteFile;
{Zweck    : Erstellt aus einem Spritefile eine leserliche ASCII-Beschreibung}
{Autor    : Kai Rohrbacher                }
{Sprache  : TurboPascal V6.0              }
{Datum    : 29.10.1991                    }
{Anmerkung: Ausgabe kann in eine Datei umgeleitet werden!}

USES DOS;
CONST Datenbytes=65485;  {maximale Spritegroesse eines Sprites, die hier}
                         {im Programm bearbeitet werden kann  (-40) }
      Err_None=0;
      Err_NotEnoughMemory=1;
      Err_FileIO=2;
      Err_NoSprite=4;
      Err_NoFile=99;

TYPE SpriteHeader= RECORD
                    Zeiger_auf_Plane:Array[0..3] OF Word;
                    Breite_in_4er_Gruppen:WORD;
                    Hoehe_in_Zeilen:WORD;
                    Translate:Array[1..4] OF Byte;
                    SpriteLength:WORD;
                    Dummy:Array[1..10] OF Word;
                    Kennung:ARRAY[1..2] OF CHAR;
                    Version:BYTE;
                    Modus:BYTE;
                    ZeigerL,ZeigerR,ZeigerO,ZeigerU:Word;
                   END;

     sprite_typ= record case Integer of
      0:( Header:Spriteheader;
          Data:Array[1..Datenbytes] OF Byte;
        );
      1:(
         readin:Array[0..Datenbytes-1 +40] OF Byte;
        )
     END;

LABEL quit_loop,
      quit_without_close;

VAR f:file;
    sprite:^sprite_typ;
    count,Kopf:WORD;
    Error:BYTE;
    P: PathStr;
    D: DirStr;
    N: NameStr;
    E: ExtStr;


FUNCTION FillBlanks(s:STRING):STRING;
{haengt an s soviele Blanks an, dass es ein Vielfaches von 13 lang wird}
CONST blanks='            '; {12 Stueck}
BEGIN
 FillBlanks:=s+Copy(blanks,1,(13-(length(s) MOD 13)) MOD 13)
END;

PROCEDURE Put(s:STRING);
BEGIN
 WRITELN(s);
END;

PROCEDURE SpriteDatenausgeben(VAR sprite:sprite_typ; count:WORD;
                              P:PathStr; name:NameStr);
CONST tab1='     '; {Tabulator vom linken Rand bis zum Operandenfeld}
VAR Tabellen_Breite,i,j:Word;
    sp,t1,t2:STRING;

BEGIN
 IF count=0
  THEN BEGIN  {erster Aufruf dieser Routine}
        Put(';');
        Put('; ASCII-listing of ANIVGA sprite file '+P);
        Put('; Created with "DUMP_SPR '+P+'"');
        Put(';');
        Put('; This file can be recompiled to a valid sprite file '
            +'with these commands:');
        Put(Fillblanks(';  MASM '+name+'.TXT;')+' -> gives you '+name+'.OBJ');
        Put(Fillblanks(';  LINK '+name+'.OBJ;')+' -> gives you '+name+'.EXE');
        Put(';  EXE2BIN '+name+'.EXE '+name+'.COD  (or .LIB)');
        Put('');
        Put(Fillblanks('DATA SEGMENT')+' ; to cheat the assembler...');
       END;
 STR(count,sp); sp:=name+sp; {Spritename erzeugen}

 Put('');
 Put(';------------------------------------------');
 Put(Fillblanks(sp+' EQU $')+' ; arbitrarily chosen name for this sprite');

 WITH Sprite.Header DO
 BEGIN
  Put('');
  Put('; Offset-pointer to plane data tables:');
  FOR i:=0 TO 3 DO
   BEGIN
    STR(Zeiger_auf_Plane[i]:4,t1); STR(i,t2);
    t1:=Fillblanks(tab1+'DW '+sp+'_Plane'+t2+' -'+sp)
        +' ; ptr to plane '+t2+' (= DW '+t1+')';
    Put(t1)
   END;

  Put('');
  STR(Breite_in_4er_Gruppen:4,t1);
  Put(Fillblanks(tab1+'DW '+t1)+' ; sprite width in multiples of 4 points');

  STR(Hoehe_in_Zeilen:4,t1);
  Put(Fillblanks(tab1+'DW '+t1)+' ; sprite height in lines');

  t1:=tab1+'DB ';
  FOR i:=1 TO 4 DO
   BEGIN
    STR(Translate[i],t2);
    t1:=t1+t2;
    IF i<>4 THEN t1:=t1+','
   END;
  Put(Fillblanks(t1)+' ; some constants: "translate tab", must be 1,2,4,8');

  STR(SpriteLength:4,t1);
  Put(Fillblanks(tab1+'DW '+t1)+' ; length of this sprite in bytes');

  t1:=tab1+'DW ';
  FOR i:=1 TO 10 DO
   BEGIN
    STR(Dummy[i],t2);
    t1:=t1+t2;
    IF i<>10 THEN t1:=t1+','
   END;
  Put(Fillblanks(t1)+' ; 10 dummy words, should be all 0');

  t1:=tab1+'DB '+''''+Kennung[1]+''','''+Kennung[2]+'''';
  Put(Fillblanks(t1)+' ; flag, must be "KR"');

  STR(Version:4,t1);
  Put(Fillblanks(tab1+'DB '+t1)+' ; version number, normally "1"');

  STR(Modus:4,t1);
  Put(Fillblanks(tab1+'DB '+t1)+' ; default display mode of sprite');

  STR(ZeigerL:4,t1);
  Put(Fillblanks(tab1+'DW '+sp+'_Left  -'+sp)+' ; ptr to left   boundaries (= DW '+t1+')');
  STR(ZeigerR:4,t1);
  Put(Fillblanks(tab1+'DW '+sp+'_Right -'+sp)+' ; ptr to right  boundaries (= DW '+t1+')');
  STR(ZeigerO:4,t1);
  Put(Fillblanks(tab1+'DW '+sp+'_Top   -'+sp)+' ; ptr to top    boundaries (= DW '+t1+')');
  STR(ZeigerU:4,t1);
  Put(Fillblanks(tab1+'DW '+sp+'_Bottom-'+sp)+' ; ptr to bottom boundaries (= DW '+t1+')');

  Put('');
  Put(Fillblanks(sp+'_Left   EQU $')+' ; Left boundary table');
  t1:=tab1+'DW ';
  FOR i:=0 TO Hoehe_in_Zeilen-1 DO
   BEGIN
    STR(INTEGER(Sprite.Readin[ZeigerL +i shl 1]
           +256*Sprite.Readin[Succ(ZeigerL +i shl 1)]),t2);
    t1:=t1+t2;
    IF length(t1)>75
     THEN BEGIN
           Put(t1);
           t1:=tab1+'DW ';
          END
     ELSE BEGIN
           IF i<>Hoehe_in_Zeilen-1
            THEN t1:=t1+','
            ELSE Put(t1)
          END;
   END;

  Put(Fillblanks(sp+'_Right  EQU $')+' ; Right boundary table');
  t1:=tab1+'DW ';
  FOR i:=0 TO Hoehe_in_Zeilen-1 DO
   BEGIN
    STR(INTEGER(Sprite.Readin[ZeigerR +i shl 1]
           +256*Sprite.Readin[Succ(ZeigerR +i shl 1)]),t2);
    t1:=t1+t2;
    IF length(t1)>75
     THEN BEGIN
           Put(t1);
           t1:=tab1+'DW ';
          END
     ELSE BEGIN
           IF i<>Hoehe_in_Zeilen-1
            THEN t1:=t1+','
            ELSE Put(t1)
          END;
   END;

  Put(Fillblanks(sp+'_Top    EQU $')+' ; Top boundary table');
  t1:=tab1+'DW ';
  FOR i:=0 TO Breite_in_4er_Gruppen*4-1 DO
   BEGIN
    STR(INTEGER(Sprite.Readin[ZeigerO +i shl 1]
           +256*Sprite.Readin[Succ(ZeigerO +i shl 1)]),t2);
    t1:=t1+t2;
    IF length(t1)>75
     THEN BEGIN
           Put(t1);
           t1:=tab1+'DW ';
          END
     ELSE BEGIN
           IF i<>Breite_in_4er_Gruppen*4-1
            THEN t1:=t1+','
            ELSE Put(t1)
          END;
   END;

  Put(Fillblanks(sp+'_Bottom EQU $')+' ; Bottom boundary table');
  t1:=tab1+'DW ';
  FOR i:=0 TO Breite_in_4er_Gruppen*4-1 DO
   BEGIN
    STR(INTEGER(Sprite.Readin[ZeigerU +i shl 1]
           +256*Sprite.Readin[Succ(ZeigerU +i shl 1)]),t2);
    t1:=t1+t2;
    IF length(t1)>75
     THEN BEGIN
           Put(t1);
           t1:=tab1+'DW ';
          END
     ELSE BEGIN
           IF i<>Breite_in_4er_Gruppen*4-1
            THEN t1:=t1+','
            ELSE Put(t1)
          END;
   END;

  Put(''); 
  Tabellen_Breite:=Breite_in_4er_Gruppen*Hoehe_in_Zeilen;
  FOR j:=0 TO 3 DO
   BEGIN
    STR(j,t2);
    t1:=Fillblanks(sp+'_Plane'+t2+' EQU $')+' ; Data for plane '+t2;
    Put(t1);
    t1:=tab1+'DB ';
    FOR i:=Zeiger_auf_Plane[j] TO Pred(Zeiger_auf_Plane[j]+Tabellen_Breite)
     DO BEGIN
         STR(Sprite.Readin[i],t2);
         t1:=t1+t2;
         IF length(t1)>75
          THEN BEGIN
                Put(t1);
                t1:=tab1+'DB '
               END
          ELSE BEGIN
                IF i<>Pred(Zeiger_auf_Plane[j]+Tabellen_Breite)
                 THEN t1:=t1+','
                 ELSE Put(t1)
               END;
        END; 

   END;
  Put('');

 END; {of WITH}
END;

FUNCTION GetErrorMessage:STRING;
{ in: Error = Nummer des aufgetretenen Fehlers}
{out: den Fehler in Worten}
BEGIN
 CASE Error OF
  Err_None:GetErrorMessage:='No Error';
  Err_NotEnoughMemory:GetErrorMessage:='Not enough memory available on heap';
  Err_FileIO:GetErrorMessage:='I/O-error with file';
  Err_NoSprite:GetErrorMessage:='No (or corrupted) sprite file';
  Err_NoFile:GetErrorMessage:='File doesn''t exist!';
  ELSE GetErrorMessage:='Unknown error';
 END;
END;


BEGIN
 New(sprite);
 Error:=Err_None;
 P:=paramstr(1);
 IF (ParamCount<>1) OR (P='/?') OR (P='-?') THEN
  BEGIN
   WRITELN;
   WRITELN('SpriteDumper, V1.10     -- by Kai Rohrbacher  (c) 1991,1992');
   WRITELN('Disassembles *.COD or *.LIB files into readable ASCII-text.');
   WRITELN;
   WRITELN('Call SpriteDumper in one of these forms:');
   WRITELN;
   WRITELN(' '+ParamStr(0)+' sprite.ext     or');
   WRITELN(' '+ParamStr(0)+' sprite.ext >sprite.TXT');
   WRITELN;
   WRITELN('The first form will list the sprite''s contents to the screen, '
          +'while the second');
   WRITELN('one will produce the ASCII-file sprite.TXT for further usage.');
   goto quit_without_close;
  END;

 FSplit(P,D,N,E);

 assign(f,P);
 {$I-}
 reset(f,1);
 {$I+}
 IF (ioresult<>0) or (P='')
  THEN BEGIN
        Error:=Err_NoFile; goto quit_without_close;
       END;

 Kopf:=SizeOf(SpriteHeader); count:=0;

 WHILE NOT EOF(f) DO
 BEGIN
  {Zunaechst den Spriteheader einlesen: }
  {$I-}     {jetzt den Spriteheader vi… BLOCKREAD auf den Heap laden}
  blockread(f,Sprite^.Readin[0],Kopf);
  {$I+}

  IF (ioresult<>0)
   THEN BEGIN
         Error:=Err_FileIO;
         goto quit_loop;
        END;
  IF (Sprite^.Header.Kennung[1]<>'K') or (Sprite^.Header.Kennung[2]<>'R')
   THEN BEGIN
         Error:=Err_NoSprite;
         goto quit_loop;
        END;
  IF (Sprite^.Header.SpriteLength>SizeOf(Sprite_Typ))  {noch genug Platz da?}
   THEN BEGIN
         Error:=Err_NotEnoughMemory;
         goto quit_loop;
        END;

  {Jetzt eigentliche Spritedaten einlesen: }
  {$I-}
  blockread(f,Sprite^.Data[1],Sprite^.Header.SpriteLength-Kopf);
  {$I+}
  IF (ioresult<>0)
   THEN BEGIN
         Error:=Err_FileIO;
         goto quit_loop;
        END;

  SpriteDatenausgeben(sprite^,count,P,N);
  INC(count);

 END; {of WHILE}

quit_loop: ;

 {$I-}
 close(f);
 {$I+}

 Put(Fillblanks('DATA ENDS')+' ; to make the assembler happy');
 Put(Fillblanks('END')+' ; that''s all folks!');

quit_without_close: ;

 IF Error<>Err_None
  THEN WRITELN('*** Error: '+GetErrorMessage);

 Dispose(sprite);
END.

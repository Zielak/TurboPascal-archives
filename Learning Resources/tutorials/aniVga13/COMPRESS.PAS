{$UNDEF test}     {Wenn "test" definiert ist: Programm, sonst Unit}
{$DEFINE RLE}     {Wenn "RLE"  definiert ist: Huffman _und_ RLE-Codierung}
{$UNDEF IOcheck}  {Wenn "IOcheck" definiert ist: $I+, sonst $I-}

{$IFDEF test}
{$A+,B-,D+,E+,F-,G-,I+,L+,N+,O-,R-,S+,V+,X-}
{$M 32768,0,655360}
{$ELSE}
{$A+,B-,D+,E+,F-,G-,I+,L+,N+,O-,R-,S-,V-,X-}
{$M 32768,0,655360}
{$ENDIF}

{$IFDEF test}
PROGRAM compression;
{$ELSE}
UNIT compression;
INTERFACE
{$ENDIF}

{Zweck    : Datenkompression nach Huffman (und RLE)}
{Autor    : Kai Rohrbacher    }
{Sprache  : TurboPascal 6.0   }
{Datum    : 25.09.1992        }
{Anmerkung: Die zur VerfÅgung gestellten "FileOfBytes" benîtigen eine Menge}
{           Speicher, so da· genÅgend Stackspeicher vorhanden sein mu·;    }
{           ebenso empfiehlt es sich, mit mîglichst wenigen solcher Dateien}
{           auszukommen, Stichwort: Mehrfachausnutzung! (Unschîn, aber     }
{           wirksam!)}
{           ErrorCompress enthÑlt den zuletzt aufgetretenen Fehler; diese  }
{           Variable mu· vom Anwender berÅcksichtigt und anschlie·end auf  }
{           CompressErr_NoError zurÅckgesetzt werden!}
USES CRT,DOS;

TYPE header=ARRAY[1..3] OF BYTE;                {Erkennungsheader fÅr}
CONST Kennung:header=(ORD('H'),ORD('U'),ORD('C')); {komprimierte Dateien}
{$IFDEF RLE}
      ESC:BYTE=$1B;
      FFh:BYTE=$FF;
      TemporaryFile='_RLE.$$$';
{$ENDIF}

CONST BufSize=512; {E/A-Puffergrî·e = 512 Bytes}

      CompressErr_NoError=0;          {mîgliche Fehlerkonstanten}
      CompressErr_Size0  =1;
      CompressErr_AlreadyCompressed=2;
      CompressErr_FileNotFound=3;
      CompressErr_FileNotOpen=4;
      CompressErr_DiskFull=5;
      CompressErr_Unknown=255;

      CompressError:BYTE=CompressErr_NoError;

TYPE Pbranch=^branch;
     branch=RECORD
             zeichen:BYTE;
             links,rechts:Pbranch
            END;
     code=RECORD
           bitcount:BYTE; {max. AstlÑnge (und damit auch CodelÑnge)=255 Bit!}
           itself:ARRAY[0..31] OF BYTE {32 Byte=256 Bits fÅr den Code selber}
          END;

     Puffer=ARRAY[0..BufSize-1] OF BYTE;
     {Folgender Typ wird nur fÅr einen Typecast des E/A-Puffers gebraucht}
     {und gehîrt eindeutig in die Rubrik "dirty tricks"...}
     Kopf=RECORD 
           info  :Header;
           Laengeunkom,Laengekom:LONGINT;
           fillup:ARRAY[SizeOf(Header)+SizeOf(LongInt)+SizeOf(LongInt)
                        ..BufSize-1] OF BYTE
          END;

     FileOfByte=RECORD
                 datei:FILE;
                 lesen,               {lesen oder schreiben?}
                 komprimiert:BOOLEAN; {komprimiert oder normales File?}
                 lenunkom,            {unkomprimierte Bytesanzahl}
                 lenbitskom:LONGINT;  {DateilÑnge in Bits}
                 filebitpos:LONGINT;  {akt. BIT-Pos. im File}
                 position:LONGINT;    {aktuelle Position im File}
                 msdosSize:LONGINT;   {totale LÑnge des Files}
                 bitzaehl:BYTE;       {BitzÑhler fÅr Bits in eabyte}
                 buf:Puffer;          {Puffer fÅr E/A-Operationen}
                 bufIndex:WORD;       {Indexzeiger in buf}
                 bufMax:WORD;         {-1=max. Wert von bufIndex}
                 stamm:branch;        {Wurzel des Codebaums}
                 codes:ARRAY[0..255] OF code;  {Codes selber}
                 {$IFDEF RLE}
                 RLEcount:INTEGER;
                 RLEchar :BYTE;
                 {$ENDIF}
                END;

{$IFNDEF test}
 PROCEDURE WriteBits(VAR f:FileOfByte; wert,Stellen:BYTE);
 PROCEDURE ReadBits(VAR f:FileOfByte; VAR wert:BYTE; Stellen:BYTE);
 PROCEDURE _Assign(VAR f:FileOfByte; s:STRING);
 PROCEDURE _Reset(VAR f:FileOfByte);
 PROCEDURE _Rewrite(VAR f:FileOfByte);
 PROCEDURE _Flush(VAR f:FileOfByte);
 FUNCTION  _FilePos(VAR f:FileOfByte):LONGINT;
 PROCEDURE _Close(VAR f:FileOfByte);
 FUNCTION  _logicalEOF(VAR f:FileOfByte):BOOLEAN;
 FUNCTION  _physicalEOF(VAR f:FileOfByte):BOOLEAN;
 PROCEDURE Resync(VAR f:FileOfByte);
 FUNCTION  _FileSize(VAR f:FileOfByte):LONGINT;
 PROCEDURE _Write(VAR f:FileOfByte; VAR b:BYTE);
 PROCEDURE _Read(VAR f:FileOfByte; VAR b:BYTE);
 PROCEDURE _ReadByte(VAR f:FileOfByte; VAR b:BYTE);
 {$IFDEF RLE}
 PROCEDURE RLEcompress(name1,name2:PathStr; VAR fin,fout:FileOfByte; chatty:BOOLEAN);
 {$ENDIF}
 PROCEDURE _BlockRead(VAR f:FileOfByte; var buf; count: Word);
 PROCEDURE __BlockRead(VAR f:FileOfByte; var buf; count: Word; VAR result:WORD);
 PROCEDURE _BlockWrite(VAR f:FileOfByte; var buf; count: Word);
 PROCEDURE __BlockWrite(VAR f:FileOfByte; var buf; count: Word; VAR result:WORD);
 PROCEDURE compress(name1,name2:PathStr; chatty:BOOLEAN);
 PROCEDURE decompress(name1,name2:PathStr; chatty:BOOLEAN);

 IMPLEMENTATION
{$ENDIF}

CONST ANDMask:ARRAY[0..7] OF BYTE=(254,253,251,247,239,223,191,127);
      OrMask :ARRAY[0..7] OF BYTE=(1,2,4,8,16,32,64,128);
      LowerBits:ARRAY[1..8] OF BYTE=(1,3,7,15,31,63,127,255);
VAR temp:FileOfByte;
    {$IFDEF test}
    vorher,nachher,gesamt:LONGINT; 
    ch:CHAR;
    datei1,datei2:PathStr;
    s:STRING;
    {$ENDIF}


PROCEDURE WriteBits(VAR f:FileOfByte; wert,Stellen:BYTE);
{rem: Schreibt das Byte "wert" in die Datei f und benutzt dazu "Stellen" Bits}
VAR bits:BYTE;
    i,ReallyWritten:WORD;
BEGIN
 IF f.lesen THEN exit;  {nur Ausgabedateien, bitte!}
 inc(f.lenbitskom,Stellen);
 IF f.bitzaehl>=Stellen
  THEN BEGIN {genug Platz in aktuellem Byte f.buf[f.bufIndex]}
        f.buf[f.bufIndex]:=(f.buf[f.bufIndex] SHL Stellen) OR wert;
        dec(f.bitzaehl,stellen);
        IF f.bitzaehl=0
	 THEN BEGIN {Byte fertig, ablegen und evtl. Puffer schreiben}
               inc(f.bufIndex); f.bitzaehl:=8;
               IF f.bufindex>bufSize-1
		THEN BEGIN
                      {$I-}
                      BlockWrite(f.datei,f.buf,BufSize,ReallyWritten);
                      {$IFDEF IOcheck} {$I+} {$ENDIF}
                      f.bufIndex:=0;
                      IF IOresult=103
                       THEN BEGIN
                             CompressError:=CompressErr_FileNotOpen;
                             exit
                            END
                      ELSE IF ReallyWritten<>BufSize
                       THEN BEGIN
                             CompressError:=CompressErr_DiskFull;
                             exit
                            END
                      ELSE IF IOresult<>0
                       THEN BEGIN
                             CompressError:=CompressErr_Unknown;
                             exit
                            END;
                     END;
              END;
       END
  ELSE BEGIN {öberhang ins nÑchste Byte!}
        bits:=Stellen-f.bitzaehl; {öberhang ins nÑchste Byte}
        f.buf[f.bufIndex]:=(f.buf[f.bufIndex] SHL f.bitzaehl) OR (wert SHR bits);
        inc(f.bufIndex);
        IF f.bufindex>bufSize-1
	 THEN BEGIN
               {$I-}
               BlockWrite(f.datei,f.buf,BufSize,ReallyWritten);
               {$IFDEF IOcheck} {$I+} {$ENDIF}
               f.bufIndex:=0;
               IF IOresult=103
                THEN BEGIN
                      CompressError:=CompressErr_FileNotOpen;
                      exit
                     END
               ELSE IF ReallyWritten<>BufSize
                THEN BEGIN
                      CompressError:=CompressErr_DiskFull;
                      exit
                     END
               ELSE IF IOresult<>0
                THEN BEGIN
                      CompressError:=CompressErr_Unknown;
                      exit
                     END;
              END;
        f.buf[f.bufIndex]:=wert; f.bitzaehl:=8-bits; {öberhang Åbernehmen}
       END;
END;

PROCEDURE ReadBits(VAR f:FileOfByte; VAR wert:BYTE; Stellen:BYTE);
{rem: Liest "Stellen" Bits aus der Datei f und legt diesen Wert in "wert" ab}
{     Dies ist ein rein *physikalisches* Lesen, es werden keine Uminterpre- }
{     tierungen der daten vorgenommen!}
VAR bits,temp:BYTE;
BEGIN
 inc(f.filebitpos,Stellen);
 IF NOT f.lesen THEN exit;  {nur Eingabedateien, bitte!}
 IF f.bitzaehl>=Stellen
  THEN BEGIN {genug Daten in aktuellem Eingabebyte}
        wert:=(f.buf[f.bufIndex] SHR (f.bitzaehl-Stellen))
               AND LowerBits[Stellen];
        dec(f.bitzaehl,Stellen);
        IF f.bitzaehl=0
	 THEN BEGIN
               f.bitzaehl:=8;
               inc(f.bufindex);
               IF f.bufIndex=SizeOf(f.buf)
		THEN BEGIN {nÑchsten Block lesen}
                      IF NOT EOF(f.datei)
                       THEN BEGIN
                             BlockRead(f.datei,f.buf,SizeOf(f.buf),f.bufMax);
                             f.bufIndex:=0
                            END
                      {ELSE f.bufIndex:=512} {..um EOF mitzuteilen!}
                     END;
              END
       END
  ELSE BEGIN {Daten auch aus nÑchstem Byte benîtigt}
        bits:=Stellen-f.bitzaehl; {öberhang aus nÑchstem Byte}
        temp:=f.buf[f.bufIndex] SHL bits; {Teil aus altem Byte}
        inc(f.bufindex);
        IF f.bufIndex=SizeOf(f.buf)
	 THEN BEGIN {nÑchsten Block lesen}
               IF NOT EOF(f.datei)
                THEN BlockRead(f.datei,f.buf,SizeOf(f.buf),f.bufMax);
               f.bufIndex:=0
              END;
        f.bitzaehl:=8-bits;
        wert:=(temp OR (f.buf[f.bufIndex] SHR f.bitzaehl))
               AND LowerBits[Stellen]
       END;
END;

PROCEDURE _Assign(VAR f:FileOfByte; s:STRING);
BEGIN
 assign(f.datei,s)
END;

PROCEDURE ReadHeader(VAR f:FileOfByte);
{rem: Liest aus der bereits zum lesen geîffneten Datei einen evtl. Header aus}
{     (und erstellt fÅr komprimierte Dateien den zugehîrigen Codebaum)}
LABEL break;
VAR i,wert:BYTE;
    help,dummyx:Pbranch;
BEGIN
 FOR i:=0 TO SizeOf(Header)-1 DO f.buf[i]:=0; {evtl. alte Infos lîschen}
 IF NOT EOF(f.datei)
  THEN BlockRead(f.datei,f.buf,SizeOf(f.buf),f.bufMax)  {1.Block lesen}
  ELSE f.bufMax:=0;   {signalisiere: keine Daten da!}
 IF f.bufMax<SizeOf(Header)+SizeOf(LongInt)+SizeOf(LongInt)
  THEN BEGIN {nichtkomprimierte "normale" Datei}
        f.komprimiert:=FALSE;
        f.lenunkom:=FileSize(f.datei); f.lenbitskom:=f.lenunkom SHL 3;
        f.bufIndex:=0;
       END
  ELSE BEGIN {genauer prÅfen, ob komprimiert oder nicht}
        f.komprimiert:=TRUE;
        FOR i:=1 TO SizeOf(Header) DO {Header auslesen:}
         f.komprimiert:=f.komprimiert AND (Kopf(f.buf).info[i]=Kennung[i]);
        IF f.komprimiert
	 THEN BEGIN {komprimierte Datei, Header Åberspringen}
               f.lenunkom:=Kopf(f.buf).Laengeunkom;
               f.lenbitskom:=Kopf(f.buf).Laengekom;
               f.bufIndex:=SizeOf(Header)+SizeOf(LongInt)+SizeOf(LongInt);
              END
	 ELSE BEGIN {normale Datei, bei Position 0 anfangen}
               f.lenunkom:=FileSize(f.datei); f.lenbitskom:=f.lenunkom SHL 3;
               f.bufIndex:=0;
              END;
       END;
 f.bitzaehl:=8; {alle 8 Bits des 0.ten Datenbytes noch auslesen}
 f.position:=0; {"0.tes" Datenbyte}
 f.filebitpos:=f.bufIndex SHL 3; {Anzahl gelesene Bits}
 {$IFDEF RLE}
 f.RLEcount:=0; {noch kein RLE aktiv}
 {$ENDIF}

 IF f.komprimiert
  THEN BEGIN
        f.stamm.links:=NIL;
        f.stamm.rechts:=NIL;
        help:=@f.stamm;
        FOR i:=0 TO 255 DO
         BEGIN
          ReadBits(f,wert,2);
          WHILE wert<2 DO  {Wert 2=EndOfOneCode, 3=EndOfAllCodes?}
           BEGIN {Wert 0 oder 1 = normalen Wert gelesen}
            IF wert=0
             THEN BEGIN
                   IF help^.links=NIL
                    THEN BEGIN
                          new(dummyx);
                          help^.links:=dummyx;
                          dummyx^.links:=NIL;
                          dummyx^.rechts:=NIL;
                         END;
                   help:=help^.links;
                  END
             ELSE BEGIN
                   IF help^.rechts=NIL
                    THEN BEGIN
                          new(dummyx);
                          help^.rechts:=dummyx;
                          dummyx^.links:=NIL;
                          dummyx^.rechts:=NIL;
                         END;
                   help:=help^.rechts;
                  END;
            ReadBits(f,wert,2)
           END;


          IF wert=3 THEN goto break; {Wert 3=EndOfAllCodes}
          help^.zeichen:=i;
          help:=@f.stamm;
         END; {of FOR}
        break:;
       END;
END;

PROCEDURE _Reset(VAR f:FileOfByte);
BEGIN
 {$I-}
 Reset(f.datei,1);
 {$IFDEF IOcheck} {$I+} {$ENDIF}
 IF IOresult<>0
  THEN BEGIN
        CompressError:=CompressErr_FileNotFound;
        exit
       END;
 f.lesen:=TRUE;
 f.msdosSize:=FileSize(f.datei);
 ReadHeader(f)
END;

PROCEDURE _Rewrite(VAR f:FileOfByte);
{Geschrieben wird nur nichtkomprimiert, deshalb nichts weiter als Ausgabe}
{auf Bits vorbereiten und fÅr bessere Performance "blocken"}
BEGIN
 {$I-}
 Rewrite(f.datei,1);
 {$IFDEF IOcheck} {$I+} {$ENDIF}
 IF IOresult=2
  THEN BEGIN
        CompressError:=CompressErr_FileNotFound;
        exit
       END
 ELSE IF IOresult<>0
  THEN BEGIN
        CompressError:=CompressErr_Unknown;
        exit
       END;
 f.lesen:=FALSE;
 f.lenunkom:=0; {noch nix geschrieben}
 f.lenbitskom:=0;
 f.komprimiert:=FALSE;
 f.BufIndex:=0;
 f.position:=0;
 f.filebitpos:=0;
 f.bitzaehl:=8;  {#freie Bits in eabyte}
 f.msdosSize:=0; {damit liefert _physicalEOF() immer TRUE}
END;

PROCEDURE _Flush(VAR f:FileOfByte);
{rem: Achtung! Ein _Flush() schreibt den Datenpuffer auf Disk, fÅllt aber das}
{     letzte Byte auf, d.h.: _Flush() sollte nur zum Schlu· (vor einem       }
{     _Close() ) aufgerufen werden (was eh automatisch geschieht), oder wenn }
{     man beim spÑteren einlesen das AuffÅllen berÅcksichtigt!}
VAR ReallyWritten:WORD;
BEGIN
 IF f.lesen THEN exit; {nur zum Schreiben geîffnete Dateien flushen!}
 IF f.bitzaehl<>8
  THEN BEGIN
        WriteBits(f,0,f.bitzaehl); {letztes Byte auffÅllen}
        inc(f.position)            {zÑhlt als ganzes Byte }
       END;
 {$I-}
 BlockWrite(f.datei,f.buf,f.bufIndex,ReallyWritten);
 {$IFDEF IOcheck} {$I+} {$ENDIF}
 f.bitzaehl:=8;
 IF IOresult=103
  THEN BEGIN
        CompressError:=CompressErr_FileNotOpen;
        f.bufIndex:=0;
        exit
       END
 ELSE IF ReallyWritten<>f.bufIndex
  THEN BEGIN
        CompressError:=CompressErr_DiskFull;
        f.bufIndex:=0;
        exit
       END
 ELSE IF IOresult<>0
  THEN BEGIN
        CompressError:=CompressErr_Unknown;
        f.bufIndex:=0;
        exit
       END;
END;

FUNCTION _FilePos(VAR f:FileOfByte):LONGINT;
{rem: Geht nur dann, wenn per _Reset() geîffnete Dateien nur per _Read()  }
{     (anstatt mit ReadBits()) gelesen werden, bzw. bei per _Rewrite() ge-}
{     îffneten Dateien nur, wenn die Daten per _Write() statt WriteBits() }
{     geschrieben werden!}
{     Ein normales Dos.FilePos() geht schief, da Dateien _geblockt_ werden!}
BEGIN
 _FilePos:=f.position
END;

PROCEDURE DelBaum(gabel:branch);
{rem: Gibt den durch den Codebaum belegten Speicher wieder frei}
BEGIN
 IF (gabel.links<>NIL) OR (gabel.rechts<>NIL)
  THEN BEGIN
        DelBaum(gabel.links^);  dispose(gabel.links);
        DelBaum(gabel.rechts^); dispose(gabel.rechts);
       END;
END;

PROCEDURE _Close(VAR f:FileOfByte);
BEGIN
 IF NOT f.lesen THEN _Flush(f);
 IF CompressError<>CompressErr_NoError THEN exit;
 {$I-}
 Close(f.datei);
 {$IFDEF IOcheck} {$I+} {$ENDIF}
 IF IOresult=103
  THEN BEGIN
        CompressError:=CompressErr_FileNotOpen;
        exit
       END
 ELSE IF IOresult<>0
  THEN BEGIN
        CompressError:=CompressErr_Unknown;
        exit
       END;
 IF f.komprimiert THEN DelBaum(f.stamm);
END;

{Zum Unterschied _logicalEOF() und _physicalEOF(): Solange eine MSDos-Datei  }
{nur eine Datei enthÑlt, sind die beiden Funktionen Ñquivalent; steht dagegen}
{in _einem_ File noch zusÑtzliche Daten (bspw. 2 komprimierte Dateien nach-  }
{einander, so wÅrde _logicalEOF() nach dem Ende der 1.Datei bereits TRUE zu- }
{rÅckliefern, hier braucht man dann _physicalEOF(), z.B. in der Art:         }
{ while not _physicalEOF(f) do   ;solange Datei nicht restlos leergemacht... }
{  BEGIN   ;...lese eine komprimierte Datei aus dem File aus:}
{   while not _logicalEOF(f) do  ;diese Schleife liest diese 1 Datei aus}
{    BEGIN                  }
{     _Read(f,b); [...]     }
{    END                    }
{   IF not _physicalEOF(f)  ;resynchronisieren, d.h.:}
{    THEN Resync(f)         ;nÑchsten Header aus MSDos-File holen}
{  END                      ;und nÑchste Datei aus File auslesen }

FUNCTION _logicalEOF(VAR f:FileOfByte):BOOLEAN;
{rem: PrÅft, ob logisches Ende der (komprimierten) Datei erreicht wurde.}
{     EnthÑlt die Datei *mehrere* Dateien, so mu· _physicalEOF() mit    }
{     herangezogen werden!}
VAR laenge:LONGINT;
BEGIN
 IF NOT f.lesen
  THEN _logicalEOF:=FilePos(f.datei)+1=FileSize(f.datei)
  ELSE BEGIN
        IF f.komprimiert
         THEN _logicalEOF:=(f.filebitpos+1>f.lenbitskom)
          {$IFDEF RLE}   AND (f.RLEcount=0)    {$ENDIF}
         ELSE _logicalEOF:=f.filebitpos+1>f.lenunkom SHL 3
       END;
 {Datei ist zuende, wenn...}
 { wir im letzten Byte sind und das letzte benutzte Bit erreicht wurde}
 { (bei nichtkomprimierten Dateien) das letzte Byte gelesen wurde}
END;


FUNCTION _physicalEOF(VAR f:FileOfByte):BOOLEAN;
{rem: PrÅft, ob Datei *physikalisch* zuende ist; eine einfache PrÅfung der }
{     Art "eof(f.datei)" ginge schief, da ja _blockweise_ gelesen wird!    }
{     Deshalb: Datei ist zuende, wenn der letzte Block gelesen wurde, die  }
{     Datei _logisch_ zuende ist und keine (Winzdatei) mehr im Puffer steht}
{     _physicalEOF:=EOF(f.datei) AND _logicalEOF(f) AND                    }
{     ( (f.bufIndex+1>=f.bufMax) OR (f.bufIndex=0) )    sollte auch gehen  }
VAR n:LONGINT;
BEGIN
 n:=FilePos(f.datei)-f.bufMax+f.BufIndex+1;
 IF f.komprimiert
  THEN _physicalEOF:=(n>=f.msdosSize) AND _logicalEOF(f)
  ELSE _physicalEOF:=(n>f.msdosSize)
END;

PROCEDURE Resync(VAR f:FileOfByte);
{rem: Die Routine dient dazu, nach dem Ende einer Datei (=Datensatzes) in }
{     einer Datei (=MSDos-File) die nÑchste Datei zum lesen vorzubereiten }
{     und entspricht einem _Reset(), mit dem Unterschied, da· eben _nicht_}
{     von dem MSDos-Anfang der Datei gelesen wird, sondern vom aktuellen  }
{     FilePos-Zeiger der offenen Datei}
VAR n:LONGINT;
BEGIN
 n:=FilePos(f.datei)-BufSize+f.bufIndex; {abs. Fileposition des akt. Bytes}
 IF f.bitzaehl<>8 THEN inc(n);
 Seek(f.datei,n);
 IF f.komprimiert THEN DelBaum(f.stamm); {alten Codebaum lîschen}
 ReadHeader(f)
END;

FUNCTION _FileSize(VAR f:FileOfByte):LONGINT;
{rem: Achtung! Dies liefert nur die Grî·e der aktuellen _logischen_ Datei;}
{     enthÑlt eine _physikalische_ Datei mehrere logische Dateien, so gibt}
{     es keine Mîglichkeit, die Gesamtgrî·e herauszubekommen!!!           }
{     N.B.: Dos.FileSize() hilft auch nicht, da dies ja die Grî·e der     }
{     *komprimierten* Datei zurÅckliefert!!}
BEGIN
 _FileSize:=f.lenunkom
END;

PROCEDURE _Write(VAR f:FileOfByte; VAR b:BYTE);
BEGIN
 WriteBits(f,b,8);
 inc(f.position)
END;

PROCEDURE _ReadByte(VAR f:FileOfByte; VAR b:BYTE);
{rem: Liest ein _logisches_ Byte aus der Datei f und legt es in "b" ab; dabei}
{     wird eine evtl. RLE-Komprimierung noch *nicht* berÅcksichtigt (Huffman-}
{     codierung aber schon)!}
VAR help:Pbranch;
    wert:BYTE;
BEGIN
 IF f.komprimiert
  THEN BEGIN
        help:=@f.stamm;
        REPEAT
         ReadBits(f,wert,1);
         IF wert=0 THEN help:=help^.links
                   ELSE help:=help^.rechts;
        UNTIL (help^.links=NIL) AND (help^.rechts=NIL);
        b:=help^.zeichen
       END
  ELSE ReadBits(f,b,8);
 inc(f.position);
END;

{$IFDEF RLE}
PROCEDURE RLEcompress(name1,name2:PathStr; VAR fin,fout:FileOfByte;
                      chatty:BOOLEAN);
{ in: name1 = Name der zu komprimierenden Datei}
{     name2 = Name der zu erzeugenden Datei}
{     chatty= TRUE fÅr: Programm ist etwas redseliger wÑhrend der Arbeit}
{out: name2 = Dateiinhalt von name1, aber komprimiert}
{     CompressError = CompressErr_Size0, falls Datei name1 LÑnge 0 hat}
{rem: Komprimiert die Datei name1 und legt das Ergebnis in Datei name2 ab.}
{     Die Datei wird "nur" Run-Length-Encoded!}
{     "fin" und "fout" werden per VAR-Åbergeben statt lokal definiert, um }
{     damit *einiges* an Stack-Speicher zu sparen: beide dÅrfen nicht be- }
{     nutzt sein, d.h. sie werden tatsÑchlich als lokaler Variablenersatz }
{     verwendet!!!}
VAR b:BYTE;
    art:BYTE;
    count:LONGINT;

 PROCEDURE dump;  {count mal art schreiben}
 VAR i:LONGINT;
     b:BYTE;
 BEGIN
  IF (art=ESC)
   THEN BEGIN {Sonderfall ESC's}
         FOR i:=1 TO (count SHR 8) DO
          BEGIN
           _Write(fout,ESC); _Write(fout,FFh); _Write(fout,ESC)
          END;

          CASE (count AND $FF) OF
           0:;
           1:BEGIN
              _Write(fout,ESC);
              b:=0; _Write(fout,b);
             END;
           2:BEGIN
              _Write(fout,ESC);
              b:=1; _Write(fout,b);
             END;
	   else BEGIN
                 _Write(fout,ESC);
                 b:=(count AND $FF)-1; _Write(fout,b);
                 _Write(fout,ESC);
                END;
          END; {of CASE}
        END
   ELSE BEGIN {normale Zeichen}
         FOR i:=1 TO (count SHR 8) DO
          BEGIN
           _Write(fout,ESC); _Write(fout,FFh); _Write(fout,art)
          END;

         IF (count AND $FF)<=3
          THEN FOR i:=1 TO count AND $FF DO _Write(fout,art) {lohnt RLE nicht}
	  ELSE BEGIN {Rest RLE codieren}
                _Write(fout,ESC);
                b:=(count AND $FF)-1; _Write(fout,b);
                _Write(fout,art);
               END;
        END;
 END;

VAR x,y:BYTE;
BEGIN {of RLEcompress}
 IF chatty THEN WRITELN('Starting RLE compression...');
 _assign(fin,name1);  _reset(fin);
 IF chatty THEN WRITELN('Size before    : ',_FileSize(fin):7);
 IF _FileSize(fin)=0
  THEN BEGIN
        {$IFDEF test} WRITELN('*** Error: file has size 0 bytes!'); {$ENDIF}
        _close(fin);
        CompressError:=CompressErr_Size0;
        exit
       END;
 _assign(fout,name2); _rewrite(fout);

 _ReadByte(fin,art); count:=1;
 WHILE NOT _physicalEOF(fin) DO
  BEGIN
   _ReadByte(fin,b);
   IF b=art
    THEN inc(count)
    ELSE BEGIN
          dump; {count mal art schreiben, aber RLE-codiert!}
          art:=b; count:=1;  {neues Zeichen Åbernehmen}
         END;

   IF chatty AND (fin.position AND 1023=0)
    THEN BEGIN
          x:=wherex; y:=wherey;
          write(fin.position:7);
          gotoxy(x,y);
         END;

  END;
 dump;  {Rest rausschreiben}

 _Close(fin); _Close(fout);

 _assign(fout,name2); _reset(fout);
 IF chatty THEN WRITELN('Size afterwards: ',_FileSize(fout):7);
 _close(fout)
END;
{$ENDIF}

{$IFDEF RLE}
PROCEDURE _Read(VAR f:FileOfByte; VAR b:BYTE);
{rem: Diese Prozedur dient als "BlackBox" zum Benutzer: sie entspricht dem   }
{     Aufruf Dos.Read(f,b), berÅcksichtigt aber RLE und Huffmankomprimierung!}
BEGIN
 IF NOT f.komprimiert
  THEN BEGIN
        ReadBits(f,b,8);
        inc(f.position)
       END
  ELSE BEGIN {komprimierte Datei lesen}
        IF f.RLEcount>0
	 THEN BEGIN {noch alte RLE-Daten}
               b:=f.RLEchar; dec(f.RLEcount)
              END
	 ELSE BEGIN {neues Datum aus Datei benîtigt}
               _ReadByte(f,b); {erhîht f.position um 1!}
               IF b=ESC
		THEN BEGIN {RLE-Datensequenz kommt!}
                      _ReadByte(f,b);      {erhîht f.position um 1!}
                      dec(f.position); {gleich rÅckgÑngig machen!}
                      CASE b OF
                       0: b:=ESC;  {1x ESC, gleich zurÅckgeben, kein RLE}
		       1: BEGIN {2x ESC, 1 zurÅckgeben, 1 behalten}
                           b:=ESC;
                           f.RLEcount:=1;
                           f.RLEchar :=ESC
                          END;
		       else BEGIN {andere Sequenz, 3.Byte benîtigt}
                             f.RLEcount:=b;
                             _ReadByte(f,b);  {auch gleich zurÅckgeben}
                             dec(f.position); {f.position korrigieren}
                             f.RLEchar :=b
                            END;
                      END; {of CASE}
                     END;
              END;
       END;
END;
{$ELSE}
PROCEDURE _Read(VAR f:FileOfByte; VAR b:BYTE);
BEGIN
 _ReadByte(f,b)
END;
{$ENDIF}

PROCEDURE _BlockRead(VAR f:FileOfByte; var buf; count: Word);
{rem: Liest count Bytes aus der Datei f an die Stelle, auf die buf zeigt.}
{     Funktioniert analog zu Dos.BlockRead(f,buf,count) mit dem Unter-   }
{     schied, da· Huffman- und RLE-Codierung berÅcksichtigt werden.      }
VAR s,o,i:WORD;
    b:BYTE;
BEGIN
 s:=SEG(buf) +(OFS(buf) SHR 4);
 o:=OFS(buf) AND $F;

 FOR i:=0 TO count-1 DO
  BEGIN
   _Read(f,b);
   MEM[s:o]:=b;
   inc(o);
   IF o=65520 THEN BEGIN inc(s,65520 DIV 16); o:=0 END;  {öberlauf vermeiden}
  END;
END;

PROCEDURE __BlockRead(VAR f:FileOfByte; var buf; count: Word; VAR result:WORD);
{rem: Liest count Bytes aus der Datei f an die Stelle, auf die buf zeigt  }
{     und gibt in result zurÅck, wieviele Bytes tatsÑchlich gelesen wurden}
{     Funktioniert analog zu Dos.BlockRead(f,buf,count,result) mit dem    }
{     Unterschied, da· Huffman- und RLE-Codierung berÅcksichtigt werden.  }
VAR s,o,i:WORD;
    b:BYTE;
BEGIN
 s:=SEG(buf) +(OFS(buf) SHR 4);
 o:=OFS(buf) AND $F;

 result:=f.lenunkom-f.position; {max. #Bytes, die gelesen werden kînnen}
 IF count>result
  THEN count :=result
  ELSE result:=count;
 FOR i:=0 TO count-1 DO
  BEGIN
   _Read(f,b);
   MEM[s:o]:=b;
   inc(o);
   IF o=65520 THEN BEGIN inc(s,65520 DIV 16); o:=0 END;  {öberlauf vermeiden}
  END;
END;

PROCEDURE _BlockWrite(VAR f:FileOfByte; var buf; count: Word);
{rem: Schreibt count Bytes von der Stelle, auf die buf zeigt, nach f.    }
{     Funktioniert analog zu Dos.BlockWrite(f,buf,count) mit dem Unter-  }
{     schied, da· prinzipiell geblockt wird!                             }
VAR s,o,i:WORD;
BEGIN
 s:=SEG(buf) +(OFS(buf) SHR 4);
 o:=OFS(buf) AND $F;
 FOR i:=0 TO count-1 DO
  BEGIN
   _Write(f,MEM[s:o]);
   inc(o);
   IF o=65520 THEN BEGIN inc(s,65520 DIV 16); o:=0 END;  {öberlauf vermeiden}
  END;
END;

PROCEDURE __BlockWrite(VAR f:FileOfByte; var buf; count: Word; VAR result:WORD);
{rem: Schreibt count Bytes von der Stelle, auf die buf zeigt, nach f und }
{     gibt in result zurÅck, wieviel Bytes tatsÑchlich geschrieben wurden}
{     Funktioniert analog zu Dos.BlockWrite(f,buf,count,result) mit dem  }
{     Unterschied, da· prinzipiell geblockt wird!                        }
VAR s,o,i:WORD;
BEGIN
 s:=SEG(buf) +(OFS(buf) SHR 4);
 o:=OFS(buf) AND $F;

 FOR i:=0 TO count-1 DO
  BEGIN
   {$I-}
   _Write(f,MEM[s:o]);
   IF IOresult<>0 THEN BEGIN result:=i; exit END;
   inc(o);
   IF o=65520 THEN BEGIN inc(s,65520 DIV 16); o:=0 END;  {öberlauf vermeiden}
  END;
 result:=count;
END;

PROCEDURE compress(name1,name2:PathStr; chatty:BOOLEAN);
{ in: name1 = Name der zu komprimierenden Datei}
{     name2 = Name der zu erzeugenden Datei}
{     chatty= TRUE fÅr: Programm ist etwas redseliger wÑhrend der Arbeit}
{out: name2 = Dateiinhalt von name1, aber komprimiert}
{     CompressError = CompressErr_AlreadyCompressed, wenn Datei bereits   }
{     komprimiert ist, oder CompressErr_Size0, falls Datei leer ist, oder }
{     einer der von anderen Routinen durchgereichten Fehler}
{rem: Komprimiert die Datei name1 und legt das Ergebnis in Datei name2 ab.}
{     Die Datei wird Huffman (und RLE) codiert.}
{     Zur RLE-Komprimierung wird eine temporÑre Datei unter dem Namen, der}
{     in "TemporaryName" steht angelegt -im aktuellen Verzeichnis bzw. im }
{     Verzeichnis das durch die Environmentvariable "TEMP" oder "TMP" an- }
{     gegeben ist.}
VAR anzahl:ARRAY[0..255] OF LONGINT;
    wert,i,j:BYTE;
    m:INTEGER;
    ungleich0,ReallyWritten:WORD;
    von,nach:FileOfByte;
    cast:RECORD {Header: LÑngenbytes (un)komprimiert}
          unkom,kom:LONGINT;
         END;
    start:code;
    orgLen,k:LONGINT;
{$IFDEF RLE}
    tempName:PathStr;
{$ENDIF}
     

   PROCEDURE BuildTree;
   {rem: Erzeugt gemÑ· den in "anzahl[]" stehenden AuftrittshÑufigkeiten der }
   {     Zeichen den Huffmanbaum und schreibt dessen Wurzel nach "nach.stamm"}
   VAR help:branch;
       i,min1,min2,gzeichen:BYTE;
       tree:ARRAY[0..255] OF Pbranch;

     PROCEDURE findmin(VAR m1,m2:BYTE);
     {rem: Findet die 2 Zeichen mit der kleinsten (und zweitkleinsten) Auf-  }
     {     trittswahrscheinlichkeit}
     VAR anz1,anz2:LONGINT;
         i:BYTE;
     BEGIN
      anz1:=MaxLongint;
      anz2:=MaxLongint;
      FOR i:=0 TO 255 DO
       IF tree[i]<>NIL
        THEN BEGIN
              IF anz1>=anzahl[i]
	       THEN BEGIN
                     anz2:=anz1; anz1:=anzahl[i]; m2:=m1; m1:=i
                    END
	       ELSE BEGIN
                     IF anz2>=anzahl[i] THEN BEGIN anz2:=anzahl[i]; m2:=i END
                    END;
             END;
     END;

   BEGIN {of BuildTree}
    gzeichen:=255;
    FOR i:=0 TO 255 DO
     IF anzahl[i]=0
      THEN BEGIN
            tree[i]:=NIL; dec(gzeichen)
           END
      ELSE BEGIN
            new(tree[i]);
            tree[i]^.zeichen:=i;
            tree[i]^.links:=NIL;
            tree[i]^.rechts:=NIL
           END;
    FOR i:=1 TO gzeichen DO
     BEGIN
      findmin(min1,min2);
      help.zeichen:=min1;
      help.links:=tree[min1];
      help.rechts:=tree[min2];
      new(tree[min1]);
      tree[min1]^:=help;
      anzahl[min1]:=anzahl[min1]+anzahl[min2];
      tree[min2]:=NIL
     END;
    i:=0;
    WHILE tree[i]=NIL DO INC(i);
    nach.stamm:=tree[i]^;
   END;

   PROCEDURE BuildLookupTable(gabel:branch; startwert:code);
   {rem: Erzeugt aus dem Huffmancodebaum eine Lookup-Tabelle fÅr eine      }
   {     schnellere Codierung; Ergebnis steht danach in nach.codes[]:      }
   {     nach.codes[i].bitcount enthÑlt die LÑnge (in Bits) von Zeichen i, }
   {     nach.codes[i].itself[] enthÑlt den Bitcode von Zeichen i (gepackt)}
   BEGIN
    IF (gabel.links=NIL) AND (gabel.rechts=NIL)
     THEN nach.codes[gabel.zeichen]:=startwert
     ELSE BEGIN
           startwert.itself[startwert.bitcount SHR 3]:=startwert.itself[startwert.bitcount SHR 3]
            AND ANDMask[startwert.bitcount AND 7];  {Bit lîschen}
           inc(startwert.bitcount);
           BuildLookupTable(gabel.links^,startwert);
           dispose(gabel.links);
           dec(startwert.bitcount);

           startwert.itself[startwert.bitcount SHR 3]:=startwert.itself[startwert.bitcount SHR 3]
            OR ORMask[startwert.bitcount AND 7]; {Bit setzen}
           inc(startwert.bitcount);
           BuildLookupTable(gabel.rechts^,startwert);
           dispose(gabel.rechts);
          END;
   END;

VAR oldx,oldy:BYTE;
BEGIN {of compress}
 _assign(von,name1);
 _reset(von);
 IF CompressError<>CompressErr_NoError THEN exit;
 orgLen:=_FileSize(von);
 _close(von);
 IF CompressError<>CompressErr_NoError THEN exit;

 IF von.komprimiert
  THEN BEGIN
        {$IFDEF test} WRITELN('*** Error: file already kompressed!'); {$ENDIF}
        CompressError:=CompressErr_AlreadyCompressed;
        exit
       END;
 IF orgLen=0
  THEN BEGIN
        {$IFDEF test} WRITELN('*** Error: file has length 0!'); {$ENDIF}
        CompressError:=CompressErr_Size0;
        exit
       END;

 {$IFDEF RLE}
 tempName:=GetEnv('TEMP');
 IF tempName='' THEN tempName:=GetEnv('TMP');
 IF Length(tempName)>0
  THEN IF tempName[Length(tempName)]<>'\' THEN tempName:=tempName+'\';
 tempName:=tempName+TemporaryFile;
 RLEcompress(name1,tempName,von,nach,chatty); {"von","nach" sind beide frei!}
 IF CompressError<>CompressErr_NoError
  THEN BEGIN {hier wird die temporÑre Datei gelîscht, die noch in "nach" steht}
        {$IFDEF RLE} close(nach.datei); erase(nach.datei); {$ENDIF}
        exit;
       END;
 {$IFDEF test} WRITELN('RLE-Codierung durchgefÅhrt...'); {$ENDIF}
 name1:=tempName;
 {$ENDIF}

 IF chatty
  THEN BEGIN
        WRITELN('Starting Huffman compression...');
        WRITELN('Size before    : ',nach.lenunkom:7);
       END;

 _assign(von,name1);
 _reset(von);
 IF CompressError<>CompressErr_NoError
  THEN BEGIN
        _close(von);
        exit;
       END;
 FillChar(anzahl,SizeOf(anzahl),0);
 FOR k:=1 TO _FileSize(von) DO
  BEGIN
   _Read(von,wert);
   inc(anzahl[wert])
  END;
 _close(von);

 _assign(von,name1);  _reset(von);
 IF CompressError<>CompressErr_NoError
  THEN BEGIN
        _close(von);
        exit;
       END;
 _assign(nach,name2); _rewrite(nach);
 IF CompressError<>CompressErr_NoError
  THEN BEGIN
        _close(von); _close(nach);
        exit;
       END;

 {Wenn die Datei aus nur einem Zeichen besteht (z.B.: "aaaaa"), dann wÑre}
 {der Huffman-Baum "degeneriert", er hÑtte die Hîhe 0 und seine Codes    }
 {entsprechend die LÑnge 0! Um dies zu verhindern wird in diesem Fall    }
 {einfach das Auftreten eines willkÅrlichen zweiten Zeichens simuliert.  }
 ungleich0:=0;
 FOR i:=0 TO 255 DO IF anzahl[i]<>0 THEN inc(ungleich0);
 IF ungleich0=1  {besteht gesamte Datei aus demselben Zeichen?}
  THEN BEGIN {ja, kÅnstlich das Auftreten eines 2.Zeichens simulieren}
        IF anzahl[0]=0 THEN inc(anzahl[0])
        ELSE inc(anzahl[1])
       END;

 {$IFDEF test} WRITELN('HÑufigkeiten ermittelt...'); {$ENDIF}
 BuildTree;
 {$IFDEF test} WRITELN('Codes generiert...'); {$ENDIF}
 FillChar(start,SizeOf(start),0);
 FOR j:=0 TO 255 DO nach.codes[j]:=start;
 BuildLookupTable(nach.stamm,start);
 {$IFDEF test} WRITELN('Lookuptable generiert...'); {$ENDIF}

 nach.lenunkom:=orgLen;  {unkomprimierte LÑnge Åbernehmen}
 FOR i:=1 TO SizeOf(Header) DO
  WriteBits(nach,Kennung[i],8);
 FOR i:=1 TO SizeOf(LONGINT)+SizeOf(LONGINT) DO
  WriteBits(nach,0,8); {Platz lassen fÅr LÑngeninfos}
 j:=255; WHILE anzahl[j]=0 DO dec(j);
 FOR i:=0 TO j DO
  BEGIN
   FOR m:=0 TO nach.codes[i].bitcount-1 DO
    WriteBits(nach,(nach.codes[i].itself[m SHR 3] SHR (m AND 7)) AND 1,2);
   WriteBits(nach,2,2)  {2=EndOfOneCode}
  END;
 IF j<>255
  THEN WriteBits(nach,3,2); {3=EndOfAllCodes: AbkÅrzen, falls mîglich}

 WHILE NOT _physicalEOF(von) DO
  BEGIN
   _ReadByte(von,wert);
   FOR i:=0 TO nach.codes[wert].bitcount-1 DO
    WriteBits(nach,(nach.codes[wert].itself[i SHR 3] SHR (i AND 7)) AND 1,1);
   inc(nach.position);

   IF chatty AND (nach.position AND 1023=0)
    THEN BEGIN
          oldx:=wherex; oldy:=wherey;
          write(von.position:7,' -> ',nach.lenbitskom SHR 3:7);
          gotoxy(oldx,oldy);
         END;
  END;

 IF CompressError<>CompressErr_NoError
  THEN BEGIN {wahrscheinlich ist die Platte voll?}
        _Close(von); Close(nach.datei);
        exit;
       END;

 {Jetzt ein "Flush" nachbilden, aber exakte Grî·e merken}
 cast.kom :=nach.lenbitskom;
 IF nach.bitzaehl<>8
  THEN BEGIN
        WriteBits(nach,0,nach.bitzaehl); {letztes Byte auffÅllen}
        inc(nach.position)
       END;
 {$I-}
 BlockWrite(nach.datei,nach.buf,nach.bufIndex,ReallyWritten);
 {$IFDEF IOcheck} {$I+} {$ENDIF}
 IF IOresult=103
  THEN BEGIN
        CompressError:=CompressErr_FileNotOpen;
        nach.bufIndex:=0; nach.bitzaehl:=8; {nur der Optik halber...}
        exit
       END
 ELSE IF ReallyWritten<>nach.bufIndex
  THEN BEGIN
        CompressError:=CompressErr_DiskFull;
        nach.bufIndex:=0; nach.bitzaehl:=8; {nur der Optik halber...}
        exit
       END
 ELSE IF IOresult<>0
  THEN BEGIN
        CompressError:=CompressErr_Unknown;
        nach.bufIndex:=0; nach.bitzaehl:=8; {nur der Optik halber...}
        exit
       END;

 Seek(nach.datei,SizeOf(Header)); {jetzt LÑngenbytes eintragen}
 cast.unkom:=nach.lenunkom;
 BlockWrite(nach.datei,cast,SizeOf(cast));

 _Close(von);
 IF chatty THEN WRITELN('Size afterwards: ',nach.lenbitskom SHR 3:7);
 Close(nach.datei); {kein _Close(), um erneutes Flush zu vermeiden!}
 {$IFDEF RLE} erase(von.datei); {$ENDIF}
END;

PROCEDURE decompress(name1,name2:PathStr; chatty:BOOLEAN);
{ in: name1 = Name des zu dekomprimierenden Files}
{     name2 = Name fÅr dekomprimiertes ergebnis  }
{     chatty= TRUE fÅr: Programm ist etwas redseliger wÑhrend der Arbeit}
{out: Datei name2 wurde erzeugt}
{rem: Dekomprimiert die Datei name1 und schreibt das Ergebnis nach name2.}
{     EnthÑlt die Datei mehr als ein logisches File, so werden alle (bis }
{     zum physikalischen Ende der Datei) dekomprimiert; dies setzt aber  }
{     voraus, da· alle logischen Dateien in der physikalischen Datei kom-}
{     primiert sind, denn sonst kann die Prozedur ja nicht feststellen,  }
{     wann eine logische Datei zuende ist.}
{     name1 und name2 mÅssen zwei verschiedene Dateien bezeichnen!}
LABEL break;
VAR wert:BYTE;
    von,nach:FileOfByte;
    oldx,oldy:BYTE;
BEGIN
 IF chatty THEN WRITELN('Starting decompression...');
 _assign(von,name1);  _reset(von);
 IF CompressError<>CompressErr_NoError
  THEN BEGIN
        _close(von); {trotzdem versuchen, die Datei zu schlie·en}
        exit
       END;
 _assign(nach,name2); _rewrite(nach);
 IF CompressError<>CompressErr_NoError
  THEN BEGIN
        _close(von); {trotzdem versuchen, die Datei zu schlie·en}
        exit
       END;

 WHILE NOT _physicalEOF(von) DO    {Ist als Ersatz zu verstehen fÅr:}
  BEGIN                            {while not _eof(von) do          }
   WHILE NOT _logicalEOF(von) DO   { begin                          }
    BEGIN                          {  _Read(von,wert);              }
     _Read(von,wert);              {  _write(nach,wert)             }
     _Write(nach,wert);            { end;                           }
     IF chatty AND (von.position AND 1023=0)
      THEN BEGIN
            oldx:=wherex; oldy:=wherey;
            write(von.position:7,' -> ',nach.position:7);
            gotoxy(oldx,oldy);
           END;
    END;                           {Linksstehende Sequenz kommt auch}
   IF not _physicalEOF(von)        {mit mehreren Dateien in einem   }
    THEN Resync(von)               {File zurecht!}
  END;
 _Close(von); _Close(nach);
 IF chatty THEN ClrEol;
END;

{$IFDEF test}
BEGIN
 IF ParamCount=3 THEN BEGIN s:=ParamStr(3); ch:=UpCase(s[1]) END;
 IF (ParamCount<>3) OR (NOT (ch IN ['C','K','D']))
  THEN BEGIN
        WRITELN('***Error! Syntax: ',ParamStr(0)+' oldFile newFile {d|k}');
        Halt
       END;

 datei1:=ParamStr(1);
 datei2:=ParamStr(2);
 IF (upcase(ch)='K') OR (upcase(ch)='C')
  THEN BEGIN
        compress(datei1,datei2,TRUE);
        WRITELN('Code auf Disk geschrieben...');

        _assign(temp,datei2); _reset(temp);
        vorher:=_FileSize(temp);
        nachher:=temp.lenbitskom;
        gesamt:=FileSize(temp.datei);
        _close(temp);

        WRITELN('vorher: ',vorher:5,'[Bytes];  nachher: ',nachher:5,
                '[Bits];  nachher+Header: ',gesamt:5,'[Bytes]');
       END
  ELSE BEGIN
        decompress(datei1,datei2,TRUE);
        WRITELN('Dekompression durchgefÅhrt...');
       END;
{$ENDIF}
END.

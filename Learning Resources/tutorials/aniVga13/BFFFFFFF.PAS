{$UNDEF test}

{$IFDEF test}
 {$A+,B-,D+,E-,F-,G-,I+,L+,N-,O-,R+,S+,V+,X-}
 {$M 16384,65536,655360}
{$ELSE}
 {$A+,B-,D+,E-,F-,G-,I-,L+,N-,O-,R-,S-,V-,X-}
 {$M 16384,65536,655360}
{$ENDIF}

PROGRAM CompressionTest;
{Zweck    : Programm zum komprimieren und dekomprimieren von Dateien}
{Autor    : Kai Rohrbacher    }
{Sprache  : TurboPascal 6.0   }
{Datum    : 21.10.1992        }
{Anmerkung: Beim Auftreten eines Fehlers wird dieser nicht weiter analysiert,}
{           was jedoch Åber den Wert von CompressError mîglich wÑre.}
USES compression,Dos;
VAR s:STRING;
    ch:CHAR;
    fin,fout:STRING;
    temp:FileOfByte;
    before,total:LONGINT;
BEGIN
 IF ParamCount=3 THEN BEGIN s:=ParamStr(3); ch:=UpCase(s[1]) END;
 IF (ParamCount<>3) OR (NOT (ch IN ['C','K','D']))
  THEN BEGIN
        WRITELN('***Error! Syntax: ',ParamStr(0)+' oldFile newFile {c|d}');
        Halt
       END;

 fin:=FExpand(ParamStr(1));
 fout:=FExpand(ParamStr(2));
 IF fin=fout 
  THEN BEGIN
        WRITELN('***Sorry, source and destination files must be different!');
        Halt
       END;
 IF (upcase(ch)='C') OR (upcase(ch)='K')
  THEN BEGIN
        WRITELN('Just a moment, I''ll compress file '+fin+' to file '+fout);
        compress(fin,fout,TRUE);
        IF CompressError<>CompressErr_NoError
         THEN BEGIN
               WRITELN('***Sorry, an error occured!');
               Halt
              END;
        WRITELN('Done!');

        _assign(temp,fout); _reset(temp);
        before:=_FileSize(temp);
        total:=FileSize(temp.datei);
        _close(temp);

        WRITELN('File compressed to ',total/before*100:5:2,
                '% of its original size.');
       END
  ELSE BEGIN
        WRITELN('Just a moment, I''ll decompress file '+fin+' to file '+fout);
        decompress(fin,fout,TRUE);
        IF CompressError<>CompressErr_NoError
         THEN BEGIN
               WRITELN('***Sorry, an error occured!');
               Halt
              END;
        WRITELN('Done!');
       END;
END.

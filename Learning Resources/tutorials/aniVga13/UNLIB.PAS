{$X+}
PROGRAM Split_Sprite_LIB_Files;
USES DOS,Compression;

CONST {Fehlercodes des Animationspaketes: }
      Err_None=0;
      Err_NotEnoughMemory=1;
      Err_FileIO=2;
      Err_NoSprite=4;
      Err_DiskFull=7;

CONST dest:STRING[12]='UNLIB000.COD';

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

VAR Error : BYTE; {globale Fehlervariable}

FUNCTION GetErrorMessage:STRING;
{ in: Error = Nummer des aufgetretenen Fehlers}
{out: den Fehler in Worten}
BEGIN
 CASE Error OF
  Err_None:GetErrorMessage:='No Error';
  Err_NotEnoughMemory:GetErrorMessage:='Not enough memory available on heap';
  Err_FileIO:GetErrorMessage:='I/O-error with file';
  Err_NoSprite:GetErrorMessage:='No (or corrupted) Sprite file';
  Err_DiskFull:GetErrorMessage:='Fileerror: Disk full';
 END;
END;


FUNCTION SplitSprites(Name:String):WORD;
{ in: Name   = Name des zu ladenden Sprite-Files (Typ: "*.COD" / "*.LIB" )}
{     Number = Nummer, die das erste Sprite aus diesem File bekommen soll }
{     dest   = Name, unter dem das erste Sprite abgelegt wird, i.d.R.     }
{              "UNLIB000.COD"                                             }
{out: Anzahl der aus dem File gelesenen Sprites (0 = Fehler trat auf)     }
{     UNLIB000.COD, UNLIB001.COD,... = ausgelesene Sprites                }
{rem: Die Routine erkennt automatisch, ob es sich bei dem File um ein ein-}
{     zelnes Sprite oder eine ganze Spritebibliothek handelt und laedt    }
{     alle Spritedaten auf den Heap, und zwar derart, dass die Adresse    }
{     immer auf eine Segmentgrenze fÑllt. Diese Anfangsadressen werden    }
{     dann in der Tabelle SPRITEAD[Number] abgelegt; sind mehrere Sprites }
{     in der Datei so werden sie mit fortlaufender Nummer eingetragen,    }
{     also Number+i }

   FUNCTION Update(VAR ch:CHAR):BOOLEAN;
   { in: ch = Ziffer als Zeichen   : '0'..'9'}
   {out: ch = um 1 erhîhtes Zeichen: '1'..'0'}
   {     TRUE/FALSE, falls öbertrag in nÑchsthîhere Stelle}
   BEGIN
    IF ch='9'
     THEN ch:='0'
     ELSE ch:=chr(succ(ord(ch)));
    Update:=ch='0'
   END;

LABEL quit_loop;
TYPE SpriteBuffer=ARRAY[0..65534] OF BYTE;
VAR Buffer: ^SpriteBuffer;
    f:FileOfByte;
    f2:File;
    count,BytesWritten,Kopf:WORD;
    Header:SpriteHeader;
BEGIN
 NEW(Buffer);
 count:=0;  {Zahl der bisher eingelesenen Sprites}
 Kopf:=SizeOf(SpriteHeader);
 _assign(f,name);
 {$I-} _reset(f); {$I+}
 if (ioresult<>0) OR (CompressError<>CompressErr_NoError)
  THEN BEGIN  {Datei existiert nicht oder nicht unter diesem Pfad}
        Error:=Err_FileIO;
        SplitSprites:=0; exit
       END;

 WHILE NOT _physicalEOF(f) DO
 BEGIN
  WRITELN('...working on sprite '+dest);

  {Zunaechst den Spriteheader einlesen: }
  {$I-}     {jetzt den Spriteheader viÖ BLOCKREAD auf den Heap laden}
  _blockread(f,Header,Kopf);
  {$I+}

  IF (ioresult<>0) OR (CompressError<>CompressErr_NoError)
   THEN BEGIN
         Error:=Err_FileIO;
         goto quit_loop;
        END;
  IF (Header.Kennung[1]<>'K') or (Header.Kennung[2]<>'R')
   THEN BEGIN
         Error:=Err_NoSprite;
         goto quit_loop;
        END;
  IF (Header.SpriteLength>MaxAvail+15)    {noch genug Platz da?}
   THEN BEGIN
         Error:=Err_NotEnoughMemory;
         goto quit_loop;
        END;

  MOVE(Header,Buffer^[0],Kopf);
  {Jetzt eigentliche Spritedaten einlesen: }
  {$I-}
  _blockread(f,Buffer^[Kopf],Header.SpriteLength-Kopf);
  {$I+}
  IF (ioresult<>0) OR (CompressError<>CompressErr_NoError)
   THEN BEGIN
         Error:=Err_FileIO;
         goto quit_loop
        END;

  {$I-}     {jetzt das Sprite auf Disk schreiben}
  assign(f2,dest);
  Rewrite(f2,1);
  {$I+}
  IF (ioresult<>0)
   THEN BEGIN
         Error:=Err_FileIO;
         goto quit_loop
        END;
  {$I-}
  blockwrite(f2,Buffer^[0],Header.SpriteLength,BytesWritten);
  {$I+}
  IF Header.SpriteLength<>BytesWritten
   THEN BEGIN
         Error:=Err_DiskFull;
         goto quit_loop
        END;
  IF (ioresult<>0)
   THEN BEGIN
         Error:=Err_FileIO;
         goto quit_loop
        END;
  {$I-}
  close(f2);
  {$I+}
  IF (ioresult<>0)
   THEN BEGIN
         Error:=Err_FileIO;
         goto quit_loop
        END;

  INC(count);
  IF Update(dest[8])  {Filenamen fÅr nÑchsten Aufruf generieren}
   THEN IF Update(dest[7])
         THEN Update(dest[6]);

  IF (NOT _physicalEOF(f))
   THEN BEGIN
         IF f.komprimiert AND (NOT _logicalEOF(f))
	  THEN BEGIN
                {nichts zu tun, da Library insgesamt komprimiert}
               END
          ELSE Resync(f); {am Ende einer logischen Datei}
        END;
 END;

 WRITELN('Done, extracted ',count,' sprites');

quit_loop: ;
 _close(f);
 SplitSprites:=count
END;


BEGIN
 WRITELN;
 WRITELN('UNLIB V1.1  -- Splits a spritelibrary into its *.COD-files');
 WRITELN(' by Kai Rohrbacher, 1991');
 WRITELN;
 IF ParamCount<>1
  THEN BEGIN
        WRITELN('*** Wrong parameters!');
        WRITELN('Call UNLIB with the name of your spritelibrary to split, e.g.:');
        WRITELN;
        WRITELN('  UNLIB c:\sprites\my_files.LIB');
        WRITELN;
        WRITELN('UNLIB will create the *.COD-files in the current directory,');
        WRITELN('starting with the name '+dest+' and using increasing numbers.');
        Halt(1);
       END;
 Error:=Err_None;
 IF SplitSprites(ParamStr(1))=0
  THEN BEGIN
        WRITELN('*** Error: '+GetErrorMessage);
       END;
END.
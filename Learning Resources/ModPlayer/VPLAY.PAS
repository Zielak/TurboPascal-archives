
 Uses VOCs, XMSDrv, Crt;

 Var
  Test1, Test2: VOCDataRec;

 Begin
  If StatusWord = $8000 Then Halt(1);

  WriteLn;
  WriteLn('Demonstration for VOCS.TPU');
  WriteLn;

  If (MemAvail < 114000) OR (XMSAddr = NIL) OR (EMBAvail < 246) Then
  Begin
   WriteLn('Not enough memory.');
   WriteLn('Needed: 114 kB base mem, 246 kB XMS');
   WriteLn;
   Halt(1);
  End;

  WriteLn('Memory data: base -> ', MemAvail, ' Bytes, XMS -> ', EMBAvail, ' kB.');
  WriteLn;

  Write('Loading TEST1.VOC: ');
  If LoadVOC('TEST1.VOC', 0, RAM, Test1) <> 0 Then
  Begin
   WriteLn('Failed!');
   Halt(1);
  End;
  WriteLn('Done!');

  Write('Loading TEST2.VOC: ');
  If LoadVOC('TEST2 .VOC', 47724, XMS, Test2) <> 0 Then
  Begin
   WriteLn('Failed!');
   FreeVOC(Test1);
   Halt(1);
  End;
  WriteLn('Done!');

  WriteLn;
  Write('Playing TEST1.VOC from base mem...');

  Speaker(ON);

  PlayVOC(Test1);
  Repeat Until StatusWord = 0;
  WriteLn('Done!');

  Write('Playing TEST2.VOC from XMS...');
  PlayVOC(Test2);

  Delay(5000);

  BreakVOC;
  Write('Ooops, a little break. Press a key...');
  ReadKey;
  ContiVOC;

  Repeat Until StatusWord = 0;
  WriteLn('Done!');
  WriteLn;

  Speaker(OFF);
  ResetDrv;

  FreeVOC(Test1); FreeVOC(Test2);

  WriteLn('Memory data: base -> ', MemAvail, ' Bytes, XMS -> ', EMBAvail, ' kB.');
  WriteLn;
 End.

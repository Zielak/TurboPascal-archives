Unit Roller;
{$G+}

Interface

Procedure ScrollLeft (X, Y, L, H : Word);
{ Сдвигает изображение в прямоугольнике влево на точку циклически; а/с }

Procedure ScrollRight (X, Y, L, H : Word);
{ Сдвигает изображение в прямоугольнике вправо на точку циклически; а/с }

Procedure ScrollUp (X, Y, L, H : Word);
{ Сдвигает изображение в прямоугольнике вверх на точку циклически; а/с }

Procedure ScrollDown (X, Y, L, H : Word);
{ Сдвигает изображение в прямоугольнике вниз на точку циклически; а/с }

        (* -------------------------------------------------------- *)

Procedure ScrollLeft2 (X, Y, L, H : Word);
{ Сдвигает изображение в прямоугольнике влево на 2 точки циклически; а/с }

Procedure ScrollRight2 (X, Y, L, H : Word);
{ Сдвигает изображение в прямоугольнике вправо на 2 точки циклически; а/с }

Procedure ScrollUp2 (X, Y, L, H : Word);
{ Сдвигает изображение в прямоугольнике вверх на 2 точки циклически; а/с }

Procedure ScrollDown2 (X, Y, L, H : Word);
{ Сдвигает изображение в прямоугольнике вниз на 2 точки циклически; а/с }

        (* -------------------------------------------------------- *)

Procedure RollLeft (X, Y, L, H : Word; C : Byte);
{ Сдвигает изображение в прямоугольнике влево на точку,
  освобождающиеся точки закрашиваются цветом C; а/с }

Procedure RollRight (X, Y, L, H : Word; C : Byte);
{ Сдвигает изображение в прямоугольнике вправо на точку,
  освобождающиеся точки закрашиваются цветом C; а/с }

Procedure RollUp (X, Y, L, H : Word; C : Byte);
{ Сдвигает изображение в прямоугольнике вверх на точку,
  освобождающиеся точки закрашиваются цветом C; а/с }

Procedure RollDown (X, Y, L, H : Word; C : Byte);
{ Сдвигает изображение в прямоугольнике вниз на точку,
  освобождающиеся точки закрашиваются цветом C; а/с }

        (* -------------------------------------------------------- *)

Procedure RollLeft2 (X, Y, L, H : Word; C : Byte);
{ Сдвигает изображение в прямоугольнике влево на 2 точки,
  освобождающиеся точки закрашиваются цветом C; а/с }

Procedure RollRight2 (X, Y, L, H : Word; C : Byte);
{ Сдвигает изображение в прямоугольнике вправо на 2 точки,
  освобождающиеся точки закрашиваются цветом C; а/с }

Procedure RollUp2 (X, Y, L, H : Word; C : Byte);
{ Сдвигает изображение в прямоугольнике вверх на 2 точки,
  освобождающиеся точки закрашиваются цветом C; а/с }

Procedure RollDown2 (X, Y, L, H : Word; C : Byte);
{ Сдвигает изображение в прямоугольнике вниз на 2 точки,
  освобождающиеся точки закрашиваются цветом C; а/с }

Implementation

Uses Grafix;

Procedure ScrollLeft (X, Y, L, H : Word); Assembler;
Asm
  Push  DS
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Mov   BX, Y
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Screen start addr }
  Mov   AX, DS
  Mov   ES, AX
  Mov   DI, SI                                  { ES:DI = DS:SI }
  CLD
  Mov   BX, H
@cyc:
  Push  DI
  Mov   AL, DS:[SI]                             { Save left pixel to AL }
  Inc   SI                                      { Starting from 2-nd pixel }
  Mov   CX, L
  Dec   CX                                      { L-1 pixel to copy }
  ShR   CX, 1
  JNC   @1
  MovSB
@1:
  Rep   MovSW
  STOSB
  Pop   DI
  Add   DI, 320
  Mov   SI, DI
  Dec   BX
  JNZ   @cyc
  Pop   DS
End;

Procedure ScrollRight (X, Y, L, H : Word); Assembler;
Asm
  Push  DS
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Add   SI, L
  Dec   SI
  Mov   BX, Y
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Screen "start" addr }
  Mov   AX, DS
  Mov   ES, AX
  Mov   DI, SI                                  { ES:DI = DS:SI }
  STD
  Mov   BX, H
@cyc:
  Push  DI
  Mov   AL, ES:[DI]                             { Save right pixel to AL }
  Dec   DI
  Dec   SI
  Dec   SI                                      { Starting from 2-nd pixel }
  Mov   CX, L
  Dec   CX                                      { L-1 pixel to copy }
  ShR   CX, 1
  Rep   MovSW
  Inc   DI
  JNC   @1                                      { If L-1 is NOT ODD }
  Inc   SI
  MovSB
@1:
  STOSB
  Pop   DI
  Add   DI, 320
  Mov   SI, DI
  Dec   BX
  JNZ   @cyc
  Pop   DS
End;

Procedure ScrollUp (X, Y, L, H : Word); Assembler;
Asm
  Push  DS
  Mov   AX, DS
  Mov   ES, AX
  Mov   DI, Offset _Poly                        { ES:DI - Buf Address }
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Mov   BX, Y
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Screen start addr }
  Mov   DX, L                                   { DX = L }
  CLD
  Push  SI
  Mov   CX, DX
  Shr   CX, 1
  Inc   CX
  Rep   MovSW                                   { Top line saved in the Buf }
  Pop   SI
  Mov   DI, SI
  Add   SI, 320                                 { DS:SI - source }
  Mov   AX, DS
  Mov   ES, AX                                  { ES:DI - destination }
  Mov   BX, H
  Dec   BX
@@cyc:
  Mov   CX, DX
  Shr   CX, 1
  Push  SI
  JNC   @@1
  MovSB
@@1:
  Rep   MovSW
  Pop   SI
  Mov   DI, SI
  Add   SI, 320
  Dec   BX
  JNZ   @@cyc                                   { Copying middle lines }
  Pop   DS
  Mov   SI, Offset _Poly
  Mov   CX, DX
  Shr   CX, 1
  JNC   @@2
  MovSB
@@2:
  Rep   MovSW                                   { Top line written to bottom }
End;

Procedure ScrollDown (X, Y, L, H : Word); Assembler;
Asm
  Push  DS
  Mov   AX, DS
  Mov   ES, AX
  Mov   DI, Offset _Poly                        { ES:DI - Buf Address }
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Mov   BX, Y
  Add   BX, H
  Dec   BX
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Scr addr of bottom line }
  Mov   DX, L                                   { DX = L }
  CLD
  Push  SI
  Mov   CX, DX
  Shr   CX, 1
  Inc   CX
  Rep   MovSW                                   { Bottom line saved in the Buf }
  Pop   SI
  Mov   DI, SI
  Sub   SI, 320                                 { DS:SI - source }
  Mov   AX, DS
  Mov   ES, AX                                  { ES:DI - destination }
  Mov   BX, H
  Dec   BX
@@cyc:
  Mov   CX, DX
  Shr   CX, 1
  Push  SI
  JNC   @@1
  MovSB
@@1:
  Rep   MovSW
  Pop   SI
  Mov   DI, SI
  Sub   SI, 320
  Dec   BX
  JNZ   @@cyc                                   { Copying middle lines }
  Pop   DS
  Mov   SI, Offset _Poly
  Mov   CX, DX
  Shr   CX, 1
  JNC   @@2
  MovSB
@@2:
  Rep   MovSW                                   { Bottom line written to top }
End;

Procedure ScrollLeft2 (X, Y, L, H : Word); Assembler;
Asm
  Push  DS
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Mov   BX, Y
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Screen start addr }
  Mov   AX, DS
  Mov   ES, AX
  Mov   DI, SI                                  { ES:DI = DS:SI }
  CLD
  Mov   BX, H
@cyc:
  Push  DI
  Mov   AX, DS:[SI]                             { Save left pixels to AX }
  Inc   SI
  Inc   SI                                      { Starting from 3-rd pixel }
  Mov   CX, L
  Dec   CX
  Dec   CX                                      { L-2 pixel to copy }
  ShR   CX, 1
  JNC   @1
  MovSB
@1:
  Rep   MovSW
  STOSW
  Pop   DI
  Add   DI, 320
  Mov   SI, DI
  Dec   BX
  JNZ   @cyc
  Pop   DS
End;

Procedure ScrollRight2 (X, Y, L, H : Word); Assembler;
Asm
  Push  DS
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Add   SI, L
  Dec   SI
  Dec   SI
  Mov   BX, Y
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Screen "start" addr }
  Mov   AX, DS
  Mov   ES, AX
  Mov   DI, SI                                  { ES:DI = DS:SI }
  STD
  Mov   BX, H
@cyc:
  Push  DI
  Mov   AX, ES:[DI]                             { Save right pixels to AX }
  Dec   SI
  Dec   SI                                      { Starting from 3-rd pixel }
  Mov   CX, L
  Dec   CX
  Dec   CX                                      { L-2 pixel to copy }
  ShR   CX, 1
  Rep   MovSW
  JNC   @1                                      { If L-2 is NOT ODD }
  Inc   DI
  Inc   SI
  MovSB
  Dec   DI
  Dec   SI
@1:
  STOSW
  Pop   DI
  Add   DI, 320
  Mov   SI, DI
  Dec   BX
  JNZ   @cyc
  Pop   DS
End;

Procedure ScrollUp2 (X, Y, L, H : Word); Assembler;
Asm
  Push  DS
  Mov   AX, DS
  Mov   ES, AX
  Mov   DI, Offset _Poly                        { ES:DI - Buf Address }
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Mov   BX, Y
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Screen start addr }
  Mov   DX, L                                   { DX = L }
  CLD
  Mov   BX, SI
  Mov   CX, DX
  Shr   CX, 1
  Inc   CX
  Rep   MovSW                                   { 1-st line saved to the Buf }
  Mov   SI, BX
  Add   SI, 320
  Mov   CX, DX
  Shr   CX, 1
  Inc   CX
  Rep   MovSW
  Mov   SI, BX                                  { 2-nd line saved to the Buf }
  Mov   DI, SI
  Add   SI, 640                                 { DS:SI - source }
  Mov   AX, DS
  Mov   ES, AX                                  { ES:DI - destination }
  Mov   BX, H
  Dec   BX
  Dec   BX
@@cyc:
  Mov   CX, DX
  Shr   CX, 1
  Push  SI
  JNC   @@1
  MovSB
@@1:
  Rep   MovSW
  Pop   SI
  Mov   DI, SI
  Sub   DI, 320
  Add   SI, 320
  Dec   BX
  JNZ   @@cyc                                   { Copying middle lines }
  Pop   DS
  Mov   SI, Offset _Poly
  Mov   BX, DI
  Mov   CX, DX
  Shr   CX, 1
  JNC   @@2
  MovSB
@@2:
  Rep   MovSW                                   { 1-st line written }
  Mov   DI, BX
  Add   DI, 320
  Mov   CX, DX
  Shr   CX, 1
  CMC
  Adc   SI, 1
  Test  DX, 1
  JZ    @@3
  MovSB
@@3:
  Rep   MovSW                                   { 2-nd line written }
End;

Procedure ScrollDown2 (X, Y, L, H : Word); Assembler;
Asm
  Push  DS
  Mov   AX, DS
  Mov   ES, AX
  Mov   DI, Offset _Poly                        { ES:DI - Buf Address }
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Mov   BX, Y
  Add   BX, H
  Dec   BX
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Scr addr of bottom line }
  Mov   DX, L                                   { DX = L }
  CLD
  Mov   BX, SI
  Mov   CX, DX
  Shr   CX, 1
  Inc   CX
  Rep   MovSW                                   { 1-st line saved in the Buf }
  Mov   SI, BX
  Sub   SI, 320
  Mov   CX, DX
  Shr   CX, 1
  Inc   CX
  Rep   MovSW                                   { 2-nd line saved in the Buf }
  Mov   SI, BX
  Mov   DI, SI
  Sub   SI, 640                                 { DS:SI - source }
  Mov   AX, DS
  Mov   ES, AX                                  { ES:DI - destination }
  Mov   BX, H
  Dec   BX
  Dec   BX
@@cyc:
  Mov   CX, DX
  Shr   CX, 1
  Push  SI
  JNC   @@1
  MovSB
@@1:
  Rep   MovSW
  Pop   SI
  Mov   DI, SI
  Add   DI, 320
  Sub   SI, 320
  Dec   BX
  JNZ   @@cyc                                   { Copying middle lines }
  Pop   DS
  Mov   SI, Offset _Poly
  Mov   BX, DI
  Mov   CX, DX
  Shr   CX, 1
  JNC   @@2
  MovSB
@@2:
  Rep   MovSW                                   { 1-st line written }
  Mov   DI, BX
  Sub   DI, 320
  Mov   CX, DX
  Shr   CX, 1
  CMC
  Adc   SI, 1
  Test  DX, 1
  JZ    @@3
  MovSB
@@3:
  Rep   MovSW                                   { 2-nd line written }
End;


Procedure RollLeft (X, Y, L, H : Word; C : Byte); Assembler;
Asm
  Push  DS
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Mov   BX, Y
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Screen start addr }
  Mov   AX, DS
  Mov   ES, AX
  Mov   DI, SI                                  { ES:DI = DS:SI }
  CLD
  Mov   BX, H
@cyc:
  Push  DI
  Mov   AL, C
  Inc   SI                                      { Starting from 2-nd pixel }
  Mov   CX, L
  Dec   CX                                      { L-1 pixel to copy }
  ShR   CX, 1
  JNC   @1
  MovSB
@1:
  Rep   MovSW
  STOSB
  Pop   DI
  Add   DI, 320
  Mov   SI, DI
  Dec   BX
  JNZ   @cyc
  Pop   DS
End;

Procedure RollRight (X, Y, L, H : Word; C : Byte); Assembler;
Asm
  Push  DS
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Add   SI, L
  Dec   SI
  Mov   BX, Y
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Screen "start" addr }
  Mov   AX, DS
  Mov   ES, AX
  Mov   DI, SI                                  { ES:DI = DS:SI }
  STD
  Mov   BX, H
@cyc:
  Push  DI
  Mov   AL, C
  Dec   DI
  Dec   SI
  Dec   SI                                      { Starting from 2-nd pixel }
  Mov   CX, L
  Dec   CX                                      { L-1 pixel to copy }
  ShR   CX, 1
  Rep   MovSW
  Inc   DI
  JNC   @1                                      { If L-1 is NOT ODD }
  Inc   SI
  MovSB
@1:
  STOSB
  Pop   DI
  Add   DI, 320
  Mov   SI, DI
  Dec   BX
  JNZ   @cyc
  Pop   DS
End;

Procedure RollUp (X, Y, L, H : Word; C : Byte); Assembler;
Asm
  Push  DS
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Mov   BX, Y
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Screen start addr }
  Mov   DX, L                                   { DX = L }
  CLD
  Mov   DI, SI
  Add   SI, 320                                 { DS:SI - source }
  Mov   AX, DS
  Mov   ES, AX                                  { ES:DI - destination }
  Mov   BX, H
  Dec   BX
@@cyc:
  Mov   CX, DX
  Shr   CX, 1
  Push  SI
  JNC   @@1
  MovSB
@@1:
  Rep   MovSW
  Pop   SI
  Mov   DI, SI
  Add   SI, 320
  Dec   BX
  JNZ   @@cyc                                   { Copying middle lines }
  Pop   DS
  Mov   AL, C
  Mov   AH, AL
  Mov   CX, DX
  Shr   CX, 1
  JNC   @@2
  STOSB
@@2:
  Rep   STOSW
End;

Procedure RollDown (X, Y, L, H : Word; C : Byte); Assembler;
Asm
  Push  DS
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Mov   BX, Y
  Add   BX, H
  Dec   BX
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Scr addr of bottom line }
  Mov   DX, L                                   { DX = L }
  CLD
  Mov   DI, SI
  Sub   SI, 320                                 { DS:SI - source }
  Mov   AX, DS
  Mov   ES, AX                                  { ES:DI - destination }
  Mov   BX, H
  Dec   BX
@@cyc:
  Mov   CX, DX
  Shr   CX, 1
  Push  SI
  JNC   @@1
  MovSB
@@1:
  Rep   MovSW
  Pop   SI
  Mov   DI, SI
  Sub   SI, 320
  Dec   BX
  JNZ   @@cyc                                   { Copying middle lines }
  Pop   DS
  Mov   AL, C
  Mov   AH, AL
  Mov   CX, DX
  Shr   CX, 1
  JNC   @@2
  STOSB
@@2:
  Rep   STOSW
End;

Procedure RollLeft2 (X, Y, L, H : Word; C : Byte); Assembler;
Asm
  Push  DS
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Mov   BX, Y
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Screen start addr }
  Mov   AX, DS
  Mov   ES, AX
  Mov   DI, SI                                  { ES:DI = DS:SI }
  CLD
  Mov   BX, H
@cyc:
  Push  DI
  Mov   AL, C
  Mov   AH, AL
  Inc   SI
  Inc   SI                                      { Starting from 3-rd pixel }
  Mov   CX, L
  Dec   CX
  Dec   CX                                      { L-2 pixel to copy }
  ShR   CX, 1
  JNC   @1
  MovSB
@1:
  Rep   MovSW
  STOSW
  Pop   DI
  Add   DI, 320
  Mov   SI, DI
  Dec   BX
  JNZ   @cyc
  Pop   DS
End;

Procedure RollRight2 (X, Y, L, H : Word; C : Byte); Assembler;
Asm
  Push  DS
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Add   SI, L
  Dec   SI
  Dec   SI
  Mov   BX, Y
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Screen "start" addr }
  Mov   AX, DS
  Mov   ES, AX
  Mov   DI, SI                                  { ES:DI = DS:SI }
  STD
  Mov   BX, H
@cyc:
  Push  DI
  Mov   AL, C
  Mov   AH, AL
  Dec   SI
  Dec   SI                                      { Starting from 3-rd pixel }
  Mov   CX, L
  Dec   CX
  Dec   CX                                      { L-2 pixel to copy }
  ShR   CX, 1
  Rep   MovSW
  JNC   @1                                      { If L-2 is NOT ODD }
  Inc   DI
  Inc   SI
  MovSB
  Dec   DI
  Dec   SI
@1:
  STOSW
  Pop   DI
  Add   DI, 320
  Mov   SI, DI
  Dec   BX
  JNZ   @cyc
  Pop   DS
End;

Procedure RollUp2 (X, Y, L, H : Word; C : Byte); Assembler;
Asm
  Push  DS
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Mov   BX, Y
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Screen start addr }
  Mov   DX, L                                   { DX = L }
  CLD
  Mov   DI, SI
  Add   SI, 640                                 { DS:SI - source }
  Mov   AX, DS
  Mov   ES, AX                                  { ES:DI - destination }
  Mov   BX, H
  Dec   BX
  Dec   BX
@@cyc:
  Mov   CX, DX
  Shr   CX, 1
  Push  SI
  JNC   @@1
  MovSB
@@1:
  Rep   MovSW
  Pop   SI
  Mov   DI, SI
  Sub   DI, 320
  Add   SI, 320
  Dec   BX
  JNZ   @@cyc                                   { Copying middle lines }
  Pop   DS
  Mov   AL, C
  Mov   AH, AL
  Mov   BX, DI
  Mov   CX, DX
  Shr   CX, 1
  JNC   @@2
  STOSB
@@2:
  Rep   STOSW                                   { 1-st line written }
  Mov   DI, BX
  Add   DI, 320
  Mov   CX, DX
  Shr   CX, 1
  JNC   @@3
  STOSB
@@3:
  Rep   STOSW                                   { 2-nd line written }
End;

Procedure RollDown2 (X, Y, L, H : Word; C : Byte); Assembler;
Asm
  Push  DS
  Mov   AX, VSegA
  Mov   DS, AX
  Mov   SI, X
  Mov   BX, Y
  Add   BX, H
  Dec   BX
  ShL   BX, 6
  Add   SI, BX
  ShL   BX, 2
  Add   SI, BX                                  { DS:SI - Scr addr of bottom line }
  Mov   DX, L                                   { DX = L }
  CLD
  Mov   DI, SI
  Sub   SI, 640                                 { DS:SI - source }
  Mov   AX, DS
  Mov   ES, AX                                  { ES:DI - destination }
  Mov   BX, H
  Dec   BX
  Dec   BX
@@cyc:
  Mov   CX, DX
  Shr   CX, 1
  Push  SI
  JNC   @@1
  MovSB
@@1:
  Rep   MovSW
  Pop   SI
  Mov   DI, SI
  Add   DI, 320
  Sub   SI, 320
  Dec   BX
  JNZ   @@cyc                                   { Copying middle lines }
  Pop   DS
  Mov   AL, C
  Mov   AH, AL
  Mov   BX, DI
  Mov   CX, DX
  Shr   CX, 1
  JNC   @@2
  STOSB
@@2:
  Rep   STOSW                                   { 1-st line written }
  Mov   DI, BX
  Sub   DI, 320
  Mov   CX, DX
  Shr   CX, 1
  JNC   @@3
  STOSB
@@3:
  Rep   STOSW                                   { 2-nd line written }
End;

End.

Uses CRT, DOS, Grafix, KeyPres2;

Const
  TRate = 6;            { Во сколько раз чаще работает таймер.          }
                        { Используется для моделирования полета снаряда }
  Step = 6;             { Шаг танка при движении }

  D = 20;               { Задержечка }

Type
  TTank = Object                        { Объект объединяет данные и методы }
    X, Y,                               { Координаты танка }
    DX, DY : Integer;                   { Приращения его координат }
                                        { при движении }
    Phase : Byte;                       { Фаза определяет номер картинки и }
                                        { направление движения танка (угол) }
    Pic : Array [1..16] of Pointer;     { Указатели на картинки танка }
    Back : Pointer;                     { Указатель на область сохранения фона }
                                        { под танком }
    PX, PY,                             { Координаты снаряда }
    PDX, PDY : Integer;                 { Приращения его координат }
                                        { при движении }
    PBack : Byte;                       { Цвет точки фона под снарядом }
    Shooting : Boolean;                 { Признак летящего снаряда }

    Procedure Init (FName : String; IX, IY : Word; IPhase : Byte);
    { Инициализирует объект: грузит картинки, устанавливает начальные }
    { координаты танка и направление его движения }

    Procedure Done;
    { Освобождает память от картинок танка }

    Procedure Draw;
    { Рисует танк }

    Procedure Hide;
    { Стирает танк с экрана }

    Procedure Move (Direction : Integer);
    { Увеличивает/уменьшает координаты танка: увелич., если Direction=1; }
    { уменьш., если Direction=1 }

    Procedure Rotate (Direction : Integer);
    { "Поворачивает" танк, изменяя напправление движения }

    Procedure Shoot;
    { Подготавливает все, что нужно, к выстрелу }
  End;

Var
  Old_Timer : Pointer;  { Указатель на старый обработчик прерыв. таймера }
  Time : Byte;          { Счетчик таймера }
  Tank : TTank;         { Собственно "танк" }

Procedure TTank.Init;
Const
  Num : Array [1..16] of String[2] =
    ('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16');
Var
  F : File;
  I : Byte;
Begin
  For I := 1 to 16 do Begin
    GetMem (Pic[I], 4+16*16);
    Assign (F, FName+Num[I]+'.SPR');
    Reset (F, 1);
    Word(Pic[I]^) := 16;                        { Ширина картинки }
    Inc (LongInt(Pic[I]), 2);
    Word(Pic[I]^) := 16;                        { Высота картинки }
    Inc (LongInt(Pic[I]), 2);
    BlockRead (F, Pic[I]^, 16*16);
    Dec (LongInt(Pic[I]), 4);
    Close (F)
  End;
  GetMem (Back, 4+16*16);
  X := IX; Y := IY;
  Phase := IPhase;
  DX := Round(Step*Cos((Phase-1)*0.392699)); { 2*PI/16=0.392699 }
  DY := Round(Step*Sin((Phase-1)*0.392699));
  Shooting := False
End;

Procedure TTank.Done;
Var I : Byte;
Begin
  For I := 1 to 16 do
    FreeMem (Pic[I], 4+16*16);
  FreeMem (Back, 4+16*16)
End;

Procedure TTank.Draw;
Begin
  GetImage (X, Y, 16, 16, Back^);       { Сохранили фон под танком }
  PutTranspImage (X, Y, Pic[Phase]^)    { Нарисовали "прозрачный" танк }
End;

Procedure TTank.Hide;
Begin
  PutImage (X, Y, Back^)                { Восстановили фон под танком }
End;

Procedure TTank.Move;
Var
  DDX, DDY : Integer;
Begin
  DDX := DX*Direction;
  DDY := DY*Direction;
  Inc (X, DDX); If (X < 0) or (X > 320-16) then Dec (X, DDX);
  Dec (Y, DDY); If (Y < 0) or (Y > 200-16) then Inc (Y, DDY)
End;

Procedure TTank.Rotate;
Begin
  Inc (Phase, Direction);
  If Phase > 16 then Dec (Phase, 16)
  Else If Phase < 1 then Inc (Phase, 16);
  DX := Round(Step*Cos((Phase-1)*0.392699));
  DY := Round(Step*Sin((Phase-1)*0.392699))
End;

Procedure TTank.Shoot;
Begin
  PX := X+8;
  PY := Y+8;                            { Стреляем прямо из башни }
  PDX := DX;
  PDY := DY;                            { В направлении движения танка }
  Time := 0;
  Shooting := True                      { Пора "включиться" таймеру }
End;

Procedure New_Timer; Interrupt;
{ Новый бработчик прерывания от таймера }
Begin
  If Time = 0 then Asm
    PushF                               { Вызываем с прежней частотой        }
    Call DWord Ptr Old_Timer            { старый обработчик тайм. прерывания }
  End
  Else Port[$20] := $20;                { Когда не вызываем, сообщаем      }
                                        { контроллеру прерываний, что      }
                                        { прерывание от таймера обработано }

  Inc (Time);                           { Это и обеспечивает вызов старого }
  If Time=TRate then Time := 0;         { обработчика со старой частотой   }
                                        { чтобы не чудили часы             }

  If not Tank.Shooting then Exit;       { Нет выстрела }

  If Time and 1 = 0 then Begin  { Рисуем снаряд }
    Tank.PBack := GetPixel (Tank.PX, Tank.PY);
    PutPixel (Tank.PX, Tank.PY, White)
  End
  Else Begin                    { А теперь стираем и изменяем его координаты }
    PutPixel (Tank.PX, Tank.PY, Tank.PBack);
    Inc (Tank.PX, Tank.PDX);
    Dec (Tank.PY, Tank.PDY);
    If (Tank.PX < 0) or (Tank.PX > 319) or
      (Tank.PY < 0) or (Tank.PY > 199) then
        Tank.Shooting := False          { Вылетел за границу экрана }
  End
End;

Var
  S : Byte;                             { Сканкод клавиши }
  P : Pointer;                          { Указатель на фоновую картинку }
  Sz : Word;                            { Размер фоновой картинки }
  Pal : TPal;                           { Палитра фоновой картинки }

Begin
  Tank.Init ('TANK', 160, 100, 5);      { Инициализируем танк }
{  LoadPCX256 ('TOWN.PCX', P, Sz, Pal);}
  GetIntVec (8, Old_Timer);             { Сохр. адрес старого обработчика
                                        { прерывания от таймера }
  SetIntVec (8, @New_Timer);
  Port[$43] := $34;                             { Ускорили частоту }
  Port[$40] := ($FFFF div TRate) and $FF;       { таймера в        }
  Port[$40] := ($FFFF div TRate) shr 8;         { TRate раз        }

  WaitForACSReleased;            { Ждем отпускания Alt,Ctrl,Shift, }
                                 { иначе будет, извините жопа }
  Set_Handler;                   { Ставим наш обработчик клавиатурного }
                                 { прерывания для повышения скорости }
                                 { ввода с клавиатуры и обработки }
                                 { одновременных нажатий клавиш }

  InitGraph;
  ClearScreen (Green);
(*  SetPal (Pal);                { Установили палитру картинки }
  PutImage (0, 0, P^);           { Кинули картинку на экран }
  FreeMem (P, Sz); *)            { Хочешь - отремь это безобразие }
  Tank.Draw;                     { Нарисовали танк }

  Repeat
    If KeyPressed2 then S := ReadScan { Ежели че-то нажато, имеем сканкод }
    Else S := 0;

    { Попробуй перекинуть фигурные скобки с выражений типа }
    { "KeyMap[s*]" на варажения вроде "S = s*", что случится? }

    If {S = sUp} KeyMap[sUp] then Begin
      Tank.Hide;
      Tank.Move (1);
      Tank.Draw;
      Delay (D)
    End;
    If {S = sDown} KeyMap[sDown] then Begin
      Tank.Hide;
      Tank.Move (-1);
      Tank.Draw;
      Delay (D)
    End;
    If {S = sLeft} KeyMap[sLeft] then Begin
      Tank.Hide;
      Tank.Rotate (1);
      Tank.Draw;
      Delay (D)
    End;
    If {S = sRight} KeyMap[sRight] then Begin
      Tank.Hide;
      Tank.Rotate (-1);
      Tank.Draw;
      Delay (D)
    End;
    If {S = sSpace} KeyMap[sSpace] then Begin
      If not Tank.Shooting then
        Tank.Shoot
    End;
  Until KeyMap[sEsc];                   { Ждемс Escap'а }

  Remove_Handler;                       { Вернули старый обработчик }
                                        { прерываний от клавиатуры }
  SetIntVec (8, Old_Timer);             { Вернули старый обработчик }
                                        { прерываний от таймера }

  Port[$43] := $34;                     { Вернули прежнюю частоту }
  Port[$40] := $00;                     { таймера -               }
  Port[$40] := $00;                     { 18.2 герц               }
  CloseGraph;
  Tank.Done                             { Освободили память перед выходом - }
                                        { правило хорошего тона             }

  { Бля буду, ведь это же просто как мычанье!!! }
End.

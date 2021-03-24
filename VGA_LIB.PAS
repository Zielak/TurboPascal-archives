{$G+}
unit VGA_lib;
interface
uses crt;
const max_spr=50;
      segfont=$F000;
      ofsfont=$FA6E;
      Scr:pointer=ptr($0A000,0);

type pal=array[0..767] of byte;

var pal_akt,pal_des:pal;
    tlo,page:pointer;
    spr:array[1..max_spr] of pointer;
    exist:array[1..max_spr] of boolean;
    s_sz:array[1..max_spr] of word;
    s_wys:array[1..max_spr] of byte;
    sx:array[1..max_spr] of word;
    sy:array[1..max_spr] of byte;
    zmienna:word;
    is_page:boolean;

procedure GetPal(var p:pal);
procedure SetColor(nr,Rpal,Gpal,Bpal:byte);
procedure GetColor(nr:byte;var Rpal,Gpal,Bpal:byte);
procedure Fade;
procedure Fader;
procedure Spread(nr1,r1,g1,b1,nr2,r2,g2,b2:byte);
procedure ShiftUp(nr1,nr2:word);
procedure ShiftDown(nr1,nr2:word);
procedure Cls(color:byte);
procedure Bar(x1,y1,x2,y2:word;color:byte);
procedure Box(x1,y1,x2,y2:word;color:byte);
procedure Line(x1,y1,x2,y2:word;color:byte);
procedure LineH(x1,x2,y:word;c:byte);
procedure LineV(x,y1,y2:word;c:byte);
procedure Circle(xc,yc,rc:word;cc:byte);
procedure Circle_Fill(xc,yc,rc:word;cc:byte);
procedure Print(x,y:word;color:byte;s:string);
procedure Init;
procedure Clinit;
procedure WaitVbl;
procedure GetBk;
procedure FreeBk;
procedure FreeAllSpr;
procedure Plot(xe,ye:integer;c:byte);
procedure PlotPage(xe,ye:integer;c:byte);
function GetPlot(xe,ye:integer):byte;

procedure GetSpr(x1,y1,x2,y2,nr:word);
procedure PutSpr(x,y,nr:word);
procedure HideSpr(nr:byte);

procedure InitPage;
procedure ClearPage;
procedure Page2Screen;

procedure Dzwiek(Wartosc,Czas:integer);
procedure TextCrt(Tekst:string; Kolor,Muzyka,Czekaj,IloscLiter: integer);

implementation

procedure InitPage;
begin
  GetMem(page,64000);
  is_page:=true;
end;
(*
procedure ClearPage;assembler;
asm
  les di,page
  db 66h
  xor ax,ax
  mov cx,09000H{64000/4}
  db 66h
  rep StosW
end;

procedure Page2Screen;assembler;
asm
  push ds
  les di,scr
  lds si,page
  mov cx,09000H{64000/4}
  db 66h
  rep movsW
  pop ds
end;
*)
procedure ClearPage;assembler;
asm
MOV AX,09000H         { do AX adres ostatniego segmentu (bufora ekranu) }
MOV ES,AX             { ES = AX                                         }
MOV DI,0              { DI = 0 - zacznij od pierwszego pixela (0,0)     }
MOV AL,0              { do AL kolor                                     }
MOV AH,0              { do AH kolor                                     }
MOV CX,32000          { zapis. po dwa bajty (64000/2) bo tak jest szyb. }
end;

procedure Page2Screen;assembler;
asm
MOV AX,09000H   { do AX adres segmentu bufora                           }
MOV DS,AX       { DS = AX                                               }
MOV SI,0        { SI = 0 - wskazuje na pierwszy pixel bufora            }
MOV AX,0A000H   { do AX adres segmentu graficznego                      }
MOV ES,AX       { ES = AX                                               }
MOV DI,0        { DI = 0 - wskazuje na pierwszy pixel ekranu            }
MOV CX,32000    { ilosc powt¢rzen (petla)                               }
REP MOVSW       { powtarzaj 32000x instrukcje MOVSW, kt¢ra kopiuje      }
                { s3owo po s3owie         z DS:SI do ES:DI              }
end;


function Adres(xa,ya:word):word;
begin
  asm
    mov dx,ya
    mov di,xa
    xchg dh,dl
    add di,dx
    shr dx,2
    add di,dx
    mov @Result,di
  end;
end;

procedure Cls(color:byte);assembler;
asm
  mov ax,0a000h
  mov es,ax
  xor di,di
  db 66h
  xor ax,ax
  mov al,color
  mov ah,al
  mov bx,ax
  db 66h
  shl ax,16
  mov ax,bx
  mov cx,16000
  db 66h
  rep stosW
end;
{
procedure Cls(color:byte);assembler;
asm
  mov ax,09000h
  mov es,ax
  mov di,0
  mov al,color
  mov ah,color
  mov cx,32000
end;
}
procedure Bar(x1,y1,x2,y2:word;color:byte);assembler;
asm
    mov ax,$A000
    mov es,ax
    mov dx,y1
    mov di,x1
    xchg dh,dl
    add di,dx
    shr dx,2
    add di,dx
    mov cx,y2
    sub cx,y1
    inc cx
    mov ah,color
    mov al,ah

@Y: mov bx,cx
    mov cx,x2
    sub cx,x1
    inc cx
    rep stosB
    add di,319
    sub di,x2
    add di,x1

    mov cx,bx
    Loop @Y
end;

procedure Line(x1,y1,x2,y2:word;color:byte);
var
  wsk1,wsk2,podpr:word;
begin
asm
        push si
        push di
        push es
        mov ax,$A000
        mov es,ax
        mov si,320
        mov cx,x2
        sub cx,x1
        jz  @@VL
        jns @@pdr1
        neg cx
        mov bx,x2
        xchg bx,x1
        mov x2,bx
        mov bx,y2
        xchg bx,y1
        mov y2,bx
@@pdr1:
        mov bx,y2
        sub bx,y1
        jz @@HL
        jns @@pdr3
        neg bx
        neg si
@@pdr3:
        push si
        mov podpr,offset @@LL1
        cmp bx,cx
        jle @@pdr4
        mov podpr,offset @@HL1
        xchg bx,cx
@@pdr4:
        shl bx,1
        mov wsk1,bx
        sub bx,cx
        mov si,bx
        sub bx,cx
        mov wsk2,bx
        push cx
        mov ax,y1
        mov bx,x1

       xchg ah,al
       add bx,ax
       shr ax,1
       shr ax,1
       add bx,ax

        mov di,bx
        pop cx
        inc cx
        pop bx
        jmp podpr
@@VL:
        mov ax,y1
        mov bx,y2
        mov cx,bx
        sub cx,ax
        jge @@pdr31
        neg cx
        mov ax,bx
@@pdr31:
        inc cx
        mov bx,x1
        push cx
       xchg ah,al
       add bx,ax
       shr ax,1
       shr ax,1
       add bx,ax

        pop cx
        mov di,bx
        dec si
        mov al,color
@@pdr32:
        stosb
        add di,si
        loop @@pdr32
        jmp @@Exit
@@HL:
        push cx
        mov ax,y1
        mov bx,x1

       xchg ah,al
       add bx,ax
       shr ax,1
       shr ax,1
       add bx,ax

        mov di,bx
        pop cx
        inc cx
        mov al,color
        rep stosb
        jmp @@Exit
@@LL1:
        mov al,color
@@pdr11:
        stosb
        or si,si
        jns @@pdr12
        add si,wsk1
        loop @@pdr11
        jmp @@Exit
@@pdr12:
        add si,wsk2
        add di,bx
        loop @@pdr11
        jmp @@Exit
@@HL1:
        mov al,color
@@pdr21:
        stosb
        add di,bx
@@pdr22:
        or si,si
        jns @@pdr23
        add si,wsk1
        dec di
        loop @@pdr21
        jmp @@Exit
@@pdr23:
        add si,wsk2
        loop @@pdr21
@@Exit:
        pop es
        pop di
        pop si

 end;
end;

procedure LineH(x1,x2,y:word;c:byte);assembler;
asm
  mov ax,x1
  cmp ax,x2
  jb @ok
  xchg ax,x2
  mov x1,ax
@ok:

  mov ax,09000h
  mov es,ax
  mov dx,y
  mov di,x1
  xchg dh,dl
  add di,dx
  shr dx,2
  add di,dx
  mov cx,x2
  sub cx,x1
  inc cx
  mov al,c
  rep Stosb
end;

procedure LineV(x,y1,y2:word;c:byte);assembler;
asm
  mov ax,09000h{_$A000}
  mov es,ax
  mov dx,y1
  mov di,x
  xchg dh,dl
  add di,dx
  shr dx,2
  add di,dx
  mov cx,y2
  sub cx,y1
  inc cx
  mov al,c
@p:
  StosB
  add di,319
  loop @p

end;

procedure Box(x1,y1,x2,y2:word;color:byte);
begin
  LineH(x1,x2,y1,color);
  LineH(x1,x2,y2,color);
  LineV(x1,y1,y2,color);
  LineV(x2,y1,y2,color);
end;

procedure SetColor(nr,Rpal,Gpal,Bpal:byte);
begin
  pal_akt[(nr shl 2)-nr+0]:=Rpal;
  pal_akt[(nr shl 2)-nr+1]:=Gpal;
  pal_akt[(nr shl 2)-nr+2]:=Bpal;
  asm
      mov si,offset pal_akt
      mov cx,768
      mov dx,$3c9
      rep outsb
  end;
end;

procedure GetColor(nr:byte;var Rpal,Gpal,Bpal:byte);
begin
  port[$3c7]:=nr;
  Rpal:=port[$3c9];
  Gpal:=port[$3c9];
  Bpal:=port[$3c9];
end;

procedure GetPal(var p:pal);
var cn:byte;
begin
  for cn:=0 to 254 do begin
    port[$3c7]:=cn;
    p[cn*3]:=port[$3c9];
    p[cn*3+1]:=port[$3c9];
    p[cn*3+2]:=port[$3c9];
  end;
end;

procedure Fade;
var l1,l2:word;
begin
  for l1:=0 to 63 do begin
    for l2:=0 to 767 do begin
      if pal_akt[l2]<pal_des[l2] then inc(pal_akt[l2]);
      if pal_akt[l2]>pal_des[l2] then dec(pal_akt[l2]);
    end;
    asm
      mov si,offset pal_akt
      mov cx,768
      mov dx,$3c9
      rep outsb
    end;
    WaitVbl;
  end;
end;

procedure Fader;
var l1,l2:word;
    pal_fad:pal;
begin
  move(pal_akt,pal_fad,768);
  for l1:=1 to 64 do begin
    for l2:=0 to 767 do begin
      pal_akt[l2]:=round((pal_des[l2]-pal_fad[l2])*l1 shr 6)+pal_fad[l2];
    end;
    WaitVbl;
    asm
      mov si,offset pal_akt
      mov cx,768
      mov dx,$3c9
      rep outsb
    end;
  end;
end;

procedure Spread(nr1,r1,g1,b1,nr2,r2,g2,b2:byte);
var lc:integer;
    Rp,Gp,Bp:byte;
    macroM:real;
begin
  if nr2<nr1 then
  begin
    rp:=r1;
    gp:=g1;
    bp:=b1;
    r1:=r2;
    g1:=g2;
    b1:=b2;
    r2:=rp;
    g2:=gp;
    b2:=bp;
    lc:=nr1;
    nr1:=nr2;
    nr2:=lc;
  end;
  for lc:=nr1 to nr2 do begin
    macroM:=(lc-nr1)/(nr2-nr1);
    Rp:=round(r1+(r2-r1)*macroM);
    Gp:=round(g1+(g2-g1)*macroM);
    Bp:=round(b1+(b2-b1)*macroM);
    pal_akt[(lc shl 2)-lc+0]:=Rp;
    pal_akt[(lc shl 2)-lc+1]:=Gp;
    pal_akt[(lc shl 2)-lc+2]:=Bp;
  end;
  asm
      mov si,offset pal_akt
      mov cx,768
      mov dx,$3c9
      rep outsb
  end;
end;

procedure ShiftUp(nr1,nr2:word);
var r,g,b:byte;
begin
  move(pal_akt[(nr2 shl 2)-nr2],r,3);
  move(pal_akt[(nr1 shl 2)-nr1],pal_akt[((nr1+1) shl 2)-nr1-1],(nr2-nr1)*3);
  move(r,pal_akt[(nr1 shl 2)-nr1],3);
   asm
      mov si,offset pal_akt
      mov cx,768
      mov dx,$3c9
      rep outsb
    end;
end;

procedure ShiftDown(nr1,nr2:word);
var r,g,b:byte;
begin
  move(pal_akt[(nr1 shl 2)-nr1],r,3);
  move(pal_akt[((nr1+1) shl 2)-nr1-1],pal_akt[(nr1 shl 2)-nr1],(nr2-nr1)*3);
  move(r,pal_akt[(nr2 shl 2)-nr2],3);
   asm
      mov si,offset pal_akt
      mov cx,768
      mov dx,$3c9
      rep outsb
    end;
end;

procedure Print(x,y:word;color:byte;s:string);
var z,b:word;
    bajt,col2:byte;
begin
  col2:=color;
  for z:=1 to length(s) do
  begin
    color:=col2;
    for b:=0 to 7 do
    begin
      asm
        mov cx,8
      @Pocz:
        push cx
        mov b,8
        sub b,cx

        mov ax,ss
        mov es,ax
        lea bx,s
        add bx,z
        xor ah,ah
        mov al,es:[bx]

        mov bx,segfont
        mov es,bx
        mov si,ofsfont
        shl ax,3
        add ax,b
        add si,ax
        mov al,es:[si]
        mov bajt,al

        cmp bajt,0
        je @Dalej
        mov ax,0A000h
        mov es,ax

        mov cx,8
      @for_a:
        push cx

        mov ah,1B
        dec cl
        shl ah,cl
        and ah,bajt
        jz @Nic
        mov di,b
        add di,y
        mov ax,di
        shl di,8
        shl ax,6
        add di,ax
        mov ax,z
        shl ax,3
        sub ax,cx
        dec cx
        add ax,x
        add di,ax
        mov al,color
        mov es:[di],al


      @Nic:
        pop cx
        loop @for_a
      @Dalej:
        pop cx
        loop @pocz
      end;
    end;
  end;
end;

procedure Init;
begin
  asm
    mov ax,13h
    int 10h
  end;
  DirectVideo:=false;
end;

procedure Clinit;
begin
  asm
    mov ax,3h
    int 10h
  end;
  if is_page then freemem(page,64000);
end;

procedure GetBk;
begin
  GetMem(tlo,64000);
  move(mem[$0A000:0000],mem[seg(tlo^):ofs(tlo^)],64000);
end;

procedure Plot(xe,ye:integer;c:byte);assembler;
asm
  mov ax,$A000
  mov es,ax
  mov dx,ye
  mov di,xe
  shl dx,8
  add di,dx
  shr dx,2
  add di,dx
  mov al,c
  mov es:[di],al
end;

procedure PlotPage(xe,ye:integer;c:byte);assembler;
asm
  les di,page
  mov dx,ye
  mov di,xe
  shl dx,8
  add di,dx
  shr dx,2
  add di,dx
  mov al,c
  mov es:[di],al
end;

function GetPlot(xe,ye:integer):byte;assembler;
asm
  mov ax,$A000
  mov es,ax
  mov dx,ye
  mov di,xe
  xchg dh,dl
  add di,dx
  shr dx,2
  add di,dx
  mov al,es:[di]
end;

procedure Circle(xc,yc,rc:word;cc:byte);
begin
  if rc=0 then begin plot(xc,yc,cc); exit; end;
  asm
    push ds
    mov cx,0
    mov ax,rc
    mov dx,1
    sub dx,rc
@do:
    push dx
    push $a000
    pop es
    mov dx,yc
    mov di,xc
    xchg dh,dl
    add di,dx
    shr dx,2
    add di,dx

    {push yc+y}
    push di
    mov dx,ax
    shl dx,6
    add di,dx
    shl dx,2
    add di,dx

    mov dl,cc
    mov bx,cx
    mov es:[di+bx],dl
    not bx
    inc bx
    mov es:[di+bx],dl
    pop di
    {push yc-y}
    push di
    mov dx,ax
    not dx
    inc dx
    shl dx,6
    add di,dx
    shl dx,2
    add di,dx

    mov dl,cc
    mov bx,cx
    mov es:[di+bx],dl
    not bx
    inc bx
    mov es:[di+bx],dl
    pop di
    {push yc+x}
    push di
    mov dx,cx
    shl dx,6
    add di,dx
    shl dx,2
    add di,dx

    mov dl,cc
    mov bx,ax
    mov es:[di+bx],dl
    not bx
    inc bx
    mov es:[di+bx],dl
    pop di
    {push yc-x}
    push di
    mov dx,cx
    not dx
    inc dx
    shl dx,6
    add di,dx
    shl dx,2
    add di,dx

    mov dl,cc
    mov bx,ax
    mov es:[di+bx],dl
    not bx
    inc bx
    mov es:[di+bx],dl
    pop di
    pop dx

    inc cx
    cmp dx,0
    jl @subd
    dec ax
    mov bx,cx
    sub bx,ax
    shl bx,1
    add dx,bx
    inc dx
    jmp @cont
@subd:
    mov bx,cx
    shl bx,1
    add dx,bx
    inc dx
@cont:
    cmp cx,ax
    jna @do
    pop ds
  end;
end;

procedure Circle_Fill(xc,yc,rc:word;cc:byte);
begin
  if rc=0 then begin plot(xc,yc,cc); exit; end;
  asm
    push ds
    mov cx,0
    mov ax,rc
    mov dx,1
    sub dx,rc
@do:
    push dx
    les di,scr
    mov dx,yc
    mov di,xc
    xchg dh,dl
    add di,dx
    shr dx,2
    add di,dx

    {push yc+y}
    push di
    mov dx,ax
    shl dx,6
    add di,dx
    shl dx,2
    add di,dx
    sub di,cx

    push ax
    push cx
    shl cx,1
    inc cx
    mov al,cc
    rep stosB
    pop cx
    pop ax
    pop di
    {push yc-y}
    push di
    mov dx,ax
    not dx
    inc dx
    shl dx,6
    add di,dx
    shl dx,2
    add di,dx
    sub di,cx

    push ax
    push cx
    shl cx,1
    inc cx
    mov al,cc
    rep stosB
    pop cx
    pop ax
    pop di
    {push yc+x}
    push di
    mov dx,cx
    shl dx,6
    add di,dx
    shl dx,2
    add di,dx
    sub di,ax

    push ax
    push cx
    mov cx,ax
    shl cx,1
    inc cx
    mov al,cc
    rep stosB
    pop cx
    pop ax
    pop di
    {push yc-x}
    push di
    mov dx,cx
    not dx
    inc dx
    shl dx,6
    add di,dx
    shl dx,2
    add di,dx
    sub di,ax

    push ax
    push cx
    mov cx,ax
    shl cx,1
    inc cx
    mov al,cc
    rep stosB
    pop cx
    pop ax
    pop di

    pop dx

    inc cx
    cmp dx,0
    jl @subd
    dec ax
    mov bx,cx
    sub bx,ax
    shl bx,1
    add dx,bx
    inc dx
    jmp @cont
@subd:
    mov bx,cx
    shl bx,1
    add dx,bx
    inc dx
@cont:
    cmp cx,ax
    jna @do
    pop ds
  end;
end;

procedure GetSpr(x1,y1,x2,y2,nr:word);
var o,s,sz,wys,o_2:word;
begin
  if Exist[nr] then exit else Exist[nr]:=true;
  sz:=x2-x1+1;
  if sz mod 2=0 then else inc(sz);
  wys:=y2-y1+1;
  s_sz[nr]:=sz;
  s_wys[nr]:=wys;
  sx[nr]:=x1;
  sy[nr]:=y1;
  GetMem(spr[nr],sz*wys);
  s:=seg(spr[nr]^);
  o:=ofs(spr[nr]^);
  o_2:=adres(x1,y1);
  asm
    push ds

    { DS:SI 0A000:o_2}
    push 0a000h
    pop ds
    mov si,o_2
    { ES:DI s:o}
    mov es,s
    mov di,o
    mov cx,wys
@1:
    push cx
    mov cx,sz
    shr cx,1
    rep movsw
    add si,320
    sub si,sz

    pop cx
    loop @1

    pop ds
  end;
end;

procedure PutSpr(x,y,nr:word);
var o,s,sz,wys,o_2,o_t,s_t,o_2new:word;
begin
  if not Exist[nr] then exit;
  sz:=s_sz[nr];
  wys:=s_wys[nr];
  o:=ofs(spr[nr]^); { ofset sprite`a }
  s:=seg(spr[nr]^); { segment sprite`a}
  o_2:=adres(sx[nr],sy[nr]);
  o_2new:=adres(x,y);
  o_t:=ofs(tlo^);
  s_t:=seg(tlo^);
  sx[nr]:=x;
  sy[nr]:=y;
  asm
    push ds
    mov ds,s_t
    mov si,o_t
    add si,o_2
    mov ax,0A000h
    mov es,ax
    mov di,o_2
    mov cx,wys
@1:
    mov dx,cx
    mov cx,sz
    shr cx,1
    rep movsw
    add si,320
    sub si,sz
    add di,320
    sub di,sz

    mov cx,dx
    loop @1
    { bylo tlo}
    {------}
    {teraz sprite}
    mov ds,s         { DS:SI - s:o }
    mov si,o         { ES:DI - A000:o_2new}
    mov di,o_2new
    mov cx,wys
@2:
    mov dx,cx
    mov cx,sz
@line:
    lodsb
    cmp al,0
    je @nic
    stosb
    jmp @k
@nic:
    inc di
@k: loop @line
    add di,320
    sub di,sz
    mov cx,dx
    loop @2

    pop ds
  end;
end;

procedure HideSpr(nr:byte);
var sz,wys,o_2,o_t,s_t:word;
begin
  if not Exist[nr] then exit;
  sz:=s_sz[nr];
  wys:=s_wys[nr];
  o_2:=adres(sx[nr],sy[nr]);
  o_t:=ofs(tlo^);
  s_t:=seg(tlo^);
  asm
    push ds
    mov ds,s_t
    mov si,o_t
    add si,o_2
    mov ax,0A000h
    mov es,ax
    mov di,o_2
    mov cx,wys
@1:
    mov dx,cx
    mov cx,sz
    shr cx,1
    rep movsw
    add si,320
    sub si,sz
    add di,320
    sub di,sz

    mov cx,dx
    loop @1
    { bylo tlo}
    pop ds
  end;
end;

procedure WaitVbl;
begin
    repeat until (port[$3DA] and 8)=8;
    repeat until (port[$3DA] and 8)=0;
end;

procedure FreeBk;
begin
  FreeMem(tlo,64000);
end;

procedure FreeAllSpr;
begin
  for zmienna:=1 to max_spr do if exist[zmienna] then freemem(spr[zmienna],s_sz[zmienna]*s_wys[zmienna]);
end;

procedure Dzwiek(Wartosc,Czas: integer);
begin
  Sound(Wartosc);
  Delay(Czas);
  NoSound;
end;

procedure TextCrt(Tekst:string; Kolor,Muzyka,Czekaj,IloscLiter: integer);
var
  DlugoscTekstu: integer;
  i            : integer;
  Text         : string;

begin
  DlugoscTekstu:= Length(Tekst);
  TextColor(Kolor);
  for i:= DlugoscTekstu downto 1 do begin
    Text:= Copy(Tekst,DlugoscTekstu-i+1,IloscLiter);
    Write(Text);
    Sound(Muzyka);
    Delay(Czekaj);
    nosound;
  end;
end;

begin
  is_page:=false;
  for zmienna:=1 to max_spr do exist[zmienna]:=false;
  if MemAvail<64000 then
  begin
    Writeln('Za malo wolnej pamieci !!!');
    halt;
  end;
end.

uses dos;

type TCounter=object
                Time1,Time2:DateTime;
                FrameCounter:int64;
                procedure Init;
                procedure Update;
                function  GetFPS:int64;
              end;

procedure TCounter.Init;
begin
Time1:=Now;
FrameCounter:=0;
end;

procedure TCounter.Update;
begin
inc(FrameCounter);
Time2:=Now;
end;

function TCounter.GetFPS:int64;
begin
if MillisecondsBetween(Time2,Time1)>1000 then
    begin
    GetFPS:=FrameCounter div MillisecondsBetween(Time2,Time1);
    Time1:=Now;
    FrameCounter:=0;
    end;
end;

var FPS:TCounter;

begin
FPS.Init;
repeat

  render;

  FPS.update;
  writeln('Frames Per Second: ',FPS.GetFPS);
until HitEsc;
end;
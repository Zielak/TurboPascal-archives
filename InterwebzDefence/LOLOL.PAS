uses zvga,crt,graph;

begin
initvga;



repeat


showbitmapimage('F:\INTERW~1\img\lol1.bmp',0,0);
drawpage;
czekaj;
delay(100);
showbitmapimage('F:\INTERW~1\img\lol2.bmp',0,0);
drawpage;
czekaj;
delay(100);
showbitmapimage('F:\INTERW~1\img\lol3.bmp',0,0);
drawpage;
czekaj;
delay(100);
showbitmapimage('F:\INTERW~1\img\lol4.bmp',0,0);
drawpage;
czekaj;
delay(100);

until keys[1]=true;

end.

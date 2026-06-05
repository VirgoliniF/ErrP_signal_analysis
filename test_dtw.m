t = 0:0.01:10*pi;

x = sin(t);
y = cos(t);

d = dtw(x,y);

figure()
plot(y(1:length(y)-d))
hold on
plot(x(d:length(x)))
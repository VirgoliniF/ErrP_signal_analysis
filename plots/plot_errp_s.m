function plot_errp(t, correct, error, stdc, stde)

    hold on;
    plot_std(t, error, stde,'r');
    plot_std(t, correct, stdc,'b');
    plot(t, error - correct, 'k', 'LineWidth', 2);
    hold off;
    
    xlim([t(1) t(end)]);
    grid on;

end

function plot_std(x, y,std_dev, c)    
    plot(x, y, c);
    %patch([x flip(x)], [y-std_dev; flip(y+std_dev)], c, 'FaceAlpha',0.25, 'EdgeColor','none')
end
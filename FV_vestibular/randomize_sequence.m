% randomize_sequence.m
% Randomizes a sequence of 15 strings (5 'low', 5 'medium', 5 'high')
% and plots the result in the command window.

%% Create and shuffle the sequence
labels = [repmat({'low'}, 1, 5), repmat({'medium'}, 1, 5), repmat({'high'}, 1, 5)];
shuffled = labels(randperm(15));

%% Display result in command window
fprintf('\n===== Randomized Sequence =====\n');
for i = 1:15
    fprintf('  %2d. %s\n', i, shuffled{i});
end
fprintf('===============================\n\n');

%% Map labels to numeric values for plotting
valueMap = containers.Map({'low','medium','high'}, {1, 2, 3});
numericVals = cellfun(@(x) valueMap(x), shuffled);

%% Plot
figure('Name', 'Randomized Sequence', 'NumberTitle', 'off');
colors = containers.Map({'low','medium','high'}, ...
    {[0.2 0.6 1.0], [1.0 0.7 0.1], [0.9 0.2 0.2]});

hold on;
for i = 1:15
    bar(i, numericVals(i), 'FaceColor', colors(shuffled{i}), 'EdgeColor', 'k', 'LineWidth', 0.8);
end
hold off;

% Axes formatting
set(gca, 'YTick', [1 2 3], 'YTickLabel', {'Low', 'Medium', 'High'}, ...
         'XTick', 1:15, 'FontSize', 11);
ylim([0 3.6]);
xlim([0 16]);
xlabel('Position in Sequence', 'FontSize', 13);
ylabel('Level', 'FontSize', 13);
title('Randomized Sequence of Levels', 'FontSize', 14, 'FontWeight', 'bold');
grid on;

% Legend using patch handles
h(1) = patch(NaN, NaN, colors('low'),    'EdgeColor', 'k');
h(2) = patch(NaN, NaN, colors('medium'), 'EdgeColor', 'k');
h(3) = patch(NaN, NaN, colors('high'),   'EdgeColor', 'k');
legend(h, 'Low', 'Medium', 'High', 'Location', 'northeastoutside', 'FontSize', 11);
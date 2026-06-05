clearvars; clc;

subject = 'norm_p_2';

decoder.threshold = 0.5058596296337956;


includepat  = {subject};
excludepat  = {'filtered'};
depthlevel  = 2;

rootpath    = '/var/home/piero/Projects/';
folder      = 'gdf_recordings';
csvpath       = [rootpath '/' folder '/'];

files = util_getfile3(csvpath, '.csv', 'include', includepat, 'exclude', excludepat, 'level', depthlevel);
nfiles = length(files);

%% Initialize the classificaiton labels

MASK_N = 'COMMAND';

mask_name = {'CAMERA', 'BUTTON', 'COMMAND', 'AUDIO'};
mask_value = [0, 80, 60, 40];

[~, id_m ] = ismember(upper(MASK_N), upper(mask_name));

MASK = mask_value(id_m);

Stop        = 100 + MASK;
CommandLx   = 101 + MASK;
CommandFx   = 102 + MASK;
CommandRx   = 103 + MASK;
ErrorLx     = 5101 + MASK;
ErrorRx     = 5103 + MASK;
NoReleaseLx = 4101 + MASK;
NoReleaseFx = 4102 + MASK;
NoReleaseRx = 4103 + MASK;

correct_tasks = {CommandLx, CommandRx};
error_tasks   = {ErrorLx, ErrorRx};

%% Initialize the vector for keep the data for the saved probability

ProbonError   = {};
ProbonCorrect = {};

ClassificationError   = {};
ClassificationCorrect = {};


%% Read and divide the data in different steps

for i = 1:nfiles
    T = readtable(files{i}, 'VariableNamingRule', 'preserve', 'Delimiter', ';');
   
    % Divide the data in the correct vectors
    for index = 1:2:size(T,1)
        task = string(T.Description(index));
        if ismember(task, string(correct_tasks))
            index_prob = size(ProbonCorrect,2);
            ProbonCorrect{index_prob + 1} = getVectorFromStr(T.Values{index});
            ClassificationCorrect{index_prob + 2} = getVectorFromStr(T.Values{index + 1});
        elseif ismember(task, string(error_tasks))
            index_prob = size(ProbonError,2);
            ProbonError{index_prob + 1} = getVectorFromStr(T.Values{index});
            ClassificationError{index_prob + 2} = getVectorFromStr(T.Values{index + 1});
        end
    end

end

%% Reshape the data if they are not the same length 
ProbonCorrect = nomalize_length(ProbonCorrect);
ProbonError = nomalize_length(ProbonError);
ClassificationCorrect = nomalize_length(ClassificationCorrect);
ClassificationError = nomalize_length(ClassificationError);

p_correct = cell2mat(ProbonCorrect');
p_error   = cell2mat(ProbonError');

c_correct = cell2mat(ClassificationCorrect')';
c_error   = cell2mat(ClassificationError')';

%% Compute the confusion matrix

outcom_c = nansum(c_correct);
outcom_e = nansum(c_error);

% replace to 1 if over a trheshold (1 for now)

outcom_c(outcom_c > 0) = 1;
outcom_e(outcom_e > 0) = 1;

outcome = [outcom_c outcom_e];
true_labels = [zeros(size(outcom_c)) ones(size(outcom_e)) ]; 
confMat = confusionmat(true_labels, outcome);

% Compute the accuracy
numCorrect = sum(diag(confMat)); % Sum of diagonal elements
total = sum(confMat, 'all');     % Total number of predictions
accuracy = numCorrect / total;

% Display the result
disp(['Accuracy: ', num2str(accuracy), '/1.0']);


%% Compute the data to plot

m_p_correct = mean(p_correct);
m_p_error   = mean(p_error);
s_p_correct = std(p_correct);
s_p_error   = std(p_error);

x = 1:size(m_p_correct',1);

%% Plot the data
y_lims = [0.4, 0.6];

figure()
subplot(2,2,3)
hold on
plot_errp_f(x, m_p_correct', m_p_error', s_p_correct', s_p_error')
yline(decoder.threshold, '--k', 'LineWidth', 1);
ylim(y_lims);
title("means")
hold off

subplot(2,2,2)
hold on
plot(x, p_error')
ylim(y_lims);
title("p err")
xlim([x(1) x(end)]);
yline(decoder.threshold, '--k', 'LineWidth', 1);
grid on;
hold off


subplot(2,2,4)
hold on
plot(x, p_correct')
ylim(y_lims);
title("p corr")
xlim([x(1) x(end)]);
yline(decoder.threshold, '--k', 'LineWidth', 1);
grid on;
hold off

subplot(2,2,1)
classNames = {'no errp', 'errp'};
confusionchart(confMat, classNames);
sgtitle(['online ' subject]) 



%% other functions

function data = getVectorFromStr(str)
    str = erase(str, '[');
    str = erase(str, ']');

    data = str2double(str);
end

function plot_errp_f(t, correct, error, stdc, stde)

    hold on;
    plot_std(t, error, stde,'r');
    plot_std(t, correct, stdc,'b');
    % plot(t, error - correct, 'k', 'LineWidth', 2);
    legend('error', '', 'correct', '')
    hold off;
    
    xlim([t(1) t(end)]);
    grid on;

end

function plot_std(x, y,std_dev, c)    
    plot(x, y, c);
    patch([x flip(x)], [y-std_dev; flip(y+std_dev)], c, 'FaceAlpha',0.25, 'EdgeColor','none')
end

function data = nomalize_length(data_in)
    l = -1;
    for i = 1:length(data_in)
        l = max(length(data_in{i}), l);
    end

    l = 41;
    
    for i = 1:length(data_in)
        if l ~= length(data_in{i})
            m = mean(data_in{i});
            for j = length(data_in{i}):(l - 1)
                data_in{i} = [data_in{i}, m];
            end
        end
    end

    data = data_in;
end
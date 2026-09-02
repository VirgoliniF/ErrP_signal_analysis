clc; clear all; close all;

addpath(genpath(pwd), '-begin');

error_modality = 'visual'; %visual or vestibular ---> for vestibular USE acc_vestibular_errp_pipeline

if not (strcmp(error_modality, 'visual') || strcmp(error_modality, 'vestibular'))
    error('Modality not recognized')
end

subjects = {
        %'learn_errp_f2_3'
        'learn_errp_i7_2',
        'learn_errp_d7_4',
        'learn_errp_l4_2',
        'learn_errp_j3_2',
        'learn_errp_m1_2',
        'learn_errp_i1_2'
       };

excludepat  = {
  'fb',
};

%% Preprocessing
% Load the gdf
for idx_s = 1:length(subjects)
    settings = new_errp_load_setting(subjects(idx_s), error_modality);
    new_errp_prepare_gdf(subjects(idx_s), settings, 'learn');
    new_errp_prepare_bag(subjects(idx_s), settings, 'learn');
end

%% Grand Average

means_e = zeros(length(settings.t), length(settings.mask), length(subjects));
means_c = zeros(length(settings.t), length(settings.mask), length(subjects));

means_ee = zeros(length(settings.t), length(settings.eog_channels), length(subjects));
means_ec = zeros(length(settings.t), length(settings.eog_channels), length(subjects));

means_vle = zeros(length(settings.t), length(settings.eog_channels), length(subjects));
means_vlc = zeros(length(settings.t), length(settings.eog_channels), length(subjects));

vl = [];

r_vect = cell(length(subjects),1);

decoder_f = [];

roc_f = figure();
hold on
grid on

for idx_s = 1:length(subjects)
    includepat = subjects(idx_s);

    settings = new_errp_load_setting(includepat, error_modality);
    disp(settings)
    %% Load the data
    [T, Tu, E, Ek, Ck, eeg, eeg_un, settings, velz] = new_errp_load_data(includepat, excludepat, settings);

    %% Remove the blob in the frequence for some triald
    %[Ek, Ck, ~] = errp_filter_on_frequency(Tu, Ek, Ck, settings);

    %% Manual filter on subject
    [Ek, Ck] = events_manual_filter(Ek,Ck, settings);
    
    %% Step 0: check if the data is 1/f
    %errp_comput_f(eeg_un, settings);
    
    %% Print the data
    new_errp_print_grand_average(T, E, Ek, Ck, settings);

    %% Print the frequency
    [tf_neg, tf_neu, tf_diff, frex] = errp_compute_frequency(Tu, Ek, Ck, settings);
    new_errp_print_frequency(tf_neg, tf_neu, tf_diff, frex, settings);

    freq = struct;

    freq.neg = tf_neg;
    freq.neu = tf_neu;
    freq.dif = tf_diff;
    freq.frex = frex;

    r_vect{idx_s}.freq = freq;
    r_vect{idx_s}.settings = settings;


    %% Compute the means
    means_e(:,:,idx_s) = mean(T(:,:,Ek),3);
    means_c(:,:,idx_s) = mean(T(:,:,Ck),3);

    means_ee(:,:,idx_s) = mean(E(:,:,Ek),3);
    means_ec(:,:,idx_s) = mean(E(:,:,Ck),3);

    means_vle(:,:,idx_s) = nanmean(abs(velz(:,Ek)),2);
    means_vlc(:,:,idx_s) = nanmean(abs(velz(:,Ck)),2);

    vl = [vl abs(velz(:,Ek))];
    vl = [vl abs(velz(:,Ck))];
  
    if (settings.use_autoencoder == true)
        file_autoenceder = 'autoencers/' + string(subjects(idx_s)) + '_' + string(settings.spatialfilter) + '_' + string(settings.artifactrej) + '_autoencoder.mat';

        try
            load(file_autoenceder, "ae");
            disp("[io] - Autoencoder loaded from file.");
            settings.ae = ae;
        catch
            
            disp("[io] - Autoencoder crating from data.");

            settings.ae = errp_autoencoder(eeg(:,settings.classificator_channel_idx,:), settings);
            disp("[io] - Autoencoder save to file.");

            if ~isfolder("autoencers")
                mkdir("autoencers")
            end
            ae = settings.ae;
            save(file_autoenceder, 'ae');
        end

        % if settings.use_frequency == true
        %     file_autoencederf = 'autoencersf/' + string(subjects(idx_s)) + '_' + string(settings.spatialfilter) + '_' + string(settings.artifactrej) + '_autoencoder.mat';
        % 
        %     try
        %         load(file_autoenceder, "aef");
        %         disp("[io] - Autoencoder loaded from file.");
        %         settings.aef = aef;
        %     catch
        % 
        %         disp("[io] - Autoencoder crating from data.");
        % 
        %         settings.aef = errp_autoencoder_f(eeg(:,settings.classificator_channel_idx,:), settings);
        %         disp("[io] - Autoencoder save to file.");
        % 
        %         if ~isfolder("autoencersf")
        %             mkdir("autoencersf")
        %         end
        %         aef = settings.aef;
        %         save(file_autoenceder, 'aef');
        %     end
        % end
    end

    % %% Compute the null-hipotesys
    % if settings.check_movement_cue
    %     filename = ['mov_acc_' settings.includepat{1}];
    % else
    %     filename = ['vis_acc_' settings.includepat{1}];
    % end
    % try
    %     S = load(filename,'n_hip_acc');
    %     n_hip_acc = S.n_hip_acc;
    %     fprintf('Loaded null distribution from %s\n', filename);
    % 
    %     S = load([filename '_auc'],'n_hip_auc');
    %     n_hip_auc = S.n_hip_auc;
    %     fprintf('Loaded null distribution from %s\n', filename);
    % 
    %     % return;
    % catch
    %     fprintf('File not found, computing null distribution...\n');
    % 
    %     n_hip_acc = [];
    %     n_hip_auc = [];
    % 
    %     Nhip  = 10000;
    % 
    %     for i = 1:Nhip
    % 
    %         % shuffle Ek
    %         Ek_n = shuffle(Ek);
    %         Ck_n = 1 - Ek_n;
    % 
    %         if settings.use_frequency == true
    %             [~, ~, ~, accuracy_nh_it] = errp_create_classifier_freq(Tu, Ek_n, Ck_n, settings);
    %         else
    %             [~, ~, ~, accuracy_nh_it, a_auc_tmp, ~, ~] = errp_create_classifier_new(T, Tu, Ek_n, Ck_n, settings, roc_f);
    %         end
    % 
    %         a = max(a_auc_tmp);
    % 
    %         n_hip_auc = [n_hip_auc, a];
    %         n_hip_acc = [n_hip_acc, accuracy_nh_it];
    % 
    %         save(filename, 'n_hip_acc');
    %         save([filename '_auc'], 'n_hip_auc');
    % 
    % 
    %     end
    % 
    % end

    % %% Evaluate the classifier
    % 
    % if settings.use_frequency == true
    %     [decoder, main_output, main_corret, accuracy] = errp_create_classifier_freq(Tu, Ek, Ck, settings);
    % else
    %     [decoder, main_output, main_corret, accuracy, a_auc, X, Y] = errp_create_classifier_new(T, Tu, Ek, Ck, settings, roc_f);
    % end

    % Nhip  = 10000;
    % 
    % p_value = (sum(n_hip_auc>max(a_auc)) + 1 ) / (Nhip+1);
    % 
    % disp(["p_value: " p_value])
    % 
    % 
    % filename = ['p_value_mov_auc_' settings.includepat{1}];
    % save(filename, 'p_value');

    % decoder_f = errp_create_decoder_final(T, Tu, Ek, Ck, settings);
    % 
    % r_vect{idx_s}.dec = decoder_f;
    % r_vect{idx_s}.out = main_output;
    % r_vect{idx_s}.lab = main_corret;
    % r_vect{idx_s}.accuracy = accuracy;
    % % r_vect{idx_s}.p_value = p_value;
    % % r_vect{idx_s}.n_hip_acc = n_hip_acc;
    % r_vect{idx_s}.a_auc = a_auc;
    % r_vect{idx_s}.X = X;
    % r_vect{idx_s}.Y = Y;
    % v_e = nanmean(abs(velz(:,Ek)),2);
    % v_c = nanmean(abs(velz(:,Ck)),2);
    % 
    % r_vect{idx_s}.vel_mean = mean([v_e, v_c],2);


end


%%%%%%%%%%%%%%%%%%%%
% str = r_vect;
% nSubjects = numel(str);
% 
% % Step 1: Define a common X-axis for interpolation (e.g., 100 points from 0 to 1)
% commonX = linspace(0,1,100);
% 
% % Step 2: Initialize a matrix to store interpolated Y
% Yinterp = nan(nSubjects, numel(commonX));
% 
% for idx = 1:nSubjects
%     % Remove duplicate X-values
%     [Xunique, ia] = unique(str{idx}.X);
%     Yunique = str{idx}.Y(ia);
% 
%     % Interpolate Y onto common X-axis
%     Yinterp(idx,:) = interp1(Xunique, Yunique, commonX, 'linear');
% end

% % Step 3: Compute mean and std across subjects
% meanY = mean(Yinterp,1);
% stdY = std(Yinterp,0,1);
% 
% % Optional: plot
% f = figure;
% plot(commonX, meanY, 'b', 'LineWidth',2); hold on;
% fill([commonX fliplr(commonX)], [meanY+stdY fliplr(meanY-stdY)], 'b', 'FaceAlpha',0.2, 'EdgeColor','none');
% xlabel('False Positive Rate');
% ylabel('True Positive Rate');
% title('Mean ROC across subjects');
% print(f, 'average_roc.svg', '-dsvg', '-vector');

%%%%%%%%%%%%%%


settings = new_errp_load_setting("final", error_modality);
settings.settings = r_vect{1}.settings.settings;

% % main_auc_matrix
% a_auc = zeros(length( r_vect), length( r_vect{idx_s}.a_auc) );
% for i = 1:length(r_vect) 
%     a_auc(i,:) = r_vect{i}.a_auc;
% end
% a_auc_sdd =  std(a_auc);
% a_auc =  mean(a_auc);
% 
% f = figure
% t = 0:length(a_auc)-1;
% t = t/512 - 0.5;
% plot(t,a_auc, 'k', 'LineWidth', 2)
% 
% hold on
% 
% fill([t fliplr(t)], ...
%      [a_auc + a_auc_sdd fliplr(a_auc - a_auc_sdd)], ...
%      [0.8 0.8 1], ...      % light blue color
%      'EdgeColor', 'none', ...
%      'FaceAlpha', 0.5);    % transparency
% 
% 
% plot_vline(0, 'k');
% grid on
% 
% ylim([0 1])
% ylabel('mean AUC')
% xlabel('window starting time')
% 
% print(f, 'auc_over_time.svg', '-dsvg', '-vector');




% % Confusion matrix
% for i = 1:length(r_vect)       
%     fig = figure('Visible', 'off');
% 
% 
%     labels ={'Neutral', 'ErrP'};
% 
%     confMat = confusionmat(r_vect{i}.lab, r_vect{i}.out);
%     cm = confusionchart(confMat, labels);
% 
%     cm.FontSize = 20;
% 
%     title_tmp = subjects(i);
% 
%     cm.Title = title_tmp;
% 
%     %confusionchart(r_vect{i}.lab, r_vect{i}.out);
%     %title(subjects(i))
% 
%     % -----------------------------------------------------------
% 
%     if strcmp(data_owner, 'Francesca')
%         folder = 'presentations/imgs/confusion_matrix/';
%     else
%         folder = 'presentations//imgs/confusion_matrix/Piero';
%     end 
% 
%     if ~exist(folder, 'dir'); mkdir(folder); end
% 
%     if settings.check_movement_cue == true
%         folder = [ folder 'movement/' ];
%     else
%         folder = [ folder 'visual/' ];
%     end
% 
%     folder = [folder settings.mode '/'];
% 
%     folder = strjoin(folder, '');
% 
%     % Save the immages
%     if ~exist(folder, 'dir'); mkdir(folder); end
%     file = fullfile(folder, "plot_" + subjects(i) + ".png");
%     %set(gca, 'LooseInset', get(gca,'TightInset'));  % removes extra padding
%     %saveas(fig, fullfile(folder, "plot_" + setting.includepat{1} + ".png"));
% 
%     fig.Position = [100 100 800 800];
%     exportgraphics(fig, file, 'Resolution', settings.img_resolution);
%     close(fig)
% 
% 
% 
% end

%freq.neg  = cat(3, freq.neg {:});
%freq.neu  = cat(3, freq.neu {:});
%freq.dif  = cat(3, freq.dif {:});

freq = struct;

freq.neg = zeros(size(r_vect{1}.freq.neg,1), size(r_vect{1}.freq.neg,2), length(r_vect));
freq.neu = zeros(size(r_vect{1}.freq.neu,1), size(r_vect{1}.freq.neu,2), length(r_vect));
freq.dif = zeros(size(r_vect{1}.freq.dif,1), size(r_vect{1}.freq.dif,2), length(r_vect));


for i = 1:length(r_vect)
    freq.neg(:, :, i) = r_vect{i}.freq.neg;
    freq.neu(:, :, i) = r_vect{i}.freq.neu;
    freq.dif(:, :, i) = r_vect{i}.freq.dif;
end

settings.settings =  r_vect{1}.settings.settings;


n_t = cat(3, means_e, means_c);
n_et = cat(3, means_ee, means_ec);
n_e = zeros(length(subjects)*2,1);
n_e(1:length(subjects)) = 1;
n_c =  ones(length(subjects)*2,1) - n_e;
n_e = logical(n_e);
n_c = logical(n_c);

new_errp_print_average_across_subjects(n_t, n_et, n_e, n_c, settings, vl);

freq.neg  = mean(freq.neg,3);
freq.neu  = mean(freq.neu,3);
freq.dif  = mean(freq.dif,3);

new_errp_print_frequency(freq.neg, freq.neu, freq.dif,  r_vect{1}.freq.frex, settings);
% 
% 
% %% --------------------------------------------------------------------
% %    Try the decoder on the movement cue
% 
% new_roc_f = figure();
% 
% for idx_s = 1:length(subjects)
%     includepat = subjects(idx_s);
% 
%     settings = new_errp_load_setting(includepat, true);
% 
%     %% Load the data
%     [T, Tu, E, Ek, Ck, eeg, eeg_un, settings] = errp_load_data(includepat, excludepat, settings);
% 
%     %% Remove the blob in the frequence for some triald
%     %[Ek, Ck, ~] = errp_filter_on_frequency(Tu, Ek, Ck, settings);
% 
%     %[Ek, Ck] = events_manual_filter(Ek,Ck, settings);
% 
% 
%     %% Step 0: check if the data is 1/f
%     % errp_comput_f(eeg_un, settings);
% 
%     %% Print the data
%     errp_print_grand_average(T, E, Ek, Ck, settings);
% 
%     %% Print the frequency
%     [tf_neg, tf_neu, tf_diff, frex] = errp_compute_frequency(Tu, Ek, Ck, settings);
%     errp_print_frequency(tf_neg, tf_neu, tf_diff, frex, settings);
% 
%     freq = struct;
% 
%     freq.neg = tf_neg;
%     freq.neu = tf_neu;
%     freq.dif = tf_diff;
%     freq.frex = frex;
% 
%     r_vect{idx_s}.freq = freq;
%     r_vect{idx_s}.settings = settings;
% 
% 
%     %% Compute the means
%     means_e(:,:,idx_s) = mean(T(:,:,Ek),3);
%     means_c(:,:,idx_s) = mean(T(:,:,Ck),3);
% 
%     means_ee(:,:,idx_s) = mean(E(:,:,Ek),3);
%     means_ec(:,:,idx_s) = mean(E(:,:,Ck),3);
% 
%     % if (settings.use_autoencoder == true)
%     %     file_autoenceder = 'autoencers/' + string(subjects(idx_s)) + '_' + string(settings.spatialfilter) + '_' + string(settings.artifactrej) + '_autoencoder.mat';
%     % 
%     %     try
%     %         load(file_autoenceder, "ae");
%     %         disp("[io] - Autoencoder loaded from file.");
%     %         settings.ae = ae;
%     %     catch
%     % 
%     %         disp("[io] - Autoencoder crating from data.");
%     % 
%     %         settings.ae = errp_autoencoder(eeg(:,settings.classificator_channel_idx,:), settings);
%     %         disp("[io] - Autoencoder save to file.");
%     % 
%     %         if ~isfolder("autoencers")
%     %             mkdir("autoencers")
%     %         end
%     %         ae = settings.ae;
%     %         save(file_autoenceder, 'ae');
%     %     end
%     % 
%     %     % if settings.use_frequency == true
%     %     %     file_autoencederf = 'autoencersf/' + string(subjects(idx_s)) + '_' + string(settings.spatialfilter) + '_' + string(settings.artifactrej) + '_autoencoder.mat';
%     %     % 
%     %     %     try
%     %     %         load(file_autoenceder, "aef");
%     %     %         disp("[io] - Autoencoder loaded from file.");
%     %     %         settings.aef = aef;
%     %     %     catch
%     %     % 
%     %     %         disp("[io] - Autoencoder crating from data.");
%     %     % 
%     %     %         settings.aef = errp_autoencoder_f(eeg(:,settings.classificator_channel_idx,:), settings);
%     %     %         disp("[io] - Autoencoder save to file.");
%     %     % 
%     %     %         if ~isfolder("autoencersf")
%     %     %             mkdir("autoencersf")
%     %     %         end
%     %     %         aef = settings.aef;
%     %     %         save(file_autoenceder, 'aef');
%     %     %     end
%     %     % end
%     % end
%     %% compute the null hip
% 
%     if settings.check_movement_cue
%         filename = ['movtovis_acc_' settings.includepat{1}];
%     else
%         filename = ['vistomov_acc_' settings.includepat{1}];
%     end
%     try
%         S = load(filename,'n_hip_acc');
%         n_hip_acc = S.n_hip_acc;
%         fprintf('Loaded null distribution from %s\n', filename);
% 
%         S = load([filename '_auc'],'n_hip_auc');
%         n_hip_auc = S.n_hip_auc;
%         fprintf('Loaded null distribution from %s\n', filename);
% 
%         % return;
%     catch
%         fprintf('File not found, computing null distribution...\n');
% 
%         n_hip_acc = [];
%         n_hip_auc = [];
% 
%         Nhip  = 10000;
% 
%         for i = 1:Nhip
% 
%             % shuffle Ek
%             Ek_n = shuffle(Ek);
%             Ck_n = 1 - Ek_n;
% 
%             [main_output, main_prob] = errp_evaluate_classifier(T, r_vect{idx_s}.dec, settings);
%             [accuracy_nh_it, AUC] = errp_print_prob_time(main_prob, Ek, Ck, settings, r_vect{idx_s}, new_roc_f);
% 
%             a = max(AUC);
% 
%             n_hip_auc = [n_hip_auc, a];
%             n_hip_acc = [n_hip_acc, accuracy_nh_it];
% 
%             save(filename, 'n_hip_acc');
%             save([filename '_auc'], 'n_hip_auc');
% 
% 
%         end
% 
%     end
% 
% 
%     %% Evaluate the classifier
% 
%     [main_output, main_prob] = errp_evaluate_classifier(T, r_vect{idx_s}.dec, settings);
% 
%     [r_vect{idx_s}.move_acc, AUC] = errp_print_prob_time(main_prob, Ek, Ck, settings, r_vect{idx_s}, new_roc_f);
%     %r_vect{idx_s}.move_acc = 0;
% 
% 
% end
% 
% settings = new_errp_load_setting("final", true);
% settings.settings =  r_vect{1}.settings.settings;
% 
% 
% freq = struct;
% 
% freq.neg = zeros(size(r_vect{1}.freq.neg,1), size(r_vect{1}.freq.neg,2), length(r_vect));
% freq.neu = zeros(size(r_vect{1}.freq.neu,1), size(r_vect{1}.freq.neu,2), length(r_vect));
% freq.dif = zeros(size(r_vect{1}.freq.dif,1), size(r_vect{1}.freq.dif,2), length(r_vect));
% 
% 
% for i = 1:length(r_vect)
%     freq.neg(:, :, i) = r_vect{i}.freq.neg;
%     freq.neu(:, :, i) = r_vect{i}.freq.neu;
%     freq.dif(:, :, i) = r_vect{i}.freq.dif;
% end
% 
% settings.settings =  r_vect{1}.settings.settings;
% 
% 
% n_t = cat(3, means_e, means_c);
% n_et = cat(3, means_ee, means_ec);
% n_e = zeros(length(subjects)*2,1);
% n_e(1:length(subjects)) = 1;
% n_c =  ones(length(subjects)*2,1) - n_e;
% n_e = logical(n_e);
% n_c = logical(n_c);
% 
% errp_print_average_across_subjects(n_t, n_et, n_e, n_c, settings);
% 
% freq.neg  = mean(freq.neg,3);
% freq.neu  = mean(freq.neu,3);
% freq.dif  = mean(freq.dif,3);
% 
% errp_print_frequency(freq.neg, freq.neu, freq.dif,  r_vect{1}.freq.frex, settings);
% 
% 
% % Print accuracy 
% % Combine the data into a single vector
% data = zeros(length(subjects),2);
% for idx_s = 1:length(subjects)
%      data(idx_s,1) = r_vect{idx_s}.accuracy;
%      data(idx_s,2) = r_vect{idx_s}.move_acc;
% end
% 
% % Create group labels
% group = [repmat({'Visual'}, 1, length(subjects)), repmat({'Movement'}, 1, length(subjects))];
% 
% % Create the boxplot
% fig = figure('Visible', 'off');
% boxplot(data, group);
% 
% set(findobj(gca, 'Tag', 'Box'), 'LineWidth', 2);
% set(findobj(gca, 'Tag', 'Median'), 'LineWidth', 2);
% set(findobj(gca, 'Tag', 'Whisker'), 'LineWidth', 2);
% set(findobj(gca, 'Tag', 'Caps'), 'LineWidth', 2);
% set(findobj(gca, 'Tag', 'Outliers'), 'MarkerSize', 6);
% 
% ylim([0.4 1])
% 
% % Optional: customize plot
% ylabel('Accuracy', 'FontWeight', 'bold', 'FontSize', 12);
% title('Accuracy Comparison Between Experiments','FontWeight', 'bold', 'FontSize', 14);
% set(gca, 'FontWeight', 'bold', 'LineWidth', 2, 'FontSize', 12);
% grid on;
% hold on;
% 
% % Plot paired lines
% for i = 1:length(subjects)
%     plot([1, 2], [data(i,1), data(i,2)], '-o', 'Color', [0.5 0.5 0.5 0.5], 'LineWidth', 2, 'MarkerSize', 8);
% end
% 
% 
% % -----------------------------------------------------------
% folder = 'presentations/imgs/acc/';
% if ~exist(folder, 'dir'); mkdir(folder); end
% 
% 
% file = fullfile(folder, "plot_accuracy.png");
% set(gca, 'LooseInset', get(gca,'TightInset'));  % removes extra padding
% 
% fig.Position = [100 100 1600 800];
% exportgraphics(fig, file, 'Resolution', settings.img_resolution);
% close(fig)
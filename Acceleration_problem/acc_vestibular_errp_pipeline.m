clc; clear all; close all;

addpath(genpath(pwd), '-begin');

error_modality = 'vestibular'; %visual or vestibular

if not(strcmp(error_modality, 'visual') || strcmp(error_modality, 'vestibular'))
    error('Modality not recognized')
end

subjects = {
        'learn_errp_d7_4',
        'learn_errp_i7_2', 
        %'learn_errp_f2_3'
        'learn_errp_l4_2',
        'learn_errp_j3_2',
        'learn_errp_m1_2',
        'learn_errp_i1_2'
       };

excludepat = {
  'fb',
};

% Difficulty categories to detect in bag file names.
% The pipeline loads each subject's data ONCE, then splits trials by the
% bag file they came from (using bagsfiles + trial_Rk from load_data).
% If none of the bag files contain a difficulty tag, the pipeline behaves
% exactly as before (only the unfiltered pass runs).
difficulty_categories = {'high', 'medium', 'low'};

% Rename bags before any processing
rename_bags(subjects, error_modality);

%% -----------------------------------------------------------------------
%  Preprocessing  –  always with the bare subject name so ALL raw files
%  are processed regardless of difficulty tag.
% -----------------------------------------------------------------------
for idx_s = 1:length(subjects)
    settings = new_errp_load_setting(subjects(idx_s), error_modality);
    new_errp_prepare_gdf(subjects(idx_s), settings, 'learn');
    new_errp_prepare_bag(subjects(idx_s), settings, 'learn');
end

%% -----------------------------------------------------------------------
%  Accumulator struct – one entry per category ('' = unfiltered original)
% -----------------------------------------------------------------------
all_cats = [{''}  difficulty_categories];   % '' first = original behaviour

acc = struct();
for cIdx = 1:length(all_cats)
    fn = cat_fieldname(all_cats{cIdx});
    acc.(fn).means_e  = [];
    acc.(fn).means_c  = [];
    acc.(fn).means_ee = [];
    acc.(fn).means_ec = [];
    acc.(fn).vl       = [];
    acc.(fn).r_vect   = {};
end

roc_f = figure();
hold on; grid on;

%% -----------------------------------------------------------------------
%  Main subject loop
% -----------------------------------------------------------------------
for idx_s = 1:length(subjects)

    subject_cell = subjects(idx_s);   % 1x1 cell

    settings = new_errp_load_setting(subject_cell, error_modality);
    disp(settings)

    %% Load data ONCE per subject.
    % acc_errp_load_data now also returns:
    %   trial_Rk  – [ntrials x 1] integer: which bag file each trial is from
    %   bagsfiles – cell of aligned bag .mat paths (Rk==k -> bagsfiles{k})
    [T, Tu, E, Ek, Ck, eeg, eeg_un, settings, velz, trial_Rk, bagsfiles] = ...
        acc_errp_load_data(subject_cell, excludepat, settings);

    fprintf('[debug-T] T all-zero trials: %d / %d\n', sum(all(all(T==0,1),2)), size(T,3));
    fprintf('[debug-T] twist.z length: %d, eeg length: %d\n', ...
    size(eeg,1), size(eeg,1));   % replace with actual twist length if accessible
    fprintf('[debug-T] mean of T across Ek trials: %.6f\n', mean(mean(mean(T(:,:,Ek)))));

    %% Manual filter on subject (applied once, on the full trial set)
    [Ek, Ck] = events_manual_filter(Ek, Ck, settings);

    %% Detect which difficulty categories are present in this subject's bags
    % A category is "present" when at least one bag file name contains it.
    present_cats = {};
    for k = 1:length(difficulty_categories)
        tag = difficulty_categories{k};
        if any(contains(bagsfiles, ['_' tag]))
            present_cats{end+1} = tag; 
            fprintf('[detect] Subject "%s": found category "%s".\n', ...
                char(subject_cell{1}), tag);
        end
    end

    % Build the list of passes for this subject:
    %   always run the unfiltered pass (''), plus one per detected category.
    cats_for_subject = [{''}  present_cats];

    %% -----------------------------------------------------------------------
    %  Per-category pass  –  no reloading, just subset Ek/Ck by trial_Rk
    % -----------------------------------------------------------------------
    for cIdx = 1:length(cats_for_subject)
        category = cats_for_subject{cIdx};

        if isempty(category)
            % Unfiltered: use all trials (original behaviour)
            Ek_cat = Ek;
            Ck_cat = Ck;
            velz_cat = velz;
        else
            % Find which Rk values correspond to bags of this category
            cat_rk_mask = contains(bagsfiles, ['_' category]);   % logical [nBags x 1]
            cat_rk_ids  = find(cat_rk_mask);                     % Rk integers for this cat

            % Restrict Ek/Ck to trials whose bag run is in cat_rk_ids
            trial_in_cat = ismember(trial_Rk, cat_rk_ids);
            Ek_cat   = Ek & trial_in_cat;
            Ck_cat   = Ck & trial_in_cat;
            velz_cat = velz;   % full matrix; indexing via Ek_cat/Ck_cat below
        end

        % Skip if no trials survive for this category
        if sum(Ek_cat) == 0 && sum(Ck_cat) == 0
            fprintf('[pipeline] Category "%s", subject "%s": no trials – skipping.\n', ...
                category, char(subject_cell{1}));
            continue;
        end

        % Build category-specific settings (title + output filename)
        settings_cat = settings;
        if isempty(category)
            settings_cat.includepat = subject_cell;
        else
            settings_cat.includepat = {[char(subject_cell{1}) '_' category]};
            settings_cat.title      = [settings.title ' | ' upper(category)];
        end

        %% Per-subject grand average plot
        new_errp_print_grand_average(T, E, Ek_cat, Ck_cat, settings_cat);

        %% Frequency plots
        errp_compute_frequency(Tu, Ek, Ck, settings_cat);

        %% Frequency analysis
        [tf_neg, tf_neu, tf_diff, frex] = errp_compute_frequency(Tu, Ek_cat, Ck_cat, settings_cat);
        new_errp_print_frequency(tf_neg, tf_neu, tf_diff, frex, settings_cat);

        freq_sub      = struct();
        freq_sub.neg  = tf_neg;
        freq_sub.neu  = tf_neu;
        freq_sub.dif  = tf_diff;
        freq_sub.frex = frex;

        %% Accumulate means for across-subjects plot
        fn = cat_fieldname(category);
        n = idx_s;   % replace:  n = size(acc.(fn).means_e, 3) + 1; 

        n_t  = length(settings_cat.t);
        n_ch = length(settings_cat.mask);
        n_eo = length(settings_cat.eog_channels);

        % if n == 1
        %     acc.(fn).means_e  = zeros(n_t, n_ch, length(subjects));
        %     acc.(fn).means_c  = zeros(n_t, n_ch, length(subjects));
        %     acc.(fn).means_ee = zeros(n_t, n_eo, length(subjects));
        %     acc.(fn).means_ec = zeros(n_t, n_eo, length(subjects));
        % end

        if idx_s == 1
            acc.(fn).means_e  = zeros(n_t, n_ch, length(subjects));
            acc.(fn).means_c  = zeros(n_t, n_ch, length(subjects));
            acc.(fn).means_ee = zeros(n_t, n_eo, length(subjects));
            acc.(fn).means_ec = zeros(n_t, n_eo, length(subjects));
        end

        acc.(fn).means_e(:, :, n)  = mean(T(:, :, Ek_cat), 3);
        acc.(fn).means_c(:, :, n)  = mean(T(:, :, Ck_cat), 3);
        acc.(fn).means_ee(:, :, n) = mean(E(:, :, Ek_cat), 3);
        acc.(fn).means_ec(:, :, n) = mean(E(:, :, Ck_cat), 3);


       % check
        fprintf('[debug-acc] fn=%s, n=%d, written means_e range: [%.6f, %.6f]\n', ...
            fn, n, min(min(acc.(fn).means_e(:,:,n))), max(max(acc.(fn).means_e(:,:,n))));

        % vl: keep only the columns (trials) belonging to this category
        acc.(fn).vl = [acc.(fn).vl  abs(velz_cat(:, Ek_cat))  abs(velz_cat(:, Ck_cat))];

        r_entry.freq     = freq_sub;
        r_entry.settings = settings_cat;
        acc.(fn).r_vect{end+1} = r_entry;

    end  % category loop
end  % subject loop


%% -----------------------------------------------------------------------
%  Across-subjects plots  –  one per category (including unfiltered)
% -----------------------------------------------------------------------
for cIdx = 1:length(all_cats)
    category = all_cats{cIdx};
    fn       = cat_fieldname(category);

    r_vect = acc.(fn).r_vect;
    if isempty(r_vect)
        fprintf('[pipeline] Category "%s": no data accumulated – skipping across-subjects plot.\n', category);
        continue;
    end

    n_subj   = length(r_vect);
    means_e  = acc.(fn).means_e(:,  :, 1:n_subj);
    means_c  = acc.(fn).means_c(:,  :, 1:n_subj);
    means_ee = acc.(fn).means_ee(:, :, 1:n_subj);
    means_ec = acc.(fn).means_ec(:, :, 1:n_subj);
    vl       = acc.(fn).vl;

    % "Final" settings: use the same includepat logic as above so the
    % output filename is e.g. plot_final.png / plot_final_high.png
    if isempty(category)
        final_includepat = {'final'};
    else
        final_includepat = {['final_' category]};
    end

    settings_final = new_errp_load_setting(final_includepat, error_modality);
    settings_final.settings = r_vect{1}.settings.settings;

    if ~isempty(category)
        settings_final.title = [settings_final.title ' | ' upper(category)];
    end

    % Build index vectors (same logic as original pipeline)
    n_t  = cat(3, means_e, means_c);
    n_et = cat(3, means_ee, means_ec);
    n_e  = false(n_subj * 2, 1);
    n_e(1:n_subj) = true;
    n_c  = ~n_e;

    % Check
    fprintf('[debug] category=%s, n_subj=%d\n', category, n_subj);
    fprintf('[debug] means_e range: [%.4f, %.4f]\n', min(means_e(:)), max(means_e(:)));
    fprintf('[debug] means_c range: [%.4f, %.4f]\n', min(means_c(:)), max(means_c(:)));
    fprintf('[debug] sum(Ek_cat)=%d, sum(Ck_cat)=%d\n', sum(Ek_cat), sum(Ck_cat));
    fprintf('[debug-rk] unique trial_Rk values: %s\n', num2str(unique(trial_Rk)'));
    fprintf('[debug-rk] length(bagsfiles): %d\n', length(bagsfiles));

    new_errp_print_average_across_subjects(n_t, n_et, n_e, n_c, settings_final, vl);

    % Frequency across subjects
    freq = struct();
    freq.neg = zeros(size(r_vect{1}.freq.neg, 1), size(r_vect{1}.freq.neg, 2), n_subj);
    freq.neu = zeros(size(r_vect{1}.freq.neu, 1), size(r_vect{1}.freq.neu, 2), n_subj);
    freq.dif = zeros(size(r_vect{1}.freq.dif, 1), size(r_vect{1}.freq.dif, 2), n_subj);

    for i = 1:n_subj
        freq.neg(:, :, i) = r_vect{i}.freq.neg;
        freq.neu(:, :, i) = r_vect{i}.freq.neu;
        freq.dif(:, :, i) = r_vect{i}.freq.dif;
    end

    freq.neg = mean(freq.neg, 3);
    freq.neu = mean(freq.neu, 3);
    freq.dif = mean(freq.dif, 3);

    new_errp_print_frequency(freq.neg, freq.neu, freq.dif, r_vect{1}.freq.frex, settings_final);

end  % across-subjects loop


%% -----------------------------------------------------------------------
%  Local helper function
% -----------------------------------------------------------------------

function fn = cat_fieldname(category)
% Convert category string to a valid MATLAB struct field name.
%   ''       -> 'all'
%   'high'   -> 'cat_high'   etc.
    if isempty(category)
        fn = 'all';
    else
        fn = ['cat_' category];
    end
end

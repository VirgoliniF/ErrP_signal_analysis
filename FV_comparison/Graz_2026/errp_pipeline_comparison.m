clc; clear all; close all;
addpath(genpath(pwd), '-begin');

excludepat = {'fb'};

%% Define the three experimental conditions
conditions = {
    struct('data_owner', 'Piero',     'owner', 'Piero', 'piero_analysis', 'visual'),
    struct('data_owner', 'Piero',     'owner', 'Piero', 'piero_analysis', 'movement'),
    struct('data_owner', 'Francesca', 'owner', 'Francesca', 'piero_analysis', 'movement')
};
n_conditions = length(conditions);

%% Subject lists per data_owner
subjects_Francesca = {
    'learn_errp_i7_1',
    'learn_errp_d7_2',
    'learn_errp_i1_1',
    'learn_errp_l4_1',
    'learn_errp_j2_1',
    %'learn_errp_j3_1'
};

subjects_Piero = {
    'learn_errp_d7_1',
    'learn_errp_i1_1',
    'learn_errp_i7_2',
    'learn_errp_j2_4',
    %'learn_errp_j3_2',
    'learn_errp_l4_1'
};

%% Analyze velocity?
vel_analysis = false;

%% Storage across conditions
all_data = cell(n_conditions, 1);  % will hold per-condition results

%% Loop over conditions
for idx_c = 1:n_conditions
    cond = conditions{idx_c};
    
    % Select subjects based on data_owner
    if strcmp(cond.data_owner, 'Francesca')
        subjects = subjects_Francesca;
    else
        subjects = subjects_Piero;
    end
    n_subjects = length(subjects);
    
    %% Preprocessing (only needed once per data_owner, but safe to repeat)
    for idx_s = 1:n_subjects
        settings = errp_load_setting(subjects(idx_s), false, cond);
        % Override the two condition-specific fields before preparing data
        settings.data_owner    = cond.data_owner;
        settings.owner         = cond.owner;
        settings.piero_analysis = cond.piero_analysis;
        errp_prepare_gdf(subjects(idx_s), settings, 'learn');
        errp_prepare_bag(subjects(idx_s), settings, 'learn');
    end
    
    %% Preallocate accumulators for this condition
    % (sizes determined after first settings load)
    settings = errp_load_setting(subjects(1), false, cond);
    settings.data_owner    = cond.data_owner;
    settings.owner          = cond.owner;
    settings.piero_analysis = cond.piero_analysis;

    means_e   = zeros(length(settings.t), length(settings.mask),         n_subjects);
    means_c   = zeros(length(settings.t), length(settings.mask),         n_subjects);
    means_ee  = zeros(length(settings.t), length(settings.eog_channels), n_subjects);
    means_ec  = zeros(length(settings.t), length(settings.eog_channels), n_subjects);
    means_vle = zeros(length(settings.t), length(settings.eog_channels), n_subjects);
    means_vlc = zeros(length(settings.t), length(settings.eog_channels), n_subjects);
    vl        = [];
    r_vect    = cell(n_subjects, 1);

    %% Load data and compute per-subject means
    for idx_s = 1:n_subjects
        includepat = subjects(idx_s);
        settings   = errp_load_setting(includepat, false, cond);
        
        % ---- inject condition-specific parameters ----
        settings.data_owner    = cond.data_owner;
        settings.owner          = cond.owner;
        settings.piero_analysis = cond.piero_analysis;
        % ----------------------------------------------
        
        if vel_analysis ~= true
            [T, Tu, E, Ek, Ck, Dk, eeg, eeg_un, settings, velz] = errp_load_data(includepat, excludepat, settings);
            [Ek, Ck] = events_manual_filter(Ek, Ck, settings);
            %% Store per-subject results for later (grand average per condition)
            r_vect{idx_s}.settings = settings;
        else 
            %Francesca 30.03.26
            %sat_vel(idx_s) = settings.saturation_vel;
            [T, Tu, E, Ek, Ck, Dk, eeg, eeg_un, setting, velz, twist, ePOS, eTYP] = errp_load_data_velocities(includepat,excludepat, settings);
            % Store velocity fields into local r_vect (not all_data directly)
            r_vect{idx_s}.twist = twist;
            r_vect{idx_s}.ePOS  = ePOS;
            r_vect{idx_s}.Ek    = Ek;
            r_vect{idx_s}.Ck    = Ck;
            r_vect{idx_s}.subj  = subjects{idx_s};
            [Ek, Ck] = events_manual_filter(Ek, Ck, settings);
            % Update Ek/Ck after manual filter
            r_vect{idx_s}.Ek_filtered = Ek;
            r_vect{idx_s}.Ck_filtered = Ck;
            r_vect{idx_s}.settings = settings;
        end


        [tf_neg, tf_neu, tf_diff, frex] = errp_compute_frequency(Tu, Ek, Ck, settings);
        freq_s = struct('neg', tf_neg, 'neu', tf_neu, 'dif', tf_diff, 'frex', frex);
        r_vect{idx_s}.freq = freq_s;

        means_e(:,:,idx_s)   = mean(T(:,:,Ek), 3);
        means_c(:,:,idx_s)   = mean(T(:,:,Ck), 3);
        means_ee(:,:,idx_s)  = mean(E(:,:,Ek), 3);
        means_ec(:,:,idx_s)  = mean(E(:,:,Ck), 3);
        means_vle(:,:,idx_s) = nanmean(abs(velz(:,Ek)), 2);
        means_vlc(:,:,idx_s) = nanmean(abs(velz(:,Ck)), 2);
        vl = [vl abs(velz(:,Ek)) abs(velz(:,Ck))];
    end

    %% Pack everything for this condition
    all_data{idx_c}.means_e   = means_e;
    all_data{idx_c}.means_c   = means_c;
    all_data{idx_c}.means_ee  = means_ee;
    all_data{idx_c};  % Print time of peak maximum negativityx_c}.means_ec  = means_ec;
    all_data{idx_c}.vl        = vl;
    all_data{idx_c}.r_vect    = r_vect;
    all_data{idx_c}.settings  = settings;   % last subject's settings (shared structure)
    all_data{idx_c}.cond      = cond;
    all_data{idx_c}.n_subjects = n_subjects;

    % francesca 30.03.26
    %all_data{idx_c}.sat_vel = sat_vel;   % [1 × n_subjects]
end

% Print maximum velocities
% for idx_c = 1:n_conditions
%     fprintf('Condition %d (%s / %s):\n', idx_c, conditions{idx_c}.owner, conditions{idx_c}.piero_analysis);
%     fprintf('  Per subject: '); fprintf('%.1f  ', all_data{idx_c}.sat_vel); fprintf('\n');
%     fprintf('  Max across subjects: %.1f\n', max(all_data{idx_c}.sat_vel));
% end

% %% Grand Average + Plotting — one call per condition
% for idx_c = 1:n_conditions
%     d        = all_data{idx_c};
%     settings = d.settings;
%     settings.settings = d.r_vect{1}.settings.settings;
% 
%     n_t  = cat(3, d.means_e, d.means_c);
%     n_et = cat(3, d.means_ee, d.means_ec);
% 
%     n_e = zeros(d.n_subjects * 2, 1);
%     n_e(1:d.n_subjects) = 1;
%     n_c = ones(d.n_subjects * 2, 1) - n_e;
%     n_e = logical(n_e);
%     n_c = logical(n_c);
% 
%     % Grand average plot for this condition
%     errp_print_grand_average(... % ← your per-subject call if still needed
%         [], [], [], [], settings);  % adjust args as required
%     errp_print_average_across_subjects(n_t, n_et, n_e, n_c, settings, d.vl);
% 
%     % Frequency
%     r_vect = d.r_vect;
%     freq.neg = zeros(size(r_vect{1}.freq.neg,1), size(r_vect{1}.freq.neg,2), d.n_subjects);
%     freq.neu = zeros(size(r_vect{1}.freq.neu,1), size(r_vect{1}.freq.neu,2), d.n_subjects);
%     freq.dif = zeros(size(r_vect{1}.freq.dif,1), size(r_vect{1}.freq.dif,2), d.n_subjects);
%     for i = 1:d.n_subjects
%         freq.neg(:,:,i) = r_vect{i}.freq.neg;
%         freq.neu(:,:,i) = r_vect{i}.freq.neu;
%         freq.dif(:,:,i) = r_vect{i}.freq.dif;
%     end
%     freq.neg = mean(freq.neg, 3);
%     freq.neu = mean(freq.neu, 3);
%     freq.dif = mean(freq.dif, 3);
%     errp_print_frequency(freq.neg, freq.neu, freq.dif, r_vect{1}.freq.frex, settings);
% end

%% Comparison plot across all conditions
errp_print_average_comparison(all_data);
% errp_print_subject_differences(all_data);
% errp_print_topoplot_comparison(all_data);
% errp_print_subject_variability(all_data);
% errp_plot_topo_fig(all_data, false);
% errp_print_subject_variability_accel(all_data); 
%errp_print_vel_accel_overlay2(all_data);
%errp_print_average_comparison_zoomed(all_data);
if vel_analysis == true
    errp_plot_velocity_profiles(all_data);
end
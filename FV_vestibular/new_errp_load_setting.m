function [setting] = new_errp_load_setting(includepat, error_modality)

    if (nargin < 3)
        check_movement_cue = false;
    end
    
    setting.error_modality = error_modality;

    setting.spatialfilter = 'laplacian'; %  {'csd', 'car', 'none', 'laplacian'}
    setting.artifactrej   = 'none'; % {'FORCe', 'none', 'ica'}

    setting.baseline_correction = false;
    setting.with_delay  = false;

    setting.manual_clean  = false;

    reverse = false;

    setting.check_movement_cue = check_movement_cue;

    setting.delta_topo = 0.2;
    if setting.check_movement_cue == true
        setting.delta_topo = 0.4;
    end

    setting.includepat = includepat;
    disp(['includepat: ', includepat])

    setting.cap = 'errp'; %  {'norm', 'errp'} _ {'', 'acc'}

    [mask, sensors, chanlocspath] = get_mask_labels(setting.cap);
    setting.remove_mask = {};

    setting.mask = mask;
    setting.chanlocspath = chanlocspath;

    setting.sensors = sensors;

    setting.mask = setdiff(mask, setting.remove_mask, 'stable');

    setting.ev_cod = get_comand_codecs(error_modality);
    setting.ev_mode = 'default';% {'default', 'active'}

    %setting.epoch = [-0.5, 1.05];
    setting.epoch = [-0.2, 1.05];


    setting.delta_t = 0.0; %% SHOULD BE 0.0
    if reverse
         setting.delta_t = 0.2;
    end

    setting.decoder_window = [0.0, 1.0]  + setting.delta_t;

    setting.downsample_ratio = 1;
    
    setting.samplerate = 512;
    setting.t = setting.epoch(1):1/setting.samplerate:setting.epoch(2);
    setting.dt = downsample(setting.t, setting.downsample_ratio);

    setting.refchannel     = {'fcz'}; %fcz o cz
    setting.sec_refchannel = {'fz'}; %fz o fcz

    setting = set_channel_idx(setting);

    setting.eog_channels = sensors; %{'af3', 'af4'}; % {'EOG'};

    setting.refractory   = 0.0; %length(epoch(1):1/samplerate:epoch(2));
    setting.max_peak     = 35 ;%18;
    setting.max_peak_eog = 35; %25;
    setting.refvel       = 200;

    setting.y_li = [-8.0 8.0];
    setting.range_v = [-15 15];
    setting.range_f = [-10 10];

    setting.title = build_title(includepat, setting.error_modality);

    setting = set_classificator_msk(setting);
    setting = set_classifiers(setting);

    setting.img_resolution = 300; % I like 300

    setting.remove_double_errors = false; 


end

function [setting_new] = set_classifiers(setting)
    setting.use_autoencoder = false;
    setting.use_frequency   = false;
    setting.use_sub_windows = false;


    setting.decoder.use_reiman = true;
    setting.decoder.use_sdn    = false;
    setting.decoder.use_svm    = false; % NO
    setting.decoder.use_gau    = false;
    setting.decoder.use_bilstm = false;
    setting.decoder.use_lstm   = false;
    setting.decoder.use_gru    = false;
    setting.decoder.use_csp    = false;
    setting.decoder.use_wave   = false;

    setting.overlap = 1;


    if setting.use_sub_windows == true
        setting.sub_windows.overlap = 32;
        setting.sub_windows.size = 0.2;
        setting.sub_windows.length  = round(setting.sub_windows.size * setting.samplerate);
    end


    setting = set_mode(setting);

    setting_new = setting;
end

function [setting_new] = set_mode(setting)
    fields = fieldnames(setting.decoder);
    active = {};
    
    for i = 1:numel(fields)
        if setting.decoder.(fields{i})
            active{end+1} = fields{i};
        end
    end
    
    fields_top = fieldnames(setting);
    for i = 1:numel(fields_top)
        if islogical(setting.(fields_top{i})) && setting.(fields_top{i})
            active{end+1} = fields_top{i};
        end
    end

    mode  = '';

    for i = 1:length(active)
        mode = [mode '_' active(i)];
    end

    setting.mode = mode;

    setting_new = setting;
end

function [title] = build_title(includepat, error_modality)

    if strcmp(error_modality, 'visual')
        task = 'Visual Feedback';
    else
        task = 'Movement Feedback';
    end 

    tmp_name = strrep(char(includepat(1)), 'learn_errp_','');

    title = [ tmp_name ' | ' char(task)];
end



function[ev_cod] = get_comand_codecs(error_modality)

    if strcmp(error_modality, 'visual')
        MASK_N = 'FEEDBACK';
    elseif strcmp(error_modality, 'vestibular')
        MASK_N = 'COMMAND';
    else
        error('Wrong MASK_N settings')
    end
   
    mask_name = {'CAMERA', 'BUTTON', 'COMMAND', 'AUDIO', 'FEEDBACK'};
    mask_value = [0, 80, 260, 40, 30];
    
    [~, id_m ] = ismember(upper(MASK_N), upper(mask_name));
    MASK = mask_value(id_m);

    ev_cod.CommandLx   =  101 + MASK; %361
    ev_cod.CommandRx   =  103 + MASK; %363
    ev_cod.ErrorLx     = 5101 + MASK; %5361
    ev_cod.ErrorRx     = 5103 + MASK; %5363
    % Francesca 04.03.26
    ev_cod.MovErrLeft  =  201 + MASK; %461
    ev_cod.MovErrRight =  203 + MASK; %463
    ev_cod.ErrLxMov    = 5201 + MASK; %5461
    ev_cod.ErrRxMov    = 5203 + MASK; %5463

    % ev_cod.Stop        =  100 + MASK;
    % ev_cod.CommandFx   =  102 + MASK;
    % ev_cod.NoReleaseLx = 4101 + MASK;
    % ev_cod.NoReleaseFx = 4102 + MASK;
    % ev_cod.NoReleaseRx = 4103 + MASK;

end

function [setting_new] = set_channel_idx(setting)   
    [~,refchannelidx] = ismember(upper(setting.refchannel), upper(setting.mask));
    setting.refchannelidx = refchannelidx;
    
    [~,refchannelidx] = ismember(upper(setting.sec_refchannel), upper(setting.mask));
    setting.sec_refchannelidx = refchannelidx;

    setting_new = setting;
end

function [setting_new] = set_classificator_msk(setting)
    %     ________                           __    
    %    / ____/ /_  ____ _____  ____  ___  / _____
    %   / /   / __ \/ __ `/ __ \/ __ \/ _ \/ / ___/
    %  / /___/ / / / /_/ / / / / / / /  __/ (__  ) 
    %  \____/_/ /_/\__,_/_/ /_/_/ /_/\___/_/____/  

    setting.classificator_channel = { 'F1', 'Fz', 'F2', 'FC1', 'FCz', 'FC2', 'C1', 'Cz', 'C2',  'CP1',  'CPz',  'CP2'};
    % setting.classificator_channel = { 'FCz','Cz', 'CPz'};
    % setting.classificator_channel  = { 'AF3', 'AF4','F3', 'F1', 'Fz', 'F2', 'F4', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'C3', 'C1', 'Cz', 'C2', 'C4', 'CP3', 'CP1',  'CPz',  'CP2','CP4','P3', 'P1', 'Pz','P2', 'P4',    'PO3',  'POz',    'PO4',   'O1',     'O2' };


    [~,refchannelidx] = ismember(upper(setting.classificator_channel), upper(setting.mask));
    setting.classificator_channel_idx = refchannelidx;

    setting_new = setting;
end

function [mask, sensors, chanlocspath] = get_mask_labels(type)
    % Load the cap information
    errp_cap = { 'AF3', 'AF4','F3', 'F1', 'Fz', 'F2', 'F4', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'C3', 'C1', 'Cz', 'C2', 'C4', 'CP3', 'CP1',  'CPz',  'CP2','CP4','P3', 'P1', 'Pz','P2', 'P4',    'PO3',  'POz',    'PO4',   'O1',     'O2' };
    normal32 = {'FP1', 'FPz', 'FP2', 'F7','F3','Fz','F4','F8','FC5','FC1','FC2','FC6','M1','T7','C3','Cz','C4', 'T8', 'M2', 'CP5','CP1','CP2','CP6','P7','P3', 'Pz', 'P4', 'P8', 'POz','O1','Oz','O2'};
    
    sensors = {'sens1'};%,'sens2','sens3','sens4','sens5','sens6','sens7','sens8','sens9','sens10','sens11','sens12','sens13','sens14','sens15','sens16','sens17','sens18','sens19','sens20','sens21','sens22','sens23','sens24' };
    
    mask = '';
    chanlocspath = '';
  
    if contains(type , 'norm') 
        mask = normal32;
        chanlocspath  = 'ch32Locations.mat'; 
    elseif contains(type , 'errp')
        mask = errp_cap;
        chanlocspath = 'ErrP_cap_chan_file.mat';
    end
    
    %if contains(type, 'acc') 
    %    mask = [mask , sensors];
    %end

end

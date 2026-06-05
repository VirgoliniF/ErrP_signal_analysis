function [outputArg1,outputArg2] = new_errp_prepare_gdf(subject,setting, task)
   
    includepat  = subject;
    excludepat  = {'filtered'};
    depthlevel  = 2;

    error_modality = setting.error_modality;

    if strcmp(error_modality, 'visual')
        rootpath    = '/home/braingear/Research/FV_data';
        folder      = 'gdf_recordings/wheelchair_errp/visual';
    else
        rootpath   = '/home/braingear/Research/FV_data';
        folder       = 'gdf_recordings/wheelchair_errp/vestibular';
    end
    

    gdfpath       = [rootpath '/' folder '/' task '/' ];

    replace_labels = false; 
    reframe_to_errp = false; 
    
    %% Setup cap

    
    mask = setting.mask;
    remove_mask = setting.remove_mask;
    chanlocspath = setting.chanlocspath;
    
    %% Processing parameters
    
    eegchannels = setdiff(mask, remove_mask, 'stable');
    
    if strcmp(error_modality, 'visual')
        datapath      = ['analysis_visual/' setting.artifactrej '/' setting.spatialfilter '/bandpass/' num2str(length(eegchannels)) '/'];
    else
        datapath      = ['analysis_vestibular/' setting.artifactrej '/' setting.spatialfilter '/bandpass/' num2str(length(eegchannels)) '/'];
    end
    
    eogchannels       = setting.eog_channels;
    
    chanlocstr        = load(chanlocspath);
    
    chanlocs = '';
    
    if (contains(setting.cap, 'norm') && reframe_to_errp == false)
        chanlocs          = errp_util_get_chanlocs(eegchannels, chanlocstr.ch32Locations);
    elseif (contains(setting.cap, 'errp') || reframe_to_errp == true )
        chanlocs          = errp_util_get_chanlocs(eegchannels, chanlocstr.chan);
    end
    
    spatial.filter    = setting.spatialfilter;
    filter.order      = 4;
    filter.bands      = [2 10]; % [2-8] -> [2 16] -> [2 10] Piero usa [2 10]

    if strcmp(error_modality, 'visual')
        savedir           = ['analysis_visual/' setting.artifactrej '/' spatial.filter '/bandpass/' num2str(length(eegchannels)) '/'];
    else
        savedir           = ['analysis_vestibular/' setting.artifactrej '/' spatial.filter '/bandpass/' num2str(length(eegchannels)) '/'];
    end
        
    %% Get datafiles
    files = util_getfile3(gdfpath, '.gdf', 'include', includepat, 'exclude', excludepat, 'level', depthlevel);

    try
        tmp_d = util_getfile3(datapath, '.mat', 'include', includepat, 'exclude', excludepat);
    catch ME
        tmp_d = {};
    end

    nfiles = length(files);
    if(nfiles > 0)
        util_bdisp(['[io] - Found ' num2str(nfiles) ' files with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') '), depth: ' num2str(depthlevel)]);
    else
        error(['[io] - No files found with the inclusion/exclusion criteria: (' strjoin(includepat, ', ') ') / (' strjoin(excludepat, ', ') '), depth: ' num2str(depthlevel)]);
    end
    
    %% Create directory
    util_mkdir(pwd, savedir);
    
    %% Processing files
    for fId = 1:nfiles
        [~, name, ~] = fileparts(files{fId});
        [~, existing_names,~]= cellfun(@(x) fileparts(x), tmp_d, 'UniformOutput', false);

        if any(strcmp(name, existing_names))
            continue;  % Skip this iteration
        end

        cfullname = files{fId};
        [cfilepath, cfilename, cfileext] = fileparts(cfullname);
        
        cfilename_unf = ['unfiltered_' cfilename];
        
        util_bdisp(['[io] + Loading file ' num2str(fId) '/' num2str(nfiles)]);
        disp(['     |- File: ' cfullname]);
        
         %% Loading data
        try
            [s, h] = sload(cfullname); 
        catch ME
            error(['[error] - Cannot load filename. Skipping it. ' Me.message]);
        end
    
        if replace_labels == true
            % may needed if saved with a wrong cap aias
            h.Label = mask';
        end

    
        if reframe_to_errp == true
            h.Label = errp_cap';
            cfilename = ['reframe_' cfilename];
    
            [tf, idx] = ismember(errp_cap, mask);
    
            tmp_s = zeros(size(s,1), length(errp_cap));
    
            tmp_s(:, tf) = s(:, idx(tf));
    
            s = tmp_s;
        end
        
        
        %% Extracting selected EEG channels
        util_bdisp('[proc] + Extracting selected EEG channels (in this ordered):');
        disp(['       |- Channels: ' strjoin(eegchannels, ', ')]);
       
        [~, eegchannelidx] = ismember(lower(eegchannels), lower(h.Label));
        eegchannelidx = eegchannelidx(eegchannelidx ~= 0);
        s_eeg = s(:, eegchannelidx);
        
        %% Extracting selected EOG channels
        util_bdisp('[proc] + Extracting selected EOG channels (in this ordered):');
        disp(['       |- Channels: ' strjoin(eogchannels, ', ')]);
       
        [~, eogchannelidx] = ismember(lower(eogchannels), lower(h.Label));
        s_eog = s(:, eogchannelidx);
        
        
        %% Get information from filename
        cinfo = errp_util_get_info(cfullname);
        
        %% Processing data
        util_bdisp('[proc] + Processing the data');

        % Compute Spatial filter
        disp(['       |- artifact rejection : ' setting.artifactrej]);
    
        switch(setting.artifactrej)
            case 'none'
                s_eeg_clean = s_eeg;
            case 'FORCe'
                f_eeg = filt_bp(s_eeg, filter.order, [1 40], h.SampleRate);
                tmp_eeg = FORCe(f_eeg(:, :)', h.SampleRate, chanlocs, 0 );
                s_eeg_clean = tmp_eeg';
            case 'ica'
                f_eeg = filt_bp(s_eeg, filter.order, [1 40], h.SampleRate);
                EEG = pop_runica(f_eeg, 'extended', 1, 'interupt', 'on');
                pop_selectcomps(EEG, [1:20]);
                EEG = iclabel(EEG);
                error('ica artifact rejection');
            otherwise
                error(['Unknown artifact rejection selected ' spatial.filter]);
        end

        % Compute Spatial filter
        disp(['       |- Spatial filter: ' spatial.filter]);
    
        switch(spatial.filter)
            case 'none'
                s_eeg_spatial = s_eeg_clean;
            case 'car'
                s_eeg_spatial = proc_car(s_eeg_clean, 'excluded', [1 2]);
            case 'laplacian'
                m = eegc3_channels2montage(h.Label(1:end-1));
                L = eegc3_montage(m);
                s_eeg_spatial = s_eeg_clean * L;
            case 'csd'
                [G,H] = GetGH(chanlocs);
                X = CSD(s_eeg_clean', G, H);
                s_eeg_spatial = X';
            otherwise
                error(['Unknown spatial filter selected ' spatial.filter]);
        end
        
        % Compute bandpass filters
        s_eeg_bp = filt_bp(s_eeg_spatial, filter.order, filter.bands, h.SampleRate);
        %s_eeg_bp = filt_bp(s_eeg_spatial, 6, [2 8], h.SampleRate);
        s_eog_bp = filt_bp(s_eog, filter.order, filter.bands, h.SampleRate);
        %s_eog_bp = filt_bp(s_eog, 6, [2 8], h.SampleRate);
        
        eeg = s_eeg_bp;
        eog = s_eog_bp;
    
        if contains(subject, 'acc') 
            tmp = filt_bp(s, 4, [1 100], h.SampleRate);
            eeg(:,33:56) = tmp(:,33:56);
        end
    
        
        % Extracting events
        disp('       |-Extract events');
        cevents     = h.EVENT;
        events.TYP = cevents.TYP;
        events.POS = cevents.POS;
        events.DUR = cevents.DUR;
        
        % Task
        disp('       |-Extract task info');
        task = cinfo.task;
        
        % Extra
        disp('       |-Extract extra info');
        device  = cinfo.extra1;
        control = 'discrete'; %cinfo.extra2;
    
        
        %% Create settings structure
        settings.spatial           = spatial;
        settings.filter            = filter;
        settings.channels.eeg      = eegchannels;
        settings.channels.eog      = eogchannels;
        settings.channels.chanlocs = chanlocs;
        settings.events.TYP        = h.EVENT.TYP;
        settings.events.POS        = h.EVENT.POS;
        settings.events.DUR        = h.EVENT.DUR;
        settings.samplerate        = h.SampleRate;
        settings.task.name         = task;
        settings.device.name       = device;
        settings.control.name      = control;
        settings.control.legend    = {'discrete', 'continuous', 'unknown'};
        settings.info              = cinfo;
        
        sfilename = fullfile(savedir, [cfilename '.mat']);
        util_bdisp(['[out] - Saving bandpass in: ' sfilename]);
        save(sfilename, 'eeg', 'eog', 'events', 'settings'); 
    
        sfilename_unfiltered = fullfile(savedir, [cfilename_unf '.mat']);
        util_bdisp(['[out] - Saving bandpass in: ' sfilename_unfiltered]);
    
        eeg = filt_bp(s_eeg, filter.order, [0.1 50], h.SampleRate);
        save(sfilename_unfiltered, 'eeg', 'eog', 'events', 'settings'); 
       
    end

end
function params = setParameters_old(SampleRate, experiment, margins)
    %%%%%%%%%%%%%%%%%%%%%%%%%
    %% General Information %%
    %%%%%%%%%%%%%%%%%%%%%%%%%
    params.fsamp = SampleRate; % header.SampleRate;
    load chanlocs64.mat
    %[keepIdx, eegIndex] = ismember(header.Label, upper({chanlocs64.labels}));
    % params.chanlocs = chanlocs64;  
    %channel_labels = {'FZ', 'FC5', 'FC1', 'FCZ', 'FC2', 'FC6', 'C3', 'CZ', 'C4', 'CP5', 'CP1', 'CP2', 'CP6'};
    
    % 01/13/25 Piero -> increase the 
    chanlocs64 = chanlocs;
    params.chanlocs = chanlocs;  
    channel_labels = { 'AF3', 'AF4','F3', 'F1', 'Fz', 'F2', 'F4', 'FC3', 'FC1', 'FCz', 'FC2', 'FC4', 'C3', 'C1', 'Cz', 'C2', 'C4', 'CP3', 'CP1',  'CPz',  'CP2','CP4','P3', 'P1', 'Pz','P2', 'P4',    'PO3',  'POz',    'PO4',   'O1',     'O2' };

    channel_labels = cellstr(channel_labels);
    [keepIdx, eegIndex] = ismember(channel_labels, upper({chanlocs64.labels}));
    params.chanlocs = chanlocs64(eegIndex(keepIdx));   

    if strcmp(experiment, 'Gel') == 1
        params.eegChannels = [1, 2, 3, 13, 4, 5, 6, 7, 8, 9, 10, 11, 12]; %re-order to match POLiTAG electrode ordering
    elseif strcmp(experiment, 'Politag') == 1
        params.eegChannels = 33:36; 
    elseif strcmp(experiment, 'Wheelchair') == 1
        % {'AF3','AF4','F3','F1','Fz','F2','F4','FC3','FC1','FCz','FC2','FC4','C3','C1','Cz','C2','C4','CP3','CP1','CPz','CP2','CP4','P3','P1','Pz','P2','P4','PO3','POz','PO4','O1','O2'};
        % {  '1',  '2', '3', '4', '5', '6', '7',  '8',  '9', '10', '11', '12','13','14','15','16','17', '18', '19', '20', '21', '22','23','24','25','26','27', '28', '29', '30','31','32'};
        params.eegChannels = [3,4,5,8,9,10,13,14,15,18,19,20];
    end

    params.triggerChannel = 37;
    params.channelPlot = find(strcmp({params.chanlocs.labels}, 'Cz'));  % normally this one
    params.plotOption = {'LineWidth', 2};
    params.plotColor = {[228,26,28], [55,126,184], [77,175,74]};
    params.plotColor = cellfun(@(x) rdivide(x, 255), params.plotColor, 'UniformOutput', false);
    
    %%%%%%%%%%%%%%
    %% Epoching %%
    %%%%%%%%%%%%%%
    % params.epochSample = -0.5*params.fsamp+1:1.0*params.fsamp;
    params.epochSample = 1: (margins(2)-margins(1))*params.fsamp;
    %margins(1)*params.fsamp+1:margins(2)*params.fsamp;

    params.epochTime = params.epochSample./params.fsamp;
    params.epochOnset = 0; % find(params.epochTime == 0);
    
    %%%%%%%%%%%%%%%%%%%%%
    %% Epoch Rejection %%
    %%%%%%%%%%%%%%%%%%%%%
    params.epochRejection.isCompute = false;
    params.epochRejection.time = round(0.2*params.fsamp)+1:round(0.8*params.fsamp);
    params.epochRejection.time = params.epochRejection.time + params.epochOnset;
    
    %%%%%%%%%%%%%%%%%%%%%
    %% Channel Removal %%
    %%%%%%%%%%%%%%%%%%%%%
    params.channelRemoval.isCompute = false;
    
    %%%%%%%%%%%%%%%%%%%%%
    %% Spectral Filter %%
    %%%%%%%%%%%%%%%%%%%%%
    params.spectralFilter.freqs = [1 10];  % cut-off frequencies
    params.spectralFilter.order = 2;  % 2*params.fsamp for FIR filter

    %%%%%%%%%%%%%%%%%%%%
    %% Spatial Filter %%
    %%%%%%%%%%%%%%%%%%%%
    params.spatialFilter.type = 'CAR'; % 'CCA';  % Option : CAR, Laplace, xDAWN, CCA, CSD, None
    params.spatialFilter.time = round(0.2*params.fsamp)+1:round(0.6*params.fsamp);
    params.spatialFilter.time = params.spatialFilter.time + params.epochOnset;
    params.spatialFilter.nComp = 3;
    params.spatialFilter.classes = [1, 2];

    %%%%%%%%%%%%%%%%%%%%%%
    %% Resampling Ratio %%
    %%%%%%%%%%%%%%%%%%%%%%
    params.resample.is_compute = false;
    params.resample.ratio = round(params.fsamp / 32);  % re-sampling frequency is 64 Hz
    params.resample.time = round(0.1*params.fsamp)+1:round(0.4*params.fsamp);
    params.resample.time = params.resample.time + params.epochOnset;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Power Spectral Density %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    params.psd.is_compute = true;
    params.psd.type = 'pwelch';  % {'pwelch', ''pmtm', 'stockwell'}
    params.psd.time = round(0.0*params.fsamp)+1:round((margins(2)-margins(1))); % *params.fsamp);
    params.psd.time = params.psd.time + params.epochOnset;
    params.psd.window = hanning(length(params.psd.time));
    params.psd.nfft  = 4*params.fsamp;
    params.psd.overlap = [];
    params.psd.freq_range = [4:2:params.spectralFilter.freqs(end)];

    %%%%%%%%%%%%%%%%%%%%%%%%%
    %% Riemannien Geometry %%
    %%%%%%%%%%%%%%%%%%%%%%%%%
    params.riemann.is_compute = true;
    params.riemann.time =  round(0.0*params.fsamp)+1:round((margins(2)-margins(1)));
    %round(0.2*params.fsamp)+1:round(0.6*params.fsamp);
    params.riemann.time = params.riemann.time + params.epochOnset;
    params.riemann.type = 'riemann';
    params.riemann.base = [2];
    params.riemann.is_plot = true;

    %%%%%%%%%%%%%%%%
    %% Classifier %%
    %%%%%%%%%%%%%%%%
    params.classify.is_normalize = true;
    params.classify.reduction.type = 'None'; % {'pca', 'fisher', 'mRMR', 'lasso', 'lasso-rLDA', 'r2', 'None'}
    params.classify.type = 'diaglinear'; % {'SVM', 'LinearSVM', 'LDA', 'diagLDA', 'diagQuadratic', 'SLR_VAR', 'L1_SLR'}
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Asynchronous Classification %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    params.asynchronous.waitSample = round(0.25*params.fsamp);    
end
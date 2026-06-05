function params = setParameters(SampleRate, modality, margins)
    %%%%%%%%%%%%%%%%%%%%%%%%%
    %% General Information %%
    %%%%%%%%%%%%%%%%%%%%%%%%%
    params.fsamp = SampleRate; 
    params.plotOption = {'LineWidth', 2};
    params.plotColor = {[228,26,28], [55,126,184], [77,175,74]};
    params.plotColor = cellfun(@(x) rdivide(x, 255), params.plotColor, 'UniformOutput', false);
    params.plotting_enabled = true;
    
    %%%%%%%%%%%%%%
    %% Epoching %%
    %%%%%%%%%%%%%%
   
    if strcmp(modality, 'auditory')
        params.epochStart = -0.5;
        params.epochEnd = 1.5;
    else
        params.epochStart = margins(1);
        params.epochEnd = margins(2);

    end

    params.epochSample = round(params.epochStart*params.fsamp)+1:round(params.epochEnd*params.fsamp);
    params.epochTime   = params.epochSample./params.fsamp;
    params.epochOnset  = find(params.epochTime == 0);

    % If zero is not found in epochTime, set epochOnset to 0
    if isempty(params.epochOnset)
        params.epochOnset = 0;
    end


 
   
    %%%%%%%%%%%%%%%%%%%%%
    %% Epoch Rejection %%
    %%%%%%%%%%%%%%%%%%%%%
    params.epochRejection.isCompute = false;
    %params.epochRejection.time = round(0.2*params.fsamp)+1:round(0.6*params.fsamp);
    %params.epochRejection.time = params.epochRejection.time + params.epochOnset;

     % Define proportions for the spatial filter within the epoch
    epochReject_window_proportion_start = 0.2;
    epochReject_window_proportion_end = 0.8;
    % Update window size
    params.epochRejection.time = updateWindowSize(params,epochReject_window_proportion_start,epochReject_window_proportion_end);
    
    % Amplitude threshold
    params.epochRejection.amplitude_threshold = 30;
    params.epochRejection.baseline_threshold = 30;

    %%%%%%%%%%%%%%%%%%%%%%%%
    %% Baseline Correction %%
    %%%%%%%%%%%%%%%%%%%%%%%%
    params.baselineCorrect.isCompute = false;
    
    %%%%%%%%%%%%%%%%%%%%%
    %% Channel Removal %%
    %%%%%%%%%%%%%%%%%%%%%
    params.channelRemoval.isCompute = false;
    params.channelRemoval.numChannels = 4; 
    
    %%%%%%%%%%%%%%%%%%%%%
    %% Spectral Filter %%
    %%%%%%%%%%%%%%%%%%%%%
    params.spectralFilter.freqs = [2 10];  % cut-off frequencies
    params.spectralFilter.order = 2;  % 2*params.fsamp for FIR filter

    %%%%%%%%%%%%%%%%%%%%
    %% Spatial Filter %%
    %%%%%%%%%%%%%%%%%%%%
    params.spatialFilter.type = 'Nonw';  % Option : CAR, Laplace, xDAWN, CCA, CSD, None
    params.spatialFilter.nComp = 3;
    params.spatialFilter.classes = [1, 2];

    % Define proportions for the spatial filter within the epoch
    spatial_filter_proportion_start = 0.2;
    spatial_filter_proportion_end = 0.8;
    % Update window size
    params.spatialFilter.time = updateWindowSize(params,spatial_filter_proportion_start,spatial_filter_proportion_end);

   
    %%%%%%%%%%%%%%%%%%%%%%
    %% Resampling Ratio %%
    %%%%%%%%%%%%%%%%%%%%%%
    params.resample.is_compute = false;
    params.resample.ratio = round(params.fsamp / 32);  % re-sampling frequency is 64 Hz
    %params.resample.time = round(0.1*params.fsamp)+1:round(0.6*params.fsamp);
    %params.resample.time = params.resample.time + params.epochOnset;


    resample_filter_proportion_start = 0.2;
    resample_filter_proportion_end = 0.8;
    % Update window size
    params.resample.time = updateWindowSize(params,resample_filter_proportion_start,resample_filter_proportion_end);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Power Spectral Density %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    params.psd.is_compute = true;
    params.psd.type = 'pwelch';  % {'pwelch', ''pmtm', 'stockwell'}
    %params.psd.time = round(0.1*params.fsamp)+1:round(0.5*params.fsamp);
    %params.psd.time = params.psd.time + params.epochOnset;
    
    psd_filter_proportion_start = 0.2;
    psd_filter_proportion_end = 0.8;
    % Update window size
    params.psd.time  = updateWindowSize(params,psd_filter_proportion_start,psd_filter_proportion_end);

    params.psd.window = hanning(length(params.psd.time));
    params.psd.nfft  = 4*params.fsamp;
    params.psd.overlap = [];
    params.psd.freq_range = 4:2:params.spectralFilter.freqs(end);
    params.psd.stockwell.resample = round(params.fsamp/64);

    %%%

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
    params.riemann.fgda.is_compute = false;
    params.riemann.distance_threshold = 0.04;
    params.riemann.decision_threshold = 0;
   
    %%%%%%%%%%%%%%%%
    %% Classifier %%
    %%%%%%%%%%%%%%%%
    params.classify.is_normalize = false;
    params.classify.reduction.type = 'pca'; % {'pca', 'fisher', 'mRMR', 'lasso', 'lasso-rLDA', 'r2', 'randomforest', 'None'}
    params.classify.reduction.numFeatures = 50; % Number of features to select
    params.classify.type = 'diaglinear'; % {'SVM', 'LinearSVM', 'LDA', 'diagLDA', 'diagQuadratic', 'SLR_VAR', 'L1_SLR'}
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Asynchronous Classification %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    params.asynchronous.waitSample = round(0.25*params.fsamp);    
end
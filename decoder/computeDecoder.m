function [decoder, classifierEpochs] = computeDecoder(trainEpochs, trainLabels, trainBaseline, params)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Used to develop classifier
    % Inputs offline epochs, labels, param
    % Outputs as decoder object
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    classifierEpochs = 0;    
    
  
    %% Amplitude Threshold
    if (params.epochRejection.isCompute) 
        
        % Initialize a logical array to mark trials to keep
        trialsToKeep = true(1, size(trainEpochs, 3));
        
        % Iterate over each trial
        for trial = 1:size(trainEpochs, 3)
             % Check if any sample in the current trial exceeds the threshold
            if any(abs(trainEpochs(:, :, trial)) > params.epochRejection.amplitude_threshold, 'all') || ...
               any(abs(trainBaseline(:, :, trial)) > params.epochRejection.baseline_threshold, 'all')

                trialsToKeep(trial) = false;  % Mark trial for rejection 
                
            end
        end
        
        % Filter out the trials that exceed the threshold
        filteredTrainEpochs = trainEpochs(:, :, trialsToKeep);
        filteredTrainLabels = trainLabels(trialsToKeep);
        filteredTrainBaseline = trainBaseline(:, :, trialsToKeep);

        trainEpochs = filteredTrainEpochs;
        trainLabels = filteredTrainLabels;
        trainBaseline = filteredTrainBaseline;

    end

    %% Baseline Correction
    if (params.baselineCorrect.isCompute)
    
        % Calculate the median of the baseline period for each trial
        baseline_median = nanmedian(trainBaseline, 1);
    
        % Subtract the baseline median from the entire epoch for each trial
        for i = 1:size(trainEpochs, 3)
            trainEpochs(:, :, i) = trainEpochs(:, :, i) - baseline_median(:, :, i);
        end

    end

    %% Riemannien Geometry
    if (params.riemann.is_compute) 

        decoder.riemann.is_compute =  true;

        % Normailize Features 
        if (params.classify.is_normalize)
            % Compute mean and standard deviation across trials (3rd dimension)
            meanNorm = mean(trainEpochs, 3);  % (Samples x Channels)
            stdNorm = std(trainEpochs, 0, 3);  % (Samples x Channels)

            % Prevent division by zero in case of zero standard deviation
            stdNorm(stdNorm == 0) = 1;

            % Normalize each trial individually by subtracting the mean and dividing by std
            trainEpochs = (trainEpochs - meanNorm) ./ stdNorm;

        end
         
        % Compute templates
        template_correct = mean(trainEpochs(:,:,trainLabels == 0), 3);  
        template_error = mean(trainEpochs(:,:,trainLabels == 1), 3); 

        decoder.riemann.template_correct = template_correct;
        decoder.riemann.template_error = template_error;
        
        % Augment data with templates
        augmentedEpochs = zeros(size(trainEpochs, 1), size(trainEpochs, 2) * 3, size(trainEpochs, 3));  % (samples, 3*channels, trial)
        for i = 1:size(trainEpochs, 3)
            % Extract the current trial
            trial_data = trainEpochs(:,:,i); 
            
            % Concatenate both templates along the channel dimension (axis 2)
            augmented_data = [trial_data, template_correct, template_error];  
            
            % Store the augmented trial
            augmentedEpochs(:,:,i) = augmented_data;           
        end

        % Compute covariance matrix
        cov_matrices = estimateRiemannianCovaraince(augmentedEpochs);

        % Ensure the covariance matrices are real
        cov_matrices = real(cov_matrices);

        % Regularize to ensure positive definiteness
        epsilon = 1e-6;  % Small regularization constant
        for i = 1:size(cov_matrices, 3)
            cov_matrices(:, :, i) = cov_matrices(:, :, i) + epsilon * eye(size(cov_matrices, 1));
        end


        if (params.riemann.fgda.is_compute)


            % Apply FGDA with class weights
            %class_weights = [1, 1.5];  % Correct class (0) weight = 1, Error class (1) weight = 2
            %[W, Cg] = fgda_weighted(cov_matrices, trainLabels, 'riemann', {}, 'shcov',{},class_weights);


            % % Apply FGDA to learn the projection matrix (W) and the geodesic center (Cg)
            [W, Cg] = fgda(cov_matrices, trainLabels, 'riemann', {}, 'shcov', {});
    
            decoder.riemann.W = W;
            decoder.riemann.Cg = Cg; 

            Nclass = length(unique(trainLabels));
            cov_projected_train = geodesic_filter(cov_matrices, Cg, W(:, 1:Nclass-1));

            % Compute class prototypes (Riemannian means of projected training data)
            prototype_correct = mean_covariances(cov_projected_train(:,:,trainLabels == 0), 'riemann');
            prototype_error = mean_covariances(cov_projected_train(:,:,trainLabels == 1), 'riemann');
       
        else

            % Compute reference matrix
            reference_matrix = riemann_mean(cov_matrices); 

            % Ensure the reference matrix is real
            reference_matrix = real(reference_matrix);
            % Regularize to ensure positive definiteness
            reference_matrix = reference_matrix + epsilon * eye(size(reference_matrix, 1));
            
            decoder.riemann.reference_train = reference_matrix;
    
            % Rebias all trials using the reference matrix
            cov_rebias_all = Affine_transformation(cov_matrices, reference_matrix);
    
            % Extract covariance matrices for correct and error trials
            cov_rebias_correct = cov_rebias_all(:,:,trainLabels == 0);  % Correct trials
            cov_rebias_error = cov_rebias_all(:,:,trainLabels == 1);    % Error trials
            
            % Compute prototypes 
            prototype_correct = riemann_mean(cov_rebias_correct);  
            prototype_error = riemann_mean(cov_rebias_error);  
       
        end

        % Ensure the prototypes are real
        prototype_correct = real(prototype_correct);
        prototype_error = real(prototype_error);
        
        % Regularize to ensure positive definiteness
        prototype_correct = prototype_correct + epsilon * eye(size(prototype_correct, 1));
        prototype_error = prototype_error + epsilon * eye(size(prototype_error, 1));
    
        % Store prototypes
        decoder.riemann.prototype_correct = prototype_correct;
        decoder.riemann.prototype_error = prototype_error;
        decoder.riemann.fgda.is_compute = params.riemann.fgda.is_compute;

        % Store trial count (for adaptive rebias)
        decoder.riemann.trialCount = 1;

  
    else  % anything other than remanian

        decoder.riemann.is_compute = false;
        
        %% Spatial Filter (not actually spatial filtering)
        % cononical correlation analysis
        % does transformation that maximizes correlationhio between individual and
        % grand average trials -> smoothing
        
        filterMatrix = get_spatial_filter(params.spatialFilter.type, trainEpochs, trainLabels, params);
        filterMatrix = filterMatrix(:, 1:params.spatialFilter.nComp);
        classEpochs = apply_spatialFilter(trainEpochs, filterMatrix);

        %% Temporal Information Features
        % extract downsampled voltages 
        if (params.resample.is_compute)
            resamps = classEpochs(params.resample.time(1:params.resample.ratio:end), :, :);
            resamps = reshape(resamps, [size(resamps,1)*size(resamps,2) size(resamps,3)]);
        end

        %% Power Spectral Density Features
        if (params.psd.is_compute)
            psdEpochs = classEpochs(params.psd.time, :, :);
            [psds, params] = compute_psd(params.psd.type, psdEpochs, params);
            psds = reshape(psds, [size(psds,1)*size(psds,2) size(psds,3)]);
            
            if any(isnan(psds))
                logicalIdx  = not(isnan(psds(:,1)));
                psds = psds(logicalIdx,:);
            end
        end

        %% Concatenate all computed features
        classifierEpochs = [];
        startSample = 1;
        if (params.resample.is_compute)
            classifierEpochs = cat(1, classifierEpochs, resamps);
            params.resample.range = startSample:size(classifierEpochs,1);
            startSample = params.resample.range(end) + 1;
        end
        if (params.psd.is_compute)
            classifierEpochs = cat(1, classifierEpochs, psds);
            params.psd.range = startSample:size(classifierEpochs,1);
            startSample = params.psd.range(end) + 1;
        end
        if (params.riemann.is_compute)
            classifierEpochs = cat(1, classifierEpochs, riemanns);
            params.riemann.range = startSample:size(classifierEpochs,1);
            startSample = params.riemann.range(end) + 1;
        end
        
        if isequal(params.classify.reduction.type, 'pca')
            [coeff, ~, ~, ~, explainedVar, mu] = pca(classifierEpochs');
            keepIdx = find(cumsum(explainedVar) > 95) - 1;
            coeff = coeff(:, 1:keepIdx);
            applyPCA = @(x) bsxfun(@minus, x', mu)*coeff;
            classifierEpochs = applyPCA(classifierEpochs)';
        end

        %% Normailize Features
        if (params.classify.is_normalize)
            meanNorm = mean(classifierEpochs, 2);
            stdNorm = std(classifierEpochs, 0, 2);

            % Prevent division by zero in case of zero standard deviation
            stdNorm(stdNorm == 0) = 1;
        
            % Normalize each trial individually by subtracting the mean and dividing by std
            classifierEpochs = (classifierEpochs - meanNorm) ./ stdNorm;

            decoder.classify.meanNorm = meanNorm;
            decoder.classify.stdNorm = stdNorm;
           
        end
        
        %% Penalization for LDA
        if isequal(params.classify.reduction.type, 'lasso')
            lambdaMax = 0.1;
            Lambda = logspace(log10(0.001*lambdaMax),log10(lambdaMax),100);
            cvmodel = fitrlinear(classifierEpochs,trainLabels,'ObservationsIn','columns', 'Lambda', Lambda, 'KFold', 5, 'Learner','leastsquares','Solver','sparsa','Regularization','lasso');
            mse = kfoldLoss(cvmodel);
            [~, idx] = min(mse);
            model = fitrlinear(classifierEpochs,trainLabels,'ObservationsIn','columns', 'Lambda', Lambda(idx), 'Learner','leastsquares','Solver','sparsa','Regularization','lasso');
            keepIdx = model.Beta~=0;
            classifierEpochs = classifierEpochs(keepIdx, :);
            
        elseif isequal(params.classify.reduction.type, 'r2')
            power = compute_r2(permute(classifierEpochs, [1 3 2]), trainLabels);
            [~, keepIdx] = sort(power, 'descend');
            % keepIdx = keepIdx(1:40);
            classifierEpochs = classifierEpochs(keepIdx, :);
        end
    
        %% Random Forest-based Feature Selection
        if isequal(params.classify.reduction.type, 'randomforest')
    
            B = TreeBagger(150, classifierEpochs', trainLabels, ...
                'Method', 'classification', ...
                'OOBPrediction', 'On', ...
                'OOBPredictorImportance', 'On');
                %'MaxNumSplits', params.classify.maxSplit, ...
                %'MinLeafSize', params.classify.minLeafSize);
    
            importance = B.OOBPermutedPredictorDeltaError;
            [~, idx] = sort(importance, 'descend');
            numAvailableFeatures = min(params.classify.reduction.numFeatures, length(idx)); % Ensure numFeatures does not exceed available features
            keepIdx = idx(1:numAvailableFeatures); % Select top features based on importance
            classifierEpochs = classifierEpochs(keepIdx, :);
        
        end

        %% PCA of selected features into 2D space

        % Apply PCA to reduce dimensionality to 2D for visualization
        % [coeff, score, ~, ~, explained] = pca(classifierEpochs');
        % 
        % % Plot the first two principal components
        % figure;
        % gscatter(score(:,1), score(:,2), trainLabels, 'rb', 'xo');
        % xlabel(['Principal Component 1 (' num2str(explained(1), '%.2f') '%)']);
        % ylabel(['Principal Component 2 (' num2str(explained(2), '%.2f') '%)']);
        % title('PCA of EEG Features');
        % legend('Class 0', 'Class 1');
        % grid on;
        % 
        % params.classify.pca.coeff = coeff;
        % params.classify.pca.score = score;
        % params.classify.pca.explained = explained;


        %% Classification %%
    
        % LDA
        if strcmp(params.classify.type, 'diaglinear')
            model = fitcdiscr(classifierEpochs', trainLabels, 'Prior', 'uniform', 'DiscrimType', params.classify.type);
            % q = model.Coeffs(2,1).Quadratic;
            w = model.Coeffs(2,1).Linear;
            mu = model.Coeffs(2,1).Const;
            % distance = classifierEpochs' * q * classifierEpochs + classifierEpochs' * w + mu;
            distance = classifierEpochs' * w + mu;
            
            p1 = 0.025;
            p2 = 1-p1;
            bcoeff1=-log((1-p1)/p1)/prctile(distance,100*p1);
            bcoeff2=-log((1-p2)/p2)/prctile(distance,100*p2);
            b = (bcoeff1+bcoeff2)/2;
            
            model = @(x) 1./(1+exp(-b*(x*w+mu))); 
        end
        
        % Random Forest
        if strcmp(params.classify.type, 'randomforest')
            % Use class weights as hyperparameter
            uniqueLabels = unique(trainLabels);
            totalSamples = length(trainLabels);
            
            % Initialize all weights to 1
            classWeightsArray = ones(totalSamples, 1);
        
            % Apply weights only to the minority class (label 1)
            majorityClass = 0;
            minorityClass = 1;
            
            % Calculate the weight for the minority class
            majorityCount = sum(trainLabels == majorityClass);
            minorityCount = sum(trainLabels == minorityClass);
            minorityClassWeight = params.classify.classWeights * (majorityCount / minorityCount);
            
            % Set the weights
            classWeightsArray(trainLabels == majorityClass) = 1;
            classWeightsArray(trainLabels == minorityClass) = minorityClassWeight;
            
            
            % Train Random Forest with class weights
            model = TreeBagger(150, classifierEpochs', trainLabels, ...
                               'Method', 'classification', ...
                               'Weights', classWeightsArray, ... 
                               'OOBPrediction', 'On');

                               % 'MaxNumSplits', params.classify.maxSplit, ...
                               % 'MinLeafSize', params.classify.minLeafSize,...
                                                
        end

        decoder.numFeatures = size(classifierEpochs, 1);
        decoder.spatialFilter = filterMatrix;
        decoder.resample = params.resample;
        decoder.psd = params.psd;
        decoder.classify.reduction.type = params.classify.reduction.type;
        if ismember(decoder.classify.reduction.type, {'lasso', 'r2', 'randomforest'})
            decoder.classify.keepIdx = keepIdx;
        elseif isequal(decoder.classify.reduction.type, 'pca')
            decoder.classify.applyPCA = applyPCA;
        end

        decoder.classify.model = model;

        decoder.classify.classWeights = params.classify.classWeights;
        decoder.classify.classWeightsArray = classWeightsArray;

        decoder.spectralFilter = params.spectralFilter;

        % decoder.classify.maxSplit = params.classify.maxSplit;
        % decoder.classify.minLeafSize = params.classify.minLeafSize;

    end
    
    %% Keep important functions
    %decoder.epochOnset = params.epochOnset;
    decoder.fsamp = params.fsamp;
    decoder.epochRejection = params.epochRejection;

    decoder.classify.is_normalize = params.classify.is_normalize;
    if (decoder.classify.is_normalize)
        decoder.classify.meanNorm = meanNorm;
        decoder.classify.stdNorm = stdNorm;
    end
    
    decoder.channelRemoval.isCompute = params.channelRemoval.isCompute;
    if decoder.channelRemoval.isCompute 
        decoder.selectedChannels = selectedChannels; % Store selected channels
    end
    
    decoder.classify.type = params.classify.type;
    
    
    
    decoder.synchronous.waitSample = params.asynchronous.waitSample;
    decoder.epochSample = params.epochSample;
   
    decoder.eegChannels = [33,34,35,36];
    decoder.epochStart = params.epochStart;
    decoder.epochEnd = params.epochEnd;

    decoder.baselineCorrect.isCompute = params.baselineCorrect.isCompute;

    decoder.spectralFilter = params.spectralFilter;

    decoder.epochRejection.amplitude_threshold = params.epochRejection.amplitude_threshold;
    decoder.epochRejection.baseline_threshold = params.epochRejection.baseline_threshold;

end
    
%% spatial filter helper function
function data_output = apply_spatialFilter(data_input, filter_matrix)
        [n_samples, ~, n_trials] = size(data_input);
        
        data_output = nan(n_samples, size(filter_matrix,2), n_trials);
        for i_trial = 1:n_trials
            data_output(:,:,i_trial) = data_input(:,:,i_trial) * filter_matrix;
        end
end


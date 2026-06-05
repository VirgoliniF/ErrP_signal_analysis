function [posterior, decoder] = singleClassification_online(decoder, eeg, baseline)
% Testing Data processing
% if ~mislocked
%     mlock
% end


%% Select the same channels as during training
if decoder.channelRemoval.isCompute 
    eeg = eeg(:, decoder.selectedChannels, :);
end


%% Baseline Correction

if (decoder.baselineCorrect.isCompute)
    
    % Calculate the median of the baseline period for each trial
    baseline_median = nanmedian(baseline, 1);
    
    % Expand baseline_median to match the size of eeg for subtraction
    baseline_median_expanded = repmat(baseline_median, [size(eeg, 1), 1, 1]);
    
    % Subtract the baseline median from the entire epoch for each trial
    eeg = eeg - baseline_median_expanded;

end

%% Riemannien Geometry
if (decoder.riemann.is_compute)

        % Normalize the test data using training statistics
        if (decoder.classify.is_normalize)
            meanNorm = decoder.classify.meanNorm;
            stdNorm = decoder.classify.stdNorm;
            eeg = (eeg - meanNorm) ./ stdNorm;
        end

        % Augment test data with the templates used in training
        template_correct = decoder.riemann.template_correct;
        template_error = decoder.riemann.template_error;
        
        augmentedEpochs_test = zeros(size(eeg, 1), size(eeg, 2) * 3, size(eeg, 3));  % (samples, 3*channels, trials)
        for i = 1:size(eeg, 3)
            trial_data = eeg(:,:,i); 
            augmented_data = [trial_data, template_correct, template_error];  
            augmentedEpochs_test(:,:,i) = augmented_data;           
        end

        % Compute covariance matrices for augmented test data
        cov_matrices_test = estimateRiemannianCovaraince(augmentedEpochs_test);

        % Ensure the covariance matrices are real
        cov_matrices_test = real(cov_matrices_test);
        
        % Regularize to ensure positive definiteness
        epsilon = 1e-6;  % Small regularization constant
        for i = 1:size(cov_matrices_test, 3)
            cov_matrices_test(:, :, i) = cov_matrices_test(:, :, i) + epsilon * eye(size(cov_matrices_test, 1));
        end

        if(decoder.riemann.fgda.is_compute)
               
            % Use FGDA for testing (apply geodesic filtering using W and Cg)
            W = decoder.riemann.W;
            Cg = decoder.riemann.Cg;
            % Use the precomputed prototypes from FGDA training
            class_prototypes = {decoder.riemann.prototype_correct, decoder.riemann.prototype_error};
            % Use the weighted FGDA for testing and classification
            % class_weights = [1, 1.5];  % Correct class (0) weight = 1, Error class (1) weight = 2
            % Project test data using the FGDA projection matrix and classify using weighted MDM
            %[Ytest, posteriors] = fgmdm_test(cov_matrices_test, class_prototypes, W, Cg, class_weights);
            [Ytest, posteriors] = fgmdm_test(cov_matrices_test, class_prototypes, W, Cg);
        
        else

            % First trial of session -> use training ref matrix
            if decoder.riemann.trialCount == 1
                % Apply affine transformation using the reference matrix from training
                reference_matrix = real(decoder.riemann.reference_train);
                %reference_matrix = reference_matrix + epsilon * eye(size(reference_matrix, 1));
                ref_tmp = cov_matrices_test(:,:,1);
                decoder.riemann.ref_tmp = ref_tmp;
            
            % Second trial -> use the covariance matrix from the first trial
            elseif decoder.riemann.trialCount == 2
                reference_matrix = decoder.riemann.ref_tmp;

            else
                % For trials i >= 3, apply geodesic interpolation to update the reference matrix
                reference_matrix = geodesicInterpolation(decoder.riemann.reference_matrix, cov_matrices_test(:,:,1), 1/(decoder.riemann.trialCount-1));

                % Ensure the updated reference matrix is real and regularized
                reference_matrix = real(reference_matrix);
                %reference_matrix = reference_matrix + epsilon * eye(size(reference_matrix, 1));
            end

            % Increment the trial count
            decoder.riemann.trialCount = decoder.riemann.trialCount + 1;

            % Update decoder reference matrix
            decoder.riemann.reference_matrix = reference_matrix;

            % Apply affine transformation using the updated reference matrix
            cov_rebias_test = Affine_transformation(cov_matrices_test, reference_matrix);
                
    
            % Use the precomputed prototypes from training for classification
            class_prototypes = {decoder.riemann.prototype_correct, decoder.riemann.prototype_error};
            [Ytest, posteriors] = mdm_test(cov_rebias_test, class_prototypes);


        end

        % Extract the posterior probability for class 1 (error)
        posterior = posteriors;  % Column 2 corresponds to class 1 (error)

    
else % any other method
    %% Spatial Filter
    n_trials = size(eeg, 3);
    sf_eeg = nan(size(eeg,1), size(decoder.spatialFilter,2), n_trials);
    for i_trial = 1:n_trials
        sf_eeg(:,:,i_trial) = eeg(:,:,i_trial) * decoder.spatialFilter;
    end

    %% Temporal Information
    if (decoder.resample.is_compute)
        resamp = sf_eeg(decoder.resample.time(1:decoder.resample.ratio:end), :, :);
        resamp = reshape(resamp, [size(resamp,1)*size(resamp,2) n_trials]);
    end

    %% Power Spectral Density
    if (decoder.psd.is_compute)
        psd_epoch = sf_eeg(decoder.psd.time, :,:);
        [psd, decoder] = compute_psd(decoder.psd.type, psd_epoch, decoder);
        psd = reshape(psd, [size(psd,1)*size(psd,2) n_trials]);
    end

    %% Concatenate all computed features
    epoch = nan(decoder.numFeatures, n_trials);
    if (decoder.resample.is_compute)
        epoch(decoder.resample.range,:) = resamp;
    end
    if (decoder.psd.is_compute)
        epoch(decoder.psd.range,:) = psd;
    end
    if (decoder.riemann.is_compute)
        epoch(decoder.riemann.range,:) = riemann;
    end
    
    if isequal(decoder.classify.reduction.type, 'pca')
        epoch = decoder.classify.applyPCA(epoch)';
    end

    %% Normailize Features
    if (decoder.classify.is_normalize)
        
        % Retrieve stored mean and std from training
        meanNorm = decoder.classify.meanNorm;
        stdNorm = decoder.classify.stdNorm;
    
        % Normalize the test data (or epoch data) using the training statistics
        epoch = (epoch - meanNorm) ./ stdNorm;
    end

    %% Feature selection
    if ismember(decoder.classify.reduction.type, {'lasso', 'r2','randomforest'})
        epoch = epoch(decoder.classify.keepIdx, :);
    end

    %% Classification
    if strcmp(decoder.classify.type, 'diaglinear')
        posterior = decoder.classify.model(epoch');
    elseif strcmp(decoder.classify.type, 'randomforest')
        [~, scores] = predict(decoder.classify.model, epoch');
        posterior = scores(:,2); % Assuming binary classification and the second column represents the positive class
    end

end
end

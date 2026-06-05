function [decoder, classifierEpochs] = computeDecoder_old(trainEpochs, trainLabels, params)

%% Spatial Filter
filterMatrix = get_spatial_filter(params.spatialFilter.type, trainEpochs, trainLabels, params);
filterMatrix = filterMatrix(:, 1:params.spatialFilter.nComp);
classEpochs = apply_spatialFilter(trainEpochs, filterMatrix);
classEpochs = trainEpochs;

%% Compute Channel-wise Joint Probability
if (params.epochRejection.isCompute) 
    epochRej = classEpochs(params.epochRejection.time, :, :);
    [jp, ~, params.epochRejection.distribution, params.epochRejection.data2idx] = jointprob(permute(epochRej, [2 1 3]));
    [logicalIdx, lowBound, highBound] = isoutlier(jp, 'median', 2, 'thresholdFactor', 2.75);
    
    rmIdx = any(logicalIdx, 1);
    nTrials = size(trainEpochs,3);
    trainEpochs(:, :, rmIdx) = [];
    trainLabels(rmIdx) = [];
    
    params.epochRejection.low = lowBound;
    params.epochRejection.high = highBound;
    
    disp([num2str(sum(rmIdx)) ' / ' num2str(nTrials) ' trials are removed: ' num2str(100*sum(rmIdx)/nTrials) ' %']);
    
    
    filterMatrix = get_spatial_filter(params.spatialFilter.type, trainEpochs, trainLabels, params);
    
    filterMatrix = filterMatrix(:, 1:params.spatialFilter.nComp);
    classEpochs = apply_spatialFilter(trainEpochs, filterMatrix);
end

%% Temporal Information
if (params.resample.is_compute)
    resamps = classEpochs(params.resample.time(1:params.resample.ratio:end), :, :);
    resamps = reshape(resamps, [size(resamps,1)*size(resamps,2) size(resamps,3)]);
end

%% Power Spectral Density
if (params.psd.is_compute)
    psdEpochs = classEpochs(params.psd.time, :, :);
    [psds, params] = compute_psd(params.psd.type, psdEpochs, params);
    psds = reshape(psds, [size(psds,1)*size(psds,2) size(psds,3)]);
    
    if any(isnan(psds))
        logicalIdx  = not(isnan(psds(:,1)));
        psds = psds(logicalIdx,:);
    end
end

%% Riemannien Geometry
if (params.riemann.is_compute)    
    riemannEpochs = classEpochs(params.riemann.time, :, :);
    [riemanns, params] = compute_riemann(riemannEpochs, trainLabels, params);
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
    maxNorm = max(classifierEpochs, [], 2);
    minNorm = min(classifierEpochs, [], 2);
    
    funNormalize = @(x) (x - minNorm) ./ (maxNorm - minNorm);
    classifierEpochs = funNormalize(classifierEpochs);
end

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
%     keepIdx = keepIdx(1:40);
    classifierEpochs = classifierEpochs(keepIdx, :);
end

%% Classification %%
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

%% Keep important functions
decoder.fsamp = params.fsamp;
decoder.epochOnset = params.epochOnset;
decoder.numFeatures = size(classifierEpochs, 1);
decoder.epochRejection = params.epochRejection;
decoder.spatialFilter = filterMatrix;
decoder.resample = params.resample;
decoder.psd = params.psd;
decoder.riemann = params.riemann;
decoder.classify.is_normalize = params.classify.is_normalize;
if (decoder.classify.is_normalize)
    decoder.classify.funNormalize = funNormalize;
end
decoder.classify.reduction.type = params.classify.reduction.type;
if ismember(decoder.classify.reduction.type, {'lasso', 'r2'})
    decoder.classify.keepIdx = keepIdx;
elseif isequal(decoder.classify.reduction.type, 'pca')
    decoder.classify.applyPCA = applyPCA;
end
decoder.classify.type = params.classify.type;
decoder.classify.model = model;
end

function data_output = apply_spatialFilter(data_input, filter_matrix)
[n_samples, ~, n_trials] = size(data_input);

data_output = nan(n_samples, size(filter_matrix,2), n_trials);
for i_trial = 1:n_trials
    data_output(:,:,i_trial) = data_input(:,:,i_trial) * filter_matrix;
end
end
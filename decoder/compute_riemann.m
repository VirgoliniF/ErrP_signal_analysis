function [riemanns, params, riemann_mat] = compute_riemann(epochs, labels, params)

uniqueLabels = unique(labels);
avrgSignals = [];
for i = 1:length(uniqueLabels)
    exLabel = uniqueLabels(i);
    exEpochs = epochs(:, :, labels == exLabel);
    
    if ismember(i, params.riemann.base)
        avrgSignals = cat(2, avrgSignals, mean(exEpochs, 3)); 
    end
end

covarianceInput = cat(2, repmat(avrgSignals, [1 1 size(epochs, 3)]), epochs);
singleCov = covariances(permute(covarianceInput, [2 1 3]), 'shcovft');

% avrgCov = mean_covariances(singleCov, 'riemann');
% distanceMatrix = nan(size(singleCov, 3), 1);
% for iTrial = 1:size(singleCov, 3)
%     distanceMatrix(iTrial) = distance(singleCov(:,:,iTrial),avrgCov,'riemann');
% end
% p = prctile(distanceMatrix, [10 90]);
% rmIdx = distanceMatrix < p(1) | distanceMatrix > p(2);
% singleCov(:, :, rmIdx) = [];

avrgCov = mean_covariances(singleCov, params.riemann.type);

covarianceInput = cat(2, repmat(avrgSignals, [1 1 size(epochs, 3)]), epochs);
singleCov = covariances(permute(covarianceInput, [2 1 3]), 'shcovft');
[riemanns, riemann_mat] = Tangent_space(singleCov, avrgCov);

%% Keep parameters
params.riemann.avrgSignals = avrgSignals;
params.riemann.avrgCov = avrgCov;

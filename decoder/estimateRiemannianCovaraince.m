function [trialCov] = estimateRiemannianCovaraince( data )
    % Extraction of covariance matrices in barachant format 
    % (To adjust accordingly with that of covariance toolbox)
    
    nbChannels = size(data,2);
    nbTrials = size(data,3);
    
    trialCov = zeros(nbChannels,nbChannels,nbTrials);
    for t=1:nbTrials
    %     tic
        E = data(:,:,t)';
        EE = E * E';
        %estimation of trial covariances using automatic covariance matrix shrinking
        trialCov(:,:,t) = cov1para(data(:,:,t)./ sqrt(trace(EE))); 
    end

end
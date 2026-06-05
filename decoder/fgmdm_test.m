function [Ytest, posteriors] = fgmdm_test(COVtest, class_prototypes, W, Cg, weights, varargin)

    % Set default methods if none are provided
    if isempty(varargin)
        method_mean = 'riemann';
        method_dist = 'riemann';
    else
        method_mean = varargin{1};
        method_dist = varargin{2};
    end
    
    % Project test data using the FGDA projection matrix (W) and geodesic center (Cg)
    COVtest = geodesic_filter(COVtest, Cg, W);  % Apply FGDA projection to test data
    
    % Perform MDM classification on the projected test data using stored prototypes
    [~, d] = mdm_test(COVtest, class_prototypes);
    
    % Convert distances to probabilities using softmax
    posteriors = softmax(-d);  % Apply softmax to negative distances to get probabilities
    
    % Assign class label based on the highest posterior probability (0 or 1)
    [~, Ytest] = max(posteriors, [], 2);  % Ytest contains the predicted class (0 or 1)
end

function probs = softmax(distances)
    % Apply softmax to the distances to convert them into probabilities
    exp_dist = exp(distances);
    probs = exp_dist ./ sum(exp_dist, 2);  % Normalize across each trial to get probabilities
end

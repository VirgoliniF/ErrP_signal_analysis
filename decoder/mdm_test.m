function [Ytest, posteriors] = mdm_test(COVtest, class_prototypes,varargin)

     if isempty(varargin)
        method_mean = 'riemann';
        method_dist = 'riemann';
    else
        method_mean = varargin{1};
        method_dist = varargin{2};
    end

    % MDM for testing using precomputed class prototypes (from training)
    % You know that class 1 = error and class 0 = correct

    Nclass = length(class_prototypes);  % Number of classes (error vs correct)
    NTesttrial = size(COVtest, 3);      % Number of test trials
    d = zeros(NTesttrial, Nclass);      % Distance matrix

    % Calculate the distance from each test trial to each prototype
    for j = 1:NTesttrial
        for i = 1:Nclass
            d(j, i) = distance(COVtest(:,:,j), class_prototypes{i}, method_dist);
        end
    end

    % Apply softmax to the negative distances to convert to probabilities
    posteriors = softmax(-d);

    % Assign the class label with the highest probability
    [~, Ytest] = max(posteriors, [], 2);  % Ytest gives you the predicted class (0 or 1)
    % Adjust Ytest to be 0 (correct) or 1 (error) instead of 1 and 2
    Ytest = Ytest - 1;  % Adjust so 1 -> 0 (correct), 2 -> 1 (error)
end

function probs = softmax(distances)
    % Apply softmax to the distances to convert them into probabilities
    exp_dist = exp(distances);
    probs = exp_dist ./ sum(exp_dist, 2);  % Normalize to get probabilities
end

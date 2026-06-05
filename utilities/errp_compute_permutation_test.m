function errp_compute_permutation_test(eeg_err ,eeg_cor, idx_channels , eeg_baseline, multiple_sub)
    %% Parameters, TODO: pass them as function params
    fs = 512;
    window_size = floor(450e-3 * fs);
    step_size = 32;
    num_permutation = 10e4;  
    time_axis =0;
    
    %% Check if we need to made the comparison between the corr or the baseline
    if  ~exist("eeg_baseline","var") == true || isempty(eeg_baseline) == true
      
        [p_values, time_axis, ~] = compute_window(eeg_err, eeg_cor, idx_channels, fs, window_size, step_size, num_permutation, multiple_sub);

        figure;
        p_plot(p_values, time_axis);
        title("p_value")

     else
        [p_values, time_err, ~] = compute_window(eeg_err, eeg_cor, idx_channels, fs, window_size, step_size, num_permutation, multiple_sub);
        [p_eer_ba, time_erb, ~] = compute_window(eeg_err, eeg_baseline, idx_channels, fs, window_size, step_size, num_permutation, multiple_sub);
        [p_cor_ba, time_cob, ~] = compute_window(eeg_cor, eeg_baseline, idx_channels, fs, window_size, step_size, num_permutation, multiple_sub);

        figure;
        subplot(3,1,1)
        p_plot(p_values, time_err);
        title("pvalue err/cor")

        subplot(3,1,2)
        p_plot(p_eer_ba, time_erb);
        title("pvalue err/bas")

        subplot(3,1,3)
        p_plot(p_cor_ba, time_cob);
        title("pvalue cor/bas")
    end
end

function p_plot(p_value, t)
    hold on;
    for idx_ch = 1:size(p_value,2)
        plot(t, p_value(:,idx_ch))
    end
    yline(0.05, '--')
    xline(0.0, '--')


end



function [pvalue, time_axis, other_p] = compute_window(eeg_err, eeg_cor, idx_channels, fs, window_size, step_size, num_permutation, multiple_sub)
  
    time_axis =0;

    num_feature = length(idx_channels);

    num_windows = floor((size(eeg_err,1) - window_size) / step_size) + 1;
    p_values_perb = zeros(num_windows, num_feature);
    p_values_norm = zeros(num_windows, num_feature);
    plverr_values = zeros(num_windows, num_feature);
    plvcor_values = zeros(num_windows, num_feature);
    p_normalyty_test = zeros(num_windows, num_feature);

    time_axis = linspace(-2, 2, num_windows);  % Get the limits from the main page!!

    warning('off', 'stats:lillietest:OutOfRangePLow');

    parfor w = 1:num_windows
        start_idx = (w-1) * step_size + 1;
        end_idx = start_idx + window_size - 1;

        data_err = eeg_err(start_idx:end_idx, idx_channels, :);
        data_cor = eeg_cor(start_idx:end_idx, idx_channels, :);

        % PVL
        phase1 = angle(hilbert(data_err));
        phase2 = angle(hilbert(data_cor));

        plverr = abs(mean(exp(1j * phase1), 3));
        plvcor = abs(mean(exp(1j * phase2), 3));

        plverr_values(w, :) = mean(plverr, 1);
        plvcor_values(w, :) = mean(plvcor, 1);

        % This is the feature for now
        %feature_err = squeeze(var(data_err,1));
        %feature_cor = squeeze(var(data_cor,1));
        var1 = squeeze(var(data_err, 1));
        var2 = squeeze(var(data_cor, 1));
    
        % 2. Peak-to-Peak Amplitude
        p2p1 = squeeze(max(data_err, [], 1) - min(data_err, [], 1));
        p2p2 = squeeze(max(data_cor, [], 1) - min(data_cor, [], 1));
    
        % 3. Theta Power (4–7 Hz)
        theta1 = squeeze(mean(bandpower(data_err, fs, [4 7]),1));
        theta2 = squeeze(mean(bandpower(data_cor, fs, [4 7]),1));
    
        % Combine features (stack them)
        feature_err = ( var1 + p2p1 + theta1 )/ 3;
        feature_cor = ( var2 + p2p2 + theta2 )/ 3;

        resampled_feature2 = feature_cor(:, randsample(size(eeg_cor,3), size(eeg_err,3), true)); % Bootstrap sampling

        % Check if the data has the normality across the data
        data_feature = [feature_err resampled_feature2];
        h = [0,0];
        for idx_ch = 1:num_feature
            [h(idx_ch), p_normalyty] = lillietest(data_feature(idx_ch,:));
            p_normalyty_test(w,idx_ch) = p_normalyty;
        end

        hh = max(h);

        if ( hh == 1)
            % If the distribution do not follow the normal distribution

            disp(["Window " w " do not follow normal distribution, performing perbutation test"])

            all_diffs = feature_err - permute(resampled_feature2, [1, 3, 2]);
            all_diffs = reshape(all_diffs, size(feature_err, 1), []);
            
            obs_diff = mean(all_diffs, 2)';

            % Compute the permutation test

            perm_diffs = zeros(num_permutation, num_feature);
    
            combined_data = [feature_err, feature_cor]; % Merge all trials
            num_total = size(combined_data, 2); % Total trials (2*n)
        
            for p = 1:num_permutation
                perm_labels = randperm(num_total); % Shuffle labels

                perm1 = combined_data(:, perm_labels(1:size(feature_err,2)));
                perm2 = combined_data(:, perm_labels(size(feature_err,2)+1:end));

                temp_diffs = perm1 - permute(perm2, [1, 3, 2]);
                temp_diffs = reshape(temp_diffs, size(perm1, 1), []); 

                perm_diffs(p, :) = mean(temp_diffs, 2);
            end
            
            % Compute p-values (two-tailed test)
            p_values_perb(w, :) = mean(abs(perm_diffs) >= abs(obs_diff));
        else
            % If the data follows the normal distribution, compute the
            % t-test NOTE: ttest for one subject and ttest2 for more
            % than a subject at the same time!!
            for i = 1:num_feature
                if multiple_sub == true
                    [~, p_ttest, ~, ~] = ttest2(feature_err(i,:), resampled_feature2(i,:));
                else
                    [~, p_ttest, ~, ~] = ttest(feature_err(i,:), resampled_feature2(i,:));
                end
                p_values_norm(w,i) = p_ttest;
            end 
        end
       
    end

    warning('on', 'stats:lillietest:OutOfRangePLow');

    pvalue = p_values_norm + p_values_perb;

    other_p.p_values_perb = p_values_perb;
    other_p.p_values_norm = p_values_norm;
    other_p.plverr_values = plverr_values;
    other_p.plvcor_values = plvcor_values;
    other_p.p_normalyty_test = p_normalyty_test;

end


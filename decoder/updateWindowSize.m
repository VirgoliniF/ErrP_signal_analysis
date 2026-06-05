function [filter_timeWindow] = updateWindowSize(params,proportion_start,proportion_end)

    % Calculate filter time based on the input proportions
    epoch_duration = params.epochEnd - params.epochStart;
    
    filter_time_start = params.epochStart + proportion_start * epoch_duration;
    filter_time_end = params.epochStart + proportion_end * epoch_duration;

    % Convert times to samples
    filter_time_start_sample = round(filter_time_start * params.fsamp) + 1;
    filter_time_end_sample = round(filter_time_end * params.fsamp);

    % Ensure filter time is within bounds of epoch
    filter_time_start_sample = max(filter_time_start_sample, 1); % Ensure starting index is at least 1
    filter_time_end_sample = min(filter_time_end_sample, length(params.epochTime)); % Ensure ending index does not exceed epoch length

    % Set filter time window
    filter_timeWindow = filter_time_start_sample:filter_time_end_sample;
    filter_timeWindow = filter_timeWindow + params.epochOnset - 1;

    % Ensure filter time indices do not exceed the size of the epoch time
    filter_timeWindow(filter_time_end_sample > length(params.epochTime)) = [];

    % % Print statements for debugging
    % fprintf('Epoch Start: %g, Epoch End: %g\n', params.epochStart, params.epochEnd);
    % fprintf('Filter Time Start: %g, Filter Time End: %g\n', filter_time_start, filter_time_end);
    % fprintf('Filter Time Indices: [%s]\n', num2str(filter_timeWindow));

end

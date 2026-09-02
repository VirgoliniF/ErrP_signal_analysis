

function [tf_negative_db_conversion, tf_neutral_db_conversion, tf_difference_neg_db_conversion, frex] = compute_theta_peak_v3_1Dcursor(eegEpochs_pre, params, baseline_subtract, baseline_normalise, error_correct_subtraction, chan)

%close all

signal_range = dsearchn(params.epochTime', 0.0):dsearchn(params.epochTime', 1.0);

wavtime = -2:1/params.fsamp:2;
%cut the first half and the last half of the convolution (N + M - 1)
half_wave = (length(wavtime)-1)/2;
wavelet_num_cycles_list = [6];

plotting = false;

min_freq =  1;
max_freq = 30;
%increase frequency resolution
freq_res = 0.1;
frex = min_freq:freq_res:max_freq;
amplitude_threshold = 10000;
%Same baseline as Reinhart PNAS
baseline_range = [dsearchn(params.epochTime', -0.3):dsearchn(params.epochTime', -0.1)];

for wav_id = 1:length(wavelet_num_cycles_list)
    keep_index = not(squeeze(any(any(abs(eegEpochs_pre.data(signal_range, :, :)) > amplitude_threshold))));
    logical_index_negative = eegEpochs_pre.label == 1 & keep_index ;
    temp_negative = eegEpochs_pre.data(:, :, logical_index_negative);
    logical_index_positive = eegEpochs_pre.label == 2 & keep_index ;
    temp_positive = eegEpochs_pre.data(:, :, logical_index_positive);
    logical_index_neutral = eegEpochs_pre.label == 3 & keep_index ;
    temp_neutral = eegEpochs_pre.data(:, :, logical_index_neutral);

    %FFT parameters (block of trials -> computational efficiency)
    nWave = length(wavtime);
    nData = size(temp_negative, 1) * size(temp_negative, 3); %number of samples x number of trials
    nConv = nWave + nData - 1;
    
    % now compute the FFT of all trials concatenated
    %reshape to one vector
    alldata = reshape( temp_negative(:, chan, :) ,1,[]);
    dataX   = fft( alldata ,nConv );
    
    % initialize output time-frequency data
    tf_negative = zeros(length(frex),size(temp_negative,1));
    % loop over frequencies
    for fi=1:length(frex)
        wavelet_freq = frex(fi);
        s = wavelet_num_cycles_list(wav_id)/(2*pi*wavelet_freq);
        %morlet wavelet
        wavelet  = exp(2*1i*pi*wavelet_freq.*wavtime) .* exp(-wavtime.^2./(2*s^2));
        %mexican hat wavelet
        
        waveletX = fft(wavelet,nConv);
        %Normalise against amplitude
        waveletX = waveletX ./ max(waveletX);
        
        % now run convolution in one step
        as = ifft(waveletX .* dataX);
        % only select the part relevant to the signal
        as = as(half_wave+1:end-half_wave);
        
        % and reshape back to time X trials
        as = reshape( as, size(temp_negative, 1), size(temp_negative, 3) );
        
        % compute power and average over trials
        tf_negative(fi,:) = mean( abs(as).^2 ,2);
        
    end
    
    nWave = length(wavtime);
    nData = size(temp_positive, 1) * size(temp_positive, 3); %number of samples x number of trials
    nConv = nWave + nData - 1;
    
    % now compute the FFT of all trials concatenated
    %reshape to one vector
    alldata = reshape(temp_positive(:, chan, :) ,1,[]);
    dataX   = fft( alldata ,nConv );
    
    % initialize output time-frequency data
    tf_positive = zeros(length(frex),size(temp_positive,1));
    % loop over frequencies
    for fi=1:length(frex)
        wavelet_freq = frex(fi);
        s = wavelet_num_cycles_list(wav_id)/(2*pi*wavelet_freq);
        %morlet wavelet
        wavelet  = exp(2*1i*pi*wavelet_freq.*wavtime) .* exp(-wavtime.^2./(2*s^2));
        %mexican hat wavelet
        
        waveletX = fft(wavelet,nConv);
        %Normalise against amplitude
        waveletX = waveletX ./ max(waveletX);
        
        % now run convolution in one step
        as = ifft(waveletX .* dataX);
        % only select the part relevant to the signal
        as = as(half_wave+1:end-half_wave);
        
        % and reshape back to time X trials
        as = reshape( as, size(temp_positive, 1), size(temp_positive, 3) );
        
        % compute power and average over trials
        tf_positive(fi,:) = mean(abs(as).^2 ,2);
        
    end

    nWave = length(wavtime);
    nData = size(temp_neutral, 1) * size(temp_neutral, 3); %number of samples x number of trials
    nConv = nWave + nData - 1;
    
    % now compute the FFT of all trials concatenated
    %reshape to one vector
    alldata = reshape(temp_neutral(:, chan, :) ,1,[]);
    dataX   = fft( alldata ,nConv );
    
    % initialize output time-frequency data
    tf_neutral = zeros(length(frex),size(temp_neutral,1));
    % loop over frequencies
    for fi=1:length(frex)
        wavelet_freq = frex(fi);
        s = wavelet_num_cycles_list(wav_id)/(2*pi*wavelet_freq);
        %morlet wavelet
        wavelet  = exp(2*1i*pi*wavelet_freq.*wavtime) .* exp(-wavtime.^2./(2*s^2));
        %mexican hat wavelet
        
        waveletX = fft(wavelet,nConv);
        %Normalise against amplitude
        waveletX = waveletX ./ max(waveletX);
        
        % now run convolution in one step
        as = ifft(waveletX .* dataX);
        % only select the part relevant to the signal
        as = as(half_wave+1:end-half_wave);
        
        % and reshape back to time X trials
        as = reshape( as, size(temp_neutral, 1), size(temp_neutral, 3) );
        
        % compute power and average over trials
        tf_neutral(fi,:) = mean(abs(as).^2 ,2);
        
    end
    
    %Apply to trial average power
    % db conversion
    tf_negative_db_conversion = zeros(size(tf_negative,1), size(tf_negative,2));
    tf_negative_percentage_change = zeros(size(tf_negative,1), size(tf_negative,2));
    if baseline_normalise
        for freq_id = 1:size(tf_negative,1)
            tf_negative_db_conversion(freq_id,:) = 10*log10(tf_negative(freq_id,:) ./ mean(tf_negative(freq_id,baseline_range),2));
            tf_negative_percentage_change(freq_id,:) = (tf_negative(freq_id,:) - mean(tf_negative(freq_id,baseline_range),2)) ./ mean(tf_negative(freq_id,baseline_range),2);
        end
    end

    
    tf_positive_db_conversion = zeros(size(tf_positive,1), size(tf_positive,2));
    tf_positive_percentage_change = zeros(size(tf_positive,1), size(tf_positive,2));
    if baseline_normalise
        for freq_id = 1:size(tf_positive,1)
            tf_positive_db_conversion(freq_id,:) = 10*log10(tf_positive(freq_id,:) ./ mean(tf_positive(freq_id,baseline_range),2));
            tf_positive_percentage_change(freq_id,:) = (tf_positive(freq_id,:) - mean(tf_positive(freq_id,baseline_range),2)) ./ mean(tf_positive(freq_id,baseline_range),2);
        end
    end

    tf_neutral_db_conversion = zeros(size(tf_neutral,1), size(tf_neutral,2));
    tf_neutral_percentage_change = zeros(size(tf_neutral,1), size(tf_neutral,2));
    if baseline_normalise
        for freq_id = 1:size(tf_neutral,1)
            tf_neutral_db_conversion(freq_id,:) = 10*log10(tf_neutral(freq_id,:) ./ mean(tf_neutral(freq_id,baseline_range),2));
            tf_neutral_percentage_change(freq_id,:) = (tf_neutral(freq_id,:) - mean(tf_neutral(freq_id,baseline_range),2)) ./ mean(tf_neutral(freq_id,baseline_range),2);
        end
    end


    %Compute the difference
    
    if (error_correct_subtraction)
        tf_difference_neg_db_conversion = tf_negative_db_conversion - tf_neutral_db_conversion;
        tf_difference_pos_db_conversion = tf_positive_db_conversion - tf_neutral_db_conversion;
    end
  

    if plotting == true

        % Not plotting if NaN values
        isAllNaN = all(isnan(tf_negative_db_conversion), 'all');
        if ~isAllNaN
            figure; clf;
            contourf(params.epochTime(80:end-80),frex,tf_negative_db_conversion(:,(80:end-80)))
            title(['tf of negative valence trials (db conversion): ' num2str(wavelet_num_cycles_list(wav_id)) 'cycles']);
            %contourf(params.epochTime,frex,tf .* 100,40,'linecolor','none')
            %set(gca,'clim',[0 400],'ydir','normal')
            xlabel('Time [s]', 'FontSize',10);
            ylabel('Frequency [Hz]', 'FontSize',10);
            colorbar
        end
        
        isAllNaN = all(isnan(tf_positive_db_conversion), 'all');
        if ~isAllNaN
            figure; clf;
            contourf(params.epochTime(80:end-80),frex,tf_positive_db_conversion(:,(80:end-80)))
            title(['tf of positive valence trials (db conversion): ' num2str(wavelet_num_cycles_list(wav_id)) 'cycles']);
            %contourf(params.epochTime,frex,tf .* 100,40,'linecolor','none')
            %set(gca,'clim',[0 400],'ydir','normal')
            xlabel('Time [s]', 'FontSize',10);
            ylabel('Frequency [Hz]', 'FontSize',10);
            colorbar
        end

        isAllNaN = all(isnan(tf_neutral_db_conversion), 'all');
        if ~isAllNaN
            figure; clf;
            contourf(params.epochTime(80:end-80),frex,tf_neutral_db_conversion(:,(80:end-80)))
            title(['tf of neutral trials (db conversion): ' num2str(wavelet_num_cycles_list(wav_id)) 'cycles']);
            %contourf(params.epochTime,frex,tf .* 100,40,'linecolor','none')
            %set(gca,'clim',[0 400],'ydir','normal')
            xlabel('Time [s]', 'FontSize',10);
            ylabel('Frequency [Hz]', 'FontSize',10);
            colorbar
        end

        isAllNaN = all(isnan(tf_difference_neg_db_conversion), 'all');
        if ~isAllNaN
            figure; clf;
            contourf(params.epochTime(80:end-80),frex,tf_difference_neg_db_conversion(:,(80:end-80)))
            title(['tf of negative - neutral trials (db conversion): ' num2str(wavelet_num_cycles_list(wav_id)) 'cycles']);
            %contourf(params.epochTime,frex,tf .* 100,40,'linecolor','none')
            %set(gca,'clim',[0 400],'ydir','normal')
            xlabel('Time [s]', 'FontSize',10);
            ylabel('Frequency [Hz]', 'FontSize',10);
            colorbar
        end

        isAllNaN = all(isnan(tf_difference_pos_db_conversion), 'all');
        if ~isAllNaN
            figure; clf;
            contourf(params.epochTime(80:end-80),frex,tf_difference_pos_db_conversion(:,(80:end-80)))
            title(['tf of positive - neutral trials (db conversion): ' num2str(wavelet_num_cycles_list(wav_id)) 'cycles']);
            %contourf(params.epochTime,frex,tf .* 100,40,'linecolor','none')
            %set(gca,'clim',[0 400],'ydir','normal')
            xlabel('Time [s]', 'FontSize',10);
            ylabel('Frequency [Hz]', 'FontSize',10);
            colorbar
        end
        
        % figure; clf;
        % contourf(params.epochTime(80:end-80),frex,tf_negative_percentage_change(:,(80:end-80)))
        % title(['tf of negative trials (percentage change): ' num2str(wavelet_num_cycles_list(wav_id)) 'cycles']);
        % %contourf(params.epochTime,frex,tf .* 100,40,'linecolor','none')
        % %set(gca,'clim',[0 400],'ydir','normal')
        % colorbar
        % 
        % figure; clf;
        % contourf(params.epochTime(80:end-80),frex,tf_positive_percentage_change(:,(80:end-80)))
        % title(['tf of positive trials (percentage change): ' num2str(wavelet_num_cycles_list(wav_id)) 'cycles']);
        % %contourf(params.epochTime,frex,tf .* 100,40,'linecolor','none')
        % %set(gca,'clim',[0 400],'ydir','normal')
        % colorbar
        % 
        % figure; clf;
        % contourf(params.epochTime(80:end-80),frex,tf_neutral_percentage_change(:,(80:end-80)))
        % title(['tf of neutral trials (percentage change): ' num2str(wavelet_num_cycles_list(wav_id)) 'cycles']);
        % %contourf(params.epochTime,frex,tf .* 100,40,'linecolor','none')
        % %set(gca,'clim',[0 400],'ydir','normal')
        % colorbar

    end
    
end









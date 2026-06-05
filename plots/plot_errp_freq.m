
function plot_errp_freq(t, correct, error, refchannelidx)

    function [t_out, fc, freq_out] = compute_freq(t, data, refchannelidx)
        data = data(:,refchannelidx, :);
    
        %% Now data is a matrix of size [n_times, n_trials]
    
        % compute the frequency spectrum for each trial 
        % and then average across trials

        nfft = 2^10;
        Fs = 512;
        overlap = 7;  
        windowLength = 8;

        tmp = spectrogram(data(:,1,1), windowLength, overlap, nfft, Fs);

        mat = zeros(size(tmp,1),size(tmp,2),size(data,3));

        for i = 1:size(data,3)
            [mat(:,:,i) ,F,T] = spectrogram(data(:,1,i), windowLength, overlap, nfft, Fs);
        end
   
        fc = mean(mat,3);

        t_out = T - abs(t(1));
        freq_out = F;
        
    end

    function ppt_f(t, datam,f)
        imagesc(t, f, real(10*log10(real(datam))), [0, 10])
        ylim([0 20])
        axis xy
    end

    % I may need to perform a baseline correction

    [~, fc, ~] = compute_freq(t, correct, refchannelidx);
    [t_out, fe, freq_out] = compute_freq(t, error,   refchannelidx);

    figure()
    subplot(3,1,1)
    ppt_f(t_out, fe, freq_out)
    title("error")
    colorbar;

    subplot(3,1,2)
    ppt_f(t_out, fc, freq_out)
    title("correct")
    colorbar;

    subplot(3,1,3)
    ppt_f(t_out, fe-fc, freq_out)
    title("diff")
    colorbar;

    
end

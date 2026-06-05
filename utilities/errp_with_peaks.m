function rmevt_peaks = errp_with_peaks(ePOS, eeg, epoch, fs, treshold )
    rmevt_peaks = [];
    
    for i = 1:length(ePOS)
        infe = ePOS(i) + floor(epoch(1)*fs);
        supp = ePOS(i) + floor(epoch(2)*fs);

        if (infe > 1 && supp < size(eeg,1) )
            signal = eeg(infe:supp, :);
            data = unique(signal);
            if (data(1) < -treshold ||  data(length(data)) > treshold )
            %if (max(max(abs(signal))) > treshold )
                rmevt_peaks = [ i, rmevt_peaks];
            end
        end
    end

end


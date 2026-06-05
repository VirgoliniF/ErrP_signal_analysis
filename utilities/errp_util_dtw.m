function delays = errp_find_dtw(eeg, refchannel, eTYP, ePOS, epoch, samplerate, errorCodecs, correctCodecs, Ck, Ek )
    delays = ones(length(ePOS),1);

    ntrials = length(ePOS);

    errorPOSITIONS = [];

    for tryID = 1:ntrials
        if ismember(eTYP(tryID), errorCodecs)
            errorPOSITIONS(length(errorPOSITIONS) + 1) = ePOS(tryID);
        end
    end

    nchannels  = size(eeg, 2);
    nsamples  = length(epoch(1):1/samplerate:epoch(2));
    T    = nan(nsamples, nchannels, ntrials);
    for trId = 1:ntrials
        cstart = ePOS(trId) + floor(epoch(1)*samplerate);
        cstop  = ePOS(trId) + floor(epoch(2)*samplerate);
        T(:, :, trId) = eeg(cstart:cstop, :);
    end

    m_eeg_err = squeeze(mean(T(:, refchannel, Ek), 3));
    m_eeg_cor = squeeze(mean(T(:, refchannel, Ck), 3));

    %select_index = length(errorPOSITIONS);
    
    base_err_sign = m_eeg_err;
    base_cor_sign = m_eeg_cor;
    % eeg(errorPOSITIONS(select_index) + epoch(1)*samplerate: errorPOSITIONS(select_index) + epoch(2)*samplerate, refchannel);

    figure;
    plot(base_err_sign)
    hold on
    plot(base_cor_sign)

    %d = zeros(length(errorPOSITIONS)-1,1);

    t = -100:100;

    % parfor index_erros = 2:length(errorPOSITIONS)
    %     dd = zeros(length(t),1);
    % 
    %     for i = 1:length(t)
    %         shift = t(i);
    %         sing = eeg(errorPOSITIONS(index_erros) + epoch(1)*samplerate + shift: errorPOSITIONS(index_erros) + epoch(2)*samplerate + shift, refchannel);
    %         dd(i) = dtw(base_err_sign, sing);
    %     end
    %     %sing = eeg(errorPOSITIONS(index_erros) + epoch(1)*samplerate: errorPOSITIONS(index_erros) + epoch(2)*samplerate, refchannel);
    %     %[~, ix, iy] = dtw(base_err_sign, sing);
    %     [~,i_min] = min(dd);
    %     d(index_erros -1) = t(i_min);
    % end
    %
    % delays = delays * mean(d)

    disp('     |- comuting dtw alliniament');


    parfor index_erros = 1:ntrials
        dd = zeros(length(t),1);

        for i = 1:length(t)
            shift = t(i);
            sing = eeg(ePOS(index_erros) + epoch(1)*samplerate + shift: ePOS(index_erros) + epoch(2)*samplerate + shift, refchannel);
            if ismember(ePOS(index_erros), errorCodecs)
                dd(i) = dtw(base_err_sign, sing);
            else
                dd(i) = dtw(base_cor_sign, sing);
            end
        end
        %sing = eeg(errorPOSITIONS(index_erros) + epoch(1)*samplerate: errorPOSITIONS(index_erros) + epoch(2)*samplerate, refchannel);
        %[~, ix, iy] = dtw(base_err_sign, sing);
        [~,i_min] = min(dd);
        delays(index_erros) = t(i_min);
        %d(index_erros -1) = t(i_min);
    end

    %delays

    %delays = delays * mean(d)

end
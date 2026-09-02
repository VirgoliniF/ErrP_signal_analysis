function [tf_neg, tf_neu, tf_diff, frex] = errp_compute_frequency(Tu, Ek, Ck, setting)
    
    params.epochTime = setting.t;
    params.fsamp = setting.samplerate;
    eegEpochs_pre.data = Tu;
    eegEpochs_pre.label = zeros(size(Tu,3),1);
    eegEpochs_pre.label = eegEpochs_pre.label + Ek;
    eegEpochs_pre.label = eegEpochs_pre.label + Ck * 3;

    [~, refchannelidx] = ismember(upper(setting.refchannel), upper(setting.mask)); %% todo change this

    [tf_neg, tf_neu, tf_diff, frex] = compute_theta_peak_v3_1Dcursor(eegEpochs_pre, params, false, true, true, refchannelidx);

end


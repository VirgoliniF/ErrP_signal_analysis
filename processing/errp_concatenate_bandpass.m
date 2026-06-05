function [F, E, events, labels, settings] = errp_concatenate_bandpass(files)

    %warning('off', 'backtrace');
    nfiles = length(files);
    
    % Getting size info to allocate memory and speedup the concatenation
    eegsize      = get_data_size(files, 'eeg');
    eogsize      = get_data_size(files, 'eog');
    eegnsamples  = sum(eegsize(1, :));
    eegnchannels = unique(eegsize(2, :));
    eognchannels = unique(eogsize(2, :));
    
    F  = nan(eegnsamples, eegnchannels);
    E  = nan(eegnsamples, eognchannels);
    Rk = nan(eegnsamples, 1);                    % Run
    Pk = nan(eegnsamples, 1);                    % Control
    Dk = nan(eegnsamples, 1);                    % Day
    Wk = nan(eegnsamples, 1);                    % Week
    Nk = nan(eegnsamples, 1);                    % Month
    Sk = nan(eegnsamples, 1);
    Dl = [];                                    % Day label
    
    settings = [];
    TYP = []; POS = []; DUR = [];
    runId = 1;
    currday  = 0;
    cweekId  = 0;
    cmonthId = 0;
    lastday  = [];
    lweek    = [];
    lmonth   = [];
    currsubj = '';
    currsubjId = 0;
    
    fileseek = 1;
    for fId = 1:nfiles
    
        cfile = files{fId};
        util_disp_progress(fId, nfiles, '        ');
        cdata = load(cfile);

        % Get current position 
        cstart   = fileseek;
        cstop    = cstart + eegsize(1, fId) - 1;
        
        % Get subject
        if(strcmp(cdata.settings.info.subject, currsubj) == false)
            currsubjId = currsubjId + 1;
            currsubj = cdata.settings.info.subject;
        end
        
        % Get run control type
        if(strcmpi(cdata.settings.control.name, 'unknown'))
            error(['Unknown protocol type: ' cdata.settings.control.name]);
        else
            [~, ccontrol] = intersect(cdata.settings.control.legend, cdata.settings.control.name);
        end
        
        % Get day id and label
        if strcmpi(cdata.settings.info.date, lastday) == false
            currday = currday + 1;
            Dl = cat(1, Dl, cdata.settings.info.date);
            lastday = cdata.settings.info.date;
        end

        % Get week id
        cweek = week(datetime(cdata.settings.info.date, 'InputFormat', 'yyyyMMdd'));
        if isequal(cweek, lweek) == false
            cweekId = cweekId +1;
            lweek = cweek;
        end

        % Get month id
        cmonth = month(datetime(cdata.settings.info.date, 'InputFormat', 'yyyyMMdd'));
        if isequal(cmonth, lmonth) == false
            cmonthId = cmonthId +1;
            lmonth = cmonth;
        end

        % Create labels
        Pk(cstart:cstop) = ccontrol;
        Rk(cstart:cstop) = runId;
        Dk(cstart:cstop) = currday;
        Wk(cstart:cstop) = cweekId;
        Nk(cstart:cstop) = cmonthId; 
        Sk(cstart:cstop) = currsubjId; 

        % Concatenate events
        TYP = cat(1, TYP, cdata.settings.events.TYP);
        DUR = cat(1, DUR, cdata.settings.events.DUR);
        POS = cat(1, POS, cdata.settings.events.POS + fileseek - 1);

        % Concatenate data
        F(cstart:cstop, :) = cdata.eeg;
        E(cstart:cstop, :) = cdata.eog;
        
        % Save the current settings, remove number of sample and filename,
        % and compare it with the previous settings. If different, it
        % raises an error.
        csettings = cdata.settings;
        csettings.data.nsamples = nan;
        csettings.data.filename = nan;
        csettings.date          = nan;
        csettings.control.name  = nan;
        csettings.info          = nan;
        csettings.spatial       = nan;
        
        
        if(isempty(settings))
            settings = csettings;
        end

        % Update runId
        runId = runId + 1;
        
        % Update the fileseek position
        fileseek = cstop + 1;
        
        
    end
    
    events.TYP = TYP;
    events.POS = POS;
    events.DUR = DUR;
    
    labels.samples.Pk = Pk;
    labels.samples.Rk = Rk;
    labels.samples.Dk = Dk;
    labels.samples.Wk = Wk;
    labels.samples.Nk = Nk;
    labels.samples.Sk = Sk;
    
    labels.run.Dl = Dl;
   
   % warning('on', 'backtrace');
end

function dsizes = get_data_size(filepaths, variable)

    nfiles = length(filepaths);
    ndimensions = 2;                            % samples x chans
    
    dsizes = zeros(ndimensions, nfiles);
    
    for fId = 1:nfiles
        cfilepath = filepaths{fId};
        cinfo = whos('-file', cfilepath, variable);
        dsizes(:, fId) = cinfo.size;    
    end

end




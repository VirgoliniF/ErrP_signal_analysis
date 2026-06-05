function [pose, twist, cmdvel, events, labels] = errp_concatenate_bags(files)

    %warning('off', 'backtrace');
    nfiles = length(files);
    
    % Getting size info to allocate memory and speedup the concatenation
    datasize = get_data_size(files);
    nsamples  = sum(datasize(1, :));
    
    posex   = nan(nsamples, 1);
    posey   = nan(nsamples, 1);
    posez   = nan(nsamples, 1);
    twistx  = nan(nsamples, 1);
    twisty  = nan(nsamples, 1);
    twistz  = nan(nsamples, 1);
    cmdvelx = nan(nsamples, 1);
    cmdvely = nan(nsamples, 1);
    cmdvelz = nan(nsamples, 1);
    

    Rk = nan(nsamples, 1);                    % Run  
    
    TYP = []; POS = []; ERR = [];
    runId = 1;
    
    fileseek = 1;
    for fId = 1:nfiles
    
        cfile = files{fId};
        util_disp_progress(fId, nfiles, '        ');
        cdata = load(cfile);

        % Get current position 
        cstart   = fileseek;
        cstop    = cstart + datasize(1, fId) - 1;

        % Create labels
        Rk(cstart:cstop) = runId;

        % Concatenate events
        TYP = cat(1, TYP, cdata.events.TYP);
        ERR = cat(1, ERR, cdata.events.ERR);
        POS = cat(1, POS, cdata.events.POS + fileseek - 1);

        % Concatenate data
        posex(cstart:cstop, :) = cdata.pose.x;
        posey(cstart:cstop, :) = cdata.pose.y;
        posez(cstart:cstop, :) = cdata.pose.z;
        twistx(cstart:cstop, :) = cdata.twist.x;
        twisty(cstart:cstop, :) = cdata.twist.y;
        twistz(cstart:cstop, :) = cdata.twist.z;
        cmdvelx(cstart:cstop, :) = cdata.cmdvel.x;
        cmdvely(cstart:cstop, :) = cdata.cmdvel.y;
        cmdvelz(cstart:cstop, :) = cdata.cmdvel.z;
        

        % Update runId
        runId = runId + 1;
        
        % Update the fileseek position
        fileseek = cstop + 1;
        
        
    end
    
    events.TYP = TYP;
    events.POS = POS;
    events.ERR = ERR;
    
    labels.samples.Rk = Rk;
    pose.x = posex;
    pose.y = posey;
    pose.z = posez;
    twist.x = twistx;
    twist.y = twisty;
    twist.z = twistz;
    cmdvel.x = cmdvelx;
    cmdvel.y = cmdvely;
    cmdvel.z = cmdvelz;

   % warning('on', 'backtrace');
end

function dsizes = get_data_size(filepaths)

    nfiles = length(filepaths);
    ndimensions = 2;                            % samples x chans
    
    dsizes = zeros(ndimensions, nfiles);

    for fId = 1:nfiles
        cfilepath = filepaths{fId};
        cinfo = load(cfilepath);
        dsizes(:, fId) = size(cinfo.pose.x);    
    end

end

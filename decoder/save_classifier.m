function savefile = save_classifier(decoder, configure)
    base = '/var/home/piero/Projects/ros/errp_usa_ws/cfg/';

    savefile.RiemannCfg = [];
    savefile.RiemannCfg.name = 'riemann';
    savefile.RiemannCfg.type = 'RiemannCfg';
    savefile.RiemannCfg.params = [];
    savefile.RiemannCfg.params.channels = int16(decoder.refchannelidx); % Recall you need to remove one from this in cpp
    %configure.channels; % TODO: check if I could do this in this way or is better in others
    savefile.RiemannCfg.params.subjects = configure.sub;
    
    if decoder.riemann.fgda.is_compute == true
        savefile.RiemannCfg.params.mode = "fgda";

        % Save the fgda components

        savefile.RiemannCfg.params.Cg = decoder.riemann.Cg;

        savefile.RiemannCfg.params.size_w = [size(decoder.riemann.W,1), size(decoder.riemann.W,2)];
        
        savefile.RiemannCfg.params.w_filename = [base 'w' char(datetime("today")) configure.sub '.yaml'];

    else
        savefile.RiemannCfg.params.mode = "mda";

        % Save the mda components
        savefile.RiemannCfg.params.online = 1; % Yust do not update the data

        savefile.RiemannCfg.params.reference_matrix = decoder.riemann.reference_train;
    end

    savefile.RiemannCfg.params.template_correct = decoder.riemann.template_correct;
    savefile.RiemannCfg.params.template_error   = decoder.riemann.template_error;


    % Save the common components

    savefile.RiemannCfg.params.downsample = decoder.downsample;

    savefile.RiemannCfg.params.treshold = decoder.threshold;
    savefile.RiemannCfg.params.treshold_min = decoder.threshold_min;
    
    savefile.RiemannCfg.params.class_prototypes_1 = decoder.riemann.prototype_correct;
    savefile.RiemannCfg.params.class_prototypes_2 = decoder.riemann.prototype_error;

    savefile.RiemannCfg.params.tasks = [0, 1];
    savefile.RiemannCfg.params.time_leng = decoder.time_leng;

    save([base 'base' char(datetime("today")) configure.sub '.mat'], 'decoder');
    disp([base 'base' char(datetime("today")) configure.sub '.mat']);
    
    yaml.dumpFile([base 'base' char(datetime("today")) configure.sub '.yaml'], savefile);

    % Save the w matrix, since it can be big, I manually write it down

    if decoder.riemann.fgda.is_compute == true
        
        chunkSize = 100; % Define chunk size
        fileID = fopen(savefile.RiemannCfg.params.w_filename, 'w');
    
        fprintf(fileID, ' w:\n');
    
        for i = 1:chunkSize:size(decoder.riemann.W, 1)
            chunk = decoder.riemann.W(i:min(i+chunkSize-1, size(decoder.riemann.W, 1)), :);
            for j = 1:size(chunk, 1)
                fprintf(fileID, '  - [');
                fprintf(fileID, '%g, ', chunk(j, 1:end-1));
                fprintf(fileID, '%g]\n', chunk(j, end)); % Avoid trailing comma
            end
        end
        
        fclose(fileID);
    else 
    end

end
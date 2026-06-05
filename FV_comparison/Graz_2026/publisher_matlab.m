opts = struct;
opts.format    = 'html';     % oppure 'pdf'
opts.outputDir = fullfile(pwd,'published');
opts.showCode  = true;
opts.evalCode  = false;      % importante: non eseguire il file
publish('errp_load_settings.m', opts);
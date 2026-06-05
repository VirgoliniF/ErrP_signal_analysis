function [outputArg1,outputArg2] = new_errp_prepare_bag(subject,setting, task)

   
    includepat  = subject;
    excludepat  = {'filtered'};
    depthlevel  = 2;
    error_modality = setting.error_modality;

    if strcmp(error_modality, 'visual')
        rootpath    = '/home/braingear/Research/FV_data';
        folder      = 'gdf_recordings/wheelchair_errp/visual';
        savedirraw     = 'analysis_visual/bags/raw/';
        savedir_processed     = 'analysis_visual/bags/aligned/';
    else
        rootpath    = '/home/braingear/Research/FV_data';
        folder      = 'gdf_recordings/wheelchair_errp/vestibular';
        savedirraw     = 'analysis_vestibular/bags/raw/';
        savedir_processed     = 'analysis_vestibular/bags/aligned/';
    end

    
    rawbagpath       = [rootpath '/' folder '/' task '/' ];


    bagpath     =  savedirraw;
    gdfpath     = rawbagpath;


    errp_processing_bags_new(includepat, excludepat, depthlevel, setting, rawbagpath, savedirraw)
    errp_processing_align_bags_new(includepat, excludepat, depthlevel, setting, savedir_processed, bagpath, gdfpath)
    

end
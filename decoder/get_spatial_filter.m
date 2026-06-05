function [spatial_matrix] = get_spatial_filter(filter_type, eeg, labels, params)

switch (filter_type)
    case 'CAR'
        nChannels = size(eeg, 2);
        spatial_matrix = eye(nChannels, nChannels);
        spatial_matrix( spatial_matrix==0 ) = -(1 / nChannels);
        spatial_matrix( spatial_matrix==1 ) = 1-(1 / nChannels);
        
    case 'Laplace'
        load('laplacian16.mat');
        spatial_matrix = lap;
        
    case 'Xdawn'
        spatial_matrix = get_xdawn_spatialfilter(eeg, params);
        
    case 'CCA'
        eeg = eeg(params.spatialFilter.time,:,:);
        spatial_matrix = get_cca_spatialfilter(eeg, labels);
        
    case 'xDAWN'
        eeg = eeg(params.spatialFilter.time,:,:);
        spatial_matrix = get_xdawn_spatialfilter(eeg, labels);
        
    case 'CSD'
        montage = ExtractMontage('10-5-System_Mastoids_EGI129.csd',{params.chanlocs.labels}');
        [spatial_matrix.g, spatial_matrix.h] = GetGH(montage);
        
    case 'None'
        spatial_matrix = eye(size(eeg,2), size(eeg,2));
        
    otherwise
        error('Unknown spatial filter');
end

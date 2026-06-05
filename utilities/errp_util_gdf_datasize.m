function [nsamples, nchannels] = errp_util_gdf_datasize(filepaths)

    nfiles = length(filepaths);

    nsamples  = nan(nfiles, 1);
    nchannels = nan(nfiles, 1);
    
    for fId = 1:nfiles
        gdffile = filepaths{fId};

        h = sopen(gdffile, 'r');
        nsamples(fId)  = h.NRec*h.SampleRate;
        nchannels(fId) = h.NS;

           
    end

end
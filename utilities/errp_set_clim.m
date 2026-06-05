function handles = errp_set_clim(handles, limits)

    nhandles = length(handles);

    maxclim = 0;
    minclim = 0;

    
    for hId = 1:nhandles
        chandle = handles(hId);
        clims = clim(chandle.Parent);
        maxclim = max(maxclim, clims(2));
        minclim = min(minclim, clims(1));
    end
    

    for hId = 1:nhandles
        chandle = handles(hId);
        clim(chandle.Parent, [minclim maxclim]);
    end


end
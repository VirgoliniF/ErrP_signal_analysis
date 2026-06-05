function [chanlocs, foundid] = plot_getchanlocs(channels, chanlocsstr)

    
    [found, index] = ismember(lower(channels), cellfun(@(x) lower(x), {chanlocsstr(:).labels}, 'UniformOutput', false));
    chanlocs = chanlocsstr(nonzeros(index));
    foundid = find(found);

end
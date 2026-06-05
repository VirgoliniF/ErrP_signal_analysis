function chanlocs = errp_util_get_chanlocs(labels, allchanlocs)

    %[~, idx] =
    idx = ismember(lower(labels), lower({allchanlocs.labels}));

    %idx

    chanlocs = allchanlocs(idx);
    

end
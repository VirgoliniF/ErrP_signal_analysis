function alignment = errp_find_alignment(evtbag, evtgdf)

    % Get all events from gdf file
    events_of_interest = unique(evtgdf.TYP);

    % Get event index from bag
    evtbag_index = get_event_index(events_of_interest, evtbag.TYP);

    % Extract events from bag structure
    evtbag.TYP = evtbag.TYP(evtbag_index);
    evtbag.POS = evtbag.POS(evtbag_index);
    evtbag.ERR = evtbag.ERR(evtbag_index);

    % Find GDF sequence in bag event list
    start_idx = find_sequence(evtgdf.TYP, evtbag.TYP);

    % If sequence has been found, than use the first event to compute the
    % displacement
    if(isempty(start_idx) == false)
        alignment = evtbag.POS(start_idx) - evtgdf.POS(1);
    end

end

function index = get_event_index(eoi, elist)

    index = false(length(elist), 1);

    for eId = 1:length(eoi)
        index = index | elist == eoi(eId);
    end

end

function [idx_start, seq] = find_sequence(seq, list, minseqlength)
% It find sequence SEQ in a LIST. It returns the index of the begin of the
% sequence in LIST and the sequence found.

    if (nargin == 2)
        minseqlength = 3;
    end

    idx_start = [];
    idx_seq_end   = length(seq) + 1;

    while(isempty(idx_start) == true)
        idx_seq_end = idx_seq_end -1;
        idx_start = strfind(list', seq(1:idx_seq_end)');
    end

    if(idx_seq_end < minseqlength)
        error(['[errp_align_bag] - Cannot find a subsequence longer than ' num2str(minseqlength) ' elements']);
    elseif(isequal(idx_seq_end, length(seq)) == false)
        warning(['[errp_align_bag] - Found subsequence from index 1 to ' num2str(idx_seq_end)]);
    end

    seq = seq(1:idx_seq_end);

end


function excluded = errp_util_events_refractory(POS, refractory)


    nevents = length(POS);

    evtidx = 2;
    evtlist = 1;

    while(evtidx <= nevents)
        
        cpos = POS(evtidx);
        ppos = POS(evtidx - 1);

        if( (cpos - ppos) >= refractory)
            evtlist = cat(1, evtlist, evtidx);
        end

        evtidx = evtidx + 1;
    end

    excluded = setdiff(1:length(POS), evtlist);

end
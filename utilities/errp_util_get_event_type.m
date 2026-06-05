function index = errp_util_get_event_type(evt, evtlist)

    nevt  = length(evt);
    index = false(length(evtlist), 1);

    for eId = 1:nevt
        index = index | evtlist == evt(eId);
    end

end
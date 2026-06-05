function evtidx = errp_util_extract_begin_end(TYP, BeginEvt, EndEvt)


    BeginIdx = find(TYP == BeginEvt, 1, 'first');
    EndIdx   = find(TYP == EndEvt, 1, 'last');

    if isempty(BeginIdx) == true
        warning(['[warning] - Cannot find begin event ''' num2str(BeginEvt) '. Using the first event as begin (' num2str(TYP(1)) ')']);
        BeginIdx = 1;
    end

     if isempty(EndIdx) == true
        warning(['[warning] - Cannot find end event ''' num2str(EndEvt) '. Using the last event as end (' num2str(TYP(end)) ')']);
        EndIdx = length(TYP);
     end
    

    evtidx = BeginIdx:EndIdx;

end
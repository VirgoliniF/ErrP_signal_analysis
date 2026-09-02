function [Ek, Ck] = events_manual_filter(Ek, Ck, setting)

    if setting.manual_clean

        if setting.check_movement_cue == false
            if strcmp(setting.includepat, 'learn_errp_d7_1')
                idx = find(Ek == 1); 
                idxs = [7,9,11,12,13,19];
                Ek(idx(idxs)) = 0;
    
                idx = find(Ck == 1); 
                idxs = [13,18,19,21]; 
                Ck(idx(idxs)) = 0;
            end
        else % Movment
            if strcmp(setting.includepat, 'learn_errp_d7_1')
                idx = find(Ek == 1);
                idxs = [6,7,8,11,12];
                Ek(idx(idxs)) = 0;
    
                idx = find(Ck == 1); 
                idxs = [14,18,20,21,23,24,30,36,38];
                Ck(idx(idxs)) = 0;
            end
        end

    end

end
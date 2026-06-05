function [t, std_t] = errp_compute_distance_events(eTYP, ePOS, commands, MASK, mask_value)
    real_commands = commands-MASK;

    r = (eTYP == real_commands);

    r_final = zeros(size(r));
    
    for mask_index = 1:length(mask_value)
        c_mask = mask_value(mask_index);
        r_tmp = (eTYP == (real_commands + c_mask));
        r_final = r_final + (r_tmp)*mask_index;
    end

    r_final = sum(r_final, 2);
    r = sum(r, 2);

    times = nan(sum(r), length(mask_value));

    main_index = 1;

    prev_is_zero = true;

    for index = 1:length(r_final)

        if (r_final(index) == 0)
            if ( prev_is_zero == false )
                main_index = main_index + 1;
            end
            prev_is_zero = true;
        else
            prev_is_zero = false;

            times(main_index, r_final(index)) = ePOS(index);
        end
    end

    main_index = find(mask_value == MASK);

    diff_times = (times - times(:,main_index)) / 512;

    t = nanmean(diff_times);
    std_t = nanstd(diff_times);

end


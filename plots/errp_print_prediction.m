function errp_print_prediction(computed_prediction, T,Tu, decoder, overlap_window_samples, refchannelidx, compute_time_freuency_decomposition, chanlocs)
    list_of_errp = {};
    list_of_errp_unfiltered = {};
    indeces = {};
    len_li = 1;

    for index = 1:size(T,3)
        run_data = T(:,:,index);
        run_data_u = Tu(:,:,index);

    
        size_t = size(run_data, 1);
        size_window = decoder.time_leng;

        sub_index = 0;
      
        % Compute the prediction across the data, according to the overlap window
        for i = 1:overlap_window_samples:(size_t - size_window + 1)
            sub_index = sub_index + 1;

            inf_time = i - 250;
            sup_time = i + size_window + 250;

            if inf_time - 250 < 1
                continue;
            end

            if sup_time + 250 > size_t
                continue;
            end

            first = true;

            for i_newx = 1:5
                if (sub_index - i_newx > 1)
                    if computed_prediction(index, sub_index - i_newx ) == 1
                        first = false;
                    end
                end
            end

            if (computed_prediction(index, sub_index) == 1 && first == true)
                list_of_errp{len_li}            = run_data(inf_time:sup_time,:);
                list_of_errp_unfiltered{len_li} = run_data_u(inf_time:sup_time,:);
                indeces{len_li}                 = [index, inf_time, sup_time];

                len_li = len_li + 1;
            end
        end
    end

    figure
    t = linspace(0,length(list_of_errp{1}) -1, length(list_of_errp{1})) / 512;

    hold on
    for i = 1:(len_li - 1)
        plot(t,list_of_errp{i}(:,refchannelidx));
    end



    mat_errp = cat(3, list_of_errp{:}); %cell2mat(list_of_errp);
    mat_errp_u = cat(3, list_of_errp_unfiltered{:}); %cell2mat(list_of_errp_unfiltered);

    a = load('a.mat','a').a;

    dd = zeros(size(mat_errp,3),1);
    ix = zeros(size(mat_errp,3),1);
    iy = zeros(size(mat_errp,3),1);

    tmp_rundata = {};
    tmp_aligned = {};


    for i = 1:size(mat_errp,3)
        d = 250;
        tmp = zeros(d*2 + 1,1);
        
        tmp_rundata{i} = T(indeces{i}(2):indeces{i}(3) ,refchannelidx,  indeces{i}(1));

        for dt = -d:d
            if (indeces{i}(2) + dt < 1 || indeces{i}(3) + dt > size(T,1) )
                tmp(d+dt+1) = NaN;
                continue;
            end
            rundata = T(indeces{i}(2) + dt :indeces{i}(3) + dt ,refchannelidx,  indeces{i}(1));

            
            tmp(d+dt+1) = dtw(a(166:length(a)), rundata);
            tmp(d+dt+1) = dtw(a, rundata);

            % [~, pos_min_data]    = min(rundata);
            % [~, pos_min_default] = min(a);
            % 
            % [~, pos_max_data]    = max(rundata);
            % [~, pos_max_default] = max(a);
            % 
            % cost = abs(pos_min_data - pos_min_default ) +  abs(pos_max_data - pos_max_default );
            % 
            % tmp(d+dt+1) = cost;

        end
        [~,idx] = min(tmp);
        %figure
        %plot(t,mat_errp(:,refchannelidx,i))
        %hold on

        if ((indeces{i}(2) + idx -d) > 1 && (indeces{i}(3) + idx - d) < size(T,1))
            data   =  T(indeces{i}(2) + idx -d :indeces{i}(3) + idx -d , :, indeces{i}(1));
            data_u = Tu(indeces{i}(2) + idx -d :indeces{i}(3) + idx -d , :, indeces{i}(1));

            mat_errp(:,:,i)   = data;
            mat_errp_u(:,:,i) = data_u;         
            tmp_aligned{i} = T(indeces{i}(2) + idx -d :indeces{i}(3) + idx -d , refchannelidx, indeces{i}(1));
        end
        %plot(t,mat_errp(:,refchannelidx,i))
    end

    figure
    hold on
    for i = 1:size(mat_errp,3)
        plot(t,mat_errp(:,refchannelidx,i))
    end

    figure
    subplot(1,2,1)
    imagesc(t, 1:size(cell2mat(tmp_rundata),2), cell2mat(tmp_rundata)', [-15,15])
    subplot(1,2,2)
    imagesc(t, 1:size(cell2mat(tmp_aligned),2), cell2mat(tmp_aligned)', [-15,15])


        
    figure
    plot(t,mean(mat_errp(:,refchannelidx,:),3), 'LineWidth', 1.5)
    grid on
    hold on
    yline(0)

    m_eeg_err = mean(mat_errp(:,1:32,:),3);

    topowins = [0.0 0.1; 0.1 0.2; 0.2 0.3; 0.3 0.4; 0.4 0.5; 0.5 0.6 ] + 0.4; % ; 0.75 1.0; 1.25 1.5];
    figure

    htop = [];
    for tId = 1:size(topowins, 1)
        subplot(1, size(topowins, 1), tId);
        cstart = find(t >= topowins(tId, 1), 1, 'first');
        cstop  = find(t <= topowins(tId, 2), 1, 'last');
        h = topoplot(mean(m_eeg_err(cstart:cstop, :), 1), chanlocs);
        title([num2str(topowins(tId, 1)) '-' num2str(topowins(tId, 2))]);
        htop = cat(1, htop, h);
    end
    errp_set_clim(htop);

    if compute_time_freuency_decomposition == true
        mat_errp_u = squeeze(mat_errp_u(:,refchannelidx,:));
        t = (0:size(mat_errp_u,1)-1) / 512;
        params.epochTime = t;
        params.fsamp = 512;
        eegEpochs_pre.data = reshape(mat_errp_u, size(mat_errp_u,1), 1, size(mat_errp_u,2));
        eegEpochs_pre.label = ones(size(mat_errp_u,2),1);
        %eegEpochs_pre.label = eegEpochs_pre.label + Ek;
        %eegEpochs_pre.label = eegEpochs_pre.label + Ck * 3;
        compute_theta_peak_v3_1Dcursor(eegEpochs_pre, params, false, true, true, 1);
    end

    

end






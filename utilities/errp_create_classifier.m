function [decoder] = errp_create_classifier(eeg_err, eeg_cor, refchannelidx, margins, label, configure, with_plots)
    %with_plots =true;
    
    % - Plotting the data ---
    if with_plots == true
        figure
        plot(configure.t, mean(eeg_err(:,refchannelidx,:),3), 'r')
        hold on
        plot(configure.t, mean(eeg_cor(:,refchannelidx,:),3), 'b')
    
        plot_vline(0, 'k');
        plot_hline(0, 'k');
    
        plot_vline(configure.t(margins(1)), '--k');
        plot_vline(configure.t(margins(2)), '--k');
    end

    % - Restrict the data to the required interval
    eeg_err = eeg_err(margins(1):margins(2),:,:);
    eeg_cor = eeg_cor(margins(1):margins(2),:,:);


    % - Shuffle and divide the data ---
    test_p = 0.2;

    th = zeros(10,1);
    th_min = zeros(10,1);

    decoders = cell(1,10);
    cost = zeros(1,10);

    downsample_n = 8;

    %figure;
    %hold on;
    % This should be done with runs, but I do not care
    for index_p = 1:10
        [err_train, err_test] = shuffle_divide_data(eeg_err, test_p);
        [cor_train, cor_test] = shuffle_divide_data(eeg_cor, test_p);
    
        [train, train_labels] = concatentate_data(cor_train, err_train, refchannelidx);
        [test,   test_labels] = concatentate_data(cor_test,  err_test,  refchannelidx);
    
        % - Donwsample the data
        train = downsample(train, downsample_n);
        test  = downsample(test, downsample_n);
        
        % - Create the classifiers ---
        %classificationLearner(train', train_labels);
        params = setParameters(512, 'Wheelchair', margins);
        %params.epochRejection.isCookmpute = false;
    
        
        [decoder, classifierEpochs] = computeDecoder(train, train_labels, train, params);
    
        decoder.channelRemoval.isCompute  = false;
        decoder.baselineCorrect.isCompute = false;
    
        % - Test the classifier ---
    
        prediction = zeros(size(test, 3),1);
    
        for index = 1:size(test,3)
            % disp(size(test(:,:,index)));
            posterior = singleClassification(decoder, test(:,:,index), test(:,:,index));
            % posterior = probablity of presence of the errp
            prediction(index) = posterior;
        end
    
        % per questo bisogna reitierare lasciando sempre fuori una run e
        % prendere il migliore con questa perfcure
        % Then you need to rebuild the classificator on all the data for the
        % online decoder
    
        [FPR,TPR,thres,~,~] = perfcurve(test_labels,prediction,1); %1 is the positive class
        [~, I] = max(TPR(:,1) .* (1 - FPR(:,1)));
        th(index_p) = thres(I);

        [FPR,TPR,thres,~,~] = perfcurve(test_labels,(1 - prediction),0); %1 is the positive class
        [~, I] = max(TPR(:,1) .* (1 - FPR(:,1)));
        th_min(index_p) = thres(I);

        p_ = prediction' > th(index_p);
        v = sum(int16(test_labels) == p_);
        %plot(prediction)
        %disp(["pos " + string(v) + "/" + string(sum(int16(test_labels))) + " = " + string(v/sum(int16(test_labels))) ]);

        p_neg = (1 - prediction)' > th_min(index_p);
        test_labels_neg = abs(test_labels - 1);
        v_neg = sum(int16(test_labels_neg) == p_neg);
        %disp(["neg " + string(v_neg) + "/" + string(sum(int16(test_labels_neg))) + " = " + string(v_neg/sum(int16(test_labels_neg)))]);

        cost_f = abs(v + v_neg - 2 * length(test_labels_neg));
        cost_f = cost_f + sum(abs(p_ - test_labels)) + sum(abs(p_neg - test_labels_neg));
        cost(index_p) = cost_f;
        disp(['Cost :' + string(cost_f)]);
 
        decoders{index_p} = decoder;
        
    end


    %prediction_labels = double(prediction >= decoder.threshold);

    % - Get the performances ---

    %accuracy =  mean(prediction_labels == test_labels);
    %disp(accuracy);

    %figure();
    %c = confusionmat(prediction_labels, test_labels);
    %confusionchart(c);

    %% recompte with all the data
    % [err_train, ~] = shuffle_divide_data(eeg_err, 0);
    % [cor_train, ~] = shuffle_divide_data(eeg_cor, 0);
    % 
    % [train, train_labels] = concatentate_data(err_train, cor_train, refchannelidx);
    % 
    % params = setParameters(512, 'Wheelchair', margins);
    % 
    % [decoder, ~] = computeDecoder(train, train_labels, train, params);
    % 
    % decoder.channelRemoval.isCompute  = false;
    % decoder.baselineCorrect.isCompute = false;

    [ ~ , index ] = min(cost);

    decoder = decoders{index};

    decoder.threshold = th(index);
    decoder.threshold_min = th_min(index);

    decoder.refchannelidx = refchannelidx;

    decoder.time_leng = margins(2)-margins(1);

    decoder.downsample = downsample_n;


    % - Save the classifier ---  
    save_classifier(decoder, configure);

end

function [train, test] = shuffle_divide_data(data, p)
    length_t = size(data, 3);

    index_0 = zeros(floor(length_t * p),1);
    index_1 = ones(length_t - floor(length_t * p),1);

    idx = [index_0; index_1];

    idx = logical(idx(randperm(length_t)));

    train = data(:,:,idx);
    test = data(:,:,not(idx));   

end

function [data, labels] = concatentate_data(task1, task2, refchannelidx)

    index_0 = zeros(size(task1,3),1);
    index_1 =  ones(size(task2,3),1);

    labels = [index_0; index_1];
    labels = reshape(labels, 1, []);
    
    task1 = task1(:,refchannelidx, :);
    task2 = task2(:,refchannelidx, :);

    %col1 = reshape(task1, [size(task1,1)* size(task1,2), size(task1,3)]);
    %col2 = reshape(task2, [size(task2,1)* size(task2,2), size(task2,3)]);

    %data = cat(2, col1, col2); 

    data = cat(3, task1, task2); 

end
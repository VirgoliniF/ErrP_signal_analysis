function [new_tipe] = recomputeTYP(v, mode)
%RECOMPUTETYP Summary of this function goes here
%   Detailed explanation goes here

err_detect_code = 5000;

if mode == "active"
    % Fixation -> new init
    idx_ones = find(v == 90);
    v(idx_ones) = 1;
    % Down -> Rigth    
    idx_ones = find(v == 104);
    v(idx_ones) = 103;
    % Up -> Left
    idx_ones = find(v == 102);
    v(idx_ones) = 103;
    % ErrDetect -> 400
    err_detect_code = 400;
end

idx_ones = find(v == 1);
idx_5000 = find(v == err_detect_code);


% Process each occurrence of 5000
for i = length(idx_5000):-1:1
    % Find the previous 1 before the current 5000
    prev_one_idx = find(idx_ones < idx_5000(i), 1, 'last');
    
    if ~isempty(prev_one_idx)
        % Update values between 1 and 5000
        v(idx_ones(prev_one_idx)+1 : idx_5000(i)-1) = v(idx_ones(prev_one_idx)+1 : idx_5000(i)-1) + 5000;
    end
end

new_tipe = v;

end


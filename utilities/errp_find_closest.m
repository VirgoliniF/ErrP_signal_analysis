function [index, error] = errp_find_closest(A, B)

    if(iscolumn(A) == false)
        A = A';
    end

    if(iscolumn(B) == false)
        B = B';
    end

    R = repmat(B, [1 length(A)]);

    [error, index] = min(abs(R-A'));

end
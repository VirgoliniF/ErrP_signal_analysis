function R_new = geodesicInterpolation(R_old, C_new, t)
    % Perform geodesic interpolation between R_old (previous reference matrix)
    % and C_new (covariance matrix of the new trial) with a weighting factor t.
    
    R_new = R_old^(1/2) * (R_old^(-1/2) * C_new * R_old^(-1/2))^t * R_old^(1/2);
end
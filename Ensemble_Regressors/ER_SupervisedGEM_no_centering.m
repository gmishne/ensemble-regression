function [y_pred,w,R,rho] = ER_SupervisedGEM_no_centering(Ztrain, ytrain, Ztest)
    n_train = numel(ytrain);
    R = Ztrain*Ztrain' / n_train;
    if rcond(R) < 1e-5 % diagonal loading
        R = R + eye(size(R)) * 1e-5;
    end;
    
    rho = sum(bsxfun(@times, Ztrain,ytrain),2) / n_train;
    w = inv(R) * rho;
    y_pred = w' * Ztest;
end
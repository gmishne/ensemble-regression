clear all; close all; close all hidden;
addpath Ensemble_Regressors;
addpath HelperFunctions;

ROOT = './Datasets/RealWorld/CCLE/mydata/EC50/';
files = dir([ROOT '*.mat']);

m=7;
Wstar = zeros(m,length(files));
Wrstar = zeros(m,length(files));
Wnnstar = zeros(m,length(files));
Wnnsum1star = zeros(m,length(files));
MSE_orig = zeros(m,length(files));

results_summary = {};
for file_idx=1:length(files)
    load([ROOT files(file_idx).name]);
    fprintf('DRUG FILE: %s\n', files(file_idx).name);
%%
    y_true = y;
    clear y;
    y_true = y_true - mean(y_true);
    Z = bsxfun(@minus, Z, mean(Z,2));
    [m n] = size(Z);
    Ey = mean(y_true);
    Ey2 = mean(y_true.^2);
    var_y = Ey2 - Ey.^2;
    mse = @(x) mean((y_true' - x).^2 / var_y);    

    for i=1:m
        MSE_orig(i,file_idx) = mse(Z(i,:)');
    end;
    
    %% Estimators
    [y_oracle2, w_oracle2] = ER_Oracle_2_Unbiased(y_true, Z); Wstar(:,file_idx) = w_oracle2;
    [y_oracle_rho, w_oracle_rho] = ER_Oracle_Rho(y_true,Z); Wrstar(:,file_idx) = w_oracle_rho;
    [y_oracle_nonneg, w_oracle_nonneg] = ER_Oracle_2_NonNegWeights(y_true,Z); Wnnstar(:,file_idx) = w_oracle_nonneg;
    [y_oracle_nonnegsum1, w_oracle_nonnegsum1] = ER_Oracle_2_NonNegSum1Weights(y_true,Z); Wnnsum1star(:,file_idx) = w_oracle_nonnegsum1;
    [y_mean,w_mean] = ER_MeanWithBiasCorrection(Z, Ey);
    y_median = ER_MedianWithBiasCorrection(Z, Ey);
    [y_dgem,w_dgem] = ER_UnsupervisedDiagonalGEM(Z, Ey);
    [y_gem,w_gem] = ER_UnsupervisedGEM(Z, Ey,Ey2);
    [y_gem_with_rho_estimation,w_gem_with_rho_estimation] = ER_UnsupervisedGEM_with_rho_estimation(Z, Ey);
    [y_spectral,w_spectral] = ER_SpectralApproach(Z, Ey, Ey2);
    [y_indepmisfit,w_indepmisfit] = ER_IndependentMisfits(Z,Ey, Ey2);
    %[y_lrm,~,y_oracle_rho] = ER_LowRankMisfitCVX(Z, Ey, Ey2, y_true);
    [y_rank1,w_rank1,Cstar_rank1_offdiag] = ER_Rank1Misfit(Z,Ey, Ey2);
    %[y_rank2,w_rank2,Cstar_rank2_offdiag] = ER_Rank2Misfit(Z,Ey, Ey2);

    %% Print results
    results = {files(file_idx).name, 'best',min(mean((Z - repmat(y_true,m,1)).^2,2))}; % best individual regressor
    for alg=who('y_*')'
        if ~strcmp(alg{1}, 'y_true')
            results = [results; {files(file_idx).name, alg{1}, mse(eval(alg{1}))}];
        end;
    end;
    results_summary = [results_summary; results];

    %% Plot principal components
%     figure('Name',files(i).name);
%     W = [w_oracle2 w_oracle_rho w_mean(2:end), w_dgem, w_gem(2:end), w_gem_with_rho_estimation, w_spectral];
%     [pc,score,latent,tsquare] = princomp(W);
%     biplot(pc(:,1:2),'Scores',score(:,1:2),'VarLabels',{'oracle2','oracle rho','mean', 'dgem', 'gem', 'gem with rho estimation', 'spectral'}, 'MarkerSize',10);

    %% Plot misfit covariance matrix
%     Cstar = cov((Z - repmat(y_true,m,1))'); labels = {'1','2','3','4','5','6','7'};
%     Cstar = Cstar - Cstar_rank1_offdiag;
%     Cstar_norm = zeros(m); for i=1:m; for j=1:m; Cstar_norm(i,j) = Cstar(i,j) ./ sqrt(Cstar(i,i) * Cstar(j,j)); end; end;
%     a=HeatMap(Cstar_norm,'Colormap','redbluecmap','LabelsWithMarkers','true','DisplayRange',1, ...
%               'Symmetric','true','RowLabels',labels,'ColumnLabels',labels);
%     set(a,'Annotate','true'); addTitle(a,['Misfit Covariance C*_ij/sqrt(C*_ii C*_jj) - ' files(file_idx).name],'interpreter','none');
%     %addTitle(a,['Misfit Covariance After Rank2 reduction - ' files(file_idx).name],'interpreter','none');
end;
writetable(table(results_summary), 'results/drug_response.csv')

%% Best ensemble regression algorithm
% with oracle regressors (which requires oracle knowledge)
t =pivottable(results_summary,2,1,3,@sum);
best = min(cell2mat(t(2:end,2:end)));
a =cell2mat(t(2:end,2:end));
fprintf('\nWith oracle\n');
for i=1:24; fprintf('%s\n',t{find(a(:,i) == best(i))+1,1}); end;

% without oracle regressors (which requires oracle knowledge)
fprintf('\n\nWithout oracles\n');
t =pivottable(results_summary,2,1,3,@sum);
t(find(strcmp(t(:,1),'best')),:) = []; t(find(strcmp(t(:,1),'y_oracle2')),:) = []; 
t(find(strcmp(t(:,1),'y_oracle_rho')),:) = []; t(find(strcmp(t(:,1),'y_oracle_nonneg')),:) = [];
best = min(cell2mat(t(2:end,2:end)));
a =cell2mat(t(2:end,2:end));
for i=1:24; fprintf('%s\n',t{find(a(:,i) == best(i))+1,1}); end;
fprintf('\n');

p=pivottable(results_summary,2,1,3,@sum)
a=cell2mat(p(2:end,2:end))
p(:,1)


%%
idx_orc = 11;

figure(1); clf;  msize = 8; 
set(gca,'fontsize',20); 
hold on; grid on; 
plot(a(idx_orc,:),a(6,:),'k>'); %mean
plot(a(idx_orc,:),a(7,:),'b.','markersize',msize);   %median
plot(a(idx_orc,:),a(2,:),'rs','markersize',msize);   %D-GEM
plot(a(idx_orc,:),a(end-1,:),'md','markersize',msize);   %GEM-HAT-RHO
%plot(a(11,:),a(5,:),'gp','markersize',msize);  %INDEPENDENT ERRORS

legend('MEAN','MED','DGEM','PCR','Location','NorthWest'); 
plot(a(idx_orc,:),a(idx_orc,:),'b-'); 
plot(a(idx_orc,:),a(idx_orc-3,:),'bo','markersize',msize+2); 

axis([0 0.7 0 1]); 

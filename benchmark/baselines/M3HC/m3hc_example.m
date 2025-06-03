
clear; % clc;

format shortG;

tol             = 10e-3;
maxCondSetM3HC   = 10;
nnSamples       = [10000];
nnLatent        = [0.1];
maxParents      = [3];
nnVarsL         = [10];
startingIter    = 1;
nIters          = 5;
skeleton        = 'MMPC';

% Initialize Parallel Environment
% myCluster = parcluster('local'); myCluster.NumWorkers = 8; saveProfile(myCluster); parcluster('local')
% parpool('local', 8)

% COR = true for correlation matrix / false for covariance matrix
% TABU = true for M3HC with TABU list / false for M3HC without TABU list

COR      = false;
TABU     = true;
TABUsize = 100;

%% Main Process

for inSamples = 1:length(nnSamples)
    nSamples=nnSamples(inSamples);
    fprintf('--------------------------------nSamples: %d------------------------------------------------------------------\n', nSamples);
    ticSamples = tic;
    
    if nSamples == 100 || nSamples == 1000
        threshold = 5e-2;
    elseif nSamples == 10000
        threshold = 5e-4;
    elseif nSamples == 100000
        threshold = 5e-6;
    end
    
    for inLatent = 1:length(nnLatent)
        fprintf('--------------------------------nLatent: %.4f----------------------------------------\n', nnLatent(inLatent));
        pLatent = 100*nnLatent(inLatent);
        ticLatent = tic;
        
        % Control random number generator within parallel environment
%         spmd
%             rng(0,'combRecursive');
%         end
        
        % Control random number generator
        rng(0,'combRecursive');
        
        for inMaxParents = 1:length(maxParents)
            nMaxParents = maxParents(inMaxParents);
            fprintf('--------------------------------nMaxParents: %d-----------------------------------\n', nMaxParents);
            ticMaxParents = tic;
            
            for inVarsL = 1:length(nnVarsL)
                nVarsL = nnVarsL(inVarsL);
                fprintf('--------------------------------nVars: %d--------------------\n', nVarsL);
                nLatent = ceil(nnLatent(inLatent)*nVarsL);
                ticVarsL = tic;
                
%                 parfor iter = startingIter:nIters
                for iter = startingIter:nIters
                    fprintf('Iter %d:\n', iter);
                    
                    % Control rng behavior
                    stream = RandStream.getGlobalStream();
                    % Unique Substream for each combination of iter-nVarsL-nMaxParents
                    stream.Substream = (iter + 60*nVarsL + 2100*nMaxParents);
                    
                    % Generate new data
                    dag = randomdag(nVarsL, nMaxParents);
                    
                    % Choose latent variables.
                    isLatent = false(1, nVarsL);
                    isLatent(randsample(1:nVarsL, nLatent)) = true;
                    Lat = find(isLatent)';
                    
                    % Simulate data
                    bn = dag2randBN(dag, 'gaussian');
                    ds = simulatedata(bn, nSamples, 'gaussian', 'isLatent', isLatent);
                    
                    % Create the true MAG/PAG
                    magT = convertDagToMag(dag, Lat, []);
                    pagT = mag2pag(magT);
                    nVars = sum(~isLatent);
                    
                    
                    % Compute the covariance/correlation matrix
                    if COR == logical(true)
                        covMat = corr(ds.data(:, ~isLatent));
                    else
                        covMat = cov(ds.data(:,~isLatent));
                    end
                    
                    
                    
                    %% Run M3HC
                    
                    [m3hcMag, mmmhc_bs, mmmhcIters, mmmhc, mmpc_final, mmmhcTime(iter,:)] = MMMHC_sim(ds, maxCondSetM3HC, threshold, nLatent, tol, COR, TABU,...
                        TABUsize, skeleton);
                    m3hcMag = ag2mag(m3hcMag);
                    
                    
                    m3hcPag = mag2pag(m3hcMag);
                    shdsMMMHC(iter)=structuralHammingDistancePAG(m3hcPag, pagT);
                    [precisionMMMHC(iter), recallMMMHC(iter)] = precisionRecall(m3hcPag, pagT);
                    
                    
                    % COMMENTS
                    % 1) M3HC will most likely not run without the TABU list heuristic since the non-TABU script isn't
                    % updated. Feel free to update it and run it without a TABU list.
                    % 2) The scoring part of M3HC (mmmhcSearchMagTABU) takes as input a set of edges from MMPC (skeleton_final)
                    % and other than that runs 100% independently of MMPC. So feel free to use any other local discovery
                    % algorithm besides MMPC.
                    
                    
                    
                end
            end
        end
    end
end


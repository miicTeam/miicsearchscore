% ==============================================================================
% File        : M3HC_eval.m
% Description : Benchmark script to evaluate the M3HC algorithm
%               on simulated linear and non-linear datasets with varying
%               sample sizes, graph densities, and latent variable settings.
%
% Author      : Nikita Lagrange (CNRS, Institut Curie, Sorbonne University)
% Created on  : 2025-05-27
% Version     : 1.0.0
%
% Dependencies:
%   - MMMHC_sim.m
%   - ag2mag.m
%   - mag2pag.m
%
% License     : GPL (>= 3)
% ==============================================================================

% Parameters for the experiment
numNodes = ["N50", "N150"];  % Number of variables/nodes per graph
sampleSizes = ["100", "250", "500", "1000", "5000", "10000", "20000"];  % Sample sizes
latentTags = ["0L", "10L", "20L"];  % Amount of latent confounding
graphDegrees = ["3", "5"];          % Average degree
numReplicates = 30;

% Paths to the datasets and result folders
basePath = "C:/Users/lagra/Documents/miicsearchscore/benchmark";
linearDataPath    = fullfile(basePath, "simulated_data", "continuous", "linear_gaussian");
nonLinearDataPath = fullfile(basePath, "simulated_data", "continuous", "non_linear");
resultPath        = fullfile(basePath, "results");

% MMMHC algorithm parameters
maxCondSetSize = 10;
alphaThreshold = 5e-2;
numLatent = 0;
tolerance = 1e-3;
useCorrelation = false;
useTabu = true;
tabuSize = 1;
skeletonMethod = 'MMPC';

for nodeIdx = 1:length(numNodes)
    for degreeIdx = 1:length(graphDegrees)
        for sizeIdx = 1:length(sampleSizes)
            for replicate = 1:numReplicates
                for tagIdx = 1:length(latentTags)

                    % === LINEAR DATA ===
                    inputFile = fullfile(linearDataPath, numNodes(nodeIdx), ...
                                         graphDegrees(degreeIdx), sampleSizes(sizeIdx), ...
                                         "input_" + latentTags(tagIdx) + "_" + int2str(replicate) + ".csv");
                    dataTable = readtable(inputFile);
                    dataMatrix = table2array(dataTable);

                    isLatent = zeros(1, size(dataMatrix, 2));
                    dataset.data = dataMatrix;
                    dataset.isLatent = isLatent;

                    % Run MMMHC
                    [m3hcMAG, ~, ~, ~, ~, ~] = MMMHC_sim(dataset, maxCondSetSize, ...
                        alphaThreshold, numLatent, tolerance, useCorrelation, ...
                        useTabu, tabuSize, skeletonMethod);

                    % Convert MAG to PAG
                    m3hcMAG = ag2mag(m3hcMAG);
                    m3hcPAG = mag2pag(m3hcMAG);

                    % Write output
                    outputDir = fullfile(resultPath, "continuous","linear_gaussian", "M3HC", ...
                                         numNodes(nodeIdx), graphDegrees(degreeIdx), sampleSizes(sizeIdx));
                    if ~exist(outputDir, 'dir')
                        mkdir(outputDir);
                    end
                    outputFile = fullfile(outputDir, ...
                                          "adj_m3hc_" + latentTags(tagIdx) + "_" + int2str(replicate) + ".csv");
                    
                    writematrix(m3hcPAG, outputFile);

                    % === NON-LINEAR DATA ===
                    inputFile = fullfile(nonLinearDataPath, numNodes(nodeIdx), ...
                                         graphDegrees(degreeIdx), sampleSizes(sizeIdx), ...
                                         "input_" + latentTags(tagIdx) + "_" + int2str(replicate) + ".csv");
                    dataTable = readtable(inputFile);
                    dataMatrix = table2array(dataTable);

                    isLatent = zeros(1, size(dataMatrix, 2));
                    dataset.data = dataMatrix;
                    dataset.isLatent = isLatent;

                    [m3hcMAG, ~, ~, ~, ~, ~] = MMMHC_sim(dataset, maxCondSetSize, ...
                        alphaThreshold, numLatent, tolerance, useCorrelation, ...
                        useTabu, tabuSize, skeletonMethod);

                    m3hcMAG = ag2mag(m3hcMAG);
                    m3hcPAG = mag2pag(m3hcMAG);

                    outputDir = fullfile(resultPath, "continuous","non_linear", "M3HC", ...
                                         numNodes(nodeIdx), graphDegrees(degreeIdx), sampleSizes(sizeIdx));
                    if ~exist(outputDir, 'dir')
                        mkdir(outputDir);
                    end
                    outputFile = fullfile(outputDir, ...
                                          "adj_m3hc_" + latentTags(tagIdx) + "_" + int2str(replicate) + ".csv");
                    
                    writematrix(m3hcPAG, outputFile);
                end
            end
        end
    end
end

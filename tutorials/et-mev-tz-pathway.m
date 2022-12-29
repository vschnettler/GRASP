clc, clear, close all
rng('default');                 % for reproducibility
addpath(fullfile('..', 'matlab_code', 'analysisFxns'), ...
        fullfile('..', 'matlab_code', 'ensembleFxns'), ...
        fullfile('..', 'matlab_code', 'patternFxns'));

maxNumberOfSamples = 1e5;
eigThreshold = 1e-5;

modelID = 'et_mev_tz_pathway';
inputFile  = fullfile('..', 'io', 'input', modelID);
outputFile = fullfile('..', 'io', 'output', [modelID, '.mat']);

ensemble = buildEnsemble(inputFile, outputFile, maxNumberOfSamples, eigThreshold);

mcaResults = controlAnalysis(ensemble,1);

categories = {};         % Displays MCA results for all the reactions
plotControlAnalysis(mcaResults, ensemble, categories);

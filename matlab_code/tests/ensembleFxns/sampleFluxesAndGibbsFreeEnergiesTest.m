classdef sampleFluxesAndGibbsFreeEnergiesTest < matlab.unittest.TestCase

    properties
        currentPath
    end
    
    methods(TestClassSetup)
        function defineCurrentPath(testCase)
            testCase.currentPath = regexp(mfilename('fullpath'), '(.*)[/\\\\]', 'match');
        end
    end
    
 
    methods (Test)
        function testSampleFluxesAndGibbsFreeEnergiesNormal(testCase)
            
            seed = 1;
            rng(seed)

            ensemble = load(fullfile(testCase.currentPath{1}, 'testFiles', 'initializedEnsemble_toy_model1_sampleFluxGibbs.mat'));
            ensemble = ensemble.ensemble;
            maxNumberOfSamples = 100;
            priorType = 'normal';
            
            ensemble = sampleFluxesAndGibbsFreeEnergies(ensemble,maxNumberOfSamples,priorType);

            trueRes = load(fullfile(testCase.currentPath{1}, 'testFiles', 'trueResSampleFluxesAndGibbsFreeEnergiesNormal.mat'));
            trueResEnsemble = trueRes.ensemble;
           
            testCase.verifyThat(trueResEnsemble, matlab.unittest.constraints.IsEqualTo(ensemble, ...
                 'Within', matlab.unittest.constraints.RelativeTolerance(1e-12)));
        end
        
        function testSampleFluxesAndGibbsFreeEnergiesUniform(testCase)
            
            seed = 1;
            rng(seed)

            ensemble = load(fullfile(testCase.currentPath{1}, 'testFiles', 'initializedEnsemble_toy_model1_sampleFluxGibbs'));
            ensemble = ensemble.ensemble;
            maxNumberOfSamples = 100;
            priorType = 'uniform';
            
            ensemble = sampleFluxesAndGibbsFreeEnergies(ensemble,maxNumberOfSamples,priorType);

            trueRes = load(fullfile(testCase.currentPath{1}, 'testFiles', 'trueResSampleFluxesAndGibbsFreeEnergiesUniform.mat'));
            trueResEnsemble = trueRes.ensemble;
           
            testCase.verifyThat(trueResEnsemble, matlab.unittest.constraints.IsEqualTo(ensemble, ...
                 'Within', matlab.unittest.constraints.RelativeTolerance(1e-12)));
        end
    end
end



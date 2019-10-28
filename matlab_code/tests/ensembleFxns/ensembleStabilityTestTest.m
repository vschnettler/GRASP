classdef ensembleStabilityTestTest < matlab.unittest.TestCase
   
    properties
        currentPath
    end
    
    methods(TestClassSetup)
        function defineCurrentPath(testCase)
            testCase.currentPath = regexp(mfilename('fullpath'), '(.*)/', 'match');
        end
    end
 
    methods(TestMethodTeardown)
        function removeReactionsFolder(testCase)           

            reactionsFolder = fullfile(testCase.currentPath{1}, '..', '..', '..', 'reactions', 'toy_model1_random2_1');
            
            if exist(reactionsFolder, 'dir')
                rmdir(reactionsFolder, 's');
            end
        end
    end
    
    
    methods (Test)
        function testEnsembleStabilityTest1(testCase)
                        
            % To make sure reaction files are created properly
            xlsxFile = fullfile(testCase.currentPath{1}, 'testFiles', 'toy_model1_random2');
            loadEnsembleStructure(xlsxFile);
            
            ensemble = load(fullfile(testCase.currentPath{1}, 'testFiles', 'final_ensemble_toy_model1_random2.mat'));
            ensemble = ensemble.ensemble;
            
            eigThreshold = -0.5;
            stabilityRes = ensembleStabilityTest(ensemble,eigThreshold);

            trueRes = load(fullfile(testCase.currentPath{1}, 'testFiles', 'trueResEnsembleStabilityTest1'));
            trueRes = trueRes.stabilityRes;
                   
            testCase.verifyEqual(trueRes, stabilityRes)
        end
    end
end

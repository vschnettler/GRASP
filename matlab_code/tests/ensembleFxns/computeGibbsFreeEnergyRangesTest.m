classdef computeGibbsFreeEnergyRangesTest < matlab.unittest.TestCase

    properties
        currentPath
    end
    
    methods(TestClassSetup)
        function defineCurrentPath(testCase)
            testCase.currentPath = regexp(mfilename('fullpath'), '(.*)[/\\\\]', 'match');
        end
    end
    
 
    methods (Test)
        function testComputeGibbsFreeEnergyRangesGurobi(testCase)
            
            seed = 1;
            rng(seed)
            
            ensemble = load(fullfile(testCase.currentPath{1}, 'testFiles', 'ensemble_toy_model1.mat'));
            ensemble = ensemble.ensemble;
            
            xlsxFile = fullfile(testCase.currentPath{1}, 'testFiles', 'toy_model1.xlsx');
            xDG_std             = xlsread(xlsxFile,'thermoRxns');                   % load thermodynamic data (rxns)
            xMetsThermo         = xlsread(xlsxFile,'thermoMets');                   % load thermodynamic data (mets)
            ineqConstraints     = xlsread(xlsxFile,'thermo_ineq_constraints');      % load ineq. thermodynamic constraints

            DGr_std        = xDG_std(ensemble.idxNotExch,:);                                                        % Use only reactions with known thermodynamics
            vmin           = ensemble.fluxRef - 2*ensemble.fluxRefStd;
            vmax           = ensemble.fluxRef + 2*ensemble.fluxRefStd;
            xmin           = xMetsThermo(:,1);
            xmax           = xMetsThermo(:,2);
            DGr_std_min    = DGr_std(:,1);
            DGr_std_max    = DGr_std(:,2);
            
            ensemble.LPSolver = 'gurobi';
            
            [v_range,DGr_range,DGf_std_range,lnx_range,x0] = computeGibbsFreeEnergyRanges(ensemble,DGr_std_min,DGr_std_max,vmin,vmax,xmin,xmax,ineqConstraints);

            trueRes = load(fullfile(testCase.currentPath{1}, 'testFiles', 'trueResComputeGibbsFreeEnergyRanges1'));
            trueResFluxes = trueRes.v_range;
            trueResDGr = trueRes.DGr_range;
            trueResDGf = trueRes.DGf_std_range;
            trueResLnMets = trueRes.lnx_range;
            trueResX0 = trueRes.x0;
            
            testCase.verifyThat(trueResFluxes, matlab.unittest.constraints.IsEqualTo(v_range, ...
                'Within', matlab.unittest.constraints.RelativeTolerance(1e-4)))
            testCase.verifyThat(trueResDGr, matlab.unittest.constraints.IsEqualTo(DGr_range, ...
                'Within', matlab.unittest.constraints.RelativeTolerance(1e-4)))
            testCase.verifyThat(trueResDGf, matlab.unittest.constraints.IsEqualTo(DGf_std_range, ...
                'Within', matlab.unittest.constraints.RelativeTolerance(1e-4)))
            testCase.verifyThat(trueResLnMets, matlab.unittest.constraints.IsEqualTo(lnx_range, ...
                'Within', matlab.unittest.constraints.RelativeTolerance(1e-10)))
            testCase.verifyThat(trueResX0, matlab.unittest.constraints.IsEqualTo(x0, ...
                'Within', matlab.unittest.constraints.RelativeTolerance(1e-4)))
        end
        
        function testComputeGibbsFreeEnergyRangesLinprog(testCase)
            
            seed = 1;
            rng(seed)
            
            ensemble =  load(fullfile(testCase.currentPath{1}, 'testFiles', 'ensemble_toy_model1.mat'));
            ensemble = ensemble.ensemble;
            
            xlsxFile = fullfile(testCase.currentPath{1}, 'testFiles', 'toy_model1');
            xlsxFile            = [xlsxFile,'.xlsx'];                               % add extension to the file
            xDG_std             = xlsread(xlsxFile,'thermoRxns');                   % load thermodynamic data (rxns)
            xMetsThermo         = xlsread(xlsxFile,'thermoMets');                   % load thermodynamic data (mets)
            ineqConstraints     = xlsread(xlsxFile,'thermo_ineq_constraints');      % load ineq. thermodynamic constraints

            Sflux       = ensemble.S(ensemble.metsBalanced,:);
            idxNotExch  = find(~ismember(1:numel(ensemble.rxns),ensemble.exchRxns));
            ensemble.Sthermo     = ensemble.S(:,idxNotExch);
            DGr_std     = xDG_std(idxNotExch,:);                                                        % Use only reactions with known thermodynamics
            vmin        = ensemble.fluxRef - 2*ensemble.fluxRefStd;
            vmax        = ensemble.fluxRef + 2*ensemble.fluxRefStd;
            xmin        = xMetsThermo(:,1);
            xmax        = xMetsThermo(:,2);
            DGr_std_min = DGr_std(:,1);
            DGr_std_max = DGr_std(:,2);
            
            ensemble.LPSolver = 'linprog';
            
            [DGr_rng,xrng,vrng] = computeGibbsFreeEnergyRanges(Sflux,ensemble.Sthermo,DGr_std_min,DGr_std_max,vmin,vmax,xmin,xmax,idxNotExch,ineqConstraints', ensemble.rxnNames, ensemble.LPSolver);
           
            trueRes = load(fullfile(testCase.currentPath{1}, 'testFiles', 'trueResComputeGibbsFreeEnergyRanges1'));
            trueResDGr = trueRes.DGr_rng;
            trueResMets = trueRes.xrng;
            trueResFluxes = trueRes.vrng;
                   
            testCase.verifyThat(trueResDGr, matlab.unittest.constraints.IsEqualTo(DGr_rng, ...
                'Within', matlab.unittest.constraints.RelativeTolerance(1e-4)))
            testCase.verifyThat(trueResMets, matlab.unittest.constraints.IsEqualTo(xrng, ...
                'Within', matlab.unittest.constraints.RelativeTolerance(1e-10)))
            testCase.verifyThat(trueResFluxes, matlab.unittest.constraints.IsEqualTo(vrng, ...
                'Within', matlab.unittest.constraints.RelativeTolerance(1e-4)))
        end
       
    end
end


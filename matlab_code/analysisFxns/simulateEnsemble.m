function simulationRes = simulateEnsemble(ensemble, finalTime, enzymesIC, metsIC, metsAbsOrRel, interruptTime, numModels)
% Takes in a model ensemble and initial conditions for enzyme and 
% metabolite concentrations and simulates all models in the ensemble.
%
% For metabolites, the initial conditions can be given either in terms of
% relative or absolute concentrations (mol/L) by setting *metsAbsOrRel* to
% 'rel' or 'abs', respectively.
%
% If metabolite concentrations are given as absolute concentrations, the
% flux values returned will also be absolute values, otherwise they'll be
% relative values (to the reference flux).
%
% If the simulation of a given model takes longer than the specified 
% *interrupTime*, then it is interrupted and no simulation results are  
% saved for that model.
%
% Note that for each model a different set of time points and respective
% concentrations/fluxes will be returned, since the solver's step size is
% adaptive, i.e., not constant.
%
%
% USAGE:
%
%    simulationRes = simulateEnsemble(ensemble, finalTime, enzymesIC, metsIC, interruptTime)
%
% INPUT:
%    ensemble (struct):           model ensemble, see buildEnsemble for fields description
%    finalTime (double):          simulation time
%    enzymesIC (double vector):	  initial conditions for enzyme concentrations
%    metsIC (double vector):      initial conditions for metabolite concentrations
%    metsAbsOrRel (char):         specify whether metabolite initial conditions are relative or absolute concentrations. Accepted values for this variable are 'abs' and 'rel'
%    interruptTime (double)       maximum time for each simulation, given in seconds
%    numModels (int):             how many models should be simulated. This number should be lower than the number of models in the ensemble.
%
% OUTPUT:
%    simulationRes (struct):  simulation results
%
%               * t (*cell*)      : time points in each model simulation
%               * conc (*cell*)   : concentrations for each time point and model simulation
%               * flux (*cell*)   : fluxes for each time point and model simulation
%
% .. Authors:
%       - Marta Matos       2019 original code

if ~strcmp(metsAbsOrRel, 'rel') && ~strcmp(metsAbsOrRel, 'abs')
    error('The value of the variable metsAbsOrRel must be either "rel" or "abs".');
end


strucIdx = 1;
if ensemble.populations(end).strucIdx(1)==0
    ensemble.populations(end).strucIdx = ones(numel(ensemble.populations(end).strucIdx),1);
end

% Add kinetic fxns to the path
addKineticFxnsToPath(ensemble);

% Find particles of the appropriate structure
particleIdx = find(ensemble.populations(end).strucIdx==strucIdx);
if numModels > numel(particleIdx) 
    numModels   = numel(particleIdx);
end

% Optimization & simulation parameters
fixedExchs   = ensemble.fixedExch;
kineticFxn   = str2func(ensemble.kineticFxn{strucIdx});
Sred         = ensemble.Sred;
kinInactRxns = ensemble.kinInactRxns;
subunits     = ensemble.subunits{strucIdx};

ix = 1;

currentPath = regexp(mfilename('fullpath'), '(.*)[/\\\\]', 'match');  
folderName =  fullfile(currentPath{1}, '..', '..', 'reactions', strcat(ensemble.description, '_', num2str(ix)));
if isfile(fullfile(folderName, strcat(func2str(kineticFxn), '_ode.m')))
    odeFunction = str2func(strcat(func2str(kineticFxn), '_ode'));
else
    error(['You need a model function to be used for the model ode simulations. It should be named as ', strcat(func2str(kineticFxn), '_ode')]);
end

if strcmp(metsAbsOrRel, 'abs')
    metsICabs = metsIC;
end

simulationRes = cell(1, numModels);

disp ('Simulating models.');

for jx = 1:numModels

    model = ensemble.populations(end).models(particleIdx(jx));
    metConcRef = model.metConcRef(ensemble.metsBalanced);
    
    if strcmp(metsAbsOrRel, 'abs')
        perturbInd = find(metsICabs ~= 1);
        metsIC(perturbInd) = metsICabs(perturbInd) ./ metConcRef(perturbInd);
    end
    
    outputFun= @(t,y,flag)interuptFun(t,y,flag,interruptTime);
    opts = odeset('RelTol',1e-13,'OutputFcn',outputFun);

    try
        % Simulate metabolite concentrations
        [t, y] = ode15s(@(t,y) odeFunction(y,enzymesIC,metConcRef,model,fixedExchs(:,ix),Sred,kinInactRxns,subunits), [0,finalTime], metsIC, opts);

        simulationRes{jx}.t = t;
        simulationRes{jx}.conc = y;   
        simulationRes{jx}.flux = calculateFluxes(t,y,enzymesIC,kineticFxn,model,fixedExchs(:,ix),Sred,kinInactRxns,subunits);   
        
        if strcmp(metsAbsOrRel, 'rel')
            simulationRes{jx}.flux = simulationRes{jx}.flux ./ ensemble.fluxRef';
        end
        
    catch ME
        if strcmp(ME.identifier,'interuptFun:Interupt')
            disp(ME.message);
        else
            rethrow(ME); % It's possible the error was due to something else
        end
    end

end

end


function status = interuptFun(t,y,flag,interruptTime)   
%
% Interrupts ODE solver if it takes more than interruptTime (in seconds);
%

persistent INIT_TIME;
status = 0;

switch(flag)
    case 'init'
        INIT_TIME = tic;
    case 'done'
        clear INIT_TIME;
    otherwise
        elapsedTime = toc(INIT_TIME);
        if elapsedTime > interruptTime
            clear INIT_TIME;
            error('interuptFun:Interupt',...
                 ['Interupted integration. Elapsed time is ' sprintf('%.6f',elapsedTime) ' seconds.']);
        end

end
end

function flux = calculateFluxes(timePoints,metConcs,enzymesIC,kineticFxn,model,fixedExchs,Sred,kinInactRxns,subunits)
    
flux = zeros(numel(timePoints), size(Sred,2));

for t=1:numel(timePoints)
    x = [metConcs(t,:)'; enzymesIC];
    flux(t,:) = feval(kineticFxn,x,model,fixedExchs,Sred,kinInactRxns,subunits,0);
end
end

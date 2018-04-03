function [rxnMetLinks,freeVars,metsActive] = buildKineticFxn(ensemble,kineticFxn,strucIdx)
%--------------------------------------------------------------------------
% Builds kinetic reaction file
%
% Inputs: ensemble    ensemble (structure), kinetic fxn name, strucIdx
%
% Outputs:    -       (writen .m file with the reaction mechanism)
%------------------------Pedro Saa 2016------------------------------------
% Define active species (mets/enzymes)
metsActive = ensemble.metsSimulated(~ismember(ensemble.metsSimulated,ensemble.metsFixed));
enzActive  = ensemble.activeRxns(~ismember(ensemble.activeRxns,ensemble.kinInactRxns));
totalEvals = numel(metsActive) + numel(enzActive) + 1;
freeVars   = [ensemble.mets(metsActive);ensemble.rxns(enzActive)];                             % return indexes of the free variables

% Write initial parameters
c = '%';
fid = fopen(['reactions',num2str(strucIdx),'/',kineticFxn,'.m'],'w');
fprintf(fid,['function [f,grad] = ',kineticFxn,'(x,model,fixedExch,Sred,kinInactRxns,subunits,flag)\n']);
fprintf(fid,'%s Pre-allocation of memory\n',c);
fprintf(fid,['v = zeros(',num2str(size(ensemble.Sred,2)),',',num2str(totalEvals),');\n']);      % Preallocation of memory (rxns)
fprintf(fid,['E = zeros(',num2str(size(ensemble.Sred,2)),',',num2str(totalEvals),');\n']);      % Preallocation of memory (enz)
fprintf(fid,'h = 1e-8;\n');                                                                                               % Step length
fprintf(fid,'x = x(:);\n');                                                                                               % Column vector

% Define metabolite species
fprintf(fid,'%s Defining metabolite and enzyme species\n',c);
fprintf(fid,['x = [x,x(:,ones(1,',num2str(totalEvals-1),')) + diag(h*1i*ones(',num2str(totalEvals-1),',1))];\n']);
i = 1; r = 1;
for j = 1:numel(metsActive)+numel(enzActive)
    if j<=numel(metsActive)
        fprintf(fid,[ensemble.mets{metsActive(j)},' = x(%i,:);\n'],i);                     % Only simulated metabolites in the kinetic fxn
    else
        fprintf(fid,['E(',num2str(enzActive(r)),',:) = x(%i,:);\n'],i);                    % Only simulated enzymes in the kinetic fxn
        r = r+1;
    end
    i = i+1;
end
if ~isempty(ensemble.kinInactRxns)
    fprintf(fid,['E(kinInactRxns,:) = fixedExch(:,ones(1,',num2str(totalEvals),'));\n']);  % Define fixed protein concentrations
end

% Define equations and determine connectivity between reactions and
% metabolites
rxnMetLinks{length(ensemble.activeRxns)} = [];
k = 1;
fprintf(fid,'%s Reaction rates\n',c);
for i = 1:numel(ensemble.activeRxns)
    reactants  = [];

    % Extract and organize substrates
    substrates  = (ensemble.mets(ensemble.S(:,ensemble.activeRxns(i))<0));   
    substrates  = substrates(ismember(substrates,ensemble.mets(ensemble.metsSimulated)));         % Extract only active substrates
    stoicCoeffs = abs(ensemble.S(ismember(ensemble.mets,substrates),ensemble.activeRxns(i)));
    
    % Substrates: Check the stoic coeff (relevant only if greater than 1)
    if any(stoicCoeffs>1)
        for w = 1:numel(substrates)
            if stoicCoeffs(w)>1
                for u = 2:stoicCoeffs(w)
                    substrates = [substrates;substrates(w)];
                end
            end
        end
    end
    
    % Extract and organize products
    products    = (ensemble.mets(ensemble.S(:,ensemble.activeRxns(i))>0));        
    products    = products(ismember(products,ensemble.mets(ensemble.metsSimulated)));               % Extract only active products
    stoicCoeffs = abs(ensemble.S(ismember(ensemble.mets,products),ensemble.activeRxns(i)));
    
    % Products: Check the stoic coeff (relevant only if greater than 1)
    if any(stoicCoeffs>1)
        for w = 1:numel(products)
            if stoicCoeffs(w)>1
                for u = 2:stoicCoeffs(w)
                    products = [products;products(w)];
                end
            end
        end
    end
    
    % Non-enzymatic reactions (diffusion)
    if strcmp('diffusion',ensemble.rxnMechanisms{strucIdx}(i))
        if ~isempty(substrates)
            reactants = substrates{1};
        else
            reactants = products{1};
        end
        rxnMetLinks{i} = reactants;                                                           % There is a link if rxn is diffusion
	
	elseif strcmp('massAction',ensemble.rxnMechanisms{strucIdx}(i))
        if ~ismember(substrates{1},ensemble.mets(ensemble.metsFixed))
            reactants      = [reactants,substrates{1},','];
            rxnMetLinks{i} = [rxnMetLinks{i},substrates(1)];
        else
            reactants = [reactants,'ones(1,',num2str(totalEvals),'),'];
        end
		if ~ismember(products{1},ensemble.mets(ensemble.metsFixed))
            reactants      = [reactants,products{1},','];
            rxnMetLinks{i} = [rxnMetLinks{i},products(1)];
        else
            reactants = [reactants,'ones(1,',num2str(totalEvals),'),'];
        end

    % Enzymatic reactions
    else	
        for j = 1:length(substrates)
            if ~ismember(substrates{j},ensemble.mets(ensemble.metsFixed))
                reactants      = [reactants,substrates{j},';'];
                rxnMetLinks{i} = [rxnMetLinks{i},substrates(j)];
            else
                reactants = [reactants,'ones(1,',num2str(totalEvals),');'];
            end
        end
        
        % If there is any inhibitors/activators we include them in the model
        if ~isempty(ensemble.inhibitors{strucIdx}{i})
            for j = 1:length(ensemble.inhibitors{strucIdx}{i})
                reactants      = [reactants,char(ensemble.inhibitors{strucIdx}{i}(j)),';'];
                rxnMetLinks{i} = [rxnMetLinks{i},ensemble.inhibitors{strucIdx}{i}];
            end
        end
        if ~isempty(ensemble.activators{strucIdx}{i})
            for j = 1:length(ensemble.activators{strucIdx}{i})
                reactants      = [reactants,char(ensemble.activators{strucIdx}{i}(j)),';'];
                rxnMetLinks{i} = [rxnMetLinks{i},ensemble.activators{strucIdx}{i}];
            end
        end
        for j = 1:length(products)
            if j<length(products)
                if ~ismember(products{j},ensemble.mets(ensemble.metsFixed))
                    reactants      = [reactants,products{j},';'];
                    rxnMetLinks{i} = [rxnMetLinks{i},products(j)];
                else
                    reactants = [reactants,'ones(1,',num2str(totalEvals),');'];
                end
            else
                if ~ismember(products{j},ensemble.mets(ensemble.metsFixed))
                    reactants      = [reactants,products{j}];
                    rxnMetLinks{i} = [rxnMetLinks{i},products(j)];
                else
                    reactants = [reactants,'ones(1,',num2str(totalEvals),');'];
                end
            end
        end
    end

    % Allosteric reaction
    if ensemble.allosteric{strucIdx}(i)
        negEffectors = [];
        posEffectors = [];
        
        % Both positive and negative effectors
        if ~isempty(ensemble.negEffectors{strucIdx}{i}) && ~isempty(ensemble.posEffectors{strucIdx}{i})
            for j = 1:length(ensemble.negEffectors{strucIdx}{i})-1
                negEffectors = [negEffectors,char(ensemble.negEffectors{strucIdx}{i}(j)),';'];
            end
            negEffectors = [negEffectors,char(ensemble.negEffectors{strucIdx}{i}(length(ensemble.negEffectors{strucIdx}{i})))];
            for j = 1:length(ensemble.posEffectors{strucIdx}{i})-1
                posEffectors = [posEffectors,char(ensemble.posEffectors{strucIdx}{i}(j)),';'];
            end
            posEffectors = [posEffectors,char(ensemble.posEffectors{strucIdx}{i}(length(ensemble.posEffectors{strucIdx}{i})))];
            fprintf(fid,['v(%i,:) = ',ensemble.rxns{i},num2str(strucIdx),'([',reactants,'],[',negEffectors,'],[',posEffectors,'],model.rxnParams(%i).kineticParams,model.rxnParams(%i).KnegEff,model.rxnParams(%i).KposEff,model.rxnParams(%i).L,subunits(%i));\n'],i,k,k,k,k,k);
            k = k+1;
            
        % Only negative effectors
        elseif ~isempty(ensemble.negEffectors{strucIdx}{i})
            for j = 1:length(ensemble.negEffectors{strucIdx}{i})-1
                negEffectors = [negEffectors,char(ensemble.negEffectors{strucIdx}{i}(j)),';'];
            end
            negEffectors = [negEffectors,char(ensemble.negEffectors{strucIdx}{i}(length(ensemble.negEffectors{strucIdx}{i})))];
            fprintf(fid,['v(%i,:) = ',ensemble.rxns{i},num2str(strucIdx),'([',reactants,'],[',negEffectors,'],model.rxnParams(%i).kineticParams,model.rxnParams(%i).KnegEff,model.rxnParams(%i).L,subunits(%i));\n'],i,k,k,k,k);
            k = k+1;
            
        % Only positive effectors
        elseif ~isempty(ensemble.posEffectors{strucIdx}{i})
            for j = 1:length(ensemble.posEffectors{strucIdx}{i})-1
                posEffectors = [posEffectors,char(ensemble.posEffectors{strucIdx}{i}(j)),';'];
            end
            posEffectors = [posEffectors,char(ensemble.posEffectors{strucIdx}{i}(length(ensemble.posEffectors{strucIdx}{i})))];
            fprintf(fid,['v(%i,:) = ',ensemble.rxns{i},num2str(strucIdx),'([',reactants,'],[',posEffectors,'],model.rxnParams(%i).kineticParams,model.rxnParams(%i).KposEff,model.rxnParams(%i).L,subunits(%i));\n'],i,k,k,k,k);
            k = k+1;
            
        % No effectors, only cooperative binding
        else
            fprintf(fid,['v(%i,:) = ',ensemble.rxns{i},num2str(strucIdx),'([',reactants,'],model.rxnParams(%i).kineticParams,model.rxnParams(%i).L,subunits(%i));\n'],i,k,k,k);
            k = k+1;
        end
        
        % Non-allosteric reaction
    else
        if strcmp('fixedExchange',ensemble.rxnMechanisms{strucIdx}(i))
            fprintf(fid,['v(%i,:) = ',ensemble.rxns{i},num2str(strucIdx),'([],[]);\n'],i);
        elseif strcmp('freeExchange',ensemble.rxnMechanisms{strucIdx}(i))
            fprintf(fid,['v(%i,:) = ',ensemble.rxns{i},num2str(strucIdx),'(model.rxnParams(%i).kineticParams,',num2str(totalEvals),');\n'],i,k);
            k = k+1;
		elseif strcmp('massAction',ensemble.rxnMechanisms{strucIdx}(i))
            fprintf(fid,['v(%i,:) = ',ensemble.rxns{i},num2str(strucIdx),'(',reactants,'model.rxnParams(%i).kineticParams);\n'],i,k);
            k = k+1;
        else
            fprintf(fid,['v(%i,:) = ',ensemble.rxns{i},num2str(strucIdx),'([',reactants,'],model.rxnParams(%i).kineticParams);\n'],i,k);
            k = k+1;
        end
    end
    
    % Add enzyme links to the rxnMet links (only if the reaction is not an exch)
    if ~isempty(reactants)
        rxnMetLinks{i} = [rxnMetLinks{i},ensemble.rxns{ensemble.activeRxns(i)}];
    end
end

% Definition of final rates
fprintf(fid,'if flag\n');
fprintf(fid,'%s Final rates\n',c);
fprintf(fid,'y = sum((Sred*(E.*v)).^2);\n');
fprintf(fid,'f = real(y(1));\n');
fprintf(fid,'if (nargout>1) %s gradient is required\n',c);
fprintf(fid,'grad = imag(y(2:end))/h;\n');
fprintf(fid,'end\n');
fprintf(fid,'else\n');
fprintf(fid,'f = E(:,1).*v(:,1);\n');
fprintf(fid,'grad = [];\n');
fprintf(fid,'end');
fclose(fid);
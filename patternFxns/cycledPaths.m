function paths = cycledPaths(subsNodes,prodNodes,forwardFlux)
%--------------------------------------------------------------------------
% Determines all the possible cycles in the pattern 
%
% Inputs:       (subsNodes)    nodes consuming substrates
%               (prodNodes)    nodes producing products
%             (forwardFlux)    list with the edges of the forward reactions
%
% Outputs:          (paths)    all possible paths (even redundants)
%-----------------------Pedro Saa 2014-------------------------------------
%% 1. Form adjacency matrix
adjMatrix = biograph(sparse(forwardFlux(:,1)',forwardFlux(:,2)',...
    true,max(max(forwardFlux)),max(max(forwardFlux))));

%% 2. Determine the shortest paths between S- and P- nodes
for i = 1:length(subsNodes)
    distCurrent = 10;        % Arbitrary large number
    for j = 1:length(prodNodes)
        [dist,shortPath] = shortestpath(adjMatrix,subsNodes(i),prodNodes(j));
        if dist > 1 && distCurrent > dist
            paths{i,1} = shortPath;
            distCurrent = dist;
        end
    end
end

%% 3. Find alternative paths (if any) and re-cycle the found paths
for k = 1:size(paths,1)
    shortPath = paths{k}; W = getWeight(shortPath,forwardFlux);
    [~,path] = shortestpath(adjMatrix,shortPath(1),shortPath(end),'Weights',W);        
    if isequal(shortPath,path) ~= 1
        paths{end+1} = path;
        [~,pathCycled] = shortestpath(adjMatrix,path(end),path(1));
        
        % Check for alternative ways for reconecting the path
        W = getWeight(pathCycled,forwardFlux);
        [~,pathAlternative] = shortestpath(adjMatrix,path(end),path(1),'Weights',W);
        paths{end} = [paths{end},pathCycled(2:end)];
        if isequal(pathAlternative,pathCycled) ~= 1
            paths{end+1} = [path,pathAlternative(2:end)];
        end
    end
    
    % Finally, re-cycle the root path appropiately
    [~,pathCycled] = shortestpath(adjMatrix,shortPath(end),shortPath(1));   
    paths{k} = [shortPath,pathCycled(2:end)];
    
    % Check for alternative ways of reconecting the root path
    W = getWeight(pathCycled,forwardFlux);
    [~,pathAlternative] = shortestpath(adjMatrix,shortPath(end),shortPath(1),'Weights',W);    
    if isequal(pathAlternative,pathCycled) ~= 1
        paths{end+1} = [shortPath,pathAlternative(2:end)];
    end
end
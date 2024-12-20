function cell_metrics = rank_order_metrics(cell_metrics,session,spikes,parameters)
% rank_order_metrics: gets median normalized rank order for each unit 
%   relative to ripple epochs 
%
% INPUTS
% cell_metrics - cell_metrics struct
% session - session struct with session-level metadata
% spikes_intervalsExcluded - spikes struct filtered by (manipulation) intervals
% spikes - spikes cell struct
%   spikes{1} : all spikes
%   spikes{2} : spikes excluding manipulation intervals
% parameters - input parameters to ProcessCellExplorer
%
% OUTPUT
% cell_metrics - updated cell_metrics struct
%           cell_metrics.rankUnits
%
% By Ryan Harvey


basepath = session.general.basePath;
basename = basenameFromBasepath(basepath);

if exist(fullfile(basepath,[basename,'.ripples.events.mat']),'file')
    
    load(fullfile(basepath,[basename,'.ripples.events.mat']),'ripples')

    % Excluding ripples that have been flagged
    if isfield(ripples,'flagged')
        ripples.timestamps(ripples.flagged,:) = [];
    end
    ripples = IntervalArray(ripples.timestamps);

    rankStats = main(basepath,spikes{1},ripples.intervals);
    
    cell_metrics.rankorder = median(rankStats.rankUnits,2,'omitnan')';
    
    if any(contains(parameters.metrics,{'state_metrics','all'})) &&...
            ~any(contains(parameters.excludeMetrics,{'state_metrics'}))
        
        spkExclu = setSpkExclu('state_metrics',parameters);
        
        statesFiles = dir(fullfile(basepath,[basename,'.*.states.mat']));
        statesFiles = {statesFiles.name};
        statesFiles(contains(statesFiles,parameters.ignoreStateTypes))=[];
        for iEvents = 1:length(statesFiles)
            statesName = strsplit(statesFiles{iEvents},'.');
            statesName = statesName{end-2};
            eventOut = load(fullfile(basepath,statesFiles{iEvents}));
            
            if isfield(eventOut.(statesName),'ints')
                states = eventOut.(statesName).ints;
                statenames = fieldnames(states);
                for iStates = 1:numel(statenames)
                    if ~size(states.(statenames{iStates}),1) > 0
                        continue
                    end

                    current_ripples = ripples & IntervalArray(states.(statenames{iStates}));

                    if current_ripples.isempty
                        continue
                    end
                    rankStats = main(basepath,...
                        spikes{spkExclu},...
                        current_ripples.intervals);
                    
                    % single cell metrics to cell_metrics
                    cell_metrics.(['rankorder_',statenames{iStates}]) =...
                        median(rankStats.rankUnits,2,'omitnan')';
                end
            end
        end
    end
end
end

function rankStats = main(basepath,spikes,ripples)
try
    ripSpk = getRipSpikes('basepath',basepath,...
        'spikes',spikes,...
        'events',ripples.timestamps,...
        'saveMat',false);
catch
    ripSpk = getRipSpikes(spikes,ripples,'saveMat',false,'basepath',basepath);
end
rankStats.rankUnits = RankOrder_units(ripSpk);
end

function rankUnits = RankOrder_units(spkEventTimes)

minUnits = 5;
normalize = true;

% Relative times of spikes for each particular event across all units.
evtTimes = spkEventTimes.EventRel;

rankUnits = nan*ones(size(spkEventTimes.UnitEventRel));
for event = 1:length(evtTimes)
    % Take into account just first spike
    units = unique(evtTimes{event}(2,:),'stable');
   
    nUnits = length(units);
    % Set event as nan if it has no enough units
    if nUnits < minUnits
        rankUnits(:,event) = nan;
    % Rank units
    else
        rankUnits(units,event) = 1:nUnits;
        % If normalize, set ranks between 0 and 1        
        if normalize
            rankUnits(units,event) = rankUnits(units,event) / nUnits;
        end
    end
end
end

function spkExclu = setSpkExclu(metrics,parameters)
if ismember(metrics,parameters.metricsToExcludeManipulationIntervals)
    spkExclu = 2; % Spikes excluding times within exclusion intervals
else
    spkExclu = 1; % All spikes (can be restricted)
end
end
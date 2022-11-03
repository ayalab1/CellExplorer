function [meanCCG,tR,population_modIndex] = detectDownStateCells(spikes,sr,varargin)
% Calculates the average CCG for each cell and determines their population modulation
% index defined as the ratio between the CCG bins from t=-250 to -200 and +200ms to
% +250ms to the interval arounnd +-50ms

% By Peter Petersen
% Last edited: 08-09-2020

p = inputParser;
addParameter(p,'showFigures',true,@islogical);
parse(p,varargin{:})

binSize = 0.01;  % in seconds (default: 0.010 second bin size)
duration = 0.5; % in seconds (default: +-0.250 second)

if ~isfield(spikes,'spindices')
    disp('Generating spindices')
    spikes.spindices = generateSpinDices(spikes.times);
end
[spiketimes,b] = sort(spikes.spindices(:,1));
spikeIDs = double(spikes.spindices(b,2));

% Generating CCG matrix
[ccgR1,tR] = CCG(spiketimes,spikeIDs,'binSize',binSize,'duration',duration,'norm','rate','Fs',1/sr);

neuron_num = size(ccgR1,3);
NaNccgR1 = ccgR1;
for i=1:neuron_num
    NaNccgR1(:,i,i)=NaN(51,1);
end
meanCCG = mean(NaNccgR1,3,'omitnan');

population_modIndex  = mean(meanCCG([21:31],:))./mean(meanCCG([1:5,47:51],:));

disp('Detecting down-state cells')
if p.Results.showFigures
if isfield(spikes,'sessionName') 
    figure('name',spikes.sessionName)
else
    figure
end
subplot(1,2,1)
plot(tR,meanCCG./mean(meanCCG)), title('Average CCG'),xlabel('Time (seconds)'), axis tight
subplot(1,2,2)
histogram(population_modIndex), title('Population modulation index'), xlabel('Modulation strength')
end

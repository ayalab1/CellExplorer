function fixture = extract_getWaveformsFromDat_templates(varargin)
% Extract a few real Kilosort templates and save a compact fixture .mat file.
%
% This is intended as a one-time helper for building CI fixtures from a real
% recording. The generated .mat file is small and self-contained, so CI does
% not need access to the original R: drive data.
%
% Example:
%   fixture = extract_getWaveformsFromDat_templates
%
%   fixture = extract_getWaveformsFromDat_templates( ...
%       'basepath', 'R:\ys2375\Test data\test_rec_260509', ...
%       'phyFolder', 'Kilosort_2026-05-09_192146', ...
%       'outputFile', fullfile('tests','fixtures', ...
%           'getWaveformsFromDat_mergepoints_templates.mat'));

p = inputParser;
addParameter(p, 'basepath', 'R:\ys2375\Test data\test_rec_260509', @ischar);
addParameter(p, 'phyFolder', 'Kilosort_2026-05-09_192146', @ischar);
addParameter(p, 'outputFile', fullfile('tests', 'fixtures', 'getWaveformsFromDat_mergepoints_templates.mat'), @ischar);
addParameter(p, 'nTemplates', 3, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'nChannelsToKeep', 4, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'cropSamples', 21, @(x) isnumeric(x) && isscalar(x) && x >= 5);
addParameter(p, 'targetPeakUv', 120, @(x) isnumeric(x) && isscalar(x) && x > 0);
parse(p, varargin{:});

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(repoRoot));

basepath = p.Results.basepath;
basename = basenameFromBasepath(basepath);
phyPath = fullfile(basepath, p.Results.phyFolder);
outputFile = p.Results.outputFile;
nTemplates = p.Results.nTemplates;
nChannelsToKeep = p.Results.nChannelsToKeep;
cropSamples = p.Results.cropSamples;
targetPeakUv = p.Results.targetPeakUv;

assert(isfolder(basepath), 'Basepath not found: %s', basepath);
assert(isfolder(phyPath), 'Phy folder not found: %s', phyPath);

sessionData = load(fullfile(basepath, [basename, '.session.mat']), 'session');
session = sessionData.session;
clusterInfo = readtable(fullfile(phyPath, 'cluster_info.tsv'), 'FileType', 'text', 'Delimiter', '\t');
templates = readNPY(fullfile(phyPath, 'templates.npy'));
spikeTemplates = double(readNPY(fullfile(phyPath, 'spike_templates.npy')));
spikeClusters = double(readNPY(fullfile(phyPath, 'spike_clusters.npy')));

assert(ndims(templates) == 3, 'Expected templates.npy to be 3D.');
assert(any(strcmp(clusterInfo.Properties.VariableNames, 'cluster_id')), ...
    'cluster_info.tsv must contain cluster_id.');

goodMask = true(height(clusterInfo), 1);
if any(strcmp(clusterInfo.Properties.VariableNames, 'group'))
    goodMask = strcmp(string(clusterInfo.group), "good");
elseif any(strcmp(clusterInfo.Properties.VariableNames, 'KSLabel'))
    goodMask = strcmp(string(clusterInfo.KSLabel), "good");
end

goodClusters = clusterInfo(goodMask, :);
assert(~isempty(goodClusters), 'No good clusters found in %s', phyPath);

if any(strcmp(goodClusters.Properties.VariableNames, 'amp'))
    [~, order] = sort(goodClusters.amp, 'descend');
else
    order = 1:height(goodClusters);
end
goodClusters = goodClusters(order, :);

selected = struct( ...
    'clusterId', {}, ...
    'templateId', {}, ...
    'globalChannels', {}, ...
    'localPeakCh1', {}, ...
    'waveformUv', {}, ...
    'waveformRawInt16', {});

usedChannelSets = {};
for i = 1:height(goodClusters)
    clusterId = double(goodClusters.cluster_id(i));
    templateId = choose_template_for_cluster(clusterId, spikeClusters, spikeTemplates);
    templateWaveform = squeeze(double(templates(templateId + 1, :, :))); % Kilosort ids are 0-indexed

    [croppedUv, globalChannels, localPeakCh1] = crop_template(templateWaveform, nChannelsToKeep, cropSamples, targetPeakUv);
    channelSignature = sprintf('%d_', globalChannels);

    if any(strcmp(usedChannelSets, channelSignature))
        continue
    end

    selected(end + 1).clusterId = clusterId; %#ok<AGROW>
    selected(end).templateId = templateId;
    selected(end).globalChannels = globalChannels;
    selected(end).localPeakCh1 = localPeakCh1;
    selected(end).waveformUv = croppedUv;
    selected(end).waveformRawInt16 = int16(round(croppedUv / session.extracellular.leastSignificantBit));
    usedChannelSets{end + 1} = channelSignature; %#ok<AGROW>

    if numel(selected) >= nTemplates
        break
    end
end

assert(~isempty(selected), 'No templates were extracted.');

fixture = struct();
fixture.sourceBasepath = basepath;
fixture.sourcePhyFolder = phyPath;
fixture.basename = basename;
fixture.sr = session.extracellular.sr;
fixture.LSB = session.extracellular.leastSignificantBit;
fixture.precision = 'int16';
fixture.cropSamples = cropSamples;
fixture.nChannelsToKeep = nChannelsToKeep;
fixture.templates = selected;

outputDir = fileparts(outputFile);
if ~isempty(outputDir) && ~isfolder(outputDir)
    mkdir(outputDir);
end
save(outputFile, 'fixture');

fprintf('Saved %d templates to %s\n', numel(selected), outputFile);
for i = 1:numel(selected)
    fprintf('  Template %d: cluster %d, template %d, channels %s, local peak ch %d\n', ...
        i, selected(i).clusterId, selected(i).templateId, mat2str(selected(i).globalChannels), selected(i).localPeakCh1);
end

end

function templateId = choose_template_for_cluster(clusterId, spikeClusters, spikeTemplates)
clusterSpikeIdx = spikeClusters == clusterId;
assert(any(clusterSpikeIdx), 'Cluster %d has no spikes in spike_clusters.npy.', clusterId);
templateId = mode(spikeTemplates(clusterSpikeIdx));
end

function [croppedUv, channelsKept, localPeakCh1] = crop_template(templateWaveform, nChannelsToKeep, cropSamples, targetPeakUv)
% templateWaveform is [time x channels]
channelSpread = range(templateWaveform, 1);
[~, channelOrder] = sort(channelSpread, 'descend');
channelsKept = sort(channelOrder(1:nChannelsToKeep));

waveformSubset = templateWaveform(:, channelsKept);
[~, localPeakCh1] = max(range(waveformSubset, 1));
[~, peakSample] = min(waveformSubset(:, localPeakCh1));

halfWindow = floor(cropSamples / 2);
startSample = max(1, peakSample - halfWindow);
stopSample = min(size(waveformSubset, 1), startSample + cropSamples - 1);
startSample = max(1, stopSample - cropSamples + 1);
croppedUv = waveformSubset(startSample:stopSample, :);

% Normalize to a predictable amplitude while preserving the real shape.
peakAbs = max(abs(croppedUv(:, localPeakCh1)));
if peakAbs > 0
    croppedUv = croppedUv * (targetPeakUv / peakAbs);
end
end

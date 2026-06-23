function fixtureData = generate_getWaveformsFromDat_fixture(varargin)
% Generate a compact synthetic dataset for getWaveformsFromDat CI tests.
%
% The synthetic data uses real templates previously extracted from a real
% recording, but writes a tiny self-contained session with:
%   basename.dat
%   subfolder_01/amplifier.dat
%   subfolder_02/amplifier.dat
%   subfolder_01/.../Acquisition_Board-100.acquisition_board/continuous.dat
%   subfolder_02/.../Acquisition_Board-100.acquisition_board/continuous.dat
%   basename.MergePoints.events.mat
%
% Example:
%   fixtureData = generate_getWaveformsFromDat_fixture

p = inputParser;
addParameter(p, 'outputRoot', tempname, @ischar);
addParameter(p, 'basename', 'test_mergepoints_fixture', @ischar);
addParameter(p, 'fixtureFile', fullfile('tests', 'fixtures', 'getWaveformsFromDat_mergepoints_templates.mat'), @ischar);
addParameter(p, 'segmentDurationSec', 5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'nChannels', 4, @(x) isnumeric(x) && isscalar(x) && x == 4);
addParameter(p, 'samplingRate', 20000, @(x) isnumeric(x) && isscalar(x) && x > 0);
parse(p, varargin{:});

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(repoRoot));

fixtureStruct = load(p.Results.fixtureFile, 'fixture');
fixture = fixtureStruct.fixture;

outputRoot = p.Results.outputRoot;
basename = p.Results.basename;
segmentDurationSec = p.Results.segmentDurationSec;
nChannels = p.Results.nChannels;
sr = p.Results.samplingRate;

segmentSamples = round(segmentDurationSec * sr);
totalSamples = segmentSamples * 2;

mkdir(outputRoot);
mkdir(fullfile(outputRoot, 'subfolder_01'));
mkdir(fullfile(outputRoot, 'subfolder_02'));

spikePlan = build_spike_plan();
rawData = zeros(totalSamples, nChannels, 'int32');

for iUnit = 1:numel(spikePlan)
    template = fixture.templates(iUnit).waveformRawInt16;
    centerSample = ceil(size(template, 1) / 2);
    for iSpike = 1:numel(spikePlan(iUnit).timesSec)
        spikeSample = round(spikePlan(iUnit).timesSec(iSpike) * sr);
        rowIdx = spikeSample - centerSample + 1 : spikeSample - centerSample + size(template, 1);
        rawData(rowIdx, :) = rawData(rowIdx, :) + int32(template);
    end
end

rawData = int16(rawData);
segment1 = rawData(1:segmentSamples, :);
segment2 = rawData(segmentSamples + 1:end, :);

write_binary(fullfile(outputRoot, [basename, '.dat']), rawData);
write_binary(fullfile(outputRoot, 'subfolder_01', 'amplifier.dat'), segment1);
write_binary(fullfile(outputRoot, 'subfolder_02', 'amplifier.dat'), segment2);
write_open_ephys_continuous(outputRoot, 'subfolder_01', segment1);
write_open_ephys_continuous(outputRoot, 'subfolder_02', segment2);

MergePoints = struct();
MergePoints.timestamps_samples = [
    0, segmentSamples;
    segmentSamples, totalSamples
];
MergePoints.foldernames = {'subfolder_01', 'subfolder_02'};
save(fullfile(outputRoot, [basename, '.MergePoints.events.mat']), 'MergePoints');

session = struct();
session.general.name = basename;
session.general.basePath = outputRoot;
session.extracellular.leastSignificantBit = fixture.LSB;
session.extracellular.nChannels = nChannels;
session.extracellular.sr = sr;
session.extracellular.precision = fixture.precision;
session.extracellular.fileName = [basename, '.dat'];
session.extracellular.nElectrodeGroups = 1;
session.extracellular.electrodeGroups.channels = {1:nChannels};
session.extracellular.spikeGroups.channels = {1:nChannels};
save(fullfile(outputRoot, [basename, '.session.mat']), 'session');

spikes = struct();
spikes.basename = basename;
spikes.sr = sr;
spikes.UID = 1:numel(spikePlan);
spikes.cluID = 101:100 + numel(spikePlan);
spikes.times = cell(1, numel(spikePlan));
spikes.ts = cell(1, numel(spikePlan));
spikes.total = zeros(1, numel(spikePlan));
for iUnit = 1:numel(spikePlan)
    spikes.times{iUnit} = spikePlan(iUnit).timesSec;
    spikes.ts{iUnit} = round(spikePlan(iUnit).timesSec * sr);
    spikes.total(iUnit) = numel(spikePlan(iUnit).timesSec);
end

fixtureData = struct();
fixtureData.basepath = outputRoot;
fixtureData.basename = basename;
fixtureData.session = session;
fixtureData.spikes = spikes;
fixtureData.segmentSamples = segmentSamples;
fixtureData.safeIntervalsSec = [
    40 / sr, segmentDurationSec - 40 / sr;
    segmentDurationSec + 40 / sr, 2 * segmentDurationSec - 40 / sr
];
fixtureData.boundarySpikeSec = spikePlan(3).timesSec(end-1:end);
fixtureData.expectedSafeTimes = {
    spikePlan(1).timesSec, ...
    spikePlan(2).timesSec, ...
    spikePlan(3).timesSec(1:end-2)
};
fixtureData.expectedPeakChannels = [fixture.templates(1).localPeakCh1, fixture.templates(2).localPeakCh1, fixture.templates(3).localPeakCh1];
end

function spikePlan = build_spike_plan()
spikePlan = struct('timesSec', {});
spikePlan(1).timesSec = [1.0, 2.0, 3.5, 4.0];
spikePlan(2).timesSec = [6.0, 7.0, 8.0, 9.0];
spikePlan(3).timesSec = [2.5, 4.5, 5.5, 7.5, 4.9990, 5.0010];
end

function write_open_ephys_continuous(outputRoot, foldername, ephysData)
continuousDir = fullfile(outputRoot, foldername, 'Record Node 101', 'experiment1', 'recording1', ...
    'continuous', 'Acquisition_Board-100.acquisition_board');
memoryDir = fullfile(outputRoot, foldername, 'Record Node 101', 'experiment1', 'recording1', ...
    'continuous', 'Acquisition_Board-100.memory_usage');
mkdir(continuousDir);
mkdir(memoryDir);

nSamples = size(ephysData, 1);
adcData = int16([repmat(101, nSamples, 1), repmat(-101, nSamples, 1)]);
write_binary(fullfile(continuousDir, 'continuous.dat'), [ephysData, adcData]);
write_binary(fullfile(memoryDir, 'continuous.dat'), int16(zeros(max(1, round(nSamples / 200)), 1)));
end

function write_binary(filename, data)
fid = fopen(filename, 'w');
assert(fid > 0, 'Failed to open %s for writing.', filename);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
count = fwrite(fid, data', 'int16');
assert(count == numel(data), 'Failed to write expected data count to %s.', filename);
end

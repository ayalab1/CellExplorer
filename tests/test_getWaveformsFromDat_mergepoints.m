function tests = test_getWaveformsFromDat_mergepoints
tests = functiontests(localfunctions);
end

function testMergePointsFallbackMatchesSafeRegion(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(repoRoot));

fixtureData = generate_getWaveformsFromDat_fixture('outputRoot', tempname);
cleanupObj = onCleanup(@() cleanup_fixture(fixtureData.basepath)); %#ok<NASGU>

directSpikes = run_waveform_extraction(fixtureData.spikes, fixtureData.session);

datFile = fullfile(fixtureData.basepath, [fixtureData.basename, '.dat']);
backupDatFile = [datFile, '.bak'];
movefile(datFile, backupDatFile);
restoreObj = onCleanup(@() restore_dat(datFile, backupDatFile)); %#ok<NASGU>

fallbackSpikes = run_waveform_extraction(fixtureData.spikes, fixtureData.session);

verifyEqual(testCase, directSpikes.processinginfo.params.WaveformsSource, 'dat file');
verifyEqual(testCase, fallbackSpikes.processinginfo.params.WaveformsSource, 'MergePoints amplifier.dat files');
verifyEqual(testCase, directSpikes.cluID, fallbackSpikes.cluID);

for iUnit = 1:numel(fixtureData.spikes.times)
    verifyEqual(testCase, directSpikes.maxWaveformCh1(iUnit), fixtureData.expectedPeakChannels(iUnit));
    verifyEqual(testCase, fallbackSpikes.maxWaveformCh1(iUnit), fixtureData.expectedPeakChannels(iUnit));

    directSafe = restrict_times_to_intervals(directSpikes.waveforms.times{iUnit}, fixtureData.safeIntervalsSec);
    fallbackSafe = restrict_times_to_intervals(fallbackSpikes.waveforms.times{iUnit}, fixtureData.safeIntervalsSec);

    verifyEqual(testCase, directSafe(:), fixtureData.expectedSafeTimes{iUnit}(:), 'AbsTol', 1e-12);
    verifyEqual(testCase, fallbackSafe(:), fixtureData.expectedSafeTimes{iUnit}(:), 'AbsTol', 1e-12);
    verifyEqual(testCase, directSafe(:), fallbackSafe(:), 'AbsTol', 1e-12);

    % Units 1-2 contain only safe spikes, so their mean waveforms should
    % match exactly between the direct and fallback paths.
    if iUnit <= 2
        verifyEqual(testCase, directSpikes.rawWaveform{iUnit}, fallbackSpikes.rawWaveform{iUnit}, 'AbsTol', 1e-9);
        verifyEqual(testCase, directSpikes.filtWaveform{iUnit}, fallbackSpikes.filtWaveform{iUnit}, 'AbsTol', 1e-9);
    end
end

verifyEqual(testCase, fallbackSpikes.waveforms.times{3}(:), fixtureData.expectedSafeTimes{3}(:), 'AbsTol', 1e-12);
verifyTrue(testCase, any(abs(directSpikes.waveforms.times{3} - fixtureData.boundarySpikeSec(1)) < 1e-12));
verifyTrue(testCase, any(abs(directSpikes.waveforms.times{3} - fixtureData.boundarySpikeSec(2)) < 1e-12));
verifyFalse(testCase, any(abs(fallbackSpikes.waveforms.times{3} - fixtureData.boundarySpikeSec(1)) < 1e-12));
verifyFalse(testCase, any(abs(fallbackSpikes.waveforms.times{3} - fixtureData.boundarySpikeSec(2)) < 1e-12));
end

function spikesOut = run_waveform_extraction(spikesIn, session)
rng(1);
spikesOut = getWaveformsFromDat( ...
    spikesIn, session, ...
    'showWaveforms', false, ...
    'saveMat', false, ...
    'keepWaveforms_raw', true, ...
    'nPull', 1000000);
end

function restricted = restrict_times_to_intervals(timesSec, intervalsSec)
keep = false(size(timesSec));
for i = 1:size(intervalsSec, 1)
    keep = keep | (timesSec > intervalsSec(i,1) & timesSec <= intervalsSec(i,2));
end
restricted = timesSec(keep);
end

function restore_dat(datFile, backupDatFile)
if exist(backupDatFile, 'file') == 2 && exist(datFile, 'file') ~= 2
    movefile(backupDatFile, datFile);
end
end

function cleanup_fixture(basepath)
if isfolder(basepath)
    rmdir(basepath, 's');
end
end

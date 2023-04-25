function [ripples] = ce_FindRipples(varargin)
%FindRipples - Find hippocampal ripples (100~200Hz oscillations).
%
% USAGE
%    ripples = ce_FindRipples(session); % This requires the ripple channel defined in the session struct: session.channelTags.Ripple.channels = 1;
%       You still have to define processing parameters 
%    OR
%    ripples = ce_FindRipples(lfp.data,lfp.timestamps,<options>)
%    OR
%    ripples = ce_FindRipples(basepath,channel,<options>)
%
%    Ripples are detected using the normalized squared signal (NSS) by
%    thresholding the baseline, merging neighboring events, thresholding
%    the peaks, and discarding events with excessive duration.
%    Thresholds are computed as multiples of the standard deviation of
%    the NSS. Alternatively, one can use explicit values, typically obtained
%    from a previous call.  The estimated EMG can be used as an additional
%    exclusion criteria
%
% INPUTS - note these are NOT name-value pairs... just raw values

%    lfp            unfiltered LFP (one channel) to use
%	 timestamps	    timestamps to match filtered variable
%    <options>      optional list of property-value pairs (see tables below)
%
%    OR
%
%    basepath       path to a single session to run findRipples on
%    channel      	Ripple channel to use for detection (1-indexed ala Matlab)
%
%    =========================================================================
%     Properties    Values
%    -------------------------------------------------------------------------
%     'thresholds'  thresholds for ripple beginning/end and peak, in multiples
%                   of the stdev (default = [2 5]); must be integer values
%     'durations'   min inter-ripple interval and max ripple duration, in ms
%                   (default = [30 100]). 
%     'minDuration' min ripple duration. Keeping this input nomenclature for backwards
%                   compatibility
%     'restrict'    interval used to compute normalization (default = all)
%     'frequency'   sampling rate (in Hz) (default = 1250Hz)
%     'stdev'       reuse previously computed stdev
%     'show'        plot results (default = 'off')
%     'noise'       noisy unfiltered channel used to exclude ripple-
%                   like noise (events also present on this channel are
%                   discarded)
%     'passband'    N x 2 matrix of frequencies to filter for ripple detection 
%                   (default = [130 200])
%     'EMGThresh'   0-1 threshold of EMG to exclude noise
%     'saveMat'     logical (default=false) to save in buzcode format
%     'plotType'   1=original version (several plots); 2=only raw lfp
%    =========================================================================
%
% OUTPUT
%
%    ripples        buzcode format .event. struct with the following fields
%                   .timestamps        Nx2 matrix of start/stop times for
%                                      each ripple
%                   .detectorName      string ID for detector function used
%                   .peaks             Nx1 matrix of peak power timestamps 
%                   .stdev             standard dev used as threshold
%                   .noise             candidate ripples that were
%                                      identified as noise and removed
%                   .peakNormedPower   Nx1 matrix of peak power values
%                   .detectorParams    struct with input parameters given
%                                      to the detector

% Copyright (C) 2004-2011 by Michaël Zugaro, initial algorithm by Hajime Hirase
% edited by David Tingley, 2017
% Edited by Peter Petersen, January 2021, renamed function and added session struct
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 3 of the License, or
% (at your option) any later version.

% Default values
p = inputParser;
addParameter(p,'thresholds',[2 5],@isnumeric)
addParameter(p,'absoluteThresholds',false,@islogical)
addParameter(p,'durations',[20 150],@isnumeric)
addParameter(p,'restrict',[],@isnumeric)
addParameter(p,'frequency',1250,@isnumeric)
addParameter(p,'stdev',[],@isnumeric)
addParameter(p,'show','off',@isstr)
addParameter(p,'noise',[],@ismatrix)
addParameter(p,'passband',[130 200],@isnumeric)
addParameter(p,'EMGThresh',.9,@isnumeric);
addParameter(p,'saveMat',false,@islogical);
addParameter(p,'minDuration',20,@isnumeric)
addParameter(p,'plotType',1,@isnumeric)

    
if isstruct(varargin{1})  % if first arg is a session struct
    addRequired(p,'session',@isstruct)
    parse(p,varargin{:})
    passband = p.Results.passband;
    EMGThresh = p.Results.EMGThresh;
    session = p.Results.session;
    basename = session.general.name;
    basepath = session.general.basePath;
    if exist(fullfile(basepath,[basename, '.lfp']),'file')
        lfp_file = fullfile(basepath,[basename, '.lfp']);
    elseif exist(fullfile(basepath,[basename, '.eeg']),'file')
        lfp_file = fullfile(basepath,[basename, '.eeg']);
    end
    lfp = LoadBinary(lfp_file,'nChannels',session.extracellular.nChannels,...
        'channels',session.channelTags.Ripple.channels(1),...
        'precision','int16','frequency',session.extracellular.srLfp);
    % Filtering the lfp trace
    [filt_b filt_a] = cheby2(4,50,passband/(0.5*session.extracellular.srLfp));
    signal = filtfilt(filt_b,filt_a,single(lfp));
    % Assigning timestamps
    timestamps = [1:length(signal)]'/session.extracellular.srLfp;

elseif isstr(varargin{1})  % if first arg is basepath (string)
    addRequired(p,'basepath',@isstr)
    addRequired(p,'channel',@isnumeric)    
    parse(p,varargin{:})
    passband = p.Results.passband;
    EMGThresh = p.Results.EMGThresh;
    basename = bz_BasenameFromBasepath(p.Results.basepath);
    basepath = p.Results.basepath;
    lfp = bz_GetLFP(p.Results.channel-1,'basepath',p.Results.basepath,'basename',basename); % currently cannot take path inputs
    signal = bz_Filter(double(lfp.data),'filter','butter','passband',passband,'order', 3);
    timestamps = lfp.timestamps;
elseif isnumeric(varargin{1}) % if first arg is filtered LFP (numeric)
    addRequired(p,'lfp',@isnumeric)
    addRequired(p,'timestamps',@isnumeric)
    parse(p,varargin{:})
    passband = p.Results.passband;
    EMGThresh = p.Results.EMGThresh;
    signal = bz_Filter(double(p.Results.lfp),'filter','butter','passband',passband,'order', 3);
    timestamps = p.Results.timestamps;
    basepath = pwd;
    basename = bz_BasenameFromBasepath(basepath);
end

% assign parameters (either defaults or given)
frequency = p.Results.frequency;
show = p.Results.show;
restrict = p.Results.restrict;
sd = p.Results.stdev;
noise = p.Results.noise;
lowThresholdFactor = p.Results.thresholds(1);
highThresholdFactor = p.Results.thresholds(2);
minInterRippleInterval = p.Results.durations(1);
maxRippleDuration = p.Results.durations(2);
minRippleDuration = p.Results.minDuration;
plotType = p.Results.plotType;

%% filter and calculate noise

% Parameters
windowLength = frequency/frequency*11;

% Square and normalize signal
squaredSignal = signal.^2;

% squaredSignal = abs(opsignal);
window = ones(windowLength,1)/windowLength;
keep = [];
if ~isempty(restrict)
    for i=1:size(restrict,1)
        keep = InIntervals(timestamps,restrict);
    end
end
keep = logical(keep); 
if p.Results.absoluteThresholds
    normalizedSquaredSignal = Filter0(window,sum(squaredSignal,2));
    if ~isempty(keep)
        normalizedSquaredSignal = normalizedSquaredSignal(keep);
    end
    lowThresholdFactor = lowThresholdFactor.^2;
    highThresholdFactor = highThresholdFactor.^2;
    
    [filt_b filt_a] = cheby2(4,50,(passband+diff(passband))/(0.5*session.extracellular.srLfp));
    signal2 = filtfilt(filt_b,filt_a,double(lfp));
    squaredSignal2 = signal2.^2;
    normalizedSquaredSignal2 = Filter0(window,sum(squaredSignal2,2));
    if ~isempty(keep)
        normalizedSquaredSignal2 = normalizedSquaredSignal2(keep);
    end
else
    [normalizedSquaredSignal,sd] = unity(Filter0(window,sum(squaredSignal,2)),sd,keep);
end

% Detect ripple periods by thresholding normalized squared signal
thresholded = normalizedSquaredSignal > lowThresholdFactor;
start = find(diff(thresholded)>0);
stop = find(diff(thresholded)<0);

debug = 0;
if debug
    figure, plot(normalizedSquaredSignal), hold on
    plot([1,numel(normalizedSquaredSignal)],[lowThresholdFactor,lowThresholdFactor],'-r')
    plot([1,numel(normalizedSquaredSignal)],[highThresholdFactor,highThresholdFactor],'-r'),ylim([0,2*10^6])
    
    figure, plot(normalizedSquaredSignal2), hold on
    plot([1,numel(normalizedSquaredSignal2)],[lowThresholdFactor,lowThresholdFactor],'-m')
    plot([1,numel(normalizedSquaredSignal2)],[highThresholdFactor,highThresholdFactor],'-m'),ylim([0,2*10^6])
end
% Exclude last ripple if it is incomplete
if length(stop) == length(start)-1
	start = start(1:end-1);
end
% Exclude first ripple if it is incomplete
if length(stop)-1 == length(start)
    stop = stop(2:end);
end
% Correct special case when both first and last ripples are incomplete
if start(1) > stop(1)
	stop(1) = [];
	start(end) = [];
end
firstPass = [start,stop];
processing_steps.detection = timestamps(round(mean(firstPass,2)));

if isempty(firstPass)
	disp('Detection by thresholding failed');
	return
else
	disp(['After detection by thresholding: ' num2str(length(firstPass)) ' events.']);
end

% Merge ripples if inter-ripple period is too short
minInterRippleSamples = minInterRippleInterval/1000*frequency;
secondPass = [];
ripple = firstPass(1,:);
for i = 2:size(firstPass,1)
	if firstPass(i,1) - ripple(2) < minInterRippleSamples
		% Merge
		ripple = [ripple(1) firstPass(i,2)];
	else
		secondPass = [secondPass ; ripple];
		ripple = firstPass(i,:);
	end
end
secondPass = [secondPass ; ripple];
if isempty(secondPass)
	disp('Ripple merge failed');
	return
else
	disp(['After ripple merge: ' num2str(length(secondPass)) ' events.']);
end
processing_steps.merging = timestamps(round(mean(secondPass,2)));

% Discard ripples with a peak power < highThresholdFactor
thirdPass = [];
peakNormalizedPower = [];
for i = 1:size(secondPass,1)
	[maxValue,maxIndex] = max(normalizedSquaredSignal([secondPass(i,1):secondPass(i,2)]));
	if maxValue > highThresholdFactor
		thirdPass = [thirdPass ; secondPass(i,:)];
		peakNormalizedPower = [peakNormalizedPower ; maxValue];
	end
end
if isempty(thirdPass),
	disp('Peak thresholding failed.');
	return
else
	disp(['After peak thresholding: ' num2str(length(thirdPass)) ' events.']);
end
processing_steps.peakThreshold = timestamps(round(mean(thirdPass,2)));

% Discard ripples with a peak power > highThresholdFactor in the frequency band above ripples
if p.Results.absoluteThresholds
    thirdPass2 = [];
    peakNormalizedPower2 = [];
    for i = 1:size(thirdPass,1)
        [maxValue,maxIndex] = max(normalizedSquaredSignal2([thirdPass(i,1):thirdPass(i,2)]));
        [maxValue2,maxIndex] = max(normalizedSquaredSignal([thirdPass(i,1):thirdPass(i,2)]));
        if maxValue < maxValue2
            thirdPass2 = [thirdPass2 ; thirdPass(i,:)];
            peakNormalizedPower2 = [peakNormalizedPower2 ; maxValue];
        end
    end
    thirdPass = thirdPass2;
    peakNormalizedPower = peakNormalizedPower2;
    if isempty(thirdPass2)
        disp('Peak thresholding2 failed.');
        return
    else
        disp(['After peak thresholding2: ' num2str(length(thirdPass)) ' events.']);
    end
end
processing_steps.peakThreshold2 = timestamps(round(mean(thirdPass,2)));

% Detect negative peak position for each ripple
peakPosition = zeros(size(thirdPass,1),1);
for i=1:size(thirdPass,1)
	[minValue,minIndex] = min(signal(thirdPass(i,1):thirdPass(i,2)));
	peakPosition(i) = minIndex + thirdPass(i,1) - 1;
end

% Discard ripples that are way too long
ripples = [timestamps(thirdPass(:,1)) timestamps(peakPosition) ...
           timestamps(thirdPass(:,2)) peakNormalizedPower];
duration = ripples(:,3)-ripples(:,1);
ripples(duration>maxRippleDuration/1000,:) = NaN;
disp(['Long ripples removed: ' num2str(sum(duration>maxRippleDuration/1000))])
ripples = ripples((all((~isnan(ripples)),2)),:);

%disp(['After duration test: ' num2str(size(ripples,1)) ' events.']);

% Discard ripples that are too short
ripples(duration<minRippleDuration/1000,:) = NaN;
disp(['Short ripples removed: ' num2str(sum(duration<minRippleDuration/1000))])
ripples = ripples((all((~isnan(ripples)),2)),:);

disp(['After duration test: ' num2str(size(ripples,1)) ' events.']);
processing_steps.durationTest = ripples(:,2);
% If a noise channel was provided, find ripple-like events and exclude them
bad = [];
if ~isempty(noise)
    if isstruct(varargin{1}) % CellExplorer
        if length(noise) == 1 % you gave a channel number
            noiselfp = (LoadBinary(fullfile(basepath,[basename, '.lfp']),'nChannels',session.extracellular.nChannels,'channels',noise,'precision','int16','frequency',session.extracellular.srLfp));
            squaredNoise = filtfilt(filt_b,filt_a,double(noiselfp)).^2;
        else
            % Filter, square, and pseudo-normalize (divide by signal stdev) noise
            squaredNoise = filtfilt(filt_b,filt_a,double(noise)).^2;
        end
    else % Buzcode
        if length(noise) == 1 % you gave a channel number
            noiselfp = bz_GetLFP(noise-1,'basepath',basepath,'basename',basename);%currently cannot take path inputs
            squaredNoise = bz_Filter(double(noiselfp.data),'filter','butter','passband',passband,'order', 3).^2;
        else
            % Filter, square, and pseudo-normalize (divide by signal stdev) noise
            squaredNoise = bz_Filter(double(noise),'filter','butter','passband',passband,'order', 3).^2;
        end
    end
    window = ones(windowLength,1)/windowLength;
    
    if p.Results.absoluteThresholds
        normalizedSquaredNoise = Filter0(window,sum(squaredNoise,2));
       
%         [filt_b filt_a] = cheby2(4,50,(passband+diff(passband))/(0.5*session.extracellular.srLfp));
%         signal2 = filtfilt(filt_b,filt_a,double(lfp));
%         squaredSignal2 = signal2.^2;
%         normalizedSquaredSignal2 = Filter0(window,sum(squaredSignal2,2));
%         if ~isempty(keep)
%             normalizedSquaredSignal2 = normalizedSquaredSignal2(keep);
%         end
    else
%         [normalizedSquaredSignal,sd] = unity(Filter0(window,sum(squaredSignal,2)),sd,keep);
        normalizedSquaredNoise = unity(Filter0(window,sum(squaredNoise,2)),sd,[]);
    end
    
    
	
	excluded = logical(zeros(size(ripples,1),1));
	% Exclude ripples when concomittent noise crosses high detection threshold
	previous = 1;
	for i = 1:size(ripples,1)
		j = FindInInterval([timestamps],[ripples(i,1),ripples(i,3)],previous);
		previous = j(2);
		if any(normalizedSquaredNoise(j(1):j(2))>highThresholdFactor)
			excluded(i) = 1;
        end
	end
	bad = ripples(excluded,:);
	ripples = ripples(~excluded,:);
	disp(['After ripple-band noise removal: ' num2str(size(ripples,1)) ' events.']);
end
processing_steps.ripple_band_noise_removal = ripples(:,2);

    %% lets try to also remove EMG artifact?
if EMGThresh
    EMGfilename = fullfile(basepath,[basename '.EMGFromLFP.LFP.mat']);
    if exist(EMGfilename)
        load(EMGfilename)   %should use a bz_load script here
    else
        if isstruct(varargin{1}) % CellExplorer
            [EMGFromLFP] = ce_EMGFromLFP(session,'samplingFrequency',10,'savemat',false,'noPrompts',true);
        else
            [EMGFromLFP] = bz_EMGFromLFP(basepath,'samplingFrequency',10,'savemat',false,'noPrompts',true);
        end
    end
    
    excluded = logical(zeros(size(ripples,1),1));
    for i = 1:size(ripples,1)
       [a ts] = min(abs(ripples(i,1)-EMGFromLFP.timestamps)); % get closest sample
       if EMGFromLFP.data(ts) > EMGThresh
           excluded(i) = 1;
       end
    end
    bad = sortrows([bad; ripples(excluded,:)]);
    ripples = ripples(~excluded,:);
    disp(['After EMG noise removal: ' num2str(size(ripples,1)) ' events.']);
end
processing_steps.EMG_noise_removal = ripples(:,2);

% Optionally, plot results
if strcmp(show,'on')
  if plotType == 1
	figure;
	if ~isempty(noise)
		MultiPlotXY([timestamps signal],[timestamps squaredSignal],...
            [timestamps normalizedSquaredSignal],[timestamps squaredNoise],...
            [timestamps squaredNoise],[timestamps normalizedSquaredNoise]);
		nPlots = 6;
		subplot(nPlots,1,3);
 		ylim([0 highThresholdFactor*1.1]);
		subplot(nPlots,1,6);
  		ylim([0 highThresholdFactor*1.1]);
	else
		MultiPlotXY([timestamps signal],[timestamps squaredSignal],[timestamps normalizedSquaredSignal]);
%  		MultiPlotXY(time,signal,time,squaredSignal,time,normalizedSquaredSignal);
		nPlots = 3;
		subplot(nPlots,1,3);
  		ylim([0 highThresholdFactor*1.1]);
	end
	for i = 1:nPlots
		subplot(nPlots,1,i);
		hold on;
  		yLim = ylim;
		for j=1:size(ripples,1)
			plot([ripples(j,1) ripples(j,1)],yLim,'g-');
			plot([ripples(j,2) ripples(j,2)],yLim,'k-');
			plot([ripples(j,3) ripples(j,3)],yLim,'r-');
			if i == 3
				plot([ripples(j,1) ripples(j,3)],[ripples(j,4) ripples(j,4)],'k-');
			end
		end
		for j=1:size(bad,1)
			plot([bad(j,1) bad(j,1)],yLim,'k-');
			plot([bad(j,2) bad(j,2)],yLim,'k-');
			plot([bad(j,3) bad(j,3)],yLim,'k-');
			if i == 3
				plot([bad(j,1) bad(j,3)],[bad(j,4) bad(j,4)],'k-');
			end
		end
		if mod(i,3) == 0
			plot(xlim,[lowThresholdFactor lowThresholdFactor],'k','linestyle','--');
			plot(xlim,[highThresholdFactor highThresholdFactor],'k-');
		end
    end
  elseif plotType == 2
      if isstruct(varargin{1})
        [filt_b filt_a] = butter(3,[50 300]/(0.5*session.extracellular.srLfp),'bandpass');
        lfpPlot = filtfilt(filt_b,filt_a,lfp);
      else
          lfpPlot = bz_Filter(double(lfp.data),'filter','butter','passband',[50 300],'order', 3);
      end
      plot(timestamps,lfpPlot);hold on;
      yLim = ylim;
		for j=1:size(ripples,1)
			plot([ripples(j,1) ripples(j,1)],yLim,'g-');
			plot([ripples(j,2) ripples(j,2)],yLim,'k-');
			plot([ripples(j,3) ripples(j,3)],yLim,'r-');
			if i == 3
				plot([ripples(j,1) ripples(j,3)],[ripples(j,4) ripples(j,4)],'k-');
			end
		end
		for j=1:size(bad,1)
			plot([bad(j,1) bad(j,1)],yLim,'k-');
			plot([bad(j,2) bad(j,2)],yLim,'k-');
			plot([bad(j,3) bad(j,3)],yLim,'k-');
			if i == 3
				plot([bad(j,1) bad(j,3)],[bad(j,4) bad(j,4)],'k-');
			end
		end
		if mod(i,3) == 0
			plot(xlim,[lowThresholdFactor lowThresholdFactor],'k','linestyle','--');
			plot(xlim,[highThresholdFactor highThresholdFactor],'k-');
		end  
  end
end


%% BUZCODE Struct Output
processing_steps.final = ripples(:,2);
rips = ripples; clear ripples

ripples.timestamps = rips(:,[1 3]);
ripples.peaks = rips(:,2);            %peaktimes? could also do these as timestamps and then ripples.ints for start/stops?
ripples.peakNormedPower = rips(:,4);  %amplitudes?
ripples.stdev = sd;
ripples.processing_steps = processing_steps;
if ~isempty(bad)
    ripples.noise.times = bad(:,[1 3]);
    ripples.noise.peaks = bad(:,[2]);
    ripples.noise.peakNormedPower = bad(:,[4]);
else
    ripples.noise.times = [];
    ripples.noise.peaks = [];
    ripples.noise.peakNormedPower = [];
end

%The detectorinto substructure
detectorinfo.detectorname = 'ce_FindRipples';
detectorinfo.detectiondate = now;
detectorinfo.detectionintervals = restrict;
detectorinfo.detectionparms = p.Results;
detectorinfo.detectionparms = rmfield(detectorinfo.detectionparms,'noise');
if isfield(detectorinfo.detectionparms,'timestamps')  
    detectorinfo.detectionparms = rmfield(detectorinfo.detectionparms,'timestamps');
end
if isfield(p.Results,'channel')
    detectorinfo.detectionchannel = p.Results.channel-1;
    detectorinfo.detectionchannel1 = p.Results.channel;
end
if isstruct(varargin{1})
    detectorinfo.detectionchannel = session.channelTags.Ripple.channels(1)-1;
    detectorinfo.detectionchannel1 = session.channelTags.Ripple.channels(1);
end
if ~isempty(noise)
    detectorinfo.noisechannel = noise-1;
    detectorinfo.noisechannel1 = noise;
else
    detectorinfo.noisechannel = nan;
end


%Put it into the ripples structure
ripples.detectorinfo = detectorinfo;

%Save
if p.Results.saveMat
    save(fullfile(basepath, [basename '.ripples.events.mat']),'ripples')
end


function y = Filter0(b,x)

if size(x,1) == 1
	x = x(:);
end

if mod(length(b),2)~=1
	error('filter order should be odd');
end

shift = (length(b)-1)/2;

[y0 z] = filter(b,1,x);

y = [y0(shift+1:end,:) ; z(1:shift,:)];

function [U,stdA] = unity(A,sd,restrict)

if ~isempty(restrict)
	meanA = mean(A(restrict));
	stdA = std(A(restrict));
else
	meanA = mean(A);
	stdA = std(A);
end
if ~isempty(sd)
	stdA = sd;
end

U = (A - meanA)/stdA;


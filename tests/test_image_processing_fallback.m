function tests = test_image_processing_fallback
tests = functiontests(localfunctions);
end

function testMedianPaddingAndBlockBoundary(testCase)
% The top row sees a 2-by-10 neighborhood. The bottom row sees one row
% of data and one row of zeros. An even median averages the middle values.
input = [ones(1, 12); 3 * ones(1, 12)];
expected = [1 1 1 1 2 2 2 1 1 1 1 0.5;
            0 0 0 0 1.5 1.5 1.5 0 0 0 0 0];
verifyEqual(testCase, ce_theta_median_filter(input, false), expected);

input = reshape(mod(1:3117, 37), 3, []);
verifyEqual(testCase, ce_theta_median_filter(input, false), referenceMedian(input));
verifyEqual(testCase, ce_theta_median_filter(7, false), 0);
end

function testThetaOnSyntheticLfp(testCase)
[session, samples, cleanup] = syntheticLfp(); %#ok<ASGLU>
result = calcInstantaneousTheta2(session, 'saveMat', false);
[magnitude, frequencies, times] = thetaSpectrogram(samples, session.extracellular.srLfp);
verifyThetaSpectrogram(testCase, result, referenceMedian(magnitude), frequencies, times);
end

function testMedianToolboxParity(testCase)
requireToolbox(testCase, 'medfilt2');
input = reshape(abs(sin((1:7434)/7) + cos((1:7434)/19)), 7, []);
for magnitude = {input, input(1, :), input(:, 1), input(1:2, 1:3)}
    expected = medfilt2(magnitude{1}, [2 10]);
    verifyEqual(testCase, ce_theta_median_filter(magnitude{1}, false), expected, 'AbsTol', 1e-14);
end

[session, samples, cleanup] = syntheticLfp(); %#ok<ASGLU>
[magnitude, frequencies, times] = thetaSpectrogram(samples, session.extracellular.srLfp);
verifyEqual(testCase, ce_theta_median_filter(magnitude, false), medfilt2(magnitude, [2 10]), 'AbsTol', 1e-12);
result = calcInstantaneousTheta2(session, 'saveMat', false);
verifyThetaSpectrogram(testCase, result, ce_theta_median_filter(magnitude, false), frequencies, times);
end

function testRectangleDragGeometry(testCase)
position = [2 3 6 8];
verifyEqual(testCase, ce_probe_rectangle_drag(position, [4 -2], [0 0]), [6 1 6 8]);
verifyEqual(testCase, ce_probe_rectangle_drag(position, [-2 4], [-1 1]), [0 3 8 12]);
verifyEqual(testCase, ce_probe_rectangle_drag(position, [3 4], [0 -1]), [2 7 6 4]);
verifyEqual(testCase, ce_probe_rectangle_drag(position, [7 -9], [-1 1]), [8 2 1 1]);
end

function testRectangleFallbackGraphic(testCase)
[fig, ax] = invisibleAxes();
cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
position = [2 3 6 8];
setPosition = ce_probe_rectangle(ax, position, @(~) [], false);
group = findobj(ax, 'Tag', 'ProbeSelectionRectangleFallback');
body = findobj(group, 'Type', 'patch');
verifyNumElements(testCase, findobj(group, 'Type', 'line'), 8);
verifyEqual(testCase, body.XData(:)', [2 8 8 2]);
verifyEqual(testCase, body.YData(:)', [3 3 11 11]);
setPosition(ce_probe_rectangle_drag(position, [7 -9], [-1 1]));
verifyEqual(testCase, body.XData(:)', [8 9 9 8]);
verifyEqual(testCase, body.YData(:)', [2 2 3 3]);
setPosition(position);
verifyEqual(testCase, body.XData(:)', [2 8 8 2]);
verifyEqual(testCase, body.YData(:)', [3 3 11 11]);
end

function testRectangleToolboxParity(testCase)
requireToolbox(testCase, 'drawrectangle');
[fig, ax] = invisibleAxes();
cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
xlim(ax, [-10 20]);
ylim(ax, [-10 20]);
position = [2 3 6 8];
setFallback = ce_probe_rectangle(ax, position, @(~) [], false);
setNative = ce_probe_rectangle(ax, position, @(~) [], true);
group = findobj(ax, 'Tag', 'ProbeSelectionRectangleFallback');
body = findobj(group, 'Type', 'patch');
native = findall(ax, 'Tag', 'ProbeSelectionRectangleNative');
verifyNumElements(testCase, native, 1);
[x, y] = meshgrid(-2:14);
x = x(:);
y = y(:);
positions = {position, ce_probe_rectangle_drag(position, [2 -3], [0 0]), ...
    ce_probe_rectangle_drag(position, [2 -3], [-1 1]), position};
for k = 1:numel(positions)
    setFallback(positions{k});
    setNative(positions{k});
    verifyEqual(testCase, inpolygon(x, y, body.XData, body.YData), inROI(native, x, y));
end
end

function testCirclesFallbackGeometry(testCase)
[fig, ax] = invisibleAxes();
cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
centers = [2 3 7; 9 11 -1];
radii = [2 4];
circles = ce_plot_trilateration_circles(ax, centers, radii);
verifyNumElements(testCase, circles, 2);
for k = 1:2
    distance = hypot(circles(k).XData - centers(k, 1), circles(k).YData - centers(k, 2));
    verifyEqual(testCase, distance, radii(k) * ones(size(distance)), 'AbsTol', 1e-12);
    verifyEqual(testCase, circles(k).ZData, centers(k, 3) * ones(size(distance)));
end
end

function testCirclesToolboxParity(testCase)
requireToolbox(testCase, 'viscircles');
[fig, ax] = invisibleAxes();
cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
center = [2 3];
radius = 4;
native = viscircles(ax, center, radius, 'EnhanceVisibility', false);
fallback = ce_plot_trilateration_circles(ax, center, radius);
outline = findobj(native, 'Type', 'line');
verifyNumElements(testCase, outline, 1);
verifyEqual(testCase, bounds2D(fallback), bounds2D(outline), 'AbsTol', 0.01);
end

function testCorrelationFallback(testCase)
a = [0 1; 2 3];
b = [0 1; 1 0];
target = cat(3, a, a, a, a, ones(2));
interferer = cat(3, a, -a, b, [0 1; 2 2], a);
actual = iosr.bss.mixture.mixWdo(target, interferer);
verifyEqual(testCase, actual(1:4), [1 -1 0 3.5/sqrt(13.75)], 'AbsTol', 1e-14);
verifyTrue(testCase, isnan(actual(5)));
end

function testCorrelationToolboxParity(testCase)
requireToolbox(testCase, 'corr2');
target = reshape(uint8(mod((1:120)*13, 255)), 4, 5, []);
interferer = flip(target, 2);
actual = iosr.bss.mixture.mixWdo(target, interferer);
for channel = 1:size(target, 3)
    verifyEqual(testCase, actual(channel), corr2(target(:, :, channel), interferer(:, :, channel)), 'AbsTol', 1e-14);
end
end

function testResizeFallback(testCase)
input = repmat(reshape(uint8([18 99 232]), 1, 1, []), 7, 9);
actual = ce_resize_image(input, 0.4, false);
verifyEqual(testCase, actual, input(1:3, 1:4, :));
% Cubic interpolation of two pixels with symmetric edge padding.
expected = repmat([-6 13 51 70] / 64, 2, 1);
verifyEqual(testCase, ce_resize_image([0 1], 2, false), expected, 'AbsTol', 1e-14);
end

function testResizeToolboxParity(testCase)
requireToolbox(testCase, 'imresize');
imageData = reshape(sin((1:429)/10), 11, 13, 3);
for scale = [0.15 0.45 1.7 2]
    expected = imresize(imageData, scale);
    verifyEqual(testCase, ce_resize_image(imageData, scale, false), expected, 'AbsTol', 1e-12);
    rgb = uint8(128 + 56 * imageData);
    actual = ce_resize_image(rgb, scale, false);
    verifyEqual(testCase, class(actual), 'uint8');
    verifyEqual(testCase, double(actual), double(imresize(rgb, scale)), 'AbsTol', 1);
end
end

function filtered = referenceMedian(input)
[nRows, nCols] = size(input);
filtered = zeros(size(input));
for column = 1:nCols
    sourceColumns = max(1, column-4):min(nCols, column+5);
    for row = 1:nRows
        available = input(row:min(nRows, row+1), sourceColumns);
        filtered(row, column) = median([available(:); zeros(20-numel(available), 1)]);
    end
end
end

function [session, samples, cleanup] = syntheticLfp()
basePath = tempname;
mkdir(basePath);
cleanup = onCleanup(@() rmdir(basePath, 's'));
sr = 250;
t = (0:8*sr-1)' / sr;
samples = int16(1350 * cos(2*pi*(7*t+0.08*t.^2)) + 250 * sin(2*pi*10*t));
file = fopen(fullfile(basePath, 'synthetic.lfp'), 'w');
assert(file ~= -1, 'Could not open the synthetic LFP fixture.');
fwrite(file, samples, 'int16');
fclose(file);
session.general = struct('name', 'synthetic', 'basePath', basePath);
session.extracellular = struct('srLfp', sr, 'leastSignificantBit', 1, 'nChannels', 1);
session.channelTags.Theta.channels = 1;
end

function [magnitude, frequencies, times] = thetaSpectrogram(samples, sr)
frequencies = 4:0.1:11;
[b, a] = butter(3, [4 11] / (sr/2));
signal = filtfilt(b, a, double(samples))';
[spectra, ~, times] = spectrogram(signal, sr, sr/5, frequencies, sr);
magnitude = abs(spectra);
end

function verifyThetaSpectrogram(testCase, result, filtered, frequencies, times)
smoothed = filter2(ones(10)/100, filtered);
[power, peaks] = max(smoothed, [], 1);
verifyEqual(testCase, result.signal_power{1}, power, 'RelTol', 1e-12);
verifyEqual(testCase, result.signal_freq{1}, frequencies(peaks));
verifyEqual(testCase, result.signal_time, times);
end

function [fig, ax] = invisibleAxes()
fig = figure('Visible', 'off');
ax = axes('Parent', fig);
end

function bounds = bounds2D(outline)
bounds = [min(outline.XData) max(outline.XData) min(outline.YData) max(outline.YData)];
end

function requireToolbox(testCase, functionName)
assumeTrue(testCase, ce_image_toolbox_available(functionName), ...
    ['Image Processing Toolbox required to compare with ' functionName '.']);
end

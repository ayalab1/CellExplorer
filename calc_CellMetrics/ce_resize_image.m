function resized = ce_resize_image(imageData, scale, useToolbox)
% Resize a grayscale or truecolor image with antialiased bicubic interpolation.
if nargin < 3
    useToolbox = ce_image_toolbox_available('imresize');
end
if useToolbox
    resized = imresize(imageData, scale);
    return
end
if scale == 1
    resized = imageData;
    return
end

% Bicubic interpolation is separable. Reflect the input at each edge and
% widen the kernel when shrinking to avoid aliasing.
resized = resizeRows(double(imageData), scale);
resized = permute(resizeRows(permute(resized, [2 1 3]), scale), [2 1 3]);
if islogical(imageData)
    resized = resized >= 0.5;
else
    resized = cast(resized, 'like', imageData);
end
end

function output = resizeRows(input, scale)
[nRows, nColumns, nChannels] = size(input);
nOutput = ceil(nRows * scale);
antialiasScale = min(scale, 1);
supportRadius = 2 / antialiasScale;
nTaps = ceil(2 * supportRadius) + 1;
output = zeros(nOutput, nColumns, nChannels);
for row = 1:nOutput
    center = (row - 0.5) / scale + 0.5;
    sourceRows = floor(center - supportRadius) + (0:nTaps-1);
    distance = abs(center - sourceRows) * antialiasScale;
    weights = zeros(size(distance));
    inner = distance <= 1;
    outer = distance > 1 & distance < 2;
    weights(inner) = ((1.5 * distance(inner) - 2.5) .* distance(inner).^2) + 1;
    weights(outer) = ((-0.5 * distance(outer) + 2.5) .* distance(outer) - 4) .* distance(outer) + 2;
    weights = weights / sum(weights);
    active = weights ~= 0;
    wrapped = mod(sourceRows(active) - 1, 2 * nRows);
    mirrored = 1 + min(wrapped, 2 * nRows - 1 - wrapped);
    output(row, :, :) = sum(input(mirrored, :, :) .* weights(active)', 1);
end
end

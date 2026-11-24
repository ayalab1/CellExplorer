function filtered = ce_theta_median_filter(spectrogramMagnitude, useToolbox)
% Apply the theta spectrogram's zero-padded 2-by-10 median filter.
if nargin < 2
    useToolbox = ce_image_toolbox_available('medfilt2');
end
if useToolbox
    filtered = medfilt2(spectrogramMagnitude, [2 10]);
    return
end

[nRows, nColumns] = size(spectrogramMagnitude);
% The even window starts on the current row and four columns to its left.
padded = zeros(nRows + 1, nColumns + 9, 'like', spectrogramMagnitude);
padded(1:nRows, 5:4+nColumns) = spectrogramMagnitude;
filtered = zeros(size(spectrogramMagnitude), 'like', spectrogramMagnitude);

% Bound the temporary window storage for long recordings.
blockWidth = 1024;
for firstColumn = 1:blockWidth:nColumns
    columns = firstColumn:min(firstColumn + blockWidth - 1, nColumns);
    windows = zeros(20, nRows * numel(columns), 'like', spectrogramMagnitude);
    for offset = 0:9
        top = padded(1:nRows, columns + offset);
        bottom = padded(2:nRows+1, columns + offset);
        windows(2*offset+1, :) = top(:);
        windows(2*offset+2, :) = bottom(:);
    end
    windows = sort(windows, 1);
    middle = (windows(10, :) + windows(11, :)) / 2;
    filtered(:, columns) = reshape(middle, nRows, []);
end
end

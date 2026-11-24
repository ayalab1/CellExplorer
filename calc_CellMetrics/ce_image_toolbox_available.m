function available = ce_image_toolbox_available(functionName)
% Check that the requested Image Processing Toolbox function can be used.
available = false;
if exist(functionName, 'file') ~= 0
    % Request the diagnostic as an output so an unavailable seat is silent.
    [available, ~] = license('checkout', 'image_toolbox');
    available = logical(available);
end
end

function available = ce_image_toolbox_available(functionName)
% Check that the requested Image Processing Toolbox function can be used.
available = exist(functionName, 'file') ~= 0 && license('checkout', 'image_toolbox');
end

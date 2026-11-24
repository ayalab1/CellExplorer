function channels = ce_probe_channels_in_rectangle(x, y, position)
% Return electrode indices inside or on the boundary of the selection.
xCorners = position(1) + position(3) * [0 1 1 0];
yCorners = position(2) + position(4) * [0 0 1 1];
channels = find(inpolygon(x, y, xCorners, yCorners));
end

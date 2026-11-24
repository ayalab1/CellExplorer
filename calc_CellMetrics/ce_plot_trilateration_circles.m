function circles = ce_plot_trilateration_circles(ax, centers, radii)
% Draw range circles in the XY plane of each electrode.
theta = linspace(0, 2*pi, 181)';
x = cos(theta) * radii(:)' + centers(:, 1)';
y = sin(theta) * radii(:)' + centers(:, 2)';
if size(centers, 2) == 3
    z = repmat(centers(:, 3)', numel(theta), 1);
    circles = line(ax, x, y, z, 'Color', [0.35 0.35 0.35]);
else
    circles = line(ax, x, y, 'Color', [0.35 0.35 0.35]);
end
end

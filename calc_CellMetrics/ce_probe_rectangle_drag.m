function position = ce_probe_rectangle_drag(startPosition, delta, direction)
% Move the whole rectangle or resize it around the opposite edge or corner.
if all(direction == 0)
    position = [startPosition(1:2) + delta, startPosition(3:4)];
    return
end

lower = startPosition(1:2) + delta .* (direction < 0);
upper = startPosition(1:2) + startPosition(3:4) + delta .* (direction > 0);
position = [min(lower, upper), abs(upper - lower)];
end

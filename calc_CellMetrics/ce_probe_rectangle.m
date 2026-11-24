function setPosition = ce_probe_rectangle(ax, position, onMoved, useToolbox)
% Create a movable, resizable probe-layout selection rectangle.
if nargin < 4
    useToolbox = ~verLessThan('matlab', '9.5') && ce_image_toolbox_available('drawrectangle');
end
if useToolbox
    roi = drawrectangle(ax, 'Position', position, 'LineWidth', 2, ...
        'FaceAlpha', 0.1, 'Deletable', false, 'FixedAspectRatio', false, ...
        'Tag', 'ProbeSelectionRectangleNative');
    addlistener(roi, 'ROIMoved', @(source, ~) onMoved(source.Position));
    setPosition = @(newPosition) set(roi, 'Position', newPosition);
    return
end

fig = ancestor(ax, 'figure');
group = hggroup('Parent', ax, 'Tag', 'ProbeSelectionRectangleFallback');
color = [0 0.45 0.74];
body = patch('Parent', group, 'XData', nan(1, 4), 'YData', nan(1, 4), ...
    'FaceColor', color, 'FaceAlpha', 0.1, 'EdgeColor', color, 'LineWidth', 2, ...
    'ButtonDownFcn', @(~, ~) startDrag([0 0]));

% A handle's direction specifies the edge(s) it moves along each axis.
directions = [-1 -1; 0 -1; 1 -1; 1 0; 1 1; 0 1; -1 1; -1 0];
handles = gobjects(size(directions, 1), 1);
for k = 1:size(directions, 1)
    direction = directions(k, :);
    handles(k) = line('Parent', group, 'XData', nan, 'YData', nan, ...
        'LineStyle', 'none', 'Marker', 's', 'MarkerSize', 5, ...
        'MarkerFaceColor', color, 'Color', color, ...
        'ButtonDownFcn', @(~, ~) startDrag(direction));
end
dragging = false;
startPoint = [];
startPosition = [];
dragDirection = [];
previousMotion = [];
previousUp = [];
group.DeleteFcn = @(~, ~) stopDrag();
setPosition = @updatePosition;
updatePosition(position);

    function updatePosition(newPosition)
        position = newPosition;
        x = position(1) + position(3) * [0 1 1 0];
        y = position(2) + position(4) * [0 0 1 1];
        set(body, 'XData', x, 'YData', y);
        for index = 1:numel(handles)
            point = position(1:2) + position(3:4) .* (directions(index, :) + 1) / 2;
            set(handles(index), 'XData', point(1), 'YData', point(2));
        end
    end

    function startDrag(direction)
        if dragging || ~strcmp(fig.SelectionType, 'normal')
            return
        end
        point = ax.CurrentPoint;
        startPoint = point(1, 1:2);
        startPosition = position;
        dragDirection = direction;
        previousMotion = fig.WindowButtonMotionFcn;
        previousUp = fig.WindowButtonUpFcn;
        dragging = true;
        fig.WindowButtonMotionFcn = @drag;
        fig.WindowButtonUpFcn = @finishDrag;
    end

    function drag(~, ~)
        point = ax.CurrentPoint;
        updatePosition(ce_probe_rectangle_drag(startPosition, point(1, 1:2) - startPoint, dragDirection));
    end

    function finishDrag(~, ~)
        stopDrag();
        if ~isequal(position, startPosition)
            onMoved(position);
        end
    end

    function stopDrag()
        if dragging && isgraphics(fig) && strcmp(fig.BeingDeleted, 'off')
            fig.WindowButtonMotionFcn = previousMotion;
            fig.WindowButtonUpFcn = previousUp;
        end
        dragging = false;
    end
end

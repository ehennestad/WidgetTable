function colIdx = getGridColumnIndexForPoint(uigrid, xCoord)
    % Function to find the column index of a given x-coordinate in a uigridlayout.
    % Inputs:
    %   uigrid - Handle to the uigridlayout object
    %   xCoord - The x-coordinate to check
    % Outputs:
    %   colIdx - The index of the column containing the x-coordinate

    % Get the position of the uigridlayout (x, y, width, height)
    %gridPos = uigrid.Position;
    gridPos = getpixelposition(uigrid, true);
    % Extract the grid layout columns and column spacing
    columnWidths = uigrid.ColumnWidth;
    columnSpacing = uigrid.ColumnSpacing;
    gridPaddingX = sum(uigrid.Padding([1,3]));

    % Initialize variables
    totalWidth = 0;
    colIdx = -1; % Default value if xCoord is outside the grid

    % Calculate the total proportional units
    flexUnits = 0;
    fixedWidthTotal = 0;
    for i = 1:length(columnWidths)
        if ischar(columnWidths{i}) && endsWith(columnWidths{i}, 'x')
            flexUnits = flexUnits + str2double(extractBefore(columnWidths{i}, 'x'));
        else
            fixedWidthTotal = fixedWidthTotal + columnWidths{i};
        end
    end

    % Calculate the width of one flex unit
    remainingWidth = gridPos(3) - fixedWidthTotal - columnSpacing * (length(columnWidths) - 1) - gridPaddingX;
    flexUnitWidth = remainingWidth / flexUnits;

    % Loop through each column to find where the x-coordinate lies
    for i = 1:length(columnWidths)
        if ischar(columnWidths{i}) && endsWith(columnWidths{i}, 'x')
            % Calculate the width for flex columns
            currentWidth = str2double(extractBefore(columnWidths{i}, 'x')) * flexUnitWidth;
        else
            % For fixed widths, convert from string to number
            currentWidth = columnWidths{i};
        end

        % Update the total width traversed, including spacing
        totalWidth = totalWidth + currentWidth;
        if i < length(columnWidths)
            totalWidth = totalWidth + columnSpacing;
        end

        % Check if the x-coordinate falls within this column
        if xCoord <= totalWidth + gridPos(1) + uigrid.Padding(1)
            colIdx = i;
            break;
        end
    end

    % If xCoord is greater than the total width of all columns, colIdx remains -1
end

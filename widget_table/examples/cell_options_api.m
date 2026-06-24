function cell_options_api
% cell_options_api - Minimal example of per-cell dropdown options.

    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(fullfile(repoRoot, 'widget_table'))

    data = table( ...
        categorical(["Fruit"; "Animal"], ["Fruit", "Animal"]), ...
        categorical(["Apple"; "Cat"], ["Apple", "Banana", "Cat", "Dog"]), ...
        [1; 2], ...
        'VariableNames', {'Kind', 'Choice', 'Amount'});

    fig = uifigure( ...
        'Name', 'WidgetTable Cell Options API', ...
        'Position', [100, 100, 420, 180]);

    layout = uigridlayout(fig, [1, 1]);
    layout.Padding = 16;

    widgetTable = WidgetTable(layout, ShowColumnHeaderHelp="off");
    widgetTable.ColumnWidth = {120, 140, 80};
    widgetTable.Data = data;
    widgetTable.CellEditedFcn = @onCellEdited;

    applyChoiceOptions(widgetTable, 1)
    applyChoiceOptions(widgetTable, 2)

    function onCellEdited(src, evt)
        if evt.Indices(2) == 1
            applyChoiceOptions(src, evt.Indices(1))
        end
    end

    function applyChoiceOptions(src, rowIndex)
        switch string(src.Data.Kind(rowIndex))
            case "Fruit"
                items = ["Apple", "Banana"];
            case "Animal"
                items = ["Cat", "Dog"];
        end

        currentChoice = string(src.Data.Choice(rowIndex));
        if any(currentChoice == items)
            value = currentChoice;
        else
            value = items(1);
        end

        src.setCellOptions(rowIndex, 2, items, value)
    end
end

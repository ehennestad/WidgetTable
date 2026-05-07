classdef WidgetTableCellOptionsTest < matlab.unittest.TestCase
    properties
        Figure
    end

    methods (TestMethodSetup)
        function createFigure(testCase)
            repoRoot = fileparts(fileparts(mfilename('fullpath')));
            widgetTablePath = fullfile(repoRoot, 'widget_table');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(widgetTablePath));

            testCase.Figure = uifigure('Visible', 'off');
            testCase.addTeardown(@delete, testCase.Figure)
        end
    end

    methods (Test)
        function setCellOptionsUpdatesOnlyOneDropdown(testCase)
            comp = testCase.createWidgetTable();

            rowOneDropdown = comp.getCellComponent(1, 2);
            rowTwoDropdown = comp.getCellComponent(2, 2);
            rowTwoItems = testCase.asRowString(rowTwoDropdown.Items);

            comp.setCellOptions(1, 2, ["Apple", "Banana"])

            testCase.verifyEqual(testCase.asRowString(rowOneDropdown.Items), ["Apple", "Banana"])
            testCase.verifyEqual(testCase.asRowString(rowTwoDropdown.Items), rowTwoItems)
        end

        function setCellOptionsWithValueUpdatesDataWithoutCallback(testCase)
            comp = testCase.createWidgetTable();
            rowOneDropdown = comp.getCellComponent(1, 2);

            setappdata(testCase.Figure, 'CellEditedFcnFired', false)
            comp.CellEditedFcn = @(~, ~) setappdata(testCase.Figure, 'CellEditedFcnFired', true);

            comp.setCellOptions(1, 2, ["Apple", "Banana"], "Banana")

            testCase.verifyEqual(string(comp.Data.Choice(1)), "Banana")
            testCase.verifyFalse(getappdata(testCase.Figure, 'CellEditedFcnFired'))
            testCase.verifyEqual(testCase.asRowString(rowOneDropdown.Items), ["Apple", "Banana"])
        end

        function setCellOptionsMirrorsClampedDropdownValue(testCase)
            comp = testCase.createWidgetTable();
            rowTwoDropdown = comp.getCellComponent(2, 2);

            comp.setCellOptions(2, 2, "Dog")

            testCase.verifyEqual(string(rowTwoDropdown.Value), "Dog")
            testCase.verifyEqual(string(comp.Data.Choice(2)), "Dog")
            testCase.verifyEqual(testCase.asRowString(rowTwoDropdown.Items), "Dog")
        end

        function setCellOptionsErrorsForNonDropdownCell(testCase)
            comp = testCase.createWidgetTable();

            testCase.verifyError( ...
                @() comp.setCellOptions(1, 3, ["Small", "Large"]), ...
                'WidgetTable:CellNotDropDown')
        end

        function setCellOptionsErrorsForInvalidCellIndex(testCase)
            comp = testCase.createWidgetTable();

            testCase.verifyError( ...
                @() comp.setCellOptions(0, 2, ["Apple", "Banana"]), ...
                'WidgetTable:InvalidCellIndex')
            testCase.verifyError( ...
                @() comp.setCellOptions(3, 2, ["Apple", "Banana"]), ...
                'WidgetTable:InvalidCellIndex')
            testCase.verifyError( ...
                @() comp.setCellOptions(1, 0, ["Apple", "Banana"]), ...
                'WidgetTable:InvalidCellIndex')
            testCase.verifyError( ...
                @() comp.setCellOptions(1, 4, ["Apple", "Banana"]), ...
                'WidgetTable:InvalidCellIndex')
        end

        function getCellComponentReturnsRenderedControl(testCase)
            comp = testCase.createWidgetTable();

            testCase.verifyClass( ...
                comp.getCellComponent(1, 2), ...
                'matlab.ui.control.DropDown')
            testCase.verifyClass( ...
                comp.getCellComponent(1, 3), ...
                'matlab.ui.control.NumericEditField')
        end

        function setCellOptionsErrorsForInvalidItems(testCase)
            comp = testCase.createWidgetTable();

            testCase.verifyError( ...
                @() comp.setCellOptions(1, 2, 42), ...
                'WidgetTable:InvalidCellOptions')
        end
    end

    methods (Access = private)
        function comp = createWidgetTable(testCase)
            layout = uigridlayout(testCase.Figure, [1, 1]);
            data = table( ...
                categorical(["Fruit"; "Animal"], ["Fruit", "Animal"]), ...
                categorical(["Apple"; "Cat"], ["Apple", "Banana", "Cat", "Dog"]), ...
                [1; 2], ...
                'VariableNames', {'Kind', 'Choice', 'Amount'});

            comp = WidgetTable(layout, ShowColumnHeaderHelp="off");
            comp.Data = data;
            drawnow
        end

        function values = asRowString(~, values)
            values = string(values);
            values = values(:)';
        end
    end
end

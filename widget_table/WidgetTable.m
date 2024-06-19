classdef WidgetTable < matlab.ui.componentcontainer.ComponentContainer

    % Properties that correspond to underlying components
    properties (Access = private, Transient, NonCopyable)
        ComponentGridLayout  matlab.ui.container.GridLayout
        TablePanel           matlab.ui.container.Panel
        TableGridLayout      matlab.ui.container.GridLayout
        TableHeaderPanel     matlab.ui.container.Panel
        HeaderGridLayout     matlab.ui.container.GridLayout
        HeaderSeparator      matlab.ui.container.Panel
        TableRowPanel        matlab.ui.container.Panel
        TableRowGridLayout   matlab.ui.container.GridLayout
    end

    properties (Access = private)
        HeaderColumnGridLayout (1,:) matlab.ui.container.GridLayout
        HeaderColumnTitle (1,:) matlab.ui.control.Label
    end
    
    properties (Access = public)
        ColumnNames (1,:) cell
    end
    
    % Todo: Make Layout and Theme classes for fine-grained control of
    % sizing and colors

    properties (Dependent)
        Data
        Height % Height of table (does not include "internal" columns)
        Width  % Width of table (does not include "internal" columns)
    end

    properties % Public table configuration properties
        EnableAddRows matlab.lang.OnOffSwitchState = "on" % todo

        RowHeight (1,1) double = 23
        RowSpacing (1,1) double = 15
                
        ColumnWidget (1,:) cell
        ColumnWidth = {}
        MinimumColumnWidth (1,:) double = 30 % Width in pixels. Scalar value or array with one element per column
        MaximumColumnWidth (1,:) double = 300 % Width in pixels. Scalar value or array with one element per column
        
        ColumnSpacing = 20
        ColumnGridWidth = 1 % Currently only for header.

        FontName = 'Segoe UI'
        CellEditedFcn
    end

    properties % Theme/color properties
        RowFocusColor = "#e9edf4"
        HeaderForegroundColor = "w"
        HeaderBackgroundColor = "#303E4C"
    end
    
    properties (Dependent)
        TableBorderType = "line"
    end

    properties (Dependent, Access = private)
        NumRows
        NumColumns
        TotalColumnExtent
        HasFlexColumns logical
        FixedWidthColumnExtent
    end

    properties (Access = private)
        Data_
    end

    properties (SetAccess = private)
        ActualColumnWidth (1,:) double
    end

    properties (Access = private)
        % Padding of table (inside panel)
        TablePadding = [7,0,20,0]

        % Margins of component (outside panel)
        Margin = [0,0,0,0]

        HeaderPadding = [0, 4, 0, 7]
    end

    properties (Access = private) % Todos
        ShowColumnHeaderHelp matlab.lang.OnOffSwitchState = "off" % todo
    end

    properties (Access = private) % Internal UI Components
        ColumnTitles (1,:) string
        RowComponents (:,:) cell
        RowGridLayout (1,:) matlab.ui.container.GridLayout
        AddRowButton matlab.ui.control.Button
        AddRowButtonGrid matlab.ui.container.GridLayout
        ViewportChangedListener
        SizeChangedListener
        MouseMotionListener
        HeaderColumnImage (1,:) matlab.ui.control.Image
    end

    properties (Access = private)
        TouchedComponents (1,:) matlab.ui.componentcontainer.ComponentContainer
    end

    properties (Access = private) % Internal layout values
        % Stores the column width for all columns, where internal columns are
        % included (i.e column with buttons for adding/removing rows).
        InternalColumnWidth

        % Stores the adjusted width for each column. This includes corrections
        % for columns that are smaller than the minimum column widths.
        % Todo: Also add maximum column widths and adjust for these as well.
        AdjustedColumnWidth
        
        % Cached pixelposition for the TableRowGrid property. This value is
        % used frequently on mouse-over and is therefore cached in a property.
        CachedTableRowGridPosition

        % Numeric flex weights (0 for non-flex columns)
        ColumnFlexWeights (1,:) double
    end

    properties (Access = private)
        % Dummy grid used for validating ColumnWidth
        DummyGridLayout matlab.ui.container.GridLayout
        UseDummyFlexColumn matlab.lang.OnOffSwitchState = "off"
    end

    properties (Constant, Access=private)
        ML_COMP_PATH = fileparts(mfilename('fullpath'))
        ICON_PATH = fullfile( fileparts(mfilename('fullpath')), 'resources', 'icons' )
    end

    methods % Public methods
        function updateCellValue(comp, rowIndex, columnIndex, cellValue)
            % No callback (i.e set programmatically)
            cellValue = comp.setCellValue(rowIndex, columnIndex, cellValue);
            comp.updateComponentValue(rowIndex, columnIndex, cellValue)
        end
    end

    methods % Set / get methods
        function h = get.Height(comp)
            if isempty(comp.Data)
                h = 0;
            elseif isa(comp.Data, 'table')
                h = size(comp.Data, 1);
            elseif isa(comp.Data, 'struct')
                h = numel(comp.Data);
            else
                error('Unsupported data type for Data')
            end
        end

        function w = get.Width(comp)
            if isempty(comp.Data)
                w = comp.getWidthFromConfigProperties();
            elseif isa(comp.Data, 'table')
                w = size(comp.Data, 2);
            elseif isa(comp.Data, 'struct')
                w = numel(fieldnames(comp.Data));
            else
                error('Unsupported data type for Data')
            end
        end

        function numRows = get.NumRows(comp)
            numRows = comp.Height;

            if comp.EnableAddRows
                numRows = numRows + 1;
            end
        end

        function numColumns = get.NumColumns(comp)
            numColumns = comp.Width;
            
            if comp.EnableAddRows
                numColumns = numColumns + 1;
            end
        end

        function set.EnableAddRows(comp, value)
            oldValue = comp.EnableAddRows;
            comp.EnableAddRows = value;
            comp.postSetEnableAddRows(value, oldValue)            
        end

        function set.RowHeight(comp, value)
            comp.RowHeight = value;
            comp.postSetRowHeight()
        end

        function set.RowSpacing(comp, value)
            comp.RowSpacing = value;
            comp.postSetRowSpacing()
        end

        function set.ColumnNames(comp, value)
            %comp.ColumnNames = strtrim(strsplit(value, ',')); % If string type
            comp.ColumnNames = value;
            comp.updateColumnTitles()
            comp.createHeader()
        end

        function set.ColumnWidth(comp, value)
            comp.validateRowColumnSize(value)
            comp.ColumnWidth = value;
            comp.postSetColumnWidth()
        end

        function set.ColumnSpacing(comp, value)
            comp.ColumnSpacing = value;
            comp.postSetColumnSpacing()
        end
        
        function set.MinimumColumnWidth(comp, value)
            value = comp.validateColumnWidth(value, 'Minimum');
            comp.MinimumColumnWidth = value;
            comp.postSetMinimumColumnWidth()
        end
        function value = get.MinimumColumnWidth(comp)
            if numel(comp.MinimumColumnWidth) == 1
                value = repmat(comp.MinimumColumnWidth, 1, comp.Width);
            else
                value = comp.MinimumColumnWidth;
            end
        end

        function set.MaximumColumnWidth(comp, value)
            value = comp.validateColumnWidth(value, 'Maximum');
            comp.MaximumColumnWidth = value;
            comp.postSetMaximumColumnWidth()
        end
        function value = get.MaximumColumnWidth(comp)
            if numel(comp.MaximumColumnWidth) == 1
                value = repmat(comp.MaximumColumnWidth, 1, comp.Width);
            else
                value = comp.MaximumColumnWidth;
            end
        end

        function set.ColumnGridWidth(comp, value)
            comp.ColumnGridWidth = value;
            comp.postSetColumnGridWidth()
        end

        function set.TablePadding(comp, value)
            comp.TablePadding = value;
            comp.postSetTablePadding()
        end
        
        function set.Data(comp, newValue)
            comp.Data_ = newValue;
            comp.onDataSet()
        end
        function data = get.Data(comp)
            data = comp.Data_;
        end

        function set.HeaderBackgroundColor(comp, newValue)
            comp.HeaderBackgroundColor = newValue;
            comp.postSetHeaderBackgroundColor()
        end

        function set.HeaderForegroundColor(comp, newValue)
            comp.HeaderForegroundColor = newValue;
            comp.postSetHeaderForegroundColor()
        end

        function set.TableBorderType(comp, value)
            comp.TablePanel.BorderType = value;
        end
        function value = get.TableBorderType(comp)
            value = comp.TablePanel.BorderType;
        end
    
        function value = get.TotalColumnExtent(comp)

            columnWidth = comp.AdjustedColumnWidth;

            isNumeric = cellfun(@(c) isnumeric(c), columnWidth);
            totalColumnWidth = sum([columnWidth{isNumeric}]);

            value = totalColumnWidth ... 
                    + comp.ColumnSpacing * (comp.NumColumns-1) ...
                    + sum(comp.TablePadding([1,3])); 
        end
        
        function value = get.FixedWidthColumnExtent(comp)
            isFlexColumn = comp.isFlexSize( comp.InternalColumnWidth );
            value = sum( [comp.InternalColumnWidth{~isFlexColumn}] );
        end

        function value = get.HasFlexColumns(comp)
            value = comp.TotalColumnExtent < comp.TableGridLayout.Position(3);
        end
    end

    methods (Access = private) % Validation methods
        function validateRowColumnSize(comp, value)
            if ~isempty(comp.Data)
                assert( numel(value) == comp.Width, ...
                    ['ColumnWidth must be a vector with the same number of ', ...
                     'elements as the number of columns in Data'])
            end

            try
                comp.DummyGridLayout.ColumnWidth = value;
            catch ME
                throwAsCaller(ME)
            end
        end

        function columnWidth = validateColumnWidth(comp, columnWidth, name)
        % validateColumnWidth - Validate the size of column width spec
            if nargin < 3; name = 'Preferred'; end

            isValid = numel(columnWidth) == 1 || numel(columnWidth) == comp.Width;
            assert( isValid, ...
                sprintf('%s column width must have a length of 1 or match the width of the table', name))

            if columnWidth == 1
                columnWidth = repmat(columnWidth, 1, comp.Width);
            end
        end
    end

    methods (Access = private) % Post-set methods for property setters
        function postSetEnableAddRows(comp, newValue, oldValue)
            comp.updateInternalColumnWidth()

            if oldValue && ~newValue
                comp.removeAddRemoveButtonColumn() % todo hide?
            elseif newValue && ~oldValue
                comp.createAddRemoveButtonColumn() % todo create/show?
            else
                % pass
                return
            end

            for i = 1:numel(comp.HeaderColumnTitle)
                comp.updateColumnTitle(i)
            end
            comp.updateTableRowHeight()
            comp.resizeTableColumns()
        end
        
        function postSetRowHeight(comp)
            comp.updateTableRowHeight()
        end

        function postSetRowSpacing(comp)
            comp.updateTableRowHeight()
            rowPadding = comp.getRowPadding();
            for i = 1:numel(comp.RowGridLayout)
                comp.RowGridLayout(i).Padding = rowPadding;
            end
        end

        function postSetColumnWidth(comp)
            comp.updateInternalColumnWidth()
            comp.computeActualColumnWidths();
            if ~isempty(comp.Data)
                comp.resizeTableColumns()
            end
        end

        function postSetColumnSpacing(comp)
            if ~isempty(comp.Data)
                set(comp.RowGridLayout, 'ColumnSpacing', comp.ColumnSpacing)
                drawnow
                comp.resizeTableColumns()
            end
        end

        function postSetColumnGridWidth(comp)
            comp.HeaderGridLayout.ColumnSpacing = comp.ColumnGridWidth;
            if ~isempty(comp.Data)
                comp.resizeTableColumns()
            end        
        end
        
        function postSetMinimumColumnWidth(comp)
            if ~isempty(comp.Data)
                comp.resizeTableColumns()
            end
        end

        function postSetMaximumColumnWidth(comp)
            if ~isempty(comp.Data)
                comp.resizeTableColumns()
            end
        end

        function postSetTablePadding(comp)
            % Todo
        end

        function postSetHeaderBackgroundColor(comp)
            if ~isempty(comp.HeaderColumnGridLayout)
                set(comp.HeaderColumnGridLayout, ...
                    'BackgroundColor', comp.HeaderBackgroundColor)
            end            
        end

        function postSetHeaderForegroundColor(comp)
            if ~isempty(comp.HeaderColumnTitle)
                set(comp.HeaderColumnTitle, ...
                    'FontColor', comp.HeaderForegroundColor)
            end
        end
    end

    methods (Access = private) % Callbacks
        function onDataSet(comp)
            comp.resetTable()
            drawnow

            comp.updateInternalColumnWidth()
            comp.updateTableColumnWidth()
            comp.updateTableRowHeight()

            comp.updateColumnTitles()
            comp.createHeader()

            drawnow
            pause(0.5)

            warning('off')
            try
                hWaitbar = ccTools.ProgressDialog(comp.TablePanel, 'color', comp.HeaderBackgroundColor);
            catch
                hWaitbar = comp.displayWaitbar("Creating table... Please wait!");
            end
            comp.createRows()
            delete(hWaitbar)
            warning('on')
            drawnow

            comp.resizeTableColumns()
        end

        function onComponentSizeChanged(comp, src, evt)
            if isempty(comp.RowGridLayout); return; end
            comp.resizeTableColumns()
        end

        function onMouseMotion(comp, src, evt)
        % onMouseMotion - Callback for mousemotion over component    
            comp.updateFocusRow(src)
            if isempty(comp.RowGridLayout); return; end

            [iRow, iCol] = comp.getCellForPointer(src);

            hControl = [];
            if iRow ~= -1 && iCol ~= -1
                hControl = comp.RowComponents{iRow, iCol};
                if ismethod(hControl, 'mouseMotionOnComponent')
                    hControl.mouseMotionOnComponent(src)
                    if ~any(comp.TouchedComponents==hControl)
                        comp.TouchedComponents(end+1)=hControl;
                    end
                else
                    hControl = [];
                end
            end

            if ~isempty(comp.TouchedComponents)
                for i = numel(comp.TouchedComponents):-1:1
                    if isequal(comp.TouchedComponents(i), hControl)
                        continue
                    else
                        comp.TouchedComponents(i).mouseMotionOnComponent(src)
                        comp.TouchedComponents(i) = [];
                    end
                end
            end
        end
        
        function onTableViewportLocationChanging(comp, src, evt)
            yScrollOffset = evt.ScrollableViewportLocation(2);
            comp.updateFocusRow([], yScrollOffset)
        end
    end

    methods (Access = private) % Sub-component creation
        function createHeader(comp)
            for i = 1:comp.NumColumns
                if numel(comp.HeaderColumnGridLayout) < i
                    comp.HeaderColumnGridLayout(i) = comp.createColumnTitleGrid(i);
                    %[comp.HeaderColumnTitle(i), comp.HeaderColumnImage(i)] = comp.createColumnTitleLabel(i); % todo
                    [comp.HeaderColumnTitle(i), ~] = comp.createColumnTitleLabel(i);
                else
                    comp.updateColumnTitle(i)
                end
            end
        end

        function createRows(comp)
            numColumns = comp.NumColumns;

            for iRow = 1:comp.Height
                comp.RowComponents(iRow, 1:numColumns) = comp.createRowComponents(iRow);
                if mod(iRow, 10)==0
                    drawnow
                end
            end
            if comp.EnableAddRows
                if isempty(comp.AddRowButton)
                    comp.AddRowButton = comp.createAddRowButton(comp.NumRows, 1);
                end
            end
        end

        function rowComponents = createRowComponents(comp, iRow)
            
            numColumns = comp.NumColumns;
            rowComponents = cell(1, numColumns);

            comp.createRowGrid(iRow)

            for iColumn = 1:numColumns
                if iColumn == 1 && comp.EnableAddRows
                    rowComponents{iColumn} = comp.createRemoveRowButton(iRow, iColumn);
                    continue
                end

                if comp.EnableAddRows && iRow == comp.NumRows
                    return
                end

                rowComponents{iColumn} = comp.createComponent(iRow, iColumn);
            end
        end
            
        function hControl = createComponent(comp, iRow, iColumn)
            iColData = comp.getDataColumnIndex(iColumn);
            parentContainer = comp.RowGridLayout(iRow);

            cellValue = comp.getCellValue(iRow, iColData);

            % Create custom component / widget
            if ~isempty(comp.ColumnWidget) && ~isempty(comp.ColumnWidget{iColData})
                if ischar( comp.ColumnWidget{iColData} )
                    hControl = feval(comp.ColumnWidget{iColData}, parentContainer);
                elseif isa( comp.ColumnWidget{iColData}, 'function_handle' )
                    hControl = comp.ColumnWidget{iColData}(parentContainer);
                    hControl.BackgroundColor = 'w'; %todo?
                end
               
            % Create standard component / widget
            else 
                switch class(cellValue)
                    case 'string'
                        hControl = uieditfield(parentContainer);
    
                    case 'char'
                        hControl = uieditfield(parentContainer);
    
                    case {'single', 'double'}
                        hControl = uieditfield(parentContainer, 'numeric');
    
                    case {'uint8'}
                        hControl = uispinner(parentContainer, 'Limits', [0,255]);
                        cellValue = double(cellValue);
    
                    case {'uint16'}
                        hControl = uispinner(parentContainer, 'Limits', [0,2^16-1]);
                        cellValue = double(cellValue);
    
                    case 'categorical'
                        hControl = uidropdown(parentContainer);
                        hControl.Items = categories(cellValue);
                        cellValue = char(cellValue);
    
                    case 'logical'
                        hControl = uicheckbox(parentContainer);
                        hControl.Text = '';
                end
            end

            hControl.Layout.Column = iColumn; 
            hControl.Layout.Row = 1;

            if isprop(hControl, 'Value')
                hControl.Value = cellValue;
                hControl.ValueChangedFcn = @comp.onCellValueChanged;
            end
        end

        function hButton = createRemoveRowButton(comp, iRow, iColumn)
            parentContainer = comp.RowGridLayout(iRow);

            hButton = uibutton(parentContainer);
            hButton.Layout.Row = 1;
            hButton.Layout.Column = iColumn;
            hButton.Text = '';
            hButton.Icon = fullfile(comp.ICON_PATH, 'minus.png');
            hButton.ButtonPushedFcn = @comp.onRemoveRowButtonPushed;
        end

        function hButton = createAddRowButton(comp, iRow, iColumn) %#ok<INUSD>
            
            % (Mis-)use the method for creating a row grid.
            comp.createRowGrid(comp.NumRows)
            
            % Move the grid to the AddRowButtonGrid property
            comp.AddRowButtonGrid = comp.RowGridLayout(comp.NumRows);
            comp.RowGridLayout(comp.NumRows) = [];

            hButton = uibutton(comp.AddRowButtonGrid);
            hButton.Layout.Row = 1;
            hButton.Layout.Column = 1;
            hButton.Text = '';
            hButton.Icon = fullfile(comp.ICON_PATH, 'plus.png');
            hButton.ButtonPushedFcn = @comp.onAddRowButtonPushed;
        end

        function createRowGrid(comp, iRow)
        % createRowGrid - Create gridlayout for an individual row

            comp.RowGridLayout(iRow) = uigridlayout(comp.TableRowGridLayout);
            comp.RowGridLayout(iRow).Layout.Row = iRow;
            comp.RowGridLayout(iRow).Layout.Column = 1;

            comp.RowGridLayout(iRow).ColumnWidth = comp.AdjustedColumnWidth;
            comp.RowGridLayout(iRow).ColumnSpacing = comp.ColumnSpacing;
            comp.RowGridLayout(iRow).RowHeight = {'1x'};
            comp.RowGridLayout(iRow).RowSpacing = 0;
            comp.RowGridLayout(iRow).BackgroundColor = comp.BackgroundColor;
            comp.TableRowGridLayout.BackgroundColor = comp.BackgroundColor;
            
            comp.RowGridLayout(iRow).Padding = comp.getRowPadding();
        end

        function h = createColumnTitleGrid(comp, iColumn)
            h = uigridlayout(comp.HeaderGridLayout);
            h.ColumnWidth = {'1x', 18};
            h.RowHeight = {'1x'};
            h.ColumnSpacing = 5;
            
            xPadding = comp.ColumnSpacing - comp.ColumnGridWidth;
            xPaddingLeft = ceil(xPadding/2);
            xPaddingRight = floor(xPadding/2);
            
            if iColumn == 1
                xPaddingLeft = xPaddingLeft + comp.TablePadding(1);
            elseif iColumn == comp.NumColumns
                xPaddingRight = xPaddingRight + comp.TablePadding(3);
            end

            h.Padding = [xPaddingLeft, comp.HeaderPadding(2), xPaddingRight, comp.HeaderPadding(4)];
            h.Layout.Row = 1;
            h.Layout.Column = iColumn;
            h.BackgroundColor = comp.HeaderBackgroundColor;
        end

        function [hLabel, hImage] = createColumnTitleLabel(comp, iColumn)
            if iColumn == 1 && comp.EnableAddRows
                columnTitle = "";
            elseif comp.EnableAddRows
                columnTitle = comp.ColumnTitles(iColumn-1);
            else
                columnTitle = comp.ColumnTitles(iColumn);
            end

            hLabel = uilabel(comp.HeaderColumnGridLayout(iColumn));
            hLabel.Text = columnTitle;
            hLabel.FontColor = comp.HeaderForegroundColor;
            hLabel.FontName = comp.FontName;
            hLabel.FontWeight = 'bold';
            hLabel.Layout.Row = 1;
            hLabel.Layout.Column = 1;

            % % % Plot transparent image to capture mouseclicks on header.
            % Todo
            % % hImage = uiimage(comp.HeaderColumnGridLayout(iColumn));
            % % %hImage = uiimage(comp.HeaderGridLayout);
            % % hImage.ScaleMethod = 'fill';
            % % hImage.ImageClickedFcn = @comp.onColumnTitleClicked;
            % % hImage.Layout.Row = 1;
            % % hImage.Layout.Column = 1;
            hImage = [];
            
            filePath = fullfile(WidgetTable.ML_COMP_PATH, 'resources', 'label_background.png');
            if ~isfile(filePath); comp.saveTransparentBackground(); end
            hImage.ImageSource = filePath;

            if isa(comp.Data, 'table')
                if ~isempty(comp.Data.Properties.VariableDescriptions)
                    if comp.EnableAddRows && iColumn == 1
                        description = '';
                    elseif comp.EnableAddRows
                        description = comp.Data.Properties.VariableDescriptions(iColumn-1);
                    else
                        description = comp.Data.Properties.VariableDescriptions(iColumn);
                    end
                    hLabel.Tooltip = description;
                end
            end

            if comp.ShowColumnHeaderHelp && iColumn ~= 1
                % Create help icon
                hHelpButton = comp.createHelpIconButton(comp.HeaderColumnGridLayout(iColumn));
                hHelpButton.Tag = columnTitle;
                hHelpButton.Layout.Row = 1;
                hHelpButton.Layout.Column = 2;
            elseif ~comp.ShowColumnHeaderHelp 
                hLabel.Layout.Column = [1,2];
                hImage.Layout.Column = [1,2];
            end
        end

        function hIconButton = createHelpIconButton(comp, hContainer)
        %createHelpIconButton Create a help button TODO
        
            hIconButton = uiimage(hContainer);
            hIconButton.Tooltip = 'Press for help';
            hIconButton.ImageSource = fullfile(comp.ICON_PATH, 'help.png');
            %hIconButton.ImageClickedFcn = @comp.onHelpButtonClicked;
        end

        function createViewportListener(comp)
            comp.ViewportChangedListener = listener(...
                comp.TableRowGridLayout, 'ScrollableViewportLocationChanging', ...
                @comp.onTableViewportLocationChanging);
        end

        function createSizeChangedListener(comp)
            comp.SizeChangedListener = listener(comp, 'SizeChanged', ...
                @comp.onComponentSizeChanged);
        end

        function createWindowMouseMotionListener(comp)
            hFigure = ancestor(comp, 'figure');

            hFigure.WindowButtonMotionFcn = @comp.onMouseMotion;
            % comp.MouseMotionListener = listener(hFigure, 'WindowMouseMotion', ...
            %     @comp.onMouseMotion);
        end

        function createDummyGrid(comp)
        % createDummyGrid - Create a dummy grid used for validating ColumnWidth
        %
        % This create a dummy grid which will be used for validating the 
        % ColumnWidth property by utilizing the GridLayout's internal 
        % validation methods for ColumnWidth.

            comp.DummyGridLayout = uigridlayout(comp);
            comp.DummyGridLayout.ColumnWidth = {'1x'};
            comp.DummyGridLayout.RowHeight = {'1x'};
            uistack(comp.DummyGridLayout, "bottom") % NB: This does not work...
            %uistack(comp.ComponentGridLayout, "top")
            comp.DummyGridLayout.Visible = "off";
        end
    
        function h = displayWaitbar(comp, message)
            hFigure = ancestor(comp, 'figure');
            h = uiprogressdlg(hFigure, "Indeterminate", "on", "Message", message);
        end
    end
    
    methods (Access = private) % Sub-component related updates
        function moveAddRowButton(comp, direction)
            arguments
                comp
                direction (1,1) string {mustBeMember(direction, ["up", "down"])} = "down"
            end

            switch direction
                case "up"
                    comp.AddRowButton.Parent.Layout.Row = comp.AddRowButton.Parent.Layout.Row - 1;
                case "down"
                    comp.AddRowButton.Parent.Layout.Row = comp.AddRowButton.Parent.Layout.Row + 1;
            end
        end
    
        function resetTable(comp)
            delete(comp.HeaderColumnGridLayout)
            % delete components
        end
    
        function updateFocusRow(comp, hFigure, yScrollOffset)
        % updateFocusRow - Update appearance of row in focus.
        
            if nargin < 2 || isempty(hFigure)
                hFigure = ancestor(comp, 'figure');
            end
            if nargin < 3 || isempty(yScrollOffset)
                yScrollOffset = comp.TableRowGridLayout.ScrollableViewportLocation(2);
            end

            yPoint = hFigure.CurrentPoint(2);

            rowExtent = comp.TableRowGridLayout.RowHeight{1} + comp.TableRowGridLayout.RowSpacing;

            pos = comp.CachedTableRowGridPosition;
            y0 = pos(2);
            yPoint = yPoint-y0;
            
            yOffsetFromTop = pos(4) - yPoint - yScrollOffset;

            rowInd = ceil(yOffsetFromTop/rowExtent);
            
            set(comp.RowGridLayout, 'BackgroundColor', 'w');

            if rowInd >= 1 && rowInd <= comp.Height
                if numel(comp.RowGridLayout) >= rowInd % Might fail during initialization
                    comp.RowGridLayout(rowInd).BackgroundColor = comp.RowFocusColor;
                end
            else
                % pass (All bg colors are reset before this block)
            end
        end
    
        function updateColumnTitle(comp, iColumn, hControl)
            
            if nargin < 3
                hControl = comp.HeaderColumnTitle(iColumn);
            end

            if iColumn == 1 && comp.EnableAddRows
                columnTitle = "";
            elseif comp.EnableAddRows
                columnTitle = comp.ColumnTitles(iColumn-1);
            else
                if iColumn > numel(comp.ColumnTitles)
                    columnTitle = "";
                else
                    columnTitle = comp.ColumnTitles(iColumn);
                end
            end

            hControl.Text = columnTitle;
        end

        function removeAddRemoveButtonColumn(comp)
            
            for iRow = 1:comp.Height
                delete( comp.RowComponents{iRow, 1} )
                for jCol = 2:comp.NumColumns+1
                    comp.RowComponents{iRow, jCol}.Layout.Column = jCol-1;
                end
            end

            comp.RowComponents(1:comp.Height,1) = [];

            % Hide add button...
            if ~isempty(comp.AddRowButtonGrid)
                delete(comp.AddRowButtonGrid); comp.AddRowButtonGrid(:) = [];
                delete(comp.AddRowButton); comp.AddRowButton(:) = [];
            end
        end

        function createAddRemoveButtonColumn(comp) % todo create/show?
            
            removeButtons = matlab.ui.control.Button.empty;
            for iRow = 1:comp.Height
                removeButtons(iRow) = comp.createRemoveRowButton(iRow, 1);
                for jCol = 1:comp.NumColumns-1
                    comp.RowComponents{iRow, jCol}.Layout.Column = jCol+1;
                end
            end
            removeButtons = num2cell(removeButtons);
            comp.RowComponents = cat(2, removeButtons', comp.RowComponents);

            % Show add button...
            if ~isempty(comp.AddRowButtonGrid)
                comp.AddRowButtonGrid.Visible = 'on';
                comp.AddRowButton.Visible = 'on';
            else
                comp.AddRowButton = comp.createAddRowButton(comp.NumRows, 1);
            end
        end
    
        function updateBackgroundColor(comp)
            comp.TableRowGridLayout.BackgroundColor = comp.BackgroundColor;
            set(comp.RowGridLayout, 'BackgroundColor', comp.BackgroundColor)
            set(comp.AddRowButtonGrid, 'BackgroundColor', comp.BackgroundColor)
        end
    end
    
    methods (Access = private) % Sub-component callbacks
        function onColumnTitleClicked(comp, src, evt)
        % onColumnTitleClicked - Handle button press on column title
            hFigure = ancestor(comp, 'figure');
            uialert(hFigure, 'Clicked column title', '')
        end
        
        function onCellValueChanged(comp, src, evt)
        % onCellValueChanged - Handle value changed for table cell.

            iRow = src.Parent.Layout.Row;
            iColumn = find( [comp.RowComponents{iRow,:}] == src );
            iColumnIndexData = comp.getDataColumnIndex(iColumn);
            
            previousData = comp.getCellValue(iRow, iColumnIndexData);
            newData = comp.setCellValue(iRow, iColumnIndexData, evt.Value);

            % Todo: Table event data...
            if ~isempty(comp.CellEditedFcn)
                evtData = CellEditEventData( ...
                    [iRow, iColumnIndexData], ...
                    [iRow, iColumn], previousData, newData, newData);
                comp.CellEditedFcn(comp, evtData);
            end
        end

        function onRemoveRowButtonPushed(comp, src, evt)
            drawnow
            hWaitbar = comp.displayWaitbar("Removing row");

            rowIndex = find( [comp.RowComponents{:,1}]==src, 1, "first" );

            % for iColumn = 1:size(comp.RowComponents, 2)
            %     delete(comp.RowComponents{rowIndex, iColumn})
            % end

            comp.removeDataRow(rowIndex)

            if comp.EnableAddRows
                firstColumn = 2;
            else
                firstColumn = 1;
            end

            for iRow = rowIndex:comp.Height
                for iColumn = firstColumn:comp.NumColumns
                    iColData = comp.getDataColumnIndex(iColumn);
                    cellValue = comp.getCellValue(iRow, iColData);
                    hControl = comp.RowComponents{iRow, iColumn};

                    % Todo: value conversion methods...
                    switch class(cellValue)
                        case {'uint8', 'uint16'}
                            cellValue = double(cellValue);
                        case 'categorical'
                            cellValue = char(cellValue);
                    end

                    if isprop(hControl, 'Value')
                        hControl.Value = cellValue;
                    end
                end
            end

            % if rowIndex ~= comp.NumRows
            %     allComponents = [comp.RowComponents{rowIndex+1:comp.NumRows, :}];
            %     layout = get(allComponents, 'Layout');
            %     layout = [layout{:}];
            %     rowIdx = [layout.Row];
            %     rowIdx = num2cell( rowIdx-1 );
            %     [layout(:).Row] = deal(rowIdx{:});
            %     set(allComponents', {'Layout'}, num2cell(layout)');
            % end
            
            % tic
            % for iRow = rowIndex+1:comp.NumRows
            %     for iColumn = 1:size(comp.RowComponents, 2)
            %         comp.RowComponents{iRow, iColumn}.Layout.Row = iRow-1;
            %     end
            % end
            % toc
            
            if comp.EnableAddRows
                comp.moveAddRowButton("up")
            end

            delete( comp.RowGridLayout(end) )
            comp.RowGridLayout(end) = [];

            comp.updateTableRowHeight()

            drawnow
            delete(hWaitbar)
        end

        function onAddRowButtonPushed(comp, src, evt)
            if ~isempty(comp.Data)
                rowData = comp.getRowData(1);
                rowData = comp.resetData(rowData); % Clear all values.
                comp.appendRowData(rowData)

            else
                comp.Data_ = cell2table( repmat({""}, 1, comp.Width), "VariableNames", comp.ColumnTitles);
            end

            comp.updateTableRowHeight()

            if comp.EnableAddRows
                comp.moveAddRowButton("down")
            end

            iRow = comp.Height;
            comp.RowComponents(iRow, 1:comp.NumColumns) = comp.createRowComponents(iRow);
        end
    end

    methods (Access = private) % Internal calculations & updates

        function updateTableContainerWidth(comp)
        % updateTableContainerWidth - Update width of comp.TableGridLayout
        %
        % This method updates the ColumnWidth of the TableGridLayout. If
        % the total computed width of all the table's columns exceed the
        % width of the container, the column width of the Grid is set to
        % the total extent (in pixels) of all the table's columns, in
        % effect enabling a horizontal scrolling. Otherwise, the
        % ColumnWidth is set to "1x", allowing flex columns to fill up the
        % available space.

            if comp.HasFlexColumns
                comp.TableGridLayout.ColumnWidth = {'1x'};
            else
                comp.TableGridLayout.ColumnWidth = comp.TotalColumnExtent; % fit?
            end
        end

        function updateTableRowHeight(comp)
            rowHeight = repmat(comp.RowHeight + comp.RowSpacing, 1, comp.NumRows);
            comp.TableRowGridLayout.RowHeight = rowHeight;
        end

        function updateTableColumnWidth(comp)
            comp.computeActualColumnWidths();
            comp.updateTableContainerWidth()
        end
    
        function updateColumnTitles(comp)
            if isempty(comp.ColumnNames)
                if isa(comp.Data, 'table')
                    columnTitles = comp.Data.Properties.VariableNames;
                elseif isa(comp.Data, 'struct')
                    columnTitles = fieldnames(comp.Data);
                else
                    error('Unknown data type for Data')
                end
                comp.ColumnTitles = columnTitles;
            else
                comp.ColumnTitles = cellstr( comp.ColumnNames );
            end
        end

        function resizeTableColumns(comp)
        % resizeTableColumns - Resize table columns

            comp.updateTableColumnWidth()

            % Update the ColumnWidth property of the dependent grid
            % layouts. Use set method on all grids for a smoother(?) update 
            headerColumnWidths = comp.getHeaderColumnWidth();
            hGrid = [comp.HeaderGridLayout, comp.RowGridLayout];
            colWidth = [{headerColumnWidths}; repmat({comp.AdjustedColumnWidth}, numel(comp.RowGridLayout), 1)];
            
            drawnow limitrate
            set(hGrid', {'ColumnWidth'}, colWidth)
            set(comp.AddRowButtonGrid, 'ColumnWidth', comp.AdjustedColumnWidth)
            
            % Finetune position of header. 
            comp.computeActualColumnWidths();
            comp.updateHeaderGridLayoutColumnWidth()
            drawnow
            
            % Update the value for the CachedTableRowGridPosition property
            comp.CachedTableRowGridPosition = getpixelposition(comp.TableRowGridLayout, true);
        end

        function updateInternalColumnWidth(comp)
        % updateInternalColumnWidth - Update InternalColumnWidth property value
            
            % Initialize with all flex columns if ColumnWidth is unset.
            if isempty(comp.ColumnWidth)
                columnWidth = repmat({'1x'}, 1, comp.Width);
            else
                columnWidth = comp.ColumnWidth;
            end
            
            if comp.EnableAddRows
                % Add extra column for which to create buttons for adding
                % and removing rows.
                comp.InternalColumnWidth = [{23}, columnWidth];
            else
                comp.InternalColumnWidth = columnWidth;
            end

            comp.updateColumnFlexWeights()
        end

        function headerColumnWidths = getHeaderColumnWidth(comp)
            
            % Initialize width based on the internal column width
            headerColumnWidths = comp.AdjustedColumnWidth;

            % The header column grid will contain one subgrid for each
            % column. In order to give appearance of grid lines for the header, 
            % the actual column spacing of the header grid is different from
            % the column spacing of the table grid. In order to make sure
            % the header will appear to have the same column spacing as the
            % table, the table's horizontal padding and column spacing is
            % added to the column widths for the header.

            % The difference in spacing that needs to be added to each column
            remainingColumnSpacing = comp.ColumnSpacing - comp.ColumnGridWidth;

            for i = 1:numel(headerColumnWidths)
                if ~ischar(headerColumnWidths{i})
                    if i==1
                        headerColumnWidths{i} = headerColumnWidths{i} + ...
                            floor(remainingColumnSpacing/2) + comp.TablePadding(1);
                    elseif i == numel(headerColumnWidths)
                        headerColumnWidths{i} = headerColumnWidths{i} + ...
                            ceil(remainingColumnSpacing/2) + comp.TablePadding(3);
                    else
                        headerColumnWidths{i} = headerColumnWidths{i} + remainingColumnSpacing;
                    end
                end
            end
        end

        function headerColumnWidths = updateHeaderGridLayoutColumnWidth(comp)
            
            tablePadding = sum(comp.TablePadding([1,3]));
            headerColumnWidths = num2cell(comp.ActualColumnWidth);
            
            % Add padding and spacing to each column's gridlayout. The
            % header is made up of a nested grid, where each column has
            % it's own grid. The spacing of the main grid will depend on
            % the ColumnGridWidth property, and in order to match the
            % column spacing of the header to the table, extra space is
            % added to each subgrid to account for the column spacing of
            % the table. Also, the table padding is added on the first and
            % last column.
            for i = 1:numel(headerColumnWidths)
                if ~ischar(headerColumnWidths{i})
                    if i==1
                        headerColumnWidths{i} = headerColumnWidths{i} + floor((comp.ColumnSpacing - comp.ColumnGridWidth)/2) + comp.TablePadding(1);
                    elseif i == numel(headerColumnWidths)
                        headerColumnWidths{i} = headerColumnWidths{i} + ceil((comp.ColumnSpacing - comp.ColumnGridWidth)/2) + comp.TablePadding(3); %3=ad hoc correction
                    else
                        headerColumnWidths{i} = headerColumnWidths{i} + comp.ColumnSpacing - comp.ColumnGridWidth;
                    end
                end
            end

            % Compute corrected flex units. The header grid (as opposed to the 
            % actual table grid) includes the horizontal table padding as
            % internal space, so the size of the flex units will not be
            % exactly the same as the flex units defined for the table.
            % Compute the header's flex units while accounting for the table's
            % padding.
            isFlex = cellfun(@(c) comp.isFlexSize(c), comp.AdjustedColumnWidth);
            
            if any(isFlex)
                totalWidth = sum([headerColumnWidths{isFlex}]) + tablePadding;
    
                %numFlex = sum(isFlex);
                flexWidth = [headerColumnWidths{isFlex}]; %+ repmat(tablePadding/numFlex, 1, numFlex);
                flexWidth = (flexWidth / totalWidth);
                flexWidth = flexWidth ./ min(flexWidth);
                headerColumnWidths(isFlex) = arrayfun(@(x) sprintf('%.2fx', x), flexWidth, 'uni', 0);
            end

            if ~nargout
                comp.HeaderGridLayout.ColumnWidth = headerColumnWidths;
                clear headerColumnWidths
            end
        end
        
        function computeFixedHeaderColumnGridWidth(comp)
        % computeFixedHeaderColumnGridWidth - Compute fixed width for header

        end

        function [actualColumnWidths, isAdjusted] = computeActualColumnWidths(comp)
        % computeActualColumnWidth - Compute actual column widths.
        %
        %   This method computes the actual column sizes and also adjusts
        %   size of columns if they are smaller than the minimul allowed
        %   size

            isAdjusted = deal( false(1, comp.NumColumns) );

            % Extract the grid layout columns and column spacing
            actualColumnWidths = comp.InternalColumnWidth;

            availableWidth = comp.getAvailableHorizontalSpace();
            remainingWidth = availableWidth - comp.FixedWidthColumnExtent;
            
            flexUnitWidth = remainingWidth / sum( comp.ColumnFlexWeights );

            isFlexColumn = comp.isFlexSize( comp.InternalColumnWidth );

            % Check if any relative column widths need to be updated with
            % minimum values...
            minimumColumnWidth = comp.MinimumColumnWidth;
            maximumColumnWidth = comp.MaximumColumnWidth;

            if comp.EnableAddRows
                % Add column for add/remove buttons
                minimumColumnWidth = [0, minimumColumnWidth];
                maximumColumnWidth = [0, maximumColumnWidth];
            end

            % Compute actual column widths:
            if flexUnitWidth < 0
                actualColumnWidths(isFlexColumn) = num2cell(minimumColumnWidth(isFlexColumn));
            else

                [sorted, colIdx] = sort( comp.ColumnFlexWeights, 'ascend' );
                colIdx = colIdx(sorted~=0);

                for i = colIdx
                    weight = comp.ColumnFlexWeights(i);
                    actualWidth = weight * flexUnitWidth;
                    
                    % Limit minimum actual column size.
                    if actualWidth <= minimumColumnWidth(i)
                        actualWidth = minimumColumnWidth(i);
                        isAdjusted(i) = true;
                    end

                    % Update actual column size for current column
                    actualColumnWidths{i} = actualWidth;
                    
                    % Recalculate flex units.
                    if isAdjusted(i)
                        usedWidth = sum( [actualColumnWidths{~isFlexColumn | isAdjusted}] );
                        remainingWidth = availableWidth - usedWidth;
                        flexUnitWidth = remainingWidth / sum( comp.ColumnFlexWeights(~isAdjusted) );
                    end
                end

                [sorted, colIdx] = sort( comp.ColumnFlexWeights, 'descend' );
                colIdx = colIdx(sorted~=0);
                
                for i = colIdx
                    if isAdjusted(i); continue; end
                    weight = comp.ColumnFlexWeights(i);
                    actualWidth = weight * flexUnitWidth;
                    
                    % Limit maximum column size
                    if actualWidth >= maximumColumnWidth(i)
                        actualWidth = maximumColumnWidth(i);
                        isAdjusted(i) = true;
                    end

                    % Update actual column size for current column
                    actualColumnWidths{i} = actualWidth;
                    
                    % Recalculate flex units.
                    if isAdjusted(i)
                        usedWidth = sum( [actualColumnWidths{~isFlexColumn | isAdjusted}] );
                        remainingWidth = availableWidth - usedWidth;
                        flexUnitWidth = remainingWidth / sum( comp.ColumnFlexWeights(~isAdjusted) );
                    end
                end
            end

            comp.ActualColumnWidth = cell2mat(actualColumnWidths);
            
            comp.updateAdjustedColumnWidth(actualColumnWidths, isAdjusted)
            
            if nargout < 1
                clear actualColumnWidths
            end
            if nargout < 2
                clear isAdjusted
            end
        end

        function updateAdjustedColumnWidth(comp, actualColumnWidth, isAdjusted)
        % updateAdjustedColumnWidth - Updates the AdjustedColumnWidth property
        %
        %   This method is called from the computeActualColumnWidths and
        %   will replace the values of actual (fixed-pixel) column widths
        %   with their corresponding flex weight if the columns are
        %   flex-columns and they are not adjusted based on minimum/maximum
        %   column widths.

            isFlex = comp.isFlexSize(comp.InternalColumnWidth);
            
            adjustedColumnWidth = actualColumnWidth;
            adjustedColumnWidth(isFlex & ~isAdjusted) = comp.InternalColumnWidth(isFlex & ~isAdjusted);

            comp.AdjustedColumnWidth = adjustedColumnWidth;
        end

        function updateColumnFlexWeights(comp)
        % updateColumnFlexWeights - Updates the ColumnFlexWeights property
        %
        %   Should be called if ColumnWidth is changed.
            isFlexUnit = comp.isFlexSize(comp.InternalColumnWidth);
            
            flexWeights = zeros( size(comp.InternalColumnWidth) );
            for i = 1:comp.NumColumns
                if isFlexUnit(i)
                    width = comp.InternalColumnWidth{i};
                    flexWeights(i) = str2double(extractBefore(width, 'x'));
                end
            end
            comp.ColumnFlexWeights = flexWeights;
        end
    
        function rowPadding = getRowPadding(comp)
            paddingLeft = comp.TablePadding(1);
            paddingBottom = ceil(comp.RowSpacing/2);
            paddingRight = comp.ColumnSpacing; % Why?
            paddingTop = floor(comp.RowSpacing/2);

            rowPadding = [paddingLeft, paddingBottom, paddingRight, paddingTop];
        end
            
        function availableWidth = getAvailableHorizontalSpace(comp)
        % getAvailableHorizontalSpace - Get available horizontal space for columns
        %
        % Returns the available horizontal space after removing column spacing 
        % and table padding.

            % Get width of container.
            gridPosition = getpixelposition(comp.TableRowGridLayout, true);
            totalWidth = round(gridPosition(3));

            totalColumnSpacing = comp.ColumnSpacing * (comp.NumColumns - 1);
            horizontalPadding = sum( comp.TablePadding([1,3]) );
            
            availableWidth = totalWidth - totalColumnSpacing - horizontalPadding;
        end
        
        function w = getWidthFromConfigProperties(comp)
            if ~isempty(comp.ColumnWidth)
                w = numel(comp.ColumnWidth);
            elseif ~isempty(comp.ColumnNames)
                w = numel(comp.ColumnNames);
            else
                w = 0;
            end
        end
    
        function [rowInd, colInd] = getCellForPointer(comp, hFigure)
        % getCellForPointer - Get cell where pointer is located.    
            
            % Todo: Consider x-scroll offset?
            xScrollOffset = comp.TableRowGridLayout.ScrollableViewportLocation(1);
            yScrollOffset = comp.TableRowGridLayout.ScrollableViewportLocation(2);

            xPoint = hFigure.CurrentPoint(1);
            yPoint = hFigure.CurrentPoint(2);

            colExtent = comp.computeColumnExtents( comp.TableRowGridLayout );
            rowExtent = comp.TableRowGridLayout.RowHeight{1} + comp.TableRowGridLayout.RowSpacing;

            %pos = getpixelposition(comp.TableRowGridLayout, true);
            pos = comp.CachedTableRowGridPosition;
            y0 = pos(2);
            yPoint = yPoint-y0;
            
            yOffsetFromTop = pos(4) - yPoint - yScrollOffset;

            rowInd = ceil(yOffsetFromTop/rowExtent);
            colInd = getGridColumnIndexForPoint(comp.RowGridLayout(1), xPoint);
            
            % Make sure returned indices are within bounds of table
            if rowInd < 1 || rowInd > comp.Height
                rowInd = -1;
            end

            if colInd < 1 || colInd > comp.NumColumns
                colInd = -1;
            end
        end
    end

    methods (Access = private) % Table data related operations
        function iRowData = getDataRowIndex(comp, iRow)
            if comp.EnableAddRows
                iRowData = iRow-1;
            else
                iRowData = iRow;
            end
        end

        function iColData = getDataColumnIndex(comp, iColumn)
            if comp.EnableAddRows
                iColData = iColumn-1;
            else
                iColData = iColumn;
            end
        end

        function iColData = getViewColumnIndex(comp, iColumn)
            if comp.EnableAddRows
                iColData = iColumn+1;
            else
                iColData = iColumn;
            end
        end

        function rowData = getRowData(comp, rowIndex)
            if isa(comp.Data, 'table')
                rowData = comp.Data(rowIndex, :);

            elseif isa(comp.Data, 'struct')
                rowData = comp.Data(rowIndex);
            end
        end

        function cellValue = getCellValue(comp, rowIndex, columnIndex)
            if isa(comp.Data, 'table')
                cellValue = comp.Data{rowIndex, columnIndex};

            elseif isa(comp.Data, 'struct')
                colNames = fieldnames(comp.Data);
                cellValue = comp.Data(rowIndex).(colNames{columnIndex});
            end
        end

        function cellValue = setCellValue(comp, rowIndex, columnIndex, cellValue)
            if isa(comp.Data, 'table')
                cellValue = comp.ensureCorrectType(cellValue, comp.Data_{rowIndex, columnIndex});
                comp.Data_{rowIndex, columnIndex} = cellValue;
            elseif isa(comp.Data, 'struct')
                colNames = fieldnames(comp.Data);
                comp.Data_(rowIndex).(colNames{columnIndex}) = cellValue;
            end
            if ~nargout
                clear cellValue
            end
        end

        function updateComponentValue(comp, iRow, iColumn, cellValue)
            iColumn = comp.getViewColumnIndex(iColumn);
            hControl = comp.RowComponents{iRow, iColumn};

            switch class(cellValue)
                case {'uint8', 'uint16'}
                    cellValue = double(cellValue);
                case 'categorical'
                    cellValue = char(cellValue);
            end

            if isprop(hControl, 'Value')
                hControl.Value = cellValue;
            end
        end

        function appendRowData(comp, rowData)

            if isa(comp.Data, 'table')
                comp.Data_ = cat(1, comp.Data, rowData);

            elseif isa(comp.Data, 'struct')
                if icolumn(comp.Data)
                    comp.Data_ = cat(1, comp.Data, rowData);
                else
                    comp.Data_ = cat(2, comp.Data, rowData);
                end
            end
        end

        function removeDataRow(comp, rowIndex)
            if isa(comp.Data, 'table')
                comp.Data_(rowIndex,:) = [];

            elseif isa(comp.Data, 'struct')
                comp.Data_(rowIndex) = [];
            end
        end
    end

    methods (Access = private, Static)
        function rowData = resetData(rowData)
            if istable(rowData)
                for iCol = 1:size(rowData, 2)
                    if isnumeric(rowData{1,iCol})
                        rowData{1,iCol} = 0;
                    elseif isstring(rowData{1,iCol})
                        rowData{1,iCol} = "";
                    elseif iscategorical(rowData{1,iCol})
                        C = categories(rowData{1,iCol});
                        rowData{1,iCol} = categorical(C(1),C');
                    end
                end
            elseif isstruct(rowData)

            end
        end
        
        function cellValue = ensureCorrectType(cellValue, referenceValue)
            if isa(referenceValue, 'categorical')
                valueSet = categories(referenceValue);
                if isnumeric(cellValue)
                    cellValue = categorical(valueSet(cellValue), valueSet);
                else
                    cellValue = categorical({cellValue}, valueSet);
                end
            else
                type = class(referenceValue);
                cellValue = feval(type, cellValue);
            end
        end

        function colExtent = computeColumnExtents( hGridLayout )
            pos = getpixelposition(hGridLayout);
            
            w = pos(3);
            w = w - sum( hGridLayout.Padding([1,3]));
            
            numColumns = numel(hGridLayout.ColumnWidth);
            w = w - hGridLayout.ColumnSpacing * (numColumns-1);

            columnWidths = hGridLayout.ColumnWidth;

            isRelative = cellfun(@(c) ischar(c), hGridLayout.ColumnWidth);
            if any(isRelative)
                w = w - sum( [hGridLayout.ColumnWidth{~isRelative}] );
    
                relativeW = hGridLayout.ColumnWidth(isRelative);
                relativeW = cellfun(@(c) str2double( c(1:end-1)), relativeW);
                relativeW = (relativeW * w) / sum(relativeW);
    
                columnWidths(isRelative) = num2cell(relativeW);
            end
            columnWidths = cell2mat(columnWidths);

            colExtent = [0, cumsum(columnWidths) + (1:numColumns)*hGridLayout.ColumnSpacing];
            colExtent(end) = pos(3);
        end

        function saveTransparentBackground()
            im = zeros(128,128);
            alpha = zeros(128,128);
            filePath = fullfile(WidgetTable.ML_COMP_PATH, 'resources', 'label_background.png');
            imwrite(im, filePath, 'png', "Alpha", alpha)
        end
    
        function flexC = addFlexUnit(flexA, flexB)
            flexA = str2double(extractBefore(flexA, 'x'));
            if ischar(flexB) && endsWith(flexB, 'x')
                flexB = extractBefore(flexB, 'x');
            end
            flexC = sprintf('%.2fx', flexA+flexB);
        end
    
        function tf = isFlexSize(value)
            isOfFormNx = @(x) ischar(x) && endsWith(x, 'x');

            if iscell(value)
                tf = cellfun(@(c) isOfFormNx(c), value);
            else
                tf = isOfFormNx(value);
            end
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function postSetupFcn(comp)
            comp.createDummyGrid()
            
            comp.createViewportListener()
            comp.createSizeChangedListener()
            comp.createWindowMouseMotionListener()

            comp.updateInternalColumnWidth()
            comp.updateTableColumnWidth()
            comp.updateTableRowHeight()

            comp.createRows()
            comp.resizeTableColumns()

            comp.updateBackgroundColor()
            comp.CachedTableRowGridPosition = getpixelposition(comp.TableRowGridLayout, true);
        end
    end

    methods (Access = protected)
        
        % Code that executes when the value of a public property is changed
        function update(comp)
            % Use this function to update the underlying components
            comp.updateBackgroundColor()
        end

        % Create the underlying components
        function setup(comp)

            comp.Position = [1 1 586 268];
            comp.BackgroundColor = [0.94 0.94 0.94];

            % Create ComponentGridLayout
            comp.ComponentGridLayout = uigridlayout(comp);
            comp.ComponentGridLayout.ColumnWidth = {'1x'};
            comp.ComponentGridLayout.RowHeight = {'1x'};
            comp.ComponentGridLayout.ColumnSpacing = 0;
            comp.ComponentGridLayout.RowSpacing = 0;
            comp.ComponentGridLayout.Padding = [0 0 0 0];
            comp.ComponentGridLayout.BackgroundColor = [1 1 1];

            % Create TablePanel
            comp.TablePanel = uipanel(comp.ComponentGridLayout);
            comp.TablePanel.BackgroundColor = [1 1 1];
            comp.TablePanel.Layout.Row = 1;
            comp.TablePanel.Layout.Column = 1;

            % Create TableGridLayout
            comp.TableGridLayout = uigridlayout(comp.TablePanel);
            comp.TableGridLayout.ColumnWidth = {'1x'};
            comp.TableGridLayout.RowHeight = {30, 1, '1x'};
            comp.TableGridLayout.ColumnSpacing = 0;
            comp.TableGridLayout.RowSpacing = 0;
            comp.TableGridLayout.Padding = [0 0 0 0];
            comp.TableGridLayout.Scrollable = 'on';
            comp.TableGridLayout.BackgroundColor = [1 1 1];

            % Create TableRowPanel
            comp.TableRowPanel = uipanel(comp.TableGridLayout);
            comp.TableRowPanel.BorderWidth = 0;
            comp.TableRowPanel.BackgroundColor = [1 1 1];
            comp.TableRowPanel.Layout.Row = 3;
            comp.TableRowPanel.Layout.Column = 1;

            % Create TableRowGridLayout
            comp.TableRowGridLayout = uigridlayout(comp.TableRowPanel);
            comp.TableRowGridLayout.ColumnWidth = {'1x'};
            comp.TableRowGridLayout.RowHeight = {20, 20, 20, 20, 20, 20, 20, 20};
            comp.TableRowGridLayout.ColumnSpacing = 1;
            comp.TableRowGridLayout.RowSpacing = 0;
            comp.TableRowGridLayout.Padding = [0 10 0 4];
            comp.TableRowGridLayout.Scrollable = 'on';
            comp.TableRowGridLayout.BackgroundColor = [1 1 1];

            % Create HeaderSeparator
            comp.HeaderSeparator = uipanel(comp.TableGridLayout);
            comp.HeaderSeparator.BorderType = 'none';
            comp.HeaderSeparator.BackgroundColor = [0 0 0];
            comp.HeaderSeparator.Tag = 'HeaderSeparator';
            comp.HeaderSeparator.Layout.Row = 2;
            comp.HeaderSeparator.Layout.Column = 1;

            % Create TableHeaderPanel
            comp.TableHeaderPanel = uipanel(comp.TableGridLayout);
            comp.TableHeaderPanel.BorderType = 'none';
            comp.TableHeaderPanel.BackgroundColor = [1 1 1];
            comp.TableHeaderPanel.Layout.Row = 1;
            comp.TableHeaderPanel.Layout.Column = 1;

            % Create HeaderGridLayout
            comp.HeaderGridLayout = uigridlayout(comp.TableHeaderPanel);
            comp.HeaderGridLayout.ColumnWidth = {'1x'};
            comp.HeaderGridLayout.RowHeight = {'1x'};
            comp.HeaderGridLayout.ColumnSpacing = 1;
            comp.HeaderGridLayout.Padding = [0 0 0 0];
            comp.HeaderGridLayout.BackgroundColor = [1 1 1];
            
            % Execute the startup function
            postSetupFcn(comp)
        end
    end
end
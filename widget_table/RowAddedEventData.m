classdef RowAddedEventData < matlab.ui.eventdata.internal.AbstractEventData
    properties
        RowIndex
        RowData
    end
    
    methods
        % Constructor
        function obj = RowAddedEventData(rowIndex, rowData)
            obj.RowIndex = rowIndex;
            obj.RowData = rowData;
        end
    end
end

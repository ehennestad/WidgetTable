classdef CellEditEventData < matlab.ui.eventdata.internal.AbstractEventData
    properties
        Indices
        DisplayIndices
        ColumnName
        PreviousData
        EditData
        NewData
    end
    
    methods
        % Constructor
        function obj = CellEditEventData(indices, displayIndices, columnName, previousData, editData, newData)
            obj.Indices = indices;
            obj.DisplayIndices = displayIndices;
            obj.ColumnName = columnName;
            obj.PreviousData = previousData;
            obj.EditData = editData;
            obj.NewData = newData;
        end
    end
end

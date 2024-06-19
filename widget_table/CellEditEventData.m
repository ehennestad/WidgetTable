classdef CellEditEventData < matlab.ui.eventdata.internal.AbstractEventData
    properties
        Indices
        DisplayIndices
        PreviousData
        EditData
        NewData
    end
    
    methods
        % Constructor
        function obj = CellEditEventData(indices, displayIndices, previousData, editData, newData)
            obj.Indices = indices;
            obj.DisplayIndices = displayIndices;
            obj.PreviousData = previousData;
            obj.EditData = editData;
            obj.NewData = newData;
        end
    end
end

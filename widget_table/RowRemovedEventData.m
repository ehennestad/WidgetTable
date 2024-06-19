classdef RowRemovedEventData < event.EventData
    properties
        RowIndex
    end
    
    methods
        % Constructor
        function obj = RowRemovedEventData(rowIndex)
            obj.RowIndex = rowIndex;
        end
    end
end

function textExtent = getTextExtent(textString, fontStyle)
% getTextExtent - Get the pixel extent of a text string with specified font properties.
%
% DESCRIPTION:
%   This function returns the pixel extent (width and height) of a given text 
%   string when rendered with specified font properties. It uses a persistent 
%   text object to measure the extent, ensuring efficient execution for 
%   repeated calls.
%
% SYNTAX:
%   textExtent = getTextExtent(textString) returns the pixel extent [x,y]
%       for a text string
%
%   textExtent = getTextExtent(textString, name, value, ...) returns the pixel 
%       extent [x,y] for a text string with specified font properties.
%
% INPUTS:
%   textString  - (string) The text string to measure pixel extent of.
%
% OPTIONS (optional name, value pairs):
%    - Name   : (string) Font name. Default is 'Helvetica'.
%    - Size   : (double) Font size in points. Default is 12.
%    - Weight : (string) Font weight. Must be one of 'normal', 'bold'.
%               Default is 'normal'.
%    - Angle  : (string) Font angle. Must be one of 'normal', 'italic'.
%               Default is 'normal'.
%
% OUTPUT:
%   textExtent  - (1x2 double) The width and height of the text string in pixels, 
%                 returned as a two-element vector [width, height].
%
% EXAMPLE:
%   extent = getTextExtent("Hello, World!", 'Size', 14, 'Weight', 'bold', 'Name', 'Arial');
%   fprintf('Width: %.2f, Height: %.2f\n', extent(1), extent(2));
%
% NOTES:
%   * The function uses a hidden figure to measure the text extent. The figure 
%     is created once and reused for subsequent calls to improve performance.
%   * The figure is deleted when the function is cleared from memory.
%
% AUTHOR:
%   Eivind Hennestad
%
% VERSION:
%   1.0 (Date: 2024-06-15) Compatibility: MATLAB 2019b and later

    arguments
        textString (1,1) string
        fontStyle.Name (1,1) string = 'Helvetica'
        fontStyle.Size (1,1) double = 12
        fontStyle.Weight (1,1) string {mustBeMember(fontStyle.Weight, ["normal", "bold"])} = 'normal'
        fontStyle.Angle (1,1) string {mustBeMember(fontStyle.Angle, ["normal", "italic"])} = 'normal'
        fontStyle.Units (1,1) string {mustBeMember(fontStyle.Units, ["pixels", "points"])} = 'points'
    end
    
    persistent hText cleanUpObject

    if isempty(hText) || ~isvalid(hText)
        % Create a figure and axes
        hFigure = figure('Visible', 'off', 'MenuBar', 'none');
        hFigure.HandleVisibility = 'off';
        hFigure.Tag = 'getTextExtent';
        ax = axes(hFigure);
        
        % Create a text object
        hText = text(ax, 0.5, 0.5, '', 'Units', 'pixels');
        
        % Create a cleanup function that deletes the figure
        cleanUpObject = onCleanup( @(f) delete(hFigure) );
    end

    if ~any(strcmpi(fontStyle.Name, listfonts))
        warning('Font is not supported, extent might be inaccurate')
    end

    hText.String = textString;
    set(hText, ...
        'FontName', fontStyle.Name, ...
        'FontSize', fontStyle.Size, ...
        'FontWeight', fontStyle.Weight, ...
        'FontAngle', fontStyle.Angle, ...
        'FontUnits', fontStyle.Units)
    
    % Get the extent of the text object
    textExtent = hText.Extent(3:4);
end

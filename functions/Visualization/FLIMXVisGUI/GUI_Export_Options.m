function varargout = GUI_Export_Options(varargin)
%=============================================================================================================
%
% @file     GUI_Export_Options.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  1.0
% @date     July, 2015
%
% @section  LICENSE
%
% Copyright (C) 2015, Matthias Klemm. All rights reserved.
%
% Redistribution and use in source and binary forms, with or without modification, are permitted provided that
% the following conditions are met:
%     * Redistributions of source code must retain the above copyright notice, this list of conditions and the
%       following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
%       the following disclaimer in the documentation and/or other materials provided with the distribution.
%     * Neither the name of FLIMX authors nor the names of its contributors may be used
%       to endorse or promote products derived from this software without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
% WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
% PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
% INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
% PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
% HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%
%
% @brief    A GUI to set export options FLIMXVis
%
%input: 
% vargin - structure with preferences and defaults
%output: same as input, but altered according to user input

% Last Modified by GUIDE v2.5 14-Feb-2012 19:26:40

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_Export_Options_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_Export_Options_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before GUI_Rosediagram_options is made visible.
function GUI_Export_Options_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_Rosediagram_options (see VARARGIN)



rdh = varargin{1};
%read current settings and draw them
%set(handles.cipopup,'String','99%|95%|90%');
%set(handles.cipopup,'Value',1);
updateGUI(handles, rdh.prefs);  
set(handles.exportOptionsGUIFigure,'userdata',rdh);


% Choose default command line output for GUI_Rosediagram_options
%handles.output = hObject;

% Update handles structure
%guidata(hObject, handles);

% UIWAIT makes GUI_Rosediagram_options wait for user response (see UIRESUME)
uiwait(handles.exportOptionsGUIFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_Export_Options_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=0;
    varargout{1} = 0;
else
    out = get(handles.exportOptionsGUIFigure,'userdata'); 
    varargout{1} = out;
    delete(handles.exportOptionsGUIFigure);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles,data)
set(handles.editDpi,'String',num2str(data.dpi));
set(handles.checkColorbar,'Value',data.plotColorbar);
idx = find(strcmp(data.colorbarLocation,get(handles.popupColorbarLocation,'String')),1);
set(handles.popupColorbarLocation,'Value',idx);
set(handles.editPlotLinewidth,'String',num2str(data.plotLinewidth));
set(handles.editLabelFontsize,'String',num2str(data.labelFontSize));
set(handles.popupAspectRatio,'Value',data.autoAspectRatio+1);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%radio buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on selection change in popupColorbarLocation.
function popupColorbarLocation_Callback(hObject, eventdata, handles)
rdh = get(handles.exportOptionsGUIFigure,'userdata');
str = get(hObject,'String');
rdh.prefs.colorbarLocation = str{get(hObject,'Value')};
set(handles.exportOptionsGUIFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

% --- Executes on selection change in popupAspectRatio.
function popupAspectRatio_Callback(hObject, eventdata, handles)
rdh = get(handles.exportOptionsGUIFigure,'userdata');
rdh.prefs.autoAspectRatio = get(hObject,'Value')-1;
set(handles.exportOptionsGUIFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%checkboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in checkColorbar.
function checkColorbar_Callback(hObject, eventdata, handles)
rdh = get(handles.exportOptionsGUIFigure,'userdata');
rdh.prefs.plotColorbar = get(hObject,'Value');
set(handles.exportOptionsGUIFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function editDpi_Callback(hObject, eventdata, handles)
rdh = get(handles.exportOptionsGUIFigure,'userdata');
rdh.prefs.dpi = abs(str2double(get(hObject,'String')));
set(handles.exportOptionsGUIFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editPlotLinewidth_Callback(hObject, eventdata, handles)
rdh = get(handles.exportOptionsGUIFigure,'userdata');
rdh.prefs.plotLinewidth = abs(str2double(get(hObject,'String')));
set(handles.exportOptionsGUIFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editLabelFontsize_Callback(hObject, eventdata, handles)
rdh = get(handles.exportOptionsGUIFigure,'userdata');
rdh.prefs.labelFontSize = abs(str2double(get(hObject,'String')));
set(handles.exportOptionsGUIFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in defaultbutton.
function defaultbutton_Callback(hObject, eventdata, handles)
rdh = get(handles.exportOptionsGUIFigure,'userdata');
%overwrite default values one by one - we don't want to delete parameters
%which are not from this gui
rdh.prefs.dpi = rdh.defaults.dpi;

set(handles.exportOptionsGUIFigure,'userdata',rdh);
updateGUI(handles, rdh.defaults); 


% --- Executes on button press in okbutton.
function okbutton_Callback(hObject, eventdata, handles)
uiresume(handles.exportOptionsGUIFigure);


% --- Executes on button press in cancelbutton.
function cancelbutton_Callback(hObject, eventdata, handles)
uiresume(handles.exportOptionsGUIFigure);
delete(handles.exportOptionsGUIFigure);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function editDpi_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupColorbarLocation_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editPlotLinewidth_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editLabelFontsize_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupAspectRatio_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

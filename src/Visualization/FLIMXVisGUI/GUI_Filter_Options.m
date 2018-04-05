function varargout = GUI_Filter_Options(varargin)
%=============================================================================================================
%
% @file     GUI_Filter_Options.m
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
% @brief    A GUI to set spatial filtering options in FLIMXVis
%
%input: 
% vargin - structure with preferences and defaults
%output: same as input, but altered according to user input

% Last Modified by GUIDE v2.5 02-Jan-2011 18:45:22

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_Filter_Options_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_Filter_Options_OutputFcn, ...
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
function GUI_Filter_Options_OpeningFcn(hObject, eventdata, handles, varargin)
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
set(handles.filterOptionsFigure,'userdata',rdh);


% Choose default command line output for GUI_Rosediagram_options
%handles.output = hObject;

% Update handles structure
%guidata(hObject, handles);

% UIWAIT makes GUI_Rosediagram_options wait for user response (see UIRESUME)
uiwait(handles.filterOptionsFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_Filter_Options_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=0;
    varargout{1} = 0;
else
    out = get(handles.filterOptionsFigure,'userdata'); 
    varargout{1} = out;
    delete(handles.filterOptionsFigure);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles,data)
set(handles.ifilter_check,'Value',data.ifilter);
if(data.ifilter)
    arg_str = 'on';
else
    arg_str = 'off';
end
set(handles.ifilter_type_text,'Enable',arg_str);
set(handles.ifilter_type_pop,'Enable',arg_str,'Value',data.ifilter_type);
set(handles.ifilter_size_text,'Enable',arg_str);
if(data.ifilter_type == 3)
    set(handles.ifilter_size_pop,'Value',data.ifilter_size-2,'Visible','off');
else
    set(handles.ifilter_size_pop,'Value',data.ifilter_size-2,'Visible',arg_str);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%radio buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on selection change in ifilter_type_pop.
function ifilter_type_pop_Callback(hObject, eventdata, handles)
rdh = get(handles.filterOptionsFigure,'userdata');
rdh.prefs.ifilter_type = get(hObject,'Value');
set(handles.filterOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

% --- Executes on selection change in ifilter_size_pop.
function ifilter_size_pop_Callback(hObject, eventdata, handles)
rdh = get(handles.filterOptionsFigure,'userdata');
rdh.prefs.ifilter_size = get(hObject,'Value')+2;
set(handles.filterOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%checkboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in ifilter_check.
function ifilter_check_Callback(hObject, eventdata, handles)
rdh = get(handles.filterOptionsFigure,'userdata');
rdh.prefs.ifilter = get(hObject,'Value');
set(handles.filterOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Executes on button press in defaultbutton.
function defaultbutton_Callback(hObject, eventdata, handles)
rdh = get(handles.filterOptionsFigure,'userdata');
%overwrite default values one by one - we don't want to delete parameters
%which are not from this gui
rdh.prefs.ifilter_check = rdh.defaults.ifilter;
rdh.prefs.ifilter_type = rdh.defaults.ifilter_type;
rdh.prefs.ifilter_size = rdh.defaults.ifilter_size;

set(handles.filterOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh.defaults); 


% --- Executes on button press in okbutton.
function okbutton_Callback(hObject, eventdata, handles)
uiresume(handles.filterOptionsFigure);


% --- Executes on button press in cancelbutton.
function cancelbutton_Callback(hObject, eventdata, handles)
uiresume(handles.filterOptionsFigure);
delete(handles.filterOptionsFigure);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function ifilter_type_pop_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function ifilter_size_pop_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

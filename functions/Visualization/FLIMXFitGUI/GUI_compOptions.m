function varargout = GUI_compOptions(varargin)
%=============================================================================================================
%
% @file     GUI_compOptions.m
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
% @brief    A GUI to set computation options in FLIMXFit
%
% GUI_COMPOPTIONS M-file for GUI_compOptions.fig
%      GUI_COMPOPTIONS, by itself, creates a new GUI_COMPOPTIONS or raises the existing
%      singleton*.
%
%      H = GUI_COMPOPTIONS returns the handle to a new GUI_COMPOPTIONS or the handle to
%      the existing singleton*.
%
%      GUI_COMPOPTIONS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_COMPOPTIONS.M with the given input arguments.
%
%      GUI_COMPOPTIONS('Property','Value',...) creates a new GUI_COMPOPTIONS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_compOptions_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_compOptions_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_compOptions

% Last Modified by GUIDE v2.5 10-Oct-2013 16:15:01

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_compOptions_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_compOptions_OutputFcn, ...
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


% --- Executes just before GUI_compOptions is made visible.
function GUI_compOptions_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_compOptions (see VARARGIN)

% Choose default command line output for GUI_compOptions
% handles.output = hObject;

% Update handles structure
% guidata(hObject, handles);
rdh.computation = varargin{1};
updateGUI(handles, rdh);  
set(handles.compOptionsFigure,'userdata',rdh);

% UIWAIT makes GUI_compOptions wait for user response (see UIRESUME)
uiwait(handles.compOptionsFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_compOptions_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=[];
    varargout{1} = [];
else
    out = get(handles.compOptionsFigure,'userdata');
    varargout{1} = out;
    delete(handles.compOptionsFigure);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles,data)
%update GUI to current values
switch data.computation.useDistComp
    case 0
        set(handles.radioLocal,'Value',1);
        set(handles.radioMulticore,'Value',0);
        flag = 'off'; 
    case 1
        set(handles.radioLocal,'Value',0);
        set(handles.radioMulticore,'Value',1);
        flag = 'on';
end
set(handles.editMCPixelPerWU,'String',num2str(data.computation.mcTargetPixelPerWU),'Enable',flag);
set(handles.editMCWUs,'String',num2str(data.computation.mcTargetNrWUs),'Enable',flag);
set(handles.textMCPixelPerWU,'Enable',flag);
set(handles.textMCWUs,'Enable',flag);
set(handles.checkMCWorkLocal,'Value',data.computation.mcWorkLocal,'Enable',flag);
set(handles.editMCPath,'String',data.computation.mcShare,'Enable',flag);
set(handles.checkMatlabDistComp,'Value',logical(data.computation.useMatlabDistComp));
set(handles.checkMatlabGPU,'Value',logical(data.computation.useGPU));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%checkboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in checkMCWorkLocal.
function checkMCWorkLocal_Callback(hObject, eventdata, handles)
rdh = get(handles.compOptionsFigure,'userdata');
rdh.computation.mcWorkLocal = get(hObject,'Value');
set(handles.compOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in checkMatlabDistComp.
function checkMatlabDistComp_Callback(hObject, eventdata, handles)
rdh = get(handles.compOptionsFigure,'userdata');
rdh.computation.useMatlabDistComp = get(hObject,'Value');
set(handles.compOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in checkMatlabGPU.
function checkMatlabGPU_Callback(hObject, eventdata, handles)
rdh = get(handles.compOptionsFigure,'userdata');
rdh.computation.useGPU = get(hObject,'Value');
set(handles.compOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editMCWUs_Callback(hObject, eventdata, handles)
rdh = get(handles.compOptionsFigure,'userdata');
rdh.computation.mcTargetNrWUs = round(abs(str2double(get(hObject,'String'))));
set(handles.compOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.computation.mcTargetNrWUs));


function editMCPath_Callback(hObject, eventdata, handles)
%
rdh = get(handles.compOptionsFigure,'userdata');
rdh.computation.mcShare = get(hObject,'String');
set(handles.compOptionsFigure,'userdata',rdh);

function editMCPixelPerWU_Callback(hObject, eventdata, handles)
%
rdh = get(handles.compOptionsFigure,'userdata');
rdh.computation.mcTargetPixelPerWU = round(abs(str2double(get(hObject,'String'))));
set(handles.compOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.computation.mcTargetPixelPerWU));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%radio buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in radioLocal.
function radioLocal_Callback(hObject, eventdata, handles)
rdh = get(handles.compOptionsFigure,'userdata');
rdh.computation.useDistComp = 0;
set(handles.compOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

function radioMulticore_Callback(hObject, eventdata, handles)
rdh = get(handles.compOptionsFigure,'userdata');
rdh.computation.useDistComp = 1;
set(handles.compOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh); 


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
uiresume(handles.compOptionsFigure);

% --- Executes on button press in buttonCancel.
function buttonCancel_Callback(hObject, eventdata, handles)
uiresume(handles.compOptionsFigure);
delete(handles.compOptionsFigure);

% --- Executes on button press in buttonMCPath.
function buttonMCPath_Callback(hObject, eventdata, handles)
%
rdh = get(handles.compOptionsFigure,'userdata');
path = uigetdir(rdh.computation.mcShare);
if(path)
    rdh.computation.mcShare = path;
    set(handles.compOptionsFigure,'userdata',rdh);
    updateGUI(handles, rdh);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%tables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function editMCWUs_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editMCPath_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editMCPixelPerWU_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

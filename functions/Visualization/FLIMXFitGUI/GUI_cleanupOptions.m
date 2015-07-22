function varargout = GUI_cleanupOptions(varargin)
%=============================================================================================================
%
% @file     GUI_cleanupOptions.m
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
% @brief    A GUI to set parameters for the cleanup fit in FLIMXFit
%
% GUI_CLEANUPOPTIONS M-file for GUI_cleanupOptions.fig
%      GUI_CLEANUPOPTIONS, by itself, creates a new GUI_CLEANUPOPTIONS or raises the existing
%      singleton*.
%
%      H = GUI_CLEANUPOPTIONS returns the handle to a new GUI_CLEANUPOPTIONS or the handle to
%      the existing singleton*.
%
%      GUI_CLEANUPOPTIONS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_CLEANUPOPTIONS.M with the given input arguments.
%
%      GUI_CLEANUPOPTIONS('Property','Value',...) creates a new GUI_CLEANUPOPTIONS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_cleanupOptions_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_cleanupOptions_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_cleanupOptions

% Last Modified by GUIDE v2.5 22-Jul-2014 13:27:23

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_cleanupOptions_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_cleanupOptions_OutputFcn, ...
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


% --- Executes just before GUI_cleanupOptions is made visible.
function GUI_cleanupOptions_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_cleanupOptions (see VARARGIN)

% Choose default command line output for GUI_cleanupOptions
% handles.output = hObject;

% Update handles structure
% guidata(hObject, handles);
rdh.cleanup_fit = varargin{1};
rdh.volatilePixel = varargin{2};
updateGUI(handles, rdh);  
set(handles.cleanupOptionsFigure,'userdata',rdh);

% UIWAIT makes GUI_cleanupOptions wait for user response (see UIRESUME)
uiwait(handles.cleanupOptionsFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_cleanupOptions_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=[];
    varargout{1} = [];
else
    out = get(handles.cleanupOptionsFigure,'userdata');
    varargout{1} = out;
    delete(handles.cleanupOptionsFigure);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles,data)
%update GUI to current values
if(data.cleanup_fit.enable)
    enableFlag = 'on';
else
    enableFlag = 'off';
end
set(handles.checkEnable,'Value',data.cleanup_fit.enable);
set(handles.editIterations,'Enable',enableFlag,'String',num2str(data.cleanup_fit.iterations));
set(handles.editFilterSize,'Enable',enableFlag,'String',num2str(data.cleanup_fit.filterSize));
set(handles.popupFilterType,'Enable',enableFlag,'Value',data.cleanup_fit.filterType);
td(:,1) = data.volatilePixel.modelParamsString;
idx = strncmp('Amplitude',td,9);
for i = 1:sum(idx)
    td{end+1,1} = sprintf('AmplitudePercent %d',i);
    td{end+1,1} = sprintf('Q %d',i);
    td{end+1,1} = sprintf('RAUC %d',i);    
end
td{end+1,1} = 'TauMean';
td{end+1,1} = 'chi2';
td{end+1,1} = 'chi2Tail';
td = sort(td);
td(:,2) = num2cell(30*ones(size(td))); %default threshold of 30%
td(:,3) = num2cell(false(size(td,1),1));
%update with values from ini
for i = 1:length(data.cleanup_fit.target)
    idx = find(strcmp(data.cleanup_fit.target{i},td),1);
    if(~isempty(idx))
        td{idx,2} = data.cleanup_fit.threshold(i)*100;
        td{idx,3} = true;
    end
end
set(handles.tableParameters,'Enable',enableFlag,'Data',td);
set(handles.tableParameters,'ColumnName',{'Parameter','Threshold (%)','Enable'});
set(handles.tableParameters,'ColumnWidth',{100,90,40});
set(handles.tableParameters,'ColumnEditable',[false,true,true]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%checkboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in checkEnable.
function checkEnable_Callback(hObject, eventdata, handles)
rdh = get(handles.cleanupOptionsFigure,'userdata');
rdh.cleanup_fit.enable = get(hObject,'Value');
set(handles.cleanupOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function editIterations_Callback(hObject, eventdata, handles)
%
rdh = get(handles.cleanupOptionsFigure,'userdata');
rdh.cleanup_fit.iterations = round(abs(str2double(get(hObject,'String'))));
set(handles.cleanupOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.cleanup_fit.iterations));

function editFilterSize_Callback(hObject, eventdata, handles)
%
rdh = get(handles.cleanupOptionsFigure,'userdata');
rdh.cleanup_fit.filterSize = max(1,floor(abs(str2double(get(hObject,'String')))/2)*2+1);
set(handles.cleanupOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.cleanup_fit.filterSize));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%radio buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
uiresume(handles.cleanupOptionsFigure);

% --- Executes on button press in buttonCancel.
function buttonCancel_Callback(hObject, eventdata, handles)
uiresume(handles.cleanupOptionsFigure);
delete(handles.cleanupOptionsFigure);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Executes on selection change in popupFilterType.
function popupFilterType_Callback(hObject, eventdata, handles)
%
rdh = get(handles.cleanupOptionsFigure,'userdata');
rdh.cleanup_fit.filterType = get(hObject,'Value');
set(handles.cleanupOptionsFigure,'userdata',rdh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%tables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes when entered data in editable cell(s) in tableParameters.
function tableParameters_CellEditCallback(hObject, eventdata, handles)
%
data = get(hObject,'Data');
rdh = get(handles.cleanupOptionsFigure,'userdata');
data = data([data{:,3}],:);
rdh.cleanup_fit.target = data(:,1);
rdh.cleanup_fit.threshold = [data{:,2}]./100;
set(handles.cleanupOptionsFigure,'userdata',rdh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function editIterations_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupFilterType_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editFilterSize_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

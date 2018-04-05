function varargout = GUI_subjectFileInfo(varargin)
%=============================================================================================================
%
% @file     GUI_subjectFileInfo.m
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
% @brief    A GUI to change location and scaling of a subject
%
% GUI_SUBJECTFILEINFO MATLAB code for GUI_subjectFileInfo.fig
%      GUI_SUBJECTFILEINFO, by itself, creates a new GUI_SUBJECTFILEINFO or raises the existing
%      singleton*.
%
%      H = GUI_SUBJECTFILEINFO returns the handle to a new GUI_SUBJECTFILEINFO or the handle to
%      the existing singleton*.
%
%      GUI_SUBJECTFILEINFO('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_SUBJECTFILEINFO.M with the given input arguments.
%
%      GUI_SUBJECTFILEINFO('Property','Value',...) creates a new GUI_SUBJECTFILEINFO or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_subjectFileInfo_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_subjectFileInfo_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_subjectFileInfo

% Last Modified by GUIDE v2.5 17-Dec-2013 15:55:51

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_subjectFileInfo_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_subjectFileInfo_OutputFcn, ...
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


% --- Executes just before GUI_subjectFileInfo is made visible.
function GUI_subjectFileInfo_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_subjectFileInfo (see VARARGIN)

% Choose default command line output for GUI_subjectFileInfo
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

rdh.position = varargin{1};
rdh.resolution = varargin{2};
if(isempty(rdh.resolution))
    delete(handles.subjectFileInfoFigure);
else
    if(isempty(rdh.position))
        idx = 1;
        en = 'off';
    elseif(strcmp(rdh.position,'OD'))
        idx = 1;
        en = 'on';
    else
        idx = 2;
        en = 'on';
    end
    set(handles.subjectFileInfoFigure,'userdata',rdh);
    set(handles.editResolution,'String',rdh.resolution);   
    set(handles.popupPosition,'Value',idx,'Enable',en);    
    % UIWAIT makes GUI_subjectFileInfo wait for user response (see UIRESUME)
    uiwait(handles.subjectFileInfoFigure);
end

% --- Outputs from this function are returned to the command line.
function varargout = GUI_subjectFileInfo_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if(isempty(handles))
    varargout{1} = [];
    varargout{2} = [];
else
    rdh = get(handles.subjectFileInfoFigure,'userdata');
    varargout{1} = rdh.position;% handles.output;
    varargout{2} = rdh.resolution;
    delete(handles.subjectFileInfoFigure);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
uiresume(handles.subjectFileInfoFigure);

% --- Executes on button press in buttonCancel.
function buttonCancel_Callback(hObject, eventdata, handles)
uiresume(handles.subjectFileInfoFigure);
delete(handles.subjectFileInfoFigure);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% --- Executes on selection change in popupPosition.
function popupPosition_Callback(hObject, eventdata, handles)
rdh = get(handles.subjectFileInfoFigure,'userdata');
str = get(hObject,'String');
rdh.position = str{get(hObject,'Value')};
set(handles.subjectFileInfoFigure,'userdata',rdh);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editResolution_Callback(hObject, eventdata, handles)
rdh = get(handles.subjectFileInfoFigure,'userdata');
rdh.resolution = max(1,abs(str2double(get(hObject,'String'))));
set(handles.subjectFileInfoFigure,'userdata',rdh);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function popupOrgStudy_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupPosition_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editResolution_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

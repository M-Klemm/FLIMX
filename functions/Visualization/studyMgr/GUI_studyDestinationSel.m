function varargout = GUI_studyDestinationSel(varargin)
%=============================================================================================================
%
% @file     GUI_studyDestinationSel.m
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
% @brief    A GUI for study duplication in study manager
%
% GUI_STUDYDESTINATIONSEL MATLAB code for GUI_studyDestinationSel.fig
%      GUI_STUDYDESTINATIONSEL, by itself, creates a new GUI_STUDYDESTINATIONSEL or raises the existing
%      singleton*.
%
%      H = GUI_STUDYDESTINATIONSEL returns the handle to a new GUI_STUDYDESTINATIONSEL or the handle to
%      the existing singleton*.
%
%      GUI_STUDYDESTINATIONSEL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_STUDYDESTINATIONSEL.M with the given input arguments.
%
%      GUI_STUDYDESTINATIONSEL('Property','Value',...) creates a new GUI_STUDYDESTINATIONSEL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_studyDestinationSel_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_studyDestinationSel_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_studyDestinationSel

% Last Modified by GUIDE v2.5 02-Dec-2013 15:14:51

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_studyDestinationSel_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_studyDestinationSel_OutputFcn, ...
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


% --- Executes just before GUI_studyDestinationSel is made visible.
function GUI_studyDestinationSel_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_studyDestinationSel (see VARARGIN)

% Choose default command line output for GUI_studyDestinationSel
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

rdh.studiesStr = varargin{1};
rdh.studyOrgSel = varargin{2};
rdh.studyDestSel = varargin{2};
if(isempty(rdh.studiesStr))
    delete(handles.studyDestinationFigure);
else
    rdh.studyOrgSel = max(1,min(length(rdh.studiesStr),rdh.studyOrgSel));
    rdh.studyDestSel = rdh.studyOrgSel;
    set(handles.studyDestinationFigure,'userdata',rdh);
    set(handles.popupOrgStudy,'String',rdh.studiesStr,'Value',rdh.studyOrgSel);
    set(handles.popupDestStudy,'String',rdh.studiesStr,'Value',rdh.studyOrgSel);    
    % UIWAIT makes GUI_studyDestinationSel wait for user response (see UIRESUME)
    uiwait(handles.studyDestinationFigure);
end

% --- Outputs from this function are returned to the command line.
function varargout = GUI_studyDestinationSel_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if(isempty(handles))
    varargout{1} = [];
else
    rdh = get(handles.studyDestinationFigure,'userdata');
    varargout{1} = rdh.studyDestSel;% handles.output;
    delete(handles.studyDestinationFigure);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
uiresume(handles.studyDestinationFigure);

% --- Executes on button press in buttonCancel.
function buttonCancel_Callback(hObject, eventdata, handles)
uiresume(handles.studyDestinationFigure);
delete(handles.studyDestinationFigure);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on selection change in popupOrgStudy.
function popupOrgStudy_Callback(hObject, eventdata, handles)

% --- Executes on selection change in popupDestStudy.
function popupDestStudy_Callback(hObject, eventdata, handles)
rdh = get(handles.studyDestinationFigure,'userdata');
rdh.studyDestSel = get(hObject,'Value');
set(handles.studyDestinationFigure,'userdata',rdh);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function popupOrgStudy_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupDestStudy_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function varargout = GUI_studyExportImport(varargin)
%=============================================================================================================
%
% @file     GUI_studyExportImport.m
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
% @brief    A GUI to export and import whole studies into FDTree
%
% GUI_STUDYEXPORTIMPORT M-file for GUI_studyExportImport.fig
%      GUI_STUDYEXPORTIMPORT, by itself, creates a new GUI_STUDYEXPORTIMPORT or raises the existing
%      singleton*.
%
%      H = GUI_STUDYEXPORTIMPORT returns the handle to a new GUI_STUDYEXPORTIMPORT or the handle to
%      the existing singleton*.
%
%      GUI_STUDYEXPORTIMPORT('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_STUDYEXPORTIMPORT.M with the given input arguments.
%
%      GUI_STUDYEXPORTIMPORT('Property','Value',...) creates a new GUI_STUDYEXPORTIMPORT or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_studyExportImport_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_studyExportImport_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_studyExportImport

% Last Modified by GUIDE v2.5 07-Oct-2010 17:36:57

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_studyExportImport_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_studyExportImport_OutputFcn, ...
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


% --- Executes just before GUI_studyExportImport is made visible.
function GUI_studyExportImport_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_studyExportImport (see VARARGIN)
movegui(handles.figure1,'center');
studiesFLIM = varargin{1};
studiesFile = varargin{2};
%initialize GUI
if(isempty(studiesFile))
    %Export
    set(handles.lbl_right,'String','Export File');
    set(handles.button_execute,'String','Export');
    set(handles.figure1,'Name','Export Studies...');    
else
    %Import
    set(handles.lbl_right,'String','Import File');
    set(handles.button_execute,'String','Import');
    set(handles.figure1,'Name','Import Studies...');    
end
    
updateGUI(handles, studiesFLIM,studiesFile);  
%set(handles.figure1,'userdata',studiesFile);

% Choose default command line output for GUI_studyExportImport
%handles.output = hObject;

% Update handles structure
%guidata(hObject, handles);

% UIWAIT makes GUI_studyExportImport wait for user response (see UIRESUME)
uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_studyExportImport_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Get default command line output from handles structure
if isempty(handles)
    handles.output='';
    varargout{1} = '';
else
    %out = get(handles.figure1,'userdata'); 
    switch get(handles.button_execute,'String')
        case 'Export'
            varargout{1} = get(handles.list_right,'String');
        case 'Import'
            varargout{1} = get(handles.list_left,'String');
    end
    delete(handles.figure1);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles,studiesFLIM,studiesFile)
%update listboxes
set(handles.list_left,'String',studiesFLIM);
set(handles.list_right,'String',studiesFile);
set(handles.list_left,'Value',curElementLeft(handles));
set(handles.list_right,'Value',curElementRight(handles));

function out = curElementLeft(handles)
out = get(handles.list_left,'Value');

function out = curElementRight(handles)
out = get(handles.list_right,'Value');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Listboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on selection change in list_right.
function list_right_Callback(hObject, eventdata, handles)
% Hints: contents = cellstr(get(hObject,'String')) returns list_right contents as cell array
%        contents{get(hObject,'Value')} returns selected item from list_right

% --- Executes on selection change in list_left.
function list_left_Callback(hObject, eventdata, handles)
% Hints: contents = cellstr(get(hObject,'String')) returns list_left contents as cell array
%        contents{get(hObject,'Value')} returns selected item from list_left


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function button_execute_Callback(hObject, eventdata, handles)
% Give list with import / export studies to StudyMgr
mode = get(hObject,'String');
if(strcmp(mode,'Export'))
    %Export
    if(isempty(get(handles.list_right,'String')))
        errordlg('You have to select at least one study to export!',...
            'Error exporting studies');
    else
        uiresume(handles.figure1);
    end
else
    %Import
    if(isempty(get(handles.list_left,'String')))
        errordlg('You have to select at least one study to import!',...
            'Error importing studies');
    else
        uiresume(handles.figure1);
    end
end

function button_cancel_Callback(hObject, eventdata, handles)
% Cancel
uiresume(handles.figure1);
delete(handles.figure1);

function button_left_all_Callback(hObject, eventdata, handles)
% Move all studies to right list (export to file)
left = get(handles.list_left,'String');
right =  get(handles.list_right,'String');
moveList = setdiff(left,right);
if(~isempty(moveList))
    right(end+1:end+length(moveList)) = moveList;
    left = setdiff(left,moveList);

    updateGUI(handles,left,right);
end

function button_left_sel_Callback(hObject, eventdata, handles)
% Move selected study to right list (export to file)
left = get(handles.list_left,'String');
right =  get(handles.list_right,'String');
if(~isempty(left))    
    moveElem = left(curElementLeft(handles));
    if(isempty(intersect(moveElem,right)))
        right(end+1:end+length(moveElem)) = moveElem;
    end
    left = setdiff(left,moveElem);
    updateGUI(handles,left,right);
end

function button_right_sel_Callback(hObject, eventdata, handles)
% Move selected study to left list (import to FLIM)
left = get(handles.list_left,'String');
right =  get(handles.list_right,'String');
if(~isempty(right))    
    moveElem = right(curElementRight(handles));
    if(isempty(intersect(moveElem,left)))
        left(end+1:end+length(moveElem)) = moveElem;
    end
    right = setdiff(right,moveElem);
    updateGUI(handles,left,right);
end

function button_right_all_Callback(hObject, eventdata, handles)
% Move all studes to left list (import to FLIM)
left = get(handles.list_left,'String');
right =  get(handles.list_right,'String');

moveList = setdiff(right,left);
if(~isempty(moveList))    
    left(end+1:end+length(moveList)) = moveList;
    right = setdiff(right,moveList);
    updateGUI(handles,left,right);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function list_right_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function list_left_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
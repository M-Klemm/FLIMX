function varargout = GUI_paramImportSelection(varargin)
%=============================================================================================================
%
% @file     GUI_paramImportSelection.m
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
% @brief    A GUI to select FLIM parameters in FLIMXVisGUI
%
% GUI_PARAMIMPORTSELECTION M-file for GUI_paramImportSelection.fig
%      GUI_PARAMIMPORTSELECTION, by itself, creates a new GUI_PARAMIMPORTSELECTION or raises the existing
%      singleton*.
%
%      H = GUI_PARAMIMPORTSELECTION returns the handle to a new GUI_PARAMIMPORTSELECTION or the handle to
%      the existing singleton*.
%
%      GUI_PARAMIMPORTSELECTION('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_PARAMIMPORTSELECTION.M with the given input arguments.
%
%      GUI_PARAMIMPORTSELECTION('Property','Value',...) creates a new GUI_PARAMIMPORTSELECTION or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_paramImportSelection_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_paramImportSelection_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_paramImportSelection

% Last Modified by GUIDE v2.5 12-Aug-2013 17:55:55

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_paramImportSelection_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_paramImportSelection_OutputFcn, ...
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


% --- Executes just before GUI_paramImportSelection is made visible.
function GUI_paramImportSelection_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_paramImportSelection (see VARARGIN)

% Choose default command line output for GUI_paramImportSelection
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

items = varargin{1};
targets = varargin{2};
items = items(~strcmpi(items,'ROI_merge_result'));
items = items(~strcmpi(items,'EffectiveTime'));
items = items(~strcmpi(items,'x_vec'));
items = items(~strcmpi(items,'hostname'));
items = items(~strcmpi(items,'Message'));

if(isempty(targets))
    %no preset target items
    targets = {'amplitude'; 'tau'; 'tc';};
    mask = makeDefaultItemSelection(items,targets);
else    
    mask = makeExactItemSelection(items,targets);
end
items(:,2) = num2cell(mask);
if(all(mask))
    set(handles.checkAllNone,'Value',1);
end
                
set(handles.tableParams,'Data',items);    

% UIWAIT makes GUI_paramImportSelection wait for user response (see UIRESUME)
uiwait(handles.ParamImportSelFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_paramImportSelection_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=[];
    varargout{1} = [];
else
    data = get(handles.tableParams,'Data');
    flags = cell2mat(data(:,2));    
    varargout{1} = data(flags,1);
    delete(handles.ParamImportSelFigure);
end

function mask = makeDefaultItemSelection(items,targets)
%find targets in items and return as logicals
mask = false(length(items),1);
idx = [];
for i = 1:length(targets)
    idxTmp = find(strncmpi(targets(i),items,length(targets(i))));
    %check if founds items are not much longer than targets (max 3 chars for running numbers)
    for j = 1:length(idxTmp)
        if(length(items{idxTmp(j)}) <= length(targets{i})+3)
            idx = [idx; idxTmp(j);];
        end
    end
    
end
mask(idx) = true;

function mask = makeExactItemSelection(items,targets)
%find targets in items and return as logicals
mask = false(length(items),1);
idx = [];
for i = 1:length(targets)
    idxTmp = find(strcmpi(targets(i),items));
    idx = [idx; idxTmp(:);];
end
mask(idx) = true;

% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
% hObject    handle to buttonOK (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
uiresume(handles.ParamImportSelFigure);

% --- Executes on button press in buttonCancel.
function buttonCancel_Callback(hObject, eventdata, handles)
% hObject    handle to buttonCancel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
uiresume(handles.ParamImportSelFigure);
delete(handles.ParamImportSelFigure);


% --- Executes when entered data in editable cell(s) in tableParams.
function tableParams_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to tableParams (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)
data = get(handles.tableParams,'Data');
str = data{eventdata.Indices(1),1};
if(strncmpi('Amp',str,3))
    %we got an amplitude, switch tau as well
    nr = str2double(str(isstrprop(str, 'digit')));
    idx = strcmpi(sprintf('Tau%d',nr),data(:,1));
    data(idx,2) = {eventdata.NewData};
    set(handles.tableParams,'Data',data);
elseif(strncmpi('Tau',str,3))
    %we got a tau, switch amplitude as well
    nr = str2double(str(isstrprop(str, 'digit')));
    idx = strcmpi(sprintf('Amplitude%d',nr),data(:,1));
    data(idx,2) = {eventdata.NewData};
    set(handles.tableParams,'Data',data);
end
if(all([data{:,2}]))
    set(handles.checkAllNone,'Value',1);
else
    set(handles.checkAllNone,'Value',0);
end


% --- Executes on button press in checkAllNone.
function checkAllNone_Callback(hObject, eventdata, handles)
%
data = get(handles.tableParams,'Data');
data(:,2) = num2cell(logical(ones(size(data,1),1).*get(hObject,'Value')));
set(handles.tableParams,'Data',data);

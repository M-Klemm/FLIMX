function varargout = GUI_boundsOptions(varargin)
%=============================================================================================================
%
% @file     GUI_boundsOptions.m
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
% @brief    A GUI to set parameter bounds in FLIMXFit
%
% GUI_BOUNDSOPTIONS M-file for GUI_boundsOptions.fig
%      GUI_BOUNDSOPTIONS, by itself, creates a new GUI_BOUNDSOPTIONS or raises the existing
%      singleton*.
%
%      H = GUI_BOUNDSOPTIONS returns the handle to a new GUI_BOUNDSOPTIONS or the handle to
%      the existing singleton*.
%
%      GUI_BOUNDSOPTIONS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_BOUNDSOPTIONS.M with the given input arguments.
%
%      GUI_BOUNDSOPTIONS('Property','Value',...) creates a new GUI_BOUNDSOPTIONS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_boundsOptions_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_boundsOptions_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_boundsOptions

% Last Modified by GUIDE v2.5 24-Mar-2011 17:06:18

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_boundsOptions_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_boundsOptions_OutputFcn, ...
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


% --- Executes just before GUI_boundsOptions is made visible.
function GUI_boundsOptions_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_boundsOptions (see VARARGIN)

% Choose default command line output for GUI_boundsOptions
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

rdh.bounds = varargin{1};
rdh.isDirty = [0 0 0 0 0 0 0 0 0 0]; %flags which part was changed, bounds_1_exp,bounds_2_exp,bounds_3_exp,bounds_nExp,bounds_tci,bounds_v_shift,bounds_h_shift,bounds_offset,bounds_scatter,bounds_s_exp
set(handles.boundsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.bounds);

% UIWAIT makes GUI_boundsOptions wait for user response (see UIRESUME)
uiwait(handles.boundsOptionsFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_boundsOptions_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=[];
    varargout{1} = [];
else
    out = get(handles.boundsOptionsFigure,'userdata'); 
    varargout{1} = out;
    delete(handles.boundsOptionsFigure);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function updateGUI(handles,bounds)
%
set(handles.tableSingle,'Data',genTabData(bounds.bounds_1_exp));
set(handles.tableDouble,'Data',genTabData(bounds.bounds_2_exp));
set(handles.tableTriple,'Data',genTabData(bounds.bounds_3_exp));
set(handles.tableStretched,'Data',genTabData(bounds.bounds_s_exp));
set(handles.tableN,'Data',genTabData(bounds.bounds_nExp));
set(handles.tableScatter,'Data',genTabData(bounds.bounds_scatter));

dtmp = genTabData(bounds.bounds_tci);
set(handles.tableTci,'Data',dtmp);

dtmp = zeros(1,8);
dtmp(1,:) = genTabData(bounds.bounds_h_shift);
set(handles.tableHShift,'Data',dtmp);

dtmp = zeros(1,8);
dtmp(1,:) = genTabData(bounds.bounds_offset);
set(handles.tableOffset,'Data',dtmp);



function data = genTabData(bStruct)
%
fn = fieldnames(bStruct);
data = zeros(length(bStruct.lb),length(fn));
for i = 1:length(fn)
    data(:,i) = bStruct.(getIniStr(i));
end

function str = getIniStr(idx)
switch idx
    case 1 
        str = 'lb';
    case 2 
        str = 'ub';
    case 3
        str = 'init';
    case 4
        str = 'deQuantization';
    case 5
        str = 'simplexInit';
    case 6
        str = 'tol';
    case 7
        str = 'quantization';
    case 8
        str = 'initGuessFactor';
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
uiresume(handles.boundsOptionsFigure);

% --- Executes on button press in buttonCancel.
function buttonCancel_Callback(hObject, eventdata, handles)
uiresume(handles.boundsOptionsFigure);
delete(handles.boundsOptionsFigure);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%table edit
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes when entered data in editable cell(s) in tableSingle.
function tableSingle_CellEditCallback(hObject, eventdata, handles)
rdh = get(handles.boundsOptionsFigure,'userdata');
rdh.bounds.bounds_1_exp.(getIniStr(eventdata.Indices(2)))(eventdata.Indices(1)) = eventdata.NewData;
rdh.isDirty(1) = 1;
set(handles.boundsOptionsFigure,'userdata',rdh);

% --- Executes when entered data in editable cell(s) in tableDouble.
function tableDouble_CellEditCallback(hObject, eventdata, handles)
rdh = get(handles.boundsOptionsFigure,'userdata');
rdh.bounds.bounds_2_exp.(getIniStr(eventdata.Indices(2)))(eventdata.Indices(1)) = eventdata.NewData;
rdh.isDirty(2) = 1;
set(handles.boundsOptionsFigure,'userdata',rdh);

% --- Executes when entered data in editable cell(s) in tableTriple.
function tableTriple_CellEditCallback(hObject, eventdata, handles)
rdh = get(handles.boundsOptionsFigure,'userdata');
rdh.bounds.bounds_3_exp.(getIniStr(eventdata.Indices(2)))(eventdata.Indices(1)) = eventdata.NewData;
rdh.isDirty(3) = 1;
set(handles.boundsOptionsFigure,'userdata',rdh);

% --- Executes when entered data in editable cell(s) in tableN.
function tableN_CellEditCallback(hObject, eventdata, handles)
rdh = get(handles.boundsOptionsFigure,'userdata');
rdh.bounds.bounds_nExp.(getIniStr(eventdata.Indices(2)))(eventdata.Indices(1)) = eventdata.NewData;
rdh.isDirty(4) = 1;
set(handles.boundsOptionsFigure,'userdata',rdh);

% --- Executes when entered data in editable cell(s) in tableStretched.
function tableStretched_CellEditCallback(hObject, eventdata, handles)
rdh = get(handles.boundsOptionsFigure,'userdata');
rdh.bounds.bounds_s_exp.(getIniStr(eventdata.Indices(2)))(eventdata.Indices(1)) = eventdata.NewData;
rdh.isDirty(10) = 1;
set(handles.boundsOptionsFigure,'userdata',rdh);

function tableTci_CellEditCallback(hObject, eventdata, handles)
rdh = get(handles.boundsOptionsFigure,'userdata');
rdh.bounds.bounds_tci.(getIniStr(eventdata.Indices(2)))(eventdata.Indices(1)) = eventdata.NewData;
rdh.isDirty(5) = 1;
set(handles.boundsOptionsFigure,'userdata',rdh);

% --- Executes when entered data in editable cell(s) in tableHShift.
function tableHShift_CellEditCallback(hObject, eventdata, handles)
rdh = get(handles.boundsOptionsFigure,'userdata');
rdh.bounds.bounds_h_shift.(getIniStr(eventdata.Indices(2)))(eventdata.Indices(1)) = eventdata.NewData;
rdh.isDirty(7) = 1;
set(handles.boundsOptionsFigure,'userdata',rdh);

% --- Executes when entered data in editable cell(s) in tableOffset.
function tableOffset_CellEditCallback(hObject, eventdata, handles)
rdh = get(handles.boundsOptionsFigure,'userdata');
rdh.bounds.bounds_offset.(getIniStr(eventdata.Indices(2)))(eventdata.Indices(1)) = eventdata.NewData;
rdh.isDirty(8) = 1;
set(handles.boundsOptionsFigure,'userdata',rdh);

% --- Executes when entered data in editable cell(s) in tableScatter.
function tableScatter_CellEditCallback(hObject, eventdata, handles)
rdh = get(handles.boundsOptionsFigure,'userdata');
rdh.bounds.bounds_scatter.(getIniStr(eventdata.Indices(2)))(eventdata.Indices(1)) = eventdata.NewData;
rdh.isDirty(9) = 1;
set(handles.boundsOptionsFigure,'userdata',rdh);

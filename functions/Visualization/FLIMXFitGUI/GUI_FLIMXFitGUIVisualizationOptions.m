function varargout = GUI_FLIMXFitGUIVisualizationOptions(varargin)
%=============================================================================================================
%
% @file     GUI_FLIMXFitGUIVisualizationOptions.m
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
% @brief    A GUI to set visualization options in FLIMXFit
%
% GUI_FLIMXFitGUIVisualizationOptions M-file for GUI_FLIMXFitGUIVisualizationOptions.fig
%      GUI_FLIMXFitGUIVisualizationOptions, by itself, creates a new GUI_FLIMXFitGUIVisualizationOptions or raises the existing
%      singleton*.
%
%      H = GUI_FLIMXFitGUIVisualizationOptions returns the handle to a new GUI_FLIMXFitGUIVisualizationOptions or the handle to
%      the existing singleton*.
%
%      GUI_FLIMXFitGUIVisualizationOptions('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_FLIMXFitGUIVisualizationOptions.M with the given input arguments.
%
%      GUI_FLIMXFitGUIVisualizationOptions('Property','Value',...) creates a new GUI_FLIMXFitGUIVisualizationOptions or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_FLIMXFitGUIVisualizationOptions_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_FLIMXFitGUIVisualizationOptions_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_FLIMXFitGUIVisualizationOptions

% Last Modified by GUIDE v2.5 12-Jul-2016 14:43:34

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @GUI_FLIMXFitGUIVisualizationOptions_OpeningFcn, ...
    'gui_OutputFcn',  @GUI_FLIMXFitGUIVisualizationOptions_OutputFcn, ...
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


% --- Executes just before GUI_FLIMXFitGUIVisualizationOptions is made visible.
function GUI_FLIMXFitGUIVisualizationOptions_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_FLIMXFitGUIVisualizationOptions (see VARARGIN)

% Choose default command line output for GUI_FLIMXFitGUIVisualizationOptions
% handles.output = hObject;

% Update handles structure
% guidata(hObject, handles);
rdh.fluoDecay = varargin{1};
rdh.general = varargin{2};
rdh.isDirty = [0 0]; %1: FLIMXFitGUI, 2: general
updateGUI(handles, rdh);
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% UIWAIT makes GUI_FLIMXFitGUIVisualizationOptions wait for user response (see UIRESUME)
uiwait(handles.FLIMXFitGUIVisualizationOptions);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_FLIMXFitGUIVisualizationOptions_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=[];
    varargout{1} = [];
else
    out = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
    varargout{1} = out;
    delete(handles.FLIMXFitGUIVisualizationOptions);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles,data)

set(handles.checkData,'Value',data.fluoDecay.plotData);
set(handles.checkExpSum,'Value',data.fluoDecay.plotExpSum);
set(handles.checkCurLinesAndText,'Value',data.fluoDecay.plotCurLinesAndText);
set(handles.checkExp,'Value',data.fluoDecay.plotExp);
set(handles.checkIRF,'Value',data.fluoDecay.plotIRF);
set(handles.checkStartEnd,'Value',data.fluoDecay.plotStartEnd);
set(handles.checkSlope,'Value',data.fluoDecay.plotSlope);
set(handles.checkInit,'Value',data.fluoDecay.plotInit);
%general
set(handles.checkLegend,'Value',data.fluoDecay.showLegend);
set(handles.checkInvertColormap,'Value',data.general.cmInvert);
idx = find(strcmpi(get(handles.popupColormap,'String'),data.general.cmType),1);
if(isempty(idx))
    idx = 10; %jet
end
set(handles.popupColormap,'Value',idx);
set(handles.checkReverseYDir,'Value',data.general.reverseYDir);

%linewidth
set(handles.editDataLinewidth,'String',num2str(data.fluoDecay.plotDataLinewidth,'%d'));
set(handles.editExpSumLinewidth,'String',num2str(data.fluoDecay.plotExpSumLinewidth,'%d'));
set(handles.editExpLinewidth,'String',num2str(data.fluoDecay.plotExpLinewidth,'%d'));
set(handles.editIRFLinewidth,'String',num2str(data.fluoDecay.plotIRFLinewidth,'%d'));
set(handles.editCurlineswidth,'String',num2str(data.fluoDecay.plotCurlineswidth,'%d'));
set(handles.editStartEndLinewidth,'String',num2str(data.fluoDecay.plotStartEndLinewidth,'%d'));
set(handles.editSlopeLinewidth,'String',num2str(data.fluoDecay.plotSlopeLinewidth,'%d'));
set(handles.editInitLinewidth,'String',num2str(data.fluoDecay.plotInitLinewidth,'%d'));
%linestyle
set(handles.popupDataLinestyle,'Value',lineStyle2id(data.fluoDecay.plotDataLinestyle));
set(handles.popupExpSumLinestyle,'Value',lineStyle2id(data.fluoDecay.plotExpSumLinestyle));
set(handles.popupExpLinestyle,'Value',lineStyle2id(data.fluoDecay.plotExpLinestyle));
set(handles.popupIRFLinestyle,'Value',lineStyle2id(data.fluoDecay.plotIRFLinestyle));
set(handles.popupCurLinesStyle,'Value',lineStyle2id(data.fluoDecay.plotCurLinesStyle));
set(handles.popupStartEndLinestyle,'Value',lineStyle2id(data.fluoDecay.plotStartEndLinestyle));
set(handles.popupSlopeLinestyle,'Value',lineStyle2id(data.fluoDecay.plotSlopeLinestyle));
set(handles.popupInitLinestyle,'Value',lineStyle2id(data.fluoDecay.plotInitLinestyle));

%color
set(handles.buttonDataColor,'BackgroundColor',data.fluoDecay.plotDataColor);
set(handles.buttonExpSumColor,'BackgroundColor',data.fluoDecay.plotExpSumColor);
set(handles.buttonCurLinesColor,'BackgroundColor',data.fluoDecay.plotCurLinesColor);
set(handles.buttonCoordinateBoxColor,'BackgroundColor',data.fluoDecay.plotCoordinateBoxColor);
set(handles.buttonExp1Color,'BackgroundColor',data.fluoDecay.plotExp1Color);
set(handles.buttonExp2Color,'BackgroundColor',data.fluoDecay.plotExp2Color);
set(handles.buttonExp3Color,'BackgroundColor',data.fluoDecay.plotExp3Color);
set(handles.buttonExp4Color,'BackgroundColor',data.fluoDecay.plotExp4Color);
set(handles.buttonExp5Color,'BackgroundColor',data.fluoDecay.plotExp5Color);
set(handles.buttonIRFColor,'BackgroundColor',data.fluoDecay.plotIRFColor);
set(handles.buttonStartEndColor,'BackgroundColor',data.fluoDecay.plotStartEndColor);
set(handles.buttonSlopeColor,'BackgroundColor',data.fluoDecay.plotSlopeColor);
set(handles.buttonInitColor,'BackgroundColor',data.fluoDecay.plotInitColor);

%transparency
set(handles.editCoordinateBoxTransparency,'String',num2str(data.fluoDecay.plotCoordinateBoxTransparency,'%d'));

%markerstyle
set(handles.popupDataMarkerstyle,'Value',markerStyle2id(data.fluoDecay.plotDataMarkerstyle));
set(handles.popupExpSumMarkerstyle,'Value',markerStyle2id(data.fluoDecay.plotExpSumMarkerstyle));
set(handles.popupExpMarkerstyle,'Value',markerStyle2id(data.fluoDecay.plotExpMarkerstyle));
set(handles.popupIRFMarkerstyle,'Value',markerStyle2id(data.fluoDecay.plotIRFMarkerstyle));
set(handles.popupInitMarkerstyle,'Value',markerStyle2id(data.fluoDecay.plotInitMarkerstyle));
%markersize
set(handles.editDataMarkersize,'String',num2str(data.fluoDecay.plotDataMarkersize,'%d'));
set(handles.editExpSumMarkersize,'String',num2str(data.fluoDecay.plotExpSumMarkersize,'%d'));
set(handles.editExpMarkersize,'String',num2str(data.fluoDecay.plotExpMarkersize,'%d'));
set(handles.editIRFMarkersize,'String',num2str(data.fluoDecay.plotIRFMarkersize,'%d'));
set(handles.editInitMarkersize,'String',num2str(data.fluoDecay.plotInitMarkersize,'%d'));

set(handles.popupFLIMItems,'Value',data.general.flimParameterView);
%startup
if(data.general.openFitGUIonStartup && ~data.general.openVisGUIonStartup)
    set(handles.popupStartupGUIs,'Value',1);
elseif(~data.general.openFitGUIonStartup && data.general.openVisGUIonStartup)
    set(handles.popupStartupGUIs,'Value',2);
else
    set(handles.popupStartupGUIs,'Value',3);
end
%window size
set(handles.popupWindowSize,'Value',data.general.windowSize);

function out = id2LineStyle(id)
%convert descriptive string to linestyle string
switch id
    case {'No line',1}
        out = 'none';
    case {'Solid line',2}
        out = '-';
    case {'Dashed line',3}
        out = '--';
    case {'Dotted line',4}
        out = ':';
    case {'Dash-dot line',5}
        out = '-.';
    otherwise
        out = id;
end

function out = lineStyle2id(str)
%convert descriptive string or linestyle string to running number
if(isnumeric(str))
    out = str;
    return
end
switch str
    case {'No line','none'}
        out = 1;
    case {'Solid line','-'}
        out = 2;
    case {'Dashed line','--'}
        out = 3;
    case {'Dotted line',':'}
        out = 4;
    case {'Dash-dot line','-.'}
        out = 5;
end

function out = id2MarkerStyle(str)
%
switch str
    case {'No marker',1}
        out = 'none';
    case {'Plus sign',2}
        out = '+';
    case {'Circle',3}
        out = 'o';
    case {'Asterisk',4}
        out = '*';
    case {'Point',5}
        out = '.';
    case {'Cross',6}
        out = 'x';
    case {'Square',7}
        out = 'square';
    case {'Diamond',8}
        out = 'diamond';
    case {'Upward-pointing triangle',9}
        out = '^';
    case {'Downward-pointing triangle',10}
        out = 'v';
    case {'Right-pointing triangle',11}
        out = '>';
    case {'Left-pointing triangle',12}
        out = '<';
    case {'Five-pointed star (pentagram)',13}
        out = 'pentagram';
    case {'Six-pointed star (hexagram)',14}
        out = 'hexagram';
    otherwise
        out = str;
end

function out = markerStyle2id(str)
%
if(isnumeric(str))
    out = str;
    return
end
switch str
    case {'No marker','none'}
        out = 1;
    case {'Plus sign','+'}
        out = 2;
    case {'Circle','o'}
        out = 3;
    case {'Asterisk','*'}
        out = 4;
    case {'Point','.'}
        out = 5;
    case {'Cross','x'}
        out = 6;
    case {'Square','square'}
        out = 7;
    case {'Diamond','diamond'}
        out = 8;
    case {'Upward-pointing triangle','^'}
        out = 9;
    case {'Downward-pointing triangle','v'}
        out = 10;
    case {'Right-pointing triangle','>'}
        out = 11;
    case {'Left-pointing triangle','<'}
        out = 12;
    case {'Five-pointed star (pentagram)','pentagram'}
        out = 13;
    case {'Six-pointed star (hexagram)','hexagram'}
        out = 14;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%radio buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%checkboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in checkExp.
function checkExp_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotExp = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on button press in checkIRF.
function checkIRF_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotIRF = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on button press in checkLegend.
function checkLegend_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.showLegend = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on button press in checkdata.fluoDecay.
function checkData_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotData = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on button press in checkExpSum.
function checkExpSum_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotExpSum = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on button press in checkStartEnd.
function checkStartEnd_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotStartEnd = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on button press in checkSlope.
function checkSlope_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotSlope = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on button press in checkInit.
function checkInit_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotInit = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on button press in checkInvertColormap.
function checkInvertColormap_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.general.cmInvert = get(hObject,'Value');
rdh.isDirty(2) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on button press in checkReverseYDir.
function checkReverseYDir_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.general.reverseYDir = get(hObject,'Value');
rdh.isDirty(2) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

function checkCurLinesAndText_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.general.CurLinesAndText = get(hObject,'Value');
rdh.isDirty(2) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editDataLinewidth_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotDataLinewidth = max(1,abs(round(str2double(get(hObject,'String')))));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotDataLinewidth);

function editIRFLinewidth_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotIRFLinewidth = max(1,abs(round(str2double(get(hObject,'String')))));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotIRFLinewidth);

function editExpLinewidth_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotExpLinewidth = max(1,abs(round(str2double(get(hObject,'String')))));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotExpLinewidth);

function editExpSumLinewidth_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotExpSumLinewidth = max(1,abs(round(str2double(get(hObject,'String')))));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotExpSumLinewidth);

function editExpMarkersize_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotExpMarkersize = max(1,abs(round(str2double(get(hObject,'String')))));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotExpMarkersize);

function editDataMarkersize_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotDataMarkersize = max(1,abs(round(str2double(get(hObject,'String')))));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotDataMarkersize);

function editIRFMarkersize_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotIRFMarkersize = max(1,abs(round(str2double(get(hObject,'String')))));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotIRFMarkersize);

function editExpSumMarkersize_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotExpSumMarkersize = max(1,abs(round(str2double(get(hObject,'String')))));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotExpSumMarkersize);

function editStartEndLinewidth_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotStartEndLinewidth = max(1,abs(round(str2double(get(hObject,'String')))));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotStartEndLinewidth);

function editInitMarkersize_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotInitMarkersize = max(1,abs(round(str2double(get(hObject,'String')))));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotInitMarkersize);

function editSlopeLinewidth_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotSlopeLinewidth = max(1,abs(round(str2double(get(hObject,'String')))));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotSlopeLinewidth);

function editInitLinewidth_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotInitLinewidth = max(1,abs(round(str2double(get(hObject,'String')))));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotInitLinewidth);

function editCurlineswidth_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotCurlineswidth = str2double(get(hObject,'String'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
set(hObject,'String',rdh.fluoDecay.plotCurlineswidth);

function editCoordinateBoxTransparency_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotCoordinateBoxTransparency = max(1,abs(round(str2double(get(hObject,'String')))))/100;
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

set(hObject,'String',rdh.fluoDecay.plotCoordinateBoxTransparency);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
uiresume(handles.FLIMXFitGUIVisualizationOptions);

% --- Executes on button press in buttonCancel.
function buttonCancel_Callback(hObject, eventdata, handles)
uiresume(handles.FLIMXFitGUIVisualizationOptions);
delete(handles.FLIMXFitGUIVisualizationOptions);

% --- Executes on button press in buttonDataColor.
function buttonDataColor_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotDataColor);
if(length(new) == 3)
    rdh.fluoDecay.plotDataColor = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end

% --- Executes on button press in buttonIRFColor.
function buttonIRFColor_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotIRFColor);
if(length(new) == 3)
    rdh.fluoDecay.plotIRFColor = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end

% --- Executes on button press in buttonExp1Color.
function buttonExp1Color_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotExp1Color);
if(length(new) == 3)
    rdh.fluoDecay.plotExp1Color = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end

% --- Executes on button press in buttonExp2Color.
function buttonExp2Color_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotExp2Color);
if(length(new) == 3)
    rdh.fluoDecay.plotExp2Color = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end

% --- Executes on button press in buttonExp3Color.
function buttonExp3Color_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotExp3Color);
if(length(new) == 3)
    rdh.fluoDecay.plotExp3Color = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end

% --- Executes on button press in buttonExp4Color.
function buttonExp4Color_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotExp4Color);
if(length(new) == 3)
    rdh.fluoDecay.plotExp4Color = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end

% --- Executes on button press in buttonExp5Color.
function buttonExp5Color_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotExp5Color);
if(length(new) == 3)
    rdh.fluoDecay.plotExp5Color = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end

% --- Executes on button press in buttonExpSumColor.
function buttonExpSumColor_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotExpSumColor);
if(length(new) == 3)
    rdh.fluoDecay.plotExpSumColor = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end

% --- Executes on button press in buttonStartEndColor.
function buttonStartEndColor_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotStartEndColor);
if(length(new) == 3)
    rdh.fluoDecay.plotStartEndColor = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end

% --- Executes on button press in buttonSlopeColor.
function buttonSlopeColor_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotSlopeColor);
if(length(new) == 3)
    rdh.fluoDecay.plotSlopeColor = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end

% --- Executes on button press in buttonInitColor.
function buttonInitColor_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotInitColor);
if(length(new) == 3)
    rdh.fluoDecay.plotInitColor = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end

% --- Executes on button press in buttonCurLinesColor.
function buttonCurLinesColor_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotCurLinesColor);
if(length(new) == 3)
    rdh.fluoDecay.plotCurLinesColor = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end

% --- Executes on button press in buttonCoordinateBoxColor.
function buttonCoordinateBoxColor_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
new = GUI_Colorselection(rdh.fluoDecay.plotCoordinateBoxColor);
if(length(new) == 3)
    rdh.fluoDecay.plotCoordinateBoxColor = new;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);    
    set(hObject,'BackgroundColor',new);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on selection change in popupDataLinestyle.
function popupDataLinestyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotDataLinestyle = id2LineStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupIRFLinestyle.
function popupIRFLinestyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotIRFLinestyle = id2LineStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupExpLinestyle.
function popupExpLinestyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotExpLinestyle = id2LineStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupExpSumLinestyle.
function popupExpSumLinestyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotExpSumLinestyle = id2LineStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupExpMarkerstyle.
function popupExpMarkerstyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotExpMarkerstyle = id2MarkerStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupDataMarkerstyle.
function popupDataMarkerstyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotDataMarkerstyle = id2MarkerStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupIRFMarkerstyle.
function popupIRFMarkerstyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotIRFMarkerstyle = id2MarkerStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupExpSumMarkerstyle.
function popupExpSumMarkerstyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotExpSumMarkerstyle = id2MarkerStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupFLIMItems.
function popupFLIMItems_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.general.flimParameterView = get(hObject,'Value');       
rdh.isDirty(2) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on selection change in popupStartupGUIs.
function popupStartupGUIs_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
switch get(hObject,'Value')
    case 1
        rdh.general.openFitGUIonStartup = 1;
        rdh.general.openVisGUIonStartup = 0;
    case 2
        rdh.general.openFitGUIonStartup = 0;
        rdh.general.openVisGUIonStartup = 1;
    otherwise
        rdh.general.openFitGUIonStartup = 1;
        rdh.general.openVisGUIonStartup = 1;
end
rdh.isDirty(2) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on selection change in popupWindowSize.
function popupWindowSize_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.general.windowSize = get(hObject,'Value');
rdh.isDirty(2) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on selection change in popupStartEndLinestyle.
function popupStartEndLinestyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotStartEndLinestyle = id2LineStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupSlopeLinestyle.
function popupSlopeLinestyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotSlopeLinestyle = id2LineStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupCurLinesStyle.
function popupCurLinesStyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotCurLinesStyle = id2LineStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupInitMarkerstyle.
function popupInitMarkerstyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotInitMarkerstyle = id2MarkerStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupInitLinestyle.
function popupInitLinestyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
rdh.fluoDecay.plotInitLinestyle = id2LineStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

% --- Executes on selection change in popupColormap.
function popupColormap_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXFitGUIVisualizationOptions,'userdata');
str = get(hObject,'String');
str = str{get(hObject,'Value')};
rdh.general.cmType = str;
rdh.isDirty(2) = 1;
set(handles.FLIMXFitGUIVisualizationOptions,'userdata',rdh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function editDataLinewidth_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupDataLinestyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editIRFLinewidth_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupIRFLinestyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editExpLinewidth_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupExpLinestyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupWindowSize_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupExpSumLinestyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editExpSumLinewidth_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupExpMarkerstyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editExpMarkersize_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupDataMarkerstyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDataMarkersize_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupIRFMarkerstyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editIRFMarkersize_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupExpSumMarkerstyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editExpSumMarkersize_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupStartEndLinestyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editStartEndLinewidth_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editInitMarkersize_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupInitMarkerstyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupInitLinestyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editInitLinewidth_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupSlopeLinestyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editSlopeLinewidth_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupColormap_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupStartupGUIs_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupFLIMItems_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function popupCurLinesStyle_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function editCurlineswidth_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function editCoordinateBoxTransparency_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

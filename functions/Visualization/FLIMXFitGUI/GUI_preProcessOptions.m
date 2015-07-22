function varargout = GUI_preProcessOptions(varargin)
%=============================================================================================================
%
% @file     GUI_preProcessOptions.m
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
% @brief    A GUI to set pre-processing options in FLIMXFit
%
% GUI_PREPROCESSOPTIONS M-file for GUI_preProcessOptions.fig
%      GUI_PREPROCESSOPTIONS, by itself, creates a new GUI_PREPROCESSOPTIONS or raises the existing
%      singleton*.
%
%      H = GUI_PREPROCESSOPTIONS returns the handle to a new GUI_PREPROCESSOPTIONS or the handle to
%      the existing singleton*.
%
%      GUI_PREPROCESSOPTIONS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_PREPROCESSOPTIONS.M with the given input arguments.
%
%      GUI_PREPROCESSOPTIONS('Property','Value',...) creates a new GUI_PREPROCESSOPTIONS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_preProcessOptions_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_preProcessOptions_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_preProcessOptions

% Last Modified by GUIDE v2.5 13-Aug-2013 16:39:38

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_preProcessOptions_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_preProcessOptions_OutputFcn, ...
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


% --- Executes just before GUI_preProcessOptions is made visible.
function GUI_preProcessOptions_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_preProcessOptions (see VARARGIN)

% Choose default command line output for GUI_preProcessOptions
% handles.output = hObject;

% Update handles structure
% guidata(hObject, handles);
rdh.preProcessing = varargin{1};
updateGUI(handles, rdh);  
set(handles.preProcessOptionsFigure,'userdata',rdh);

% UIWAIT makes GUI_preProcessOptions wait for user response (see UIRESUME)
uiwait(handles.preProcessOptionsFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_preProcessOptions_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=[];
    varargout{1} = [];
else
    varargout{1} = get(handles.preProcessOptionsFigure,'userdata');
    delete(handles.preProcessOptionsFigure);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles,data)
%general
switch data.preProcessing.autoStartPos
    case 1
        set(handles.radioStartAuto,'Value',1);
        set(handles.radioStartManual,'Value',0);
        set(handles.radioStartFix,'Value',0);
        set(handles.editStartFix,'Enable','off','String',num2str(data.preProcessing.fixStartPos));
    case 0
        set(handles.radioStartAuto,'Value',0);
        set(handles.radioStartManual,'Value',1);
        set(handles.radioStartFix,'Value',0);
        set(handles.editStartFix,'Enable','off','String',num2str(data.preProcessing.fixStartPos));
    case -1
        set(handles.radioStartAuto,'Value',0);
        set(handles.radioStartManual,'Value',0);
        set(handles.radioStartFix,'Value',1);
        set(handles.editStartFix,'Enable','on','String',num2str(data.preProcessing.fixStartPos));
end
switch data.preProcessing.autoEndPos
    case 1
        set(handles.radioEndAuto,'Value',1);
        set(handles.radioEndManual,'Value',0);
        set(handles.radioEndFix,'Value',0);
        set(handles.editEndFix,'Enable','off','String',num2str(data.preProcessing.fixEndPos));
    case 0
        set(handles.radioEndAuto,'Value',0);
        set(handles.radioEndManual,'Value',1);
        set(handles.radioEndFix,'Value',0);
        set(handles.editEndFix,'Enable','off','String',num2str(data.preProcessing.fixEndPos));
    case -1
        set(handles.radioEndAuto,'Value',0);
        set(handles.radioEndManual,'Value',0);
        set(handles.radioEndFix,'Value',1);
        set(handles.editEndFix,'Enable','on','String',num2str(data.preProcessing.fixEndPos));
end
switch data.preProcessing.autoReflRem
    case 1
        set(handles.radioReflRemAuto,'Value',1);
        set(handles.radioReflRemManual,'Value',0);
        set(handles.radioReflRemDisabled,'Value',0);
        set(handles.editReflRemWinSz,'String',num2str(data.preProcessing.ReflRemWinSz),'Enable','on');
        set(handles.editReflRemGrpSz,'String',num2str(data.preProcessing.ReflRemGrpSz),'Enable','on');
        set(handles.textReflRemWinSz,'Enable','on');
        set(handles.textReflRemGrpSz,'Enable','on');
    case 0
        set(handles.radioReflRemAuto,'Value',0);
        set(handles.radioReflRemManual,'Value',1);
        set(handles.radioReflRemDisabled,'Value',0);
        set(handles.editReflRemWinSz,'String',num2str(data.preProcessing.ReflRemWinSz),'Enable','off');
        set(handles.editReflRemGrpSz,'String',num2str(data.preProcessing.ReflRemGrpSz),'Enable','off');  
        set(handles.textReflRemWinSz,'Enable','off');
        set(handles.textReflRemGrpSz,'Enable','off');
    case -1
        set(handles.radioReflRemAuto,'Value',0);
        set(handles.radioReflRemManual,'Value',0);
        set(handles.radioReflRemDisabled,'Value',1);
        set(handles.editReflRemWinSz,'String',num2str(data.preProcessing.ReflRemWinSz),'Enable','off');
        set(handles.editReflRemGrpSz,'String',num2str(data.preProcessing.ReflRemGrpSz),'Enable','off');
        set(handles.textReflRemWinSz,'Enable','off');
        set(handles.textReflRemGrpSz,'Enable','off');
end
switch data.preProcessing.roiAdaptiveBinEnable
    case 0
        set(handles.radioStaticBinning,'Value',1);
        set(handles.editStaticBinFactor,'String',num2str(data.preProcessing.roiBinning),'Enable','on');
        set(handles.buttonDecStaticBinFactor,'Enable','on');
        set(handles.buttonIncStaticBinFactor,'Enable','on');
        set(handles.textStaticBinFactor,'Enable','on');
        set(handles.radioAdaptiveBinning,'Value',0);  
        set(handles.editAdaptiveBinFactor,'String',num2str(data.preProcessing.roiAdaptiveBinMax),'Enable','off');
        set(handles.editAdaptiveTargetPhotons,'String',num2str(data.preProcessing.roiAdaptiveBinThreshold),'Enable','off');
        set(handles.buttonDecAdaptiveBinFactor,'Enable','off');
        set(handles.buttonIncAdaptiveBinFactor,'Enable','off');
        set(handles.textAdaptiveBinFactor,'Enable','off');
        set(handles.textAdaptiveTargetPhotons,'Enable','off');
    case 1
        set(handles.radioStaticBinning,'Value',0);
        set(handles.editStaticBinFactor,'String',num2str(data.preProcessing.roiBinning),'Enable','off');
        set(handles.buttonDecStaticBinFactor,'Enable','off');
        set(handles.buttonIncStaticBinFactor,'Enable','off');
        set(handles.textStaticBinFactor,'Enable','off');
        set(handles.radioAdaptiveBinning,'Value',1);
        set(handles.editAdaptiveBinFactor,'String',num2str(data.preProcessing.roiAdaptiveBinMax),'Enable','on');
        set(handles.editAdaptiveTargetPhotons,'String',num2str(data.preProcessing.roiAdaptiveBinThreshold),'Enable','on');
        set(handles.buttonDecAdaptiveBinFactor,'Enable','on');
        set(handles.buttonIncAdaptiveBinFactor,'Enable','on');
        set(handles.textAdaptiveBinFactor,'Enable','on');
        set(handles.textAdaptiveTargetPhotons,'Enable','on');
end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%checkboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editStartFix_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.fixStartPos = abs(str2double(get(hObject,'String')));
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

function editEndFix_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.fixEndPos = abs(str2double(get(hObject,'String')));
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

function editReflRemGrpSz_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.ReflRemGrpSz = round(abs(str2double(get(hObject,'String'))));
set(handles.preProcessOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.preProcessing.ReflRemGrpSz));

function editReflRemWinSz_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.ReflRemWinSz = round(abs(str2double(get(hObject,'String'))));
set(handles.preProcessOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.preProcessing.ReflRemWinSz));

function editStaticBinFactor_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.roiBinning = round(abs(str2double(get(hObject,'String'))));
set(handles.preProcessOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.preProcessing.roiBinning));

function editAdaptiveBinFactor_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.roiAdaptiveBinMax = round(abs(str2double(get(hObject,'String'))));
set(handles.preProcessOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.preProcessing.roiAdaptiveBinMax));

function editAdaptiveTargetPhotons_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.roiAdaptiveBinThreshold = round(abs(str2double(get(hObject,'String'))));
set(handles.preProcessOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.preProcessing.roiAdaptiveBinThreshold));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%radio buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function radioStartAuto_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.autoStartPos = 1;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in radiostartManual.
function radioStartManual_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.autoStartPos = 0;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in radioStartFix.
function radioStartFix_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.autoStartPos = -1;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in radioEndAuto.
function radioEndAuto_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.autoEndPos = 1;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in radioEndManual.
function radioEndManual_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.autoEndPos = 0;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in radioEndFix.
function radioEndFix_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.autoEndPos = -1;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in checkAutoReflRem.
function radioReflRemAuto_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.autoReflRem = 1;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh); 

% --- Executes on button press in radioReflRemManual.
function radioReflRemManual_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.autoReflRem = 0;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh); 

% --- Executes on button press in radioReflRemDisabled.
function radioReflRemDisabled_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.autoReflRem = -1;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh); 

% --- Executes on button press in radioStaticBinning.
function radioStaticBinning_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.roiAdaptiveBinEnable = 0;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh); 

% --- Executes on button press in radioAdaptiveBinning.
function radioAdaptiveBinning_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.roiAdaptiveBinEnable = 1;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh); 


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
uiresume(handles.preProcessOptionsFigure);

% --- Executes on button press in buttonCancel.
function buttonCancel_Callback(hObject, eventdata, handles)
uiresume(handles.preProcessOptionsFigure);
delete(handles.preProcessOptionsFigure);

% --- Executes on button press in buttonDecStaticBinFactor.
function buttonDecStaticBinFactor_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.roiBinning = max(0,rdh.preProcessing.roiBinning-1);
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in buttonIncStaticBinFactor.
function buttonIncStaticBinFactor_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.roiBinning = rdh.preProcessing.roiBinning+1;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in buttonDecAdaptiveBinFactor.
function buttonDecAdaptiveBinFactor_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.roiAdaptiveBinMax = max(0,rdh.preProcessing.roiAdaptiveBinMax-1);
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in buttonIncAdaptiveBinFactor.
function buttonIncAdaptiveBinFactor_Callback(hObject, eventdata, handles)
rdh = get(handles.preProcessOptionsFigure,'userdata');
rdh.preProcessing.roiAdaptiveBinMax = rdh.preProcessing.roiAdaptiveBinMax+1;
set(handles.preProcessOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);


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
function editReflRemGrpSz_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editReflRemWinSz_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editEndFix_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editStartFix_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editStaticBinFactor_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editAdaptiveBinFactor_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editAdaptiveTargetPhotons_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

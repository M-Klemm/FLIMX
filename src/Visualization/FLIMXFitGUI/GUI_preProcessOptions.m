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

% Last Modified by GUIDE v2.5 10-Apr-2018 18:32:58

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
rdh.currentSubject = varargin{2};
if(strcmp('Off',varargin{3}))
    rdh.enableGUIControlsFlag = 'Off';
else
    rdh.enableGUIControlsFlag = 'On';
end
updateGUI(handles, rdh);
set(handles.preProcessOptionsFigure,'userdata',rdh);
%set tooltips
handles.radioStartAuto.TooltipString = 'Automatic determination of the start position of the time interval used for the fluorescence lifetime approximation';
handles.radioStartManual.TooltipString = 'Manually set the start position of the time interval used for the fluorescence lifetime approximation (this will open a GUI when loading a new subject)';
handles.radioStartFix.TooltipString = 'Set the start position of the time interval used for the fluorescence lifetime approximation to a fixed value';
handles.editStartFix.TooltipString = 'Value for fixed start position';
handles.buttonStartManual.TooltipString = 'Set start position for current subject';
handles.radioEndAuto.TooltipString = 'Automatic determination of the end position of the time interval used for the fluorescence lifetime approximation';
handles.radioEndManual.TooltipString = 'Manually set the end position of the time interval used for the fluorescence lifetime approximation (this will open a GUI when loading a new subject)';
handles.radioEndFix.TooltipString = 'Set the end position of the time interval used for the fluorescence lifetime approximation to a fixed value';
handles.editEndFix.TooltipString = 'Value for fixed end position';
handles.buttonEndManual.TooltipString = 'Set end position for current subject';
handles.radioReflRemAuto.TooltipString = 'Automatic detection and removal of ascending parts in the time interval used for fluorescence lifetime approximation caused by reflections';
handles.radioReflRemManual.TooltipString = 'Manually select time intervals for each channel, which are removed from the fluorescence lifetime approximation (this will open a GUI when loading a new subject)';
handles.radioReflRemDisabled.TooltipString = 'Disable algorithm to remove ascending parts in time interval used for fluorescence lifetime approximation caused by reflections';
handles.editReflRemWinSz.TooltipString = 'Window size for reflection removal algorithm (used to smooth the fluorescence intensity decay)';
handles.editReflRemGrpSz.TooltipString = 'Group size for reflection removal algorithm (number of consecutive time points with a rising fluorescence signal to be detected as a reflection artifact) ';
handles.buttonReflRemManual.TooltipString = 'Set the parts of the time interval, which are irgnored for fluorescence lifetime approximation for current subject';
handles.radioStaticBinning.TooltipString = 'Use static binning to improve the signal-to-noise ratio for the fluorescence lifetime approximation by reducing the effective spatial resolution';
handles.editStaticBinFactor.TooltipString = 'Binning factor; number of pixels binned = (2 x binning factor +1)²';
handles.buttonDecStaticBinFactor.TooltipString = 'Decrease static binning factor';
handles.buttonIncStaticBinFactor.TooltipString = 'Increase static binning factor';
handles.radioAdaptiveBinning.TooltipString = 'Use adaptive binning to improve the signal-to-noise ratio for the fluorescence lifetime approximation by reducing the effective spatial resolution (best compromise of signal quality and loss of spatial resolution for a target number of photons per pixel';
handles.editAdaptiveBinFactor.TooltipString = 'Maximum binning factor used';
handles.editAdaptiveTargetPhotons.TooltipString = 'Target number of photons after adaptive binning';
handles.buttonDecAdaptiveBinFactor.TooltipString = 'Decrease max binning factor';
handles.buttonIncAdaptiveBinFactor.TooltipString = 'Increase max binning factor';
handles.buttonOK.TooltipString = 'Save changes and close window';
handles.buttonCancel.TooltipString = 'Discard changes and close window';
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
    rdh = get(handles.preProcessOptionsFigure,'userdata');
    rdh = rmfield(rdh,'currentSubject');
    varargout{1} = rdh;
    delete(handles.preProcessOptionsFigure);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles,data)
%general
switch data.preProcessing.autoStartPos
    case 1
        set(handles.radioStartAuto,'Value',1,'Enable',data.enableGUIControlsFlag);
        set(handles.radioStartManual,'Value',0,'Enable',data.enableGUIControlsFlag);
        set(handles.radioStartFix,'Value',0,'Enable',data.enableGUIControlsFlag);
        set(handles.editStartFix,'Enable','Off','String',num2str(data.preProcessing.fixStartPos));
        handles.buttonStartManual.Enable = 'Off';
    case 0
        set(handles.radioStartAuto,'Value',0,'Enable',data.enableGUIControlsFlag);
        set(handles.radioStartManual,'Value',1,'Enable',data.enableGUIControlsFlag);
        set(handles.radioStartFix,'Value',0,'Enable',data.enableGUIControlsFlag);
        set(handles.editStartFix,'Enable','Off','String',num2str(data.preProcessing.fixStartPos));
        if(strcmp(data.enableGUIControlsFlag,'On'))
            handles.buttonStartManual.Enable = 'On';
        end
    case -1
        set(handles.radioStartAuto,'Value',0,'Enable',data.enableGUIControlsFlag);
        set(handles.radioStartManual,'Value',0,'Enable',data.enableGUIControlsFlag);
        set(handles.radioStartFix,'Value',1,'Enable',data.enableGUIControlsFlag);
        if(strcmp(data.enableGUIControlsFlag,'On'))
            set(handles.editStartFix,'Enable','on','String',num2str(data.preProcessing.fixStartPos));
        else
            set(handles.editStartFix,'Enable','Off','String',num2str(data.preProcessing.fixStartPos));
        end
        handles.buttonStartManual.Enable = 'Off';
end
switch data.preProcessing.autoEndPos
    case 1
        set(handles.radioEndAuto,'Value',1,'Enable',data.enableGUIControlsFlag);
        set(handles.radioEndManual,'Value',0,'Enable',data.enableGUIControlsFlag);
        set(handles.radioEndFix,'Value',0,'Enable',data.enableGUIControlsFlag);
        set(handles.editEndFix,'Enable','Off','String',num2str(data.preProcessing.fixEndPos));
        handles.buttonEndManual.Enable = 'Off';
    case 0
        set(handles.radioEndAuto,'Value',0,'Enable',data.enableGUIControlsFlag);
        set(handles.radioEndManual,'Value',1,'Enable',data.enableGUIControlsFlag);
        set(handles.radioEndFix,'Value',0,'Enable',data.enableGUIControlsFlag);
        set(handles.editEndFix,'Enable','Off','String',num2str(data.preProcessing.fixEndPos));
        if(strcmp(data.enableGUIControlsFlag,'On'))
            handles.buttonEndManual.Enable = 'On';
        end
    case -1
        set(handles.radioEndAuto,'Value',0,'Enable',data.enableGUIControlsFlag);
        set(handles.radioEndManual,'Value',0,'Enable',data.enableGUIControlsFlag);
        set(handles.radioEndFix,'Value',1,'Enable',data.enableGUIControlsFlag);
        if(strcmp(data.enableGUIControlsFlag,'On'))
            set(handles.editEndFix,'Enable','On','String',num2str(data.preProcessing.fixEndPos));
        else
            set(handles.editEndFix,'Enable','Off','String',num2str(data.preProcessing.fixEndPos));
        end
        handles.buttonEndManual.Enable = 'Off';
end
%reflection removal
set(handles.editReflRemWinSz,'String',num2str(data.preProcessing.ReflRemWinSz));
set(handles.editReflRemGrpSz,'String',num2str(data.preProcessing.ReflRemGrpSz));
if(strcmp(data.enableGUIControlsFlag,'Off'))
    handles.buttonReflRemManual.Enable = 'Off';
    autoReflRemFlag = 'Off';
    radioFlag = 'Off';
else
    radioFlag = 'On';
    switch data.preProcessing.autoReflRem
        case 1
            handles.buttonReflRemManual.Enable = 'Off';            
            autoReflRemFlag = 'On';
        case 0
            handles.buttonReflRemManual.Enable = 'On';
            autoReflRemFlag = 'Off';
        case -1
            handles.buttonReflRemManual.Enable = 'Off';
            autoReflRemFlag = 'Off';
    end
end
switch data.preProcessing.autoReflRem
    case 1
        set(handles.radioReflRemAuto,'Value',1,'Enable',radioFlag);
        set(handles.radioReflRemManual,'Value',0,'Enable',radioFlag);
        set(handles.radioReflRemDisabled,'Value',0,'Enable',radioFlag);
    case 0
        set(handles.radioReflRemAuto,'Value',0,'Enable',radioFlag);
        set(handles.radioReflRemManual,'Value',1,'Enable',radioFlag);
        set(handles.radioReflRemDisabled,'Value',0,'Enable',radioFlag);
    case -1
        set(handles.radioReflRemAuto,'Value',0,'Enable',radioFlag);
        set(handles.radioReflRemManual,'Value',0,'Enable',radioFlag);
        set(handles.radioReflRemDisabled,'Value',1,'Enable',radioFlag);
end
set(handles.editReflRemWinSz,'String',num2str(data.preProcessing.ReflRemWinSz),'Enable',autoReflRemFlag);
set(handles.editReflRemGrpSz,'String',num2str(data.preProcessing.ReflRemGrpSz),'Enable',autoReflRemFlag);
set(handles.textReflRemWinSz,'Enable',autoReflRemFlag);
set(handles.textReflRemGrpSz,'Enable',autoReflRemFlag);
%binning
set(handles.radioStaticBinning,'Value',~data.preProcessing.roiAdaptiveBinEnable,'Enable',data.enableGUIControlsFlag);
set(handles.radioAdaptiveBinning,'Value',data.preProcessing.roiAdaptiveBinEnable,'Enable',data.enableGUIControlsFlag);
if(strcmp(data.enableGUIControlsFlag,'Off'))
    staticFlag = 'Off';
    adaptiveFlag = 'Off';
else
    switch data.preProcessing.roiAdaptiveBinEnable
        case 0
            staticFlag = 'On';
            adaptiveFlag = 'Off';
        case 1
            staticFlag = 'Off';
            adaptiveFlag = 'On';
    end
end
set(handles.editStaticBinFactor,'String',num2str(data.preProcessing.roiBinning),'Enable',staticFlag);
set(handles.buttonDecStaticBinFactor,'Enable',staticFlag);
set(handles.buttonIncStaticBinFactor,'Enable',staticFlag);
set(handles.textStaticBinFactor,'Enable',staticFlag);
set(handles.editAdaptiveBinFactor,'String',num2str(data.preProcessing.roiAdaptiveBinMax),'Enable',adaptiveFlag);
set(handles.editAdaptiveTargetPhotons,'String',num2str(data.preProcessing.roiAdaptiveBinThreshold),'Enable',adaptiveFlag);
set(handles.buttonDecAdaptiveBinFactor,'Enable',adaptiveFlag);
set(handles.buttonIncAdaptiveBinFactor,'Enable',adaptiveFlag);
set(handles.textAdaptiveBinFactor,'Enable',adaptiveFlag);
set(handles.textAdaptiveTargetPhotons,'Enable',adaptiveFlag);


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

% --- Executes on button press in buttonReflRemManual.
function buttonReflRemManual_Callback(hObject, eventdata, handles)
buttonStartManual_Callback(hObject, eventdata, handles)

% --- Executes on button press in buttonStartManual.
function buttonStartManual_Callback(hObject, eventdata, handles)
%start wizard
rdh = get(handles.preProcessOptionsFigure,'userdata');
nrChs = rdh.currentSubject.myMeasurement.nrSpectralChannels;
subjectName = rdh.currentSubject.name;
studyName = '';
if(~isempty(rdh.currentSubject.myParent))
    studyName = rdh.currentSubject.myParent.name;
end
for ch = 1:nrChs
    fi = rdh.currentSubject.myMeasurement.getFileInfoStruct(ch);
    if(~isempty(fi))
        [fi.StartPosition, fi.EndPosition, fi.reflectionMask] = GUI_startEndPosWizard(rdh.currentSubject.getROIMerged(ch),rdh.preProcessing,studyName,subjectName,ch,fi.StartPosition, fi.EndPosition);
        if(fi.StartPosition >= 0 &&  fi.EndPosition >= 0 && all(fi.reflectionMask(:) > 0))
            %user did not press cancel, force deletion of results after GUI closes
            handles.buttonCancel.Enable = 'Off';
            rdh.currentSubject.myMeasurement.setStartPosition(ch,fi.StartPosition);
            rdh.currentSubject.myMeasurement.setEndPosition(ch,fi.EndPosition);
            rdh.currentSubject.myMeasurement.setReflectionMask(ch,fi.reflectionMask);
        end
    end
end

% --- Executes on button press in buttonEndManual.
function buttonEndManual_Callback(hObject, eventdata, handles)
buttonStartManual_Callback(hObject, eventdata, handles)


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

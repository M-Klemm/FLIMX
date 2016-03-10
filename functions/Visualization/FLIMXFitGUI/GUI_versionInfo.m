function varargout = GUI_versionInfo(varargin)
%=============================================================================================================
%
% @file     GUI_versionInfo.m
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
% @brief    A GUI to show version and license information of FLIMX
%
% GUI_VERSIONINFO M-file for GUI_versionInfo.fig
%      GUI_VERSIONINFO, by itself, creates a new GUI_VERSIONINFO or raises the existing
%      singleton*.
%
%      H = GUI_VERSIONINFO returns the handle to a new GUI_VERSIONINFO or the handle to
%      the existing singleton*.
%
%      GUI_VERSIONINFO('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_VERSIONINFO.M with the given input arguments.
%
%      GUI_VERSIONINFO('Property','Value',...) creates a new GUI_VERSIONINFO or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_versionInfo_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_versionInfo_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_versionInfo

% Last Modified by GUIDE v2.5 08-Sep-2014 20:49:19

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_versionInfo_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_versionInfo_OutputFcn, ...
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


% --- Executes just before GUI_versionInfo is made visible.
function GUI_versionInfo_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_versionInfo (see VARARGIN)

% Choose default command line output for GUI_versionInfo
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

updateGUI(handles,varargin{1},varargin{2});

% UIWAIT makes GUI_versionInfo wait for user response (see UIRESUME)
uiwait(handles.versionInfoFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_versionInfo_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = [];
if isempty(handles)
    handles.output=[];    
else
    delete(handles.versionInfoFigure);    
end



function updateGUI(handles,dataS,dataR)
%
set(handles.textSclient,'String',num2str(dataS.client_revision/100,'%01.2f'));
set(handles.textScore,'String',num2str(dataS.core_revision/100,'%01.2f'));
set(handles.textSconfig,'String',num2str(dataS.config_revision/100,'%01.2f'));
set(handles.textSresults,'String',num2str(dataS.results_revision/100,'%01.2f'));

set(handles.textRclient,'String',num2str(dataR.client_revision/100,'%01.2f'));
set(handles.textRcore,'String',num2str(dataR.core_revision/100,'%01.2f'));
set(handles.textRconfig,'String',num2str(dataR.config_revision/100,'%01.2f'));
set(handles.textRresults,'String',num2str(dataR.results_revision/100,'%01.2f'));

buttonMexTest_Callback( [], [], handles);
%license
set(handles.editLicense,'String',FLIMX.getLicenseInfo());
%fill acknowledgements
set(handles.editAck,'String',FLIMX.getAcknowledgementInfo());



% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
uiresume(handles.versionInfoFigure);
delete(handles.versionInfoFigure); 

% --- Executes on button press in buttonMexTest.
function buttonMexTest_Callback(hObject, eventdata, handles)

data{1,1} = 'Static Binning';
data{2,1} = 'Adaptive Binning';
data{3,1} = 'Linear Optimization';
data(:,2) = num2cell(false(3,1));

if(measurementFile.testStaticBinMex())
    data{1,2} = true;
end
if(measurementFile.testAdaptiveBinMex())
    data{2,2} = true;
end
if(fluoPixelModel.testShiftLinOpt1024())
    data{3,2} = true;
end
set(handles.tableMexSupport,'Data',data);

% --- Executes on button press in buttonCreateMex.
function buttonCreateMex_Callback(hObject, eventdata, handles)
%try to create mex files
try
    set(hObject,'String',sprintf('<html><img src="file:/%s"/> Creating...</html>',FLIMX.getAnimationPath()));
end
drawnow;
%run coder
try
    coder -build getStaticBinROIMex.prj
catch ME
    errordlg(sprintf('Error compiling ''getStaticBinROIMex''\n\nIdentifier: %s\nMessage: %s',ME.identifier,ME.message),'MEX-File Gen. Error');
end
buttonMexTest_Callback(handles.buttonMexTest, eventdata, handles);
try
    coder -build getAdaptiveBinROIMex.prj
catch ME
    errordlg(sprintf('Error compiling ''getAdaptiveBinROIMex''\n\nIdentifier: %s\nMessage: %s',ME.identifier,ME.message),'MEX-File Gen. Error');
end
buttonMexTest_Callback(handles.buttonMexTest, eventdata, handles);
try
    coder -build shiftAndLinearOptMexWin.prj
catch ME
    errordlg(sprintf('Error compiling ''shiftAndLinearOptMexWin''\n\nIdentifier: %s\nMessage: %s',ME.identifier,ME.message),'MEX-File Gen. Error');
end
buttonMexTest_Callback(handles.buttonMexTest, eventdata, handles);
%update GUI
buttonMexTest_Callback(handles.buttonMexTest, eventdata, handles);
set(hObject,'String','Create Files');

% --- Executes on selection change in editAck.
function editAck_Callback(hObject, eventdata, handles)

function editLicense_Callback(hObject, eventdata, handles)


% --- Executes during object creation, after setting all properties.
function editAck_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editLicense_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

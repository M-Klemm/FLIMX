function varargout = GUI_optOptions(varargin)
%=============================================================================================================
%
% @file     GUI_optOptions.m
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
% @brief    A GUI to set optimizer options in FLIMXFit
%
% GUI_OPTOPTIONS M-file for GUI_optOptions.fig
%      GUI_OPTOPTIONS, by itself, creates a new GUI_OPTOPTIONS or raises the existing
%      singleton*.
%
%      H = GUI_OPTOPTIONS returns the handle to a new GUI_OPTOPTIONS or the handle to
%      the existing singleton*.
%
%      GUI_OPTOPTIONS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_OPTOPTIONS.M with the given input arguments.
%
%      GUI_OPTOPTIONS('Property','Value',...) creates a new GUI_OPTOPTIONS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_optOptions_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_optOptions_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_optOptions

% Last Modified by GUIDE v2.5 11-Nov-2015 10:57:31

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_optOptions_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_optOptions_OutputFcn, ...
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


% --- Executes just before GUI_optOptions is made visible.
function GUI_optOptions_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_optOptions (see VARARGIN)

% Choose default command line output for GUI_optOptions
% handles.output = hObject;

% Update handles structure
% guidata(hObject, handles);
rdh.optParams = varargin{1};
rdh.isDirty = [0 0 0 0]; %flags which part was changed, 1-de, 2-msimplexbnd, 2-fminsearchbnd, 4-pso
updateGUI(handles, rdh.optParams);  
set(handles.optOptionsFigure,'userdata',rdh);

% UIWAIT makes GUI_optOptions wait for user response (see UIRESUME)
uiwait(handles.optOptionsFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_optOptions_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=[];
    varargout{1} = [];
else
    out = get(handles.optOptionsFigure,'userdata'); 
    varargout{1} = out;
    delete(handles.optOptionsFigure);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles,data)
%de
set(handles.editDE_CR,'String',data.options_de.CR);
set(handles.editDE_F,'String',data.options_de.F);
set(handles.editDE_Fv,'String',data.options_de.Fv);
set(handles.editDE_NP,'String',data.options_de.NP);
set(handles.editDE_Strat,'String',data.options_de.strategy);
set(handles.editDE_Iter,'String',data.options_de.maxiter);
set(handles.editDE_MaxReInit,'String',data.options_de.maxReInitCnt);
set(handles.editDE_MaxBestValConst,'String',data.options_de.maxBestValConstCnt);
set(handles.editDE_BestValTol,'String',data.options_de.bestValTol);
set(handles.editDE_minValSD,'String',data.options_de.minvalstddev);
set(handles.editDE_minParamSD,'String',data.options_de.minparamstddev);
set(handles.editDE_StopVal,'String',data.options_de.stopVal);
%msimplexbnd
set(handles.editMSB_Fun,'String',data.options_msimplexbnd.MaxFunEvals);
set(handles.editMSB_Iter,'String',data.options_msimplexbnd.MaxIter);
set(handles.editMSB_TolFun,'String',data.options_msimplexbnd.TolFun);
set(handles.popupMSB_MultSeeds,'Value',data.options_msimplexbnd.multipleSeedsMode);
%fminsearchbnd
set(handles.editFMSB_Fun,'String',data.options_fminsearchbnd.MaxFunEvals);
set(handles.editFMSB_Iter,'String',data.options_fminsearchbnd.MaxIter);
set(handles.editFMSB_TolFun,'String',data.options_fminsearchbnd.TolFun);
set(handles.editFMSB_TolX,'String',data.options_fminsearchbnd.TolX);
%pso
set(handles.editPSO_CA,'String',num2str(data.options_pso.CognitiveAttraction));
set(handles.editPSO_CB,'String',data.options_pso.ConstrBoundary);
set(handles.editPSO_Generations,'String',num2str(data.options_pso.Generations));
set(handles.editPSO_PS,'String',num2str(data.options_pso.PopulationSize));
set(handles.editPSO_SA,'String',num2str(data.options_pso.SocialAttraction));
set(handles.editPSO_SGL,'String',num2str(data.options_pso.StallGenLimit));
set(handles.editPSO_time,'String',num2str(data.options_pso.TimeLimit));
set(handles.editPSO_TolX,'String',num2str(data.options_pso.TolCon));
set(handles.editPSO_TolFun,'String',num2str(data.options_pso.TolFun));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%de
function editDE_NP_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_de.NP = max(min(round(str2double(get(hObject,'String'))),100),1);
rdh.isDirty(1) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_de.NP));

function editDE_F_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_de.F = max(min(abs(str2double(get(hObject,'String'))),2),0.001);
rdh.isDirty(1) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_de.F));

function editDE_Fv_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_de.Fv = max(min(abs(str2double(get(hObject,'String'))),1),0.001);
rdh.isDirty(1) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_de.Fv));

function editDE_CR_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_de.CR = max(min(abs(str2double(get(hObject,'String'))),1),0.001);
rdh.isDirty(1) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_de.CR));

function editDE_Iter_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_de.maxiter = max(min(round(str2double(get(hObject,'String'))),10000),1);
rdh.isDirty(1) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_de.maxiter));

function editDE_Strat_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_de.strategy = max(min(round(str2double(get(hObject,'String'))),10),1);
rdh.isDirty(1) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_de.strategy));

function editDE_MaxBestValConst_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_de.maxBestValConstCnt = max(min(round(str2double(get(hObject,'String'))),1000),0);
rdh.isDirty(1) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_de.maxBestValConstCnt));

function editDE_MaxReInit_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_de.maxReInitCnt = max(min(round(str2double(get(hObject,'String'))),1000),1);
rdh.isDirty(1) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_de.maxReInitCnt));

function editDE_BestValTol_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_de.bestValTol = max(min(str2double(get(hObject,'String')),10),0.0001);
rdh.isDirty(1) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_de.bestValTol));

function editDE_minValSD_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_de.minvalstddev = max(min(str2double(get(hObject,'String')),10),0.0001);
rdh.isDirty(1) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_de.minvalstddev));

function editDE_minParamSD_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_de.minparamstddev = max(min(str2double(get(hObject,'String')),10),0.0001);
rdh.isDirty(1) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_de.minparamstddev));

function editDE_StopVal_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_de.stopVal = str2double(get(hObject,'String'));
rdh.isDirty(1) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_de.stopVal));

%msimplexbnd
function editMSB_Iter_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_msimplexbnd.MaxIter = max(min(round(str2double(get(hObject,'String'))),5000),1);
rdh.isDirty(2) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_msimplexbnd.MaxIter));

function editMSB_Fun_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_msimplexbnd.MaxFunEvals = max(min(round(str2double(get(hObject,'String'))),5000),1);
rdh.isDirty(2) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_msimplexbnd.MaxFunEvals));

function editMSB_TolFun_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_msimplexbnd.TolFun = max(min(str2double(get(hObject,'String')),100),0.00001);
rdh.isDirty(2) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_msimplexbnd.TolFun));

function popupMSB_MultSeeds_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_msimplexbnd.multipleSeedsMode = get(hObject,'String');
rdh.isDirty(2) = 1;
set(handles.optOptionsFigure,'userdata',rdh);

%fminsearchbnd
function editFMSB_Iter_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_fminsearchbnd.MaxIter = max(min(round(str2double(get(hObject,'String'))),5000),1);
rdh.isDirty(3) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_fminsearchbnd.MaxIter));

function editFMSB_Fun_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_fminsearchbnd.MaxFunEvals = max(min(round(str2double(get(hObject,'String'))),5000),1);
rdh.isDirty(3) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_fminsearchbnd.MaxFunEvals));

function editFMSB_TolFun_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_fminsearchbnd.TolFun = max(min(str2double(get(hObject,'String')),100),0.00001);
rdh.isDirty(3) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_fminsearchbnd.TolFun));

function editFMSB_TolX_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_fminsearchbnd.TolX = max(min(str2double(get(hObject,'String')),100),0.00001);
rdh.isDirty(3) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_fminsearchbnd.TolX));

%pso
function editPSO_PS_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_pso.PopulationSize = max(min(str2double(get(hObject,'String')),1000),1);
rdh.isDirty(4) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_pso.PopulationSize));

function editPSO_CA_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_pso.CognitiveAttraction = max(min(str2double(get(hObject,'String')),100),0.00001);
rdh.isDirty(4) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_pso.CognitiveAttraction));

function editPSO_CB_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_pso.ConstrBoundary = get(hObject,'String');
rdh.isDirty(4) = 1;
set(handles.optOptionsFigure,'userdata',rdh);

function editPSO_Generations_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_pso.Generations = max(min(str2double(get(hObject,'String')),1000),1);
rdh.isDirty(4) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_pso.Generations));

function editPSO_SA_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_pso.SocialAttraction = max(min(str2double(get(hObject,'String')),100),0.00001);
rdh.isDirty(4) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_pso.SocialAttraction));

function editPSO_SGL_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_pso.StallGenLimit = max(min(str2double(get(hObject,'String')),1000),1);
rdh.isDirty(4) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_pso.StallGenLimit));

function editPSO_time_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_pso.TimeLimit = max(min(str2double(get(hObject,'String')),100),0.001);
rdh.isDirty(4) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_pso.TimeLimit));

function editPSO_TolX_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_pso.TolCon = max(min(str2double(get(hObject,'String')),100),0.00001);
rdh.isDirty(4) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_pso.TolCon));

function editPSO_TolFun_Callback(hObject, eventdata, handles)
rdh = get(handles.optOptionsFigure,'userdata');
rdh.optParams.options_pso.TolFun = max(min(str2double(get(hObject,'String')),100),0.00001);
rdh.isDirty(4) = 1;
set(handles.optOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.optParams.options_pso.TolFun));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
uiresume(handles.optOptionsFigure);

% --- Executes on button press in buttonCancel.
function buttonCancel_Callback(hObject, eventdata, handles)
uiresume(handles.optOptionsFigure);
delete(handles.optOptionsFigure);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%checkboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%radio buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function popupInitOptimizer_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editMCPath_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupNExp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupNtci_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupPPOptimizer_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupPPHeightMode_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupPPErrorMode_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupInitErrorMode_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupInitHeightMode_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDE_Strat_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editMSB_Iter_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editMSB_Fun_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editMSB_TolFun_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDE_NP_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDE_F_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDE_CR_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDE_Iter_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editFMSB_Iter_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editFMSB_Fun_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editFMSB_TolFun_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editFMSB_TolX_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDE_Fv_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDE_MaxBestValConst_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDE_MaxReInit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDE_BestValTol_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupMSB_MultSeeds_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editPSO_SA_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editPSO_PS_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editPSO_CB_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editPSO_CA_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editPSO_SGL_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editPSO_Generations_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editPSO_TolFun_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editPSO_time_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editPSO_TolX_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDE_minValSD_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDE_minParamSD_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editDE_StopVal_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

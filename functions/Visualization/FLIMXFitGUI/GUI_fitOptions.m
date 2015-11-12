function varargout = GUI_fitOptions(varargin)
%=============================================================================================================
%
% @file     GUI_fitOptions.m
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
% @brief    A GUI to set approximation options in FLIMXFit
%
% GUI_FITOPTIONS M-file for GUI_fitOptions.fig
%      GUI_FITOPTIONS, by itself, creates a new GUI_FITOPTIONS or raises the existing
%      singleton*.
%
%      H = GUI_FITOPTIONS returns the handle to a new GUI_FITOPTIONS or the handle to
%      the existing singleton*.
%
%      GUI_FITOPTIONS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_FITOPTIONS.M with the given input arguments.
%
%      GUI_FITOPTIONS('Property','Value',...) creates a new GUI_FITOPTIONS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_fitOptions_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_fitOptions_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_fitOptions

% Last Modified by GUIDE v2.5 05-Nov-2015 15:13:54

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_fitOptions_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_fitOptions_OutputFcn, ...
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


% --- Executes just before GUI_fitOptions is made visible.
function GUI_fitOptions_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_fitOptions (see VARARGIN)

% Choose default command line output for GUI_fitOptions
% handles.output = hObject;

% Update handles structure
% guidata(hObject, handles);
rdh.basic = varargin{1};
rdh.init = varargin{2};
rdh.pixel = varargin{3};
rdh.volatilePixel = varargin{4};
rdh.volatileChannel = varargin{5};
rdh.bounds = varargin{6};
rdh.IRFStr = varargin{7};
rdh.IRFMask = varargin{8};
rdh.studiesStr = varargin{9};
rdh.isDirty = [0 0 0]; %flags which part was changed, 1-basic, 2-init, 3-pixel
updateGUI(handles, rdh);  
set(handles.fitOptionsFigure,'userdata',rdh);

% UIWAIT makes GUI_fitOptions wait for user response (see UIRESUME)
uiwait(handles.fitOptionsFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_fitOptions_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=[];
    varargout{1} = [];
else
    out = get(handles.fitOptionsFigure,'userdata');
    out.init.optimizer = out.init.optimizer(out.init.optimizer ~= 0);
    out.pixel.optimizer = out.pixel.optimizer(out.pixel.optimizer ~= 0);
    varargout{1} = out;
    delete(handles.fitOptionsFigure);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles,data)
%general
set(handles.popupApproxTarget,'Value',data.basic.approximationTarget);
if(data.basic.approximationTarget == 2)
    %anisotropy
    set(handles.panelApproxModel,'Visible','off');
    set(handles.panelAnisotropy,'Visible','on');
else
    %lifetime
    set(handles.panelApproxModel,'Visible','on');
    set(handles.panelAnisotropy,'Visible','off');
end
set(handles.checkReconvolute,'Value',data.basic.reconvoluteWithIRF)
if(data.basic.reconvoluteWithIRF)
    set(handles.popupIRF,'Visible','on');
else
    set(handles.popupIRF,'Visible','off');
end
set(handles.popupNExp,'Value',data.basic.nExp);
if(data.basic.nExp == 1)
    set(handles.popupAmplitudeOrder,'Value',1,'Enable','off');
    set(handles.textAmplitudeOrder,'Enable','off');
else
    set(handles.popupAmplitudeOrder,'Value',data.basic.amplitudeOrder+1,'Enable','on');
    set(handles.textAmplitudeOrder,'Enable','on');
end
set(handles.editLifetimeGap,'String',(data.basic.lifetimeGap-1)*100);
switch data.basic.hybridFit
    case 0
        hybridHeightFlag = 'on';
    case 1
        hybridHeightFlag = 'off';
end
set(handles.popupOffsetFit,'Value',data.basic.nonLinOffsetFit);
if(isempty(data.IRFStr))
    set(handles.popupIRF,'String','no IRF found','Value',1);
else
    idx = find(strcmp(data.basic.curIRFID,data.IRFStr));
    if(isempty(idx))
        idx = 1;
    end
    set(handles.popupIRF,'String',data.IRFStr,'Value',idx);
end
switch data.basic.fitModel
    case 0
        set(handles.radioTciFit,'Value',0);
        set(handles.radioTailFit,'Value',1);
    case 1
        set(handles.radioTciFit,'Value',1);
        set(handles.radioTailFit,'Value',0);
    case 2
        set(handles.radioTciFit,'Value',0);
        set(handles.radioTailFit,'Value',0);
end
tcilen = length(data.basic.tciMask);
stelen = length(data.basic.stretchedExpMask);
for i = 1:5
    %tci
    if(data.basic.fitModel ~= 1 || i > tcilen)
        set(handles.(sprintf('checkTc%d',i)),'Enable','off','Value',0);
    else
        set(handles.(sprintf('checkTc%d',i)),'Enable','on','Value',data.basic.tciMask(i));
    end
    %stretched exp
    if(i > stelen)
        set(handles.(sprintf('checkSE%d',i)),'Enable','off','Value',0);
    else
        set(handles.(sprintf('checkSE%d',i)),'Enable','on','Value',data.basic.stretchedExpMask(i));
    end
    %global fit
    if(i > data.basic.nExp)
        set(handles.(sprintf('checkGFTau%d',i)),'Enable','off','Value',0);        
    else
        set(handles.(sprintf('checkGFTau%d',i)),'Enable','on','Value',any(strcmp(sprintf('Tau %d',i),data.basic.globalFitMaskSaveStr)));
    end
    if(data.basic.fitModel ~= 1 || i > data.basic.nExp || data.basic.tciMask(i) == 0)
        set(handles.(sprintf('checkGFtc%d',i)),'Enable','off','Value',0);        
    else
        set(handles.(sprintf('checkGFtc%d',i)),'Enable','on','Value',any(strcmp(sprintf('tc %d',i),data.basic.globalFitMaskSaveStr)));
    end
end
%anisotropy controls
set(handles.editAnisoChannelShift,'String',data.basic.anisotropyChannelShift);
set(handles.editAnisoGFactor,'String',data.basic.anisotropyGFactor);
set(handles.editAnisoPerpenFactor,'String',data.basic.anisotropyPerpendicularFactor);
set(handles.popupAnisoR0Method,'Value',data.basic.anisotropyR0Method);
set(handles.checkIDec,'Value',data.basic.incompleteDecay);
set(handles.editPhotons,'String',num2str(data.basic.photonThreshold));
set(handles.checkSmoothInitFix,'Value',data.basic.fix2InitSmoothing);
set(handles.editInitGridSize,'String',num2str(data.init.gridSize));
set(handles.editInitGridPhotons,'String',num2str(data.init.gridPhotons));
set(handles.editResultValidyCheckCnt,'String',num2str(data.basic.resultValidyCheckCnt));
switch data.basic.neighborFit
    case 0
        set(handles.popupNBPixels,'Value',1);
    case 4
        set(handles.popupNBPixels,'Value',2);
    case 8
        set(handles.popupNBPixels,'Value',3);
end
set(handles.editNBWeight,'String',num2str(data.basic.neighborWeight));
set(handles.popupPPErrorMode,'Value',data.basic.errorMode);
set(handles.popupChiWeighting,'Value',data.basic.chiWeightingMode);
switch data.basic.errorMode
    case 2
        set(handles.textErrorMPixelP1,'String','Boost Factor','Visible','on');
        set(handles.textErrorMPixelP2,'String','pre-Max Window-Size','Visible','on');
        set(handles.textErrorMPixelP3,'String','post-Max Window-Size','Visible','on');
        
        set(handles.editErrorMPixelP1,'String',data.basic.ErrorMP1,'Visible','on');
        set(handles.editErrorMPixelP2,'String',data.basic.ErrorMP2,'Visible','on');
        set(handles.editErrorMPixelP3,'String',data.basic.ErrorMP3,'Visible','on');
    otherwise
        set(handles.textErrorMPixelP1,'String','','Visible','off');
        set(handles.textErrorMPixelP2,'String','','Visible','off');
        set(handles.textErrorMPixelP3,'String','','Visible','off');
        set(handles.editErrorMPixelP1,'String','','Visible','off');
        set(handles.editErrorMPixelP2,'String','','Visible','off');
        set(handles.editErrorMPixelP3,'String','','Visible','off');
end

%init
set(handles.popupInitOptimizer,'Value',data.init.optimizer(1));
%per pixel
set(handles.popupPPOptInit,'Value',data.basic.optimizerInitStrategy);
set(handles.popupPPOptimizer1,'Value',data.pixel.optimizer(1));
if(length(data.pixel.optimizer) > 1)
    set(handles.popupPPOptimizer2,'Value',data.pixel.optimizer(2) + 1);
else
    set(handles.popupPPOptimizer2,'Value',1);
end
set(handles.popupPPDimension,'Value',data.pixel.fitDimension);
%constant parameters
set(handles.tableConstParams,'ColumnName',{'Parameter','Value','manual','Init.'});
set(handles.tableConstParams,'ColumnWidth',{80,50,55,55});
set(handles.tableConstParams,'ColumnEditable',[false,true,true,true]);
dstr = getTableData(get(handles.popupChannel,'Value'),data.basic,data.bounds,data.volatilePixel);
set(handles.tableConstParams,'Data',dstr);
%init fit panel
if(any([dstr{:,4}]) || data.basic.optimizerInitStrategy == 2)
    set(handles.panelInitFit,'Visible','on');
else
    set(handles.panelInitFit,'Visible','off');
end
%scatter light
if(data.basic.scatterEnable)
    scatterEn = 'on';
else
    scatterEn = 'off';
end
set(handles.checkScatterEnable,'Value',data.basic.scatterEnable);
set(handles.checkScatterIRF,'Value',data.basic.scatterIRF,'enable',scatterEn);
set(handles.textScatterStudy,'enable',scatterEn);
str = {'-'};
if(any(~cellfun('isempty',data.studiesStr)))
    str(2:1+length(data.studiesStr)) = data.studiesStr;
end
scatterTarget = find(strcmp(data.basic.scatterStudy,data.studiesStr),1);
if(isempty(data.basic.scatterStudy) || isempty(scatterTarget))
    set(handles.popupScatterStudy,'String',str,'Value',1,'enable',scatterEn);
else    
    set(handles.popupScatterStudy,'String',str,'Value',scatterTarget+1,'enable',scatterEn);    
end

function dstr = getTableData(ch,basicParams,bounds,volatilePixelParams)
%make cell array for table
dstr = cell(0,4);
for i = 1:basicParams.nExp
    dstr{i,1} = sprintf('Amplitude %d',i);
    dstr{i+basicParams.nExp,1} = sprintf('Tau %d',i);
    switch basicParams.nExp
        case {1,2,3}
            dstr(i,2) = {bounds.(sprintf('bounds_%d_exp',basicParams.nExp)).init(i)};
            dstr(basicParams.nExp+i,2) = {bounds.(sprintf('bounds_%d_exp',basicParams.nExp)).init(basicParams.nExp+i)};
        otherwise
            if(i < 4)
                dstr(i,2) = {bounds.bounds_3_exp.init(i)};
                dstr(basicParams.nExp+i,2) = {bounds.bounds_3_exp.init(3+i)};
            else
                dstr(i,2) = {bounds.bounds_nExp.init(1)};
                dstr(basicParams.nExp+i,2) = {bounds.bounds_nExp.init(2)};
            end
    end
end
tcis = find(basicParams.tciMask);
row = 2*basicParams.nExp;
for i = 1:length(tcis)
    row = row+1;
    dstr(row,1) = {sprintf('tc %d',tcis(i))};
    dstr(row,2) = {bounds.bounds_tci.init(1)};
end
ses = find(basicParams.stretchedExpMask);
for i = 1:length(ses)
    row = row+1;
    dstr(row,1) = {sprintf('Beta %d',ses(i))};
    dstr(row,2) = {bounds.bounds_s_exp.init(1)};
end
for i = 1:volatilePixelParams.nScatter
    dstr(end+1,1) = {sprintf('ScatterAmplitude %d',i)};
    dstr(end,2) = {bounds.bounds_scatter.init(1)};
    dstr(end+1,1) = {sprintf('ScatterShift %d',i)};
    dstr(end,2) = {bounds.bounds_scatter.init(2)};
    dstr(end+1,1) = {sprintf('ScatterOffset %d',i)};
    dstr(end,2) = {bounds.bounds_scatter.init(3)};
end
dstr(end+1,1) = {'hShift'}; 
dstr(end,2) = {bounds.bounds_h_shift.init(1)};
dstr(end+1,1) = {'Offset'};
dstr(end,2) = {bounds.bounds_offset.init(1)};

dstr(:,3) = num2cell(false(length(dstr),1));
dstr(:,4) = num2cell(false(length(dstr),1));
for i = 1 : size(dstr,1)
    idxConst = find(strcmp(dstr{i},basicParams.(sprintf('constMaskSaveStrCh%d',ch))),1);
    idxInit = strcmp(dstr{i},basicParams.fix2InitTargets);
    if(any(idxConst))
        tmp = basicParams.(sprintf('constMaskSaveValCh%d',ch));
        if(length(tmp) >= idxConst)
            dstr(i,2) = {tmp(idxConst)};
        else
            
        end
        dstr(i,3) = {true};
    end
    if(any(idxInit))
        dstr(i,4) = {true};
    end    
end

function str = makeGlobalFitSaveString(handles)
%build a cell array of all global fit parameter names
str = cell(0,0);
names = {'Tau 1','Tau 2','Tau 3','Tau 4','Tau 5','tc 1','tc 2','tc 3','tc 4','tc 5'};
for i = 1:length(names)
    str = checkGlobalFitCheckbox(handles,str,names{i});
end

function str = checkGlobalFitCheckbox(handles,str,name)
%add parameter name to the cell array str if checkbox enabled
idx = isstrprop(name,'wspace');
if(get(handles.(sprintf('checkGF%s',name(~idx))),'Value'))
    str(end+1,1) = {name};
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%checkboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in checkReconvolute.
function checkReconvolute_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.reconvoluteWithIRF = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkHybridFit.
function checkHybridFit_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.hybridFit = get(hObject,'Value');
if(rdh.basic.hybridFit)
    %currently only auto height mode supported by hybrid fit
    rdh.basic.heightMode = 1;
else
    %for 'complete' nonlinear fit we prefer fixed height mode
    rdh.basic.heightMode = 2;
    %only allow linear offset fit in hybrid fit mode
    rdh.basic.nonLinOffsetFit = max(2,rdh.basic.nonLinOffsetFit);
    set(handles.popupOffsetFit,'Value',rdh.basic.nonLinOffsetFit);
end
rdh.isDirty(1) = 1;
rdh.isDirty(2) = 1;
rdh.isDirty(3) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkSmoothInitFix.
function checkSmoothInitFix_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.fix2InitSmoothing = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkTc1.
function checkTc1_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.tciMask(1) = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkTc2.
function checkTc2_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.tciMask(2) = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkTc3.
function checkTc3_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.tciMask(3) = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkTc4.
function checkTc4_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.tciMask(4) = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkTc5.
function checkTc5_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.tciMask(5) = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkSE1.
function checkSE1_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.stretchedExpMask(1) = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkSE2.
function checkSE2_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.stretchedExpMask(2) = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkSE3.
function checkSE3_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.stretchedExpMask(3) = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkSE4.
function checkSE4_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.stretchedExpMask(4) = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkSE5.
function checkSE5_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.stretchedExpMask(5) = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkGFTau1.
function checkGFTau1_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.globalFitMaskSaveStr = makeGlobalFitSaveString(handles);
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkGFTau2.
function checkGFTau2_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.globalFitMaskSaveStr = makeGlobalFitSaveString(handles);
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkGFTau3.
function checkGFTau3_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.globalFitMaskSaveStr = makeGlobalFitSaveString(handles);
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkGFTau4.
function checkGFTau4_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.globalFitMaskSaveStr = makeGlobalFitSaveString(handles);
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkGFTau5.
function checkGFTau5_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.globalFitMaskSaveStr = makeGlobalFitSaveString(handles);
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkGFtc1.
function checkGFtc1_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.globalFitMaskSaveStr = makeGlobalFitSaveString(handles);
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkGFtc2.
function checkGFtc2_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.globalFitMaskSaveStr = makeGlobalFitSaveString(handles);
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkGFtc3.
function checkGFtc3_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.globalFitMaskSaveStr = makeGlobalFitSaveString(handles);
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkGFtc4.
function checkGFtc4_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.globalFitMaskSaveStr = makeGlobalFitSaveString(handles);
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkGFtc5.
function checkGFtc5_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.globalFitMaskSaveStr = makeGlobalFitSaveString(handles);
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkIDec.
function checkIDec_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.incompleteDecay = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);

% --- Executes on button press in checkScatterEnable.
function checkScatterEnable_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.scatterEnable = get(hObject,'Value');
rdh.isDirty(1) = 1;
[rdh.volatilePixel, rdh.volatileChannel{get(handles.popupChannel,'Value')}] = paramMgr.makeVolatileParams(rdh.basic,2);
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkScatterIRF.
function checkScatterIRF_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.scatterIRF = get(hObject,'Value');
rdh.isDirty(1) = 1;
[rdh.volatilePixel, rdh.volatileChannel{get(handles.popupChannel,'Value')}] = paramMgr.makeVolatileParams(rdh.basic,2);
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkFittedChiWeighting.
function checkFittedChiWeighting_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.fittedChiWeighting = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editLifetimeGap_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.lifetimeGap = abs(str2double(get(hObject,'String'))) / 100 + 1;
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str((rdh.basic.lifetimeGap-1)*100));

function editPhotons_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.photonThreshold = round(abs(str2double(get(hObject,'String'))));
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.basic.photonThreshold));

function editAnisoChannelShift_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.anisotropyChannelShift = str2double(get(hObject,'String'));
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);

function editAnisoGFactor_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.anisotropyGFactor = abs(str2double(get(hObject,'String')));
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.basic.anisotropyGFactor));

function editAnisoPerpenFactor_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.anisotropyPerpendicularFactor = abs(str2double(get(hObject,'String')));
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.basic.anisotropyPerpendicularFactor));

function editInitGridSize_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.init.gridSize = round(abs(str2double(get(hObject,'String'))));
rdh.isDirty(2) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.init.gridSize));

function editInitGridPhotons_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.init.gridPhotons = round(abs(str2double(get(hObject,'String'))));
rdh.isDirty(2) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
set(hObject,'String',num2str(rdh.init.gridPhotons));

function editResultValidyCheckCnt_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.resultValidyCheckCnt = abs(str2double(get(hObject,'String')));
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

function editNBWeight_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.neighborWeight = abs(str2double(get(hObject,'String')));
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

function editErrorMPixelP1_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.ErrorMP1 = str2double(get(hObject,'String'));
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

function editErrorMPixelP2_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.ErrorMP2 = str2double(get(hObject,'String'));
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

function editErrorMPixelP3_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.ErrorMP3 = str2double(get(hObject,'String'));
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%radio buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in radioTciFit.
function radioTciFit_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.fitModel = 1;
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in radioTailFit.
function radioTailFit_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.fitModel = 0;
rdh.basic.tciMask = zeros(size(rdh.basic.tciMask));
%rdh.basic.stretchedExpMask = zeros(size(rdh.basic.stretchedExpMask));
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on button press in radioTailFitNoIRF.
function radioTailFitNoIRF_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.fitModel = 2;
rdh.basic.tciMask = zeros(size(rdh.basic.tciMask));
%rdh.basic.stretchedExpMask = zeros(size(rdh.basic.stretchedExpMask));
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
uiresume(handles.fitOptionsFigure);

% --- Executes on button press in buttonCancel.
function buttonCancel_Callback(hObject, eventdata, handles)
uiresume(handles.fitOptionsFigure);
delete(handles.fitOptionsFigure);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on selection change in popupNExp.
function popupNExp_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
new = get(hObject,'Value');
if(new > rdh.basic.nExp)
    rdh.basic.tciMask = [rdh.basic.tciMask zeros(1,new-rdh.basic.nExp)];
    rdh.basic.stretchedExpMask = [rdh.basic.stretchedExpMask zeros(1,new-rdh.basic.nExp)];
else
    rdh.basic.tciMask = rdh.basic.tciMask(1:new);
    rdh.basic.stretchedExpMask = rdh.basic.stretchedExpMask(1:new);
end
rdh.basic.nExp = new;
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on selection change in popupAmplitudeOrder.
function popupAmplitudeOrder_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.amplitudeOrder = get(hObject,'Value')-1;
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
set(hObject,'Value',rdh.basic.nonLinOffsetFit);
updateGUI(handles, rdh);

% --- Executes on button press in popupOffsetFit.
function popupOffsetFit_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.nonLinOffsetFit = get(hObject,'Value');
if(rdh.basic.hybridFit == 0)
    %only allow linear offset fit in hybrid fit mode
    rdh.basic.nonLinOffsetFit = max(2,rdh.basic.nonLinOffsetFit);
end
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
set(hObject,'Value',rdh.basic.nonLinOffsetFit);

% --- Executes on selection change in popupIRF.
function popupIRF_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');  
str = get(hObject,'String');
if(~isempty(str) && iscell(str))
    str = str{get(hObject,'Value')};
end
if(~strcmp('no IRF found',str))
    rdh.basic.curIRFID = str;%rdh.IRFMask(get(hObject,'Value'));
end
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);

% --- Executes on selection change in popupApproxTarget.
function popupApproxTarget_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.approximationTarget = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on selection change in popupAnisoR0Method.
function popupAnisoR0Method_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.anisotropyR0Method = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on selection change in popupNBPixels.
function popupNBPixels_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');  
switch get(hObject,'Value')
    case 1
        rdh.basic.neighborFit = 0;
    case 2
        rdh.basic.neighborFit = 4;
    case 3
        rdh.basic.neighborFit = 8;
end
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);

% --- Executes on selection change in popupChannel.
function popupChannel_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
updateGUI(handles, rdh);

% --- Executes on selection change in popupPPOptimizer12.
function popupInitOptimizer_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
current = get(hObject,'Value');
if(current == 1 || current == 4 || current == 6)
    current = [current 2]; %add simplex after differnetial evolution
end
rdh.init.optimizer = current;
rdh.isDirty(2) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);

% --- Executes on selection change in popupPPOptInit.
function popupPPOptInit_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.optimizerInitStrategy = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on selection change in popupPPOptimizer1.
function popupPPOptimizer1_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.pixel.optimizer(1) = get(hObject,'Value');
rdh.isDirty(3) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);

% --- Executes on selection change in popupPPOptimizer12.
function popupPPOptimizer2_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.pixel.optimizer(2) = get(hObject,'Value')-1;
rdh.isDirty(3) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);

% --- Executes on selection change in popupPPErrorMode.
function popupPPErrorMode_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.errorMode = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on selection change in popupChiWeighting.
function popupChiWeighting_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.basic.chiWeightingMode = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

% --- Executes on selection change in popupPPDimension.
function popupPPDimension_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
rdh.pixel.fitDimension = get(hObject,'Value');
rdh.isDirty(3) = 1;
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh); 

% --- Executes on selection change in popupScatterStudy.
function popupScatterStudy_Callback(hObject, eventdata, handles)
rdh = get(handles.fitOptionsFigure,'userdata');
str = get(hObject,'String');
val = get(hObject,'Value');
if(val == 1)
    str = '';
elseif(~isempty(str) && iscell(str))
    str = str{val};
% elseif(ischar(str))
%     str = str;
end
rdh.basic.scatterStudy = str;
rdh.isDirty(1) = 1;
[rdh.volatilePixel, rdh.volatileChannel{get(handles.popupChannel,'Value')}] = paramMgr.makeVolatileParams(rdh.basic,2);
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%tables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes when entered data in editable cell(s) in tableConstParams.
function tableConstParams_CellEditCallback(hObject, eventdata, handles)
data = get(hObject,'Data');
rdh = get(handles.fitOptionsFigure,'userdata');
%check bounds
lb = zeros(size(data,1),1);
ub = zeros(size(data,1),1);
switch rdh.basic.nExp
        case {1,2,3}
            lb(1:2*rdh.basic.nExp) = rdh.bounds.(sprintf('bounds_%d_exp',rdh.basic.nExp)).lb;
            ub(1:2*rdh.basic.nExp) = rdh.bounds.(sprintf('bounds_%d_exp',rdh.basic.nExp)).ub;
    otherwise
            lb(1:3) = rdh.bounds.bounds_3_exp.lb(1:3); %amps
            ub(1:3) = rdh.bounds.bounds_3_exp.ub(1:3); %amps
            lb(rdh.basic.nExp+1:rdh.basic.nExp+3) = rdh.bounds.bounds_3_exp.lb(4:6); %taus
            ub(rdh.basic.nExp+1:rdh.basic.nExp+3) = rdh.bounds.bounds_3_exp.ub(4:6); %taus            
            lb(4:rdh.basic.nExp) = repmat(rdh.bounds.bounds_nExp.lb(1),1,rdh.basic.nExp-3); %amps
            ub(4:rdh.basic.nExp) = repmat(rdh.bounds.bounds_nExp.ub(1),1,rdh.basic.nExp-3); %amps
            lb(rdh.basic.nExp+4:2*rdh.basic.nExp) = repmat(rdh.bounds.bounds_nExp.lb(2),1,rdh.basic.nExp-3); %amps
            ub(rdh.basic.nExp+4:2*rdh.basic.nExp) = repmat(rdh.bounds.bounds_nExp.ub(2),1,rdh.basic.nExp-3); %amps
end
%tcis
tcis = find(rdh.basic.tciMask);
for i = 1:length(tcis)
    lb(i+2*rdh.basic.nExp) = rdh.bounds.bounds_tci.lb(1);
    ub(i+2*rdh.basic.nExp) = rdh.bounds.bounds_tci.ub(1);
end
row = 2*rdh.basic.nExp+length(tcis);
%stretched exponentials (betas)
ses = find(rdh.basic.stretchedExpMask);
for i = 1:length(ses)
    row = row+1;
    lb(row) = rdh.bounds.bounds_s_exp.lb(1);
    ub(row) = rdh.bounds.bounds_s_exp.ub(1);    
end
%scatter
for i = 1:3:3*rdh.volatilePixel.nScatter
    lb(i+row) = rdh.bounds.bounds_scatter.lb(1);
    ub(i+row) = rdh.bounds.bounds_scatter.ub(1);
    lb(i+row+1) =  rdh.bounds.bounds_scatter.lb(2);
    ub(i+row+1) = rdh.bounds.bounds_scatter.ub(2);
    lb(i+row+2) = rdh.bounds.bounds_scatter.lb(3);
    ub(i+row+2) = rdh.bounds.bounds_scatter.ub(3);
end
%shifts
row = row+3*rdh.volatilePixel.nScatter+1;
lb(row) = rdh.bounds.bounds_h_shift.lb(1);
ub(row) = rdh.bounds.bounds_h_shift.ub(1);
row = row+1;
%offset
lb(row) = rdh.bounds.bounds_offset.lb(1);
ub(row) = rdh.bounds.bounds_offset.ub(1);
data(:,2) = num2cell(checkBounds([data{:,2}]',lb,ub));
%set constant flags
idx = [data{:,3}] == [data{:,4}] & [data{:,3}] > 0;
if(~isempty(idx) && any(idx))
    data{idx,3} = false;
end
if(get(handles.popupChannel,'Value') == 1)
    ch = 1;
else
    ch = 2;
end
rdh.basic.(sprintf('constMaskSaveStrCh%d',ch)) = data([data{:,3}],1);%;
%rdh.basic.(sprintf('constMaskSaveStrCh%d',2)) = data([data{:,3}],1);
rdh.basic.(sprintf('constMaskSaveValCh%d',ch)) = [data{[data{:,3}],2}];
dstr = getTableData(ch,rdh.basic,rdh.bounds,rdh.volatilePixel);
rdh.basic.(sprintf('constMaskSaveValCh%d',ch)) = [dstr{[data{:,3}],2}];
rdh.basic.fix2InitTargets = data([data{:,4}],1);
rdh.isDirty(1) = 1;
set(hObject,'Data',data);
set(handles.fitOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function popupInitOptimizer_CreateFcn(hObject, eventdata, handles)
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
function popupPPOptimizer1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupPPErrorMode_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editPhotons_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editErrorMPixelP1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editErrorMPixelP2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editErrorMPixelP3_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editErrorMInitP1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editErrorMInitP2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editErrorMInitP3_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupPPDimension_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupPPOptimizer2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupPPOptInit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editMCInit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupOffsetFit_CreateFcn(hObject, eventdata, handles)
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editLifetimeGap_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editResultValidyCheckCnt_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupIRF_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editNBWeight_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupNBPixels_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupChannel_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editInitGridSize_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editInitGridPhotons_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupScatterStudy_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupChiWeighting_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editAnisoChannelShift_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editAnisoGFactor_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editAnisoPerpenFactor_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupAnisoR0Method_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupApproxTarget_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupAmplitudeOrder_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

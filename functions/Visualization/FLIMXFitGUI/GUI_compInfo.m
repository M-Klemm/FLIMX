function varargout = GUI_compInfo(varargin)
%=============================================================================================================
%
% @file     GUI_compInfo.m
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
% @brief    A GUI to show information about the computation in FLIMXFit
%
% GUI_COMPINFO M-file for GUI_compInfo.fig
%      GUI_COMPINFO, by itself, creates a new GUI_COMPINFO or raises the existing
%      singleton*.
%
%      H = GUI_COMPINFO returns the handle to a new GUI_COMPINFO or the handle to
%      the existing singleton*.
%
%      GUI_COMPINFO('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_COMPINFO.M with the given input arguments.
%
%      GUI_COMPINFO('Property','Value',...) creates a new GUI_COMPINFO or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_compInfo_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_compInfo_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_compInfo

% Last Modified by GUIDE v2.5 25-Jul-2016 17:11:28

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_compInfo_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_compInfo_OutputFcn, ...
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


% --- Executes just before GUI_compInfo is made visible.
function GUI_compInfo_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_compInfo (see VARARGIN)

% Choose default command line output for GUI_compInfo
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);
updateGUI(handles,varargin{1});

% UIWAIT makes GUI_compInfo wait for user response (see UIRESUME)
uiwait(handles.compInfoFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_compInfo_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = [];
if isempty(handles)
    handles.output=[];    
else
    delete(handles.compInfoFigure);    
end


function updateGUI(handles,data)
%
if(isempty(data.hostname{1,1}))
    return;
end
    
% hostsS = unique(data.hostname(logical(data.standalone)));
% hostsM = unique(data.hostname(~data.standalone));
nonEIdx = ~cellfun('isempty',data.hostname);
allHosts = unique(data.hostname(nonEIdx));
nrAllHosts = size(allHosts,1);
work = zeros(nrAllHosts,2);
time = zeros(nrAllHosts,2);

for i = 1:nrAllHosts
    %standalone
    tmp = data.FunctionEvaluations(strcmp(allHosts(i,1),data.hostname) & logical(data.standalone) & (data.Iterations ~= 0));
    work(i,1) = sum(tmp(:));
    tmp = data.Time(strcmp(allHosts(i,1),data.hostname) & logical(data.standalone) & data.Time ~= 0);
    time(i,1) = sum(tmp(:)); 
    %matlab
    tmp = data.FunctionEvaluations(strcmp(allHosts(i,1),data.hostname) & ~data.standalone & (data.Iterations ~= 0));
    work(i,2) = sum(tmp(:));  
    tmp = data.Time(strcmp(allHosts(i,1),data.hostname) & ~data.standalone & data.Time ~= 0);
    time(i,2) = sum(tmp(:));     
end

workPercS = work(:,1)./sum(work(:,1));
workPercA = sum(work,2)./sum(work(:));

hostsPercS = cell(nrAllHosts,1);
hostsPercA = cell(nrAllHosts,1);
for i=1:nrAllHosts
    hostsPercS{i,1} = sprintf('%s %d%%',allHosts{i,1},round(workPercS(i)*100));
    hostsPercA{i,1} = sprintf('%s %d%%',allHosts{i,1},round(workPercA(i)*100));
end

explodeS = zeros(nrAllHosts,1);
explodeM = zeros(nrAllHosts,1);
[~, idx] = max(work(:,1));
explodeS(idx) = 1;
[~, idx] = max(sum(work,2));
explodeM(idx) = 1;

%axes(handles.axesWorkStandalone);
idx = work(:,1) ~= 0;
tmp = work(idx,1);
explodeS = explodeS(idx);
hostsPercS = hostsPercS(idx);
if(isempty(tmp))
    cla(handles.axesWorkStandalone);
    axis(handles.axesWorkStandalone,'off');
else
    pie3(handles.axesWorkStandalone,tmp,explodeS,hostsPercS);
    title(handles.axesWorkStandalone,'Work-share of Deployed Code (Servers)');
end
%axes(handles.axesWorkTotal);
pie3(handles.axesWorkTotal,sum(work,2)',explodeM,hostsPercA);
title(handles.axesWorkTotal,'Work-share of all Hosts');

eff(:,1) = time(:,1) ./ work(:,1) *1000;
eff(:,2) = time(:,2) ./ work(:,2) *1000;
%ym = max(eff(:));
%axes(handles.axesHostEff);
b = bar(handles.axesHostEff,eff,'Group');
b(1).FaceColor = 'b';
if(length(b) > 1)
    b(2).FaceColor = 'r';
end
set(handles.buttonDeployed,'Backgroundcolor','b');
set(handles.buttonMatlab,'Backgroundcolor','r');
ylabel(handles.axesHostEff,'(ms)');
title(handles.axesHostEff,'Average Time per Function Evaluation');
set(handles.axesHostEff,'XTick',round(get(handles.axesHostEff,'XTick')),'XTickLabel',allHosts,'XTickLabelRotation',45);
%set(handles.axesHostEff,'XTickLabel',allHosts);
%ylim([0 ym]);
%efficiency table
best = min(eff(:));
tstr = cell(0,3);
row = 0;
for i = 1:size(eff,1)    
    if(~isnan(eff(i,2)))
        %'online'
        row = row +1;
        tstr{row,1} = sprintf('%s',allHosts{i,1}); tstr{row,2} = num2str(eff(i,2),'%.2f'); tstr{row,3} = num2str(round(eff(i,2)/best*100),'%.0f');
    end
    %hosts may have both kinds of workers: no else branch here
    if(~isnan(eff(i,1)))
        %deployed
        row = row +1;
        tstr{row,1} = sprintf('%s (d)',allHosts{i,1}); tstr{row,2} = num2str(eff(i,1),'%.2f'); tstr{row,3} = num2str(round(eff(i,1)/best*100),'%.0f');
    end
end
set(handles.tableHostEff,'Data',tstr);

colormap(jet)
%fill info table
tstr = cell(5,2);
[h, m, s] = secs2hms(sum(time(:)));
d =  max(floor(h/24),0);
h = h-d*24;
iter = sum(data.Iterations(data.Iterations ~= 0));
feval = sum(data.FunctionEvaluations(data.FunctionEvaluations ~= 0));
px = numel(data.Iterations(data.Iterations ~= 0));
iter_px = iter/px;
feval_px = feval/px;
%avg_feval = feval/sum(time(:));
t_pixel = sum(time(:))/px;
%info tabe 1
tstr{1,1} = 'Number of fitted pixels'; tstr{1,2} = num2str(px); 
tstr{2,1} = 'total CPU time';  tstr{2,2} = sprintf('%dd %dh %dmin %ds',d,h,m,round(s));
[h, m, s] = secs2hms(feval*best/1000);
d =  max(floor(h/24),0);
h = h-d*24;
tstr{3,1} = 'est. run time on fastest CPU';  tstr{3,2} = sprintf('%dd %dh %dmin %ds',d,h,m,round(s));
if(isfield(data,'EffectiveTime'))
    [h, m, s] = secs2hms(sum(data.EffectiveTime));
    d =  max(floor(h/24),0);
    h = h-d*24;
    tstr{4,1} = 'effective run time';  tstr{4,2} = sprintf('%dd %dh %dmin %ds',d,h,m,round(s));
end
tstr{5,1} = 'Speedup'; tstr{5,2} = num2str(sum(time(:))/sum(data.EffectiveTime),'%.1f'); 
set(handles.tableInfo1,'Data',tstr);
%info table 2
tstr = cell(4,2);
tstr{1,1} = 'Number of iterations'; tstr{1,2} = num2str(iter); 
tstr{2,1} = 'average iterations / pixel'; tstr{2,2} = num2str(iter_px); 
tstr{3,1} = 'Number of function evaluations'; tstr{3,2} = num2str(feval); 
tstr{4,1} = 'average function evaluations / pixel'; tstr{4,2} = num2str(feval_px);
[~, m, s] = secs2hms(t_pixel);
ms = round((s-floor(s))*1000);
tstr{5,1} = 'average CPU time / pixel'; tstr{5,2} = sprintf('%dmin %ds %dms',m,floor(s),ms);
set(handles.tableInfo2,'Data',tstr);

lstr = cell(0,0);
if(any(any(work(:,1),2)))
    lstr(end+1) = {'deployed'};
end
if(any(any(work(:,2),2)))
    lstr(end+1) = {'Matlab'};
end
%legend(handles.axesHostEff,lstr,'location','NorthEastOutside');

% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
uiresume(handles.compInfoFigure);


% --- Executes on button press in buttonDeployed.
function buttonDeployed_Callback(hObject, eventdata, handles)
% hObject    handle to buttonDeployed (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in buttonMatlab.
function buttonMatlab_Callback(hObject, eventdata, handles)
% hObject    handle to buttonMatlab (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

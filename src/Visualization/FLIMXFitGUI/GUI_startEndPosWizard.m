function varargout = GUI_startEndPosWizard(varargin)
%=============================================================================================================
%
% @file     makePixelFit.m
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
% @brief    A GUI to (manually) set start and end position for a subjet in the time dimension
%
% GUI_STARTENDPOSWIZARD M-file for GUI_startEndPosWizard.fig
%      GUI_STARTENDPOSWIZARD, by itself, creates a new GUI_STARTENDPOSWIZARD or raises the existing
%      singleton*.
%
%      H = GUI_STARTENDPOSWIZARD returns the handle to a new GUI_STARTENDPOSWIZARD or the handle to
%      the existing singleton*.
%
%      GUI_STARTENDPOSWIZARD('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_STARTENDPOSWIZARD.M with the given input arguments.
%
%      GUI_STARTENDPOSWIZARD('Property','Value',...) creates a new GUI_STARTENDPOSWIZARD or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_startEndPosWizard_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_startEndPosWizard_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_startEndPosWizard

% Last Modified by GUIDE v2.5 14-Aug-2009 17:52:37

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @GUI_startEndPosWizard_OpeningFcn, ...
    'gui_OutputFcn',  @GUI_startEndPosWizard_OutputFcn, ...
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


% --- Executes just before GUI_startEndPosWizard is made visible.
function GUI_startEndPosWizard_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_startEndPosWizard (see VARARGIN)

sep.data = varargin{1};
sep.auto_start = varargin{2};
sep.auto_end = varargin{3};
sep.timeChannelWidth = varargin{4};
sep.RRWinSz = varargin{5};
sep.RRgrpSz = varargin{6};
sep.fix_start = varargin{7};
sep.fix_end = varargin{8};
sep.start_pos = fluoPixelModel.getStartPos(sep.data);

sep.ERidx = [];
%[mask sep.ERidx] = compReflectionMask(sep.data,sep.RRWinSz,sep.RRgrpSz);
sep.tableERrow = 1;
sep.buttonDown = 0;
switch sep.auto_start
    case 1 %auto
        sep.start_pos = fluoPixelModel.getStartPos(sep.data);
        set(handles.buttonSDec,'Enable','off');
        set(handles.buttonSInc,'Enable','off');
        set(handles.buttonSAuto,'Enable','off');
        set(handles.editStart,'Enable','off');
    case 0 %manual
        sep.start_pos = fluoPixelModel.getStartPos(sep.data);
    case -1 %fix
        sep.start_pos = varargin{7};
        set(handles.buttonSDec,'Enable','off');
        set(handles.buttonSInc,'Enable','off');
        set(handles.buttonSAuto,'Enable','off');
        set(handles.editStart,'Enable','off');
end
switch sep.auto_end
    case 1 %auto
        sep.end_pos = fluoPixelModel.getEndPos(sep.data);
        set(handles.buttonEDec,'Enable','off');
        set(handles.buttonEInc,'Enable','off');
        set(handles.buttonEAuto,'Enable','off');
        set(handles.editEnd,'Enable','off');
    case 0 %manual
        sep.end_pos = fluoPixelModel.getEndPos(sep.data);
    case -1 %fix
        sep.end_pos = varargin{8};
        set(handles.buttonEDec,'Enable','off');
        set(handles.buttonEInc,'Enable','off');
        set(handles.buttonEAuto,'Enable','off');
        set(handles.editEnd,'Enable','off');
end
set(handles.startEndPosWizardFigure,'Userdata',sep);
set(handles.editStart,'String',num2str(sep.start_pos));
set(handles.editEnd,'String',num2str(sep.end_pos));
updateGUI(handles);

% Choose default command line output for GUI_startEndPosWizard
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes GUI_startEndPosWizard wait for user response (see UIRESUME)
uiwait(handles.startEndPosWizardFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_startEndPosWizard_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    varargout{1} = 0;
    varargout{2} = 0;
    varargout{3} = 0;
else
    sep = get(handles.startEndPosWizardFigure,'userdata');
    varargout{1} = sep.start_pos;
    varargout{2} = sep.end_pos;    
    mask = true(size(sep.data));
    for i = 1:size(sep.ERidx,1)
        mask(sep.ERidx(i,1):sep.ERidx(i,2)) = false;
    end
    varargout{3} = mask;    
    delete(handles.startEndPosWizardFigure);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles)
%draw data and borders
sep = get(handles.startEndPosWizardFigure,'userdata');
semilogy(handles.axesData,sep.data,'.b','Linewidth',2);
xlim(handles.axesData,[0 length(sep.data)]);
start_pos = round(abs(str2double(get(handles.editStart,'String'))));
end_pos = round(abs(str2double(get(handles.editEnd,'String'))));
yl = ylim;
rectangle('Position',[start_pos,yl(1),end_pos-start_pos+1,yl(2)-yl(1)],'FaceColor',[0.8 0.8 0.8]);
hold on
for i = 1:size(sep.ERidx,1)
    if(all(sep.ERidx(i,:)))
        rectangle('Position',[sep.ERidx(i,1),yl(1),sep.ERidx(i,2)-sep.ERidx(i,1)+1,yl(2)-yl(1)],'FaceColor','r');
    end
end
semilogy(handles.axesData,sep.data,'.b','Linewidth',2);
% line('XData',[start_pos start_pos],'YData',[ylim],'Color',[0 0 0],'Linestyle','--','color',[0.2 0.2 0.2]);
% line('XData',[end_pos end_pos],'YData',[ylim],'Color',[0 0 0],'Linestyle','--','color',[0.2 0.2 0.2]);
ylabel('Photon-Frequency (counts)');

hold off
%fill talbe text
rows = size(sep.ERidx,1)+1;
tstr = cell(rows,2);
for i = 1:rows-1
    tstr{i,1} = sep.ERidx(i,1); 
    tstr{i,2} = sep.ERidx(i,2); 
end
set(handles.tableER,'Data',tstr);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in buttonSAuto.
function buttonSAuto_Callback(hObject, eventdata, handles)
%
sep = get(handles.startEndPosWizardFigure,'userdata');
sep.start_pos = fluoPixelModel.getStartPos(sep.data);
set(handles.editStart,'String',num2str(sep.start_pos));
set(handles.startEndPosWizardFigure,'userdata',sep);

% --- Executes on button press in buttonEAuto.
function buttonEAuto_Callback(hObject, eventdata, handles)
%
sep = get(handles.startEndPosWizardFigure,'userdata');
sep.end_pos = fluoPixelModel.getEndPos(sep.data);
set(handles.editEnd,'String',num2str(sep.end_pos));
set(handles.startEndPosWizardFigure,'userdata',sep);

% --- Executes on button press in buttonEDec.
function buttonEDec_Callback(hObject, eventdata, handles)
%
set(handles.editEnd,'String',num2str(round(abs(str2double(get(handles.editEnd,'String'))))-1));
editEnd_Callback(handles.editEnd,[],handles);

% --- Executes on button press in buttonEInc.
function buttonEInc_Callback(hObject, eventdata, handles)
%
set(handles.editEnd,'String',num2str(round(abs(str2double(get(handles.editEnd,'String'))))+1));
editEnd_Callback(handles.editEnd,[],handles);

% --- Executes on button press in buttonSDec.
function buttonSDec_Callback(hObject, eventdata, handles)
%
set(handles.editStart,'String',num2str(round(abs(str2double(get(handles.editStart,'String'))))-1));
editStart_Callback(handles.editStart,[],handles);

% --- Executes on button press in buttonSInc.
function buttonSInc_Callback(hObject, eventdata, handles)
%
set(handles.editStart,'String',num2str(round(abs(str2double(get(handles.editStart,'String'))))+1));
editStart_Callback(handles.editStart,[],handles);

% --- Executes on button press in buttonERAuto.
function buttonERAuto_Callback(hObject, eventdata, handles)
%
sep = get(handles.startEndPosWizardFigure,'userdata');
[mask sep.ERidx] = measurementFile.compReflectionMask(sep.data,sep.RRWinSz,sep.RRgrpSz);
set(handles.startEndPosWizardFigure,'userdata',sep);
updateGUI(handles);

% --- Executes on button press in buttonERremove.
function buttonERremove_Callback(hObject, eventdata, handles)
%
sep = get(handles.startEndPosWizardFigure,'userdata');
sep.ERidx(sep.tableERrow,:) = [];
set(handles.startEndPosWizardFigure,'userdata',sep);
updateGUI(handles);

% --- Executes on button press in buttonOK.
function buttonOK_Callback(hObject, eventdata, handles)
uiresume(handles.startEndPosWizardFigure);

% --- Executes on button press in buttonCancel.
function buttonCancel_Callback(hObject, eventdata, handles)
uiresume(handles.startEndPosWizardFigure);
delete(handles.startEndPosWizardFigure);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%radio buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%80
%mouse callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function mouseButtonDown_Callback(hObject, eventdata, handles)
%executes on click in window
sep = get(handles.startEndPosWizardFigure,'userdata');
cp = get(handles.axesData,'CurrentPoint');
cp = cp(logical([1 1 0; 0 0 0]));
cp=fix(cp+0.52);
yl = ylim(handles.axesData);
if(~(cp(1) >= 1 && cp(1) <= length(sep.data)) || ~(cp(2) >= yl(1) && cp(2) <= yl(2)))
    %pointer out of axes
    return;
end
cp(1)=fix(cp(1)+2.7-0.52);
cp(2)=fix(cp(2)-10-0.52);
sel = get(handles.startEndPosWizardFigure,'SelectionType');
if(strcmpi(sel,'normal'))
    %left click
    if(sep.auto_start)
        return
    end 
    set(handles.editStart,'String',max(min(round(abs(cp(1))),sep.end_pos-1),1));
elseif(strcmpi(sel,'alt'))
    %right click
    if(sep.auto_end)
        return
    end
    set(handles.editEnd,'String',min(max(round(abs(cp(1))),sep.start_pos+1),length(sep.data)));
elseif(strcmpi(sel,'Extend'))
    %click with both buttons 
    sep.ERidx(sep.tableERrow,1) = round(abs(cp(1)));
    sep.ERidx(sep.tableERrow,2) = round(abs(cp(1)));
end
sep.buttonDown = 1;
set(handles.startEndPosWizardFigure,'userdata',sep);
updateGUI(handles);

function mouseMotion_Callback(hObject, eventdata, handles)
%executes on mouse move in window
sep = get(handles.startEndPosWizardFigure,'userdata');
if(sep.auto_start && sep.auto_end)
    return
end
cp = get(handles.axesData,'CurrentPoint');
cp = cp(logical([1 1 0; 0 0 0]));
if(any(cp(:) < 0))
    set(handles.startEndPosWizardFigure,'Pointer','arrow');
    updateGUI(handles);
    return;
end
cp=fix(cp+0.52);
yl = ylim(handles.axesData);
if(~(cp(1) >= 1 && cp(1) <= length(sep.data)) || ~(cp(2) >= yl(1) && cp(2) <= yl(2)))
    %pointer out of axes
    set(handles.startEndPosWizardFigure,'Pointer','arrow');
    set(handles.editStart,'String',sep.start_pos);
    set(handles.editEnd,'String',sep.end_pos);
    updateGUI(handles); 
    return
end
set(handles.startEndPosWizardFigure,'Pointer','cross');
if(~sep.buttonDown) 
    return
end
cp(1)=fix(cp(1)+2.7-0.52);
sel = get(handles.startEndPosWizardFigure,'SelectionType');
if(strcmpi(sel,'normal'))
    %left click
    if(sep.auto_start)
        return
    end
    set(handles.editStart,'String',max(min(round(abs(cp(1))),sep.end_pos-1),1));
elseif(strcmpi(sel,'alt'))
    %right click
    if(sep.auto_end)
        return
    end
    set(handles.editEnd,'String',min(max(round(abs(cp(1))),sep.start_pos+1),length(sep.data)));
elseif(strcmpi(sel,'Extend'))
    %click with both buttons
    current = round(abs(cp(1)));
    if(current < sep.ERidx(sep.tableERrow,2))
        sep.ERidx(sep.tableERrow,2) = sep.ERidx(sep.tableERrow,1)+1;
    else
        sep.ERidx(sep.tableERrow,2) = current;
    end
    set(handles.startEndPosWizardFigure,'userdata',sep);
end
updateGUI(handles);

function mouseButtonUp_Callback(hObject, eventdata, handles)
%executes on click in window
cp = get(handles.axesData,'CurrentPoint');
cp = cp(logical([1 1 0; 0 0 0]));
if(any(cp(:) < 0))
    return;
end
sep = get(handles.startEndPosWizardFigure,'userdata');
sep.buttonDown = 0;

cp=fix(cp+0.52);
yl = ylim(handles.axesData);
if(~(cp(1) >= 1 && cp(1) <= length(sep.data)) || ~(cp(2) >= yl(1) && cp(2) <= yl(2)))
    %pointer out of axes
    return;
end
cp(1)=fix(cp(1)+2.7-0.52);
cp(2)=fix(cp(2)-10-0.52);
sel = get(handles.startEndPosWizardFigure,'SelectionType');
if(strcmpi(sel,'normal'))
    %left click
    if(sep.auto_start)
        return
    end
    set(handles.editStart,'String',max(min(round(abs(cp(1))),sep.end_pos-1),1));
    sep.start_pos = round(abs(cp(1)));
elseif(strcmpi(sel,'alt'))
     %right click
    if(sep.auto_end)
        return
    end    
    set(handles.editEnd,'String',min(max(round(abs(cp(1))),sep.start_pos+1),length(sep.data)));
    sep.end_pos = round(abs(cp(1)));
elseif(strcmpi(sel,'Extend'))
    %click with both buttons 
    current = round(abs(cp(1)));
    if(current < sep.ERidx(sep.tableERrow,2))
        sep.ERidx(sep.tableERrow,2) = sep.ERidx(sep.tableERrow,1)+1;
    else
        sep.ERidx(sep.tableERrow,2) = current;
    end
end
set(handles.startEndPosWizardFigure,'userdata',sep);
updateGUI(handles);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%table callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes when selected cell(s) is changed in tableER.
function tableER_CellSelectionCallback(hObject, eventdata, handles)
% hObject    handle to tableER (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) currently selecteds
% handles    structure with handles and user data (see GUIDATA)
sep = get(handles.startEndPosWizardFigure,'userdata');
if(~isempty(eventdata.Indices))
    sep.tableERrow = eventdata.Indices(1);
end
set(handles.startEndPosWizardFigure,'Userdata',sep);

% --- Executes when entered data in editable cell(s) in tableER.
function tableER_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to tableER (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)
sep = get(handles.startEndPosWizardFigure,'userdata');
if(eventdata.Indices(1) > size(sep.ERidx,1))
    sep.ERidx(eventdata.Indices(1),:) = zeros(1,2);
end
sep.ERidx(eventdata.Indices(1),eventdata.Indices(2)) = double(eventdata.NewData);
switch eventdata.Indices(2)
    case 1
        sep.ERidx(eventdata.Indices(1),1) = max(1,min(length(sep.data)-1,sep.ERidx(eventdata.Indices(1),1)));
    case 2
        sep.ERidx(eventdata.Indices(1),2) = min(length(sep.data),sep.ERidx(eventdata.Indices(1),2));
end
set(handles.startEndPosWizardFigure,'Userdata',sep);
updateGUI(handles);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editStart_Callback(hObject, eventdata, handles)
% 
sep = get(handles.startEndPosWizardFigure,'userdata');
sep.start_pos = max(min(round(abs(str2double(get(hObject,'String')))),sep.end_pos-1),1);
set(hObject,'String',num2str(sep.start_pos));
set(handles.startEndPosWizardFigure,'Userdata',sep);
updateGUI(handles);

function editEnd_Callback(hObject, eventdata, handles)
%
sep = get(handles.startEndPosWizardFigure,'userdata');
sep.end_pos = min(max(round(abs(str2double(get(hObject,'String')))),sep.start_pos+1),length(sep.data));
set(hObject,'String',num2str(sep.end_pos));
set(handles.startEndPosWizardFigure,'Userdata',sep);
updateGUI(handles);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function popupIRF_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editBin_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupChannel_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editEnd_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

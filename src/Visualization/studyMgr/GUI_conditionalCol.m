function varargout = GUI_conditionalCol(varargin)
%=============================================================================================================
%
% @file     GUI_conditionalCol.m
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
% @brief    A GUI to configure columns in study manager's subject info
%
% GUI_CONDITIONALCOL M-file for GUI_conditionalCol.fig

% Last Modified by GUIDE v2.5 20-Oct-2016 15:14:58

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_conditionalCol_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_conditionalCol_OutputFcn, ...
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


% --- Executes just before GUI_conditionalCol is made visible.
function GUI_conditionalCol_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_conditionalCol (see VARARGIN)
movegui(handles.FLIMXStudyMgrColumnCreationFigure,'center');
opt = varargin{1};
%init GUI:
if(isempty(opt.name))
    %new (conditional) column
    i=1;
    while(true)    
        name = sprintf('Column0%d',i);
        check = intersect(name,opt.list);
        if(~isempty(check))
            i = i+1;
        else
            break
        end
    end
    opt.name = name;
else
    %edit exisiting column, adapt GUI
    set(handles.lblHeading,'String','Edit Column');
    set(handles.FLIMXStudyMgrColumnCreationFigure,'Name','Edit Column');
    if(~opt.cond)
        %edit regular column
        set(handles.rbNormalCol,'Value',1);
    else
        %edit conditional column
        set(handles.rbConditionCol,'Value',1);
    end        
end
if(length(opt.list) == 1)
    %only one column in table
    set(handles.popupColB,'Enable','Off');
    set(handles.popupLogOp,'Enable','Off');
    opt.colB = 1;
end
set(handles.FLIMXStudyMgrColumnCreationFigure,'userdata',opt);
set(handles.editColName,'String',opt.name);
if(isempty(opt.list))
    set(handles.popupColA,'String','-');
    set(handles.popupColB,'String','-');
    set(handles.rbConditionCol,'Enable','Off');
else
    set(handles.popupColA,'String',opt.list);
    set(handles.popupColB,'String',opt.list);
end
set(handles.popupLogOp,'String',opt.ops(1:6),'Value',1);
set(handles.popupRelA,'String',opt.ops(7:end),'Value',5);
set(handles.popupRelB,'String',opt.ops(7:end),'Value',5);

updateGUI(handles);

% Choose default command line output for GUI_conditionalCol
%handles.output = hObject;

% Update handles structure
%guidata(hObject, handles);

% UIWAIT makes GUI_conditionalCol wait for user response (see UIRESUME)
uiwait(handles.FLIMXStudyMgrColumnCreationFigure);

% --- Outputs from this function are returned to the command line.
function varargout = GUI_conditionalCol_OutputFcn(hObject, eventdata, handles) 
if isempty(handles)
    handles.output='';
    varargout{1} = '';
else
    out = get(handles.FLIMXStudyMgrColumnCreationFigure,'userdata');          
    
    varargout{1} = out;
    delete(handles.FLIMXStudyMgrColumnCreationFigure);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles)
%update GUI
%set values
opt = get(handles.FLIMXStudyMgrColumnCreationFigure,'userdata');
set(handles.editColName,'String',opt.name);
%enable/disable GUI controls
if(opt.cond)
    %conditinal column - set related GUI controls
    set(handles.editValA,'Enable','On');
    set(handles.popupColA,'Enable','On');
    set(handles.popupRelA,'Enable','On');
    if(length(opt.list) > 1)
        set(handles.popupLogOp,'Enable','On');
    end
    set(handles.editValA,'String',num2str(opt.valA));
    set(handles.popupColA,'Value',opt.colA);
    set(handles.popupRelA,'Value',opt.relA);    
    set(handles.popupLogOp,'Value',opt.logOp);    
    
    if(opt.logOp == 1)
        %no logical operation selected
        set(handles.popupColB,'Enable','Off');
        set(handles.popupRelB,'Enable','Off');
        set(handles.editValB,'Enable','Off');
    else
        %logical operation selected --> create combination        
        set(handles.popupColB,'Enable','On');
        set(handles.popupRelB,'Enable','On');
        set(handles.editValB,'Enable','On');
        set(handles.editValB,'String',num2str(opt.valB));
        set(handles.popupColB,'Value',opt.colB);
        set(handles.popupRelB,'Value',opt.relB);
    end
else
    %no conditional column - disable all corresponding GUI controls
    set(handles.editValA,'Enable','Off');
    set(handles.editValB,'Enable','Off');
    set(handles.popupColA,'Enable','Off');
    set(handles.popupColB,'Enable','Off');
    set(handles.popupRelA,'Enable','Off');
    set(handles.popupRelB,'Enable','Off');
    set(handles.popupLogOp,'Enable','Off');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Push Buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function btExecute_Callback(hObject, eventdata, handles)
uiresume(handles.FLIMXStudyMgrColumnCreationFigure);

function btCancel_Callback(hObject, eventdata, handles)
% Cancel
uiresume(handles.FLIMXStudyMgrColumnCreationFigure);
delete(handles.FLIMXStudyMgrColumnCreationFigure);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Popups
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function popupLogOp_Callback(hObject, eventdata, handles)
% update selected logical / relational operator
opt = get(handles.FLIMXStudyMgrColumnCreationFigure,'userdata');
opt.logOp = get(hObject,'Value');
set(handles.FLIMXStudyMgrColumnCreationFigure,'userdata',opt);
updateGUI(handles);

function popupColA_Callback(hObject, eventdata, handles)
%selected Column A
opt = get(handles.FLIMXStudyMgrColumnCreationFigure,'userdata');
colA = get(hObject,'Value');

if(colA == opt.colB)
    %change column b due to not to have the same column twice
    opt.colB = opt.colA;
end

opt.colA = colA;
set(handles.FLIMXStudyMgrColumnCreationFigure,'userdata',opt);
updateGUI(handles);

function popupColB_Callback(hObject, eventdata, handles)
%selected Column B
opt = get(handles.FLIMXStudyMgrColumnCreationFigure,'userdata');
colB = get(hObject,'Value');

% if(colB == opt.colA)
%     %error message
%     errordlg('You have to select two different Colums! Please select another Column!',...
%                     'Error selecting Columns');
% else
    opt.colB = colB;
    set(handles.FLIMXStudyMgrColumnCreationFigure,'userdata',opt);
% end
updateGUI(handles);

function popupRelA_Callback(hObject, eventdata, handles)
% Popup for relational operator of column A
opt = get(handles.FLIMXStudyMgrColumnCreationFigure,'userdata');
opt.relA = get(hObject,'Value');
set(handles.FLIMXStudyMgrColumnCreationFigure,'userdata',opt);

function popupRelB_Callback(hObject, eventdata, handles)
% Popup for relational operator of column B
opt = get(handles.FLIMXStudyMgrColumnCreationFigure,'userdata');
opt.relB = get(hObject,'Value');
set(handles.FLIMXStudyMgrColumnCreationFigure,'userdata',opt);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Edit boxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editColName_Callback(hObject, eventdata, handles)
%get unique column name
name = get(hObject,'String');
opt = get(handles.FLIMXStudyMgrColumnCreationFigure,'userdata');
if(~isempty(name))    
    check = intersect(name,opt.list);
    if(~isempty(check))
        %name already exists
        errordlg('This is not a unique column name! Please insert another name!',...
                    'Error selecting column name');
    else
        %save new name
        opt.name = name;
        set(handles.FLIMXStudyMgrColumnCreationFigure,'userdata',opt);
    end
end
set(hObject,'String',opt.name);

function editValA_Callback(hObject, eventdata, handles)
% value for relational condition of column A
val = get(hObject,'String');
opt = get(handles.FLIMXStudyMgrColumnCreationFigure,'userdata');
if(isempty(val))
    %input is not valid
    errordlg('This is not a valid value! Please insert another number or string!',...
        'Error entering value');
else
    %save new value
    opt.valA = val;
    set(handles.FLIMXStudyMgrColumnCreationFigure,'userdata',opt);
end
set(hObject,'String',opt.valA);

function editValB_Callback(hObject, eventdata, handles)
% value for relational condition of column B
val = get(hObject,'String');
opt = get(handles.FLIMXStudyMgrColumnCreationFigure,'userdata');
if(isempty(val))
    %input is not valid
    errordlg('This is not a valid value! Please insert another number or string!',...
        'Error entering value');
else
    %save new value
    opt.valB = val;
    set(handles.FLIMXStudyMgrColumnCreationFigure,'userdata',opt);
end
set(hObject,'String',opt.valB);    


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Group Buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes when selected object is changed in panelColType.
function panelColType_SelectionChangeFcn(hObject, eventdata, handles)
opt = get(handles.FLIMXStudyMgrColumnCreationFigure,'userdata');
if(length(opt.list) < 2)
    %at least one column necessary
    errordlg('There must be at least one existing Colum in order to create a Condition!',...
        'Error creating Conditional Column');
    return
end
switch get(eventdata.NewValue,'Tag')    
    case 'rbNormalCol'        
        opt.cond = false;        
    case 'rbConditionCol'        
        opt.cond = true;        
end
set(handles.FLIMXStudyMgrColumnCreationFigure,'userdata',opt);
updateGUI(handles);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function popupColB_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end    
function popupRelA_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end   
function popupRelB_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function editColName_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function editValB_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function editValA_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function popupLogOp_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function popupColA_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

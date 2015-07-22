function varargout = GUI_channelImport(varargin)
%=============================================================================================================
%
% @file     GUI_channelImport.m
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
% @brief    A GUI to set to select spectral channels on SPCImage result import to FDTree
%
% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_channelImport_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_channelImport_OutputFcn, ...
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


% --- Executes just before GUI_channelImport is made visible.
function GUI_channelImport_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_channelImport (see VARARGIN)

%initialize GUI
opt = varargin{1};
%init GUI
if(strcmp(opt.parent,'FLIMXVisGUI'))
    %import via FLIMXVisGUI GUI
    set(handles.lblHeading,'String',sprintf('Import Fit Results to FLIMXVisGUI:'));
    set(handles.rbAdd,'Enable','on');
    set(handles.lblChannel,'Enable','on');
    set(handles.popChannel,'Enable','off');
    set(handles.buttonSkip,'Enable','off');
    set(handles.popChannel,'Visible','off');
    set(handles.editChannel,'Enable','on','Visible','on','Value',opt.ch);
    set(handles.panelChSelect,'Title','New Channel Number');
    set(handles.lblChannel,'String','Enter new channel number:');
    
    opt.newStudy = false; 
    [~, idx] = ismember(opt.studyName,opt.studyList);
    set(handles.popupStudySel,'String',opt.studyList);
    set(handles.popupStudySel,'Value',idx);
    set(handles.editStudyName,'String',opt.studyName);
    set(handles.editDSName,'String',opt.subName);
else
    %import via studyMgr for specific subject    
    set(handles.editStudyName,'String',opt.studyName);
    set(handles.popupStudySel,'Visible','off');
    set(handles.editDSName,'String',opt.subName);
    set(handles.lblHeading,'String',sprintf('Import Fit Results for Subject ''%s'':',opt.subName));
    set(handles.rbExistingStudy,'Enable','off');    
    set(handles.rbNewStudy,'Enable','off');
    set(handles.lblStudy,'Enable','off');
    set(handles.editStudyName,'Enable','off');    
end
% if(isempty(opt.chList))
%     %opt.ch = 1;
%     opt.mode = 1;
%     set(handles.rbOverwrite,'Enable','off');
%     set(handles.rbClear,'Enable','off');
% end

set(handles.channelImportFigure,'userdata',opt);
updateGUI(handles);  

% UIWAIT makes GUI_channelImport wait for user response (see UIRESUME)
uiwait(handles.channelImportFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_channelImport_OutputFcn(hObject, eventdata, handles) 

if isempty(handles)
    handles.output='';
    varargout{1} = '';
else
    out = get(handles.channelImportFigure,'userdata');         
    varargout{1} = out;
    delete(handles.channelImportFigure);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function flag = checkSubjectID(handles)
%check if channel ch of subject is already in tree
opt = get(handles.channelImportFigure,'userdata');
if(opt.mode > 1)
    flag = false;
    return
end
flag = opt.fdt.isMember(opt.studyName,opt.subName,opt.ch,[]);

function updateGUI(handles)
%update GUI controls to current values
opt = get(handles.channelImportFigure,'userdata');

if(checkSubjectID(handles) && ~isempty(opt.chList))
    %we have this subject & channel already
    set(handles.rbOverwrite,'Enable','on'); %overwrite channel
    set(handles.rbClear,'Enable','on'); %clear all old data
else
    %we don't have this subject & channel yet
    set(handles.rbOverwrite,'Enable','off'); %overwrite channel
    set(handles.rbClear,'Enable','off'); %clear all old data
end

if(strcmp(opt.parent,'FLIMXVisGUI'))
    %import via FLIMXVisGUI
    if(opt.mode == 0)
        %ASCII import --> request dataset name
        set(handles.editDSName,'Enable','off');
        set(handles.lblDSName,'Enable','off');
    else
        set(handles.editDSName,'Enable','on');
        set(handles.lblDSName,'Enable','on');
    end
    
    if(opt.newStudy == false)
        set(handles.editStudyName,'Visible','off');
        set(handles.popupStudySel,'Visible','on');
        set(handles.lblStudy,'String','Select Study:');
    else
        set(handles.popupStudySel,'Visible','off');
        set(handles.editStudyName,'Visible','on','String',opt.studyName);
        set(handles.lblStudy,'String','Enter Study Name:');
        set(handles.channelImportFigure,'userdata',opt);
    end
    %update edit box
    set(handles.editChannel,'String',opt.ch); 
else    
    %update popup
    if(~isempty(opt.chList))
        set(handles.popChannel,'String',opt.chList);
    else
        set(handles.popChannel,'String',{0});
        set(handles.popChannel,'Enable','off');
    end    
    %update edit box
    set(handles.editChannel,'String',opt.ch);    
    %update panel
    switch opt.mode
        case {1,3}
            set(handles.popChannel,'Visible','off');
            set(handles.editChannel,'Visible','on');
            set(handles.panelChSelect,'Title','New Channel Number');
            set(handles.lblChannel,'String','Enter new channel number:');
        case 2
            set(handles.popChannel,'Visible','on');
            set(handles.editChannel,'Visible','off');
            set(handles.panelChSelect,'Title','Select Channel');
            set(handles.lblChannel,'String','Select channel to overwrite:');
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Popups
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function popChannel_Callback(hObject, eventdata, handles)

opt = get(handles.channelImportFigure,'userdata');
opt.ch = get(handles.popChannel,'Value');
set(handles.channelImportFigure,'userdata',opt);
updateGUI(handles);

function popupStudySel_Callback(hObject, eventdata, handles)

opt = get(handles.channelImportFigure,'userdata');
str = get(hObject,'String');
opt.studyName = str{get(hObject,'Value')};
set(handles.channelImportFigure,'userdata',opt);
updateGUI(handles);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function buttonExecute_Callback(hObject, eventdata, handles)
% Give channel list to StudyMgr
opt = get(handles.channelImportFigure,'userdata');
if(checkSubjectID(handles))
    msgbox(sprintf('Channel ''%d'' of subject ''%s'' in study ''%s'' already exists. Please re-choose channel, subject name, study or channel options.',opt.ch,opt.subName,opt.studyName), 'Channel already exists', 'error');
    return
end
uiresume(handles.channelImportFigure);

function buttonSkip_Callback(hObject, eventdata, handles)
opt = get(handles.channelImportFigure,'userdata');
opt.mode = 0;
set(handles.channelImportFigure,'userdata',opt);
uiresume(handles.channelImportFigure);
% Skip current subject --> don't import fit result

function buttonCancel_Callback(hObject, eventdata, handles)
% Cancel
uiresume(handles.channelImportFigure);
delete(handles.channelImportFigure);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Group Buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function panelChOptions_SelectionChangeFcn(hObject, eventdata, handles)
switch get(eventdata.NewValue,'Tag')
    case 'rbAdd'
        opt = get(handles.channelImportFigure,'userdata');
        %opt.ch = str2double(get(handles.editChannel,'String'));
        if(isempty(opt.chList))
            opt.ch = 1;
        end
        opt.mode = 1;
        set(handles.channelImportFigure,'userdata',opt);
    case 'rbOverwrite'
        opt = get(handles.channelImportFigure,'userdata');
        opt.ch = get(handles.popChannel,'Value');
        opt.mode = 2;
        set(handles.channelImportFigure,'userdata',opt);
    case 'rbClear'
        opt = get(handles.channelImportFigure,'userdata');
        %opt.ch = str2double(get(handles.editChannel,'String'));
        opt.ch = 1;
        opt.mode = 3;
        set(handles.channelImportFigure,'userdata',opt);
end
updateGUI(handles);

function panelStudyOptions_SelectionChangeFcn(hObject, eventdata, handles)
opt = get(handles.channelImportFigure,'userdata');
switch get(eventdata.NewValue,'Tag')
    case 'rbExistingStudy'
        opt.newStudy = false;
    case 'rbNewStudy'
        opt.newStudy = true;
        i=1;
        %create unique study name
        conflict = 1;
        while(~isempty(conflict))
            studyName = sprintf('study%02d',i);
            conflict = intersect(studyName,opt.studyList);
            i = i+1;
        end
        opt.studyName = studyName;
end
set(handles.channelImportFigure,'userdata',opt);
updateGUI(handles);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Edit boxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editChannel_Callback(hObject, eventdata, handles)
% get channel number for new channel
ch = str2double(get(hObject,'String'));
opt = get(handles.channelImportFigure,'userdata');    

if(isempty(ch))    
    msg = errordlg('This is not a valid channel identification! Please choose another name.',...
        'Error adding channel');
else
    if(~isempty(opt.chList))
        check = intersect(ch,opt.chList{:});
    else
        check = [];
    end
    if(~isempty(check) && opt.mode == 1)
        choice = questdlg(sprintf('This channel identification is already assigned! Overwrite?'),...
            'Error adding channel','Overwrite','Cancel','Cancel');
        switch choice
            case 'Overwrite'
                %
                opt.ch = ch;
                set(handles.channelImportFigure,'userdata',opt);
            case 'Cancel'
                set(handles.editChannel,'String',opt.ch);
        end
    else
        %set new value
        opt.ch = ch;
        set(handles.channelImportFigure,'userdata',opt);
    end
end
updateGUI(handles);
 
function editStudyName_Callback(hObject, eventdata, handles)
%get new study name
studyName = get(hObject,'String');
if(isempty(studyName))
    set(hObject,'String','study01');
else
    opt = get(handles.channelImportFigure,'userdata');
    check = intersect(studyName,opt.studyList);
    if(~isempty(check))
        errordlg('This study name is already assigned! Please choose another one.',...
                    'Error adding new Study');
        set(hObject,'String',opt.studyName);
    else
        opt.studyName = studyName;
        set(handles.channelImportFigure,'userdata',opt);
    end
end

function editDSName_Callback(hObject, eventdata, handles)
%get new dataset name
subName = get(hObject,'String');
opt = get(handles.channelImportFigure,'userdata');
if(isempty(subName))
    set(hObject,'String',opt.subName);
else    
    %remove any '\' a might have entered    
    idx = strfind(subName,'\');
    if(~isempty(idx))
        subName(idx) = '';
    end
    opt.subName = subName;
    set(handles.channelImportFigure,'userdata',opt);
end
updateGUI(handles);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editDSName_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function editStudyName_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function editChannel_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function popChannel_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function popupStudySel_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

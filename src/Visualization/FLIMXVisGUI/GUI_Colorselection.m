function varargout = GUI_Colorselection(varargin)
%=============================================================================================================
%
% @file     GUI_Colorselection.m
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
% @brief    A Graphical User Interface to select a color
%
%input: 
% varargin - proposed color
%output: selected color

% Last Modified by GUIDE v2.5 09-Mar-2015 17:50:11

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_Colorselection_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_Colorselection_OutputFcn, ...
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


% --- Executes just before GUI_Colorselection is made visible.
function GUI_Colorselection_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_Colorselection (see VARARGIN)

% Choose default command line output for GUI_Colorselection
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);
movegui(handles.colorSelectionFigure,'center');

set(gcf,'Name','Color Selection');
map1 = hsv(256);
map2 = gray(256);
%select colorbar
if(isempty(varargin))
    color = map1(round(rand(1,1)*255+1),:);
elseif(length(varargin) == 1)
    color = varargin{1};
    if(length(color) == 1)
        %we got an index of a jet colormap
        color = map1(max(1,min(256,round(color))),:);
    elseif(isempty(color) || length(color) == 2 || length(color) > 3)
        %something is wrong with the input
        color = map1(round(rand(1,1)*255+1),:);
    end
else
    error('Too many input arguments');
end
%set(handles.ctext,'BackgroundColor',color);
set(handles.colorSelectionFigure,'userdata',color);
    
temp = zeros(1,256,3);
temp(1,:,:) = colormap(map2);
imagesc(temp,'HitTest','off','Parent',handles.c2axes);
set(handles.c2axes,'XTickLabel','');
set(handles.c2axes,'XTick',[]);
set(handles.c2axes,'YTickLabel','');
set(handles.c2axes,'YTick',[]);
set(handles.c2axes,'ButtonDownFcn',{@cb2_click,handles});
set(handles.c2axes,'XLim',[1 256]);

temp = zeros(1,256,3);
temp(1,:,:) = colormap(map1);
imagesc(temp,'HitTest','off','Parent',handles.c1axes);
set(handles.c1axes,'XTickLabel','');
set(handles.c1axes,'XTick',[]);
set(handles.c1axes,'YTickLabel','');
set(handles.c1axes,'YTick',[]);
set(handles.c1axes,'ButtonDownFcn',{@cb1_click,handles});
set(handles.c1axes,'XLim',[1 256]);

updateGUI(handles,color);

% UIWAIT makes GUI_Colorselection wait for user response (see UIRESUME)
uiwait(handles.colorSelectionFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_Colorselection_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=0;
    varargout{1} = 0;
else
    varargout{1} = get(handles.colorSelectionFigure,'userdata');
    delete(handles.colorSelectionFigure);
end

function updateGUI(handles,data)
%draw GUI
set(handles.editR,'String',round(data(1)*255));
set(handles.editG,'String',round(data(2)*255));
set(handles.editB,'String',round(data(3)*255));
set(handles.ctext,'BackgroundColor',data);

% --- Executes on button press in ok_button.
function ok_button_Callback(hObject, eventdata, handles)
uiresume(handles.colorSelectionFigure);


function cb1_click(hObject, eventdata, handles)
current = get(hObject,'CurrentPoint');
map1 = hsv(256);
set(handles.colorSelectionFigure,'userdata',map1(max(1,min(256,round(current(1,1)))),:));
updateGUI(handles,get(handles.colorSelectionFigure,'userdata'));
%set(handles.ctext,'BackgroundColor',map1(max(1,min(256,round(current(1,1)))),:));


function cb2_click(hObject, eventdata, handles)
current = get(hObject,'CurrentPoint');
map2 = gray(256);
set(handles.colorSelectionFigure,'userdata',map2(max(1,min(256,round(current(1,1)))),:));
%set(handles.ctext,'BackgroundColor',map2(max(1,min(256,round(current(1,1)))),:));
updateGUI(handles,get(handles.colorSelectionFigure,'userdata'));


% --- Executes on button press in cancel_button.
function cancel_button_Callback(hObject, eventdata, handles)
set(handles.colorSelectionFigure,'userdata',[]);
uiresume(handles.colorSelectionFigure);
delete(handles.colorSelectionFigure);


function editR_Callback(hObject, eventdata, handles)
r = max(0,min(255,round(abs(str2double(get(handles.editR,'String'))))))/255;
g = max(0,min(255,round(abs(str2double(get(handles.editG,'String'))))))/255;
b = max(0,min(255,round(abs(str2double(get(handles.editB,'String'))))))/255;
set(handles.colorSelectionFigure,'userdata',[r g b]);
updateGUI(handles,get(handles.colorSelectionFigure,'userdata'));


function editG_Callback(hObject, eventdata, handles)
r = max(0,min(255,round(abs(str2double(get(handles.editR,'String'))))))/255;
g = max(0,min(255,round(abs(str2double(get(handles.editG,'String'))))))/255;
b = max(0,min(255,round(abs(str2double(get(handles.editB,'String'))))))/255;
set(handles.colorSelectionFigure,'userdata',[r g b]);
updateGUI(handles,get(handles.colorSelectionFigure,'userdata'));


function editB_Callback(hObject, eventdata, handles)
r = max(0,min(255,round(abs(str2double(get(handles.editR,'String'))))))/255;
g = max(0,min(255,round(abs(str2double(get(handles.editG,'String'))))))/255;
b = max(0,min(255,round(abs(str2double(get(handles.editB,'String'))))))/255;
set(handles.colorSelectionFigure,'userdata',[r g b]);
updateGUI(handles,get(handles.colorSelectionFigure,'userdata'));


% --- Executes during object creation, after setting all properties.
function editR_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editG_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editB_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

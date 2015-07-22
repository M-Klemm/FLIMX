function varargout = GUI_Statistics_Options(varargin)
%=============================================================================================================
%
% @file     GUI_Statistics_Options.m
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
% @brief    A GUI to set statistics options (histogram parameters) in FLIMXVis
%
%input: 
% vargin - structure with preferences and defaults
%output: same as input, but altered according to user input

% Last Modified by GUIDE v2.5 30-Jul-2011 16:24:10

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_Statistics_Options_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_Statistics_Options_OutputFcn, ...
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

% --- Executes just before GUI_Rosediagram_options is made visible.
function GUI_Statistics_Options_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_Rosediagram_options (see VARARGIN)



rdh = varargin{1};
%setup objects
parent.visHandles = handles;

types = {'amp','ampPer','tau','q'};
for i = 1:length(types) %loop of types
    for j = 1:3
        oStr = sprintf('%s%d',types{i},j);
        rdh.obj.(oStr) = BoundsCtrl(parent,oStr);
        rdh.obj.(oStr).setUIHandles();
        rdh.obj.(oStr).setBounds([rdh.prefs.(sprintf('%s%d_lb',types{i},j)) rdh.prefs.(sprintf('%s%d_ub',types{i},j))]);
        rdh.obj.(oStr).setQuantization(rdh.prefs.(sprintf('%s%d_classwidth',types{i},j)));
        rdh.obj.(oStr).setStatus(rdh.prefs.(sprintf('%s%d_lim',types{i},j)));
    end
    % n
    oStr = sprintf('%sN',types{i});
    rdh.obj.(oStr) = BoundsCtrl(parent,oStr);
    rdh.obj.(oStr).setUIHandles();
    rdh.obj.(oStr).setBounds([rdh.prefs.(sprintf('%sN_lb',types{i})) rdh.prefs.(sprintf('%sN_ub',types{i}))]);
    rdh.obj.(oStr).setQuantization(rdh.prefs.(sprintf('%sN_classwidth',types{i})));
    rdh.obj.(oStr).setStatus(rdh.prefs.(sprintf('%sN_lim',types{i})));
    
end
rdh.obj.tauMean = BoundsCtrl(parent,'tauMean');
rdh.obj.tauMean.setUIHandles();
rdh.obj.tauMean.setBounds([rdh.prefs.tauMean_lb rdh.prefs.tauMean_ub]);
rdh.obj.tauMean.setQuantization(rdh.prefs.tauMean_classwidth);
rdh.obj.tauMean.setStatus(rdh.prefs.tauMean_lim);

rdh.obj.c = BoundsCtrl(parent,'c');
rdh.obj.c.setUIHandles();
rdh.obj.c.setBounds([rdh.prefs.c_lb rdh.prefs.c_ub]);
rdh.obj.c.setQuantization(rdh.prefs.c_classwidth);
rdh.obj.c.setStatus(rdh.prefs.c_lim);

rdh.obj.o = BoundsCtrl(parent,'o');
rdh.obj.o.setUIHandles();
rdh.obj.o.setBounds([rdh.prefs.o_lb rdh.prefs.o_ub]);
rdh.obj.o.setQuantization(rdh.prefs.o_classwidth);
rdh.obj.o.setStatus(rdh.prefs.o_lim);

%read current settings and draw them
updateGUI(handles, rdh.prefs);  
set(handles.StatisticsOptionsFigure,'userdata',rdh);


% Choose default command line output for GUI_Rosediagram_options
%handles.output = hObject;

% Update handles structure
%guidata(hObject, handles);

% UIWAIT makes GUI_Rosediagram_options wait for user response (see UIRESUME)
uiwait(handles.StatisticsOptionsFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_Statistics_Options_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=0;
    varargout{1} = 0;
else
    out = get(handles.StatisticsOptionsFigure,'userdata'); 
    varargout{1} = out;
    delete(handles.StatisticsOptionsFigure);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles,data)
types = {'amp','ampPer','tau','q'};
typesB = {'Amp','AmpPer','Tau','Q'};
for i = 1:length(types) %loop of types
    for j = 1:3 
        set(handles.(sprintf('edit%s%d',typesB{i},j)),'String',num2str(data.(sprintf('%s%d_classwidth',types{i},j))));
    end
    % n
    set(handles.(sprintf('edit%sN',typesB{i})),'String',num2str(data.(sprintf('%sN_classwidth',types{i}))));
    
end
set(handles.editTauMean,'String',num2str(data.tauMean_classwidth));
set(handles.editCluster,'String',num2str(data.c_classwidth));
set(handles.editOther,'String',num2str(data.o_classwidth));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%radio buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%checkboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editAmp1_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.amp1_classwidth = abs(str2double(get(hObject,'String')));
rdh.a_lim_obj.factor = rdh.prefs.amp1_classwidth;
rdh.a_lim_obj.offset = 0.5*rdh.prefs.amp1_classwidth;
rdh.obj.amp1.setQuantization(rdh.prefs.amp1_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editAmp2_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.amp2_classwidth = abs(str2double(get(hObject,'String')));
rdh.a_lim_obj.factor = rdh.prefs.amp2_classwidth;
rdh.a_lim_obj.offset = 0.5*rdh.prefs.amp2_classwidth;
rdh.obj.amp2.setQuantization(rdh.prefs.amp2_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editAmp3_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.amp3_classwidth = abs(str2double(get(hObject,'String')));
rdh.a_lim_obj.factor = rdh.prefs.amp3_classwidth;
rdh.a_lim_obj.offset = 0.5*rdh.prefs.amp3_classwidth;
rdh.obj.amp3.setQuantization(rdh.prefs.amp3_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editAmpN_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.ampN_classwidth = abs(str2double(get(hObject,'String')));
rdh.a_lim_obj.factor = rdh.prefs.ampN_classwidth;
rdh.a_lim_obj.offset = 0.5*rdh.prefs.ampN_classwidth;
rdh.obj.ampN.setQuantization(rdh.prefs.ampN_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editAmpPer1_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.ampPer1_classwidth = abs(str2double(get(hObject,'String')));
rdh.p_lim_obj.factor = rdh.prefs.ampPer1_classwidth;
rdh.p_lim_obj.offset = 0.5*rdh.prefs.ampPer1_classwidth;
rdh.obj.ampPer1.setQuantization(rdh.prefs.ampPer1_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editAmpPer2_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.ampPer2_classwidth = abs(str2double(get(hObject,'String')));
rdh.p_lim_obj.factor = rdh.prefs.ampPer2_classwidth;
rdh.p_lim_obj.offset = 0.5*rdh.prefs.ampPer2_classwidth;
rdh.obj.ampPer2.setQuantization(rdh.prefs.ampPer2_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editAmpPer3_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.ampPer3_classwidth = abs(str2double(get(hObject,'String')));
rdh.p_lim_obj.factor = rdh.prefs.ampPer3_classwidth;
rdh.p_lim_obj.offset = 0.5*rdh.prefs.ampPer3_classwidth;
rdh.obj.ampPer3.setQuantization(rdh.prefs.ampPer3_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editAmpPerN_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.ampPerN_classwidth = abs(str2double(get(hObject,'String')));
rdh.p_lim_obj.factor = rdh.prefs.ampPerN_classwidth;
rdh.p_lim_obj.offset = 0.5*rdh.prefs.ampPerN_classwidth;
rdh.obj.ampPerN.setQuantization(rdh.prefs.ampPerN_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editTau1_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.tau1_classwidth = abs(str2double(get(hObject,'String')));
rdh.t_lim_obj.factor = rdh.prefs.tau1_classwidth;
rdh.t_lim_obj.offset = 0.5*rdh.prefs.tau1_classwidth;
rdh.obj.tau1.setQuantization(rdh.prefs.tau1_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editTau2_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.tau2_classwidth = abs(str2double(get(hObject,'String')));
rdh.t_lim_obj.factor = rdh.prefs.tau2_classwidth;
rdh.t_lim_obj.offset = 0.5*rdh.prefs.tau2_classwidth;
rdh.obj.tau2.setQuantization(rdh.prefs.tau2_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editTau3_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.tau3_classwidth = abs(str2double(get(hObject,'String')));
rdh.t_lim_obj.factor = rdh.prefs.tau3_classwidth;
rdh.t_lim_obj.offset = 0.5*rdh.prefs.tau3_classwidth;
rdh.obj.tau3.setQuantization(rdh.prefs.tau3_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editTauN_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.tauN_classwidth = abs(str2double(get(hObject,'String')));
rdh.t_lim_obj.factor = rdh.prefs.tauN_classwidth;
rdh.t_lim_obj.offset = 0.5*rdh.prefs.tauN_classwidth;
rdh.obj.tauN.setQuantization(rdh.prefs.tauN_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editTauMean_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.tauMean_classwidth = abs(str2double(get(hObject,'String')));
rdh.t_lim_obj.factor = rdh.prefs.tauMean_classwidth;
rdh.t_lim_obj.offset = 0.5*rdh.prefs.tauMean_classwidth;
rdh.obj.tauMean.setQuantization(rdh.prefs.tauMean_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editQ1_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.q1_classwidth = abs(str2double(get(hObject,'String')));
rdh.q_lim_obj.factor = rdh.prefs.q1_classwidth;
rdh.q_lim_obj.offset = 0.5*rdh.prefs.q1_classwidth;
rdh.obj.q1.setQuantization(rdh.prefs.q1_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editQ2_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.q2_classwidth = abs(str2double(get(hObject,'String')));
rdh.q_lim_obj.factor = rdh.prefs.q2_classwidth;
rdh.q_lim_obj.offset = 0.5*rdh.prefs.q2_classwidth;
rdh.obj.q2.setQuantization(rdh.prefs.q2_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editQ3_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.q3_classwidth = abs(str2double(get(hObject,'String')));
rdh.q_lim_obj.factor = rdh.prefs.q3_classwidth;
rdh.q_lim_obj.offset = 0.5*rdh.prefs.q3_classwidth;
rdh.obj.q3.setQuantization(rdh.prefs.q3_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editQN_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.qN_classwidth = abs(str2double(get(hObject,'String')));
rdh.q_lim_obj.factor = rdh.prefs.qN_classwidth;
rdh.q_lim_obj.offset = 0.5*rdh.prefs.qN_classwidth;
rdh.obj.qN.setQuantization(rdh.prefs.qN_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editCluster_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.c_classwidth = abs(str2double(get(hObject,'String')));
rdh.c_lim_obj.factor = rdh.prefs.c_classwidth;
rdh.c_lim_obj.offset = 0.5*rdh.prefs.c_classwidth;
rdh.obj.c.setQuantization(rdh.prefs.c_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

function editOther_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
rdh.prefs.o_classwidth = abs(str2double(get(hObject,'String')));
rdh.o_lim_obj.factor = rdh.prefs.o_classwidth;
rdh.o_lim_obj.offset = 0.5*rdh.prefs.o_classwidth;
rdh.obj.o.setQuantization(rdh.prefs.o_classwidth);
set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh.prefs);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% --- Executes on button press in defaultbutton.
function defaultbutton_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
%overwrite default values one by one - we don't want to delete parameters
%which are not from this gui
rdh.prefs.amp1_classwidth = rdh.defaults.amp1_classwidth;
rdh.prefs.amp2_classwidth = rdh.defaults.amp2_classwidth;
rdh.prefs.amp3_classwidth = rdh.defaults.amp3_classwidth;
rdh.prefs.ampN_classwidth = rdh.defaults.ampN_classwidth;
rdh.prefs.ampPer1_classwidth = rdh.defaults.ampPer1_classwidth;
rdh.prefs.ampPer2_classwidth = rdh.defaults.ampPer2_classwidth;
rdh.prefs.ampPer3_classwidth = rdh.defaults.ampPer3_classwidth;
rdh.prefs.ampPerN_classwidth = rdh.defaults.ampPerN_classwidth;
rdh.prefs.tau1_classwidth = rdh.defaults.tau1_classwidth;
rdh.prefs.tau2_classwidth = rdh.defaults.tau2_classwidth;
rdh.prefs.tau3_classwidth = rdh.defaults.tau3_classwidth;
rdh.prefs.tauN_classwidth = rdh.defaults.tauN_classwidth;
rdh.prefs.q1_classwidth = rdh.defaults.q1_classwidth;
rdh.prefs.q2_classwidth = rdh.defaults.q2_classwidth;
rdh.prefs.q3_classwidth = rdh.defaults.q3_classwidth;
rdh.prefs.qN_classwidth = rdh.defaults.qN_classwidth;
rdh.prefs.c_classwidth = rdh.defaults.c_classwidth;
rdh.prefs.o_classwidth = rdh.defaults.o_classwidth;

set(handles.StatisticsOptionsFigure,'userdata',rdh);
updateGUI(handles, rdh.defaults); 

% --- Executes on button press in okbutton.
function okbutton_Callback(hObject, eventdata, handles)
rdh = get(handles.StatisticsOptionsFigure,'userdata');
%read settings from objects
types = {'amp','ampPer','tau','q'};
for i = 1:length(types) %loop of types
    for j = 1:3 
        oStr = sprintf('%s%d',types{i},j);        
        [rdh.prefs.(sprintf('%s%d_lb',types{i},j)) rdh.prefs.(sprintf('%s%d_ub',types{i},j)) gMin gMax rdh.prefs.(sprintf('%s%d_lim',types{i},j))] = rdh.obj.(oStr).getCurVals();
    end
    % n
    oStr = sprintf('%sN',types{i}); 
    [rdh.prefs.(sprintf('%sN_lb',types{i})) rdh.prefs.(sprintf('%sN_ub',types{i})) gMin gMax rdh.prefs.(sprintf('%sN_lim',types{i}))] = rdh.obj.(oStr).getCurVals();
end
[rdh.prefs.tauMean_lb rdh.prefs.tauMean_ub gMin gMax rdh.prefs.tauMean_lim] = rdh.obj.tauMean.getCurVals();
[rdh.prefs.c_lb rdh.prefs.c_ub gMin gMax rdh.prefs.c_lim] = rdh.obj.c.getCurVals();
[rdh.prefs.o_lb rdh.prefs.o_ub gMin gMax rdh.prefs.o_lim] = rdh.obj.o.getCurVals();
set(handles.StatisticsOptionsFigure,'userdata',rdh);
uiresume(handles.StatisticsOptionsFigure);

% --- Executes on button press in cancelbutton.
function cancelbutton_Callback(hObject, eventdata, handles)
uiresume(handles.StatisticsOptionsFigure);
delete(handles.StatisticsOptionsFigure);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function editAmp1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editTauN_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editQ1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function amp1_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function amp1_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function tauN_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function tauN_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end% --- Executes during object creation, after setting all properties.
function q1_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function q1_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editCluster_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function c_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function c_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editAmpPerN_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function ampPerN_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function ampPerN_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editTau3_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function tau3_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function tau3_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editTau2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function tau2_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function tau2_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editTau1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function tau1_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function tau1_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editAmpPer3_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function ampPer3_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function ampPer3_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editAmpPer2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function ampPer2_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function ampPer2_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editAmpPer1_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function ampPer1_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function ampPer1_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editAmp2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function amp2_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function amp2_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editAmp3_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function amp3_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function amp3_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editAmpN_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function ampN_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function ampN_hi_edit_CreateFcn(hObject, eventdata, handles)%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editTauMean_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function tauMean_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function tauMean_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editQ2_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function q2_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function q2_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editQ3_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function q3_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function q3_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editQN_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function qN_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function qN_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editOther_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function o_lo_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function o_hi_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

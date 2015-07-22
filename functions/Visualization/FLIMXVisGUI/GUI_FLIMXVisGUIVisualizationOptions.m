function varargout = GUI_FLIMXVisGUIVisualizationOptions(varargin)
%=============================================================================================================
%
% @file     GUI_FLIMXVisGUIVisualizationOptions.m
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
% @brief    A GUI to set visualization options in FLIMXVis
%
%input:
% vargin - structure with preferences and defaults
%output: same as input, but altered according to user input

% Last Modified by GUIDE v2.5 17-Jul-2015 14:57:45

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @GUI_FLIMXVisGUIVisualizationOptions_OpeningFcn, ...
    'gui_OutputFcn',  @GUI_FLIMXVisGUIVisualizationOptions_OutputFcn, ...
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
function GUI_FLIMXVisGUIVisualizationOptions_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_Rosediagram_options (see VARARGIN)
%read current settings and draw them
rdh.flimvis = varargin{1};
rdh.general = varargin{2};
rdh.defaults = varargin{3};
rdh.isDirty = [0 0]; %1: flimvis, 2: general
updateGUI(handles, rdh);
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);

% UIWAIT makes GUI_Rosediagram_options wait for user response (see UIRESUME)
uiwait(handles.FLIMXVisVisualizationOptionsFigure);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_FLIMXVisGUIVisualizationOptions_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    handles.output=[];
    varargout{1} = [];
else
    out = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
    varargout{1} = out;
    delete(handles.FLIMXVisVisualizationOptionsFigure);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%other functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function updateGUI(handles,data)
set(handles.plot_bg_color_button,'Backgroundcolor',data.flimvis.supp_plot_bg_color);
set(handles.plot_cutXLine_color_button,'Backgroundcolor',data.flimvis.cutXColor);
set(handles.plot_cutYLine_color_button,'Backgroundcolor',data.flimvis.cutYColor);
set(handles.plot_ROILine_color_button,'Backgroundcolor',data.flimvis.ROIColor);
set(handles.supp_plot_value_color_button,'Backgroundcolor',data.flimvis.supp_plot_color);
set(handles.cluster_grp_bg_color_button,'Backgroundcolor',data.flimvis.cluster_grp_bg_color);
set(handles.supp_plot_linewidth_edit,'String',num2str(data.flimvis.supp_plot_linewidth));
set(handles.padd_zero_checkbox,'Value',data.flimvis.padd);
set(handles.check_grid_3d,'Value',data.flimvis.grid);
set(handles.check_grid_supp,'Value',data.flimvis.grid);
set(handles.alpha_edit,'String',num2str(data.flimvis.alpha,'%03.2f'));
set(handles.fontsize_edit,'String',num2str(data.flimvis.fontsize,'%2d'));
if(strcmp(data.flimvis.shading,'flat'))
    set(handles.shading_pop,'Value',1);
else
    set(handles.shading_pop,'Value',2);
end
idx = find(strcmpi(get(handles.popupColormap,'String'),data.general.cmType),1);
if(isempty(idx))
    idx = 10; %jet
end
set(handles.popupColormap,'Value',idx);
set(handles.checkInvertColormap,'Value',data.general.cmInvert);
%plot colormap
try
    cm = eval(sprintf('%s(256)',lower(data.general.cmType)));
    if(data.general.cmInvert)
        cm = flipud(cm);
    end
    temp(1,:,:) = cm;
    image(temp,'Parent',handles.axesCM);
    axis(handles.axesCM,'off');
end
set(handles.check_fill_roi,'Value',data.flimvis.ROI_fill_enable);
val = find(strncmp(get(handles.popup_ETDRS_subfield_values,'String'),data.flimvis.ETDRS_subfield_values,length(data.flimvis.ETDRS_subfield_values)),1);
if(isempty(val))
    val = 1;
end
set(handles.popup_ETDRS_subfield_values,'Value',val);
if(val > 1 && data.flimvis.ETDRS_subfield_bg_enable) %sum(data.flimvis.ETDRS_subfield_bg_color(:)) < 1)
    set(handles.check_EDTRS_subfield_bg,'Value',1);
    set(handles.textSubfieldBGColor,'Visible','on');
    set(handles.textSubfieldBGTrans,'Visible','on');
    set(handles.button_ETDRS_bg_color,'Visible','on','Backgroundcolor',data.flimvis.ETDRS_subfield_bg_color(1:3));
    set(handles.edit_ETDRS_bg_trans,'Visible','on','String',data.flimvis.ETDRS_subfield_bg_color(4));
else
    set(handles.check_EDTRS_subfield_bg,'Value',0);
    set(handles.textSubfieldBGColor,'Visible','off');
    set(handles.textSubfieldBGTrans,'Visible','off');
    set(handles.button_ETDRS_bg_color,'Visible','off');
    set(handles.edit_ETDRS_bg_trans,'Visible','off');
end
set(handles.offset_m3d_checkbox,'Value',data.flimvis.offset_m3d);
set(handles.color_cuts_checkbox,'Value',data.flimvis.color_cuts);
set(handles.show_cut_checkbox,'Value',data.flimvis.show_cut);
if(data.flimvis.offset_m3d)
    set(handles.offset_fixed_radio,'Value',data.flimvis.offset_sc,'Enable','on');
    set(handles.offset_adaptive_radio,'Value',~data.flimvis.offset_sc,'Enable','on');
else
    set(handles.offset_fixed_radio,'Value',data.flimvis.offset_sc,'Enable','off');
    set(handles.offset_adaptive_radio,'Value',~data.flimvis.offset_sc,'Enable','off');
end
%startup
if(data.general.openFitGUIonStartup && ~data.general.openVisGUIonStartup)
    set(handles.popupStartupGUIs,'Value',1);
elseif(~data.general.openFitGUIonStartup && data.general.openVisGUIonStartup)
    set(handles.popupStartupGUIs,'Value',2);
else
    set(handles.popupStartupGUIs,'Value',3);
end
set(handles.popupWindowSize,'Value',data.general.windowSize);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%radio buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in offset_fixed_radio.
function offset_fixed_radio_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.offset_sc = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in offset_adaptive_radio.
function offset_adaptive_radio_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.offset_sc = double(~get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on selection change in shading_pop.
function shading_pop_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
if(get(hObject,'Value')==1)
    rdh.flimvis.shading = 'flat';
else
    rdh.flimvis.shading = 'interp';
end
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on selection change in popupColormap.
function popupColormap_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
str = get(hObject,'String');
str = str{get(hObject,'Value')};
rdh.general.cmType = str;
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on selection change in popupStartupGUIs.
function popupStartupGUIs_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
switch get(hObject,'Value')
    case 1
        rdh.general.openFitGUIonStartup = 1;
        rdh.general.openVisGUIonStartup = 0;
    case 2
        rdh.general.openFitGUIonStartup = 0;
        rdh.general.openVisGUIonStartup = 1;
    otherwise
        rdh.general.openFitGUIonStartup = 1;
        rdh.general.openVisGUIonStartup = 1;
end
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on selection change in popupWindowSize.
function popupWindowSize_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.general.windowSize = get(hObject,'Value');
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on selection change in popup_ETDRS_subfield_values.
function popup_ETDRS_subfield_values_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
str = get(hObject,'String');
rdh.flimvis.ETDRS_subfield_values = strtrim(str{get(hObject,'Value')});
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%checkboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in check_fill_roi.
function check_fill_roi_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.ROI_fill_enable = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in check_EDTRS_subfield_bg.
function check_EDTRS_subfield_bg_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.ETDRS_subfield_bg_enable = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in check_grid_3d.
function check_grid_3d_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.grid = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in check_grid_supp.
function check_grid_supp_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.grid = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkInvertColormap.
function checkInvertColormap_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.general.cmInvert = get(hObject,'Value');
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in padd_zero_checkbox.
function padd_zero_checkbox_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.padd = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in offset_m3d_checkbox.
function offset_m3d_checkbox_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.offset_m3d = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in color_cuts_checkbox.
function color_cuts_checkbox_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.color_cuts = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in show_cut_checkbox.
function show_cut_checkbox_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.show_cut = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function edit_ETDRS_bg_trans_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
tmp = max(0,min(1,abs(str2double(get(hObject,'String')))));
if(isnan(tmp))
    tmp = 0.33;
end
rdh.flimvis.ETDRS_subfield_bg_color(4) = tmp;
set(hObject,'String',rdh.flimvis.ETDRS_subfield_bg_color(4));
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);

function alpha_edit_Callback(hObject, eventdata, handles)
current = abs(str2double(get(hObject,'String')));
if(current > 1)
    current = 1;
end
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.alpha = current;
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

function fontsize_edit_Callback(hObject, eventdata, handles)
current = abs(str2double(get(hObject,'String')));
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.fontsize = current;
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

function supp_plot_linewidth_edit_Callback(hObject, eventdata, handles)
current = max(round(abs(str2double(get(hObject,'String')))),1);
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.supp_plot_linewidth = current;
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in button_ETDRS_bg_color.
function button_ETDRS_bg_color_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
cs = GUI_Colorselection(rdh.flimvis.ETDRS_subfield_bg_color(1:3));
if(length(cs) == 3)
    rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
    rdh.flimvis.ETDRS_subfield_bg_color(1:3) = cs;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
end

% --- Executes on button press in plot_bg_color_button.
function plot_bg_color_button_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
cs = GUI_Colorselection(rdh.flimvis.supp_plot_bg_color);
if(length(cs) == 3)
    rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
    rdh.flimvis.supp_plot_bg_color = cs;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
end
updateGUI(handles,rdh);

% --- Executes on button press in plot_cutXLine_color_button.
function plot_cutXLine_color_button_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
cs = GUI_Colorselection(rdh.flimvis.cutXColor);
if(length(cs) == 3)
    rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
    rdh.flimvis.cutXColor = cs;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
end
updateGUI(handles,rdh);

% --- Executes on button press in plot_cutYLine_color_button.
function plot_cutYLine_color_button_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
cs = GUI_Colorselection(rdh.flimvis.cutYColor);
if(length(cs) == 3)
    rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
    rdh.flimvis.cutYColor = cs;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
end
updateGUI(handles,rdh);

% --- Executes on button press in plot_ROILine_color_button.
function plot_ROILine_color_button_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
cs = GUI_Colorselection(rdh.flimvis.ROIColor);
if(length(cs) == 3)
    rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
    rdh.flimvis.ROIColor = cs;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
end
updateGUI(handles,rdh);


% --- Executes on button press in supp_plot_value_color_button.
function supp_plot_value_color_button_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
cs = GUI_Colorselection(rdh.flimvis.supp_plot_color);
if(length(cs) == 3)
    rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
    rdh.flimvis.supp_plot_color = cs;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
end
updateGUI(handles,rdh);

% --- Executes on button press in cluster_grp_bg_color_button.
function cluster_grp_bg_color_button_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
cs = GUI_Colorselection(rdh.flimvis.cluster_grp_bg_color);
if(length(cs) == 3)
    rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
    rdh.flimvis.cluster_grp_bg_color = cs;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
end
updateGUI(handles,rdh);

% --- Executes on button press in defaultbutton.
function defaultbutton_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
%overwrite default values one by one - we don't want to delete parameters
%which are not from this gui
rdh.flimvis.supp_plot_bg_color = data.defaults.flimvis.supp_plot_bg_color;
rdh.flimvis.supp_plot_color = data.defaults.flimvis.supp_plot_color;
rdh.flimvis.supp_plot_linewidth = data.defaults.flimvis.supp_plot_linewidth;
rdh.flimvis.padd = data.defaults.flimvis.padd;
rdh.flimvis.grid = data.defaults.flimvis.grid;
rdh.flimvis.light = data.defaults.flimvis.light;
rdh.flimvis.alpha = data.defaults.flimvis.alpha;
rdh.flimvis.fontsize = data.defaults.flimvis.fontsize;
rdh.flimvis.shading = data.defaults.flimvis.shading;
rdh.flimvis.offset_m3d = data.defaults.flimvis.offset_m3d;
rdh.flimvis.color_cuts = data.defaults.flimvis.color_cuts;
rdh.flimvis.show_cut = data.defaults.flimvis.show_cut;
rdh.flimvis.offset_sc = data.defaults.flimvis.offset_sc;
rdh.flimvis.cluster_grp_bg_color = data.defaults.flimvis.cluster_grp_bg_color;
rdh.general.windowSize = data.defaults.general.windowSize;

% --- Executes on button press in okbutton.
function okbutton_Callback(hObject, eventdata, handles)
uiresume(handles.FLIMXVisVisualizationOptionsFigure);

% --- Executes on button press in cancelbutton.
function cancelbutton_Callback(hObject, eventdata, handles)
uiresume(handles.FLIMXVisVisualizationOptionsFigure);
delete(handles.FLIMXVisVisualizationOptionsFigure);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
function alpha_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function fontsize_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function shading_pop_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function supp_plot_linewidth_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupWindowSize_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupColormap_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupStartupGUIs_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function edit_ETDRS_bg_trans_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
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

% Last Modified by GUIDE v2.5 02-Dec-2021 23:55:03

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
movegui(handles.FLIMXVisVisualizationOptionsFigure,'center');
rdh.flimvis = varargin{1};
rdh.general = varargin{2};
rdh.region_of_interest = varargin{3};
rdh.defaults = varargin{4};
rdh.fdt = varargin{5};
rdh.isDirty = [0 0 0]; %1: flimvis, 2: general 3: region_of_interest
[mapNames, iconPaths] = FLIMX.getColormapsInfo();
if(~isempty(iconPaths))
    %thanks to Yair Altman
    htmlStr = strcat('<html><img width=105 height=10 src="file:///', iconPaths,'">', mapNames');
    set(handles.popupColormapFLIMItems,'String',htmlStr);
    set(handles.popupColormapIntensity,'String',htmlStr);
end
handles.cacheSlider = controllib.widget.Slider(handles.uipaneCacheMemory, [110,21,160,45], unique([0.250:0.25:FLIMX.getMaxSystemCacheSize()/1e9,FLIMX.getMaxSystemCacheSize()/1e9]));
handles.cacheSlider.FontSize = 10;
handles.cacheSlider.Value = rdh.general.maxMemoryCacheSize/1e9;
addlistener(handles.cacheSlider, 'ValueChanged', @cacheSlider_Callback);%,handles.cacheSlider, handles});
%prepare patch for cache level
set(handles.axesCacheMemory,'XLim',[0 100],...
    'YLim',[0 1],...
    'Box','on', ...
    'FontSize', get(0,'FactoryAxesFontSize'),...
    'XTickMode','manual',...
    'YTickMode','manual',...
    'XTick',[],...
    'YTick',[],...
    'XTickLabelMode','manual',...
    'XTickLabel',[],...
    'YTickLabelMode','manual',...
    'YTickLabel',[]);
xpatch = [0 0 0 0];
ypatch = [0 0 1 1];
handles.patchCacheMemory = patch(xpatch,ypatch,'m','EdgeColor','m','Parent',handles.axesCacheMemory);%,'EraseMode','normal'
handles.textCacheMemory = text(1,0,'','Parent',handles.axesCacheMemory);
%set tooltips
handles.textCacheMemorySize = 'Set abount of memory (RAM) used to cache measurements and results';
handles.textCacheMemoryUtilization = 'Shows the current utilization of the cache memory';
guidata(handles.FLIMXVisVisualizationOptionsFigure,handles);
updateGUI(handles,rdh);
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
set(handles.plot_cutXLine_color_button,'Backgroundcolor',data.flimvis.crossSectionXColor);
set(handles.plot_cutYLine_color_button,'Backgroundcolor',data.flimvis.crossSectionYColor);
set(handles.ButtonROILinecolor,'Backgroundcolor',data.flimvis.ROIColor);
set(handles.buttonSuppLinecolor,'Backgroundcolor',data.flimvis.supp_plot_color);
set(handles.buttonMVGrpBgColor,'Backgroundcolor',data.flimvis.cluster_grp_bg_color);
set(handles.editSuppLinewidth,'String',num2str(data.flimvis.supp_plot_linewidth));
set(handles.checkPaddZero,'Value',data.flimvis.padd);
set(handles.checkGrid3D,'Value',data.flimvis.grid);
set(handles.checkSuppGrid,'Value',data.flimvis.grid);
set(handles.editTrans3D,'String',num2str(data.flimvis.alpha,'%03.2f'));
set(handles.editFontsize,'String',num2str(data.flimvis.fontsize,'%2d'));
set(handles.checkReverseYDir,'Value',data.general.reverseYDir);
if(strcmp(data.flimvis.shading,'flat'))
    set(handles.popupShading3D,'Value',1);
else
    set(handles.popupShading3D,'Value',2);
end
set(handles.popupFLIMItems,'Value',data.general.flimParameterView);
switch data.flimvis.MVGroupBrightnessScaling
    case 'log10'
        handles.popupMVGroupBrightnessScaling.Value = 2;
    case 'square'
        handles.popupMVGroupBrightnessScaling.Value = 3;
    case 'exponential'
        handles.popupMVGroupBrightnessScaling.Value = 4;    
    otherwise
        handles.popupMVGroupBrightnessScaling.Value = 1;
end
idx = find(strcmpi(regexprep(get(handles.popupColormapFLIMItems,'String'), '<html><.*">', ''),data.general.cmType),1);
if(isempty(idx))
    idx = 10; %jet
end
set(handles.popupColormapFLIMItems,'Value',idx);
idx = find(strcmpi(regexprep(get(handles.popupColormapIntensity,'String'), '<html><.*">', ''),data.general.cmIntensityType),1);
if(isempty(idx))
    idx = 7; %gray
end
set(handles.popupColormapIntensity,'Value',idx);
set(handles.checkInvertColormapFLIMItems,'Value',data.general.cmInvert);
set(handles.checkInvertColormapIntensity,'Value',data.general.cmIntensityInvert);
set(handles.editLowerBoundColormapFLIMItems,'string',data.general.cmPercentileLB);
set(handles.editUpperBoundColormapFLIMItems,'string',data.general.cmPercentileUB);
set(handles.editLowerBoundColormapIntensity,'string',data.general.cmIntensityPercentileLB);
set(handles.editUpperBoundColormapIntensity,'string',data.general.cmIntensityPercentileUB);
%plot colormap
cm = FLIMX.getColormap(data.general.cmType);%eval(sprintf('%s(256)',lower(data.general.cmType)));
if(data.general.cmInvert)
    cm = flipud(cm);
end
image(shiftdim(cm,-1),'Parent',handles.axesColormapFLIMItems);
axis(handles.axesColormapFLIMItems,'off');
%plot intensity colormap
cm = FLIMX.getColormap(data.general.cmIntensityType);%eval(sprintf('%s(256)',lower(data.general.cmIntensityType)));
if(data.general.cmIntensityInvert)
    cm = flipud(cm);
end
image(shiftdim(cm,-1),'Parent',handles.axesColormapIntensity);
axis(handles.axesColormapIntensity,'off');
set(handles.checkFillROI,'Value',data.flimvis.ROI_fill_enable);
val = find(strncmp(get(handles.popupETDRSSubfieldValues,'String'),data.flimvis.ETDRS_subfield_values,length(data.flimvis.ETDRS_subfield_values)),1);
if(isempty(val))
    val = 1;
end
set(handles.popupROILinestyle,'Value',lineStyle2id(data.flimvis.ROILinestyle));
set(handles.editROILinewidth,'String',data.flimvis.ROILinewidth);
set(handles.checkROIDrawAllOfType,'Value',data.flimvis.ROIDrawAllOfType);
set(handles.popupETDRSSubfieldValues,'Value',val);
if(val > 1 && data.flimvis.ETDRS_subfield_bg_enable) %sum(data.flimvis.ETDRS_subfield_bg_color(:)) < 1)
    set(handles.checkEDTRSSubfieldBg,'Value',1,'Visible','on');
    set(handles.textSubfieldBGColor,'Visible','on');
    %set(handles.textSubfieldBGTrans,'Visible','on');
    set(handles.buttonETDRSBgColor,'Visible','on','Backgroundcolor',data.flimvis.ETDRS_subfield_bg_color(1:3));
    %set(handles.editETDRSBgTrans,'Visible','on','String',data.flimvis.ETDRS_subfield_bg_color(4));
else
    set(handles.checkEDTRSSubfieldBg,'Value',0,'Visible','off');
    set(handles.textSubfieldBGColor,'Visible','off');
    %set(handles.textSubfieldBGTrans,'Visible','off');
    set(handles.buttonETDRSBgColor,'Visible','off');
    %set(handles.editETDRSBgTrans,'Visible','off');
end
set(handles.editETDRSBgTrans,'Visible','on','String',data.flimvis.ETDRS_subfield_bg_color(4));
set(handles.editROIVicinityDistance,'String',data.region_of_interest.vicinityDistance);
set(handles.editROIVicinityWidth,'String',data.region_of_interest.vicinityDiameter);
set(handles.checkOffsetM3D,'Value',data.flimvis.offset_m3d);
set(handles.checkColorCrossSections,'Value',data.flimvis.color_crossSections);
set(handles.checkSuppShowCrossSectionPos,'Value',data.flimvis.show_crossSection);
if(data.flimvis.offset_m3d)
    set(handles.radioOffsetFixed,'Value',data.flimvis.offset_sc,'Enable','on');
    set(handles.radioOffsetAdaptive,'Value',~data.flimvis.offset_sc,'Enable','on');
else
    set(handles.radioOffsetFixed,'Value',data.flimvis.offset_sc,'Enable','off');
    set(handles.radioOffsetAdaptive,'Value',~data.flimvis.offset_sc,'Enable','off');
end
%startup
if(data.general.openFitGUIonStartup && ~data.general.openVisGUIonStartup)
    set(handles.popupStartupGUIs,'Value',1);
elseif(~data.general.openFitGUIonStartup && data.general.openVisGUIonStartup)
    set(handles.popupStartupGUIs,'Value',2);
else
    set(handles.popupStartupGUIs,'Value',3);
end
%window size
if(data.general.autoWindowSize)
    enFlag = 'off';
else
    enFlag = 'on';
end
set(handles.checkAutoWindowSize,'Value',data.general.autoWindowSize);
set(handles.popupWindowSize,'Value',data.general.windowSize,'Enable',enFlag);
%cache level
[~,sz] = data.fdt.getLRUCacheTableSize();
x = sz / data.general.maxMemoryCacheSize * 100;
xpatch = [0 x x 0];
set(handles.patchCacheMemory,'XData',xpatch,'Parent',handles.axesCacheMemory)
yl = ylim(handles.axesCacheMemory);
set(handles.textCacheMemory,'Position',[1,yl(2)/2,0],'String',sprintf('%02.1f%%',x),'Parent',handles.axesCacheMemory);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%sliders
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cacheSlider_Callback(hObject, eventdata)
hFig = gcf;
rdh = get(hFig,'userdata');
rdh.general.maxMemoryCacheSize = hObject.Value*1e9;
[~,curCacheSz] = rdh.fdt.getLRUCacheTableSize();
if(rdh.general.maxMemoryCacheSize < curCacheSz)
    rdh.fdt.checkLRUCacheTableSize(rdh.general.maxMemoryCacheSize);
end
rdh.isDirty(2) = 1;
set(hFig,'userdata',rdh);
updateGUI(handles,rdh);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%radio buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in radioOffsetFixed.
function radioOffsetFixed_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.offset_sc = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in radioOffsetAdaptive.
function radioOffsetAdaptive_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.offset_sc = double(~get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%popup menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on selection change in popupShading3D.
function popupShading3D_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
if(get(hObject,'Value')==1)
    rdh.flimvis.shading = 'flat';
else
    rdh.flimvis.shading = 'interp';
end
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on selection change in popupColormapFLIMItems.
function popupColormapFLIMItems_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
str = get(hObject,'String');
str = str(get(hObject,'Value'));
str = regexprep(str, '<html><.*">', '');
rdh.general.cmType = str{:};
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on selection change in popupColormapIntensity.
function popupColormapIntensity_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
str = get(hObject,'String');
str = str(get(hObject,'Value'));
str = regexprep(str, '<html><.*">', '');
rdh.general.cmIntensityType = str{:};
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on selection change in popupFLIMItems.
function popupFLIMItems_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.general.flimParameterView = get(hObject,'Value');
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on selection change in popupMVGroupBrightnessScaling.
function popupMVGroupBrightnessScaling_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.MVGroupBrightnessScaling = hObject.String{hObject.Value};
rdh.isDirty(1) = 1;
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

% --- Executes on selection change in popupETDRSSubfieldValues.
function popupETDRSSubfieldValues_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
str = get(hObject,'String');
rdh.flimvis.ETDRS_subfield_values = strtrim(str{get(hObject,'Value')});
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on selection change in popupROILinestyle.
function popupROILinestyle_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.ROILinestyle = id2LineStyle(get(hObject,'Value'));
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%checkboxes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in checkFillROI.
function checkFillROI_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.ROI_fill_enable = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkEDTRSSubfieldBg.
function checkEDTRSSubfieldBg_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.ETDRS_subfield_bg_enable = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkROIDrawAllOfType.
function checkROIDrawAllOfType_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.ROIDrawAllOfType = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkGrid3D.
function checkGrid3D_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.grid = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkSuppGrid.
function checkSuppGrid_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.grid = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkInvertColormapFLIMItems.
function checkInvertColormapFLIMItems_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.general.cmInvert = get(hObject,'Value');
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkInvertColormapIntensity.
function checkInvertColormapIntensity_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.general.cmIntensityInvert = get(hObject,'Value');
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkPaddZero.
function checkPaddZero_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.padd = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkOffsetM3D.
function checkOffsetM3D_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.offset_m3d = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkColorCrossSections.
function checkColorCrossSections_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.color_crossSections = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkSuppShowCrossSectionPos.
function checkSuppShowCrossSectionPos_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.show_crossSection = get(hObject,'Value');
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkReverseYDir.
function checkReverseYDir_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.general.reverseYDir = get(hObject,'Value');
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

% --- Executes on button press in checkAutoWindowSize.
function checkAutoWindowSize_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.general.autoWindowSize = get(hObject,'Value');
if(rdh.general.autoWindowSize)
    rdh.general.windowSize = FLIMX.getAutoWindowSize();
end
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%edit fields
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function editROILinewidth_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
tmp = max(1,abs(str2double(get(hObject,'String'))));
if(isnan(tmp))
    tmp = 1;
end
rdh.flimvis.ROILinewidth = tmp;
set(hObject,'String',rdh.flimvis.ROILinewidth);
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);

function editETDRSBgTrans_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
tmp = max(0,min(1,abs(str2double(get(hObject,'String')))));
if(isnan(tmp))
    tmp = 0.33;
end
rdh.flimvis.ETDRS_subfield_bg_color(4) = tmp;
set(hObject,'String',rdh.flimvis.ETDRS_subfield_bg_color(4));
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);

function editTrans3D_Callback(hObject, eventdata, handles)
current = abs(str2double(get(hObject,'String')));
if(current > 1)
    current = 1;
end
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.alpha = current;
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

function editFontsize_Callback(hObject, eventdata, handles)
current = abs(str2double(get(hObject,'String')));
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.fontsize = current;
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

function editSuppLinewidth_Callback(hObject, eventdata, handles)
current = max(round(abs(str2double(get(hObject,'String')))),1);
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.flimvis.supp_plot_linewidth = current;
rdh.isDirty(1) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
updateGUI(handles,rdh);

function editUpperBoundColormapFLIMItems_Callback(hObject, eventdata, handles)
current = min(max(round(10*str2double(get(hObject,'String')))/10,1+str2double(get(handles.editLowerBoundColormapFLIMItems,'String'))),100);
set(hObject,'String',current);
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.general.cmPercentileUB = current;
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);

function editLowerBoundColormapFLIMItems_Callback(hObject, eventdata, handles)
current = min(max(round(10*str2double(get(hObject,'String')))/10,0),str2double(get(handles.editUpperBoundColormapFLIMItems,'String'))-1);
set(hObject,'String',current);
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.general.cmPercentileLB = current;
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);

function editUpperBoundColormapIntensity_Callback(hObject, eventdata, handles)
current = min(max(round(10*str2double(get(hObject,'String')))/10,1+str2double(get(handles.editLowerBoundColormapIntensity,'String'))),100);
set(hObject,'String',current);
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.general.cmIntensityPercentileUB = current;
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);

function editLowerBoundColormapIntensity_Callback(hObject, eventdata, handles)
current = min(max(round(10*str2double(get(hObject,'String')))/10,0),str2double(get(handles.editUpperBoundColormapIntensity,'String'))-1);
set(hObject,'String',current);
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.general.cmIntensityPercentileLB = current;
rdh.isDirty(2) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);


function editROIVicinityDistance_Callback(hObject, eventdata, handles)
current = abs(str2double(get(hObject,'String')));
set(hObject,'String',current);
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.region_of_interest.vicinityDistance = current;
rdh.isDirty(3) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);

function editROIVicinityWidth_Callback(hObject, eventdata, handles)
current = max(1,abs(str2double(get(hObject,'String'))));
set(hObject,'String',current);
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
rdh.region_of_interest.vicinityDiameter = current;
rdh.isDirty(3) = 1;
set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%push buttons
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes on button press in buttonETDRSBgColor.
function buttonETDRSBgColor_Callback(hObject, eventdata, handles)
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
cs = GUI_Colorselection(rdh.flimvis.crossSectionXColor);
if(length(cs) == 3)
    rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
    rdh.flimvis.crossSectionXColor = cs;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
end
updateGUI(handles,rdh);

% --- Executes on button press in plot_cutYLine_color_button.
function plot_cutYLine_color_button_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
cs = GUI_Colorselection(rdh.flimvis.crossSectionYColor);
if(length(cs) == 3)
    rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
    rdh.flimvis.crossSectionYColor = cs;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
end
updateGUI(handles,rdh);

% --- Executes on button press in ButtonROILinecolor.
function ButtonROILinecolor_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
cs = GUI_Colorselection(rdh.flimvis.ROIColor);
if(length(cs) == 3)
    rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
    rdh.flimvis.ROIColor = cs;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
end
updateGUI(handles,rdh);

% --- Executes on button press in buttonSuppLinecolor.
function buttonSuppLinecolor_Callback(hObject, eventdata, handles)
rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
cs = GUI_Colorselection(rdh.flimvis.supp_plot_color);
if(length(cs) == 3)
    rdh = get(handles.FLIMXVisVisualizationOptionsFigure,'userdata');
    rdh.flimvis.supp_plot_color = cs;
    rdh.isDirty(1) = 1;
    set(handles.FLIMXVisVisualizationOptionsFigure,'userdata',rdh);
end
updateGUI(handles,rdh);

% --- Executes on button press in buttonMVGrpBgColor.
function buttonMVGrpBgColor_Callback(hObject, eventdata, handles)
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
%overwrite default values one by one - we don't want to delete parameters which are not from this gui
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
rdh.flimvis.color_crossSections = data.defaults.flimvis.color_crossSections;
rdh.flimvis.show_crossSection = data.defaults.flimvis.show_crossSection;
rdh.flimvis.offset_sc = data.defaults.flimvis.offset_sc;
rdh.flimvis.cluster_grp_bg_color = data.defaults.flimvis.cluster_grp_bg_color;
rdh.general.windowSize = data.defaults.general.windowSize;
updateGUI(handles,rdh);

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
function editTrans3D_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editFontsize_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupShading3D_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editSuppLinewidth_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupWindowSize_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupColormapFLIMItems_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupStartupGUIs_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editETDRSBgTrans_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupFLIMItems_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupROILinestyle_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editROILinewidth_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editUpperBoundColormapFLIMItems_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editLowerBoundColormapFLIMItems_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupColormapIntensity_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editUpperBoundColormapIntensity_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editLowerBoundColormapIntensity_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editROIVicinityDistance_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function editROIVicinityWidth_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes during object creation, after setting all properties.
function popupMVGroupBrightnessScaling_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

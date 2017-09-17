classdef FLIMXVisGUI < handle
    %=============================================================================================================
    %
    % @file     FLIMXVisGUI.m
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
    % @brief    A class to represent a GUI, which visualizes FLIM parameter, enables statistics computations, ...
    %
    properties(GetAccess = public, SetAccess = protected)
        dynParams = []; %sores dynamic display parameters, e.g. color maps
        visHandles = []; %structure to save handles to uicontrols
        objHandles = []; %handles runtime objects except for fdt
        FLIMXObj = []; %FLIMXObj object        
        myStatsDescr = [];
        myStatsGroupComp = [];
        myStatsMVGroup = [];
    end
    properties (Dependent = true)
        fdt = []; %FDTree object
        visParams = []; %options for visualization
        statParams = []; %options for statistics
        exportParams = []; %options for export
        filtParams = []; %options for filtering        
        generalParams = []; %general parameters
    end

    methods
        function this = FLIMXVisGUI(flimX)
            %Constructs a FLIMXVisGUI object.
            if(isempty(flimX))               
                error('Handle to FLIMX object required!');
            end
            this.FLIMXObj = flimX;
            this.myStatsDescr = StatsDescriptive(this);
            this.myStatsGroupComp = StatsGroupComparison(this);
            this.myStatsMVGroup = StatsMVGroupMgr(this);
            this.dynParams.lastPath = flimX.getWorkingDir();
            try
                this.dynParams.cm = eval(sprintf('%s(256)',lower(this.generalParams.cmType)));
            catch
                this.dynParams.cm = jet(256);
            end
            if(this.generalParams.cmInvert)
                this.dynParams.cm = flipud(this.dynParams.cm);
            end
            try
                this.dynParams.cmIntensity = eval(sprintf('%s(256)',lower(this.generalParams.cmIntensityType)));
            catch
                this.dynParams.cmIntensity = gray(256);
            end
            if(this.generalParams.cmIntensityInvert)
                this.dynParams.cmIntensity = flipud(this.dynVisParams.cmIntensity);
            end            
            this.dynParams.mouseButtonDown = false;
            this.dynParams.mouseButtonUp = false;
            this.dynParams.mouseButtonDownROI = [];
            this.dynParams.lastExportFile = 'image.png';
            %init objects            
            this.fdt.setShortProgressCallback(@this.updateShortProgressbar);
            this.fdt.setLongProgressCallback(@this.updateLongProgressbar);            
        end %constructor
        
        %% input functions        
        function setStudy(this,s,val)
            % set current study of side s
            if(isempty(s))
                s = ['l' 'r'];
            end
            for i=1:length(s)
                set(this.visHandles.(sprintf('study_%s_pop',s(i))),'Value',val);
            end
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.FLIMXVisGUIFigure) || ~strcmp(get(this.visHandles.FLIMXVisGUIFigure,'Tag'),'FLIMXVisGUIFigure'));
        end
        
        function checkVisWnd(this)
            %if not reopen
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.setupPopUps([]);
            this.setupGUI();
            this.updateGUI([]);
            figure(this.visHandles.FLIMXVisGUIFigure);
        end %checkVisWnd
                
        function clearAxes(this,s)            
            %clear axes
            if(isempty(s))
                this.clearAxes('l');
                this.clearAxes('r');
                return
            end
            cla(this.visHandles.(sprintf('main_%s_axes',s)));
            axis(this.visHandles.(sprintf('main_%s_axes',s)),'off');
            cla(this.visHandles.(sprintf('supp_%s_axes',s)));
            axis(this.visHandles.(sprintf('supp_%s_axes',s)),'off');
            cla(this.visHandles.cm_axes);
            axis(this.visHandles.cm_axes,'off');
            this.setupPopUps(s);
        end
        
        function setupPopUps(this,s)
            %set defaults
            if(isempty(s))
                s = ['l' 'r'];
            end
            for i=1:length(s)
                set(this.visHandles.(sprintf('main_axes_chan_%s_pop',s(i))),'Value',1,'Visible','on');
                set(this.visHandles.(sprintf('main_axes_%s_pop',s(i))),'Value',1,'Visible','on');
                set(this.visHandles.(sprintf('main_axes_pdim_%s_pop',s(i))),'Enable','on');
                set(this.visHandles.(sprintf('main_axes_var_%s_pop',s(i))),'Value',1,'Enable','off');
                set(this.visHandles.(sprintf('main_axes_scale_%s_pop',s(i))),'Value',1);
            end
        end
        
        function setupGUI(this)
            %setup GUI (popup menus, enable/disable/show/hide controls)
            if(~this.isOpenVisWnd())
                return
            end
            side =  ['l' 'r'];
            studies = this.fdt.getStudyNames();
            try
                this.dynParams.cm = eval(sprintf('%s(256)',lower(this.generalParams.cmType)));
            catch
                this.dynParams.cm = jet(256);
            end
            if(this.generalParams.cmInvert)
                this.dynParams.cm = flipud(this.dynParams.cm);
            end
            try
                this.dynParams.cmIntensity = eval(sprintf('%s(256)',lower(this.generalParams.cmIntensityType)));
            catch
                this.dynParams.cmIntensity = gray(256);
            end
            if(this.generalParams.cmIntensityInvert)
                this.dynParams.cmIntensity = flipud(this.dynParams.cmIntensity);
            end
            %colormap(this.visHandles.cm_axes,this.dynParams.cm);
            for j = 1:length(side)
                s = side(j);
                curStudy = this.getStudy(s); %current study name and index
                curStudyIdx = find(strcmp(curStudy,studies),1);
                if(isempty(curStudyIdx) || curStudyIdx ~= get(this.visHandles.(sprintf('study_%s_pop',s)),'Value'))
                    set(this.visHandles.(sprintf('study_%s_pop',s)),'Value',min(get(this.visHandles.(sprintf('study_%s_pop',s)),'Value'),length(studies)),'String',studies);
                else
                    set(this.visHandles.(sprintf('study_%s_pop',s)),'String',studies,'Value',curStudyIdx);
                end
                curStudy = this.getStudy(s);
                %update views
                views = this.fdt.getStudyViewsStr(this.getStudy(s));
                set(this.visHandles.(sprintf('view_%s_pop',s)),'String',views,'Value',min(get(this.visHandles.(sprintf('view_%s_pop',s)),'Value'),length(views)));
                curView = this.getView(s);          %current view name
                nrSubs = this.fdt.getNrSubjects(curStudy,curView);    %Number of subjects
                if(~nrSubs)
                    this.clearAxes(s);
                    this.updateColorbar();                                                    
                    %clear display objects
                    this.objHandles.(sprintf('%sdo',s)).sethfdMain([]);
                    %channel popups
                    set(this.visHandles.(sprintf('main_axes_chan_%s_pop',s)),'String','Ch','Value',1);                    
                    %setup main popup menus
                    set(this.visHandles.(sprintf('main_axes_%s_pop',s)),'String','params','Value',1);
                    %setup study controls                    
                    set(this.visHandles.(sprintf('dataset_%s_pop',s)),'String','dataset','Value',1);                    
                    %update cuts
                    this.objHandles.cutx.updateCtrls();
                    this.objHandles.cuty.updateCtrls();
                    %ROI
                    this.objHandles.(sprintf('%sROI',s)).setupGUI();
                    this.objHandles.(sprintf('%sZScale',s)).setupGUI();
                    %descriptive statistics
                    this.objHandles.(sprintf('%sdo',s)).makeDSTable();
                    %arithmetic images
                    this.objHandles.AI.updateCtrls();
                    continue
                end                               
                %update subject selection popups
                dStr = this.fdt.getSubjectsNames(curStudy,curView);
                if(~isempty(dStr))
                    set(this.visHandles.(sprintf('dataset_%s_pop',s)),'String',dStr,'Value',min(get(this.visHandles.(sprintf('dataset_%s_pop',s)),'Value'),nrSubs));
                else
                    set(this.visHandles.(sprintf('dataset_%s_pop',s)),'String','dataset','Value',1);
                end
                this.myStatsGroupComp.setupGUI();
                curSubject = this.getSubject(s);
                str = this.fdt.getChStr(curStudy,curSubject);                
                if(~isempty(str))                    
                    %channel popups
                    set(this.visHandles.(sprintf('main_axes_chan_%s_pop',s)),'String',str,'Value',...
                        min(length(str),get(this.visHandles.(sprintf('main_axes_chan_%s_pop',s)),'Value')));                                                                                
                    %setup main popup menus
                    chObj = this.fdt.getChObjStr(curStudy,curSubject,this.getChannel(s));
                    if(~isempty(chObj))
                        MVGroupNames = this.fdt.getStudyClustersStr(curStudy,1);
                        idx = strncmp('MVGroup_',MVGroupNames,8);
                        if(~isempty(idx))
                            MVGroupNames = MVGroupNames(idx);
                        end
                    else
                        MVGroupNames = [];
                    end
                    %determine if variation selection can be activated
                    if(~isempty(MVGroupNames))                        
                        set(this.visHandles.(sprintf('main_axes_var_%s_pop',s)),'Enable','On');
                    else
                        set(this.visHandles.(sprintf('main_axes_var_%s_pop',s)),'Enable','Off');
                        set(this.visHandles.(sprintf('main_axes_var_%s_pop',s)),'Value',1);
                    end
                    %setup gui according to variation selection
                    switch get(this.visHandles.(sprintf('main_axes_var_%s_pop',s)),'Value')
                        case 1 %univariate
                            %add cluster objects to channel object string
                            chObj = unique([chObj;MVGroupNames]);
                            set(this.visHandles.(sprintf('dataset_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('dataset_%s_dec_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('dataset_%s_inc_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('main_axes_pdim_%s_pop',s)),'Enable','on');
                            set(this.visHandles.(sprintf('study_color_%s_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('study_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('view_%s_pop',s)),'Visible','on');
                        case 2 %multivariate
                            chObj = MVGroupNames;
                            set(this.visHandles.(sprintf('dataset_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('dataset_%s_dec_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('dataset_%s_inc_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('main_axes_pdim_%s_pop',s)),'Enable','off','Value',3);
                            set(this.visHandles.(sprintf('study_color_%s_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('study_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('view_%s_pop',s)),'Visible','on');
                        case 3 %view clusters
                            %show only clusters
                            chObj = MVGroupNames;
                            set(this.visHandles.(sprintf('dataset_%s_pop',s)),'Visible','off');
                            set(this.visHandles.(sprintf('dataset_%s_dec_button',s)),'Visible','off');
                            set(this.visHandles.(sprintf('dataset_%s_inc_button',s)),'Visible','off');
                            set(this.visHandles.(sprintf('main_axes_pdim_%s_pop',s)),'Enable','on');
                            set(this.visHandles.(sprintf('study_color_%s_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('study_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('view_%s_pop',s)),'Visible','on');
                        case 4 %global clusters
                            globalMVGroupNames = this.fdt.getGlobalClustersStr();
                            idx = strncmp('MVGroup_',globalMVGroupNames,8);
                            if(~isempty(idx))
                                globalMVGroupNames = globalMVGroupNames(idx);
                            end
                            if(isempty(globalMVGroupNames))
                                %global cluster not created yet
                                errordlg('No multivariate group in mulitple studies available! Please define in Statistics -> Multivariate Groups.','Error Multivariate Groups');
                                set(this.visHandles.(sprintf('main_axes_var_%s_pop',s)),'Value',1);
                                chObj = unique([chObj;MVGroupNames]);
                                set(this.visHandles.(sprintf('dataset_%s_pop',s)),'Visible','on');
                                set(this.visHandles.(sprintf('dataset_%s_dec_button',s)),'Visible','on');
                                set(this.visHandles.(sprintf('dataset_%s_inc_button',s)),'Visible','on');
                                set(this.visHandles.(sprintf('main_axes_pdim_%s_pop',s)),'Enable','on');
                                set(this.visHandles.(sprintf('study_color_%s_button',s)),'Visible','on');
                                set(this.visHandles.(sprintf('study_%s_pop',s)),'Visible','on');
                                set(this.visHandles.(sprintf('view_%s_pop',s)),'Visible','on');
                            else
                                chObj = globalMVGroupNames;
                                set(this.visHandles.(sprintf('dataset_%s_pop',s)),'Visible','off');
                                set(this.visHandles.(sprintf('dataset_%s_dec_button',s)),'Visible','off');
                                set(this.visHandles.(sprintf('dataset_%s_inc_button',s)),'Visible','off');
                                set(this.visHandles.(sprintf('study_color_%s_button',s)),'Visible','off');
                                set(this.visHandles.(sprintf('study_%s_pop',s)),'Visible','off');
                                set(this.visHandles.(sprintf('view_%s_pop',s)),'Visible','off');
                            end
                    end
                    %supplementary plot histogram selection
                    if(get(this.visHandles.(sprintf('supp_axes_%s_pop',s)),'Value') == 2)
                        %Histogram
                        if(get(this.visHandles.(sprintf('main_axes_var_%s_pop',s)),'Value') == 1)
                            %univariate
                            set(this.visHandles.(sprintf('supp_axes_hist_%s_pop',s)),'Visible','on','Enable','on');
                        else %multivariate, clusters
                            set(this.visHandles.(sprintf('supp_axes_hist_%s_pop',s)),'Visible','on','Enable','off','Value',1);
                        end
                        set(this.visHandles.(sprintf('supp_axes_scale_%s_pop',s)),'Visible','on');
                        set(this.visHandles.(sprintf('color_scale_%s_panel',s)),'Visible','on');
                    else %none, cuts
                        set(this.visHandles.(sprintf('supp_axes_hist_%s_pop',s)),'Visible','off');
                        set(this.visHandles.(sprintf('supp_axes_scale_%s_pop',s)),'Visible','off');
                        set(this.visHandles.(sprintf('color_scale_%s_panel',s)),'Visible','off');
                    end
                    if(~isempty(chObj))
                        oldPStr = get(this.visHandles.(sprintf('main_axes_%s_pop',s)),'String');
                        if(iscell(oldPStr))
                            oldPStr = oldPStr(get(this.visHandles.(sprintf('main_axes_%s_pop',s)),'Value'));
                        end
                        %try to find oldPStr in new pstr
                        idx = find(strcmp(oldPStr,chObj),1);
                        if(isempty(idx))
                            idx = min(get(this.visHandles.(sprintf('main_axes_%s_pop',s)),'Value'),length(chObj));
                        end            
                        set(this.visHandles.(sprintf('main_axes_%s_pop',s)),'String',chObj,'Value',idx);
                    else
                        %empty channels
                        set(this.visHandles.(sprintf('main_axes_%s_pop',s)),'String','params','Value',1);
                    end
                else
                    %no channels
                    this.clearAxes(s);
                    %clear display objects
                    this.objHandles.(sprintf('%sdo',s)).sethfdMain([]);
                    %channel popups
                    set(this.visHandles.(sprintf('main_axes_chan_%s_pop',s)),'String','Ch','Value',1);
                    %setup main popup menus
                    set(this.visHandles.(sprintf('main_axes_%s_pop',s)),'String','params','Value',1);
                end
                %set arbitrary initial color value for new study
                cColor = this.fdt.getViewColor(curStudy,curView);
                if(isempty(cColor) || length(cColor) ~= 3)
                    newColor = studyIS.makeRndColor();
                    set(this.visHandles.(sprintf('study_color_%s_button',s)),'Backgroundcolor',newColor);
                    this.fdt.setViewColor(curStudy,curView,newColor);
                else
                    set(this.visHandles.(sprintf('study_color_%s_button',s)),'Backgroundcolor',cColor);
                end
            end
            %colorbar
            this.updateColorbar();                               
            %arithmetic images
            this.objHandles.AI.updateCtrls();            
        end %setupGUI
        
        function updateGUI(this,side)
            %update GUI
            if(~this.isOpenVisWnd())
                return
            end
            if(isempty(side))
                side =  ['l' 'r'];
            end
            this.fdt.setCancelFlag(false);
            for j = 1:length(side)                
                s = side(j);                
                if(~this.fdt.getNrSubjects(this.getStudy(s),this.getView(s)))
                    continue
                end
                %update display objects
                this.objHandles.(sprintf('%sdo',s)).sethfdMain([]);
                %roi
                this.objHandles.(sprintf('%sROI',s)).updateGUI([]);
                this.objHandles.(sprintf('%sZScale',s)).updateGUI([]);
                this.objHandles.(sprintf('%sdo',s)).updatePlots();
                this.objHandles.(sprintf('%sdo',s)).myColorScaleObj.checkCallback();                
                if(strcmp(s,'l'))
                    %update cuts
                    this.objHandles.cutx.updateCtrls();
                    this.objHandles.cuty.updateCtrls();
                end
                switch get(this.visHandles.(sprintf('supp_axes_%s_pop',s)),'Value')
                    case 1 %none
                        set(this.visHandles.(sprintf('supp_axes_scale_%s_pop',s)),'Enable','off');
                    case {2,3,4} %histograms
                        set(this.visHandles.(sprintf('supp_axes_scale_%s_pop',s)),'Enable','off');
                    case 5 %horizontal cut
                        set(this.visHandles.(sprintf('supp_axes_scale_%s_pop',s)),'Enable','on');
                    case 6 %vertical cut
                        set(this.visHandles.(sprintf('supp_axes_scale_%s_pop',s)),'Enable','on'); 
                end
                %enable / disable intensity overlay functions
                var = get(this.visHandles.(sprintf('main_axes_var_%s_pop',s)),'Value');
                dType = this.getFLIMItem(s);                
                %check if a cluster object is selected
                clf = false;
                switch var
                    case 1
                        if(strncmp(dType,'MVGroup',7))
                            %we have a cluster object in univariate mode
                            
                            clf = true;
                        end
                    case 3
                        %view cluster
                        clf = true;
                end
                if(clf)
                    %disable intensity overlay functions
                    set(this.visHandles.(sprintf('IO_%s_check',s)),'Enable','Off');
                    set(this.visHandles.(sprintf('IO_%s_edit',s)),'Enable','Off');
                    set(this.visHandles.(sprintf('IO_%s_inc_button',s)),'Enable','Off');
                    set(this.visHandles.(sprintf('IO_%s_dec_button',s)),'Enable','Off');
                else
                    %enable intensity overlay functions
                    set(this.visHandles.(sprintf('IO_%s_check',s)),'Enable','On');
                    set(this.visHandles.(sprintf('IO_%s_edit',s)),'Enable','On');
                    set(this.visHandles.(sprintf('IO_%s_inc_button',s)),'Enable','On');
                    set(this.visHandles.(sprintf('IO_%s_dec_button',s)),'Enable','On');
                end
            end %for j=1:length(side)
        end %updateGUI
        
        function updateShortProgressbar(this,x,text)
            %update short progress bar; inputs: progress x: 0..1, text on progressbar
            if(this.isOpenVisWnd())
                x = max(0,min(100*x,100));
                xpatch = [0 x x 0];
                set(this.visHandles.patch_short_progress,'XData',xpatch,'Parent',this.visHandles.short_progress_axes)
                yl = ylim(this.visHandles.short_progress_axes);
                set(this.visHandles.text_short_progress,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.short_progress_axes);
                drawnow;
            end
        end
        
        function updateLongProgressbar(this,x,text)
            %update long progress bar; inputs: progress x: 0..1, text on progressbar
            if(this.isOpenVisWnd())
                x = max(0,min(100*x,100));
                xpatch = [0 x x 0];
                set(this.visHandles.patch_long_progress,'XData',xpatch,'Parent',this.visHandles.long_progress_axes)
                yl = ylim(this.visHandles.long_progress_axes);
                set(this.visHandles.text_long_progress,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.long_progress_axes);
                drawnow;
            end
        end          
        
        %colorbar
        function updateColorbar(this)
            %update the colorbar to the current color map
            temp = zeros(length(this.dynParams.cm),2,3);
            if(strcmp(this.getFLIMItem('l'),'Intensity'))
                temp(:,1,:) = gray(size(temp,1));
            else
                temp(:,1,:) = this.dynParams.cm;
            end
            if(strcmp(this.getFLIMItem('r'),'Intensity'))
                temp(:,2,:) = gray(size(temp,1));
            else
                temp(:,2,:) = this.dynParams.cm;
            end
            image(temp,'Parent',this.visHandles.cm_axes);
            ytick = (0:0.25:1).*size(this.dynParams.cm,1);
            ytick(1) = 1;
            set(this.visHandles.cm_axes,'YDir','normal','YTick',ytick,'YTickLabel','','YAxisLocation','right','XTick',[],'XTickLabel','');
            ylim(this.visHandles.cm_axes,[1 size(this.dynParams.cm,1)]);
            setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.cm_axes,false);
        end
                               
        %% menu functions                
        function menuExit_Callback(this,hObject,eventdata)
            %close window
            this.myStatsMVGroup.closeCallback();
            this.myStatsDescr.menuExit_Callback();
            this.myStatsGroupComp.menuExit_Callback();
            if(ishandle(this.visHandles.FLIMXVisGUIFigure))
                delete(this.visHandles.FLIMXVisGUIFigure);
            end
            this.FLIMXObj.destroy(false);
        end
        
        function menuFiltOpt_Callback(this,hObject,eventdata)
            %Open GUI to configure FLIMXVis filtering options
            this.FLIMXObj.paramMgr.readConfig();
            opts.prefs = this.filtParams;
            opts.defaults = this.filtParams; %todo
            new = GUI_Filter_Options(opts);
            if(isfield(new,'prefs'))
                %save to disc
                this.FLIMXObj.paramMgr.setParamSection('filtering',new.prefs);
                this.updateGUI([]);
            end  
        end
        function menuStatOpt_Callback(this,hObject,eventdata)
            %Open GUI to configure FLIMXVis statistics options
            this.FLIMXObj.paramMgr.readConfig();
            opts.prefs = this.statParams;
            opts.defaults = this.statParams; %todo
            new = GUI_Statistics_Options(opts);
            if(isfield(new,'prefs'))
                %save to disc
                this.FLIMXObj.paramMgr.setParamSection('statistics',new.prefs);
                this.fdt.clearAllCIs(''); %can be more efficient
                this.myStatsGroupComp.clearResults();
                this.updateGUI([]);
                %instead?!
            end 
        end
        function menuVisOpt_Callback(this,hObject,eventdata)
            %Open GUI to configure FLIMXVis visualization options
            defaults.flimvis = this.visParams;
            defaults.general = this.generalParams; %todo
            new = GUI_FLIMXVisGUIVisualizationOptions(defaults.flimvis,defaults.general,defaults);
            if(~isempty(new))
                %save to disc
                if(new.isDirty(1) == 1)
                    this.FLIMXObj.paramMgr.setParamSection('flimvis_gui',new.flimvis);
                end
                if(new.isDirty(2) == 1)                    
                    if(this.generalParams.flimParameterView ~= new.general.flimParameterView)
                        this.FLIMXObj.fdt.unloadAllChannels();                        
                    end
                    this.FLIMXObj.paramMgr.setParamSection('general',new.general);
                    this.FLIMXObj.FLIMFitGUI.setupGUI();
                    this.FLIMXObj.FLIMFitGUI.updateGUI(1);
%                     if(new.general.cmIntensityPercentileLB ~= defaults.general.cmIntensityPercentileLB || new.general.cmIntensityPercentileUB ~= defaults.general.cmIntensityPercentileUB ||...
%                         new.general.cmPercentileLB ~= defaults.general.cmPercentileLB || new.general.cmPercentileUB ~= defaults.general.cmPercentileUB)
%                         this.objHandles.ldo.myColorScaleObj.checkCallback();
%                         this.objHandles.rdo.myColorScaleObj.checkCallback();
%                     end
                end
                this.setupGUI();
                this.updateGUI([]);
            end            
        end
        
        function menuExpOpt_Callback(this,hObject,eventdata)
            %Open GUI to configure FLIMXVis export options
            this.FLIMXObj.paramMgr.readConfig();
            opts.prefs = this.exportParams;
            opts.defaults = this.exportParams; %todo
            new = GUI_Export_Options(opts);
            if(isfield(new,'prefs'))
                %save to disc
                this.FLIMXObj.paramMgr.setParamSection('export',new.prefs);
            end  
        end
                
        function menuDescriptive_Callback(this,hObject,eventdata)
            %show descriptive statistics tool window
            this.myStatsDescr.checkVisWnd(); 
            this.myStatsDescr.setCurrentStudy(this.getStudy('l'),this.getView('l'));
        end
        
        function menuHolmWilcoxon_Callback(this,hObject,eventdata)
            %show holm wilcoxon statistics tool window
            this.myStatsGroupComp.checkVisWnd();            
        end
        
        function menuClustering_Callback(this,hObject,eventdata)
            %show clustering tool window
            this.myStatsMVGroup.checkVisWnd();
        end
        
        function menuOpenStudyMgr_Callback(this,hObject,eventdata)
            %show study manager window
            this.FLIMXObj.studyMgrGUI.checkVisWnd();
            this.FLIMXObj.studyMgrGUI.curStudyName = this.getStudy('l');
        end
        
        function menuOpenFLIMXFit_Callback(this,hObject,eventdata)
            %show FLIMXFit GUI window
            this.FLIMXObj.FLIMFitGUI.checkVisWnd();
        end        
        
        function menuScreenshot_Callback(this,hObject,eventdata)
            %take a screenshot (therefore redraw selected axes in new figure)   
            tag = get(hObject,'Tag');
            side = 'l';            
            if(contains(tag,'R'))
                side = 'r';
            end
            pType = 'main'; %main plot
            if(contains(tag,'B'))
                pType = 'supp'; %supp. plot
            end
            %[pathstr,name,ext] = fileparts(this.dynParams.lastExportFile);
            formats = {'*.png','Portable Network Graphics (*.png)';...
                '*.jpg','Joint Photographic Experts Group (*.jpg)';...
                '*.eps','Encapsulated Postscript (*.eps)';...
                '*.tiff','TaggedImage File Format (*.tiff)';...
                '*.bmp','Windows Bitmap (*.bmp)';...
                '*.emf','Windows Enhanced Metafile (*.emf)';...
                '*.pdf','Portable Document Format (*.pdf)';...
                '*.fig','MATLAB figure (*.fig)';...
                '*.png','16-bit Portable Network Graphics (*.png)';...
                '*.jpg','16-bit Joint Photographic Experts Group (*.jpg)';...
                '*.tiff','16-bit TaggedImage File Format (*.tiff)';...
                };
%             idx = strcmp(formats(:,1),['*' ext]);
%             if(any(idx))
%                 fn = cell(size(formats));
%                 fn(1,:) = formats(idx,:);
%                 fn(2:end,:) = formats(~idx,:);
%                 formats = fn;
%                 clear fn
%             end
            [file, path, filterindex] = uiputfile(formats,'Export Figure as',this.dynParams.lastExportFile);
            if ~path ; return ; end
            fn = fullfile(path,file);
            this.dynParams.lastExportFile = file;
            switch filterindex
                case 5 %'*.bmp'
                    str = '-dbmp';
                case 6% '*.emf'
                    str = '-dmeta';
                case 3 %'*.eps'
                    str = '-depsc2';
                case 2 %'*.jpg'
                    str = '-djpeg';
                case 7 %'*.pdf'
                    str = '-dpdf';
                case 1 %'*.png'
                    str = '-dpng';
                case 4 %'*.tiff'
                    str = '-dtiff';                    
            end            
            hFig = figure;
            set(hFig,'Renderer','Painters');
            ssObj = FScreenshot(this.objHandles.(sprintf('%sdo',side)));
            ssObj.makeScreenshotPlot(hFig,pType);
            %pause(1) %workaround for wrong painting
            switch filterindex
                case 8
                    savefig(hFig,fn);
                case {9,11}
                    imwrite(uint16(ssObj.mainExportXls),fn);
                case 10
                    imwrite(uint16(ssObj.mainExportXls),fn,'BitDepth',16,'Mode','lossless');
                otherwise                    
                    if(this.exportParams.resampleImage)
                        print(hFig,str,['-r' num2str(this.exportParams.dpi)],fn);
                    else
                        imwrite(ssObj.mainExportColors,fn);
                    end
            end
            if(ishandle(hFig))
                close(hFig);
            end   
        end
        
        function menuExportMovie_Callback(this,hObject,eventdata)
            %export a movie
            this.objHandles.movObj.checkVisWnd();
        end
        
        function menuAbout_Callback(this,hObject,eventdata)
            %
            GUI_versionInfo(this.FLIMXObj.paramMgr.getParamSection('about'),this.FLIMXObj.curSubject.aboutInfo());
        end
        
        
        %% dependent properties
        function out = get.fdt(this)
            %shortcut to fdt
            out = this.FLIMXObj.fdt;
        end
        
        function out = get.generalParams(this)
            %
            out = this.FLIMXObj.paramMgr.getParamSection('general');
        end
        
        function out = get.visParams(this)
            %
            out = this.FLIMXObj.paramMgr.getParamSection('flimvis_gui');
        end        
        
        function set.visParams(this,val)
            %
            this.FLIMXObj.paramMgr.setParamSection('flimvis_gui',val);
        end
        
        function out = get.statParams(this)
            %
            out = this.FLIMXObj.paramMgr.getParamSection('statistics');
        end
        
        function out = get.exportParams(this)
            %
            out = this.FLIMXObj.paramMgr.getParamSection('export');
        end
        
        function out = get.filtParams(this)
            %
            out = this.FLIMXObj.paramMgr.getParamSection('filtering');
        end
        
        %% get current GUI values
        function out = getScale(this,s)
            %get current channel number of side s
            out = get(this.visHandles.(sprintf('main_axes_scale_%s_pop',s)),'Value');
        end
        
        function [dType, dTypeNr] = getFLIMItem(this,s)
            %get datatype and number of currently selected FLIM item
            list = get(this.visHandles.(sprintf('main_axes_%s_pop',s)),'String');
            ma_pop_sel = get(this.visHandles.(sprintf('main_axes_%s_pop',s)),'Value');
            switch get(this.visHandles.(sprintf('main_axes_var_%s_pop',s)),'Value')                
                case {1,3,4} %univariate / view cluster
                    [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(list(ma_pop_sel,:));
                case 2 %multivariate
                    cMVs = this.fdt.getClusterTargets(this.getStudy(s),list{ma_pop_sel});
                    %get multivariate targets out of cluster targets
                    MVTargets = unique([cMVs.x,cMVs.y]);
                    dType = cell(length(MVTargets),1);
                    dTypeNr = zeros(length(MVTargets),1);
                    for i = 1:length(MVTargets)
                        [dType(i), dTypeNr(i)] = FLIMXVisGUI.FLIMItem2TypeAndID(MVTargets{i});
                    end                    
            end
        end
        
        function out = getChannel(this,s)
            %get current channel number of side s
            out = 1;
            str = get(this.visHandles.(sprintf('main_axes_chan_%s_pop',s)),'String');
            str = str(get(this.visHandles.(sprintf('main_axes_chan_%s_pop',s)),'Value'));
            idx = isstrprop(str, 'digit');
            if(~iscell(idx))
                return
            end
            idx = idx{:};
            str = char(str);
            out = str2double(str(idx));
        end
        
        function out = getROIDisplayMode(this,s)
            %get '2D', ROI 2D or ROI 3D
            out = get(this.visHandles.(sprintf('main_axes_pdim_%s_pop',s)),'Value');
        end
        
        function [name, nr] = getSubject(this,s)
            %get current subject name of side s
            name = [];
            NrSubs = this.fdt.getNrSubjects(this.getStudy(s),this.getView(s));
            if(NrSubs ~= 0)
                %study/view does contain subjects
                nr = get(this.visHandles.(sprintf('dataset_%s_pop',s)),'Value');
                subs = get(this.visHandles.(sprintf('dataset_%s_pop',s)),'String');           
                if(iscell(subs))
                    name = subs{nr};
                else
                    name = subs;
                end
            end
        end
        
        function [name, nr] = getStudy(this,s)
            %get name of current study of side s            
            %out = get(this.visHandles.(sprintf('study_%s_pop',s)),'Value');
            nr = get(this.visHandles.(sprintf('study_%s_pop',s)),'Value');
            str = get(this.visHandles.(sprintf('study_%s_pop',s)),'String');
            if(iscell(str))
                name = str{nr};
            elseif(ischar(str))
                %nothing to do
                name = str;
            else
                nr = 1;
                name = 'Default';
            end
        end
        
        function [name, nr] = getView(this,s)
            %get name of current view of side s
            nr = get(this.visHandles.(sprintf('view_%s_pop',s)),'Value');
            names = get(this.visHandles.(sprintf('view_%s_pop',s)),'String');
            name = names{nr};
        end
        
        function out = getROICoordinates(this,s)
            %get the coordinates of the ROI of side s
            out = this.objHandles.(sprintf('%sROI',s)).getCurROIInfo();
            out = out(:,2:end);
        end
        
        function out = getROIType(this,s)
            %get the type of the ROI of side s
            out = this.objHandles.(sprintf('%sROI',s)).ROIType;
        end
        
        function out = getROISubType(this,s)
            %get the subtype of the ROI of side s
            out = this.objHandles.(sprintf('%sROI',s)).ROISubType;
        end
        
        function out = getROIInvertFlag(this,s)
            %get the subtype of the ROI of side s
            out = this.objHandles.(sprintf('%sROI',s)).ROIInvertFlag;
        end
        
        function out = getStatsParams(this)
            %get statistics parameters
            out = this.statParams;
        end
        
        %% GUI callbacks
        function GUI_cancelButton_Callback(this,hObject,eventdata)
            %try to stop current FDTree operation
            button = questdlg(sprintf('Caution!\nCanceling the current operation will probably lead to false results!\nInvalidate to force re-computation (e.g. by reseting the Region of Interest).\n\nStill Cancel?'),'Cancel','Cancel','Continue','Continue');
            switch button
                case 'Cancel'
                    this.fdt.setCancelFlag(true);
            end
        end
        
        function GUI_enableMouseCheck_Callback(this,hObject,eventdata)
            %en/dis-able mouse motion callbacks
        end
        
        function GUI_sync3DViews_check_Callback(this,hObject,eventdata)
            %en/dis-able synchronization of 3D views
            %left side leads
            this.objHandles.rdo.setDispView(this.objHandles.ldo.getDispView());
            this.objHandles.rdo.updatePlots();            
        end
        
        function GUI_mouseScrollWheel_Callback(this,hObject,eventdata)
            %executes on mouse scroll wheel move in window 
            cp = this.objHandles.ldo.getMyCP(1);
            s = 'l'; %this side
            if(isempty(cp))
                cp = this.objHandles.rdo.getMyCP(1);
                if(isempty(cp))
                    return;
                end
                s = 'r';
            end
            hSlider = this.visHandles.(sprintf('slider_%s_zoom',s));
            this.objHandles.(sprintf('%sdo',s)).setZoomAnchor(cp);
            hSlider.Value = max(hSlider.Min,min(hSlider.Max,hSlider.Value+hSlider.SliderStep(1)*eventdata.VerticalScrollCount));
            if(hSlider.Value == 1)
                %reset zoom anchor if zoom level = 1
                this.objHandles.(sprintf('%sdo',s)).setZoomAnchor([]);
            end
            this.objHandles.(sprintf('%sdo',s)).makeZoom();
            GUI_mouseMotion_Callback(this,hObject,[]);
        end
        
        function GUI_mouseMotion_Callback(this,hObject,eventdata)
            %executes on mouse move in window 
            oneSec = 1/24/60/60;
            persistent inFunction lastUpdate
            if(isempty(lastUpdate))
                lastUpdate = now;
            end            
            if(~isempty(inFunction) && now - lastUpdate < 5*oneSec), return; end
            inFunction = 1;  %prevent callback re-entry
            %update at most 100 times per second (every 0.01 sec)            
            try
                tNow = datenummx(clock);  %fast
            catch
                tNow = now;  %slower
            end            
            if(~isempty(lastUpdate) && tNow - lastUpdate < 0.010*oneSec || this.dynParams.mouseButtonUp)
                inFunction = [];  %enable callback
                return;
            end
            lastUpdate = tNow;
            %% coordinates
            cpMain = this.objHandles.ldo.getMyCP(1);
            thisSide = 'l';
            otherSide = 'r';
            if(isempty(cpMain))
                cpMain = this.objHandles.rdo.getMyCP(1);
                thisSide = 'r';
                otherSide = 'l';
            end
            cpSupp = [];
            if(isempty(cpMain))
                %no hit on main axes, try supp axes
                cpSupp = this.objHandles.ldo.getMyCP(2);
                thisSide = 'l';
                otherSide = 'r';
                if(isempty(cpSupp))
                    cpSupp = this.objHandles.rdo.getMyCP(2);
                    thisSide = 'r';
                    otherSide = 'l';
                end
            end
            %% cursor
            if(~isempty(cpMain) && this.getROIDisplayMode(thisSide) < 3 || ~isempty(cpSupp))
                set(this.visHandles.FLIMXVisGUIFigure,'Pointer','cross');
            elseif(isempty(cpMain) && isempty(cpSupp))
                set(this.visHandles.FLIMXVisGUIFigure,'Pointer','arrow'); 
            end
            %% main axes           
            thisROIObj = this.objHandles.(sprintf('%sROI',thisSide));
            otherROIObj = this.objHandles.(sprintf('%sROI',otherSide));
            if(~isempty(cpMain) && this.getROIDisplayMode(thisSide) < 3)
                if(this.dynParams.mouseButtonDown)
                    if(this.getROIType(thisSide) >= 1)% && this.getROIType(thisSide) < 6)% && get(this.visHandles.enableMouse_check,'Value'))
                        if(strcmp('normal',get(hObject,'SelectionType')))
                            %left button down
                            thisROIObj.setEndPoint(flipud(cpMain),false);
                            %draw ROI
                            this.objHandles.(sprintf('%sdo',thisSide)).drawROI(this.getROIType(thisSide),flipud(this.dynParams.mouseButtonDownCoord),flipud(cpMain),false);
                        else
                            %right button down: move ROI
                            dTarget = int16(flipud(this.dynParams.mouseButtonDownCoord-cpMain));
                            ROICoord = thisROIObj.getCurROIInfo();
                            ROICoord = ROICoord(:,2:end);
                            dMoved = this.dynParams.mouseButtonDownROI - ROICoord(:,1);
                            thisROIObj.moveROI(dTarget-dMoved,false);
                            %get ROI coordinates after moving
                            ROICoord = thisROIObj.getCurROIInfo();
                            %draw ROI
                            this.objHandles.(sprintf('%sdo',thisSide)).drawROI(this.getROIType(thisSide),ROICoord(:,3:end),ROICoord(:,2),false);
                            if(thisROIObj.ROIType == otherROIObj.ROIType && strcmp(this.getStudy(thisSide),this.getStudy(otherSide)) && strcmp(this.getSubject(thisSide),this.getSubject(otherSide)) && this.getROIDisplayMode(otherSide) == 1)
                                %move ROI also on the other side
                                this.objHandles.(sprintf('%sdo',otherSide)).drawROI(this.getROIType(thisSide),ROICoord(:,3:end),ROICoord(:,2),false);
                            end
                        end                    
                    end
                end
                %draw mouse overlay on this side in main axes
                this.objHandles.(sprintf('%sdo',thisSide)).drawCPMain(cpMain);
                if(this.getROIDisplayMode(thisSide) == 1 && this.getROIDisplayMode(otherSide) == 1 || this.getROIDisplayMode(thisSide) == 2 && this.getROIDisplayMode(otherSide) == 2 && thisROIObj.ROIType == otherROIObj.ROIType)
                    this.objHandles.(sprintf('%sdo',otherSide)).drawCPMain(cpMain);
                else
                    %other side displays something else, clear possible invalid mouse overlay
                    this.objHandles.(sprintf('%sdo',otherSide)).drawCPMain([]);
                end
            else
                %we are not inside of main axes -> clear possible invalid mouse overlays
                this.objHandles.(sprintf('%sdo',thisSide)).drawCPMain([]);
                this.objHandles.(sprintf('%sdo',otherSide)).drawCPMain([]);
            end            
            %% supp axes
            if(~isempty(cpSupp) && this.visHandles.(sprintf('supp_axes_%s_pop',thisSide)).Value >= 2)
                %in supp axes and either histogram or cross-section is shown
                if(this.visHandles.(sprintf('supp_axes_%s_pop',thisSide)).Value == 2 && this.dynParams.mouseButtonDown)
                    this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.setColorScale(int16([0 this.dynParams.mouseButtonDownCoord(1) cpSupp(1)]),true);
                    [thisDType, thisDTypeNr] = this.getFLIMItem(thisSide);
                    [otherDType, otherDTypeNr] = this.getFLIMItem(otherSide);
                    if(strcmp(thisDType,otherDType) && thisDTypeNr == otherDTypeNr && strcmp(this.getStudy(thisSide),this.getStudy(otherSide)) && strcmp(this.getSubject(thisSide),this.getSubject(otherSide)))
                        this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
                    end
                end  
            else
                %we are not inside of supp axes -> this will clear a possible invalid mouse overlay
                cpSupp = [];
            end
            %draw mouse overlay on this side in support axes
            this.objHandles.(sprintf('%sdo',thisSide)).drawCPSupp(cpSupp);
            %clear mous overlay on the other side in the support axes
            this.objHandles.(sprintf('%sdo',otherSide)).drawCPSupp([]);
            %% enable callback
            inFunction = [];            
        end
        
        function GUI_mouseButtonDown_Callback(this,hObject,eventdata)
            %executes on mouse button down in window
            %this function is now always called by its wrapper: rotate_mouseButtonDownWrapper        
            %% coordinates
            cpMain = this.objHandles.ldo.getMyCP(1);
            thisSide = 'l';
            otherSide = 'r';
            if(isempty(cpMain))
                cpMain = this.objHandles.rdo.getMyCP(1);
                thisSide = 'r';
                otherSide = 'l';
            end
            cpSupp = [];
            if(isempty(cpMain))
                %no hit on main axes, try supp axes
                cpSupp = this.objHandles.ldo.getMyCP(2);
                thisSide = 'l';
                otherSide = 'r';
                if(isempty(cpSupp))
                    cpSupp = this.objHandles.rdo.getMyCP(2);
                    thisSide = 'r';
                    otherSide = 'l';
                end
            end
            %% cursor
            if(~isempty(cpMain) && this.getROIDisplayMode(thisSide) < 3 || ~isempty(cpSupp))
                set(this.visHandles.FLIMXVisGUIFigure,'Pointer','cross');
            elseif(isempty(cpMain) && isempty(cpSupp))
                set(this.visHandles.FLIMXVisGUIFigure,'Pointer','arrow');
                return
            end
            %% main axes
            if(~isempty(cpMain) && this.getROIType(thisSide) >= 1)
                mLeftButton = strcmp('normal',get(hObject,'SelectionType'));
                thisROIObj = this.objHandles.(sprintf('%sROI',thisSide));
                otherROIObj = this.objHandles.(sprintf('%sROI',otherSide));
                if(this.getROIDisplayMode(thisSide) < 3 && get(this.visHandles.enableMouse_check,'Value') && this.getROIType(thisSide) >= 1)
                    this.dynParams.mouseButtonDown = true;
                    this.dynParams.mouseButtonUp = false;
                    this.dynParams.mouseButtonDownCoord = cpMain;
                    currentROI = thisROIObj.getCurROIInfo();
                    if(size(currentROI,2) >= 2)
                        this.dynParams.mouseButtonDownROI = currentROI(:,2);
                    else
                        this.dynParams.mouseButtonDownCoord = [];
                    end
                    if(mLeftButton && this.getROIType(thisSide) < 6)
                        %left click
                        thisROIObj.setStartPoint(flipud(cpMain));
                    end
                else
                    return
                end
                if(mLeftButton && this.getROIType(thisSide) < 6)
                    %draw current point in both (empty cp deletes old lines)
                    this.objHandles.(sprintf('%sdo',thisSide)).drawROI(this.getROIType(thisSide),flipud(cpMain),flipud(cpMain),false);
                    this.objHandles.(sprintf('%sdo',thisSide)).drawCPMain(cpMain);
                    if(thisROIObj.ROIType == otherROIObj.ROIType && strcmp(this.getStudy(thisSide),this.getStudy(otherSide)) && strcmp(this.getSubject(thisSide),this.getSubject(otherSide)) && this.getROIDisplayMode(otherSide) == 1)
                        this.objHandles.(sprintf('%sdo',otherSide)).drawROI(this.getROIType(thisSide),flipud(cpMain),flipud(cpMain),false);
                        this.objHandles.(sprintf('%sdo',otherSide)).drawCPMain(cpMain);
                    end
                end
                return
            end
            %% supp axes
            if(isempty(cpSupp) || this.visHandles.(sprintf('supp_axes_%s_pop',thisSide)).Value ~= 2 || this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.check)
                return
            end
            switch get(hObject,'SelectionType')
                case 'normal'
                    this.dynParams.mouseButtonDown = true;
                    this.dynParams.mouseButtonUp = false;
                    this.dynParams.mouseButtonDownCoord = cpSupp;
                    this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.setLowerBorder(cpSupp(1),true);
                    this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
                    this.objHandles.(sprintf('%sdo',thisSide)).drawCPSupp(cpSupp);
                    this.objHandles.(sprintf('%sdo',otherSide)).drawCPSupp([]);
                case 'alt'
            end
        end
        
        function GUI_mouseButtonUp_Callback(this,hObject,eventdata)
            %executes on mouse button up in window
            %this function is now always called by its wrapper: rotate_mouseButtonUpWrapper
            this.dynParams.mouseButtonUp = true;
            cpMain = this.objHandles.ldo.getMyCP(1);
            thisSide = 'l';
            otherSide = 'r';
            if(isempty(cpMain))
                cpMain = this.objHandles.rdo.getMyCP(1);
                thisSide = 'r';
                otherSide = 'l';
            end
            cpSupp = [];
            if(isempty(cpMain))
                %no hit on main axes, try supp axes
                cpSupp = this.objHandles.ldo.getMyCP(2);
                thisSide = 'l';
                otherSide = 'r';
                if(isempty(cpSupp))
                    cpSupp = this.objHandles.rdo.getMyCP(2);
                    thisSide = 'r';
                    otherSide = 'l';
                end
            end
            %% cursor
            if(~isempty(cpMain) && this.getROIDisplayMode(thisSide) < 3 || ~isempty(cpSupp))
                set(this.visHandles.FLIMXVisGUIFigure,'Pointer','cross');
            elseif(isempty(cpMain) && isempty(cpSupp))
                set(this.visHandles.FLIMXVisGUIFigure,'Pointer','arrow'); 
            end
            %% main axes
            %draw mouse overlay in both main axes (empty cp deletes old overlays)
            if(this.getROIDisplayMode(thisSide) < 3)                               
                if(isempty(cpSupp) && this.getROIType(thisSide) >= 1 && get(this.visHandles.enableMouse_check,'Value'))
                    thisROIObj = this.objHandles.(sprintf('%sROI',thisSide));
                    otherROIObj = this.objHandles.(sprintf('%sROI',otherSide));
                    if(~isempty(cpMain))
                        if(strcmp('normal',get(hObject,'SelectionType')))
                            thisROIObj.setEndPoint(flipud(cpMain),true);
                        else
                            %right click
                            dTarget = int16(flipud(this.dynParams.mouseButtonDownCoord-cpMain));
                            ROICoord = thisROIObj.getCurROIInfo();
                            ROICoord = ROICoord(:,2:end);
                            dMoved = this.dynParams.mouseButtonDownROI - ROICoord(:,1);
                            thisROIObj.moveROI(dTarget-dMoved,true);
                        end
                    end
                    otherROIObj.updateGUI([]);
                    this.myStatsGroupComp.clearResults();
                    this.objHandles.rdo.updatePlots();
                    this.objHandles.ldo.updatePlots();                    
                    %draw mouse overlay on this side in main axes
                    this.objHandles.(sprintf('%sdo',thisSide)).drawCPMain(cpMain);
                    if(this.getROIDisplayMode(thisSide) == 1 && this.getROIDisplayMode(otherSide) == 1 || this.getROIDisplayMode(thisSide) == 2 && this.getROIDisplayMode(otherSide) == 2 && thisROIObj.ROIType == otherROIObj.ROIType)
                        this.objHandles.(sprintf('%sdo',otherSide)).drawCPMain(cpMain);
                    else
                        %other side displays something else, clear possible invalid mouse overlay
                        this.objHandles.(sprintf('%sdo',otherSide)).drawCPMain([]);
                    end
                    this.dynParams.mouseButtonDown = false;
                    this.dynParams.mouseButtonDownCoord = [];
                    this.dynParams.mouseButtonDownROI = [];
                end                
            end                        
            %% supp axes
            if(~isempty(cpMain) || this.visHandles.(sprintf('supp_axes_%s_pop',thisSide)).Value ~= 2)
                this.dynParams.mouseButtonUp = false;
                return
            end
            switch get(hObject,'SelectionType')
                case 'normal'
                    if(this.dynParams.mouseButtonDown)
                        if(~isempty(cpSupp))
                            %we only have a valid current point inside of axes, if mouse button is released outside, the last valid cp from mouseMotion is used
                            this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.setColorScale(int16([0 this.dynParams.mouseButtonDownCoord(1) cpSupp(1)]),true);
                        end
                        this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
                        this.dynParams.mouseButtonDownCoord = [];
                        this.dynParams.mouseButtonDown = false;
                    end
                case 'alt'                    
                    this.dynParams.mouseButtonDownCoord = [];
                    this.dynParams.mouseButtonDown = false;
                    if(~isempty(cpSupp))
                        %reset color scaling to auto only if click happened inside of axes
                        this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.forceAutoScale();                        
                    end
                    this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
            end
            this.dynParams.mouseButtonUp = false;
            this.objHandles.(sprintf('%sdo',thisSide)).drawCPSupp(cpSupp);
            this.objHandles.(sprintf('%sdo',otherSide)).drawCPSupp([]);
        end
        
        function GUI_studySet_Callback(this,hObject,eventdata)
            %select study                        
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'study_l_pop'))                
                s = 'l';            
            end
            this.setupGUI();
            this.updateGUI(s);            
            
        end
        
        function GUI_viewSet_Callback(this,hObject,eventdata)
            %select view
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'view_l_pop'))                
                s = 'l';            
            end
            this.setupGUI();
            this.updateGUI(s);             
        end
                        
        function GUI_subjectPop_Callback(this,hObject,eventdata)
            %select subject
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'dataset_l_pop'))
                s = 'l';
            end            
            this.setupGUI();
            this.updateGUI(s);
        end
        
        function GUI_subjectButton_Callback(this,hObject,eventdata)
            %switch subject
            switch get(hObject,'Tag')
                case 'dataset_l_dec_button'
                    set(this.visHandles.dataset_l_pop,'Value',max(1,get(this.visHandles.dataset_l_pop,'Value')-1));
                    s = 'l';
                case 'dataset_l_inc_button'
                    set(this.visHandles.dataset_l_pop,'Value',min(length(get(this.visHandles.dataset_l_pop,'String')),get(this.visHandles.dataset_l_pop,'Value')+1));
                    s = 'l';
                case 'dataset_r_dec_button'
                    set(this.visHandles.dataset_r_pop,'Value',max(1,get(this.visHandles.dataset_r_pop,'Value')-1));
                    s = 'r';
                case 'dataset_r_inc_button'
                    set(this.visHandles.dataset_r_pop,'Value',min(length(get(this.visHandles.dataset_r_pop,'String')),get(this.visHandles.dataset_r_pop,'Value')+1));
                    s = 'r';
                otherwise
                    return
            end
            this.setupGUI();
            this.updateGUI(s);
        end
        
        function GUI_mainAxesPop_Callback(this,hObject,eventdata)
            %select FLIMItem
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'main_axes_l_pop'))
                s = 'l';
            end                       
            this.updateGUI(s);
            this.updateColorbar();
%             this.objHandles.(sprintf('%sdo',s)).sethfdMain([]);
%             this.objHandles.(sprintf('%sROI',s)).updateGUI([]);
%             this.objHandles.(sprintf('%sdo',s)).updatePlots();       
        end
        
        function GUI_mainAxesVarPop_Callback(this,hObject,eventdata)
            %select uni- or multivariate mode
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'main_axes_var_l_pop'))
                s = 'l';
            end            
            this.setupGUI();
            this.updateGUI(s);                      
        end
        
        function GUI_mainAxesDimPop_Callback(this,hObject,eventdata)
            %select 2D overview, 2D or 3D visualization
            s = 'r';                       
            if(strcmp(get(hObject,'Tag'),'main_axes_pdim_l_pop'))
                s = 'l';
            end
            if(this.fdt.getNrSubjects(this.getStudy(s),this.getView(s)) < 1)
                return
            end            
            this.objHandles.(sprintf('%sdo',s)).updatePlots();  
            %this.updateGUI([]);
        end
        
        function GUI_mainAxesChPop_Callback(this,hObject,eventdata)
            %select channel
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'main_axes_chan_l_pop'))
                s = 'l';
            end
            this.setupGUI();
            this.updateGUI(s);
        end
        
        function GUI_mainAxesScalePop_Callback(this,hObject,eventdata)
            %select linear or log10 scaling
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'main_axes_scale_l_pop'))
                s = 'l';
            end
            this.objHandles.(sprintf('%sdo',s)).sethfdMain([]);
            this.objHandles.(sprintf('%sROI',s)).updateGUI([]);
            this.objHandles.(sprintf('%sdo',s)).updatePlots();
        end
        
        function GUI_mainAxesZoom_Callback(this,hObject,eventdata)
            %zoom
            s = 'r';
            if(strcmp(hObject.Tag,'slider_l_zoom'))
                s = 'l';
            end
            if(hObject.Value == 1)
                %reset zoom anchor if zoom level = 1
                this.objHandles.(sprintf('%sdo',s)).setZoomAnchor([]);
            end
            this.objHandles.(sprintf('%sdo',s)).makeZoom();
        end
        
        function GUI_cut_Callback(this,hObject,eventdata)
            %access cut controls
            if(this.fdt.getNrSubjects(this.getStudy('l'),this.getView('l')) < 1)
                return
            end
            ax = 'x';
            tag = get(hObject,'Tag');
            if(contains(tag,'y'))
                ax = 'y';
            end
            if(contains(tag,'edit'))
                this.objHandles.(sprintf('cut%s',ax)).editCallback();
            elseif(contains(tag,'check'))
                this.objHandles.(sprintf('cut%s',ax)).checkCallback();
            else
                this.objHandles.(sprintf('cut%s',ax)).sliderCallback();
            end
            this.objHandles.rdo.updatePlots();
            this.objHandles.ldo.updatePlots();
        end
        
        function GUI_colorScale_Callback(this,hObject,eventdata)
            %adjust the color scaling
            thisSide = 'r';
            otherSide = 'l';
            tag = get(hObject,'Tag');
            if(contains(tag,'_l_'))
                thisSide = 'l';
                otherSide = 'r';
            end
            if(contains(tag,'edit'))
                this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.editCallback();
                %this.objHandles.(sprintf('%sdo',thisSide)).updatePlots();
                if(this.objHandles.(sprintf('%sdo',thisSide)).myhfdMain{1} == this.objHandles.(sprintf('%sdo',otherSide)).myhfdMain{1})
                    this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
                end
            elseif(contains(tag,'check'))
                this.objHandles.(sprintf('%sdo',thisSide)).myColorScaleObj.checkCallback();
                if(this.objHandles.(sprintf('%sdo',thisSide)).myhfdMain{1} == this.objHandles.(sprintf('%sdo',otherSide)).myhfdMain{1})
                    this.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
                end
            elseif(contains(tag,'button'))
                if(contains(tag,'in'))
                    this.objHandles.(sprintf('%sdo',thisSide)).zoomSuppXScale('in');
                    if(this.objHandles.(sprintf('%sdo',thisSide)).myhfdMain{1} == this.objHandles.(sprintf('%sdo',otherSide)).myhfdMain{1})
                        this.objHandles.(sprintf('%sdo',otherSide)).zoomSuppXScale('in');
                    end
                else
                    this.objHandles.(sprintf('%sdo',thisSide)).zoomSuppXScale('out');
                    if(this.objHandles.(sprintf('%sdo',thisSide)).myhfdMain{1} == this.objHandles.(sprintf('%sdo',otherSide)).myhfdMain{1})
                        this.objHandles.(sprintf('%sdo',otherSide)).zoomSuppXScale('out');
                    end
                end
                return
            end
        end
        
        function GUI_roi_Callback(this,hObject,eventdata)
            %change roi size in x, y or z direction
            s1 = 'r'; %side which activated the control
            s2 = 'l'; %side we have to update to the new values
            %find side/axes
            tag = get(hObject,'Tag');
            if(contains(tag,'_l_'))
                s1 = 'l';
                s2 = 'r';
            end
            %find dimension
            if(contains(tag,'_x_'))
                dim = 'x';
            elseif(contains(tag,'_y_'))
                dim = 'y';
            else
                dim = 'z';
            end
            %lower or upper bound?
            if(contains(tag,'_lo_'))
                bnd = 'lo';
            else
                bnd = 'u';
            end
            %find control type
            if(contains(tag,'edit'))
                if(strcmp(dim,'z'))
                    this.objHandles.(sprintf('%sZScale',s1)).editCallback(dim,bnd);
                else
                    this.objHandles.(sprintf('%sROI',s1)).editCallback(dim,bnd);
                end
            elseif(length(tag) == 11 && contains(tag,'table'))
                this.objHandles.(sprintf('%sROI',s1)).tableEditCallback(eventdata);
                this.objHandles.(sprintf('%sROI',s2)).updateGUI([]);
            elseif(contains(tag,'roi_table_clearLast'))
                this.objHandles.(sprintf('%sROI',s1)).buttonClearLastCallback();
                this.objHandles.(sprintf('%sROI',s2)).updateGUI([]);
            elseif(contains(tag,'roi_table_clearAll'))
                this.objHandles.(sprintf('%sROI',s1)).buttonClearAllCallback();
                this.objHandles.(sprintf('%sROI',s2)).updateGUI([]);
            elseif(contains(tag,'button') && ~contains(tag,'roi_table_clearAll'))
                if(contains(tag,'_dec_'))
                    target = 'dec';
                else
                    target = 'inc';
                end
                if(strcmp(dim,'z'))
                    this.objHandles.(sprintf('%sZScale',s1)).buttonCallback(dim,bnd,target);
                else
                    this.objHandles.(sprintf('%sROI',s1)).buttonCallback(dim,bnd,target);
                end
            elseif(contains(tag,'popup'))
                if(contains(tag,'roi_subtype_'))
                    type = 'main';
                else
                    type = 'sub';
                end
                this.objHandles.(sprintf('%sROI',s1)).popupCallback(type);
            else %check
                this.objHandles.(sprintf('%sZScale',s1)).checkCallback(dim);
            end
            %update ROI controls on other side
            if(contains(tag,'type_'))
                this.objHandles.(sprintf('%sROI',s2)).updateGUI([]);
            else                
                if(~strcmp(dim,'z'))
                    this.objHandles.(sprintf('%sROI',s2)).updateGUI([]);
                    %update cuts only for x and y
                    this.objHandles.(sprintf('cut%s',dim)).checkCallback();
                else
                    this.objHandles.(sprintf('%sZScale',s2)).updateGUI([]);
                end
            end
            %make sure FDisplay rebuild merged statistics
            this.objHandles.ldo.sethfdSupp([]);
            this.objHandles.rdo.sethfdSupp([]);
            this.myStatsGroupComp.clearResults();
            this.objHandles.rdo.updatePlots();
            this.objHandles.ldo.updatePlots();
        end
        
        function GUI_suppAxesPop_Callback(this,hObject,eventdata)
            %select cut or histogram for supplemental display
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'supp_axes_l_pop'))
                s = 'l';
            end
            this.setupGUI();
            this.updateGUI(s);
        end
        
        function GUI_suppAxesHistPop_Callback(this,hObject,eventdata)
            %select cut or histogram for supplemental display
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'supp_axes_hist_l_pop'))
                s = 'l';
            end            
            this.updateGUI(s);
        end
        
        function GUI_suppAxesScalePop_Callback(this,hObject,eventdata)
            %select linear or log10 scaling for cuts in supplemental plot
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'supp_axes_scale_l_pop'))
                s = 'l';
            end
            this.objHandles.(sprintf('%sdo',s)).makeSuppPlot();
        end        
                
        function menuExportExcel_Callback(this,hObject,eventdata)
            %
            tag = get(hObject,'Tag');
            side = 'l';            
            if(contains(tag,'R'))
                side = 'r';
            end
            pType = 'main'; %main plot
            if(contains(tag,'B'))
                pType = 'supp'; %supp. plot
            end
            switch pType
                case 'main'
                    ex = this.objHandles.(sprintf('%sdo',side)).(sprintf('%sExportXls',pType));
                case 'supp'
                    ex = this.objHandles.(sprintf('%sdo',side)).(sprintf('%sExport',pType));
            end
            if(isempty(ex))
                return
            end
            [file,path] = uiputfile({'*.xlsx','Excel File';'*.xls','Excel 97-2003 File'},'Export Data in Excel Fileformat...');
            if ~file ; return ; end
            fn = fullfile(path,file);            
%             [y x] = size(ex);
%             if(x > y)
%                 ex = ex';
%             end
            dType = get(this.visHandles.(sprintf('main_axes_%s_pop',side)),'String');
            dType = char(dType(get(this.visHandles.(sprintf('main_axes_%s_pop',side)),'Value'),:));
            if(strcmp(pType,'supp'))
                eType = get(this.visHandles.(sprintf('supp_axes_%s_pop',side)),'String');
                eType = char(eType(get(this.visHandles.(sprintf('supp_axes_%s_pop',side)),'Value'),:));
                sheetName = [dType '_' eType];
            else
                sheetName = dType;
            end
            exportExcel(fn,double(ex),'','',sheetName,'');
        end
        
        function GUI_intOverlay_Callback(this,hObject,eventdata)
            %
            s = 'l';                     
            %find side/axes
            tag = get(hObject,'Tag');
            if(~contains(tag,'_l_'))
                s = 'r';
            end     
            if(this.fdt.getNrSubjects(this.getStudy(s),this.getView(s)) < 1)
                return
            end
            %check if button was pressed
            if(contains(tag,'_button'))
                if(contains(tag,'_dec_'))
                    %decrease brightness
                    set(this.visHandles.(sprintf('IO_%s_edit',s)),'String',...
                        num2str(max(str2double(get(this.visHandles.(sprintf('IO_%s_edit',s)),'String'))-0.1,0)));
                else
                    %increase brightness
                    set(this.visHandles.(sprintf('IO_%s_edit',s)),'String',...
                        num2str(min(str2double(get(this.visHandles.(sprintf('IO_%s_edit',s)),'String'))+0.1,1)));
                end
            end
            this.objHandles.(sprintf('%sdo',s)).sethfdMain([]); %for log10 scaling
            this.objHandles.(sprintf('%sdo',s)).updatePlots();
        end 
        
        function GUI_viewColorSelection_Callback(this,hObject,eventdata)
            %change study color
            s = 'l';
            if(~strcmp(sprintf('study_color_%s_button',s),get(hObject,'Tag')))
                s = 'r';
            end
            cs = GUI_Colorselection(this.fdt.getViewColor(this.getStudy(s),this.getView(s)));
            if(length(cs) == 3)
                %set new color
                this.fdt.setViewColor(this.getStudy(s),this.getView(s),cs);
                this.setupGUI();
                this.updateGUI([]);
            end
        end
        
        
    end %methods
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            %make a window for visualization of current fit
            switch this.generalParams.windowSize
                case 1                    
                    this.visHandles = FLIMXVisGUIFigureMedium();
                case 2
                     this.visHandles = FLIMXVisGUIFigureSmall();
                case 3
                    this.visHandles = FLIMXVisGUIFigureLarge();
            end
            figure(this.visHandles.FLIMXVisGUIFigure);
            %set callbacks
            set(this.visHandles.FLIMXVisGUIFigure,'Units','Pixels');
            %popups
            set(this.visHandles.enableMouse_check,'Callback',@this.GUI_enableMouseCheck_Callback,'Value',0,'String','enable ROI definition');
            set(this.visHandles.sync3DViews_check,'Callback',@this.GUI_sync3DViews_check_Callback,'Value',0);
            %main axes
            set(this.visHandles.dataset_l_pop,'Callback',@this.GUI_subjectPop_Callback,'TooltipString','Select current subject of the left side');
            set(this.visHandles.dataset_r_pop,'Callback',@this.GUI_subjectPop_Callback,'TooltipString','Select current subject of the right side');
            set(this.visHandles.dataset_l_dec_button,'FontName','Symbol','String',char(173),'Callback',@this.GUI_subjectButton_Callback,'TooltipString','Switch to previous subject on the left side');
            set(this.visHandles.dataset_l_inc_button,'FontName','Symbol','String',char(175),'Callback',@this.GUI_subjectButton_Callback,'TooltipString','Switch to next subject on the left side');
            set(this.visHandles.dataset_r_dec_button,'FontName','Symbol','String',char(173),'Callback',@this.GUI_subjectButton_Callback,'TooltipString','Switch to previous subject on the right side');
            set(this.visHandles.dataset_r_inc_button,'FontName','Symbol','String',char(175),'Callback',@this.GUI_subjectButton_Callback,'TooltipString','Switch to next subject on the right side');
            set(this.visHandles.main_axes_l_pop,'Callback',@this.GUI_mainAxesPop_Callback,'TooltipString','Select FLIM parameter to display on the left side');
            set(this.visHandles.main_axes_r_pop,'Callback',@this.GUI_mainAxesPop_Callback,'TooltipString','Select FLIM parameter to display on the right side');
            set(this.visHandles.main_axes_var_l_pop,'Callback',@this.GUI_mainAxesVarPop_Callback,'TooltipString','Display one or multiple FLIM parameters on the left side');
            set(this.visHandles.main_axes_var_r_pop,'Callback',@this.GUI_mainAxesVarPop_Callback,'TooltipString','Display one or multiple FLIM parameters on the right side');
            set(this.visHandles.main_axes_pdim_l_pop,'Callback',@this.GUI_mainAxesDimPop_Callback,'TooltipString','Show the whole image in 2D or only the ROI in 2D and 3D respectively on the left side');
            set(this.visHandles.main_axes_pdim_r_pop,'Callback',@this.GUI_mainAxesDimPop_Callback,'TooltipString','Show the whole image in 2D or only the ROI in 2D and 3D respectively on the right side');
            set(this.visHandles.main_axes_chan_l_pop,'Callback',@this.GUI_mainAxesChPop_Callback,'TooltipString','Switch the spectral channel on the left side');
            set(this.visHandles.main_axes_chan_r_pop,'Callback',@this.GUI_mainAxesChPop_Callback,'TooltipString','Switch the spectral channel on the right side');
            set(this.visHandles.main_axes_scale_l_pop,'Callback',@this.GUI_mainAxesScalePop_Callback,'Enable','off','Value',1,'TooltipString','Select linear or log10 scaling of the FLIM parameter on the left side');
            set(this.visHandles.main_axes_scale_r_pop,'Callback',@this.GUI_mainAxesScalePop_Callback,'Enable','off','Value',1,'TooltipString','Select linear or log10 scaling of the FLIM parameter on the right side');
            set(this.visHandles.slider_l_zoom,'Callback',@this.GUI_mainAxesZoom_Callback,'TooltipString','Zoom left side');
            set(this.visHandles.slider_r_zoom,'Callback',@this.GUI_mainAxesZoom_Callback,'TooltipString','Zoom right side');
            %supp axes
            set(this.visHandles.supp_axes_l_pop,'Callback',@this.GUI_suppAxesPop_Callback,'TooltipString','Show histogram or cross-section for current subject','Value',2);
            set(this.visHandles.supp_axes_r_pop,'Callback',@this.GUI_suppAxesPop_Callback,'TooltipString','Show histogram or cross-section for current subject','Value',2);
            set(this.visHandles.supp_axes_hist_l_pop,'Callback',@this.GUI_suppAxesHistPop_Callback,'TooltipString','Show histogram for current subject or current study / condition');
            set(this.visHandles.supp_axes_hist_r_pop,'Callback',@this.GUI_suppAxesHistPop_Callback,'TooltipString','Show histogram for current subject or current study / condition');
            set(this.visHandles.supp_axes_scale_l_pop,'Callback',@this.GUI_suppAxesScalePop_Callback,'TooltipString','Select linear or log10 scaling for cross-section');
            set(this.visHandles.supp_axes_scale_r_pop,'Callback',@this.GUI_suppAxesScalePop_Callback,'TooltipString','Select linear or log10 scaling for cross-section');
            %cuts
            set(this.visHandles.cut_x_l_check,'Callback',@this.GUI_cut_Callback,'TooltipString','Enable or disable the vertical cross-section');
            set(this.visHandles.cut_y_l_check,'Callback',@this.GUI_cut_Callback,'TooltipString','Enable or disable the horizontal cross-section');
            set(this.visHandles.cut_y_l_slider,'Callback',@this.GUI_cut_Callback,'TooltipString','Move horizontal cross-section');
            set(this.visHandles.cut_x_l_slider,'Callback',@this.GUI_cut_Callback,'TooltipString','Move vertical cross-section');
            set(this.visHandles.cut_y_l_edit,'Callback',@this.GUI_cut_Callback,'TooltipString','Enter position in pixels for horizontal cross-section');
            set(this.visHandles.cut_x_l_edit,'Callback',@this.GUI_cut_Callback,'TooltipString','Enter position in pixels for vertical cross-section');
            set(this.visHandles.cut_x_inv_check,'Callback',@this.GUI_cut_Callback,'TooltipString','Toggle which side of the cross-section is cut off (3D plot only)');
            set(this.visHandles.cut_y_inv_check,'Callback',@this.GUI_cut_Callback,'TooltipString','Toggle which side of the cross-section is cut off (3D plot only)');
            %ROI controls and z scaling
            dims =['x','y','z'];
            axs = ['l','r'];
            for j = 1:2
                ax = axs(j);
                for i=1:3
                    dim = dims(i);
                    set(this.visHandles.(sprintf('ms_%s_%s_lo_dec_button',ax,dim)),'Callback',@this.GUI_roi_Callback,'TooltipString',sprintf('Decrease %s-value',dim));
                    set(this.visHandles.(sprintf('ms_%s_%s_lo_inc_button',ax,dim)),'Callback',@this.GUI_roi_Callback,'TooltipString',sprintf('Increase %s-value',dim));
                    set(this.visHandles.(sprintf('ms_%s_%s_lo_edit',ax,dim)),'Callback',@this.GUI_roi_Callback,'TooltipString',sprintf('Enter %s-value',dim));
                    set(this.visHandles.(sprintf('ms_%s_%s_u_dec_button',ax,dim)),'Callback',@this.GUI_roi_Callback,'TooltipString',sprintf('Decrease %s-value',dim));
                    set(this.visHandles.(sprintf('ms_%s_%s_u_inc_button',ax,dim)),'Callback',@this.GUI_roi_Callback,'TooltipString',sprintf('Increase %s-value',dim));
                    set(this.visHandles.(sprintf('ms_%s_%s_u_edit',ax,dim)),'Callback',@this.GUI_roi_Callback,'TooltipString',sprintf('Enter %s-value',dim));
                end
                set(this.visHandles.(sprintf('ms_%s_z_check',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Enable or disable z scaling');
                set(this.visHandles.(sprintf('roi_type_%s_popup',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Select ROI type');
                set(this.visHandles.(sprintf('roi_subtype_%s_popup',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Select subfield of ETDRS grid');
                set(this.visHandles.(sprintf('roi_%s_table',ax)),'CellEditCallback',@this.GUI_roi_Callback);
                set(this.visHandles.(sprintf('roi_table_clearLast_%s_button',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Clear last node of current polygon ROI');
                set(this.visHandles.(sprintf('roi_table_clearAll_%s_button',ax)),'Callback',@this.GUI_roi_Callback,'TooltipString','Clear all nodes of current polygon ROI');
                %color scaling controls
                set(this.visHandles.(sprintf('colormap_auto_%s_check',ax)),'Callback',@this.GUI_colorScale_Callback,'TooltipString','Enable or disable automatic color scaling');
                set(this.visHandles.(sprintf('colormap_low_%s_edit',ax)),'Callback',@this.GUI_colorScale_Callback,'TooltipString','Enter lower border for color scaling');
                set(this.visHandles.(sprintf('colormap_high_%s_edit',ax)),'Callback',@this.GUI_colorScale_Callback,'TooltipString','Enter upper border for color scaling');
                set(this.visHandles.(sprintf('colormap_zoom_in_%s_button',ax)),'Callback',@this.GUI_colorScale_Callback,'TooltipString','Zoom into histogram');
                set(this.visHandles.(sprintf('colormap_zoom_out_%s_button',ax)),'Callback',@this.GUI_colorScale_Callback,'TooltipString','Zoom out of histogram');
            end
            %menu
            set(this.visHandles.menuExit,'Callback',@this.menuExit_Callback);
            set(this.visHandles.FLIMXVisGUIFigure,'CloseRequestFcn',@this.menuExit_Callback);
            set(this.visHandles.menuFilterOptions,'Callback',@this.menuFiltOpt_Callback);
            set(this.visHandles.menuStatisticsOptions,'Callback',@this.menuStatOpt_Callback);
            set(this.visHandles.menuVisualzationOptions,'Callback',@this.menuVisOpt_Callback);
            set(this.visHandles.menuExportOptions,'Callback',@this.menuExpOpt_Callback);
            set(this.visHandles.menuDescriptive,'Callback',@this.menuDescriptive_Callback);
            set(this.visHandles.menuHolmWilcoxon,'Callback',@this.menuHolmWilcoxon_Callback);
            set(this.visHandles.menuClustering,'Callback',@this.menuClustering_Callback);
            set(this.visHandles.menuOpenStudyMgr,'Callback',@this.menuOpenStudyMgr_Callback);
            set(this.visHandles.menuSSTL,'Callback',@this.menuScreenshot_Callback);
            set(this.visHandles.menuSSTR,'Callback',@this.menuScreenshot_Callback);
            set(this.visHandles.menuSSBL,'Callback',@this.menuScreenshot_Callback);
            set(this.visHandles.menuSSBR,'Callback',@this.menuScreenshot_Callback);
            set(this.visHandles.menuMovie,'Callback',@this.menuExportMovie_Callback);
            set(this.visHandles.menuXlsTL,'Callback',@this.menuExportExcel_Callback);
            set(this.visHandles.menuXlsTR,'Callback',@this.menuExportExcel_Callback);
            set(this.visHandles.menuXlsBL,'Callback',@this.menuExportExcel_Callback);
            set(this.visHandles.menuXlsBR,'Callback',@this.menuExportExcel_Callback);
            set(this.visHandles.menuOpenFLIMXFit,'Callback',@this.menuOpenFLIMXFit_Callback);
            set(this.visHandles.menuAbout,'Callback',@this.menuAbout_Callback);
            %intensity overlay
            set(this.visHandles.IO_l_check,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Enable or disable overlay of the intensity image on the left side');
            set(this.visHandles.IO_r_check,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Enable or disable overlay of the intensity image on the right side');
            set(this.visHandles.IO_l_dec_button,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Decrease brightness of intensity overlay on the left side');
            set(this.visHandles.IO_r_dec_button,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Decrease brightness of intensity overlay on the right side');
            set(this.visHandles.IO_l_inc_button,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Increase brightness of intensity overlay on the left side');
            set(this.visHandles.IO_r_inc_button,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Increase brightness of intensity overlay on the right side');
            set(this.visHandles.IO_l_edit,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Enter brightness value for the intensity overlay on the left side (0: dark; 1: bright)');
            set(this.visHandles.IO_r_edit,'Callback',@this.GUI_intOverlay_Callback,'TooltipString','Enter brightness value for the intensity overlay on the right side (0: dark; 1: bright)');
            %setup study controls
            set(this.visHandles.study_l_pop,'Callback',@this.GUI_studySet_Callback,'TooltipString','Select current study for the left side');
            set(this.visHandles.study_r_pop,'Callback',@this.GUI_studySet_Callback,'TooltipString','Select current study for the right side');
            set(this.visHandles.view_l_pop,'Callback',@this.GUI_viewSet_Callback,'TooltipString','Select current condition for the current study on left side');
            set(this.visHandles.view_r_pop,'Callback',@this.GUI_viewSet_Callback,'TooltipString','Select current condition for the current study on right side');
            %study color selection
            set(this.visHandles.study_color_l_button,'Callback',@this.GUI_viewColorSelection_Callback,'TooltipString','Set color for current condition on the left side (only for scatter plots)');
            set(this.visHandles.study_color_r_button,'Callback',@this.GUI_viewColorSelection_Callback,'TooltipString','Set color for current condition on the right side (only for scatter plots)');
            %progress bars
            set(this.visHandles.cancel_button,'Callback',@this.GUI_cancelButton_Callback,'TooltipString','Stop current operation');
            xpatch = [0 0 0 0];
            ypatch = [0 0 1 1];
            axis(this.visHandles.short_progress_axes ,'off');
            xlim(this.visHandles.short_progress_axes,[0 100]);
            ylim(this.visHandles.short_progress_axes,[0 1]);
            this.visHandles.patch_short_progress = patch(xpatch,ypatch,'m','EdgeColor','m','Parent',this.visHandles.short_progress_axes);%,'EraseMode','normal'
            this.visHandles.text_short_progress = text(1,0,'','Parent',this.visHandles.short_progress_axes);
            axis(this.visHandles.long_progress_axes ,'off');
            xlim(this.visHandles.long_progress_axes,[0 100]);
            ylim(this.visHandles.long_progress_axes,[0 1]);
            this.visHandles.patch_long_progress = patch(xpatch,ypatch,'r','EdgeColor','r','Parent',this.visHandles.long_progress_axes);%,'EraseMode','normal'
            this.visHandles.text_long_progress = text(1,0,'','Parent',this.visHandles.long_progress_axes);
            %init ui control objects
            this.objHandles.ldo = FDisplay(this,'l');
            this.objHandles.rdo = FDisplay(this,'r');
            this.objHandles.cutx = CutCtrl(this,'x',this.objHandles.ldo,this.objHandles.rdo);
            this.objHandles.cuty = CutCtrl(this,'y',this.objHandles.ldo,this.objHandles.rdo);
            this.objHandles.lROI = ROICtrl(this,'l',this.objHandles.ldo,this.objHandles.rdo);
            this.objHandles.rROI = ROICtrl(this,'r',this.objHandles.ldo,this.objHandles.rdo);
            this.objHandles.lZScale = ZCtrl(this,'l',this.objHandles.ldo,this.objHandles.rdo);
            this.objHandles.rZScale = ZCtrl(this,'r',this.objHandles.ldo,this.objHandles.rdo);
            this.objHandles.AI = AICtrl(this); %arithmetic image
            this.objHandles.movObj = exportMovie(this);
            this.clearAxes([]);
            this.setupPopUps([]);
            this.visHandles.hrotate3d = rotate3d(this.visHandles.FLIMXVisGUIFigure);
            set(this.visHandles.hrotate3d,'Enable','on','ActionPostCallback',{@FLIMXVisGUI.rotate_postCallback,this});
            setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.main_l_axes,false);
            this.setupGUI();
            this.updateGUI([]);
            this.objHandles.ldo.drawCPMain([]);
            this.objHandles.rdo.drawCPMain([]);
            this.objHandles.lZScale.updateGUI([]);
            this.objHandles.rZScale.updateGUI([]);
            set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback);
            %enable mouse button callbacks although 3d rotation is enabled
            %thanks to http://undocumentedmatlab.com/blog/enabling-user-callbacks-during-zoom-pan
            hManager = uigetmodemanager(this.visHandles.FLIMXVisGUIFigure);
            try
                set(hManager.WindowListenerHandles, 'Enable', 'off');  % HG1
            catch
                [hManager.WindowListenerHandles.Enabled] = deal(false);  % HG2
            end
            set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonDownFcn',{@FLIMXVisGUI.rotate_mouseButtonDownWrapper,this});
            set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonUpFcn',{@FLIMXVisGUI.rotate_mouseButtonUpWrapper,this});
            set(this.visHandles.FLIMXVisGUIFigure,'WindowScrollWheelFcn',@this.GUI_mouseScrollWheel_Callback);
            setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.short_progress_axes,false);
            setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.long_progress_axes,false);
        end
    end %methods protected
    
    methods(Static)
        function [dType, dTypeNr] = FLIMItem2TypeAndID(dType)
            %convert FLIMItem 'Amplitude 1' to 'Amplitude' and 1
            dType = deblank(char(dType));
            %find whitespace
            idx = isstrprop(dType, 'wspace');
            if(any(idx))
                idx = find(idx,1,'last');
                dTypeNr = str2double(dType(idx:end));
                dType = {dType(1:idx-1)};
            else
                dTypeNr = 0;
                dType = {dType};
            end
        end
        
        function rotate_mouseButtonDownWrapper(hObject, eventdata, hFLIMXVis)
            %wrapper for mouse button down funtion in rotate3d mode
            hFLIMXVis.GUI_mouseButtonDown_Callback(hObject, eventdata);
            %now run hrotate3d callback
            %rdata = getuimode(hFig,'Exploration.Rotate3d');
            hManager = uigetmodemanager(hObject);
            try
                hManager.CurrentMode.WindowButtonDownFcn(hObject,eventdata);
            catch
                return
            end
            %hrotate3d callback set the button up function to empty
            try
                set(hManager.WindowListenerHandles, 'Enable', 'off');  % HG1
            catch
                [hManager.WindowListenerHandles.Enabled] = deal(false);  % HG2
            end
            set(hObject,'WindowButtonUpFcn',{@FLIMXVisGUI.rotate_mouseButtonUpWrapper,hFLIMXVis});
        end
        
        function rotate_mouseButtonUpWrapper(hObject, eventdata, hFLIMXVis)
            %wrapper for mouse button up funtion in rotate3d mode
            hFLIMXVis.GUI_mouseButtonUp_Callback(hObject, eventdata);
            %in case of 3d roation, we have to call the button up function to stop rotating
            hManager = uigetmodemanager(hObject);
            if(~isempty(hManager.CurrentMode.WindowButtonUpFcn))
                hManager.CurrentMode.WindowButtonUpFcn(hObject,eventdata);
            end
        end
        
        function rotate_postCallback(hObject, eventdata, hFLIMXVis)
            %after rotation we may have to update the axis labels
            if(eventdata.Axes == hFLIMXVis.visHandles.main_l_axes)
                side = 'l';
                otherSide = 'r';
            else
                side = 'r';
                otherSide = 'l';
            end
            hFLIMXVis.objHandles.(sprintf('%sdo',side)).setDispView(get(eventdata.Axes,'View'));
            if(get(hFLIMXVis.visHandles.sync3DViews_check,'Value'))
                hFLIMXVis.objHandles.(sprintf('%sdo',otherSide)).setDispView(get(eventdata.Axes,'View'));
                hFLIMXVis.objHandles.(sprintf('%sdo',otherSide)).updatePlots();
            end
        end
    end  %methods(Static)  
end %classdef
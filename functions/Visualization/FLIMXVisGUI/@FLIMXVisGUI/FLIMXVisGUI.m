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
            this.dynParams.lastScreenshotFile = 'image.png';
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
            %setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.(sprintf('main_%s_axes',s)),true);
            axis(this.visHandles.(sprintf('main_%s_axes',s)),'off');
            cla(this.visHandles.(sprintf('supp_%s_axes',s)));
            %setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.(sprintf('supp_%s_axes',s)),false);
            axis(this.visHandles.(sprintf('supp_%s_axes',s)),'off');
            cla(this.visHandles.cm_axes);
            %setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.cm_axes,false);
            axis(this.visHandles.cm_axes ,'off');
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
                this.dynParams.cmIntensity = flipud(this.dynVisParams.cmIntensity);
            end
            colormap(this.visHandles.cm_axes,this.dynParams.cm);
            for j = 1:length(side)                
                s = side(j);                      
                curStudy = this.getStudy(s); %current study name and index  
                curStudyIdx = find(strcmp(curStudy,studies),1);
                if(isempty(curStudyIdx) || curStudyIdx ~= get(this.visHandles.(sprintf('study_%s_pop',s)),'Value'))
                    set(this.visHandles.(sprintf('study_%s_pop',s)),'Value',min(get(this.visHandles.(sprintf('study_%s_pop',s)),'Value'),length(studies)),'String',studies);                    
                else
                    set(this.visHandles.(sprintf('study_%s_pop',s)),'String',studies,'Value',curStudyIdx);
                end    
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
                    set(this.visHandles.(sprintf('dataset_%s_pop',s)),'String',dStr,'Value',...
                    min(get(this.visHandles.(sprintf('dataset_%s_pop',s)),'Value'),nrSubs));
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
                    switch get(this.visHandles.(sprintf('main_axes_var_%s_pop',s)),'Value');
                        case 1 %univariate
                            %add cluster objects to channel object string
                            chObj = unique([chObj;MVGroupNames]);
                            set(this.visHandles.(sprintf('dataset_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('dataset_%s_dec_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('dataset_%s_inc_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('main_axes_pdim_%s_pop',s)),'Enable','on');
%                             set(this.visHandles.(sprintf('parasel_%s_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('study_color_%s_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('study_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('view_%s_pop',s)),'Visible','on');
                        case 2 %multivariate
                            chObj = MVGroupNames;
                            set(this.visHandles.(sprintf('dataset_%s_pop',s)),'Visible','on');
                            set(this.visHandles.(sprintf('dataset_%s_dec_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('dataset_%s_inc_button',s)),'Visible','on');
                            set(this.visHandles.(sprintf('main_axes_pdim_%s_pop',s)),'Enable','off','Value',3);
%                             set(this.visHandles.(sprintf('parasel_%s_button',s)),'Visible','off');
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
%                             set(this.visHandles.(sprintf('parasel_%s_button',s)),'Visible','off');
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
%                                 set(this.visHandles.(sprintf('parasel_%s_button',s)),'Visible','on');
                                set(this.visHandles.(sprintf('study_color_%s_button',s)),'Visible','on');
                                set(this.visHandles.(sprintf('study_%s_pop',s)),'Visible','on');
                                set(this.visHandles.(sprintf('view_%s_pop',s)),'Visible','on');
                            else
                                chObj = globalMVGroupNames;
                                set(this.visHandles.(sprintf('dataset_%s_pop',s)),'Visible','off');
                                set(this.visHandles.(sprintf('dataset_%s_dec_button',s)),'Visible','off');
                                set(this.visHandles.(sprintf('dataset_%s_inc_button',s)),'Visible','off');
%                                 set(this.visHandles.(sprintf('remove_ds_%s_button',s)),'Visible','off');
%                                 set(this.visHandles.(sprintf('parasel_%s_button',s)),'Visible','off');
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
                    else %none, cuts
                        set(this.visHandles.(sprintf('supp_axes_hist_%s_pop',s)),'Visible','off');
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
                if(isempty(this.fdt.getViewColor(curStudy,curView)))
                    newColor = studyIS.makeRndColor();
                    set(this.visHandles.(sprintf('study_color_%s_button',s)),'Backgroundcolor',newColor);
                    this.fdt.setViewColor(curStudy,curView,newColor);
                end                
                set(this.visHandles.(sprintf('study_color_%s_button',s)),'Backgroundcolor',this.fdt.getViewColor(curStudy,curView));
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
                if(strcmp(s,'l'))
                    %update cuts
                    this.objHandles.cutx.updateCtrls();
                    this.objHandles.cuty.updateCtrls();
                end
                switch get(this.visHandles.(sprintf('supp_axes_%s_pop',s)),'Value');
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
          
        function success = importResult(this,rs,opt)
            %import a FLIMXFit result (optional: from structure)   
            %todo: move this function to study manager so we don't need the FLIMVis GUI anymore
            this.checkVisWnd(); %we need the GUI
            if(nargin < 2)
                rs = [];
            end
            if(isempty(rs))
                fileImport = true;
                %get initial values from GUI
                subjectName = this.getSubject('l');
                ch = this.getChannel('l');
            else
                fileImport = false;
                subjectName = rs.name;
                ch = rs.channel;
            end
            if(nargin < 3)                
                studyName = this.getStudy('l');
                if(isempty(subjectName))
                    subjectName = 'subject01';
                end
                if(isempty(ch))
                    ch = 1;
                end
                opt.parent = 'FLIMXVisGUI';
                opt.studyList = this.fdt.getStudyNames();
                opt.studyName = studyName;
                opt.subName = subjectName;
                opt.mode = 1;
                opt.ch = ch;
                [~, opt.chList] = this.fdt.getChStr(studyName,subjectName);
                opt.fdt = this.fdt;
                fi = measurementFile.getDefaultFileInfo();
                opt.position = fi.position;
                opt.pixelResolution = fi.pixelResolution;
            end       
            while(true)  
                success = false;
                %open GUI dialog to select study for new result
                opt.ch = ch;
                %opt.chList = {ch-1};    %last added channel
                opt = GUI_channelImport(opt);
                if(isempty(opt))
                    return
                else
                    studyName = opt.studyName;
                    subjectName = opt.subName;
                end
                %check if channel number exceeds IRF channel number
                if(fileImport) %we don't need an IRF we have a result structure (amplitues are already in photons)
                    if(opt.ch > this.FLIMXObj.irfMgr.getSpectralChNrs([],'',[]))
                        choice = questdlg('Channel number exceeds number of IRF channels! Select another Channel?','Error importing Channel','Yes','No','Yes');
                        switch choice
                            case 'Yes'
                                continue
                            case 'No'
                                return
                        end
                    end      
                    %get import subject
                    is = this.fdt.getSubject4Import(studyName,subjectName);
                    if(isempty(is))
                        return
                    end
                    pause(1);
                    [files, path, filterindex] = uigetfile( ...
                        {'*.asc','ASCII files [SPCImage >= 3.97] (*.asc)';
                        '*.dat;*.txt','Text files [SPCImage < 3.97] (*.dat,*.txt)';
                        '*.mat','FLIMFit result files (*.mat)'}, ...
                        sprintf('Select fitting results for subject %s channel %d...',subjectName,ch), ...
                        'MultiSelect', 'on',this.dynParams.lastPath);
                    if(~path)
                        %lastPath = '';
                        return
                    end
                    lastPath = path;
                    idx = strfind(lastPath,filesep);
                    if(length(idx) > 1)
                        lastPath = lastPath(1:idx(end-1));
                    end                    
                    is.importResult(fullfile(path,files),filterindex,opt.ch,opt.position,opt.pixelResolution)
                    this.dynParams.lastPath = lastPath;
                else
                    %update subject name
                    rs.name = subjectName;
                end
                switch opt.mode
                    case 0
                        %skip subject
                        return
                    case 1
                        %add new channel
                    case 2
                        %overwrite selected channel
                        %opt.ch = opt.chList{opt.ch};
                        choice = questdlg(sprintf('This will delete channel %d for subject ''%s''! \n\nContinue?',opt.ch,subjectName),'Overwrite channel?','Yes','No','Yes');
                        switch choice
                            case 'Yes'
                                this.fdt.removeChannel(studyName,subjectName,opt.ch);
                            case 'No'
                                return
                        end
                    case 3
                        %clear data and add new channel
                        choice = questdlg(sprintf('This will delete all existing channels for subject ''%s''! \n\nContinue?',subjectName),'Clear subject files?','Yes','No','Yes');
                        switch choice
                            case 'Yes'
                                this.fdt.removeChannel(studyName,subjectName,[]);
                                this.fdt.clearSubjectFiles(studyName,subjectName);
                            case 'No'
                                return
                        end
                end
%                 %get FLIMitems
%                 items = GUI_paramImportSelection(sort(removeNonVisItems(fieldnames(rs.result.pixel))),[]);
%                 if(isempty(items))
%                     return
%                 end 
%                 %import results                
%                 this.fdt.importResultStruct(studyName,subjectName,rs,items); 
                %update GUI
                this.setupGUI();
                this.updateGUI([]);
                success = true;
                if(fileImport)
                    choice = questdlg(sprintf('Import another Channel to subject ''%s?''',subjectName),'Import next Channel?','Yes','No','Yes');
                else
                    break
                end
                switch choice
                    case 'No'
                        break
                end
                ch = ch+1;
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
        function menuImport_Callback(this,hObject,eventdata)
            %import approximation result(s)
            this.importResult([]);
        end
                
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
            if(~isempty(strfind(tag,'R')))
                side = 'r';
            end
            pType = 'main'; %main plot
            if(~isempty(strfind(tag,'B')))
                pType = 'supp'; %supp. plot
            end
            [pathstr,name,ext] = fileparts(this.dynParams.lastScreenshotFile);
            formats = {'*.png','Portable Network Graphics (*.png)';...
                '*.jpg','Joint Photographic Experts Group (*.jpg)';...
                '*.eps','Encapsulated Postscript (*.eps)';...
                '*.tiff','TaggedImage File Format (*.tiff)';...
                '*.bmp','Windows Bitmap (*.bmp)';...
                '*.emf','Windows Enhanced Metafile (*.emf)';...
                '*.pdf','Portable Document Format (*.pdf)';...
                '*.fig','MATLAB figure (*.fig)';...
                };
            idx = strcmp(formats(:,1),['*' ext]);
            if(any(idx))
                fn = cell(size(formats));
                fn(1,:) = formats(idx,:);
                fn(2:end,:) = formats(~idx,:);
                formats = fn;
                clear fn
            end
            [file, path, filterindex] = uiputfile(formats,'Export Screenshot as',this.dynParams.lastScreenshotFile);
            if ~path ; return ; end
            fn = fullfile(path,file);
            this.dynParams.lastScreenshotFile = file;
            switch formats{filterindex,1}
                case '*.bmp'
                    str = '-dbmp';
                case '*.emf'
                    str = '-dmeta';
                case '*.eps'
                    str = '-depsc2';
                case '*.jpg'
                    str = '-djpeg';
                case '*.pdf'
                    str = '-dpdf';
                case '*.png'
                    str = '-dpng';
                case '*.tiff'
                    str = '-dtiff';
                case '*.fig'
                    str = '*.fig';
            end            
            hFig = figure;
            set(hFig,'Renderer','Painters');
            ssObj = FScreenshot(this.objHandles.(sprintf('%sdo',side)));
            ssObj.makeScreenshotPlot(hFig,pType);
            %pause(1) %workaround for wrong painting            
            if(strcmp(str,'*.fig'))
                savefig(hFig,fn);
            else
                print(hFig,str,['-r' num2str(this.exportParams.dpi)],fn);
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
            switch get(hObject,'Value')
                case 0
                    set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonDown','');
                    set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonUpFcn','');
                    set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback);
                    set(this.visHandles.hrotate3d,'Enable','on','ActionPostCallback',{@FLIMXVisGUI.rotate_postCallback,this});
                case 1
                    set(this.visHandles.hrotate3d,'Enable','off','ActionPostCallback',{@FLIMXVisGUI.rotate_postCallback,this});
                    set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonDown',@this.GUI_mouseButtonDown_Callback);
                    set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonUpFcn',@this.GUI_mouseButtonUp_Callback);
                    set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback);
            end
        end
        
        function GUI_sync3DViews_check_Callback(this,hObject,eventdata)
            %en/dis-able synchronization of 3D views
            %left side leads
            this.objHandles.rdo.setDispView(this.objHandles.ldo.getDispView());
            this.objHandles.rdo.updatePlots();            
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
            if ~isempty(lastUpdate) && tNow - lastUpdate < 0.010*oneSec
                inFunction = [];  %enable callback
                return;
            end
            lastUpdate = tNow;
            cp = this.objHandles.ldo.getMyCP();
            thisSide = 'l'; %this side
            otherSide = 'r'; %other side
            if(isempty(cp))
                cp = this.objHandles.rdo.getMyCP();
                thisSide = 'r';
                otherSide = 'l';
            end            
            %draw current point in both (empty cp deletes old lines)
            this.objHandles.ldo.drawCP(cp);
            this.objHandles.rdo.drawCP(cp);
            if(isempty(cp))
                if(this.getROIDisplayMode(thisSide) < 3)
                    set(this.visHandles.FLIMXVisGUIFigure,'Pointer','arrow');
                end
                inFunction = []; %enable callback
                return
            end
            if(~isempty(cp) && this.getROIDisplayMode(thisSide) < 3)
                set(this.visHandles.FLIMXVisGUIFigure,'Pointer','cross');
                if(this.dynParams.mouseButtonDown)% && this.getROIType(s) == 2)
                    this.objHandles.(sprintf('%sdo',thisSide)).drawROI(this.getROIType(thisSide),flipud(this.dynParams.mouseButtonDownCoord),flipud(cp),false);
                    if(strcmp(this.getStudy(thisSide),this.getStudy(otherSide)) && strcmp(this.getSubject(thisSide),this.getSubject(otherSide)) && this.getROIDisplayMode(otherSide) == 1)
                        this.objHandles.(sprintf('%sdo',otherSide)).drawROI(this.getROIType(thisSide),flipud(this.dynParams.mouseButtonDownCoord),flipud(cp),false);
                    end
                    %this.objHandles.rdo.drawROI(this.getROIType(tS),flipud(cp),flipud(this.dynParams.mouseButtonDownCoord),false);
                    if(this.getROIType(thisSide) >= 1 && this.getROIType(thisSide) < 6)
                        this.objHandles.(sprintf('%sROI',thisSide)).setEndPoint(flipud(cp),false);
                    end
                end
            end 
            inFunction = []; %enable callback
        end
        
        function GUI_mouseButtonDown_Callback(this,hObject,eventdata)
            %executes on mouse button down in window
            cp = this.objHandles.ldo.getMyCP();
            thisSide = 'l';
            otherSide = 'r';
            if(isempty(cp))
                cp = this.objHandles.rdo.getMyCP();
                thisSide = 'r';
                otherSide = 'l';
            end
            if(this.getROIType(thisSide) < 1)
                return
            end            
            if(isempty(cp))
                %set(this.visHandles.FLIMXVisGUIFigure,'Pointer','arrow');
            elseif(this.getROIDisplayMode(thisSide) < 3 && this.getROIType(thisSide) >= 1 && this.getROIType(thisSide) < 6)
                this.dynParams.mouseButtonDown = true;
                this.dynParams.mouseButtonDownCoord = cp;
                set(this.visHandles.FLIMXVisGUIFigure,'Pointer','cross');
                if(get(this.visHandles.enableMouse_check,'Value'))
                    this.objHandles.(sprintf('%sROI',thisSide)).setStartPoint(flipud(cp));
                end
            else
                return
            end
            %draw current point in both (empty cp deletes old lines)
            this.objHandles.(sprintf('%sdo',thisSide)).drawROI(this.getROIType(thisSide),flipud(cp),flipud(cp),false);
            if(strcmp(this.getStudy(thisSide),this.getStudy(otherSide)) && strcmp(this.getSubject(thisSide),this.getSubject(otherSide)) && this.getROIDisplayMode(otherSide) == 1)
                this.objHandles.(sprintf('%sdo',otherSide)).drawROI(this.getROIType(thisSide),flipud(cp),flipud(cp),false);
            end
        end
        
        function GUI_mouseButtonUp_Callback(this,hObject,eventdata)
            %executes on mouse button up in window 
            cp = this.objHandles.ldo.getMyCP();
            thisSide = 'l';
            otherSide = 'r';
            if(isempty(cp))
                cp = this.objHandles.rdo.getMyCP();
                thisSide = 'r';
                otherSide = 'l';
            end
            %draw current point in both (empty cp deletes old lines)
            this.objHandles.ldo.drawCP(cp);
            this.objHandles.rdo.drawCP(cp);
            if(isempty(cp))
                %set(this.visHandles.FLIMXVisGUIFigure,'Pointer','arrow');
            elseif(this.getROIDisplayMode(thisSide) < 3)
                set(this.visHandles.FLIMXVisGUIFigure,'Pointer','cross');
                if(this.getROIType(thisSide) >= 1 && get(this.visHandles.enableMouse_check,'Value'))
                    this.objHandles.(sprintf('%sROI',thisSide)).setEndPoint(flipud(cp),true);
                    this.objHandles.(sprintf('%sROI',otherSide)).updateGUI([]);
                    this.myStatsGroupComp.clearResults();
                    this.objHandles.rdo.updatePlots();
                    this.objHandles.ldo.updatePlots();
                    this.objHandles.ldo.drawCP(cp);
                    this.objHandles.rdo.drawCP(cp);
                end
                this.dynParams.mouseButtonDown = false;
            end
        end
        
        function GUI_studySet_Callback(this,hObject,eventdata)
            %select study                        
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'study_l_pop'))                
                s = 'l';            
            end
%             this.updateViewList(s);
%             this.updateSubjectDSList(s);
            this.setupGUI();
            this.updateGUI(s);            
            
        end
        
        function GUI_viewSet_Callback(this,hObject,eventdata)
            %select view
            s = 'r';
            if(strcmp(get(hObject,'Tag'),'view_l_pop'))                
                s = 'l';            
            end
%             this.updateSubjectDSList(s);
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
        
        function GUI_cut_Callback(this,hObject,eventdata)
            %access cut controls
            if(this.fdt.getNrSubjects(this.getStudy('l'),this.getView('l')) < 1)
                return
            end
            ax = 'x';
            tag = get(hObject,'Tag');
            if(~isempty(strfind(tag,'y')))
                ax = 'y';
            end
            if(~isempty(strfind(tag,'edit')))
                this.objHandles.(sprintf('cut%s',ax)).editCallback();
            elseif(~isempty(strfind(tag,'check')))
                this.objHandles.(sprintf('cut%s',ax)).checkCallback();
            else
                this.objHandles.(sprintf('cut%s',ax)).sliderCallback();
            end
            this.objHandles.rdo.updatePlots();
            this.objHandles.ldo.updatePlots();
        end
                                
        function GUI_roi_Callback(this,hObject,eventdata)
            %change roi size in x, y or z direction
            s1 = 'r'; %side which activated the control
            s2 = 'l'; %side we have to update to the new values
            %find side/axes
            tag = get(hObject,'Tag');
            if(~isempty(strfind(tag,'_l_')))
                s1 = 'l';
                s2 = 'r';
            end
            %find dimension
            if(~isempty(strfind(tag,'_x_')))
                dim = 'x';
            elseif(~isempty(strfind(tag,'_y_')))
                dim = 'y';
            else
                dim = 'z';
            end
            %lower or upper bound?
            if(~isempty(strfind(tag,'_lo_')))
                bnd = 'lo';
            else
                bnd = 'u';
            end
            %find control type
            if(~isempty(strfind(tag,'edit')))
                if(strcmp(dim,'z'))
                    this.objHandles.(sprintf('%sZScale',s1)).editCallback(dim,bnd);
                else
                    this.objHandles.(sprintf('%sROI',s1)).editCallback(dim,bnd);
                end
            elseif(length(tag) == 11 && ~isempty(strfind(tag,'table')))
                this.objHandles.(sprintf('%sROI',s1)).tableEditCallback(eventdata);
            elseif(~isempty(strfind(tag,'roi_table_clearLast')))
                this.objHandles.(sprintf('%sROI',s1)).buttonClearLastCallback();
            elseif(~isempty(strfind(tag,'roi_table_clearAll')))
                this.objHandles.(sprintf('%sROI',s1)).buttonClearAllCallback();
            elseif(~isempty(strfind(tag,'button')) && isempty(strfind(tag,'roi_table_clearAll')))
                if(~isempty(strfind(tag,'_dec_')))
                    target = 'dec';
                else
                    target = 'inc';
                end
                if(strcmp(dim,'z'))
                    this.objHandles.(sprintf('%sZScale',s1)).buttonCallback(dim,bnd,target);
                else
                    this.objHandles.(sprintf('%sROI',s1)).buttonCallback(dim,bnd,target);
                end
            elseif(~isempty(strfind(tag,'popup')))
                if(~isempty(strfind(tag,'roi_subtype_')))
                    type = 'main';
                else
                    type = 'sub';
                end
                this.objHandles.(sprintf('%sROI',s1)).popupCallback(type);
            else %check
                this.objHandles.(sprintf('%sZScale',s1)).checkCallback(dim);
            end
            %update ROI controls on other side
            if(~isempty(strfind(tag,'type_')))
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
            if(~isempty(strfind(tag,'R')))
                side = 'r';
            end
            pType = 'main'; %main plot
            if(~isempty(strfind(tag,'B')))
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
            if(isempty(strfind(tag,'_l_')))
                s = 'r';
            end     
            if(this.fdt.getNrSubjects(this.getStudy(s),this.getView(s)) < 1)
                return
            end
            %check if button was pressed
            if(~isempty(strfind(tag,'_button')))
                if(~isempty(strfind(tag,'_dec_')))
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
            %set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback);%,'WindowButtonUpFcn',@this.mouseButtonUp);
            set(this.visHandles.FLIMXVisGUIFigure,'Units','Pixels');
            %popups
            set(this.visHandles.enableMouse_check,'Callback',@this.GUI_enableMouseCheck_Callback,'Value',0,'String','enable ROI definition');
            set(this.visHandles.sync3DViews_check,'Callback',@this.GUI_sync3DViews_check_Callback,'Value',0);
            %main axes
            set(this.visHandles.dataset_l_pop,'Callback',@this.GUI_subjectPop_Callback);
            set(this.visHandles.dataset_r_pop,'Callback',@this.GUI_subjectPop_Callback);
            set(this.visHandles.dataset_l_dec_button,'FontName','Symbol','String',char(173),'Callback',@this.GUI_subjectButton_Callback);
            set(this.visHandles.dataset_l_inc_button,'FontName','Symbol','String',char(175),'Callback',@this.GUI_subjectButton_Callback);
            set(this.visHandles.dataset_r_dec_button,'FontName','Symbol','String',char(173),'Callback',@this.GUI_subjectButton_Callback);
            set(this.visHandles.dataset_r_inc_button,'FontName','Symbol','String',char(175),'Callback',@this.GUI_subjectButton_Callback);            
            set(this.visHandles.main_axes_l_pop,'Callback',@this.GUI_mainAxesPop_Callback);
            set(this.visHandles.main_axes_r_pop,'Callback',@this.GUI_mainAxesPop_Callback);            
            set(this.visHandles.main_axes_var_l_pop,'Callback',@this.GUI_mainAxesVarPop_Callback);
            set(this.visHandles.main_axes_var_r_pop,'Callback',@this.GUI_mainAxesVarPop_Callback);            
            set(this.visHandles.main_axes_pdim_l_pop,'Callback',@this.GUI_mainAxesDimPop_Callback);
            set(this.visHandles.main_axes_pdim_r_pop,'Callback',@this.GUI_mainAxesDimPop_Callback);            
            set(this.visHandles.main_axes_chan_l_pop,'Callback',@this.GUI_mainAxesChPop_Callback);
            set(this.visHandles.main_axes_chan_r_pop,'Callback',@this.GUI_mainAxesChPop_Callback);            
            set(this.visHandles.main_axes_scale_l_pop,'Callback',@this.GUI_mainAxesScalePop_Callback,'Enable','off','Value',1);
            set(this.visHandles.main_axes_scale_r_pop,'Callback',@this.GUI_mainAxesScalePop_Callback,'Enable','off','Value',1); 
            %supp axes
            set(this.visHandles.supp_axes_l_pop,'Callback',@this.GUI_suppAxesPop_Callback); 
            set(this.visHandles.supp_axes_r_pop,'Callback',@this.GUI_suppAxesPop_Callback); 
            set(this.visHandles.supp_axes_hist_l_pop,'Callback',@this.GUI_suppAxesHistPop_Callback); 
            set(this.visHandles.supp_axes_hist_r_pop,'Callback',@this.GUI_suppAxesHistPop_Callback); 
            set(this.visHandles.supp_axes_scale_l_pop,'Callback',@this.GUI_suppAxesScalePop_Callback); 
            set(this.visHandles.supp_axes_scale_r_pop,'Callback',@this.GUI_suppAxesScalePop_Callback);            
            %cuts
            set(this.visHandles.cut_x_l_check,'Callback',@this.GUI_cut_Callback);
            set(this.visHandles.cut_y_l_check,'Callback',@this.GUI_cut_Callback);
            set(this.visHandles.cut_y_l_slider,'Callback',@this.GUI_cut_Callback);
            set(this.visHandles.cut_x_l_slider,'Callback',@this.GUI_cut_Callback);
            set(this.visHandles.cut_y_l_edit,'Callback',@this.GUI_cut_Callback);
            set(this.visHandles.cut_x_l_edit,'Callback',@this.GUI_cut_Callback);
            set(this.visHandles.cut_x_inv_check,'Callback',@this.GUI_cut_Callback);
            set(this.visHandles.cut_y_inv_check,'Callback',@this.GUI_cut_Callback);
            %manual scaling
            dims =['x','y','z'];
            axs = ['l','r'];
            for j = 1:2
                ax = axs(j);
                for i=1:3
                    dim = dims(i);
                    set(this.visHandles.(sprintf('ms_%s_%s_lo_dec_button',ax,dim)),'Callback',@this.GUI_roi_Callback);
                    set(this.visHandles.(sprintf('ms_%s_%s_lo_inc_button',ax,dim)),'Callback',@this.GUI_roi_Callback);
                    set(this.visHandles.(sprintf('ms_%s_%s_lo_edit',ax,dim)),'Callback',@this.GUI_roi_Callback);
                    set(this.visHandles.(sprintf('ms_%s_%s_u_dec_button',ax,dim)),'Callback',@this.GUI_roi_Callback);
                    set(this.visHandles.(sprintf('ms_%s_%s_u_inc_button',ax,dim)),'Callback',@this.GUI_roi_Callback);
                    set(this.visHandles.(sprintf('ms_%s_%s_u_edit',ax,dim)),'Callback',@this.GUI_roi_Callback);
                    set(this.visHandles.(sprintf('ms_%s_%s_check',ax,dim)),'Callback',@this.GUI_roi_Callback);
                end
                set(this.visHandles.(sprintf('roi_type_%s_popup',ax)),'Callback',@this.GUI_roi_Callback);
                set(this.visHandles.(sprintf('roi_subtype_%s_popup',ax)),'Callback',@this.GUI_roi_Callback);
                set(this.visHandles.(sprintf('roi_%s_table',ax)),'CellEditCallback',@this.GUI_roi_Callback);
                set(this.visHandles.(sprintf('roi_table_clearLast_%s_button',ax)),'Callback',@this.GUI_roi_Callback);
                set(this.visHandles.(sprintf('roi_table_clearAll_%s_button',ax)),'Callback',@this.GUI_roi_Callback);
            end
            %menu            
            set(this.visHandles.menuImportResult,'Callback',@this.menuImport_Callback); 
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
            set(this.visHandles.IO_l_check,'Callback',@this.GUI_intOverlay_Callback);
            set(this.visHandles.IO_r_check,'Callback',@this.GUI_intOverlay_Callback);
            set(this.visHandles.IO_l_dec_button,'Callback',@this.GUI_intOverlay_Callback);            
            set(this.visHandles.IO_r_dec_button,'Callback',@this.GUI_intOverlay_Callback);
            set(this.visHandles.IO_l_inc_button,'Callback',@this.GUI_intOverlay_Callback);
            set(this.visHandles.IO_r_inc_button,'Callback',@this.GUI_intOverlay_Callback);
            set(this.visHandles.IO_l_edit,'Callback',@this.GUI_intOverlay_Callback);
            set(this.visHandles.IO_r_edit,'Callback',@this.GUI_intOverlay_Callback);            
            %current point
            set(this.visHandles.cp_l_desc_text,'Visible','on');
            set(this.visHandles.cp_r_desc_text,'Visible','on');
            set(this.visHandles.cp_l_pos_text,'Visible','on');
            set(this.visHandles.cp_r_pos_text,'Visible','on');
            set(this.visHandles.cp_l_val_text,'Visible','on');
            set(this.visHandles.cp_r_val_text,'Visible','on');            
            %setup study controls
            set(this.visHandles.study_l_pop,'Callback',@this.GUI_studySet_Callback);
            set(this.visHandles.study_r_pop,'Callback',@this.GUI_studySet_Callback);
            set(this.visHandles.view_l_pop,'Callback',@this.GUI_viewSet_Callback);
            set(this.visHandles.view_r_pop,'Callback',@this.GUI_viewSet_Callback);            
            %study color selection
            set(this.visHandles.study_color_l_button,'Callback',@this.GUI_viewColorSelection_Callback);
            set(this.visHandles.study_color_r_button,'Callback',@this.GUI_viewColorSelection_Callback);            
            %progress bars
            set(this.visHandles.cancel_button,'Callback',@this.GUI_cancelButton_Callback);
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
            this.objHandles.ldo.drawCP([]);
            this.objHandles.rdo.drawCP([]);
            this.objHandles.lZScale.updateGUI([]);
            this.objHandles.rZScale.updateGUI([]);
            set(this.visHandles.FLIMXVisGUIFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback);
        end   
    end %methods protected   
    
    methods(Static)
        function [rs, lastPath] = loadResultFile(lastPath,subjectName,ch)
            %import a FLIMFit result from file(s)
            [files, path, filterindex] = uigetfile( ...
                {'*.asc','ASCII files [SPCImage >= 3.97] (*.asc)';
                '*.dat;*.txt','Text files [SPCImage < 3.97] (*.dat,*.txt)';                
                '*.mat','FLIMFit result files (*.mat)'}, ...
                sprintf('Select fitting results for subject %s channel %d...',subjectName,ch), ...
                'MultiSelect', 'on',lastPath);
            if(~path)
                rs = []; lastPath = '';
                return
            end
            lastPath = path;
            idx = strfind(lastPath,filesep);
            if(length(idx) > 1)
                lastPath = lastPath(1:idx(end-1));
            end
            switch filterindex
                case {1,2} %ASCII file
                    try
                        rs = FLIMXVisGUI.ASCII2ResultStruct(files,path,subjectName,filterindex,ch);                    
                    catch ME
                        uiwait(errordlg(ME.message,'Error importing ASCII result','modal'));
                        rs = [];                        
                        lastPath = '';
                    end
                case 3 %flimfit result
                    if(size(files,1) > 1)
                        uiwait(warndlg('Too many result files selected.\n\nPlease select only one FLIMFit result file at a time!','Too many result files','modal'));
                        return;
                    end
                    fn = fullfile(path,files);
                    rs = load(fn);
                    rs = rs.result;
                    rs.name = subjectName;
                    if(rs.channel ~= ch)
                        uiwait(warndlg(sprintf('Result file with wrong channel has been selected!\n\nChannel required: %d\nChannel loaded: %d\n\nPlease select result file for channel %d.',ch,rs.parameters.dynamic.curChannel,ch),'Wrong channel loaded','modal'));
                        return;
                    end
            end
        end
        
        function rs = ASCII2ResultStruct(files,path,dn,type,chan)
            %convert ASCII parameter files to internal result format
            files = sort(files);
            nr_e = length(files);
            counters = [];
            rs.results.pixel.Amplitude1 = [];
            idx = ~cellfun('isempty',strfind(files,'a1.asc'));
            if(~any(idx))
                error('Amplitude 1 (''xxx_a1.asc'') not be found among selected files.');
            elseif(sum(idx(:)) > 1)
                error('Multiple files for amplitude 1 (''xxx_a1.asc'') found among selected files - multiple channels selected?');
            end
            files = circshift(files(:),-find(idx,1)+1);
            for i=1:nr_e
                if(~isempty(path))
                    fn = fullfile(path,files{i});
                else
                    fn = files{i};
                end
                [~, dType, ~] = fileparts(lower(char(files{i,1})));%filename without '.txt'/'.dat'/'.asc'
                if(type == 1)
                    %new ascii type
                    %find last '_'
                    idx = strfind(dType,'_');
                    if(isempty(idx))
                        %something is wrong with this file
                        continue
                    end
                    dType = dType(min(length(dType),idx(end)+1):end);
                    if(isempty(dType) ||  ~isempty(strfind(dType,'[%]')) || strcmp(dType,'trace'))
                        %error or amplitude in percent or data trace
                        continue
                    end
                    if(strcmp(dType(1),'a') && length(dType) == 2)
                        dType = 'Amplitude';
                    elseif(strcmp(dType(1),'t') && length(dType) == 2)
                        dType = 'Tau';
                    else
                        %get datatype from filename; remove space chars
                        dType = dType(~isspace(dType));
                    end                    
                else
                    %old ascii type
                    if(strcmp(dType(1:3),'amp'))
                        dType = 'Amplitude';
                    elseif(strcmp(dType(1:3),'tau') && ~strcmp(dType(1:4),'tau_'))
                        dType = 'Tau';
                    else
                        %get datatype from filename
                        dType = dType(1:end);
                        mask = true(length(dType),1);
                        mask(isstrprop(dType, 'digit')) = false; %remove numbers
                        mask(isstrprop(dType, 'wspace')) = false; %remove spaces
                        dType = dType(mask);
                    end
                end
                %count what we read from disk
                if(~isfield(counters,dType))
                    counters.(dType) = 0;
                end
                counters.(dType) = counters.(dType)+1;
                data_temp = load(fn,'-ASCII');
                %restrict B&H amplitudes to <= 1 and amplify
%                 if(strcmp(dType,'Amplitude') && median(data_temp(:)) < 0.5)
%                     data_temp(data_temp > 1) = 0;
%                     data_temp = data_temp .* 100000;
%                 end
                if(~isempty(rs.results.pixel.Amplitude1))
                    if(all(size(rs.results.pixel.Amplitude1) == size(data_temp)))
                        rs.results.pixel.(sprintf('%s%d',dType,counters.(dType))) = data_temp;
                    else
                        warning('FLIMXVisGUI:ASCII2ResultStruct:ignoredItem','Size of ''%s'' (%dx%d) does not match image size (%dx%d). ''%s'' is ignored.',dType,size(data_temp,1),size(data_temp,2),size(rs.results.pixel.Amplitude1,1),size(rs.results.pixel.Amplitude1,2),dType);
                    end
                else
                    %this should be amplitude 1
                    rs.results.pixel.(sprintf('%s%d',dType,counters.(dType))) = data_temp;
                end
            end
            rs.roiCoordinates = [];
            rs.channel = chan; 
            rs.name = dn;
            rs.resultType = 'ASCII';
            rs.about.results_revision = 200;
        end     
        
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
        
        % --- Executes on mouse press over axes background.
        function rotate_postCallback(hObject, eventdata, hFLIMXVis)
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
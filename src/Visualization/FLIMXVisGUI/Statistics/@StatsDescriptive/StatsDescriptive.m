classdef StatsDescriptive < handle
    %=============================================================================================================
    %
    % @file     StatsDescriptive.m
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
    % @brief    A class to compute descriptive statistical of all subjects in a study
    %
    properties(GetAccess = public, SetAccess = protected)
        visHandles = []; %structure to handles in GUI
        visObj = []; %handle to FLIMXVis
        subjectStats = cell(0,0);   
        nonEmptySubjectStats = false(0,0);
        statsDesc = cell(0,0);
        subjectDesc = cell(0,0);
        statHist = [];
        statCenters = [];
        normDistTests = [];
        normDistTestsLegend = cell(0,0);
    end
%     properties(GetAccess = protected, SetAccess = protected)
%         stopFlag = false;
%     end
    properties (Dependent = true)
        study = '';
        condition = '';
        ch = 1;
        dType = '';
        totalDTypes = 0;
        statType = '';
        statPos = 1;
        totalStatTypes = 0;
        groupStats = cell(0,0);
        id = 0;
        classWidth = 1;
        exportModeFLIM = 1;
        exportModeROI = 1;
        exportModeStat = 0;
        exportModeCh = 1;
        exportModeCondition = 1;
        exportNormDistTests = 0;
        exportSubjectRawData = 0;
        currentSheetName = '';
        ROIType = 1001;
        ROISubType = 1;
        ROIVicinityFlag = 0;
        alpha = 5;
        allROITypes = cell(0,0);
    end
    
    methods
        function this = StatsDescriptive(visObj)
            %constructor for StatsDescriptive
            this.visObj = visObj;
        end
        
        function createVisWnd(this)
            %make a new window
            this.visHandles = StatsDescriptiveFigure();
            set(this.visHandles.StatsDescriptiveFigure,'CloseRequestFcn',@this.menuExit_Callback);
            %set callbacks
            set(this.visHandles.popupSelStudy,'Callback',@this.GUI_SelStudyPop_Callback);
            set(this.visHandles.popupSelCondition,'Callback',@this.GUI_SelConditionPop_Callback);
            set(this.visHandles.popupSelCh,'Callback',@this.GUI_SelChPop_Callback);
            set(this.visHandles.popupSelFLIMParam,'Callback',@this.GUI_SelFLIMParamPop_Callback);
            set(this.visHandles.popupSelROIType,'Callback',@this.GUI_SelROITypePop_Callback);
            set(this.visHandles.popupSelROISubType,'Callback',@this.GUI_SelROITypePop_Callback);
            set(this.visHandles.popupSelROIVicinity,'Callback',@this.GUI_SelROITypePop_Callback);
            set(this.visHandles.popupSelStatParam,'Callback',@this.GUI_SelStatParamPop_Callback);
            set(this.visHandles.checkDisplayAllROIs,'Callback',@this.GUI_checkDisplayAllROIs_Callback);
            set(this.visHandles.checkHideEmptyROIs,'Callback',@this.GUI_checkHideEmptyROIs_Callback);
            %export
            set(this.visHandles.buttonExportExcel,'Callback',@this.GUI_buttonExcelExport_Callback);
            set(this.visHandles.checkSNFLIM,'Callback',@this.GUI_checkExcelExport_Callback);
            set(this.visHandles.checkSNROI,'Callback',@this.GUI_checkExcelExport_Callback);
            set(this.visHandles.checkSNCh,'Callback',@this.GUI_checkExcelExport_Callback);
            set(this.visHandles.checkSNCondition,'Callback',@this.GUI_checkExcelExport_Callback);
            set(this.visHandles.popupSelExportFLIM,'Callback',@this.GUI_popupSelExportFLIM_Callback);
            set(this.visHandles.popupSelExportROI,'Callback',@this.GUI_popupSelExportROI_Callback);
            set(this.visHandles.popupSelExportCh,'Callback',@this.GUI_popupSelExportCh_Callback);
            set(this.visHandles.popupSelExportCondition,'Callback',@this.GUI_popupSelExportCondition_Callback);
            %display
            set(this.visHandles.buttonUpdateGUI,'Callback',@this.GUI_buttonUpdateGUI_Callback);
            %table main
            axis(this.visHandles.axesBar,'off');
            axis(this.visHandles.axesBoxplot,'off');
            set(this.visHandles.popupSelStatParam,'String',FData.getDescriptiveStatisticsDescription(),'Value',3);
            %normal distribution tests
            set(this.visHandles.editAlpha,'Callback',@this.GUI_editAlpha_Callback);
            %progress bar
            xpatch = [0 0 0 0];
            ypatch = [0 0 1 1];
            axis(this.visHandles.axesProgress ,'off');            
            xlim(this.visHandles.axesProgress,[0 100]);
            ylim(this.visHandles.axesProgress,[0 1]);
            this.visHandles.patchProgress = patch(xpatch,ypatch,'r','EdgeColor','r','Parent',this.visHandles.axesProgress);
            this.visHandles.textProgress = text(1,1,'','Parent',this.visHandles.axesProgress,'Fontsize',8);%,'HorizontalAlignment','right','Units','pixels');
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~isfield(this.visHandles,'StatsDescriptiveFigure') || ~ishandle(this.visHandles.StatsDescriptiveFigure) || ~strcmp(get(this.visHandles.StatsDescriptiveFigure,'Tag'),'StatsDescriptiveFigure'));
        end
        
        function checkVisWnd(this)
            %check if my window is open, if not: create it
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.GUI_SelFLIMParamPop_Callback(this.visHandles.popupSelFLIMParam,[]); %will call setupGUI
            figure(this.visHandles.StatsDescriptiveFigure);
        end
        
        function setCurrentStudy(this,studyName,condition)
            %set the GUI to a certain study and condition
            if(~this.isOpenVisWnd())
                %no window 
                return
            end
            %find study
            idx = find(strcmp(get(this.visHandles.popupSelStudy,'String'),studyName),1);
            if(isempty(idx))
                return
            end
            set(this.visHandles.popupSelStudy,'Value',idx);
            this.setupGUI();
            %find condition
            idx = find(strcmp(get(this.visHandles.popupSelCondition,'String'),condition),1);
            if(isempty(idx))
                return
            end
            set(this.visHandles.popupSelCondition,'Value',idx);
        end 
        
        %% GUI callbacks
        function GUI_SelStudyPop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_SelConditionPop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_SelChPop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_SelFLIMParamPop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
            [cw, ~, ~, ~] = getHistParams(this.visObj.getStatsParams(),this.ch,this.dType,this.id);
            set(this.visHandles.editClassWidth,'String',cw);            
        end
        
        function GUI_SelROITypePop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_SelStatParamPop_Callback(this,hObject,eventdata)
            %
            %set class width on statistics parameter change
            this.setupGUI();
        end
        
        function GUI_checkDisplayAllROIs_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_checkHideEmptyROIs_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_buttonUpdateGUI_Callback(this,hObject,eventdata)
            %
%             try
%                 set(hObject,'String',sprintf('<html><img src="file:/%s"/> Update</html>',FLIMX.getAnimationPath()));
%                 drawnow;
%             end
            this.clearResults();
            this.updateGUI();
%             set(hObject,'String','Update');
        end
        
        function GUI_DispGrpPop_Callback(this,hObject,eventdata)
            %
            this.updateGUI();
        end
        
        function GUI_editAlpha_Callback(this,hObject,eventdata)
            %alpha value changed
            set(hObject,'String',num2str(abs(max(0.1,min(10,abs(str2double(get(hObject,'string'))))))));
            this.clearResults();
            this.updateGUI();
        end
        
        function GUI_popupSelExportFLIM_Callback(this,hObject,eventdata)
            %
            if(get(hObject,'Value') == 1)
                set(this.visHandles.checkSNFLIM,'Enable','on')
            else
                set(this.visHandles.checkSNFLIM,'Enable','off','Value',1)
            end
            
            GUI_checkExcelExport_Callback(this,this.visHandles.checkSNFLIM,eventdata);
        end
        
        function GUI_popupSelExportROI_Callback(this,hObject,eventdata)
            %
            if(get(hObject,'Value') == 1)
                set(this.visHandles.checkSNROI,'Enable','on')
            else
                set(this.visHandles.checkSNROI,'Enable','off','Value',1)
            end
            
            GUI_checkExcelExport_Callback(this,this.visHandles.checkSNROI,eventdata);
        end
        
        function GUI_popupSelExportCh_Callback(this,hObject,eventdata)
            %
            if(get(hObject,'Value') == 1)
                set(this.visHandles.checkSNCh,'Enable','on')
            else
                set(this.visHandles.checkSNCh,'Enable','off','Value',1)
            end
            GUI_checkExcelExport_Callback(this,this.visHandles.checkSNCh,eventdata);
        end
        
        function GUI_popupSelExportCondition_Callback(this,hObject,eventdata)
            %
            if(get(hObject,'Value') == 1)
                set(this.visHandles.checkSNCondition,'Enable','on')
            else
                set(this.visHandles.checkSNCondition,'Enable','off','Value',1)
            end
            GUI_checkExcelExport_Callback(this,this.visHandles.checkSNCondition,eventdata);
        end
        
        function GUI_checkExcelExport_Callback(this,hObject,eventdata)
            %
            set(this.visHandles.editSNPreview,'String',this.currentSheetName);
        end
                
        function GUI_buttonExcelExport_Callback(this,hObject,eventdata)
            %create xls file with current statistics data
            [file,path] = uiputfile({'*.xlsx','Excel file (*.xlsx)';'*.xls','Excel 97-2003 file (*.xls)'},'Export Data in Excel Fileformat...');
            if ~file ; return ; end
            fn = fullfile(path,file);
            %switch of GUI elements
            try
                set(hObject,'String',sprintf('<html><img src="file:/%s"/></html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            this.toggleGUIControls('Off');            
            switch this.exportModeFLIM
                case 1 %single (current) result
                    if(isempty(this.subjectStats))
                        this.makeStats();
                        if(isempty(this.subjectStats))
                            this.clearPlots();
                        end
                    end
                    FLIMIds = get(this.visHandles.popupSelFLIMParam,'Value');
                case 2 %all FLIM parameters
                    FLIMIds = 1:this.totalDTypes;
                    this.clearResults();
            end
            if(length(this.visHandles.popupSelROIType.String) == 1)
                ROIIds = 1;
            else
                switch this.exportModeROI
                    case 1 %current ROI
                        ROIIds = 1;
                    case 2 %all ETDRS grid ROIs
                        this.visHandles.popupSelROIType.Value = 2; %switch to ETDRS grid
                        this.setupGUI();
                        this.clearResults();
                        ROIIds = 1:length(this.visHandles.popupSelROISubType.String);
                    case 3 %all major ROIs except for the ETDRS grid
                        this.clearResults();
                        if(this.visHandles.checkDisplayAllROIs.Value)
                            [~,ROIIds] = unique(round(this.allROITypes./1000));
                            ROIIds(ROIIds < 3) = [];
                        else
                            ROIIds = 3:length(this.visHandles.popupSelROIType.String);
                        end
                end
            end
            switch this.exportModeCh
                case 1 %current channel
                    chIds = this.ch;
                case 2 % all channels
                    chIds = 1:length(get(this.visHandles.popupSelCh,'String'));
                    this.clearResults();
            end
            switch this.exportModeCondition
                case 1 %current condition
                    condIds = get(this.visHandles.popupSelCondition,'Value');
                case 2 % all conditions
                    condIds = 1:length(get(this.visHandles.popupSelCondition,'String'));
                    this.clearResults();
            end
            %loop over all export paramters
            totalIter = length(condIds)*length(FLIMIds)*length(ROIIds)*length(chIds); %assume identical number of FLIM items in all channels
            curIter = 0;
            for v = 1:length(condIds)
                if(length(condIds) > 1)
                    set(this.visHandles.popupSelCondition,'Value',v);
                    this.clearResults();
                    this.GUI_SelConditionPop_Callback(this.visHandles.popupSelCondition,[]); %will call setupGUI
                end
                for c = 1:length(chIds)
                    if(length(chIds) > 1)
                        set(this.visHandles.popupSelCh,'Value',c);
                        this.clearResults();
                        this.GUI_SelChPop_Callback(this.visHandles.popupSelCh,[]); %will call setupGUI
                    end
                    if(this.exportModeFLIM == 2)
                        FLIMIds = 1:this.totalDTypes;
                    else
                        FLIMIds = get(this.visHandles.popupSelFLIMParam,'Value');
                    end
                    for f = 1:length(FLIMIds)
                        if(length(FLIMIds) > 1)
                            set(this.visHandles.popupSelFLIMParam,'Value',f);
                            this.clearResults();
                            this.GUI_SelFLIMParamPop_Callback(this.visHandles.popupSelFLIMParam,[]); %will call setupGUI
                        end
                        for r = 1:length(ROIIds)
                            if(length(ROIIds) > 1)
                                switch this.exportModeROI
                                    case 2 %all ETDRS grid ROIs
                                        set(this.visHandles.popupSelROIType,'Value',2); %switch to ETDRS grid
                                        set(this.visHandles.popupSelROISubType,'Value',ROIIds(r));
                                        this.clearResults();
                                        this.GUI_SelROITypePop_Callback(this.visHandles.popupSelROIType,[]); %will call setupGUI
                                    case 3 %all major ROIs except for the ETDRS grid
                                        set(this.visHandles.popupSelROIType,'Value',ROIIds(r));
                                        this.clearResults();
                                        this.GUI_SelROITypePop_Callback(this.visHandles.popupSelROIType,[]); %will call setupGUI
                                end
                            end
                            %finally update the GUI and export its data
                            this.updateGUI();
                            if(isempty(this.subjectStats))
                                this.makeStats();
                                if(isempty(this.subjectStats))
                                    continue;
                                end
                            end
                            exportExcel(fn,this.subjectStats(this.nonEmptySubjectStats,:),this.statsDesc,this.subjectDesc(this.nonEmptySubjectStats,1),this.currentSheetName,sprintf('%s%d',this.dType,this.id));
                            if(this.exportModeStat)
                                data = cell(0,0);
                                str = get(this.visHandles.popupSelStatParam,'String');
                                for i = 1:this.totalStatTypes
                                    [statHist, statCenters] = makeHistogram(this,i);
                                    if(~isempty(statHist))
                                        data(end+1,1) = str(i);
                                        data(end,2:1+length(statCenters)) = num2cell(statCenters);
                                        data(end+1,2:1+length(statHist)) = num2cell(statHist);
                                        data(end+1,1) = cell(1,1);
                                    end
                                end
                                exportExcel(fn,data,'',num2cell(this.statCenters),['Hist-' this.currentSheetName],sprintf('%s%d',this.dType,this.id));
                            end
                            if(this.exportNormDistTests)
                                data = this.normDistTestsLegend;
                                data(:,2) = sprintfc('%1.4f',this.normDistTests(:,1));
                                data(:,3) = num2cell(logical(this.normDistTests(:,2)));
                                exportExcel(fn,data,{'Test','p','Significance'},'',[this.statType '-' this.currentSheetName],'');
                            end
                            if(this.exportSubjectRawData)
                                subjects = this.visObj.fdt.getAllSubjectNames(this.study,this.condition);
                                for s = 1:length(subjects)
                                    fdt = this.visObj.fdt.getFDataObj(this.study,subjects{s},this.ch,this.dType,this.id,1);
                                    rt = this.ROIType;
                                    rc = fdt.getROICoordinates(rt);
                                    data = fdt.getROIImage(rc,rt,this.ROISubType,this.ROIVicinityFlag);                                    
                                    if(rt > FDTStudy.roiBaseETDRS && rt < FDTStudy.roiBaseRectangle)
                                        txt = {'C','IS','IN','II','IT','OS','ON','OI','OT','IR','OR','FC'}';
                                        rStr = txt{this.ROISubType};
                                    else
                                        txt = {'Rect','Circ','Poly'};
                                        rStr = sprintf('%s%d',txt{floor(rt/1000)},rt-floor(rt/1000)*1000);
                                    end                                        
                                    exportExcel(fn,data,{''},'',sprintf('%s_%s_%d_%s%d',subjects{s},rStr,this.ch,this.dType,this.id),'');
                                end
                            end
                            curIter = curIter+1;
                            this.updateProgressbar(curIter/totalIter,sprintf('%d%%',round(curIter/totalIter*100)));
                        end
                    end
                end
            end
            this.toggleGUIControls('On');
            set(hObject,'String','Go');
            this.updateProgressbar(0,'');
        end
        
        function clearResults(this)
            %clear all current results
            this.subjectStats = cell(0,0);
            this.statsDesc = cell(0,0);
            this.subjectDesc = cell(0,0);
            this.statHist = [];
            this.statCenters = [];
            this.normDistTests = [];
            this.normDistTestsLegend = cell(0,0);
        end
        
        function clearPlots(this)
            %clear 3D plot and table
            if(this.isOpenVisWnd())
                cla(this.visHandles.axesBar);
                cla(this.visHandles.axesBoxplot);
                set(this.visHandles.tableSubjectStats,'ColumnName','','RowName','','Data',[],'ColumnEditable',[]);
                set(this.visHandles.tableGroupStats,'RowName','','Data',[],'ColumnEditable',[]);
                set(this.visHandles.tableNormalTests,'Data',[]);
            end
        end
        
        function setupGUI(this)
            %setup GUI control
            if(~this.isOpenVisWnd())
                %no window
                return
            end
            this.clearResults();
            %update studies and conditions
            sStr = this.visObj.fdt.getAllStudyNames();
            set(this.visHandles.popupSelStudy,'String',sStr,'Value',min(length(sStr),this.visHandles.popupSelStudy.Value));
            %get conditions for the selected studies
            cStr = this.visObj.fdt.getStudyConditionsStr(this.study);
            set(this.visHandles.popupSelCondition,'String',cStr,'Value',min(length(cStr),this.visHandles.popupSelCondition.Value));
            %update channels and parameters
            ds1 = this.visObj.fdt.getAllSubjectNames(this.study,this.condition);
            if(~isempty(ds1))
                chStr = this.visObj.fdt.getChStr(this.study,ds1{1});
                coStr = this.visObj.fdt.getChObjStr(this.study,ds1{1},this.ch);
                coStr = sort(coStr);
            else
                chStr = [];
                coStr = 'param';
            end
            if(isempty(chStr))
                chStr = 'Ch 1';
            end
            set(this.visHandles.popupSelCh,'String',chStr,'Value',min(length(chStr),this.visHandles.popupSelCh.Value));
            %ROI
            allROIStr = arrayfun(@ROICtrl.ROIType2ROIItem,this.allROITypes,'UniformOutput',false);
            grps = this.visObj.fdt.getResultROIGroup(this.study,[]);
            if(~isempty(grps) && ~isempty(grps{1,1}))
                allROIStr = [allROIStr; sprintfc('Group: %s',string(grps(:,1)))];
            else
                grps = [];
            end
            set(this.visHandles.popupSelROIType,'String',allROIStr,'Value',min(this.visHandles.popupSelROIType.Value,length(allROIStr)));
            rt = this.ROIType;
            if(rt < 0)
                this.visHandles.checkDisplayAllROIs.String = 'Display all ROIs of the current ROI group';
                this.visHandles.checkDisplayAllROIs.Tooltip = 'Display all ROIs of the current ROI group in the subject statistics (this will also influence exported data)';
            else
                this.visHandles.checkDisplayAllROIs.String = 'Display all ROIs of the current type';
                this.visHandles.checkDisplayAllROIs.Tooltip = 'Display all ROIs of the current type in the subject statistics (this will also influence exported data)';
            end
            if(rt == 0 || rt > FDTStudy.roiBaseRectangle || rt < 0 && ~isempty(grps) && size(grps,2) == 2 && all([grps{abs(rt),2}] >= FDTStudy.roiBaseRectangle))
                flag = 'off';
            else
                flag = 'on';
            end
            this.visHandles.popupSelROISubType.Visible = flag;
            if(rt > FDTStudy.roiBaseETDRS || rt < 0)
                flag = 'on';
            end
            this.visHandles.popupSelROIVicinity.Visible = flag;
            %params
            oldPStr = this.visHandles.popupSelFLIMParam.String;
            if(iscell(oldPStr) && length(oldPStr) > 1)
                oldPStr = oldPStr(min(length(oldPStr),this.visHandles.popupSelFLIMParam.Value));
            end
            if(isempty(oldPStr))
                idx = 1;
            else
                %try to find oldPStr in new pstr
                idx = find(strcmp(oldPStr,coStr),1);
                if(isempty(idx))
                    idx = min(this.visHandles.popupSelFLIMParam.Value,length(coStr));
                end
            end
            set(this.visHandles.popupSelFLIMParam,'String',coStr,'Value',idx);
            this.clearPlots();
            %excel export sheet name preview
            this.visHandles.editSNPreview.String = this.currentSheetName;
        end
        
        function updateGUI(this)
            %update tables and axes
            try
                set(this.visHandles.buttonUpdateGUI,'String',sprintf('<html><img src="file:/%s"/> Update</html>',FLIMX.getAnimationPath()));
                drawnow;
            end            
            if(isempty(this.subjectStats))
                this.makeStats();
                if(isempty(this.subjectStats))
                    this.clearPlots();
                end
            end
            if(this.visHandles.checkHideEmptyROIs.Value)
                this.nonEmptySubjectStats = ~all(isnan(this.subjectStats) | (abs(this.subjectStats) < eps),2); %find NaN and zero values
            else
                this.nonEmptySubjectStats = true(size(this.subjectStats,1),1);
            end
            set(this.visHandles.tableSubjectStats,'ColumnName',this.statsDesc,'RowName',this.subjectDesc(this.nonEmptySubjectStats,1),'Data',FLIMXFitGUI.num4disp(this.subjectStats(this.nonEmptySubjectStats,:)));
            set(this.visHandles.tableGroupStats,'RowName','','Data',FLIMXFitGUI.num4disp(this.groupStats));
            %axes
            if(~isempty(this.statHist))
                bar(this.visHandles.axesBar,this.statCenters,this.statHist);
                %boxplot(this.visHandles.axesBoxplot,this.subjectStats(:,this.statPos),'labels',this.statsDesc(this.statPos));
                cla(this.visHandles.axesBoxplot);
                axis(this.visHandles.axesBoxplot,'on');
                violinplot(this.subjectStats(:,this.statPos), this.statsDesc(this.statPos),this.visHandles.axesBoxplot, [], 'ShowMean',true,'ViolinAlpha',0.5);
                if(~isempty(this.normDistTests))
                    tmp = this.normDistTestsLegend;
                    tmp(:,2) = sprintfc('%1.4f',this.normDistTests(:,1));
                    tmp(:,3) = num2cell(logical(this.normDistTests(:,2)));
                    this.visHandles.tableNormalTests.Data = tmp;
                end
            end
            set(this.visHandles.buttonUpdateGUI,'String','Update');
        end
        
        function updateProgressbar(this,x,text)
            %update progress bar; inputs: progress x: 0..1, text on progressbar
            if(this.isOpenVisWnd())
                x = max(0,min(100*x,100));
                xpatch = [0 x x 0];
                set(this.visHandles.patchProgress,'XData',xpatch,'Parent',this.visHandles.axesProgress)
                yl = ylim(this.visHandles.axesProgress);
                set(this.visHandles.textProgress,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.axesProgress);
                drawnow;
            end
        end
                
        function makeStats(this)
            %collect stats info from FDTree
            [this.subjectStats, this.statsDesc, this.subjectDesc] = this.visObj.fdt.getStudyStatistics(this.study,this.condition,this.ch,this.dType,this.id,this.ROIType,this.ROISubType,this.ROIVicinityFlag,true);
            if(this.visHandles.checkDisplayAllROIs.Value)
                nSubs = size(this.subjectStats,1);
                if(this.ROIType > 0)
                    %show all ROIs of the current type
                    allROT = this.allROITypes;
                    idx = find(floor(allROT/1000) - floor(this.ROIType/1000) == 0);                    
                    nROIs = length(idx);
                elseif(this.ROIType < 0)
                    %show all members of the current ROI group
                    grps = this.visObj.fdt.getResultROIGroup(this.study,[]);
                    allROT = grps{abs(this.ROIType),2};
                    nROIs = length(allROT);
                    idx = 1:nROIs;                    
                end
                if(~isempty(idx) && nROIs > 1)
                    statsTmp = zeros(nSubs*nROIs,size(this.subjectStats,2));
                    subDescTmp = cell(nSubs*nROIs,1);
                    for i = 1:nROIs
                        iVec = i:nROIs:nSubs*nROIs;
                        ROIName = ROICtrl.ROIType2ROIItem(allROT(idx(i)));
                        subDescTmp(iVec) = cellfun(@(x) sprintf('%s_%s',x,ROIName),this.subjectDesc,'uniform',false);
                        statsTmp(iVec,:) = this.visObj.fdt.getStudyStatistics(this.study,this.condition,this.ch,this.dType,this.id,allROT(idx(i)),this.ROISubType,this.ROIVicinityFlag,true);
                    end
                    this.subjectStats = statsTmp;
                    this.subjectDesc = subDescTmp;
                end
            end
            [this.statHist, this.statCenters] = this.makeHistogram(this.statPos);
            [this.normDistTests, this.normDistTestsLegend]= this.makeNormalDistributionTests(this.statPos);
        end
        
        function [result, legend] = makeNormalDistributionTests(this,statsID)
            %test statsID for normal distribution
            result = [ones(3,1), zeros(3,1)]; legend = cell(0,0);
            if(isempty(this.subjectStats) || statsID > length(this.subjectStats))
                return
            end
            legend = {'Lilliefors';'Shapiro-Wilk';'Kolmogorov-Smirnov'};
            ci = this.subjectStats(:,statsID);
            if(~any(ci(:)) || length(ci(:)) < 4)
                return
            end
            [result(1,2),result(1,1)] = StatsDescriptive.test4NormalDist('li',ci,this.alpha);
            [result(2,2),result(2,1)] = StatsDescriptive.test4NormalDist('sw',ci,this.alpha);
            [result(3,2),result(3,1)] = StatsDescriptive.test4NormalDist('ks',ci,this.alpha);
        end
        
        function [statHist, statCenters] = makeHistogram(this,statsID)
            %make histogram for statsID
            statHist = []; statCenters = [];
            if(isempty(this.subjectStats) || statsID > length(this.subjectStats))
                return
            end
            ci = this.subjectStats(:,statsID);
            cw = this.classWidth;
            c_min = round((min(ci(:)))/cw)*cw;%min(ci(:));
            c_max = round((max(ci(:)))/cw)*cw;%max(ci(:));
            if(c_max - c_min < eps)
                %flat data -> max = min, just leave it in one class
                statHist = numel(ci);
                statCenters = c_min;
                return
            end
            %make centers vector
            statCenters = c_min : cw : c_max;
            while length(statCenters) > 100
                cw = cw*10;
                statCenters = c_min : cw : c_max;
            end
            if(~all(isnan(ci(:))) && ~all(isinf(ci(:))))
                statHist = hist(ci,statCenters);
            end
        end
        
        function menuExit_Callback(this,hObject,eventdata)
            %executes on figure close
            if(~isempty(this.visHandles) && ishandle(this.visHandles.StatsDescriptiveFigure))
                delete(this.visHandles.StatsDescriptiveFigure);
            end
        end
        
        %% dependend properties
        function out = get.study(this)
            out = get(this.visHandles.popupSelStudy,'String');
            if(~ischar(out) && ~isempty(out))
                gNr = get(this.visHandles.popupSelStudy,'Value');
                out = out{min(gNr,length(out))};
            end
        end
        
        function out = get.condition(this)
            out = get(this.visHandles.popupSelCondition,'String');
            if(~ischar(out) && ~isempty(out))
                gNr = get(this.visHandles.popupSelCondition,'Value');
                out = out{min(gNr,length(out))};
            end
        end
        
        function out = get.ch(this)
            out = get(this.visHandles.popupSelCh,'String');
            if(~ischar(out))
                out = out{get(this.visHandles.popupSelCh,'Value')};
            end
            out = str2double(out(isstrprop(out, 'digit')));
        end
        
        function dType = get.dType(this) 
            dType = [];
            str = get(this.visHandles.popupSelFLIMParam,'String');
            if(~ischar(str) && ~isempty(str))
                [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(str{get(this.visHandles.popupSelFLIMParam,'Value')});
                dType = dType{1};
            end
        end
        
        function out = get.totalDTypes(this)
            tmp = get(this.visHandles.popupSelFLIMParam,'String');
            if(isempty(tmp))
                out = 0;
                return
            end
            if(~ischar(tmp))
                out = length(tmp);
            else
                out = 1;
            end
        end
        
        function str = get.statType(this)
            str = get(this.visHandles.popupSelStatParam,'String');
            if(~ischar(str))
                str = str{get(this.visHandles.popupSelStatParam,'Value')};
            end
            %[dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(str);
        end
        
        function out = get.totalStatTypes(this)
            tmp = get(this.visHandles.popupSelStatParam,'String');
            if(isempty(tmp))
                out = 0;
                return
            end
            if(~ischar(tmp))
                out = length(tmp);
            else
                out = 1;
            end
        end
        
        function out = get.groupStats(this)
            %return group mean of subject statistics (average of each parameter)
            if(isempty(this.subjectStats))
                out = [];
            else
                idx = isnan(this.subjectStats);                
                subjectROIMeans = this.subjectStats(~idx(:,3),3);
                [cw,lim,c_min,c_max] = getHistParams(this.visObj.statParams,this.ch,this.dType,this.id);
                if(lim)
                    subjectROIMeans = subjectROIMeans(subjectROIMeans >= c_min & subjectROIMeans <= c_max);
                else
                    c_min = round((min(subjectROIMeans(:)))/cw)*cw;
                    c_max = round((max(subjectROIMeans(:)))/cw)*cw;
                end
                if(c_max - c_min < eps)
                    %flat data -> max = min, just leave it in one class
                    histogram = numel(subjectROIMeans);
                    histCenters = c_min;
                else
                    %make centers vector
                    histCenters = c_min : cw : c_max;
                    histogram = hist(subjectROIMeans,histCenters);
                end
                out = FData.computeDescriptiveStatistics(subjectROIMeans,histogram,histCenters)';
                out(1,end+1) = out(1,end);
                out(1,end-1) = mean(this.subjectStats(~idx(:,end),end),1);
%                 out = zeros(1,size(idx,2));
%                 for i = 1:size(idx,2)
%                     out(i) = mean(this.subjectStats(~idx(:,i),i),1);
%                 end
            end
        end
        
        function out = get.statPos(this)
            out = get(this.visHandles.popupSelStatParam,'Value');
        end
        
        function out = get.classWidth(this)
            out = abs(str2double(get(this.visHandles.editClassWidth,'String')));
        end
        
        function dTypeNr = get.id(this)
            dTypeNr = [];
            out = get(this.visHandles.popupSelFLIMParam,'String');
            if(~ischar(out))
                [~, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(out{get(this.visHandles.popupSelFLIMParam,'Value')});
                dTypeNr = dTypeNr(1);
            end 
        end
        
        function out = get.exportModeFLIM(this)
            out = get(this.visHandles.popupSelExportFLIM,'Value');
        end
        
        function out = get.exportModeStat(this)
            out = get(this.visHandles.checkExportStatsHist,'Value');
        end  
        
        function out = get.exportNormDistTests(this)
            out = get(this.visHandles.checkExportNormalTests,'Value');
        end
        
        function out = get.exportSubjectRawData(this)
            out = get(this.visHandles.checkExportSubjectData,'Value');
        end
        
        function out = get.exportModeROI(this)
            out = get(this.visHandles.popupSelExportROI,'Value');
        end
        
        function out = get.exportModeCh(this)
            out = get(this.visHandles.popupSelExportCh,'Value');
        end
        
        function out = get.exportModeCondition(this)
            out = get(this.visHandles.popupSelExportCondition,'Value');
        end
                
        function out = get.currentSheetName(this)
            %build current sheet name
            out = '';      
            if(get(this.visHandles.checkSNCondition,'Value'))
                out = this.condition;
                if(strcmp(out,FDTree.defaultConditionName()))
                    out = '';
                else
                    out = [out '_'];
                end
            end
            if(get(this.visHandles.checkSNROI,'Value'))
                rt = this.ROIType;
                rtStr = ROICtrl.ROIType2ROIItem(rt);
                if(this.visHandles.checkDisplayAllROIs.Value)
                    rtStr = deblank(strtok(rtStr,'#'));
                end
                if(rt > FDTStudy.roiBaseETDRS && rt < FDTStudy.roiBaseRectangle)
                    str = this.visHandles.popupSelROISubType.String;
                    out = [out str{this.ROISubType} '_']; %[out rtStr str{this.ROISubType} '_']
                else
                    out = [out rtStr '_'];
                end
            end
            if(get(this.visHandles.checkSNCh,'Value'))
                out = [out sprintf('ch%d_',this.ch)];
            end
            if(get(this.visHandles.checkSNFLIM,'Value'))
                out = [out sprintf('%s%d_',this.dType,this.id)];
            end
            if(isempty(out))
                out = 'sheetName';
            else
                out(end) = ''; %remove trailing '_'
                out = out(1:min(length(out),31)); %sheet name is limited to 31 characters
            end
        end
        
        function out = get.ROIType(this)
            str = this.visHandles.popupSelROIType.String;
            nr = this.visHandles.popupSelROIType.Value;
            if(iscell(str))
                str = str{nr};
            elseif(ischar(str))
                %nothing to do
            else
                %should not happen
            end
            if(strncmp(str,'Group: ',7))
                %this is a group
                idx = strncmp(this.visHandles.popupSelROIType.String,'Group: ',7);
                grps = this.visHandles.popupSelROIType.String(idx);
                out = -1*find(strcmp(grps,str),1,'first');
            else
                out = ROICtrl.ROIItem2ROIType(str);
            end
        end
        
        function out = get.ROISubType(this)
            out = get(this.visHandles.popupSelROISubType,'Value');
        end
        
        function out = get.ROIVicinityFlag(this)
            out = get(this.visHandles.popupSelROIVicinity,'Value');
        end
        
        function allROT = get.allROITypes(this)
            ds1 = this.visObj.fdt.getAllSubjectNames(this.study,this.condition);
            if(~isempty(ds1))
                allROT = this.visObj.fdt.getResultROICoordinates(this.study,ds1{1},this.dType,[]);
                if(isempty(allROT))
                    allROT = ROICtrl.getDefaultROIStruct();
                end
                allROT = [0;allROT(:,1,1)];
            else
                allROT = 0;
            end
        end
        
        function out = get.alpha(this)
            %get current alpha value
            out = abs(str2double(get(this.visHandles.editAlpha,'string')))/100;
        end
    end %methods
    
    methods(Access = protected)
        function toggleGUIControls(this,flag)
            %disable or enable GUI elements, e.g. during export
            persistent oldSNCondition oldSNROI oldSNCh oldSNFLIM
            if(isempty(oldSNCondition))
                oldSNCondition = 'On';
            end
            if(isempty(oldSNROI))
                oldSNROI = 'On';
            end
            if(isempty(oldSNCh))
                oldSNCh = 'On';
            end
            if(isempty(oldSNFLIM))
                oldSNFLIM = 'On';
            end
            this.visHandles.popupSelStudy.Enable = flag;
            this.visHandles.popupSelCondition.Enable = flag;
            this.visHandles.popupSelFLIMParam.Enable = flag;
            this.visHandles.popupSelCh.Enable = flag;
            this.visHandles.popupSelExportCondition.Enable = flag;
            this.visHandles.popupSelExportROI.Enable = flag;
            this.visHandles.popupSelExportCh.Enable = flag;
            this.visHandles.popupSelExportFLIM.Enable = flag;
            this.visHandles.checkExportStatsHist.Enable = flag;
            this.visHandles.checkExportNormalTests.Enable = flag;
            this.visHandles.checkExportSubjectData.Enable = flag;
            this.visHandles.popupSelROIType.Enable = flag;
            this.visHandles.popupSelROISubType.Enable = flag;
            this.visHandles.popupSelROIVicinity.Enable = flag;
            this.visHandles.popupSelStatParam.Enable = flag;
            this.visHandles.editClassWidth.Enable = flag;
            this.visHandles.editAlpha.Enable = flag;
            this.visHandles.buttonUpdateGUI.Enable = flag;
            if(strcmpi(flag,'off'))
                %save old state
                oldSNCondition = this.visHandles.checkSNCondition.Enable;
                oldSNROI = this.visHandles.checkSNROI.Enable;
                oldSNCh = this.visHandles.checkSNCh.Enable;
                oldSNFLIM = this.visHandles.checkSNFLIM.Enable;
                this.visHandles.checkSNCondition.Enable = flag;
                this.visHandles.checkSNROI.Enable = flag;
                this.visHandles.checkSNCh.Enable = flag;
                this.visHandles.checkSNFLIM.Enable = flag;
            else
                %restore old state
                this.visHandles.checkSNCondition.Enable = oldSNCondition;
                this.visHandles.checkSNROI.Enable = oldSNROI;
                this.visHandles.checkSNCh.Enable = oldSNCh;
                this.visHandles.checkSNFLIM.Enable = oldSNFLIM;
            end
        end
    end
    
    methods(Static)
        function [h,p] = test4NormalDist(test,data,alpha)
            %test group data for normal distribution
            h = 1; p = 0;
            data = data(~isnan(data));
            data = data(~isinf(data));
            if(~any(data(:)) || length(data) < 4)
                return
            end
            switch test
                case 'li' %Lilliefors test
                    [h,p] = lillietest(data,'Alpha',alpha);
                case 'ks' %kolmogorov smirnov test
                    %center data for ks test
                    if(var(data(:)) >= eps)
                        tmp = data(:);
                        tmp = (tmp-mean(tmp(:)))/std(tmp);
                        [h,p] = kstest(tmp,'Alpha',alpha);
                    end
                case 'sw' %shapiro-wilk test
                    if(var(data(:)) >= eps)
                        [h,p] = swtest(data,alpha);
                    end
            end
        end
        
    end %static
end %class
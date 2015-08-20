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
        visObj = []; %handle to FLIMVis
        stats = cell(0,0);
        statsDesc = cell(0,0);
        subjectDesc = cell(0,0);
        statHist = [];
        statCenters = [];
        dispView = [-10 25];
    end
    properties (Dependent = true)
        study = '';
        view = '';
        ch = 1;
        dType = '';
        totalDTypes = 0;
        statType = '';
        statPos = 1;
        totalStatTypes = 0;
        id = 0;
        classWidth = 1;
        exportModeFLIM = 1;
        exportModeROI = 1;
        exportModeStat = 0;
        exportModeCh = 1;
        currentSheetName = '';
        ROIType = 1;
        ROISubType = 1;
        ROIInvertFlag = 0;
    end
    
    methods
        function this = StatsDescriptive(visObj)
            %constructor for StatsDescriptive
            this.visObj = visObj;
        end
        
        function createVisWnd(this)
            %make a new window
            this.visHandles = StatsDescriptiveFigure();
            set(this.visHandles.menuExit,'Callback',@this.menuExit_Callback);
            %set callbacks
            set(this.visHandles.popupSelStudy,'Callback',@this.GUI_SelStudyPop_Callback);
            set(this.visHandles.popupSelView,'Callback',@this.GUI_SelViewPop_Callback);
            set(this.visHandles.popupSelCh,'Callback',@this.GUI_SelChPop_Callback);
            set(this.visHandles.popupSelFLIMParam,'Callback',@this.GUI_SelFLIMParamPop_Callback);
            set(this.visHandles.popupSelROIType,'Callback',@this.GUI_SelROITypePop_Callback);
            set(this.visHandles.popupSelROISubType,'Callback',@this.GUI_SelROITypePop_Callback);
            set(this.visHandles.popupSelStatParam,'Callback',@this.GUI_SelStatParamPop_Callback);
            %export
            set(this.visHandles.buttonExportExcel,'Callback',@this.GUI_buttonExcelExport_Callback);
            set(this.visHandles.checkSNFLIM,'Callback',@this.GUI_checkExcelExport_Callback);
            set(this.visHandles.checkSNROI,'Callback',@this.GUI_checkExcelExport_Callback);
            set(this.visHandles.checkSNCh,'Callback',@this.GUI_checkExcelExport_Callback);
            set(this.visHandles.popupSelExportFLIM,'Callback',@this.GUI_popupSelExportFLIM_Callback);
            set(this.visHandles.popupSelExportROI,'Callback',@this.GUI_popupSelExportROI_Callback);
            set(this.visHandles.popupSelExportCh,'Callback',@this.GUI_popupSelExportCh_Callback);
            %display
            set(this.visHandles.buttonUpdateGUI,'Callback',@this.GUI_buttonUpdateGUI_Callback);
            %table callback
            axis(this.visHandles.axesBar,'off');
            set(this.visHandles.popupSelStatParam,'String',FData.getDescriptiveStatisticsDescription(),'Value',1);
        end
        
        function checkVisWnd(this)
            %
            if(isempty(this.visHandles) || ~ishandle(this.visHandles.StatsDescriptiveFigure) || ~strcmp(get(this.visHandles.StatsDescriptiveFigure,'Tag'),'StatsDescriptiveFigure'))
                %no window - open one
                this.createVisWnd();
            end
            this.GUI_SelFLIMParamPop_Callback(this.visHandles.popupSelFLIMParam,[]); %will call setupGUI
            figure(this.visHandles.StatsDescriptiveFigure);
        end
        
        function setCurrentStudy(this,studyName,view)
            %set the GUI to a certain study and view
            if(isempty(this.visHandles) || ~ishandle(this.visHandles.StatsDescriptiveFigure) || ~strcmp(get(this.visHandles.StatsDescriptiveFigure,'Tag'),'StatsDescriptiveFigure'))
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
            %find view
            idx = find(strcmp(get(this.visHandles.popupSelView,'String'),view),1);
            if(isempty(idx))
                return
            end
            set(this.visHandles.popupSelView,'Value',idx);
        end 
        
        %% GUI callbacks
        function GUI_SelStudyPop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_SelViewPop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_SelChPop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_SelFLIMParamPop_Callback(this,hObject,eventdata)
            %
            [cw, ~, ~, ub] = getHistParams(this.visObj.getStatsParams(),this.ch,this.dType,this.id);
            set(this.visHandles.editClassWidth,'String',cw);
            this.setupGUI();
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
        
        function GUI_buttonUpdateGUI_Callback(this,hObject,eventdata)
            %
            try
                set(hObject,'String',sprintf('<html><img src="file:/%s"/> Update</html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            this.clearResults();
            this.updateGUI();
            set(hObject,'String','Update');
        end
        
        function GUI_DispGrpPop_Callback(this,hObject,eventdata)
            %
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
        
        function GUI_checkExcelExport_Callback(this,hObject,eventdata)
            %
            set(this.visHandles.editSNPreview,'String',this.currentSheetName);
        end
        
        function GUI_buttonExcelExport_Callback(this,hObject,eventdata)
            %
            [file,path] = uiputfile('*.xls','Export Data in Excel Fileformat...');
            if ~file ; return ; end
            try
                set(hObject,'String',sprintf('<html><img src="file:/%s"/></html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            fn = fullfile(path,file);
            switch this.exportModeFLIM
                case 1 %single (current) result                    
                    if(isempty(this.stats))
                        this.makeStats();
                        if(isempty(this.stats))
                            this.clearPlots();
                        end
                    end
                    FLIMIds = get(this.visHandles.popupSelFLIMParam,'Value');
%                     exportExcel(fn,this.stats,this.statsDesc,this.subjectDesc,...
%                         this.currentSheetName,sprintf('%s%d',this.dType,this.id));
                case 2 %all FLIM parameters
                    FLIMIds = 1:this.totalDTypes;
                    this.clearResults();
%                     for i = 1:this.totalDTypes
%                         set(this.visHandles.popupSelFLIMParam,'Value',i);
%                         this.GUI_SelFLIMParamPop_Callback(this.visHandles.popupSelFLIMParam,[]); %will call setupGUI
%                         this.updateGUI();
%                         if(isempty(this.stats))
%                             this.makeStats();
%                             if(isempty(this.stats))
%                                 continue;
%                             end
%                         end
%                         exportExcel(fn,this.stats,this.statsDesc,this.subjectDesc,...
%                             sprintf('%s%d(%s_%s)',this.dType,this.id,this.study,this.view),sprintf('%s%d',this.dType,this.id));
%                     end
            end
            switch this.exportModeROI
                case 1 %current ROI
                    ROIIds = 1;
                case 2 %all ETDRS grid ROIs
                    set(this.visHandles.popupSelROIType,'Value',1); %switch to ETDRS grid
                    this.clearResults();
                    ROIIds = 1:length(get(this.visHandles.popupSelROISubType,'String'));
            end
            switch this.exportModeCh
                case 1 %current channel
                    chIds = this.ch;
                case 2 % all channels
                    chIds = 1:length(get(this.visHandles.popupSelCh,'String'));
                    this.clearResults();
            end
            %loop over all export paramters
            for f = 1:length(FLIMIds)
                if(length(FLIMIds) > 1)
                    set(this.visHandles.popupSelFLIMParam,'Value',f);
                    this.clearResults();
                    this.GUI_SelFLIMParamPop_Callback(this.visHandles.popupSelFLIMParam,[]); %will call setupGUI
                end
                for r = 1:length(ROIIds)
                    if(length(ROIIds) > 1)
                        set(this.visHandles.popupSelROISubType,'Value',r);
                        this.clearResults();
                        this.GUI_SelROITypePop_Callback(this.visHandles.popupSelROISubType,[]); %will call setupGUI
                    end
                    for c = 1:length(chIds)
                        if(length(chIds) > 1)
                            set(this.visHandles.popupSelCh,'Value',c);
                            this.clearResults();
                            this.GUI_SelChPop_Callback(this.visHandles.popupSelCh,[]);
                        end
                        this.updateGUI();
                        if(isempty(this.stats))
                            this.makeStats();
                            if(isempty(this.stats))
                                continue;
                            end
                        end
                        exportExcel(fn,this.stats,this.statsDesc,this.subjectDesc,this.currentSheetName,sprintf('%s%d',this.dType,this.id));
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
                    end
                end
            end
                
            set(hObject,'String','Go');
        end
        
        function clearResults(this)
            %clear all current results
            this.stats = cell(0,0);
            this.statsDesc = cell(0,0);
            this.subjectDesc = cell(0,0);
            this.statHist = [];
            this.statCenters = [];
        end
        
        function clearPlots(this)
            %clear 3D plot and table
            if(~isempty(this.visHandles) && ishandle(this.visHandles.StatsDescriptiveFigure) && strcmp(get(this.visHandles.StatsDescriptiveFigure,'Tag'),'StatsDescriptiveFigure'))
                cla(this.visHandles.axesBar);
                set(this.visHandles.tableMain,'ColumnName','','RowName','','Data',[],'ColumnEditable',[]);
            end
        end
        
        function setupGUI(this)
            %setup GUI control
            if(isempty(this.visHandles) || ~(ishandle(this.visHandles.StatsDescriptiveFigure) || ~strcmp(get(this.visHandles.StatsDescriptiveFigure,'Tag'),'StatsDescriptiveFigure')))
                %no window
                return
            end
            this.clearResults();
            %update studies and views
            sStr = this.visObj.fdt.getStudyNames();
            set(this.visHandles.popupSelStudy,'String',sStr,'Value',min(length(sStr),get(this.visHandles.popupSelStudy,'Value')));
            %get views for the selected studies
            vStr = this.visObj.fdt.getStudyViewsStr(this.study);
            set(this.visHandles.popupSelView,'String',vStr,'Value',min(length(vStr),get(this.visHandles.popupSelView,'Value')));
            %update channels and parameters
            ds1 = this.visObj.fdt.getSubjectsNames(this.study,this.view);
            if(~isempty(ds1))
                chStr = this.visObj.fdt.getChStr(this.study,ds1{1});
                coStr = this.visObj.fdt.getChObjStr(this.study,ds1{1},this.ch);
            else
                chStr = [];
                coStr = 'param';
            end
            if(isempty(chStr))
                chStr = 'Ch 1';
            end
            set(this.visHandles.popupSelCh,'String',chStr,'Value',min(length(chStr),get(this.visHandles.popupSelCh,'Value')));
            %ROI
            if(this.ROIType ~= 1)
                flag = 'off';
            else
                flag = 'on';
            end
            set(this.visHandles.popupSelROISubType,'Visible',flag);
            %params
            oldPStr = get(this.visHandles.popupSelFLIMParam,'String');
            if(iscell(oldPStr))
                oldPStr = oldPStr(get(this.visHandles.popupSelFLIMParam,'Value'));
            end
            %try to find oldPStr in new pstr
            idx = find(strcmp(oldPStr,coStr),1);
            if(isempty(idx))
                idx = min(get(this.visHandles.popupSelFLIMParam,'Value'),length(coStr));
            end            
            set(this.visHandles.popupSelFLIMParam,'String',coStr,'Value',idx);
            this.clearPlots();
            %excel export sheet name preview
            set(this.visHandles.editSNPreview,'String',this.currentSheetName);
        end
        
        function updateGUI(this)
            %update tables and axes
            if(isempty(this.stats))
                this.makeStats();
                if(isempty(this.stats))
                    this.clearPlots();
                end
            end
            set(this.visHandles.tableMain,'ColumnName',this.statsDesc,'RowName',this.subjectDesc,'Data',num2cell(this.stats));
            %axes
            if(~isempty(this.statHist))
                bar(this.visHandles.axesBar,this.statCenters,this.statHist);
                %                 xlim(this.visHandles.axesBar,[1 size(this.statHist,2)]);
                %                 xlim(this.visHandles.axesBar,[1 size(this.statHist,1)]);
                %                 ticklbl = this.subjectDesc;
                %                 set(this.visHandles.axesBar,'YTickLabel',ticklbl(get(this.visHandles.axesBar,'YTick')));
                %                 ticklbl = this.statsDesc;
                %                 set(this.visHandles.axesBar,'XTickLabel',ticklbl(get(this.visHandles.axesBar,'XTick')));
                %                 view(this.visHandles.axesBar,this.dispView);
                %                 setAllowAxesRotate(this.visHandles.hrotate3d,this.visHandles.axesBar,true);
            end
        end
        
        function rotateCallback(this, eventdata, axes)
            %Executes on mouse press over axes background.
            this.setDispView(get(this.visHandles.axesBar,'View'));
        end
        
        function setDispView(this,val)
            %set display view to new value
            this.dispView = val;
        end
        
        function makeStats(this)
            %collect stats info from FDTree
            [this.stats, this.statsDesc, this.subjectDesc] = this.visObj.fdt.getStudyStatistics(this.study,this.view,this.ch,this.dType,this.id,this.ROIType,this.ROISubType,this.ROIInvertFlag,true);
            [this.statHist, this.statCenters] = this.makeHistogram(this.statPos);
        end
        
        function [statHist, statCenters] = makeHistogram(this,statsID)
            %make histogram for statsID
            statHist = []; statCenters = [];
            if(isempty(this.stats) || statsID > length(this.stats))
                return
            end
            ci = this.stats(:,statsID);
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
            statHist = hist(ci,statCenters);
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
        
        function out = get.view(this)
            out = get(this.visHandles.popupSelView,'String');
            if(~ischar(out) && ~isempty(out))
                gNr = get(this.visHandles.popupSelView,'Value');
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
        
        function out = get.dType(this)
            out = get(this.visHandles.popupSelFLIMParam,'String');
            if(~ischar(out))
                out = out{get(this.visHandles.popupSelFLIMParam,'Value')};
            end
            out = out(isstrprop(out, 'alpha'));
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
        
        function out = get.statPos(this)
            out = get(this.visHandles.popupSelStatParam,'Value');
        end
        
        function out = get.classWidth(this)
            out = abs(str2double(get(this.visHandles.editClassWidth,'String')));
        end
        
        function dTypeNr = get.id(this)
            str = get(this.visHandles.popupSelFLIMParam,'String');
            if(~ischar(str))
                str = str{get(this.visHandles.popupSelFLIMParam,'Value')};
            end
            [~, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(str);
        end
        
        function out = get.exportModeFLIM(this)
            out = get(this.visHandles.popupSelExportFLIM,'Value');
        end
        
        function out = get.exportModeStat(this)
            out = get(this.visHandles.checkExportStatsHist,'Value');
        end        
        
        function out = get.exportModeROI(this)
            out = get(this.visHandles.popupSelExportROI,'Value');
        end
        
        function out = get.exportModeCh(this)
            out = get(this.visHandles.popupSelExportCh,'Value');
        end
                
        function out = get.currentSheetName(this)
            out = '';            
            if(get(this.visHandles.checkSNROI,'Value'))
                if(this.ROIType == 1)
                    str = get(this.visHandles.popupSelROISubType,'String');
                    out = [out 'ETDRS ' str{this.ROISubType} '_'];
                else
                    str = get(this.visHandles.popupSelROIType,'String');
                    out = [out str{this.ROIType+1} '_'];
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
            out = get(this.visHandles.popupSelROIType,'Value')-1;
        end
        
        function out = get.ROISubType(this)
            out = get(this.visHandles.popupSelROISubType,'Value');
        end
        
        function out = get.ROIInvertFlag(this)
            out = 0; %get(this.visHandles.popupSelROISubType,'Value');
        end        
    end %methods    
end %class
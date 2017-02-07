classdef StatsGroupComparison < handle
    %=============================================================================================================
    %
    % @file     StatsGroupComparison.m
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
    % @brief    A class to do a statistical group comparisons using t-tests, Wilcoxon ranksum tests and the Holm-Bonferroni method
    %
    properties
        
    end
    properties(GetAccess = public, SetAccess = protected)
        visHandles = []; %structure to handles in GUI
        visObj = []; %handle to FLIMVis
        grpNames = cell(0,0);
        grpData = cell(0,0); %data for statistics (except holm-bonferroni)
        histograms = cell(0,0);
        histogramSum = cell(0,0);
        histogramDiff = [];
        histCenters = []; %centers
        columnIgnore = false(0,0); %ignored columns (too few values / zero)
        pValues = []; %p values from wilcoxon test
        threshold = []; %threshold for significance
        significance = []; %vector of significant differences
        pIdx = [];
        dispView = [-10 25];
        rocData = []; %data of ROC
        settings = []; %struct to save visualisation paramters
    end
    properties (Dependent = true)
        study1 = '';
        study2 = '';
        view1 = '';
        view2 = '';
        currentGrp = '';
        currentGrpIdx = 0;
        currentRowHeaders = cell(0,0);
        currentColumnHeaders = cell(0,0);
        ch = 1;
        dType = '';
        id = 0;
        alpha = 0.05;
        sortP = true;
        HistSumScale = 1;
        ROIType = 1;
        ROISubType = 1;
        ROIInvertFlag = 0;
    end
    
    methods
        function this = StatsGroupComparison(visObj)
            %constructor for StatsHolmWilcoxon
            this.visObj = visObj;
            this.settings.screenshot = false; %flag to signalize if screenshot is produced (for 3D axes rotate)
            this.settings.colorPath = [1 0 0];  
            this.settings.colorControls = [0 1 0];
            this.settings.colorSigClass = [0.8 0.8 0.8];
            this.settings.colorMostSigClass = [0.4 0.4 0.4];
            
        end
        
        function createVisWnd(this)
            %make a new window for study management
            this.visHandles = StatsGroupComparisonFigure();
            %menu callback
            set(this.visHandles.menuExit,'Callback',@this.menuExit_Callback);
            set(this.visHandles.menuExcel,'Callback',@this.menuExcelExport_Callback);
            set(this.visHandles.menuAllExcel,'Callback',@this.menuExcelExportAllParams_Callback);
            set(this.visHandles.menuSSRocCurve,'Callback',@this.menuScreenshot_Callback);
            set(this.visHandles.menuSSRocTable,'Callback',@this.menuScreenshot_Callback);
            set(this.visHandles.menuSSSumGrps,'Callback',@this.menuScreenshot_Callback);
            set(this.visHandles.menuSSDiffGrps,'Callback',@this.menuScreenshot_Callback);
            %set callbacks
            set(this.visHandles.popupSelStudy1,'Callback',@this.GUI_SelStudy1Pop_Callback);
            set(this.visHandles.popupSelStudy2,'Callback',@this.GUI_SelStudy2Pop_Callback);
            set(this.visHandles.popupSelView1,'Callback',@this.GUI_SelView1Pop_Callback);
            set(this.visHandles.popupSelView2,'Callback',@this.GUI_SelView2Pop_Callback);
            set(this.visHandles.buttonStudyPColor,'Callback',@this.GUI_ColorButton_Callback);
            set(this.visHandles.buttonStudyCColor,'Callback',@this.GUI_ColorButton_Callback);
            set(this.visHandles.popupSelCh,'Callback',@this.GUI_SelChPop_Callback);
            set(this.visHandles.popupSelParam,'Callback',@this.GUI_SelParamPop_Callback);                      
            set(this.visHandles.popupSelROIType,'Callback',@this.GUI_SelROITypePop_Callback);
            set(this.visHandles.popupSelROISubType,'Callback',@this.GUI_SelROITypePop_Callback);
            %test method
            set(this.visHandles.popupTestSel,'Callback',@this.GUI_TestSel_Callback);
            set(this.visHandles.editAlpha,'Callback',@this.GUI_editAlpha_Callback);  
            %display
            set(this.visHandles.buttonUpdateGUI,'Callback',@this.GUI_buttonUpdateGUI_Callback);
            set(this.visHandles.popupDispStudy,'Callback',@this.GUI_DispGrpPop_Callback);            
            %p values
            set(this.visHandles.checkNonZeroRowCnt,'Callback',@this.GUI_nonZeroRowCnt_Callback);
            set(this.visHandles.editNonZeroRowCnt,'Callback',@this.GUI_nonZeroRowCnt_Callback);
            set(this.visHandles.checkSubstractRowMax,'Callback',@this.GUI_substractRowMax_Callback);
            set(this.visHandles.editSubstractRowMax,'Callback',@this.GUI_substractRowMax_Callback);
            set(this.visHandles.checkSortP,'Callback',@this.GUI_checkSortP_Callback);
            %ROC
            set(this.visHandles.popupExtAnalysis,'Callback',@this.GUI_RocHistClass_Callback);
            set(this.visHandles.radioROC,'Callback',@this.GUI_radioROC_Callback);
            set(this.visHandles.radioCT,'Callback',@this.GUI_radioROC_Callback);
            %table callback
            set(this.visHandles.tableMain,'CellEditCallback',@this.GUI_tableMainEdit_Callback);
            axis(this.visHandles.axesSumGrps,'off');
            axis(this.visHandles.axesDiffGrps,'off');
            axis(this.visHandles.axesExtAnalysis,'off');
            %Histogram sum scale
            set(this.visHandles.popupHistSumScale,'Callback',@this.GUI_histSumScale_Callback);
            set(this.visHandles.checkHighlightSigClass,'Callback',@this.GUI_HighlightSigClass_Callback);
            set(this.visHandles.buttonSigClassColor,'Callback',@this.GUI_ColorButton_Callback);
            set(this.visHandles.buttonMostSigClassColor,'Callback',@this.GUI_ColorButton_Callback);
        end
        
        function checkVisWnd(this)
            %
            if(isempty(this.visHandles) || ~ishandle(this.visHandles.StatsGroupComparisonFigure) || ~strcmp(get(this.visHandles.StatsGroupComparisonFigure,'Tag'),'StatsGroupComparisonFigure'))
                %no window - open one
                this.createVisWnd();
            end
            this.setupGUI();
            figure(this.visHandles.StatsGroupComparisonFigure);
        end
        
        function clearResults(this)
            %clear all current results
            this.grpNames = cell(0,0);
            this.grpData = cell(0,0);
            this.histograms = cell(0,0);
            this.histCenters = [];
            this.columnIgnore = false(0,0);
            this.pValues = [];
            this.pIdx = [];
            this.rocData = [];
        end
        
        %% GUI callbacks
        function GUI_SelStudy1Pop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_SelStudy2Pop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_SelView1Pop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_SelView2Pop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_ColorButton_Callback(this,hObject,eventdata)
            %
            switch get(hObject,'Tag')
                case 'buttonStudyPColor'
                    cStr = 'colorPath';
                case 'buttonStudyCColor'
                    cStr = 'colorControls';
                case 'buttonSigClassColor'
                    cStr = 'colorSigClass';
                case 'buttonMostSigClassColor'
                    cStr = 'colorMostSigClass';                    
            end
            cs = GUI_Colorselection(this.settings.(cStr));            
            if(length(cs) == 3)
                %set new color
                this.settings.(cStr) = cs;
                this.setupGUI();
                this.updateGUI();
            end            
        end
        
        function GUI_SelChPop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_SelROITypePop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_SelParamPop_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
        end
        
        function GUI_RocHistClass_Callback(this,hObject,eventdata)
            %
            if(get(this.visHandles.popupTestSel,'Value') == 5)
                this.rocData = [];
                this.updateGUI();
            else
                this.setupGUI();
            end
        end
        
        function GUI_radioROC_Callback(this,hObject,eventdata)
            %
            switch get(hObject,'Tag')
                case 'radioROC'
                    set(this.visHandles.radioCT,'Value',~logical(get(hObject,'Value')));
                case 'radioCT'
                    set(this.visHandles.radioROC,'Value',~logical(get(hObject,'Value')));
            end
            this.updateGUI();
        end
        
        function GUI_buttonUpdateGUI_Callback(this,hObject,eventdata)
            %
            this.clearResults();
            this.updateGUI();
        end
        
        function GUI_DispGrpPop_Callback(this,hObject,eventdata)
            %
            this.updateGUI();
        end
        
        function GUI_HighlightSigClass_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
            this.updateGUI();
        end
                
        function GUI_checkSortP_Callback(this,hObject,eventdata)
            %
            this.clearResults();
            this.updateGUI();
        end
        
        function GUI_nonZeroRowCnt_Callback(this,hObject,eventdata)
            %
            if(strcmp('editNonZeroRowCnt',get(hObject,'Tag')))
                val = max(1,round(abs(str2double(get(hObject,'String')))));
                set(hObject,'String',num2str(val));
            end
            %if(get(this.visHandles.checkNonZeroRowCnt,'Value'))
            this.columnIgnore = false(0,0);
            %this.histograms = cell(0,0);
            this.pValues = cell(0,0);
            this.updateGUI();
        end
        
        function GUI_substractRowMax_Callback(this,hObject,eventdata)
            %
            if(strcmp('editSubstractRowMax',get(hObject,'Tag')))
                val = abs(str2double(get(hObject,'String')));
                set(hObject,'String',num2str(val));
            end
            %if(~(get(this.visHandles.checkSubstractRowMax,'Value') )
            this.columnIgnore = false(0,0);
            this.histograms = cell(0,0);
            this.pValues = cell(0,0);
            this.updateGUI();
        end
        
        function GUI_TestSel_Callback(this,hObject,eventdata)
            %
            this.setupGUI();
            %this.updateGUI();
        end
        
        function GUI_editAlpha_Callback(this,hObject,eventdata)
            %
            set(hObject,'String',num2str(abs(max(0.1,min(10,abs(str2double(get(hObject,'string'))))))));
            this.clearResults();
            this.updateGUI();
        end
        
        function menuExcelExport_Callback(this,hObject,eventdata)
            %
            if(isempty(this.histCenters))
                return
            end
            [file,path] = uiputfile('*.xls','Export Data in Excel Fileformat...');
            if ~file ; return ; end
            fn = fullfile(path,file);
            exportExcel(fn,this.makeExcelExortData(),[],[],...
                sprintf('%s %d(%s - %s)',this.dType,this.id,this.study1,this.study2),sprintf('%s %d (centers)',this.dType,this.id));                        
        end
        
        function menuExcelExportAllParams_Callback(this,hObject,eventdata)
            %
            if(isempty(this.histCenters))
                return
            end
            [file,path] = uiputfile('*.xls','Export Data in Excel Fileformat...');
            if ~file ; return ; end
            fn = fullfile(path,file);
            chObjStr = get(this.visHandles.popupSelParam,'String');
            whitelist = {'AmplitudePercent','Tau','Q','RAUC'};
            for i = 1:length(chObjStr)
                set(this.visHandles.popupSelParam,'Value',i);
                GUI_SelParamPop_Callback(this,this.visHandles.popupSelParam,[]);
                if(any(strcmp(whitelist, this.dType)))                    
                    exportExcel(fn,this.makeExcelExortData(),[],[],...
                        sprintf('%s %d(%s - %s)',this.dType,this.id,this.study1,this.study2),sprintf('%s %d (centers)',this.dType,this.id));
                end
            end
        end
        
        function out = makeExcelExortData(this)
            %make cell array for excel export based on current GUI            
            %get patients
            set(this.visHandles.popupDispStudy,'Value',1);
            this.updateGUI();
            if(get(this.visHandles.popupTestSel,'Value') == 5)
                tmp = this.grpNames{1};
                out = cell(length(tmp)+1,length(this.currentColumnHeaders)+1);
                out(1,2:end) = this.currentColumnHeaders;
                out(2:end,1) = tmp;
                out(2:end,2:end) = num2cell(this.histograms{1});
                %get controls
                set(this.visHandles.popupDispStudy,'Value',2);
                this.updateGUI();
                lastRow = size(out,1);
                cRows = length(this.currentRowHeaders);
                out(lastRow+1:lastRow+cRows,1) = this.currentRowHeaders;
                out(lastRow+1:lastRow+cRows,2:end) = this.getCurrentTableData();
                %roc detailed data
                this.makeROCData();
                if(~isempty(this.rocData.cutOffData))
                    out(end+2,1) = {sprintf('ROC Cut-off Point for class %d',this.histCenters(sort(this.pIdx(1))))};
                    out(end+1:end+length(this.rocData.cutOffData.tableData),1) = this.rocData.cutOffData.tableData;
                end
            else
                out = get(this.visHandles.tableExtAnalysis,'Data');                
            end
        end
        
        function GUI_tableMainEdit_Callback(this,hObject,eventdata)
            %callback function to manually set "ignored" columns
            tData = get(hObject,'Data');
            [r, c] = size(tData);
            if(eventdata.Indices(1) ~= r-3)
                tData(eventdata.Indices(1),eventdata.Indices(2)) = {eventdata.PreviousData};
                set(hObject,'Data',tData);
                return
            end
            if(isempty(this.columnIgnore))
                if(isempty(this.histograms)) %should not happen...
                    this.makeHistTables();
                end
                this.makeZeroColumns(this.histograms{this.currentGrpIdx});
            end
            this.columnIgnore(eventdata.Indices(2)) = ~this.columnIgnore(eventdata.Indices(2));
            this.updateGUI();
        end
        
        function GUI_histSumScale_Callback(this,hObject,eventdata)
            %
            this.clearResults();
            this.updateGUI();
        end
                        
        function clearPlots(this)
            %clear 3D plot and table
            if(~isempty(this.visHandles) && ishandle(this.visHandles.StatsGroupComparisonFigure) && strcmp(get(this.visHandles.StatsGroupComparisonFigure,'Tag'),'StatsGroupComparisonFigure'))                
                cla(this.visHandles.axesExtAnalysis);
                axis(this.visHandles.axesExtAnalysis,'off');
                cla(this.visHandles.axesSumGrps);
                axis(this.visHandles.axesSumGrps,'off');
                cla(this.visHandles.axesDiffGrps);
                axis(this.visHandles.axesDiffGrps,'off');
                legend(this.visHandles.axesSumGrps,'off');
                legend(this.visHandles.axesDiffGrps,'off');
                legend(this.visHandles.axesExtAnalysis,'off');
                set(this.visHandles.tableMain,'ColumnName','','RowName','','Data',[],'ColumnEditable',[]);
                set(this.visHandles.tableExtAnalysis,'ColumnName','','RowName','','Data',[],'ColumnEditable',[]);
            end
        end
        
        function setupGUI(this)
            %setup GUI control
            if(isempty(this.visHandles) || ~ishandle(this.visHandles.StatsGroupComparisonFigure) || ~strcmp(get(this.visHandles.StatsGroupComparisonFigure,'Tag'),'StatsGroupComparisonFigure'))
                %no window
                return
            end
            this.clearResults();
            %update studies and views
            sStr = this.visObj.fdt.getStudyNames();
            set(this.visHandles.popupSelStudy1,'String',sStr,'Value',min(length(sStr),get(this.visHandles.popupSelStudy1,'Value')));
            set(this.visHandles.popupSelStudy2,'String',sStr,'Value',min(length(sStr),get(this.visHandles.popupSelStudy2,'Value')));
            %get views for the selected studies
            vStr1 = this.visObj.fdt.getStudyViewsStr(this.study1);
            set(this.visHandles.popupSelView1,'String',vStr1,'Value',min(length(vStr1),get(this.visHandles.popupSelView1,'Value')));
            vStr2 = this.visObj.fdt.getStudyViewsStr(this.study2);
            set(this.visHandles.popupSelView2,'String',vStr2,'Value',min(length(vStr2),get(this.visHandles.popupSelView2,'Value')));
            dStr{1} = [this.study1 '_' this.view1];
            dStr{2} = [this.study2 '_' this.view2];
            set(this.visHandles.popupDispStudy,'String',dStr,'Value',min(length(dStr),get(this.visHandles.popupDispStudy,'Value')));
            %update channels and parameters
            ds1 = this.visObj.fdt.getSubjectsNames(this.study1,this.view1);
            if(~isempty(ds1))
                ch1 = this.visObj.fdt.getChStr(this.study1,ds1{1});
                coStr = this.visObj.fdt.getChObjStr(this.study1,ds1{1},this.ch);
            else
                ch1 = [];
                coStr = 'param';
            end
            ds2 = this.visObj.fdt.getSubjectsNames(this.study2,this.view2);
            if(~isempty(ds2))
                ch2 = this.visObj.fdt.getChStr(this.study2,ds2{1});
                coStr = intersect(coStr,this.visObj.fdt.getChObjStr(this.study2,ds2{1},this.ch));
            else
                ch2 = [];
            end
            chStr = unique([ch1; ch2]);
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
            if(isempty(coStr))
                set(this.visHandles.popupSelParam,'String','FLIM param','Value',1);
            else
                oldPStr = get(this.visHandles.popupSelParam,'String');
                if(iscell(oldPStr) && ~isempty(oldPStr))
                    oldPStr = oldPStr(get(this.visHandles.popupSelParam,'Value'));
                end
                %try to find oldPStr in new pstr
                idx = find(strcmp(oldPStr,coStr),1);
                if(isempty(idx))
                    idx = min(get(this.visHandles.popupSelParam,'Value'),length(coStr));
                end
                set(this.visHandles.popupSelParam,'String',coStr,'Value',idx);
            end
            set(this.visHandles.buttonStudyPColor,'Backgroundcolor',this.settings.colorPath);
            set(this.visHandles.buttonStudyCColor,'Backgroundcolor',this.settings.colorControls);
            set(this.visHandles.buttonSigClassColor,'Backgroundcolor',this.settings.colorSigClass);
            set(this.visHandles.buttonMostSigClassColor,'Backgroundcolor',this.settings.colorMostSigClass);
            this.clearPlots();
            %statistics method selection
            if(get(this.visHandles.popupTestSel,'Value') == 5)
                set(this.visHandles.ExtendedAnalysisPanel,'Title','ROC Analysis');
                set(this.visHandles.menuSSRocCurve,'Label','ROC Curve');
                set(this.visHandles.textExtPopup,'String','Histogram Class');
                set(this.visHandles.popupExtAnalysis,'String','1','Value',1);
                holmVisFlag = 'on';
            else
                set(this.visHandles.ExtendedAnalysisPanel,'Title','Test Results');
                set(this.visHandles.menuSSRocCurve,'Label','Box Plots');
                set(this.visHandles.textExtPopup,'String','Data Source');
                set(this.visHandles.popupExtAnalysis,'String',{'raw','mean','median'},'Value',min(get(this.visHandles.popupExtAnalysis,'Value'),3));
                holmVisFlag = 'off';
            end
            if(get(this.visHandles.checkHighlightSigClass,'Value'))
                enFlag = 'on';                
            else
                enFlag = 'off';
            end
%             set(this.visHandles.textExtPopup,'Visible','on');
%             set(this.visHandles.popupExtAnalysis,'Visible','on');
            set(this.visHandles.textROCDiagramType,'Visible',holmVisFlag);
            set(this.visHandles.radioROC,'Visible',holmVisFlag);
            set(this.visHandles.radioCT,'Visible',holmVisFlag);
            set(this.visHandles.HolmPrefsPanel,'Visible',holmVisFlag);            
            set(this.visHandles.checkHighlightSigClass,'Visible',holmVisFlag);
            set(this.visHandles.buttonSigClassColor,'Enable',enFlag,'Visible',holmVisFlag);
            set(this.visHandles.buttonMostSigClassColor,'Enable',enFlag,'Visible',holmVisFlag);
            set(this.visHandles.textMostSigClassColor,'Enable',enFlag,'Visible',holmVisFlag);            
            set(this.visHandles.menuSSRocTable,'Visible',holmVisFlag);
        end
        
        function updateGUI(this)
            %update tables and axes            
            try
                set(this.visHandles.buttonUpdateGUI,'String',sprintf('<html><img src="file:/%s"/> Update</html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            tData = this.getCurrentTableData();
            this.clearPlots();
            if(isempty(tData))
                set(this.visHandles.buttonUpdateGUI,'String','Update');
                return
            end
            if(get(this.visHandles.popupDispStudy,'Value') == 1)
                %pathology group
                backColor = this.settings.colorPath;
            else
                backColor = this.settings.colorControls;
            end
            if(sum(backColor(:)) < 1.5)
                textColor = [1 1 1];
            else
                textColor = [0 0 0];
            end
            set(this.visHandles.popupDispStudy,'Backgroundcolor',backColor,'ForegroundColor',textColor);
            cEdit = true(1,size(tData,2));
            if(length(cEdit) > 10000)
                button = questdlg(sprintf('%d classes have been computed. This will consume a lot of RAM and the GUI will be very slow! Please increase class width.\n\nContinue?',length(cEdit)),'Too many classes','Yes','No','No');
                if(strcmp(button,'No'))
                    set(this.visHandles.buttonUpdateGUI,'String','Update');
                    return
                end
            end
            set(this.visHandles.tableMain,'ColumnName',this.currentColumnHeaders,'RowName',this.currentRowHeaders,'Data',tData,'ColumnEditable',cEdit);
            %h = this.histograms{this.currentGrpIdx};
            %histogram plot
            histData = this.histograms{this.currentGrpIdx};
            histIdxStart = find(~this.columnIgnore,1,'first');
            histIdxEnd = find(~this.columnIgnore,1,'last');
            histData = histData(:,histIdxStart:histIdxEnd);
            grpStr = get(this.visHandles.popupDispStudy,'String');
            if(~isempty(histData))                
                xTicklbl = [];
                %                 yTicklbl = [];
                %                 if(size(histData,1) > 1)
                %                     yTicklbl = this.currentRowHeaders;
                %                 end
                if(size(histData,2) > 1)
                    xTicklbl = num2cell(this.histCenters);
                    xTicklbl = xTicklbl(histIdxStart:histIdxEnd);
                end
                %sum of histograms plot
                if(this.settings.screenshot)
                    lw = this.visObj.exportParams.plotLinewidth;
                else
                    lw = 2;
                end
                hDiffMin = min(this.histogramDiff(histIdxStart:histIdxEnd));
                hDiffMax = max(this.histogramDiff(histIdxStart:histIdxEnd));
                hSumMin = min([this.histogramSum{1}(histIdxStart:histIdxEnd), this.histogramSum{2}(histIdxStart:histIdxEnd)]);
                hSumMax = max([this.histogramSum{1}(histIdxStart:histIdxEnd), this.histogramSum{2}(histIdxStart:histIdxEnd)]);
                if(abs(hDiffMin - hDiffMax) < eps)
                    hDiffMax = hDiffMax + eps + abs(hDiffMax)*0.1;
                end
                if(abs(hSumMin - hSumMax) < eps)
                    hSumMax = hSumMax + eps + abs(hSumMax)*0.1;
                end
                cla(this.visHandles.axesSumGrps);
                cla(this.visHandles.axesDiffGrps);
                hold(this.visHandles.axesSumGrps,'on');
                hold(this.visHandles.axesDiffGrps,'on');
                if(get(this.visHandles.checkHighlightSigClass,'Value') == 1 && get(this.visHandles.popupTestSel,'Value') == 5)
                    sig = find(this.significance(histIdxStart:histIdxEnd) & ~this.columnIgnore(histIdxStart:histIdxEnd));
                    pV = this.pValues(histIdxStart:histIdxEnd);
                    pV = pV(sig);
                    [~,pMinIdx] = min(pV(:));
                    %highlight significant classes
                    for i = 1:length(sig)
                        if(i==pMinIdx)
                            color = this.settings.colorMostSigClass;
                        else
                            color = this.settings.colorSigClass;
                        end
                        rectangle('Position',[sig(i)-0.5,hSumMin,1,abs(hSumMin-hSumMax)],'FaceColor',color,'Parent',this.visHandles.axesSumGrps);
                        rectangle('Position',[sig(i)-0.5,hDiffMin,1,abs(hDiffMin-hDiffMax)],'FaceColor',color,'Parent',this.visHandles.axesDiffGrps);
                    end
                end
                plot(this.visHandles.axesSumGrps,this.histogramSum{1}(histIdxStart:histIdxEnd),'Color',this.settings.colorPath,'Linewidth',lw);
                plot(this.visHandles.axesSumGrps,this.histogramSum{2}(histIdxStart:histIdxEnd),'Color',this.settings.colorControls,'Linewidth',lw);
                hold(this.visHandles.axesSumGrps,'off');
                %diff grps
                plot(this.visHandles.axesDiffGrps,this.histogramDiff(histIdxStart:histIdxEnd),'Linewidth',lw,'Color',[0 0 0]);
                hold(this.visHandles.axesDiffGrps,'off');
                if(histIdxEnd-histIdxStart < eps)
                    histIdxEnd = histIdxEnd+0.1;
                end
                xlim(this.visHandles.axesSumGrps,[1 histIdxEnd-histIdxStart+1]);%length(this.histogramSum{1})
                xlim(this.visHandles.axesDiffGrps,[1 histIdxEnd-histIdxStart+1]);%length(this.histogramDiff)
                ylim(this.visHandles.axesDiffGrps,[hDiffMin hDiffMax]);
                ylim(this.visHandles.axesSumGrps,[hSumMin hSumMax]);
                if(this.settings.screenshot)
                    legend(this.visHandles.axesSumGrps,grpStr);
                    title(this.visHandles.axesSumGrps,'Normalized Group Histograms');
                    title(this.visHandles.axesDiffGrps,'Difference of Group Histograms');
                    xlabel(this.visHandles.axesSumGrps,sprintf('%s %d',this.dType,this.id));
                    xlabel(this.visHandles.axesDiffGrps,sprintf('%s %d',this.dType,this.id));
                else
                    legend(this.visHandles.axesSumGrps,'off');
                    legend(this.visHandles.axesDiffGrps,'off');
                    title(this.visHandles.axesSumGrps,'remove');
                    title(this.visHandles.axesDiffGrps,'remove');
                    xlabel(this.visHandles.axesSumGrps,sprintf('%s %d',this.dType,this.id));
                    xlabel(this.visHandles.axesDiffGrps,sprintf('%s %d',this.dType,this.id));
                    %                     set(this.visHandles.sumGrpsText,'String',sprintf('Normalized sum of histograms of %s and %s',grpStr{1},grpStr{2}));
                    %                     set(this.visHandles.diffGrpsText,'String',sprintf('Difference of %s and %s',grpStr{1},grpStr{2}));
                end
                %labels
                axis(this.visHandles.axesSumGrps,'on');
                axis(this.visHandles.axesDiffGrps,'on');
                set(this.visHandles.axesSumGrps,'XTickMode','auto');
                set(this.visHandles.axesDiffGrps,'XTickMode','auto');
                if(~isempty(xTicklbl))
                    xtick = unique(fix(get(this.visHandles.axesSumGrps,'XTick')));
                    set(this.visHandles.axesSumGrps,'XTick',xtick,'XTickLabel',xTicklbl(xtick));
                    xtick = unique(fix(get(this.visHandles.axesDiffGrps,'XTick')));
                    set(this.visHandles.axesDiffGrps,'XTick',xtick,'XTickLabel',xTicklbl(xtick));
                end
                if(get(this.visHandles.popupTestSel,'Value') ~= 5)
                    [h,p,ci,stats] = this.makeSimpleGroupStats();                    
                    tmp = cell(3,2);                    
                    tmp{1,1} = 'Null Hypothesis';
                    switch get(this.visHandles.popupTestSel,'Value')
                        case 1 %One-sample paired t-test
                            tmp{1,2} = 'PATHOLOGIC - CONTROLS comes from a normal distribution with mean equal to zero and unknown variance';
                        case 2 %Two-sample paired t-test
                            tmp{1,2} = 'PATHOLOGIC and CONTROLS come from independent random samples from normal distributions with equal means and equal but unknown variances';
                        case 3 %Wilcoxon signed rank test
                            tmp{1,2} = 'PATHOLOGIC - CONTROLS comes from a distribution with zero median';
                        case 4 %Wilcoxon rank sum test  
                            tmp{1,2} = 'PATHOLOGIC and CONTROLS are samples from continuous distributions with equal medians';
                    end
                    tmp{2,1} = 'Decision';
                    if(h)
                        tmp{2,2} = 'null hypothesis rejected';
                    else
                        tmp{2,2} = 'null hypothesis NOT rejected';
                    end
                    tmp{3,1} = 'p Value';
                    tmp{3,2} = num2str(p,5);
                    if(~isempty(ci))
                        tmp{4,1} = 'Confidence Interval';
                        tmp{4,2} = num2str(ci(:)');
                    end
                    tmp(end+1,1) = cell(1,1);
                    fn = fieldnames(stats);
                    for i = 1:length(fn)
                        tmp(end+1,1) = fn(i);
                        tmp{end,2} = num2str(stats.(fn{i}));
                    end
                    tmp(end+1,1) = cell(1,1);
                    %some descriptive statistics
                    vals = FLIMXFitGUI.num4disp([mean(this.grpData{1}),std(this.grpData{1}),mean(this.grpData{2}),std(this.grpData{2})]);
                    if(length(vals) == 4)
                        tmp{end+1,1} = 'Mean PATHOLOGIC';
                        tmp{end,2} = sprintf('%s %s %s',vals{1},char(177),vals{2});
                        tmp{end+1,1} = 'Mean CONTROLS';
                        tmp{end,2} = sprintf('%s %s %s',vals{3},char(177),vals{4});
                        tmp(end+1,1) = cell(1,1);
                    end
                    %test for normal distribution
                    %Lilliefors test
                    tmp2 = cell(7,2);
                    tmp2{1,1} = 'Normal Distribution'; tmp2{1,2} = 'Lilliefors';
                    tmp2{2,1} = 'Null Hypothesis'; 
                    tmp2{2,2} = 'Group data comes from a standard normal distribution, against the alternative that it does not come from such a distribution';                    
                    [hP,pP] = StatsDescriptive.test4NormalDist('li',this.grpData{1},this.alpha);
                    [hC,pC] = StatsDescriptive.test4NormalDist('li',this.grpData{2},this.alpha);
                    tmp2{3,1} = 'Decision PATHOLOGIC';
                    if(hP)
                        tmp2{3,2} = 'null hypothesis rejected';
                    else
                        tmp2{3,2} = 'null hypothesis NOT rejected';
                    end
                    tmp2{4,1} = 'p Value PATHOLOGIC';
                    tmp2{4,2} = num2str(pP,5);
                    tmp2{5,1} = 'Decision CONTROLS';
                    if(hC)
                        tmp2{5,2} = 'null hypothesis rejected';
                    else
                        tmp2{5,2} = 'null hypothesis NOT rejected';
                    end
                    tmp2{6,1} = 'p Value CONTROLS';
                    tmp2{6,2} = num2str(pC,5);
                    tmp2{7,1} = ''; tmp2{7,2} = ''; 
                    tmp(end+1:end+7,:) = tmp2;
                    %Shapiro-Wilk
                    tmp2{1,2} = 'Shapiro-Wilk';
                    tmp2{2,2} = 'The Shapiro-Wilk and Shapiro-Francia null hypothesis is: "group data is normal with unspecified mean and variance."';                    
                    [hP,pP] = StatsDescriptive.test4NormalDist('sw',this.grpData{1},this.alpha);
                    [hC,pC] = StatsDescriptive.test4NormalDist('sw',this.grpData{2},this.alpha);
                    if(hP)
                        tmp2{3,2} = 'null hypothesis rejected';
                    else
                        tmp2{3,2} = 'null hypothesis NOT rejected';
                    end
                    tmp2{4,2} = num2str(pP,5);
                    if(hC)
                        tmp2{5,2} = 'null hypothesis rejected';
                    else
                        tmp2{5,2} = 'null hypothesis NOT rejected';
                    end
                    tmp2{6,2} = num2str(pC,5);
                    tmp2{7,1} = ''; tmp2{7,2} = ''; 
                    tmp(end+1:end+7,:) = tmp2;                    
                    %Kolmogorov-Smirnov
                    tmp2 = cell(7,2);
                    tmp2{1,1} = 'Normal Distribution'; tmp2{1,2} = 'Kolmogorov-Smirnov';
                    tmp2{2,1} = 'Null Hypothesis'; 
                    tmp2{2,2} = 'Group data comes from a standard normal distribution, against the alternative that it does not come from such a distribution';                    
                    [hP,pP] = StatsDescriptive.test4NormalDist('ks',this.grpData{1},this.alpha);
                    [hC,pC] = StatsDescriptive.test4NormalDist('ks',this.grpData{2},this.alpha);
                    tmp2{3,1} = 'Decision PATHOLOGIC';
                    if(hP)
                        tmp2{3,2} = 'null hypothesis rejected';
                    else
                        tmp2{3,2} = 'null hypothesis NOT rejected';
                    end
                    tmp2{4,1} = 'p Value PATHOLOGIC';
                    tmp2{4,2} = num2str(pP,5);
                    tmp2{5,1} = 'Decision CONTROLS';
                    if(hC)
                        tmp2{5,2} = 'null hypothesis rejected';
                    else
                        tmp2{5,2} = 'null hypothesis NOT rejected';
                    end
                    tmp2{6,1} = 'p Value CONTROLS';
                    tmp2{6,2} = num2str(pC,5);
                    tmp2{7,1} = ''; tmp2{7,2} = ''; 
                    tmp(end+1:end+7,:) = tmp2;
                    
                    set(this.visHandles.tableExtAnalysis,'Data',tmp,'ColumnWidth',{120 700});
                    if(~isempty(this.grpData))
                        boxplot(this.visHandles.axesExtAnalysis,[this.grpData{1}; this.grpData{2}],[zeros(length(this.grpData{1}),1); ones(length(this.grpData{2}),1)],'labels',{'PATHOLOGIC';'CONTROLS'});                        
                    end
                else
                    %Holm-Bonferroni -> roc
                    set(this.visHandles.popupExtAnalysis,'String',this.currentColumnHeaders,'Value',min(get(this.visHandles.popupExtAnalysis,'Value'),size(histData,2)));
                    if(~isempty(this.rocData))
                        if(get(this.visHandles.radioROC,'Value'))
                            %ROC plot
                            if(~this.settings.screenshot)
                                lw = 0.5;
                            end
                            HR1=plot(this.visHandles.axesExtAnalysis,this.rocData.xr,this.rocData.yr,'r.-','Linewidth',lw);
                            hold(this.visHandles.axesExtAnalysis,'on');
                            HRC1=plot(this.visHandles.axesExtAnalysis,[0 1],[0 1],'k','Linewidth',lw);
                            plot(this.visHandles.axesExtAnalysis,[0 1],[1 0],'g','Linewidth',lw)
                            if(~isempty(this.rocData.cutOffPos))
                                HCO1=plot(this.visHandles.axesExtAnalysis,this.rocData.cutOffPos(1),this.rocData.cutOffPos(2),'bo','Linewidth',lw);
                            else
                                HCO1 = [];
                            end
                            hold(this.visHandles.axesExtAnalysis,'off');
                            %title(this.visHandles.axesExtAnalysis,'ROC curve')
                            axis(this.visHandles.axesExtAnalysis,'square');
                            xlabel(this.visHandles.axesExtAnalysis,'False positive rate (1-Specificity)','Fontsize',get(this.visHandles.popupSelStudy1,'Fontsize'),'Fontname',get(this.visHandles.popupSelStudy1,'Fontname'));
                            ylabel(this.visHandles.axesExtAnalysis,'True positive rate (Sensitivity)','Fontsize',get(this.visHandles.popupSelStudy1,'Fontsize'),'Fontname',get(this.visHandles.popupSelStudy1,'Fontname'));
                            legend(this.visHandles.axesExtAnalysis,[HR1,HRC1,HCO1],this.rocData.legend,'Location','eastoutside');
                        else
                            %cut off point plot
                            if(~isempty(this.rocData.cutOffData))
                                dData = this.rocData.cutOffData.diagrams;
                                cla(this.visHandles.axesExtAnalysis);
                                %code below adapted from partest.m
                                color={'r','g','y','b'};
                                %graph
                                hold(this.visHandles.axesExtAnalysis,'on');
                                for i=1:4
                                    fill(dData.(sprintf('rect%dx',i)),dData.(sprintf('rect%dy',i)),color{i},'Parent',this.visHandles.axesExtAnalysis);
                                end
                                hold(this.visHandles.axesExtAnalysis,'off');
                                axis(this.visHandles.axesExtAnalysis,'on');
                                axis(this.visHandles.axesExtAnalysis,'square');
                                %title(this.visHandles.axesExtAnalysis,'Cut-off Point Graph');
                                xlabel(this.visHandles.axesExtAnalysis,'Subjects proportion','Fontsize',get(this.visHandles.popupSelStudy1,'Fontsize'),'Fontname',get(this.visHandles.popupSelStudy1,'Fontname'));
                                ylabel(this.visHandles.axesExtAnalysis,'Parameters proportion','Fontsize',get(this.visHandles.popupSelStudy1,'Fontsize'),'Fontname',get(this.visHandles.popupSelStudy1,'Fontname'));
                                legend(this.visHandles.axesExtAnalysis,dData.legend,'Location','eastoutside');
                            end
                        end
                        set(this.visHandles.axesExtAnalysis,'Fontsize',get(this.visHandles.popupSelStudy1,'Fontsize'),'Fontname',get(this.visHandles.popupSelStudy1,'Fontname'));
                        %table
                        if(~isempty(this.rocData.cutOffData))
                            set(this.visHandles.tableExtAnalysis,'Data',this.rocData.cutOffData.tableData,'ColumnWidth',{500});
                        end
                    end
                end
            end            
            set(this.visHandles.buttonUpdateGUI,'String','Update');
        end
                
        function setDispView(this,val)
            %set display view to new value
            this.dispView = val;
        end
        
        function makeROCData(this)
            %compute receiver operating characteristic (roc)
            if(isempty(this.pIdx) || isempty(this.histograms))
                this.rocData = [];
            else
                histClass = this.pIdx(min(length(this.pIdx),get(this.visHandles.popupExtAnalysis,'Value')));
                patients = this.histograms{1};
                healthy = this.histograms{2};
                rocdata = zeros(size(patients,1)+size(healthy,1),2);
                rocdata(1:size(patients,1),1) = patients(:,histClass);
                rocdata(1:size(patients,1),2) = ones(size(patients,1),1);
                rocdata(size(patients,1)+1:end,1) = healthy(:,histClass);
                stats = this.visObj.fdt.getStudyStatistics(this.study1,this.view1,this.ch,this.dType,this.id,this.ROIType,this.ROISubType,this.ROIInvertFlag,false);
                %we simply use the ROI size of the last subject, which might be wrong, as subjects are not checked to have identical ROI sizes yet
                %also, it is quite expensive to calculate the study statistics only to get the ROI size
                this.rocData = roc(rocdata,[],[],false,stats(1,end));
            end
        end
        
        function [h,p,ci,stats] = makeSimpleGroupStats(this)
            %make group comparison based in t-test or Wilcoxon
            h = 0; p = []; ci = []; stats = [];
            str = get(this.visHandles.popupExtAnalysis,'String');
            str = str{get(this.visHandles.popupExtAnalysis,'Value')};
            if(isempty(this.grpData))                
                this.grpData{1} = this.visObj.fdt.getStudyPayload(this.study1,this.view1,this.ch,this.dType,this.id,this.ROIType,this.ROISubType,this.ROIInvertFlag,str);
                this.grpData{2} = this.visObj.fdt.getStudyPayload(this.study2,this.view2,this.ch,this.dType,this.id,this.ROIType,this.ROISubType,this.ROIInvertFlag,str);
            end
            dataP = this.grpData{1};
            dataC = this.grpData{2};
            if(~isempty(dataP) && ~isempty(dataC))
                switch get(this.visHandles.popupTestSel,'Value')
                    case 1 %One-sample paired t-test
                        if(length(dataP) ~= length(dataC))
                            stats.message = 'The data in a paired t-test must be the same size.';
                            return
                        end
                        [h,p,ci,stats] = ttest(dataP,dataC,'Alpha',this.alpha);
                    case 2 %Two-sample t-test
                        [h,p,ci,stats] = ttest2(dataP,dataC,'Alpha',this.alpha);
                    case 3 %Wilcoxon signed rank test
                        if(length(dataP) ~= length(dataC))
                            stats.message = 'The data in a signed rank test must be the same size.';
                            return
                        end
                        [p,h,stats] = signrank(dataP,dataC,'Alpha',this.alpha);
                        ci = [];
                    case 4 %Wilcoxon rank sum test  
                        [p,h,stats] = ranksum(dataP,dataC,'Alpha',this.alpha);
                        ci = [];
                end                
            end            
        end
        
        function makePValues(this)
            %perform wilcoxon ranksum test between 2 groups
            if(isempty(this.histograms))
                this.makeHistTables();
                if(isempty(this.histograms))
                    this.pValues = [];
                    this.pIdx = [];
                    return
                end
            end
            h1 = this.histograms{1};
            h2 = this.histograms{2};
            p = ones(1,length(this.histCenters));
            if(size(h1,1) > 1 && size(h2,1) > 1)
                a = this.alpha;
                hLen = length(this.histCenters);
                for i = 1:hLen
                    p(i) = ranksum(h1(:,i),h2(:,i),'alpha',a);
                end
            end
            %threshold
            if(isempty(this.columnIgnore))
                this.makeZeroColumns();
            end
            this.threshold = ones(1,length(this.histCenters)).*this.alpha/(length(this.histCenters)-sum(this.columnIgnore(:)));
            %significance
            this.significance = p < this.threshold;
            this.pValues = p;
            if(this.sortP)
                [~, this.pIdx] = sort(p);
            else
                this.pIdx = 1:1:length(p);
            end
        end
        
        function makeHistTables(this)
            %make histogram tables
            %first get the centers for all groups
            centers = unique([this.visObj.fdt.getStudyHistogram(this.study1,this.view1,this.ch,this.dType,this.id,this.ROIType,this.ROISubType,this.ROIInvertFlag)...
                this.visObj.fdt.getStudyHistogram(this.study2,this.view2,this.ch,this.dType,this.id,this.ROIType,this.ROISubType,this.ROIInvertFlag)]);
            %now insert each histogram table at the correct position
            for j = 1:2
                [grpCenters, histMerge, histTable, colDescr] = this.visObj.fdt.getStudyHistogram(eval(sprintf('this.study%d',j)),eval(sprintf('this.view%d',j)),this.ch,this.dType,this.id,this.ROIType,this.ROISubType,this.ROIInvertFlag);
                if(~isempty(grpCenters))
                    tab = zeros(length(colDescr),length(centers)); %subjects x classes
                    start = find(centers == grpCenters(1));
                    if(get(this.visHandles.checkSubstractRowMax,'Value'))
                        histTable = bsxfun(@minus,histTable,max(histTable,[],2) .* str2double(get(this.visHandles.editSubstractRowMax,'String'))/100);
                        histTable(histTable < 0) = 0;
                    end
                    tab(:,start:start+length(grpCenters)-1) = histTable;
                    this.histograms(j) = {tab};
                    this.grpNames(j) = {colDescr};
                    %normalized sum of group histogram                   
                    tab = sum(this.histograms{j},1);
                    %summenhist durch anzahl probanden teilen = mittleres
                    switch this.HistSumScale
                        case 1 %maximum
                            tab = tab./max(tab(:));
                        case 2 %number of subjects
                            tab = tab./length(colDescr);
                    end
                    this.histogramSum(j) = {tab};
                else
                    %the histogram for this group is empty, clear all related info
                    this.histograms(j) = {[]};
                    this.grpNames(j) = {[]};
                    this.histogramSum(j) = {[]};                    
                end
            end
            if(isempty(this.histograms{1}) || isempty(this.histograms{2}))
                %at least one group is empty, we can't compute the differences
                this.histCenters = [];
                this.histogramDiff = [];
            else
                this.histCenters = centers;
                this.histogramDiff = this.histogramSum{1} - this.histogramSum{2};
            end
        end
        
        function makeZeroColumns(this)
            %
            if(isempty(this.histograms))
                this.makeHistTables();
                if(isempty(this.histograms))
                    this.columnIgnore = false(0,0);
                    return
                end
            end
            if(get(this.visHandles.checkNonZeroRowCnt,'Value'))
                th = str2double(get(this.visHandles.editNonZeroRowCnt,'String'));
                h1 = this.histograms{1};
                h2 = this.histograms{2};
                h1 = sum(h1 ~= 0) <= th;
                h2 = sum(h2 ~= 0) <= th;
                this.columnIgnore = h1 & h2;
            else
                this.columnIgnore = false(1,size(this.histograms{1},2));
            end
        end
        
        function tData = getCurrentTableData(this)
            %make data for table display
            if(isempty(this.histograms))
                this.makeHistTables();
            end
            if(isempty(this.pValues))
                this.makePValues();
            end
            if(isempty(this.rocData)) %not exactly needed here
                this.makeROCData();
            end
            if(~isempty(this.pIdx))
                tData = this.histograms{this.currentGrpIdx};
                if(size(this.histograms{this.currentGrpIdx},1) == 0)
                    %empty histograms
                    tData = zeros(1,size(tData,2));
                end
                if(size(tData,2) < length(this.pIdx))
                    tData = num2cell(tData(:,this.pIdx(1:size(tData,2))));
                    uiwait(warndlg(sprintf('Number of indices of sorted p-values (%d) did NOT match histogram size (%d)!',length(this.pIdx),size(tData,2)),'Histogram Size Error','modal'));
                else
                    tData = num2cell(tData(:,this.pIdx));
                end
            else
                tData = cell(0,0);
            end
            tData(end+1,:) = cell(1,size(tData,2));
            if(get(this.visHandles.popupTestSel,'Value') == 5)
                %add ignored colums
                %columnIgnore
                if(isempty(this.columnIgnore))
                    this.makeZeroColumns();
                end
                if(~isempty(this.pIdx) && (length(this.pIdx) == length(this.columnIgnore)))
                    tData(end+1,:) = num2cell(this.columnIgnore(this.pIdx));
                end
                %p-values
                p = this.pValues;
                if(isempty(p))
                    p = cell(1,length(this.histCenters));
                else
                    p = num2cell(p(this.pIdx));
                end
                tData(end+1,:) = p;
                if(isempty(tData))
                    return
                end
                %threshold
                tData(end+1,:) = num2cell(this.threshold(this.pIdx));
                %significance
                tData(end+1,:) = num2cell(this.significance(this.pIdx));
                %sum of current group histogram
                tmp = this.histogramSum{this.currentGrpIdx};
                tData(end+1,:) = num2cell(tmp(this.pIdx));
                %difference between group histograms
                tData(end+1,:) = num2cell(this.histogramDiff(this.pIdx));
            end
        end
        
        function menuExit_Callback(this,hObject,eventdata)
            %executes on figure close
            if(~isempty(this.visHandles) && ishandle(this.visHandles.StatsGroupComparisonFigure))
                delete(this.visHandles.StatsGroupComparisonFigure);
            end
        end
        
        function menuScreenshot_Callback(this,hObject,eventdata)
           %export screenshots
            switch get(hObject,'Tag');
                case 'menuSSRocCurve'
                    axStr = 'axesExtAnalysis';
                    set(this.visHandles.radioROC,'Value',1);
                    this.GUI_radioROC_Callback(this.visHandles.radioROC,[]);
                case 'menuSSRocTable'
                    set(this.visHandles.radioROC,'Value',0);
                    this.GUI_radioROC_Callback(this.visHandles.radioROC,[]);
                    axStr = 'axesExtAnalysis';
                case 'menuSSSumGrps'
                    axStr = 'axesSumGrps';
                case 'menuSSDiffGrps'
                    axStr = 'axesDiffGrps';
                otherwise
                    return
            end            
            formats = {'*.png','Portable Network Graphics (*.png)';...
                '*.jpg','Joint Photographic Experts Group (*.jpg)';...
                '*.eps','Encapsulated Postscript (*.eps)';...
                '*.tiff','TaggedImage File Format (*.tiff)';...
                '*.bmp','Windows Bitmap (*.bmp)';...
                '*.emf','Windows Enhanced Metafile (*.emf)';...
                '*.pdf','Portable Document Format (*.pdf)';...
                '*.fig','MATLAB figure (*.fig)';...
                };
            [file, path, filterindex] = uiputfile(formats,'Export as','image.png');
            if ~path ; return ; end
            fn = fullfile(path,file);
            switch filterindex
                case 5
                    str = '-dbmp';
                case 6
                    str = '-dmeta';
                case 3
                    str = '-depsc2';
                case 2
                    str = '-djpeg';
                case 7
                    str = '-dpdf';
                case 1
                    str = '-dpng';
                case 4
                    str = '-dtiff';
            end
            %draw the screenshot
            hFig = figure; %open new figure
            hAx = axes(); %open new axes
            set(hAx,'FontSize',this.visObj.exportParams.labelFontSize);
            %save original axes handle
            hOld = this.visHandles.(axStr);
            %temporarily overwrite with new one
            this.visHandles.(axStr) = hAx;
            %draw plots
            this.settings.screenshot = true;
            this.updateGUI();
            this.settings.screenshot = false;
            %write back origonal handle
            this.visHandles.(axStr) = hOld;
            %do not stretch to fill the axes for screenshots            
            pause(1) %workaround for wrong painting
            if(filterindex == 8)
                hgsave(hFig,fn);
            else
                print(hFig,str,['-r' num2str(this.visObj.exportParams.dpi)],fn);
            end
            if(ishandle(hFig))
                close(hFig);
            end
            this.updateGUI(); %redraw without screenshot flag
        end
        
        %% dependend properties
        function out = get.study1(this)
            out = get(this.visHandles.popupSelStudy1,'String');
            if(~ischar(out) && ~isempty(out))
                gNr = get(this.visHandles.popupSelStudy1,'Value');
                out = out{min(gNr,length(out))};
            end
        end
        
        function out = get.study2(this)
            out = get(this.visHandles.popupSelStudy2,'String');
            if(~ischar(out) && ~isempty(out))
                gNr = get(this.visHandles.popupSelStudy2,'Value');
                out = out{min(gNr,length(out))};
            end
        end
        
        function out = get.view1(this)
            out = get(this.visHandles.popupSelView1,'String');
            if(~ischar(out) && ~isempty(out))
                gNr = get(this.visHandles.popupSelView1,'Value');
                out = out{min(gNr,length(out))};
            end
        end
        
        function out = get.view2(this)
            out = get(this.visHandles.popupSelView2,'String');
            if(~ischar(out) && ~isempty(out))
                gNr = get(this.visHandles.popupSelView2,'Value');
                out = out{min(gNr,length(out))};
            end
        end
        
        function out = get.currentGrp(this)
            out = get(this.visHandles.popupDispStudy,'String');
            if(~ischar(out))
                out = out(get(this.visHandles.popupDispStudy,'Value'));
            end
        end
        
        function out = get.currentGrpIdx(this)
            out = get(this.visHandles.popupDispStudy,'Value');
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
            out = get(this.visHandles.popupSelParam,'String');
            if(~ischar(out))
                [dType, ~] = FLIMXVisGUI.FLIMItem2TypeAndID(out{get(this.visHandles.popupSelParam,'Value')});
                dType = dType{1};
            end            
        end
        
        function dTypeNr = get.id(this)
            dTypeNr = [];
            out = get(this.visHandles.popupSelParam,'String');
            if(~ischar(out))
                [~, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(out{get(this.visHandles.popupSelParam,'Value')});
                dTypeNr = dTypeNr(1);
            end  
        end
        
        function out = get.sortP(this)
            %flag if group histograms should sorted by p values
            if(get(this.visHandles.popupTestSel,'Value') ~= 5)
                out = false;
            else
                out = get(this.visHandles.checkSortP,'Value');
            end
        end
        
        function out = get.currentRowHeaders(this)
            %make current row discriptions
            if(isempty(this.grpNames))
                this.makeHistTables();
            end
            out = this.grpNames{this.currentGrpIdx};
            if(get(this.visHandles.popupTestSel,'Value') == 5)
                out(end+1) = cell(1,1);
                out(end+1) = {'ignored'};
                out(end+1) = {'pValue'};
                out(end+1) = {'Threshold'};
                out(end+1) = {'significant'};
                out(end+1) = {'sum (norm.)'};
                out(end+1) = {'diff. (norm.)'};
            end
        end
        
        function out = get.currentColumnHeaders(this)
            %make current column discriptions
            if(isempty(this.histCenters))
                this.makeHistTables();
            end
            if(isempty(this.pValues))
                this.makePValues();
            end
            if(~isempty(this.pIdx))
                out = num2cell(this.histCenters(this.pIdx));
            else
                out = num2cell(this.histCenters);
            end
        end
        
        function out = get.alpha(this)
            %get current alpha value
            out = abs(str2double(get(this.visHandles.editAlpha,'string')))/100;
        end
        
        function out = get.HistSumScale(this)
            %get current histogram sum scaling; 1:by maximum, 2:by number of subjects
            out = get(this.visHandles.popupHistSumScale,'Value');
        end
        
        function out = get.ROIType(this)
            out = get(this.visHandles.popupSelROIType,'Value')-1;
        end
        
        function out = get.ROISubType(this)
            out = get(this.visHandles.popupSelROISubType,'Value');
        end
        
        function out = get.ROIInvertFlag(this)
            out = 0;%get(this.visHandles.popupSelROISubType,'Value');
        end
        
    end %methods
    
    methods(Static)
        
    end %static
    
end %class
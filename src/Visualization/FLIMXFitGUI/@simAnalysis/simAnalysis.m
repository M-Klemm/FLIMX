classdef simAnalysis < handle
    %=============================================================================================================
    %
    % @file     simAnalysis.m
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
    % @brief    A class to represent a GUI to compare simulation parameters with approximation results
    %
    properties(GetAccess = public, SetAccess = private)
        FLIMXObj = [];              %handle to flimx object
        simObj = [];                %handle to simulation object
        myResSubject = [];
        mySimSubject = [];
        paramMgrObj = [];           %handle to parameter manager        
        visHandles = [];            %structure to handles in GUI
        dynVisParams = [];          %dynamic visualization parameter
        hAx = [];                   %handle to main axes
        histAx = [];                %handle to histogram axes        
        resultNames = cell(0,0);    %names of results in export folder
        arraySubsets = cell(0,0);   %subsets of parameter set array
        arraySubsetNames = cell(0,0);     %names of subsets
        emptySubsets = [];          %indices of empty subsets        
        arrayData = [];      %combined data of parameter set array and reference data of subsets        
        selectedSubsets = [];       %indices of selected subsets
        lStr = cell(0,0);           %label string        
        chi2PlotSel = []; 
        chi2StatsSel = [];
        stop = [];
    end
    
    properties (Dependent = true)
        paraSetNames = cell(0,0);        
        fileInfo = [];
        pixelFitParams = [];
        volatileParams = [];
        preProcessParams = [];
        basicFitParams = [];
        computationParams = [];
        fluoDecayFitVisParams = [];
        about = [];        
        curStudy = '';
        curChannel = [];
        curParaSetName = [];
        curArrayName = [];
        curResultChanIsAvailable = [];        
        showArray = [];
        curParameter = [];          %id of currently selected parameter
    end
    
    methods
        function this = simAnalysis(flimX,simObj)
            %constructor for simulation analysis tool                        
            this.FLIMXObj = flimX;
            this.simObj = simObj;
            %this.paramMgrObj = paramMgr(this.FLIMXObj.configPath,this.about);
            
            this.dynVisParams.timeScalingAuto = 1;
            this.dynVisParams.timeScalingStart = 1;
            this.dynVisParams.timeScalingEnd = 1024;
            
            this.arrayData = LinkedList();
            
            this.stop = false;
        end
        
        %% input methods
%         function getFitResultNames(this,paraSetName)
%             %get names of fit results from export folder on hard drive for selected parameter set
%             if(isempty(paraSetName))
%                 return
%             end            
%             this.resultNames = cell(0,0);            
%             %load automatically from export folder
%             expDir = this.FLIMXObj.fitObj.folderParams.export;
%             subDir = fullfile(expDir,sprintf('%s',paraSetName));            
%             if(~isfolder(subDir))
%                 return
%             end            
%             dirs = dir(subDir);
%             for i = 1:length(dirs)
%                 if(dirs(i,1).isdir && ~strcmp(dirs(i,1).name,'.') && ~strcmp(dirs(i,1).name,'..'))
%                     %get only result with current channel
%                     files = dir(fullfile(subDir,dirs(i,1).name));
%                     if(~isempty(strfind(files(3,1).name,sprintf('ch%02d',this.curChannel))))
%                         this.resultNames(end+1,1) = {dirs(i,1).name};
%                         break
%                     end
%                 end
%             end
%         end
        
%         function loadParaSetNames(this)
%             %load names of parameter sets and corresponding arrays
%             %load single parameter sets and arrays
%             this.paraSetNames = cell(0,0);
%             allNames = this.FLIMXObj.sDDMgr.getAllSDDNames();            
%             for i=1:length(allNames)
%                 %find parameter sets independently from specific channel number
%                 setName = allNames{i};
%                 sdd = this.getSynthDataDef(setName);        
%                 if(isempty(sdd.arrayParentSDD))
%                     paraName = '-';
%                 else
%                     paraName = sdd.arrayParamName;
%                     setName = sdd.arrayParentSDD;
%                 end
%                 if(isempty(this.paraSetNames))
%                     tf = false;
%                 else
%                     [tf pos] = ismember(setName,this.paraSetNames(:,1));
%                 end
%                 
%                 if(~tf)
%                     %we don't have this set yet
%                     this.paraSetNames{end+1,1} = setName;   %single parameter set name
%                     arrayIDs = {paraName};
%                     this.paraSetNames{end,2} = arrayIDs;    %array ID
%                 else
%                     %set is already available, add arrayID
%                     arrayIDs = this.paraSetNames{pos,2};
%                     if(~ismember(paraName,arrayIDs))
%                         %add new array
%                         arrayIDs(end+1) = {paraName};
%                         this.paraSetNames{pos,2} = arrayIDs;
%                     end
%                 end
%             end
%         end
        
        function loadArrayParaSets(this)
            %load subsets of parameter set array (i.e. sets with same parent)
            this.arraySubsets = cell(0,0);
            this.arraySubsetNames = cell(0,0);            
%             sdd = this.getSynthDataDef(this.curParaSetName);
%             if(isempty(sdd) || isempty(sdd.arrayParentSDD))
%                 return
%             end
            [this.arraySubsets, this.arraySubsetNames] = this.FLIMXObj.sDDMgr.getArrayParamSet(this.curChannel,this.curArrayName);
            this.arraySubsetNames(:,2) = {true};
            this.emptySubsets = true(length(this.arraySubsets),1);
            for i = 1:length(this.arraySubsets)
                if(~this.resultIsAvailable(this.curStudy,this.arraySubsetNames{i,1},this.curChannel))
                    this.emptySubsets(i) = false;
                else
                    %we need a result from the array to get the approximation parameters (we assume the parameters are identical for the whole array
                    if(isempty(this.myResSubject))
                        this.loadResult(this.arraySubsetNames{i,1});                        
                    end
                end
            end           
        end
        
        function [arrayStr, arrayID] = findArrayParaSet4Study(this,study,ch)
            %find first array parameter set for study
            arrayStr = '';
            arrayID = 0;
            aStr = this.FLIMXObj.sDDMgr.getAllArrayParamSetNames(ch);            
            subjects = this.FLIMXObj.fdt.getAllSubjectNames(study,FDTree.defaultConditionName());
            if(isempty(aStr) || isempty(subjects))
                return
            end
            for arrayID = 1:length(aStr)
                arrayStr = aStr{arrayID};
                if(any(strncmp(arrayStr,subjects,length(arrayStr))))                    
                    return
                end
            end
            arrayStr = '';
            arrayID = 0;
        end
        
        function loadResult(this,paraSetName)
            %get current single result from fdtree
            if(isempty(paraSetName))
                return
            end
%             this.curFluoFileObj = this.FLIMXObj.fdt.getMeasurementObj(this.curStudy,paraSetName,this.curChannel);%fluoResultFile(this.paramMgrObj);
%             this.curResultObj = this.FLIMXObj.fdt.getResultObj(this.curStudy,paraSetName,this.curChannel);
            this.myResSubject = this.FLIMXObj.fdt.getSubject4Approx(this.curStudy,paraSetName,false);
%             if(~isempty(this.curResultObj))
%                 this.curResultObj.setIRFMgrHandle(this.FLIMXObj.irfMgr);
%                 this.curResultObj.setFluoFileHandle(this.curFluoFileObj);                
%             end
        end
        
        %% output methods
        function out = getSynthDataCh(this,name,ch)
            %get simultation parameter set by name and channel
            out = this.FLIMXObj.sDDMgr.getSDDChannel(name,ch);
        end
        
        function out = getSynthDataDef(this,name)
            %get simultation parameter set by name
            out = this.FLIMXObj.sDDMgr.getSDD(name);
        end
        
        function out = resultIsAvailable(this,study,paraSetName,ch)
            %returns true if result parameter set with channel ch is available in study
            [~, nrs] = this.FLIMXObj.fdt.getSubjectFilesStatus(study,paraSetName);
            if(any(nrs == ch))
                out = true;
            else
                out = false;
            end
        end
        
        function [pMode, pMean, pMedian, pVar, pStd, pSkew, pKurt, pCIl, pCIh, data] = computeParaStats(this,dType,dTypeNr)
            %compute statistics for corresponding parameter of current result
            %             [y x] = size(this.curResultObj.getPixelFLIMItem(this.curChannel,'Amplitude1'));
            pMode = []; pMean = []; pMedian = []; pVar = []; pStd = []; pSkew = []; pKurt = []; pCIl = []; pCIh = []; data = [];
%             if(strcmp(dType{1},'Amplitude') && (~isempty(dTypeNr) || dTypeNr > 0))
%                 data = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('AmplitudePercent%d',dTypeNr));
            if(isempty(dTypeNr) || dTypeNr == 0)
                data = this.myResSubject.getPixelFLIMItem(this.curChannel,dType{1});
            else
                data = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('%s%d',dType{1},dTypeNr));
            end
            if(isempty(data))
                return
            end
            data = data(:);
            data=data(~isnan(data));
            %compute statistical values
            pMode = mode(data);
            pMean = mean(data);
            pMedian = median(data);
            pVar = var(data);
            pStd = sqrt(pVar);
            pSkew = skewness(data);
            pKurt = kurtosis(data);
            px = numel(data);
            t = icdf('t',1-(1-0.95)/2,px-1); %confidence level 95%
            pCIl = pMedian - t*pStd/sqrt(px);
            pCIh = pMedian + t*pStd/sqrt(px);
        end
        
        function [y x] = getWorstPixel(this,chi2Sel)
            %get worst pixel according to value of chi2 or chi2 tail
            y = []; x = [];
            switch chi2Sel
                case 1 %chi2
                    data = this.myResSubject.getPixelFLIMItem(this.curChannel,'chi2');
                case 2 %chi2Tail
                    data = this.myResSubject.getPixelFLIMItem(this.curChannel,'chi2Tail');
            end
            if(isempty(data))
                return
            end
            [val y] = max(data,[],1);
            [~, x] = max(val);
            y=y(x);
        end
        
        function [y x] = getBestPixel(this,chi2Sel)
            %get best pixel according to value of chi2 or chi2 tail
            %find minimum of chi2 unequal to zero
            y = []; x = [];
            switch chi2Sel
                case 1 %chi2
                    data = this.myResSubject.getPixelFLIMItem(this.curChannel,'chi2');
                case 2 %chi2Tail
                    data = this.myResSubject.getPixelFLIMItem(this.curChannel,'chi2Tail');
            end
            if(isempty(data))
                return
            end
            data(data==0) = NaN;    %remove possible values equal to zero
            [val y] = min(data,[],1);
            [~, x] = min(val);
            y=y(x);
        end
        
        function val= getArrayRunningParameter(this)
            %get running parameter of parameter set array
            subsets = this.arraySubsets(cell2mat(this.arraySubsetNames(:,2)));
            rID = subsets{1}.arrayParamNr;
            val = zeros(1,length(subsets));
            switch rID                
                case 1 %photons
                    for i = 1:length(subsets)
                        val(i) = subsets{i}.nrPhotons;
                    end
                case 2 %offset
                    for i = 1:length(subsets)
                        val(i) = subsets{i}.offset;
                    end
                otherwise %xVec parameter
                    for i = 1:length(subsets)
                        val(i) = subsets{i}.xVec(rID-2);
                    end
            end            
        end
        
        function exportXLS(this,fn,mode)
            %export standard statistics table to excel file
            this.updateProgressbar(0.1,'Exporting Statistics to Excel File');
            tableName = sprintf('Simulation Parameter Set "%s"',this.curParaSetName);
            %export sheet for simulation parameter set
            columnHeader = get(this.visHandles.tableSimParaSet,'ColumnName');
            columnHeader = columnHeader(2:end);
            data = get(this.visHandles.tableSimParaSet,'Data');
            rowHeader = data(:,1);
            data(:,1) = [];
            sheetName = 'Simulation Parameter Set';
            exportExcel(fn,data,columnHeader,rowHeader,sheetName,tableName);
            
            %export result
            if(~this.curResultChanIsAvailable)
                return
            end
            this.updateProgressbar(0.3,'Exporting Statistics to Excel File');
            
            %export sheet for comparison with fit result
            columnHeader = get(this.visHandles.tableResultDiffs,'ColumnName');
            data = get(this.visHandles.tableResultDiffs,'Data');
            tableName = this.curParaSetName;
            sheetName = 'Comparison with Fit Result';
            exportExcel(fn,data,columnHeader,rowHeader,sheetName,tableName);
            this.updateProgressbar(0.5,'Exporting Statistics to Excel File');
            
            %export general parameters of fit result
            columnHeader = {'Value'};
            data = get(this.visHandles.tableResultStats,'Data');
            rowHeader = data(:,1);
            data(:,1) = [];
            sheetName = 'General Statistics (Fit Result)';
            exportExcel(fn,data,columnHeader,rowHeader,sheetName,tableName);
            this.updateProgressbar(0.7,'Exporting Statistics to Excel File');
            
            if(mode==1)
                %include statistics for all parameters
                columnHeader = simAnalysis.getParameterStr(this.myResSubject.basicParams.nExp,this.myResSubject.basicParams.stretchedExpMask);
                rowHeader = get(this.visHandles.tableSelectedResult,'Data');
                rowHeader(:,2) = [];
                
                %gather data
                data = zeros(9,length(columnHeader));
                for i = 1:length(columnHeader)
                    [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(columnHeader{i});
                    [pMode, pMean, pMedian, pVar, pStd, pSkew, pKurt, pCIl, pCIh] = this.computeParaStats(dType,dTypeNr);
                    if(~isempty(pMode))
                        data(1,i) = pMode;
                        data(2,i) = pMean;
                        data(3,i) = pMedian;
                        data(4,i) = pVar;
                        data(5,i) = pStd;
                        data(6,i) = pSkew;
                        data(7,i) = pKurt;
                        data(8,i) = pCIl;
                        data(9,i) = pCIh;
                    end
                    this.updateProgressbar(0.7+0.3/length(columnHeader)*i,...
                        'Exporting Statistics to Excel File');
                end
                
                sheetName = 'Statistics of Fit Result Parameters';
                exportExcel(fn,data,columnHeader,rowHeader,sheetName,tableName);
            end
            this.updateProgressbar(0,'');
        end
        
        
        function out = get.pixelFitParams(this)
            %make fitParams struct
            out = this.paramMgrObj.getParamSection('pixel_fit');
        end
        
        function params = get.fileInfo(this)
            %get file info struct of simulation file
            params = this.myResSubject.getFileInfoStruct(this.curChannel);
        end
        
        function params = get.volatileParams(this)
            %get bounds
            params = this.paramMgrObj.getParamSection('volatile');
        end
        
        function params = get.preProcessParams(this)
            %get basic fit parameters
            params = this.paramMgrObj.getParamSection('pre_processing');
        end
        
        function params = get.basicFitParams(this)
            %get basic fit parameters
            params = this.paramMgrObj.getParamSection('basic_fit');
        end
        
        function params = get.computationParams(this)
            %get basic fit parameters
            params = this.paramMgrObj.getParamSection('computation');
        end
        
        function params = get.fluoDecayFitVisParams(this)
            %getcomputation parameters
            params = this.FLIMXObj.paramMgr.getParamSection('fluo_decay_fit_gui');
        end
        
        function out = get.about(this)
            %make visParams struct
            out = this.FLIMXObj.paramMgr.getParamSection('about');
        end
        
        function out = get.curStudy(this)
            %get current study
            out = '';
            str = get(this.visHandles.popupStudy,'String');
            if(~isempty(str) && iscell(str))
                out = str{get(this.visHandles.popupStudy,'Value')};
            elseif(ischar(str))
                out = str;
            end
        end
        
        function out = get.curChannel(this)
            %get current channel
            out = get(this.visHandles.popupChannel,'Value');
        end
        
        function out = get.paraSetNames(this)
            %get names of all 
            out = this.FLIMXObj.sDDMgr.getAllSDDNames();
        end
        
        
        function out = get.curParaSetName(this)
            %get current parameter set name
            if(isempty(this.paraSetNames))
                out = [];
                return
            end            
%             arrayIDs = this.paraSetNames{this.curParaSetID,2};
%             if(~strcmp('-',arrayIDs{this.curParaSetArrayID}))
%                 %combine parameter set name with array subset name
%                 %setName = sprintf('%s %s',this.paraSetNames{this.curParaSetID,1},arrayIDs{this.curParaSetArrayID});
%                 %find all array subsets for current channel
%                 subsetNames = this.FLIMXObj.sDDMgr.getAllArrayParamSetNames(this.curChannel);
%                 %set selected array subset as current parameter set
%                 out = subsetNames{min(get(this.visHandles.popupArraySubsets,'Value'),length(subsetNames))};
%             else
                %single parameter set
%                 out = this.paraSetNames{get(this.visHandles.popupParaSets,'Value'),1};
%             end
            out = '';
            str = get(this.visHandles.popupParaSets,'String');
            if(~isempty(str) && iscell(str))
                out = str{get(this.visHandles.popupParaSets,'Value')};
            elseif(ischar(str))
                out = str;
            end
        end
        
%         function out = get.curParaSetID(this)
%             %get id of currently selected parameter set, i.e. position in popup menu
%             out = get(this.visHandles.popupParaSets,'Value');
%         end
        
        function out = get.curArrayName(this)
            %get id of currently selected parmeter set array
            str = get(this.visHandles.popupParaSetArrays,'String');
            val = get(this.visHandles.popupParaSetArrays,'Value');
            if(~iscell(str) || length(str) == 1 || val == 1)
                out = '';
            else
                out = str{val};
            end
        end
        
        function out = get.curResultChanIsAvailable(this)
            %get flag to determine if a result is available
            out = this.resultIsAvailable(this.curStudy,this.curParaSetName,this.curChannel);
        end
                       
%         function out = get.isArray(this)
%             %get logical output to determine if a parameter set array is selected
%             out = false;
%             arrayIDs = this.FLIMXObj.sDDMgr.getAllArrayParamSetNames(this.curChannel); %this.paraSetNames{this.curParaSetID,2};
%             if(~strcmp('-',arrayIDs{this.curParaSetArrayID}))
%                 out = true;
%             end
%         end
        
        function out = get.showArray(this)
            %get logical output if array mode is active
            out = ~get(this.visHandles.toggleShowSubset,'Value');
        end
        
        function out = get.curParameter(this)
            %get current parameter for selected statistics
            out = [];
            paraStr = get(this.visHandles.popupParaSelection,'String');
            tmp = paraStr{get(this.visHandles.popupParaSelection,'Value')};
            if(~strcmp('-',tmp))
                out = tmp;
            end
        end
        
        %% computation and other functions
        function createVisWnd(this)
            %make new window for parameter set manager
            this.visHandles = GUI_simAnalysis();
            set(this.visHandles.simAnalysisFigure,'CloseRequestFcn',@this.GUI_buttonClose_Callback);
            %set callbacks
            %buttons
            set(this.visHandles.buttonClose,'Callback',@this.GUI_buttonClose_Callback);
            set(this.visHandles.buttonExportStats,'Callback',@this.GUI_buttonExportStats_Callback);
            set(this.visHandles.buttonExportArrayStats,'Callback',@this.GUI_buttonExportArrayStats_Callback);
            set(this.visHandles.buttonExportMultArrayStats,'Callback',@this.GUI_buttonExportMultArrayStats_Callback);
            set(this.visHandles.buttonExportMultStats,'Callback',@this.GUI_buttonExportMultStats_Callback);
            set(this.visHandles.buttonScreenshot,'Callback',@this.GUI_buttonScreenshot_Callback);
            set(this.visHandles.buttonStop,'Callback',@this.GUI_buttonStop_Callback);
            set(this.visHandles.buttonTimeScalStartDec,'String',char(172),'Callback',@this.GUI_buttonTimeScal_Callback);
            set(this.visHandles.buttonTimeScalStartInc,'String',char(174),'Callback',@this.GUI_buttonTimeScal_Callback);
            set(this.visHandles.buttonTimeScalEndDec,'String',char(172),'Callback',@this.GUI_buttonTimeScal_Callback);
            set(this.visHandles.buttonTimeScalEndInc,'String',char(174),'Callback',@this.GUI_buttonTimeScal_Callback);
            set(this.visHandles.buttonSelectSubsets,'Callback',@this.GUI_buttonSelectSubsets_Callback);
            set(this.visHandles.buttonDeselectSubsets,'Callback',@this.GUI_buttonDeselectSubsets_Callback);
            %toogle button
            set(this.visHandles.toggleShowSubset,'Callback',@this.GUI_toggleShowSubset_Callback);
            %edits
            set(this.visHandles.editTimeScalStart,'Callback',@this.GUI_editTimeScal_Callback);
            set(this.visHandles.editTimeScalEnd,'Callback',@this.GUI_editTimeScal_Callback);
            %popups
            set(this.visHandles.popupStudy,'Callback',@this.GUI_popupStudy_Callback);
            set(this.visHandles.popupParaSets,'Callback',@this.GUI_popupParaSets_Callback);
            set(this.visHandles.popupDisplayMode,'Callback',@this.GUI_popupDisplayMode_Callback)
            set(this.visHandles.popupResultMode,'Callback',@this.GUI_popupResultMode_Callback);
            set(this.visHandles.popupResultStatsMode,'Callback',@this.GUI_popupResultStatsMode_Callback);
            set(this.visHandles.popupParaSelection,'Callback',@this.GUI_popupParaSelection_Callback);
            set(this.visHandles.popupArrayStats,'Callback',@this.GUI_popupArrayStats_Callback);
            set(this.visHandles.popupParaSetArrays,'Callback',@this.GUI_popupParaSetArrays_Callback);
            set(this.visHandles.popupArraySubsets,'Callback',@this.GUI_popupArraySubsets_Callback,'Visible','off');
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback);
            %checkboxes
            set(this.visHandles.checkExp,'Callback',@this.GUI_checkExp_Callback);
            set(this.visHandles.checkModel,'Callback',@this.GUI_checkModel_Callback);
            set(this.visHandles.checkData,'Callback',@this.GUI_checkData_Callback);
            set(this.visHandles.checkPercentDiffs,'Callback',@this.GUI_checkPercentDiffs_Callback);
            set(this.visHandles.checkAmps,'Callback',@this.GUI_checkAmps_Callback);
            set(this.visHandles.checkAmpsPercent,'Callback',@this.GUI_checkAmpsPercent_Callback);
            set(this.visHandles.checkTaus,'Callback',@this.GUI_checkTaus_Callback);
            set(this.visHandles.checkTcis,'Callback',@this.GUI_checkTcis_Callback);
            set(this.visHandles.checkQs,'Callback',@this.GUI_checkQs_Callback);
            set(this.visHandles.checkChi2,'Callback',@this.GUI_checkChi2_Callback);
            set(this.visHandles.checkOffset,'Callback',@this.GUI_checkOffset_Callback);
            %table
            set(this.visHandles.tableSimParaSet,'CellSelectionCallback',@this.GUI_tableSimParaSelection_Callback);
            set(this.visHandles.tableResultDiffs,'CellSelectionCallback',@this.GUI_tableResultDiffsSelection_Callback);
            set(this.visHandles.tableResultStats,'CellSelectionCallback',@this.GUI_tableResultStatsSelection_Callback);
            set(this.visHandles.tableSubsets,'CellEditCallback',@this.GUI_tableSubsets_EditCallback);
            set(this.visHandles.tableSubsets,'CellSelectionCallback',@this.GUI_tableSubsets_SelectionCallback);
            %radio buttons
            set(this.visHandles.radioChi2Plot,'Callback',@this.GUI_radioChi2Plot_Callback);
            set(this.visHandles.radioChi2TailPlot,'Callback',@this.GUI_radioChi2TailPlot_Callback);
            set(this.visHandles.radioChi2Stats,'Callback',@this.GUI_radioChi2Stats_Callback);
            set(this.visHandles.radioChi2TailStats,'Callback',@this.GUI_radioChi2TailStats_Callback);
            set(this.visHandles.radioTimeScalAuto,'Callback',@this.GUI_radioTimeScal_Callback);
            set(this.visHandles.radioTimeScalManual,'Callback',@this.GUI_radioTimeScal_Callback);
            %axes
            this.hAx = this.visHandles.axesMain;
            this.histAx = this.visHandles.axesHist;
            set(this.visHandles.axesProgress,'XLim',[0 100],...
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
            this.visHandles.patchWait = patch(xpatch,ypatch,'r','EdgeColor','r','Parent',this.visHandles.axesProgress);%,'EraseMode','normal'
            this.visHandles.textWait = text(1,0,'','Parent',this.visHandles.axesProgress);
            this.FLIMXObj.sDDMgr.scanForSDDs();
        end
        
        function checkVisWnd(this)
            %
            if(isempty(this.visHandles) || ~ishandle(this.visHandles.simAnalysisFigure) || ~strcmp(get(this.visHandles.simAnalysisFigure,'Tag'),'simAnalysisFigure'))
                %no window - open one
                this.createVisWnd();
            end            
            %init analysis tool
            set(this.visHandles.toggleShowSubset,'String','Show Subset in Detail','Value',0);    %do not show subset in detail by default
            %this.loadParaSetNames();
            if(~isempty(this.paraSetNames))
                %load single parameter sets and arrays
                set(this.visHandles.popupParaSets,'String',this.paraSetNames,'Value',1);
%                 set(this.visHandles.popupParaSetArrays,'String',this.paraSetNames{1,2},'Value',1);
            else
                set(this.visHandles.popupParaSets,'String','-','Value',1);
                set(this.visHandles.popupParaSetArrays,'String','-','Value',1);
                return
            end            
            this.chi2PlotSel = 1;
            this.chi2StatsSel = 1;            
            %check channel
            sdd = this.getSynthDataDef(this.curParaSetName);
            if(isempty(sdd.getChannel(this.curChannel)))
                [~, mask] = sdd.nonEmptyChannelStr();
                set(this.visHandles.popupChannel,'Value',find(mask,1));
            end            
%             this.loadArrayParaSets();
            this.setupGUI();    %load set names etc. initially
            if(~isempty(this.paraSetNames))
                this.loadResult(this.curParaSetName);
                this.setupGUI();
            end
            this.updateGUI();
            this.makeMainPlot();
            figure(this.visHandles.simAnalysisFigure);
        end
        
        function setupGUI(this)
            %setup GUI controls
            if(isempty(this.visHandles) || ~ishandle(this.visHandles.simAnalysisFigure) ||...
                    ~strcmp(get(this.visHandles.simAnalysisFigure,'Tag'),'simAnalysisFigure') || isempty(this.paraSetNames))
                return
            end            
            %update popup menus for parameter sets, parameter set arrays and array subsets
            %make sure arrays of current parameter set are shown
            studies = this.FLIMXObj.fdt.getAllStudyNames();
            set(this.visHandles.popupStudy,'String',studies,'Value',min(get(this.visHandles.popupStudy,'Value'),length(studies)));
            aStr = this.FLIMXObj.sDDMgr.getAllArrayParamSetNames(this.curChannel);
            aStr(end+1) = {'-'};
            aStr = circshift(aStr,[1 1]);
            set(this.visHandles.popupParaSetArrays,'String',aStr,... %this.paraSetNames{this.curParaSetID,2}
                'Value',min(get(this.visHandles.popupParaSetArrays,'Value'),length(aStr)));            
            if(~isempty(this.curArrayName))
                %parameter set array
                set(this.visHandles.toggleShowSubset,'Enable','On');
                subsetNames = this.arraySubsetNames(cell2mat(this.arraySubsetNames(:,2)),1);
                if(isempty(subsetNames))
                    set(this.visHandles.popupParaSets,'String','-','Value',1);
                    return
                end
%                 set(this.visHandles.popupArraySubsets,'String',subsetNames,...
%                     'Value',min(get(this.visHandles.popupArraySubsets,'Value'),length(subsetNames)),'Enable','On');
                set(this.visHandles.popupParaSets,'String',subsetNames,'Value',min(length(subsetNames),get(this.visHandles.popupParaSets,'Value')));
            else
                set(this.visHandles.toggleShowSubset,'Enable','Off','Value',1); %disable parameter set array mode
%                 set(this.visHandles.popupArraySubsets,'String','-','Value',1,'Enable','Off');
                set(this.visHandles.popupParaSets,'String',this.paraSetNames,'Value',min(length(this.paraSetNames),get(this.visHandles.popupParaSets,'Value')));
            end
            
            if(~this.curResultChanIsAvailable)
                return
            end
            sdd = this.getSynthDataDef(this.curParaSetName);
            if(this.showArray && ~isempty(sdd))
                %parameter set array
%                 set(this.visHandles.popupFitResults,'String','-','Value',1,'Enable','Off');
                set(this.visHandles.tableSubsets,'Visible','On','ColumnEditable',[false true]);
                set(this.visHandles.buttonSelectSubsets,'Visible','On');
                set(this.visHandles.buttonDeselectSubsets,'Visible','On');
                set(this.visHandles.buttonExportArrayStats,'Enable','On');
                set(this.visHandles.buttonExportStats,'Enable','Off');
                %setup popups
                id = simAnalysis.rID2paraName(sdd.arrayParamNr,this.myResSubject.basicParams.nExp);
                dispModes = {'Boxplot', sprintf('Parameter vs. %s',id)};
                parameters = simAnalysis.getParameterStr(this.myResSubject.basicParams.nExp,this.myResSubject.basicParams.stretchedExpMask);    %get parameter string
                set(this.visHandles.popupDisplayMode,'String',dispModes,'Value',...
                    min(get(this.visHandles.popupDisplayMode,'Value'),length(dispModes)));
                set(this.visHandles.popupResultMode,'String',parameters,'Enable','On',...
                    'Value',min(get(this.visHandles.popupResultMode,'Value'),length(parameters)));
                set(this.visHandles.popupArrayStats,'Visible','On');
                %make statistics tables invisble
                set(this.visHandles.panelResultStats,'Visible','Off');
                set(this.visHandles.panelDescStats,'Visible','Off');
            else
                %no parameter set array
                set(this.visHandles.tableSubsets,'Visible','Off');
                set(this.visHandles.buttonSelectSubsets,'Visible','Off');
                set(this.visHandles.buttonDeselectSubsets,'Visible','Off');
                %setup popups
                dispModes = {'Boxplot (Result only)', 'Parameter Set and Result', 'Parameter Set only', 'Result only'};
                resultModes = {'Whole Dataset', 'Whole Dataset (std)', 'Whole Dataset (Max-Min)', 'Best Pixel', 'Worst Pixel'};
                set(this.visHandles.popupDisplayMode,'String',dispModes,'Value',...
                    min(get(this.visHandles.popupDisplayMode,'Value'),length(dispModes)));
                set(this.visHandles.popupResultMode,'String',resultModes,'Value',1);
                set(this.visHandles.popupArrayStats,'Visible','Off');
                set(this.visHandles.buttonExportStats,'Enable','On');
                set(this.visHandles.panelResultStats,'Visible','On');
                set(this.visHandles.panelDescStats,'Visible','On');
                set(this.visHandles.buttonExportArrayStats,'Enable','Off');
            end
        end
        
        function updateGUI(this)
            %update GUI controls
            if(isempty(this.visHandles) || ~ishandle(this.visHandles.simAnalysisFigure) ||...
                    ~strcmp(get(this.visHandles.simAnalysisFigure,'Tag'),'simAnalysisFigure') || isempty(this.paraSetNames))
                return
            end
            
            %enable / disable channel popup
            sdd = this.getSynthDataDef(this.curParaSetName);
            if(length(sdd.nonEmptyChannelStr()) > 1)
                set(this.visHandles.popupChannel,'Enable','On');
            else
                set(this.visHandles.popupChannel,'Enable','Off');
            end
            
            if(this.showArray)
                %parameter set array
                set(this.visHandles.toggleShowSubset,'String','Show Subset in Detail');
%                 this.arraySubsetNames(~this.emptySubsets,2) = {false};
                set(this.visHandles.tableSubsets,'Data',this.arraySubsetNames);
                switch(get(this.visHandles.popupDisplayMode,'Value'))
                    case 1 %Boxplot
                        set(this.visHandles.popupArrayStats,'Visible','Off');
                    case 2 %Parameter Set Array Plot
                        set(this.visHandles.popupArrayStats,'Visible','On');
                end
                set(this.visHandles.radioTimeScalAuto,'Visible','Off');
                set(this.visHandles.radioTimeScalManual,'Visible','Off');
                set(this.visHandles.buttonTimeScalStartDec,'Visible','Off');
                set(this.visHandles.buttonTimeScalStartInc,'Visible','Off');
                set(this.visHandles.buttonTimeScalEndDec,'Visible','Off');
                set(this.visHandles.buttonTimeScalEndInc,'Visible','Off');
                set(this.visHandles.editTimeScalStart,'Visible','Off');
                set(this.visHandles.editTimeScalEnd,'Visible','Off');
                set(this.visHandles.textTimeScaling,'Visible','Off');
                set(this.visHandles.textTimeScaling2,'Visible','Off');
                this.makeStatsTable(this.curParaSetName,this.curChannel);
            else
                %no parameter set array
                set(this.visHandles.toggleShowSubset,'String','Show Array Analysis');
%                 if(~isempty(this.resultNames))
%                     [tf pos] = ismember(this.curResultName,this.resultNames);
%                     set(this.visHandles.popupFitResults,'String',this.resultNames,'Value',pos,'Enable','On');
%                 else
%                     set(this.visHandles.popupFitResults,'String','-','Value',1,'Enable','Off');
%                 end
                if(~this.curResultChanIsAvailable)
                    %disable UI controls
                    set(this.visHandles.popupResultStatsMode,'Enable','Off');
                    set(this.visHandles.popupParaSelection,'String','-','Value',1);
                else
                    %enable UI controls
                    set(this.visHandles.popupResultStatsMode,'Enable','On');
                    paraStr = simAnalysis.getParameterStr(this.myResSubject.basicParams.nExp,this.myResSubject.basicParams.stretchedExpMask);
                    set(this.visHandles.popupParaSelection,'String',paraStr);
                    [tf pos] = ismember(this.curParameter,paraStr);
                    if(tf)
                        set(this.visHandles.popupParaSelection,'Value',pos);
                    else
                        set(this.visHandles.popupParaSelection,'Value',1);
                    end
                end
                
                switch(get(this.visHandles.popupDisplayMode,'Value'))
                    case 1 %boxplot
                        set(this.visHandles.popupResultMode,'Enable','Off');
                        set(this.visHandles.checkAmps,'Enable','On','Visible','On');
                        set(this.visHandles.checkAmpsPercent,'Enable','On','Visible','On');
                        set(this.visHandles.checkTaus,'Enable','On','Visible','On');
                        set(this.visHandles.checkTcis,'Enable','On','Visible','On');
                        set(this.visHandles.checkQs,'Enable','On','Visible','On');
                        set(this.visHandles.checkChi2,'Enable','On','Visible','On');
                        set(this.visHandles.checkOffset,'Enable','On','Visible','On');
                        set(this.visHandles.checkExp,'Enable','Off','Visible','Off');
                        set(this.visHandles.checkModel,'Enable','Off','Visible','Off');
                        set(this.visHandles.checkData,'Enable','Off','Visible','Off');
                        set(this.visHandles.radioTimeScalAuto,'Visible','Off');
                        set(this.visHandles.radioTimeScalManual,'Visible','Off');
                        set(this.visHandles.buttonTimeScalStartDec,'Visible','Off');
                        set(this.visHandles.buttonTimeScalStartInc,'Visible','Off');
                        set(this.visHandles.buttonTimeScalEndDec,'Visible','Off');
                        set(this.visHandles.buttonTimeScalEndInc,'Visible','Off');
                        set(this.visHandles.editTimeScalStart,'Visible','Off');
                        set(this.visHandles.editTimeScalEnd,'Visible','Off');
                        set(this.visHandles.textTimeScaling,'Visible','Off');
                        set(this.visHandles.textTimeScaling2,'Visible','Off');
                    otherwise %result,simulation parameter set
                        if(get(this.visHandles.popupDisplayMode,'Value') ~= 3)
                            set(this.visHandles.popupResultMode,'Enable','On');
                        else
                            set(this.visHandles.popupResultMode,'Enable','Off');
                        end
                        set(this.visHandles.checkAmps,'Enable','Off','Visible','Off');
                        set(this.visHandles.checkAmpsPercent,'Enable','Off','Visible','Off');
                        set(this.visHandles.checkTaus,'Enable','Off','Visible','Off');
                        set(this.visHandles.checkTcis,'Enable','Off','Visible','Off');
                        set(this.visHandles.checkQs,'Enable','Off','Visible','Off');
                        set(this.visHandles.checkChi2,'Enable','Off','Visible','Off');
                        set(this.visHandles.checkOffset,'Enable','Off','Visible','Off');
                        set(this.visHandles.checkExp,'Enable','On','Visible','On');
                        set(this.visHandles.checkModel,'Enable','On','Visible','On');
                        set(this.visHandles.checkData,'Enable','On','Visible','On');
                        set(this.visHandles.radioTimeScalAuto,'Visible','On');
                        set(this.visHandles.radioTimeScalManual,'Visible','On');
                        set(this.visHandles.buttonTimeScalStartDec,'Visible','On');
                        set(this.visHandles.buttonTimeScalStartInc,'Visible','On');
                        set(this.visHandles.buttonTimeScalEndDec,'Visible','On');
                        set(this.visHandles.buttonTimeScalEndInc,'Visible','On');
                        set(this.visHandles.editTimeScalStart,'Visible','On');
                        set(this.visHandles.editTimeScalEnd,'Visible','On');
                        set(this.visHandles.textTimeScaling,'Visible','On');
                        set(this.visHandles.textTimeScaling2,'Visible','On');
                end
                
                %show or hide radio buttons
                if(get(this.visHandles.popupResultMode,'Value') < 4)
                    set(this.visHandles.radioChi2Plot,'Enable','Off','Visible','Off');
                    set(this.visHandles.radioChi2TailPlot,'Enable','Off','Visible','Off');
                else
                    %update chi2 selection for plot
                    set(this.visHandles.radioChi2Plot,'Enable','On','Visible','On');
                    set(this.visHandles.radioChi2TailPlot,'Enable','On','Visible','On');
                end
                
                if(get(this.visHandles.popupResultStatsMode,'Value') < 2)
                    set(this.visHandles.radioChi2Stats,'Enable','Off','Visible','Off');
                    set(this.visHandles.radioChi2TailStats,'Enable','Off','Visible','Off');
                else
                    %update chi2 selection for statistics
                    set(this.visHandles.radioChi2Stats,'Enable','On','Visible','On');
                    set(this.visHandles.radioChi2TailStats,'Enable','On','Visible','On');
                end
                
                %update table headers
                if(get(this.visHandles.checkPercentDiffs,'Value'))
                    colHeaders = {'Amp.' 'Diff. (%)' 'Amp. (%)' 'Diff. (%)' 'Tau (ps)' 'Diff. (%)' 'tci (ps)' 'Diff. (%)' 'Q (%)' 'Diff. (%)'};
                else
                    colHeaders = {'Amp.' 'Diff.' 'Amp. (%)' 'Diff.' 'Tau (ps)' 'Diff.' 'tci (ps)' 'Diff.' 'Q (%)' 'Diff.'};
                end
                set(this.visHandles.tableResultDiffs,'ColumnName',colHeaders);
                
                cla(this.histAx)
                axis(this.histAx,'off');
                %update tables
                this.makeStatsTable(this.curParaSetName,this.curChannel);
                this.makeSelResultTable();
            end
        end
        
        function clearMainPlot(this)
            %reset plot            
            cla(this.hAx);
            ylabel(this.hAx,'');
            xlabel(this.hAx,'');
            this.lStr = cell(0,0);      %reset labels
        end
        
        function makeMainPlot(this)
            %create main plot
            if(isempty(this.FLIMXObj.sDDMgr.getAllSDDNames()))
                %nothing to plot
                return
            end
            
            arrayIDs = get(this.visHandles.popupParaSetArrays,'String');
            if(~strcmp('-',arrayIDs{get(this.visHandles.popupParaSetArrays,'Value')}))
                %parameter set array
                if(this.showArray)
                    %parameter set array
                    switch get(this.visHandles.popupDisplayMode,'Value')
                        case 1
                            %plot boxplot of parameter set array
                            this.makeArrayBoxPlot();
                        case 2
                            %plot selected parameter against array running parameter
                            this.makeArrayPlot();
                    end
                    return
                end
            end
            
            %no parameter set array
            hold(this.hAx,'on');
            switch get(this.visHandles.popupDisplayMode,'Value')
                case 1
                    %plot boxplot
                    this.makeBoxPlot();
                case 2
                    %plot result and parameter set
                    this.makeParaSetPlot();
                    this.makeResultPlot();
                case 3
                    %plot parameter set only
                    this.makeParaSetPlot();
                case 4
                    %plot result only
                    this.makeResultPlot();
            end
            hold(this.hAx,'off');
            
            if(~isempty(this.lStr))
                legend(this.hAx,this.lStr);
            else
                legend(this.hAx,'off')
            end
        end                                    
        
        function makeBoxPlot(this)
            %make boxplot for results
            this.stop = false;
            if((~get(this.visHandles.checkAmps,'Value') && ~get(this.visHandles.checkAmpsPercent,'Value') && ~get(this.visHandles.checkTaus,'Value')...
                    && ~get(this.visHandles.checkTcis,'Value') && ~get(this.visHandles.checkQs,'Value')...
                    && ~get(this.visHandles.checkChi2,'Value') && ~get(this.visHandles.checkOffset,'Value'))...
                    || ~this.curResultChanIsAvailable)
                return
            end
            
            %get data over whole dataset
            allAmps = [];  allAmpsPercent = []; allTaus = []; allTcis = []; allQs = []; allChi2 = []; allOffset = [];            
            grpLbls = cell(0,0);
            nExp = this.myResSubject.basicParams.nExp;
            for i = 1:nExp
                if(get(this.visHandles.checkAmps,'Value')) 
                    tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('Amplitude%d',i));
                    allAmps(i,:) = tmp(:);
                end
                if(get(this.visHandles.checkAmpsPercent,'Value')) 
                    tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('AmplitudePercent%d',i));
                    allAmpsPercent(i,:) = tmp(:);
                end
                if(get(this.visHandles.checkTaus,'Value'))
                    tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('Tau%d',i));
                    allTaus(i,:) = tmp(:);
                end
                if(get(this.visHandles.checkTcis,'Value') && this.myResSubject.basicParams.tciMask(i))
                    tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('tc%d',i));
                    allTcis(end+1,:) = tmp(:);
                end
                if(get(this.visHandles.checkQs,'Value'))
                    tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('Q%d',i));
                    allQs(i,:) = tmp(:);
                end
            end
            
            %create label string for groups of boxplot            
            for i = 1:size(allAmps,1)
                grpLbls(end+1) = {sprintf('Amplitude %d',i)};
            end
            for i = 1:size(allAmpsPercent,1)
                grpLbls(end+1) = {sprintf('AmplitudePercent %d',i)};
            end
            for i = 1:size(allTaus,1)
                grpLbls(end+1) = {sprintf('Tau %d',i)};
            end
            ind = find(this.myResSubject.basicParams.tciMask);
            for i = 1:size(allTcis,1)
                grpLbls(end+1) = {sprintf('tc %d',ind(i))};
            end
            for i = 1:size(allQs,1)
                grpLbls(end+1) = {sprintf('Q %d',i)};
            end
            
            if(get(this.visHandles.checkChi2,'Value'))
                %get values for chi2
                allChi2 = this.myResSubject.getPixelFLIMItem(this.curChannel,'chi2');
                allChi2 = allChi2(:);
                grpLbls(end+1) = {'Chi2'};
            end
            
            if(get(this.visHandles.checkOffset,'Value'))
                %get values for offset
                allOffset = this.myResSubject.getPixelFLIMItem(this.curChannel,'Offset');
                allOffset = allOffset(:);
                grpLbls(end+1) = {'Offset'};
            end
            
            data = [allAmps' allAmpsPercent' allTaus' allTcis' allQs' allChi2 allOffset];
            this.updateProgressbar(0.7,'Create Boxplot');
            %make boxplot            
            set(this.hAx,'Visible','Off');
            set(this.hAx,'Yscale','lin');
            boxplot(this.hAx,data,'plotstyle','traditional','labels',grpLbls); %bug: resizes axes
            this.updateProgressbar(0.9,'Create Boxplot');
            set(this.hAx,'Position',[250 295 890 340]);
            set(this.hAx,'Visible','On');
            this.updateProgressbar(0,'');
        end
        
        function makeArrayBoxPlot(this)
            %make boxplot for parameter set array
            this.stop = false;
            if(~any(cell2mat(this.arraySubsetNames(:,2))))
                %no subset selected or all empty
                return
            end            
            [data, reference, paraStr] = this.getCurArrayData();
            if(isempty(data))
                this.updateProgressbar(0,'');
                return
            end            
            subsets = this.arraySubsets(cell2mat(this.arraySubsetNames(:,2)),1);
            grpLbls = this.getArrayRunningParameter();
            [grpLbls,idx] = sort(grpLbls);            
            data = data(:,idx);
            reference = reference(1,idx);
            %remove empty subsets
            idx = all(data,1);
            data = data(:,idx);
            reference = reference(1,idx);
            grpLbls = grpLbls(:,idx);
            grpLbls = num2cell(grpLbls);
            %make boxplot
            set(this.hAx,'Visible','Off');
            set(this.hAx,'Yscale','lin');
            boxplot(this.hAx,data,'labels',grpLbls);%,'plotstyle','compact'
            hold(this.hAx,'on');
            xLim = get(this.hAx,'XLim');
            xVal = linspace(xLim(1),xLim(2),length(grpLbls));
            if(~isempty(reference))
                %plot reference line
                plot(this.hAx,xVal,reference,'r--');
                %check boundary values
                yLim = get(this.hAx,'YLim');
                yLim(1) = min(min(reference),yLim(1));
                yLim(2) = max(max(reference),yLim(2));
                set(this.hAx,'YLim',yLim);
            end
            hold(this.hAx,'off');
            ylabel(this.hAx,paraStr);
            xlabel(this.hAx,subsets{1}.arrayParamName);
            set(this.hAx,'Position',[250 295 890 340]);
            set(this.hAx,'Visible','On');
        end
        
        function makeParaSetPlot(this)
            %make plot for selected parameter set
            if(~this.curResultChanIsAvailable)
                return
            end
%             this.updateProgressbar(0.1,'Plot Simulation Parameter Set');
            set(this.hAx,'Position',[250 295 890 340]);
            %get parameter, raw data and model
            [szX szY szTime nExp photons offset sdt xVec tci] = this.simObj.getSimParams(this.curParaSetName,this.curChannel);
            sdc = this.getSynthDataCh(this.curParaSetName,this.curChannel);
            raw = sdc.rawData;
            model = sdc.modelData;
            
            xAxis = this.myResSubject.timeVector(1:szTime);
            set(this.hAx,'XTickLabel',xAxis);
%             this.updateProgressbar(0.3,'Plot Simulation Parameter Set');
            staticVisParams = this.fluoDecayFitVisParams;
            if(get(this.visHandles.checkModel,'Value'))
                %plot model                
                staticVisParams.plotExpSumColor = 'g';
                staticVisParams.plotExpSumLinestyle = '-';
                FLIMXFitGUI.makeModelPlot(this.hAx,squeeze(model),xAxis,'ExpSum',this.dynVisParams,staticVisParams,'',[]);            
                this.lStr(end+1) = {'Model (Parameter Set)'};
%                 this.updateProgressbar(0.6,'Plot Simulation Parameter Set');
            end
            
            if(get(this.visHandles.checkExp,'Value'))
                %plot exponentials
                apObj = this.getSimApObj();
                %scale xvec to max(data)
                dMax = max(raw(:));
                xVec(1:nExp) = xVec(1:nExp).* dMax;                
                FLIMXFitGUI.makeExponentialsPlot(this.hAx,xAxis,apObj,apObj.getNonConstantXVec(this.curChannel,xVec),this.lStr,this.dynVisParams,staticVisParams);
                for i = 1:apObj.basicParams.nExp
                    this.lStr(end+1) = {sprintf('Exp. %d (Parameter Set)',i)};
                end
%                 this.updateProgressbar(1,'Plot Simulation Parameter Set');
            end
%             this.updateProgressbar(0,'');        
        end
        
        function out = getSimApObj(this)
            %get approximation object for simulation
%             out = this.myResSubject.getApproxObj(this.curChannel,1,1);
            tmp = this.simObj.getSimSubject(this.getSynthDataCh(this.curParaSetName,this.curChannel));
            out = tmp.getApproxObj(this.curChannel,1,1);
%             sdc = this.getSynthDataCh(this.curParaSetName,this.curChannel);
%             allIRFs{this.curChannel} = this.FLIMXObj.irfMgr.getIRF(sdc.IRFName,this.curChannel,sdc.nrTimeChannels);
%             fileInfo(this.curChannel) = this.myResSubject.getFileInfoStruct(this.curChannel);
%             params.volatilePixel = this.simObj.volatilePixelParams;
%             params.volatileChannel = this.simObj.paramMgrObj.getParamSection('volatileChannel');
%             params.basicFit = this.simObj.basicParams;
%             params.preProcessing = [];
%             params.computation = this.simObj.computationParams;
%             params.bounds = [];
%             params.pixelFit = this.simObj.pixelFitParams;
%             out = fluoPixelModel(allIRFs,fileInfo,params);
%             out.setCurrentChannel(this.curChannel);
        end
                
        function makeResultPlot(this)
            %make result plot with exponentials and model
            if(~this.curResultChanIsAvailable)
                return
            end
%             persistent lastUpdate
            this.stop = false;
            plotEnvelopes = false;
            
            [y, x] = size(this.myResSubject.getPixelFLIMItem(this.curChannel,'Amplitude1'));
%             this.updateProgressbar(0.1,'Plot Fit Result');
            set(this.hAx,'Position',[250 295 890 340]);
            %rawData = this.myResSubject.getRawData(this.curChannel);
            xAxis = this.myResSubject.timeVector(1:this.myResSubject.nrTimeChannels);
            
            if(get(this.visHandles.popupResultMode,'Value') < 4)
                %computation over whole dataset
                allData = []; allModels = []; allExponentials = []; allXVec = [];                
                for i = 1:x
                    for j = 1:y
                        %get fit parameters
                        %apObj = this.myResSubject.getApproxObj(this.curChannel,j,i);
                        [apObj, xVec] = this.myResSubject.getVisParams(this.curChannel,j,i,false);
                        %get data and model for each pixel
                        if(sum(xVec(:)) == 0)
                            model = [];
                            exponentials = [];
                        else
                            exponentials = apObj.getExponentials(this.curChannel,xVec,1);
                            model = apObj.getModel(this.curChannel,xVec,1);
                            model(model < 1e-1) = 1e-1;
                        end
                        allData(:,end+1) = apObj.getMeasurementData(this.curChannel);
                        allModels(:,end+1) = model;
                        allXVec(:,end+1) = xVec;
                        %get exponentials
                        exponentials = squeeze(exponentials);
                        if(size(exponentials,2) ~= this.myResSubject.basicParams.nExp+1)
                            continue
                        end
                        allExponentials(:,:,((i-1)*y)+j) = exponentials;
                    end
%                     if(isempty(lastUpdate) || etime(clock, lastUpdate) > 1)
%                         lastUpdate = clock;
%                         this.updateProgressbar((0.5/x)*i,'Plot Fit Result');
%                     end                    
                    if(this.stop)
                        this.stop = false;
                        this.updateProgressbar(0,'');
                        return
                    end
                end
            end            
            
            switch get(this.visHandles.popupResultMode,'Value')
                case 1 %whole dataset                                        
                    %calculate average data,model and exponentials
                    data = mean(allData,2);
                    model = mean(allModels,2);
                    xVec = mean(allXVec,2);
                    exponentials = mean(allExponentials,3);                    
                case 2 %whole dataset (std)
                    data = mean(allData,2);
                    model = mean(allModels,2);
                    exponentials = mean(allExponentials,3);                    
                    %compute enveloping functions
                    leData = data - std(allData,0,2);    %lower envelope
                    ueData = data + std(allData,0,2);    %upper envelope
                    leModel = model - std(allModels,0,2);
                    ueModel = model + std(allModels,0,2);
                    %leExp = exponentials - std(allExponentials,0,3);
                    %ueExp = exponentials + std(allExponentials,0,3);
                    plotEnvelopes = true;
                case 3 %whole dataset (max-min)
                    data = mean(allData,2);
                    model = mean(allModels,2);
                    exponentials = mean(allExponentials,3);                    
                    %compute enveloping functions
                    leData = min(allData,[],2);       %lower envelope
                    ueData = max(allData,[],2);       %upper envelope
                    leModel = min(allModels,[],2);
                    ueModel = max(allModels,[],2);
                    %leExp = min(allExponentials,[],3);
                    %ueExp = max(allExponentials,[],3);
                    plotEnvelopes = true;
                case {4,5} 
                    if(get(this.visHandles.popupResultMode,'Value') == 4)
                        %best pixel
                        [y x] = this.getBestPixel(this.chi2PlotSel);
                    else
                        %worst pixel
                        [y x] = this.getWorstPixel(this.chi2PlotSel);
                    end
                    if(isempty(y))
                        return
                    end
                    [apObj xVec] = this.myResSubject.getVisParams(apObj,this.curChannel,y,x,false);
                    %get data and model for each pixel
                    data = single(squeeze(rawData(y,x,:)));
                    xAxis = this.myResSubject.timeVector(1:this.fileInfo.nrTimeChannels);
                    if(sum(xVec(:)) == 0)
                        model = [];
                    else
                        exponentials = apObj.getExponentials(this.curChannel,xVec,1);
                        model = apObj.getModel(this.curChannel,xVec,1);
                        model(model < 1e-1) = 1e-1;
                    end
                    %get exponentials
                    exponentials = squeeze(exponentials);
            end
%             this.updateProgressbar(0.7,'Plot Fit Result');
            staticVisParams = this.fluoDecayFitVisParams;
            %plot results
            if(get(this.visHandles.checkData,'Value'))
                %plot data
                FLIMXFitGUI.makeModelPlot(this.hAx,data,xAxis,'Data',this.dynVisParams,staticVisParams,'',[]);
                this.lStr(end+1) = {'Data (Result)'};                
                if(plotEnvelopes)
                    %plot enveloping functions                    
                    staticVisParams.plotDataColor = 'r';
                    staticVisParams.plotDataMarkerstyle = '.';
                    FLIMXFitGUI.makeModelPlot(this.hAx,leData,xAxis,'Data',this.dynVisParams,staticVisParams,'',[]);
                    this.lStr(end+1) = {'Data (Lower Envelope)'};
                    staticVisParams.plotDataColor = 'g';
                    FLIMXFitGUI.makeModelPlot(this.hAx,ueData,xAxis,'Data',this.dynVisParams,staticVisParams,'',[]);
                    this.lStr(end+1) = {'Data (Upper Envelope)'};
                end
%                 this.updateProgressbar(0.8,'Plot Fit Result');
            end
            
            if(get(this.visHandles.checkModel,'Value'))
                %plot model
                FLIMXFitGUI.makeModelPlot(this.hAx,model,xAxis,'ExpSum',this.dynVisParams,staticVisParams,'',[]);
                this.lStr(end+1) = {'Model (Result)'};
                if(plotEnvelopes)
                    %plot enveloping functions
                    staticVisParams.plotDataColor = 'm';
                    staticVisParams.plotDataMarkerstyle = 'none';
                    staticVisParams.plotDataLinestyle = '--';
                    FLIMXFitGUI.makeModelPlot(this.hAx,leModel,xAxis,'Data',this.dynVisParams,staticVisParams,'',[]);
                    this.lStr(end+1) = {'Model (Lower Envelope)'};
                    staticVisParams.plotDataColor = 'y';
                    FLIMXFitGUI.makeModelPlot(this.hAx,ueModel,xAxis,'Data',this.dynVisParams,staticVisParams,'',[]);
                    this.lStr(end+1) = {'Model (Upper Envelope)'};
                end
%                 this.updateProgressbar(0.9,'Plot Fit Result');
            end
            
            if(get(this.visHandles.checkExp,'Value'))
                %plot exponentials
                staticVisParams.plotExpLinestyle = '--';
                FLIMXFitGUI.makeExponentialsPlot(this.hAx,xAxis,apObj,apObj.getNonConstantXVec(this.curChannel,xVec),this.lStr,this.dynVisParams,staticVisParams,exponentials);
                for i = 1:apObj.basicParams.nExp
                %for i = 1:this.curResult
                    this.lStr(end+1) = {sprintf('Exp. %d (Result)',i)};
                end
%                 this.updateProgressbar(1,'Plot Fit Result');
            end
            set(this.hAx,'Yscale','log');
            set(this.hAx,'YLimMode','auto');
            set(this.hAx,'XTickMode','auto');
            set(this.hAx,'XTickLabelMode','auto');
%             this.updateProgressbar(0,'');
        end
        
        function makeArrayPlot(this)
            %make plot of selected parameter against array running parameter
            this.stop = false;
            if(~any(cell2mat(this.arraySubsetNames(:,2))))
                %no subset selected or all empty
                return
            end
            
            [data reference paraStr] = this.getCurArrayData();
            if(isempty(data))
                this.updateProgressbar(0,'');
                return
            end             
            switch(get(this.visHandles.popupArrayStats,'Value'))
                case 1
                    data = mean(data(~isnan(data(:,1)),:));
                case 2
                    data = median(data(~isnan(data(:,1)),:));
            end
            %make array plot
            subsets = this.arraySubsets(cell2mat(this.arraySubsetNames(:,2)),1);
            rID = simAnalysis.rID2paraName(subsets{1}.arrayParamNr,subsets{1}.nrExponentials);
            this.updateProgressbar(0.8,sprintf('Plot Parameter against %s',rID));
            xAxis = this.getArrayRunningParameter();
            set(this.hAx,'Visible','On');
            set(this.hAx,'Yscale','lin');
            plot(this.hAx,xAxis,data,'-b','Linewidth',2);
            hold(this.hAx,'on');
            xLim = get(this.hAx,'XLim');
            xVal = linspace(xLim(1),xLim(2),length(xAxis));
            if(~isempty(reference))
                %plot reference line
                plot(this.hAx,xVal,reference,'r--');
                %check boundary values
                yLim = get(this.hAx,'YLim');
                yLim(1) = min(min(reference),yLim(1));
                yLim(2) = max(max(reference),yLim(2));
                set(this.hAx,'YLim',yLim);
            end
            hold(this.hAx,'off');
            this.updateProgressbar(0.9,'Create Boxplot');
            ylabel(this.hAx,paraStr);
            xlabel(this.hAx,rID);
            set(this.hAx,'Position',[250 295 890 340]);
            set(this.hAx,'Visible','On');
            this.updateProgressbar(0,'');
        end
        
        function makeStatsTable(this,paraSetName,channel)
            %make statistics tables
            this.stop = false;
            if(isempty(this.FLIMXObj.sDDMgr.getAllSDDNames()))
                return
            end

            %get parameter, raw data and model
            sdc = this.getSynthDataCh(paraSetName,channel);
            if(isempty(sdc))
                return
            end
            
%             this.updateProgressbar(0.1,'Gathering Statistical Data');
            rowNames = cell(1,sdc.nrExponentials);
            for i = 1:sdc.nrExponentials
                rowNames(i) = {sprintf('Exp. %d',i)};
            end
            paraSetData = cell(sdc.nrExponentials,5);
            resultDiffData = cell(0,0);
            resultStatsData = cell(0,0);
            paraSetData(:,1) = rowNames;
            
            paraSetValues = zeros(sdc.nrExponentials,5);
            if(~isempty(sdc.xVec))
                paraSetValues(:,1) = sdc.xVec(1:sdc.nrExponentials).*max(sdc.modelData(:)); %Amps
                paraSetValues(:,2) = sdc.xVec(1:sdc.nrExponentials)./sum(sdc.xVec(1:sdc.nrExponentials)).*100; %AmpsPercent
                paraSetValues(:,3) = sdc.xVec(sdc.nrExponentials+1:sdc.nrExponentials*2); %Taus
                paraSetValues(:,4) = sdc.xVec(sdc.nrExponentials*2+1:sdc.nrExponentials*3); %Tcis
                paraSetValues(:,5) = simFLIM.computeQs(sdc.xVec(1:sdc.nrExponentials),sdc.xVec(sdc.nrExponentials+1:sdc.nrExponentials*2)); %Qs
            end
            
            for i = 1:size(paraSetValues,1)
                for j = 1:size(paraSetValues,2)
                    paraSetData(i,j+1) = {num2str(paraSetValues(i,j),'%.3G')};
                end
            end
            %get data from result
            if(this.curResultChanIsAvailable)
                %get result data and differences to simulation parameter
                chi2 = this.myResSubject.getPixelFLIMItem(this.curChannel,'chi2');
                chi2Tail = this.myResSubject.getPixelFLIMItem(this.curChannel,'chi2Tail');
                offset = this.myResSubject.getPixelFLIMItem(this.curChannel,'Offset');
                functionEvaluations = this.myResSubject.getPixelFLIMItem(this.curChannel,'FunctionEvaluations');
                t = this.myResSubject.getPixelFLIMItem(this.curChannel,'Time');
                nExp = this.myResSubject.basicParams.nExp;               
                switch get(this.visHandles.popupResultStatsMode,'Value')
                    case 1
                        %whole dataset (mean value)
                        amps = zeros(nExp,1);
                        ampsPercent = zeros(nExp,1);                        
                        taus = zeros(nExp,1);
                        tcis = zeros(nExp,1);
                        for i = 1:nExp
                            tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('Amplitude%d',i));
                            amps(i) = mean(tmp(:));
                            tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('AmplitudePercent%d',i));
                            ampsPercent(i) = mean(tmp(:));
                            tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('Tau%d',i));
                            taus(i) = mean(tmp(:));
                            if(this.myResSubject.basicParams.tciMask(i))
                                tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('tc%d',i));
                                tcis(i) = mean(tmp(:));
                            end
                        end
                        
                        chi2 = mean(chi2(:));
                        chi2Tail = mean(chi2Tail(:));
                        offset = mean(offset(:));
                        functionEvaluations = mean(functionEvaluations(:));
                        t = mean(t(:));
                    case {2,3}
                        if(get(this.visHandles.popupResultStatsMode,'Value') == 2)
                            %best pixel
                            [y, x] = this.getBestPixel(this.chi2StatsSel);
                        else
                            %worst pixel
                            [y, x] = this.getWorstPixel(this.chi2StatsSel);
                        end
                        if(isempty(y))
                            return
                        end
                        amps = zeros(nExp,1);
                        ampsPercent = zeros(nExp,1);
                        taus = zeros(nExp,1);
                        tcis = zeros(nExp,1);
                        for i = 1:nExp
                            amps(i) = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('AmplitudePercent%d',i),y,x);
                            ampsPercent(i) = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('AmplitudePercent%d',i),y,x);
                            taus(i) = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('Tau%d',i),y,x);
                            if(this.myResSubject.basicParams.tciMask(i))
                                tcis(i) = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('tc%d',i),y,x);
                            end
                        end
                        chi2 = chi2(y,x);
                        chi2Tail = chi2Tail(y,x);
                        offset = offset(y,x);
                        functionEvaluations = functionEvaluations(y,x);
                        t = t(y,x);
                end
                %compute differences to simulation parameter set
                as = sum(ampsPercent(:));
                resultDiffs = zeros(nExp,10);
                resultDiffs(:,1) = amps;
                resultDiffs(:,2) = simAnalysis.computeDiff(paraSetValues(1:min(nExp,sdc.nrExponentials),1),amps,get(this.visHandles.checkPercentDiffs,'Value'));
                resultDiffs(:,3) = ampsPercent;
                resultDiffs(:,4) = simAnalysis.computeDiff(paraSetValues(1:min(nExp,sdc.nrExponentials),1),100*ampsPercent./as,get(this.visHandles.checkPercentDiffs,'Value'));
                resultDiffs(:,5) = taus;
                resultDiffs(:,6) = simAnalysis.computeDiff(paraSetValues(1:min(nExp,sdc.nrExponentials),2),taus,get(this.visHandles.checkPercentDiffs,'Value'));
                resultDiffs(:,7) = tcis;
                resultDiffs(:,8) = simAnalysis.computeDiff(paraSetValues(1:min(nExp,sdc.nrExponentials),3),tcis,get(this.visHandles.checkPercentDiffs,'Value'));
                resultDiffs(:,9) = simFLIM.computeQs(ampsPercent,taus);
                resultDiffs(:,10) = simAnalysis.computeDiff(paraSetValues(1:min(nExp,sdc.nrExponentials),4),resultDiffs(:,7),get(this.visHandles.checkPercentDiffs,'Value'));                
%                 this.updateProgressbar(0.7,'Gathering Statistical Data');
                %compute errror sums in percent
                [errAmps, errTaus, errTotal] = this.computeErrorSums(paraSetValues(1:min(nExp,sdc.nrExponentials),2),100*ampsPercent./as,...
                    paraSetValues(1:min(nExp,sdc.nrExponentials),3),taus);
                %get result specific statistics
                resultStatsData = cell(8,2);
                resultStatsData(:,1) = {'Chi2';'Chi2 Tail';'Offset';'FuncEvals';'Time';'Err. Amps.(%)';'Err. Taus(%)';'Total Err. (%)'};
                resultStatsData(1,2) = {num2str(chi2,'%.3G')};
                resultStatsData(2,2) = {num2str(chi2Tail,'%.3G')};
                resultStatsData(3,2) = {num2str(offset,'%.3G')};
                resultStatsData(4,2) = {num2str(functionEvaluations,'%.3G')};
                resultStatsData(5,2) = {num2str(t,'%.3G')};
                resultStatsData(6,2) = {num2str(errAmps,'%.3G')};
                resultStatsData(7,2) = {num2str(errTaus,'%.3G')};
                resultStatsData(8,2) = {num2str(errTotal,'%.3G')};
%                 this.updateProgressbar(0.9,'Gathering Statistical Data');
                
                %convert to strings                
                resultDiffData = cell(size(resultDiffs));
                for i = 1:size(resultDiffs,1)
                    for j = 1:size(resultDiffs,2)
                        resultDiffData(i,j) = {num2str(resultDiffs(i,j),'%.3G')};
                    end
                end                
%                 this.updateProgressbar(1,'');
            end
            %update offset
            set(this.visHandles.editOffsetPhotons,'String',num2str(sdc.offset));
            %update tables
            set(this.visHandles.tableSimParaSet,'Data',paraSetData);
            set(this.visHandles.tableResultDiffs,'Data',resultDiffData);
            set(this.visHandles.tableResultStats,'Data',resultStatsData);
%             this.updateProgressbar(0,'');
        end
        
        function makeSelResultTable(this)
            %make table for selected result parameter
            if(~this.curResultChanIsAvailable || isempty(this.curParameter))
                set(this.visHandles.tableSelectedResult,'Data',[]);
                return
            end
            descrStats = cell(9,2);
            descrStats(:,1) = {'Mode';'Mean';'Median';'Var';'SD';'Skew.';'Kurt.';'CI low';'CI high'};
            
%             this.updateProgressbar(0.2,'Compute Statistics for selected Parameter');
            [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(this.curParameter);
            [pMode, pMean, pMedian, pVar, pStd, pSkew, pKurt, pCIl, pCIh, data] = this.computeParaStats(dType,dTypeNr);
%             this.updateProgressbar(0.6,'Compute Statistics for selected Parameter');
            descrStats(1,2) = {num2str(pMode,'%.3G')};
            descrStats(2,2) = {num2str(pMean,'%.3G')};
            descrStats(3,2) = {num2str(pMedian,'%.3G')};
            descrStats(4,2) = {num2str(pVar,'%.3G')};
            descrStats(5,2) = {num2str(pStd,'%.3G')};
            descrStats(6,2) = {num2str(pSkew,'%.3G')};
            descrStats(7,2) = {num2str(pKurt,'%.3G')};
            descrStats(8,2) = {num2str(pCIl,'%.3G')};
            descrStats(9,2) = {num2str(pCIh,'%.3G')};
%             this.updateProgressbar(0.8,'Make histogram for selected Parameter');
            this.makeHist(data);
%             this.updateProgressbar(0.9,'Make histogram for selected Parameter');
            %update table
            set(this.visHandles.tableSelectedResult,'Data',descrStats);
%             this.updateProgressbar(0,'');
        end
        
        function makeHist(this,dataVec)
            %make histogram for selected result parameter
            if(isempty(dataVec) || ~any(dataVec))
                cla(this.histAx)
                axis(this.histAx,'off');
                return
            end
            rh = [];
            nc = round(max(3,min(numel(dataVec)/10,100)));
            nc = nc + rem(nc,2)+1;
            yl = min(dataVec);
            yh = max(dataVec);
            if(yl ~= yh)
                binVec = linspace(yl,yh,nc);
                rh = hist(dataVec,binVec);
            end
            if(any(rh))
                bh = barh(this.histAx,binVec,rh,'hist');
                xlim(this.histAx,[0 max(rh(:))]);
                ylim(this.histAx,[yl yh]);
                set(bh,'FaceColor','r','LineStyle','none');
                set(this.histAx,'XTickLabel','');
                set(this.histAx,'YTickLabel','');
            else
                cla(this.histAx)
                axis(this.histAx,'off');
            end
        end
        
        function [data, refVal, paraStr] = getCurArrayData(this)
            %get array data for current GUI settings
            paraStr = '';
            str = get(this.visHandles.popupResultMode,'String');
            if(~isempty(str) && iscell(str))
                paraStr = str{get(this.visHandles.popupResultMode,'Value')};
            elseif(ischar(str))
                paraStr = str;
            end            
            [data, refVal] = this.getArrayData(paraStr);
        end
        
        function [data, refVal] = getArrayData(this,paraStr)
            %return array data and reference value for parameter
            if(isempty(paraStr))                
                data = [];
                refVal = [];
                return
            end
            payload = this.arrayData.getDataByID(paraStr);
            if(isempty(payload))
                [payload{1}, payload{2}] = this.computeArrayData(paraStr);
                this.arrayData.insertID(payload,paraStr);
            end            
            data = payload{1};
            refVal = payload{2};
        end
        
        function [data, refVal] = computeArrayData(this,paraStr)
            %gather data for selected parameter out of parameter set array
            [pStr, pNr] = FLIMXVisGUI.FLIMItem2TypeAndID(paraStr);
            pStr = lower(pStr{1});
            %get initial parameters from first subset
            subsets = this.arraySubsets(cell2mat(this.arraySubsetNames(:,2)),1);
            if(isempty(subsets))
                return
            end
            persistent lastUpdate
            subsetNames = this.arraySubsetNames(cell2mat(this.arraySubsetNames(:,2)),1);
            x = subsets{1}.sizeX;
            y = subsets{1}.sizeY;
            data = zeros(x*y,length(subsetNames));
            tmp = zeros(y,x);
            refVal = zeros(1,length(subsets));
            for k = 1:length(subsetNames);
                %load result into fluodecay fit
                this.loadResult(subsetNames{k});
                if(~this.resultIsAvailable(this.curStudy,subsetNames{k},this.curChannel))
                    %result not available for selected channel
                    continue
                end
                %gather data from all subResults
                switch pStr
                    case 'amplitude' %amplitudes
                        tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('Amplitude%d',pNr));
                        refVal(k) = subsets{k}.xVec(pNr).*max(subsets{k}.modelData(:));
                    case 'amplitudepercent' %amplitudespercent
                        tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('AmplitudePercent%d',pNr));
                        refAs = sum(subsets{k}.xVec(1:subsets{k}.nrExponentials));
                        refVal(k) = 100*subsets{k}.xVec(pNr)/refAs;
                    case 'tau' %taus
                        tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('Tau%d',pNr));
                        refVal(k) = subsets{k}.xVec(subsets{k}.nrExponentials+pNr);
                    case 'tc' %tcis
                        tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('tc%d',pNr));
                        refVal(k) = subsets{k}.xVec(2*subsets{k}.nrExponentials+pNr);
                    case 'q' %Qs
                        tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('Q%d',pNr));
                        refQs = simFLIM.computeQs(subsets{k}.xVec(1:subsets{k}.nrExponentials).*100,subsets{k}.xVec(subsets{k}.nrExponentials+1:2*subsets{k}.nrExponentials));
                        refVal(k) = refQs(pNr);
                    case 'beta' %betas
                        tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,sprintf('Beta%d',pNr));
                    case 'chi2'
                        tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,'chi2');
                    case 'chi2tail'
                        tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,'chi2Tail');
                    case 'offset'
                        tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,'Offset');
                        refVal(k) = subsets{k}.offset;
                    case 'functionevaluations'
                        tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,'FunctionEvaluations');
                    case 'time'
                        tmp = this.myResSubject.getPixelFLIMItem(this.curChannel,'Time');
                end
                if(this.stop)
%                    this.stop = false;
                    this.updateProgressbar(0,'');
                    return
                end
                if(isempty(lastUpdate) || etime(clock, lastUpdate) > 0.5)
                    lastUpdate = clock;
                    this.updateProgressbar(k/length(subsetNames),'Gathering Data from Parameter Set Array');
                end
                if(isempty(tmp))                    
                    continue
                end
                n = x*y;
                iStart = max(1,floor((n-length(tmp))/2));
                data(:,k) = tmp(iStart:iStart+n-1); %if we have more values than we need, take them roughly from the center               
            end
            this.updateProgressbar(0,'');
        end
        
        function clearArrayData(this)
            %clear array data and current result object handle
            this.arrayData.removeAll();
        end
        
        function updateProgressbar(this,x,text)
            %update progress bar, progress x: 0..1, varargin{1}: title (currently unused), varargin{2}: text on progressbar
            x = max(0,min(100*x,100));                      
            xpatch = [0 x x 0];
            set(this.visHandles.patchWait,'XData',xpatch,'Parent',this.visHandles.axesProgress)
            yl = ylim(this.visHandles.axesProgress);
            set(this.visHandles.textWait,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.axesProgress);            
            drawnow;
        end
        
        %% GUI callbacks        
        function GUI_buttonClose_Callback(this,hObject,eventdata)
            %close parameter set manager
            if(~isempty(this.visHandles) && ishandle(this.visHandles.simAnalysisFigure))
                delete(this.visHandles.simAnalysisFigure);
            end
        end
        
        function GUI_buttonExportStats_Callback(this,hObject,eventdata)
            %export statistics to excel file
            if(isempty(this.curParaSetName) || ~this.curResultChanIsAvailable)
                return
            end
            
            %get file name
            [file path] = uiputfile({'*.xls','Excel file (*.xls)'},'Export to Excel file');
            if(file==0)
                return;
            end
            fn = fullfile(path,file);
            
            %user request for export mode
            choice = questdlg('Include statistics for each parameter?','Select export mode','Yes','No','Cancel','Yes');
            switch choice
                case 'Yes'
                    %include statistics
                    mode = 1;
                case 'No'
                    %only export comparison and standard result parameter
                    mode = 0;
                otherwise
                    return
            end
            
            %export statistics
            this.exportXLS(fn,mode);            
        end
        
        function GUI_buttonExportArrayStats_Callback(this,hObject,eventdata)
            %export statistics of parameter set array
            if(isempty(this.curParaSetName) || isempty(this.curArrayName) || ~any(cell2mat(this.arraySubsetNames(:,2))))
                %no subset selected
                return
            end
                       
            [file, path] = uiputfile({'*.xls','Excel file (*.xls)'},'Export to Excel file');
            if(file==0)
                return;
            end
            fn = fullfile(path,file);            
            %get parameters to export
            paraStr = simAnalysis.getParameterStr(this.myResSubject.basicParams.nExp,this.myResSubject.basicParams.stretchedExpMask);            
            [paramSelection, ok] = listdlg('PromptString','Select parameters to export:','ListString',paraStr,'ListSize',[300 300]);            
            if(ok == 0 || isempty(paramSelection))
                return
            end
            this.stop = false; 
            this.exportArrayStatistics(fn,{this.curStudy},paramSelection);
            this.updateGUI();
            this.makeMainPlot();
        end
        
        function GUI_buttonExportMultArrayStats_Callback(this,hObject,eventdata)
            %export statistics of parameter set array(s)
            aStr = this.FLIMXObj.sDDMgr.getAllArrayParamSetNames(this.curChannel);
            if(isempty(aStr))
                return
            end
            %ask user
            [arraySelection, ok] = listdlg('PromptString','Select arrays to export:','ListString',aStr,'ListSize',[300 300]);
            if(ok == 0 || isempty(arraySelection))
                return
            end
            this.setCurArraySet(aStr{1});
            %get studies to export
            studies = this.FLIMXObj.fdt.getAllStudyNames();
            [studySelection, ok] = listdlg('PromptString','Select parameter arrays to export:','ListString',studies,'ListSize',[300 300]);
            if(ok == 0 || isempty(studySelection))
                return
            end
            studies = studies(studySelection);
            this.setCurStudy(studies{1});
            %get parameters to export
            paraStr = simAnalysis.getParameterStr(this.myResSubject.basicParams.nExp,this.myResSubject.basicParams.stretchedExpMask);
            [paramSelection, ok] = listdlg('PromptString','Select parameters to export:','ListString',paraStr,'ListSize',[300 300]);
            if(ok == 0 || isempty(paramSelection))
                return
            end
            %loop over arrays
            for i = arraySelection
                this.setCurArraySet(aStr{i});
                this.stop = false;
                this.exportArrayStatistics(fullfile(cd,aStr{i}),studies,paramSelection);
            end
            this.updateGUI();
            this.makeMainPlot();
        end
        
        function exportArrayStatistics(this,fn,studies,paramSelection)
            %write array statistics to excel file
            paraStr = simAnalysis.getParameterStr(this.myResSubject.basicParams.nExp,this.myResSubject.basicParams.stretchedExpMask);
            paraStr = paraStr(paramSelection);
            oldStudy = this.curStudy;
            oldParam = get(this.visHandles.popupResultMode,'Value');
            set(this.visHandles.popupResultMode,'Value',paramSelection(1));            
            subsets = this.arraySubsets(cell2mat(this.arraySubsetNames(:,2)),1); 
            rID = simAnalysis.rID2paraName(subsets{1}.arrayParamNr,subsets{1}.nrExponentials);
            dataTmp = this.makeArrayStatisticsTable(this.getArrayData(paraStr{1}),rID);
            %loop over parameters            
            for paramID = 1:length(paramSelection)
                data = cell(size(dataTmp,1),2+length(studies)*2);
                colHeaders = cell(1,2+length(studies)*2);
                %loop over studies
                for studyID = 1:length(studies)
                    %set new study and array
                    this.setCurStudy(studies{studyID});
                    [dataTmp0, refVal] = this.getArrayData(paraStr{paramID});
                    dataTmp = this.makeArrayStatisticsTable(dataTmp0,rID);
                    data(:,2+2*(studyID-1)+1) = num2cell(dataTmp(:,3)); %mean
                    data(:,2+2*(studyID-1)+2) = num2cell(dataTmp(:,5)); %sdt
                    colHeaders(1,2+2*(studyID-1)+1) = {['mean ' studies{studyID}]};
                    colHeaders(1,2+2*(studyID-1)+2) = {['sdt ' studies{studyID}]};
                end
                %export
                colHeaders(1,1) = {rID};
                colHeaders(1,2) = {'reference'};
                data(:,1) = num2cell(dataTmp(:,1)); %running parameter of array
                data(:,2) = num2cell(refVal); %reference
                tableName = '';
                sheetName = sprintf('%s',paraStr{paramID});
                rowHeaders = cell(size(data{paramID},1),1);
                exportExcel(fn,data,colHeaders,rowHeaders,sheetName,tableName);
                if(this.stop)
                    this.stop = false;
                    break
                end
            end
            this.setCurStudy(oldStudy);
            set(this.visHandles.popupResultMode,'Value',oldParam);
        end
        
        function [data, colHeaders] = makeArrayStatisticsTable(this,arrayDataP,rID)
            %make statistics of an array
            runningP = this.getArrayRunningParameter();
            data = zeros(length(runningP),11);
            data(:,1) = runningP;
            arrayDataP(isnan(arrayDataP)) = [];
            data(:,2) = median(arrayDataP);
            data(:,3) = mean(arrayDataP);
            data(:,4) = var(arrayDataP);
            data(:,5) = sqrt(data(:,4));
            data(:,6) = skewness(arrayDataP);
            data(:,7) = kurtosis(arrayDataP);
            data(:,10) = sum(arrayDataP,1);
            for j = 1:size(arrayDataP,2)
                data(j,11) = numel(arrayDataP(:,j));
                t = icdf('t',1-(1-0.95)/2,data(j,11)-1); %confidence level 95%
                data(j,8) = data(j,3) - t*data(j,5)/sqrt(data(j,11));
                data(j,9) = data(j,3) + t*data(j,5)/sqrt(data(j,11));
            end
            colHeaders = {rID,'Median','Mean','Variance','Standard Deviation','Skewness','Kurtosis','Confidence Interval (lower)','Confidence Interval (upper)','Total','Pixel'};                
        end
        
        function GUI_buttonExportMultStats_Callback(this,hObject,eventdata)
            %batch export of statistics for each parameter set within
            %parameter set array
            if(isempty(this.curParaSetName))
                return
            end            
            this.stop = false;
            path = uigetdir_workaround('','Select Export Folder');
            if(path==0)
                return
            end
            allNames = this.FLIMXObj.sDDMgr.getAllSDDNames();
            %get sets to export
            [selection, ok] = listdlg('PromptString','Select Parameter Sets to export:',...
                'ListString',allNames);
            
            if(ok == 0 || isempty(selection))
                return
            end            
            %user request for export mode
            choice = questdlg('Include statistics for each parameter?','Select export mode','Yes','No','Cancel','Yes');
            switch choice
                case 'Yes'
                    %include statistics
                    mode = 1;
                case 'No'
                    %only export comparison and standard result parameter
                    mode = 0;
                otherwise
                    return
            end            
            %export statistics
            for i = 1:length(selection)
                if(this.stop)
                    this.stop = false;
                    break
                end
                pStr = get(this.visHandles.popupParaSets,'String');
                idx = find(strcmp(allNames{selection(i)},pStr),1);
                if(~isempty(idx))
                    set(this.visHandles.popupParaSets,'Value',idx);
                    this.GUI_popupParaSets_Callback(this.visHandles.popupParaSets,[]);
                    fn = fullfile(path,sprintf('SimulationAnalysis_%s.xls',allNames{selection(i)}));
                    this.exportXLS(fn,mode);
                end
            end
            %load result from before
            this.loadResult(this.curParaSetName);
            this.updateGUI();
        end
        
        function GUI_buttonScreenshot_Callback(this,hObject,eventdata)
            %create screenshot of current plot
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
            this.updateProgressbar(0.1,'Create Screenshot');
            %create new figure
            hFig = figure;
            h = axes;
            set(h,'FontSize',this.FLIMXObj.FLIMFitGUI.exportParams.labelFontSize);
            this.updateProgressbar(0.2,'Create Screenshot');
            %copy content of main axes            
            hAxChildren = get(this.hAx,'Children');
            newHandle = copyobj(hAxChildren,h);
            this.updateProgressbar(0.5,'Create Screenshot');
            %make sure that temporary figure is scaled correctly
            xlim = get(this.hAx,'XLim');
            set(h,'YScale','log','XLim',xlim);
            legend(this.lStr);
            this.updateProgressbar(0.7,'Create Screenshot');
            %finally, create the screenshot
            if(filterindex == 8)
                hgsave(hFig,fn);
            else
                print(hFig,str,['-r' num2str(this.FLIMXObj.FLIMFitGUI.exportParams.dpi)],fn);
            end
            this.updateProgressbar(1,'Create Screenshot');
            if(ishandle(hFig))
                close(hFig);
            end
            this.updateProgressbar(0,'');
        end
        
        function GUI_buttonTimeScal_Callback(this,hObject,eventdata)
            %call of button for time scaling control
            switch(hObject)
                case this.visHandles.buttonTimeScalStartInc
                    this.dynVisParams.timeScalingStart = max(min(this.dynVisParams.timeScalingStart +1,this.dynVisParams.timeScalingEnd-1),1);
                    set(this.visHandles.editTimeScalStart,'String',num2str(this.dynVisParams.timeScalingStart*this.myResSubject.timeChannelWidth,'%.02f'));
                case this.visHandles.buttonTimeScalStartDec
                    this.dynVisParams.timeScalingStart = max(min(this.dynVisParams.timeScalingStart -1,this.dynVisParams.timeScalingEnd-1),1);
                    set(this.visHandles.editTimeScalStart,'String',num2str(this.dynVisParams.timeScalingStart*this.myResSubject.timeChannelWidth,'%.02f'));
                case this.visHandles.buttonTimeScalEndInc
                    this.dynVisParams.timeScalingEnd = min(max(this.dynVisParams.timeScalingEnd+1,this.dynVisParams.timeScalingStart+1),this.myResSubject.nrTimeChannels);
                    set(this.visHandles.editTimeScalEnd,'String',num2str(this.dynVisParams.timeScalingEnd*this.myResSubject.timeChannelWidth,'%.02f'));
                case this.visHandles.buttonTimeScalEndDec
                    this.dynVisParams.timeScalingEnd = min(max(this.dynVisParams.timeScalingEnd-1,this.dynVisParams.timeScalingStart+1),this.myResSubject.nrTimeChannels);
                    set(this.visHandles.editTimeScalEnd,'String',num2str(this.dynVisParams.timeScalingEnd*this.myResSubject.timeChannelWidth,'%.02f'));
            end
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_buttonSelectSubsets_Callback(this,hObject,eventdata)
            %callback of subset selection
            if(isempty(this.arraySubsets))
                return
            end
            this.arraySubsetNames(this.selectedSubsets,2) = {true};
            this.updateGUI();
            this.clearArrayData();
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_buttonDeselectSubsets_Callback(this,hObject,eventdata)
            %callback of subset deselection
            if(isempty(this.arraySubsets))
                return
            end
            this.arraySubsetNames(this.selectedSubsets,2) = {false};
            this.updateGUI();
            this.clearArrayData();
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_editTimeScal_Callback(this,hObject,eventdata)
            %call of editTimeScal control
            current = round(abs(str2double(get(hObject,'String')))/this.myResSubject.timeChannelWidth);
            if(hObject == this.visHandles.editTimeScalStart)
                current = max(min(current,this.dynVisParams.timeScalingEnd-1),1);
                this.dynVisParams.timeScalingStart = current;
            else
                current = min(max(current,this.dynVisParams.timeScalingStart+1),this.myResSubject.nrTimeChannels);
                this.dynVisParams.timeScalingEnd = current;
            end
            set(hObject,'String',num2str(current*this.myResSubject.timeChannelWidth,'%.02f'));
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_popupParaSets_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            if(isempty(this.curParaSetName))
                return
            end            
            %check channel
            sdd = this.getSynthDataDef(this.curParaSetName);
            if(isempty(sdd.getChannel(this.curChannel)))
                [~, mask] = sdd.nonEmptyChannelStr();
                set(this.visHandles.popupChannel,'Value',find(mask,1));
            end
            
            if(~isempty(this.curArrayName) && this.showArray)
                %update possible parameter set arrays
%                 this.loadArrayParaSets();
%                 this.clearArrayData();
            else
                %load latest result
                this.loadResult(this.curParaSetName);
            end
            %update GUI and make plots
            this.setupGUI();            
            this.updateGUI();
            this.makeMainPlot();
        end
        
        function GUI_buttonStop_Callback(this,hObject,eventdata)
            %set stop flag
            this.stop = true;
        end
        
        function GUI_popupStudy_Callback(this,hObject,eventdata)
            %
            this.setCurStudy(this.curStudy);
        end
        
        function setCurStudy(this,studyName)
            %set the GUI to study
            %we expect studyName to be set in popupStudy
            str = get(this.visHandles.popupStudy,'String');
            id = find(strcmp(str,studyName),1);
            if(~isempty(id))
                set(this.visHandles.popupStudy,'Value',id)
                this.clearMainPlot();
                this.loadArrayParaSets();
                this.clearArrayData();
                if(isempty(this.arraySubsets) || ~this.curResultChanIsAvailable)
                    arrayName = this.findArrayParaSet4Study(this.curStudy,this.curChannel);
                    if(~isempty(arrayName))
                        this.setCurArraySet(arrayName);
                    else
                        this.setupGUI();
                        this.loadResult(this.curParaSetName);
                        this.updateGUI();
                        this.makeMainPlot();
                    end
                else
                    this.updateGUI();
                    this.clearArrayData();
                    this.clearMainPlot();
                    this.makeMainPlot();
                end                
            end
        end
        
        function setCurArraySet(this,arrayName)
            %set the GUI to array
            %we expect arrayName to be set in popupParaSetArrays
            str = get(this.visHandles.popupParaSetArrays,'String');
            id = find(strcmp(str,arrayName),1);
            if(~isempty(id))
                set(this.visHandles.popupParaSetArrays,'Value',id)
                this.clearMainPlot();
                set(this.visHandles.toggleShowSubset,'Value',0);
                this.loadArrayParaSets();
                this.clearArrayData();
                this.setupGUI();
                this.updateGUI();
                this.makeMainPlot();
            end
        end
        
        function GUI_popupDisplayMode_Callback(this,hObject,eventdata)
            %            
            this.clearMainPlot(); 
            this.updateGUI();
            this.makeMainPlot();
        end
        
        function GUI_popupResultMode_Callback(this,hObject,eventdata)
            %            
            this.clearMainPlot();
            this.updateGUI();
            this.makeMainPlot();
        end
        
        function GUI_popupResultStatsMode_Callback(this,hObject,eventdata)
            %            
            this.updateGUI();
        end
        
        function GUI_popupParaSelection_Callback(this,hObject,eventdata)
            %
            this.makeSelResultTable();
        end
        
        function GUI_popupArrayStats_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_popupArraySubsets_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            if(~this.showArray)
                %load latest result
                this.loadResult(this.curParaSetName);
            end
            
            this.setupGUI();
            this.updateGUI();
            this.makeMainPlot();
        end
        
        function GUI_popupParaSetArrays_Callback(this,hObject,eventdata)
            %
            if(isempty(this.paraSetNames))
                return
            end
            this.clearMainPlot();
            if(~isempty(this.curArrayName))
                this.setCurArraySet(this.curArrayName);
            else
                %load latest result
                this.setupGUI();
                this.loadResult(this.curParaSetName);                
                this.updateGUI();
                this.makeMainPlot();
            end
        end
        
        function GUI_popupChannel_Callback(this,hObject,eventdata)
            %
            if(isempty(this.paraSetNames))
                return
            end
            this.clearMainPlot();
            this.loadArrayParaSets();
            if(~isempty(this.arraySubsets))
                this.clearArrayData();
            end            
            %load other channel of current result
            this.loadResult(this.curParaSetName);            
            this.setupGUI();
            this.updateGUI();
            this.makeMainPlot();
        end
        
        function GUI_checkExp_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_checkModel_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_checkData_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_checkPercentDiffs_Callback(this,hObject,eventdata)
            %            
            this.clearMainPlot();
            this.makeMainPlot();
            this.updateGUI();
        end
        
        function GUI_checkAmps_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_checkAmpsPercent_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            this.makeMainPlot();
        end

        function GUI_checkTaus_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_checkTcis_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_checkQs_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_checkChi2_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_checkOffset_Callback(this,hObject,eventdata)
            %
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_toggleShowSubset_Callback(this,hObject,eventdata)
            %enable / disable analysis of parameter set array
            if(get(hObject,'Value'))
                %load latest result
                this.loadResult(this.curParaSetName);
            end
            if(~this.curResultChanIsAvailable)
                return
            end
            this.clearMainPlot();
            this.setupGUI();
            this.updateGUI();
            this.makeMainPlot();
        end
        
        function GUI_radioChi2Plot_Callback(this,hObject,eventdata)
            %select parameter to determine best/worst pixel in dataset
            this.chi2PlotSel = 1;
            set(this.visHandles.radioChi2Plot,'Value',1);
            set(this.visHandles.radioChi2TailPlot,'Value',0);
            if(get(this.visHandles.popupResultMode,'Value') > 3)
                this.clearMainPlot();
                this.makeMainPlot();
            end
        end
        
        function GUI_radioChi2TailPlot_Callback(this,hObject,eventdata)
            %select parameter to determine best/worst pixel in dataset
            this.chi2PlotSel = 2;
            set(this.visHandles.radioChi2Plot,'Value',0);
            set(this.visHandles.radioChi2TailPlot,'Value',1);
            if(get(this.visHandles.popupResultMode,'Value') > 3)
                this.clearMainPlot();
                this.makeMainPlot();
            end
        end
        
        function GUI_radioChi2Stats_Callback(this,hObject,eventdata)
            %select parameter to determine best/worst pixel in dataset
            this.chi2StatsSel = 1;
            set(this.visHandles.radioChi2Stats,'Value',1);
            set(this.visHandles.radioChi2TailStats,'Value',0);
            this.makeStatsTable(this.curParaSetName,this.curChannel);
            this.makeSelResultTable();
        end
        
        function GUI_radioChi2TailStats_Callback(this,hObject,eventdata)
            %select parameter to determine best/worst pixel in dataset
            this.chi2StatsSel = 2;
            set(this.visHandles.radioChi2Stats,'Value',0);
            set(this.visHandles.radioChi2TailStats,'Value',1);
            this.makeStatsTable(this.curParaSetName,this.curChannel);
            this.makeSelResultTable();
        end
        
        function GUI_radioTimeScal_Callback(this,hObject,eventdata)
            %call of radioTimeScal control
            if(hObject == this.visHandles.radioTimeScalAuto)
                set(this.visHandles.radioTimeScalManual,'Value',~get(this.visHandles.radioTimeScalAuto,'Value'));
            else
                set(this.visHandles.radioTimeScalAuto,'Value',~get(this.visHandles.radioTimeScalManual,'Value'));
            end
            this.dynVisParams.timeScalingAuto = get(this.visHandles.radioTimeScalAuto,'Value');
            flag = 'off';
            if(~this.dynVisParams.timeScalingAuto)
                flag = 'on';
                set(this.visHandles.editTimeScalStart,'String',num2str(this.dynVisParams.timeScalingStart*this.myResSubject.timeChannelWidth,'%.02f'));
                set(this.visHandles.editTimeScalEnd,'String',num2str(this.dynVisParams.timeScalingEnd*this.myResSubject.timeChannelWidth,'%.02f'));
            end
            set(this.visHandles.buttonTimeScalStartDec,'Enable',flag);
            set(this.visHandles.buttonTimeScalStartInc,'Enable',flag);
            set(this.visHandles.buttonTimeScalEndDec,'Enable',flag);
            set(this.visHandles.buttonTimeScalEndInc,'Enable',flag);
            set(this.visHandles.editTimeScalStart,'Enable',flag);
            set(this.visHandles.editTimeScalEnd,'Enable',flag);
            this.clearMainPlot();
            this.makeMainPlot();
        end
        
        function GUI_tableSimParaSelection_Callback(this,hObject,eventdata)
            %select result parameter from selection in tableSimParaSelection            
            idx = eventdata.Indices;
            if(~this.curResultChanIsAvailable || isempty(idx))
                return
            end
            
            switch idx(2)
                case {1,2} %Amps
                    type = 'Amplitude';
                case 3 %Taus
                    type = 'Tau';
                case 4 %tcis
                    type = 'tc';
                case 5 %Qs
                    type = 'Q';
            end
            paraID = sprintf('%s %d',type,idx(1));
            paraStr = simAnalysis.getParameterStr(this.myResSubject.basicParams.nExp,this.myResSubject.basicParams.stretchedExpMask);
            [tf pos] = ismember(paraID,paraStr);
            if(tf)
                set(this.visHandles.popupParaSelection,'Value',pos);
            else
                set(this.visHandles.popupParaSelection,'Value',1);
            end
            this.makeSelResultTable();
        end
        
        function GUI_tableResultDiffsSelection_Callback(this,hObject,eventdata)
            %select result parameter from selection in tableResultDiffs
            idx = eventdata.Indices;            
            if(~this.curResultChanIsAvailable || isempty(idx))
                return
            end
                        
            switch idx(2)
                case {1,2} %Amps
                    type = 'Amplitude';
                case {3,4} %Taus
                    type = 'Tau';
                case {5,6} %tcis
                    type = 'tc';
                case {7,8} %Qs
                    type = 'Q';
            end
            paraID = sprintf('%s %d',type,idx(1));
            paraStr = simAnalysis.getParameterStr(this.myResSubject.basicParams.nExp,this.myResSubject.basicParams.stretchedExpMask);
            [tf pos] = ismember(paraID,paraStr);
            if(tf)
                set(this.visHandles.popupParaSelection,'Value',pos);
            else
                set(this.visHandles.popupParaSelection,'Value',1);
            end
            this.makeSelResultTable();
        end
        
        function GUI_tableResultStatsSelection_Callback(this,hObject,eventdata)
            %select result parameter from selection in tableResultStats
            idx = eventdata.Indices;
            if(~this.curResultChanIsAvailable || isempty(idx))
                return
            end                        
            
            switch idx(1)
                case 1
                    paraID = 'chi2';
                case 2
                    paraID = 'chi2 Tail';
                case 3
                    paraID = 'Offset';
                case 4
                    paraID = 'FunctionEvaluations';
                case 5
                    paraID = 'Time';
                otherwise
                    return
            end
            paraStr = simAnalysis.getParameterStr(this.myResSubject.basicParams.nExp,this.myResSubject.basicParams.stretchedExpMask);
            [tf pos] = ismember(paraID,paraStr);
            if(tf)
                set(this.visHandles.popupParaSelection,'Value',pos);
            else
                set(this.visHandles.popupParaSelection,'Value',1);
            end
            this.makeSelResultTable();
        end
        
        function GUI_tableSubsets_EditCallback(this,hObject,eventdata)
            %callback of table subsets
            idx = eventdata.Indices(1);
            this.arraySubsetNames{idx,2} = ~this.arraySubsetNames{idx,2};
            this.setupGUI();
            this.updateGUI();
            this.clearArrayData();
            this.clearMainPlot();
            this.makeMainPlot();
        end

        function GUI_tableSubsets_SelectionCallback(this,hObject,eventdata)
            %callback of table subsets
            this.selectedSubsets = eventdata.Indices(:,1);            
        end
        
    end% methods
        
    methods(Static)
        function str = getParameterStr(nExp,seMask)
            %get string of result parameters
            nSE = length(find(seMask));
            str = cell(5*nExp+nSE+5,1);
            %make string for general parameters
            for i = 1:nExp
                str(i) = {sprintf('Amplitude %d',i)};
                str(i+nExp) = {sprintf('AmplitudePercent %d',i)};
                str(i+2*nExp) = {sprintf('Tau %d',i)};
                str(i+3*nExp) = {sprintf('tc %d',i)};
                str(i+4*nExp) = {sprintf('Q %d',i)};
            end
            %make string for stretched exponentials
            for i = 1:nSE
                str(i+5*nExp) = {sprintf('Beta %d',i)};
            end
            %make string for other parameters
            str(end-4:end) = {'chi2';'chi2Tail';'Offset';'FunctionEvaluations';'Time'};
        end
        
        function paraName = rID2paraName(rID,nExp)
            %convert running ID to parameter name
            switch rID
                case 1 %photons
                    paraName = 'Photons';
                case 2 %offset
                    paraName = 'Offset';                
                otherwise %xVec parameter
                    if(rID-2 <= nExp)
                        paraName = sprintf('Amplitude %d',rID-2);
                    elseif(rID-2 <= 2*nExp)
                        paraName = sprintf('Tau %d',rID-2-nExp);
                    else
                        paraName = sprintf('tc %d',rID-2-2*nExp);
                    end
            end
        end
        
        function diffVec = computeDiff(A,B,inPercent)
            %compute difference between A and B
            diffVec = zeros(max(length(A),length(B)),1);
            diffVec(1:length(A)) = -A;
            diffVec(1:length(B)) = diffVec(1:length(B))+B;
            if(inPercent)
                %calculate relative differences in percent
                diffVec(1:length(A)) = (diffVec(1:length(A))./A).*100;
            end
        end
        
        function [errAmps errTaus errTotal] = computeErrorSums(simAmps,resAmps,simTaus,resTaus)
            %compute error sums for amps, taus and both combined
            ampsDiff = simAnalysis.computeDiff(simAmps,resAmps,true);
            tausDiff = simAnalysis.computeDiff(simTaus,resTaus,true);
            errAmps = sum(abs(ampsDiff));
            errTaus = sum(abs(tausDiff));
            errTotal = errAmps+errTaus;
        end
    end%methods(Static)
end


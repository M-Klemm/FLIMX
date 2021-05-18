classdef StatsMVGroupMgr < handle
    %=============================================================================================================
    %
    % @file     StatsMVGroupMgr.m
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
    % @brief    A class to handle multivariate groups / scatter plots
    %
    properties(SetAccess = protected,GetAccess = protected)
        visObj = [];                %handle to FLIMXVisGUI object
        visHandles = [];            %handle to MVGroupMgr GUI
        curStudyName = '';          %name of currently selected study
        curMVGroupName = '';        %name of currently selected MVGroup
        cwX = [];                   %classwidth of selected target on x axis
        cwY = [];                   %classwidth of selected target on y axis
        oldMVs = [];
        curAxis = [];               %indicates axis for target selection (x or y)
        conditionSelectionTableIdx = []; %current selection in condition table
        studyConditionTableIdx = [];     %current selection in study condition table
        lLB = [];
        xLB = [];
        yLB = [];
        xButton = [];
        yButton = [];
        dButton = [];
    end
    
    methods
        %% computations and other methods
        function this = StatsMVGroupMgr(visObj)
            % Constructor for statsClustering.
            this.visObj = visObj;           %handle to FLIMXVisGUI class
        end
        
        function createVisWnd(this)
            %initialize and create GUI
            this.visHandles = StatsMVGroupMgrFigure();
            %buttons
            set(this.visHandles.buttonAddCluster,'Callback',@this.GUI_addMVGroupCallback);
            set(this.visHandles.buttonDeleteCluster,'Callback',@this.GUI_deleteMVGroupCallback);
            set(this.visHandles.buttonRenameCluster,'Callback',@this.GUI_renameMVGroupCallback);
            set(this.visHandles.buttonClose,'Callback',@this.closeCallback);
            set(this.visHandles.buttonSelectX,'Callback',@this.addMVCallback);
            set(this.visHandles.buttonSelectY,'Callback',@this.addMVCallback);
            set(this.visHandles.buttonDeselect,'Callback',@this.removeMVCallback);
            set(this.visHandles.buttonSelectView,'Callback',@this.addConditionCallback);
            set(this.visHandles.buttonDeselectView,'Callback',@this.removeConditionCallback);
            %popups
            set(this.visHandles.popupStudies,'Callback',@this.GUI_popupStudiesCallback,'String', this.visObj.fdt.getAllStudyNames(),'Value',1);
            set(this.visHandles.popupMVGroups,'Callback',@this.GUI_popupMVGroupsCallback);
            %listbox            
            set(this.visHandles.listboxSelectedX,'Callback',@this.selectAxisCallback);
            set(this.visHandles.listboxSelectedY,'Callback',@this.selectAxisCallback);
            %table
            set(this.visHandles.tableSelectedViews,'CellSelectionCallback',@this.tableSelectedConditionsCallback);
            set(this.visHandles.tableStudyViews,'CellSelectionCallback',@this.tableStudyConditionsCallback);
            %ROI handling
            set(this.visHandles.popupROIType,'Callback',@this.GUI_ROICallback);
            set(this.visHandles.popupROISubType,'Callback',@this.GUI_ROICallback);
            set(this.visHandles.popupROIVicinity,'Callback',@this.GUI_ROICallback);
            %initialize other values
            this.curAxis = 'x';
            this.setUIHandles();
            %initialize listbox with study from left side of FIMXVisGUI
            this.setCurStudy(this.visObj.getStudy('l'));
        end
        
        function checkVisWnd(this)
            %
            if(isempty(this.visHandles) || ~ishandle(this.visHandles.StatsMVGroupMgrFigure) || ~strcmp(get(this.visHandles.StatsMVGroupMgrFigure,'Tag'),'StatsMVGroupMgrFigure'))
                %no cluster manager window - open one
                this.createVisWnd();
            end
            this.updateGUI();
            figure(this.visHandles.StatsMVGroupMgrFigure);
        end
        
        function updateCtrls(this)
            %updates controls to current values
            %pick first subject and first channel if current subject is empty (e.g. not loaded from disk)
            curSubName = this.visObj.fdt.getAllSubjectNames(this.curStudyName,FDTree.defaultConditionName());
            if(isempty(curSubName) && iscell(curSubName))
                curSubName = '';
            else
                curSubName = curSubName{1};
            end
            [~, curChNr] = this.visObj.fdt.getChStr(this.curStudyName,curSubName);
            if(~isempty(curChNr))
                curChNr = curChNr(1);
            end
            curChNr = this.visObj.getChannel('l');
            allObjs = this.visObj.fdt.getChObjStr(this.curStudyName,curSubName,curChNr);
            if(~isempty(this.curMVGroupName))
                cMVs = this.visObj.fdt.getStudyMVGroupTargets(this.curStudyName,this.curMVGroupName);
            else
                cMVs.x = [];
                cMVs.y = [];
                cMVs.ROI.ROIType = 0;
                cMVs.ROI.ROISubType = 1;
                cMVs.ROI.ROIVicinity = 1;
            end
            %remove all current targets from allObjs
            if(isempty(allObjs))
                allObjs = cellstr('-none-');
                cMVs.x = cellstr('-none-');
                cMVs.y = cellstr('none-');
            else
                if(isempty(cMVs.x))
                    cMVs.x = cellstr('-none-');
                end
                if(isempty(cMVs.y))
                    cMVs.y = cellstr('-none-');
                end
                idx = false(length(allObjs),1);
                if(~strcmp(cMVs.x{1},'-none-'))
                    %remove reference target (x-axis)
                    idx = idx | strcmpi(cMVs.x{1}, allObjs);
                    %get corresponding class width
                    [dType, dTypeNr] = this.visObj.FLIMItem2TypeAndID(cMVs.x{1});
                    this.cwX = getHistParams(this.visObj.getStatsParams(),curChNr,dType{1},dTypeNr);
                    set(this.visHandles.lblHeadingX,'String',sprintf('x-axis\n(Used classwidth: %d)',this.cwX));
                    set(this.xButton,'Enable','Off');
                    set(this.yButton,'Enable','On');
                    set(this.dButton,'Enable','On');
                else
                    set(this.xButton,'Enable','On');
                    set(this.yButton,'Enable','Off');
                    set(this.dButton,'Enable','Off');
                    set(this.visHandles.lblHeadingX,'String',sprintf('x-axis\n(Used classwidth: -)'));
                end                
                if(~strcmp(cMVs.y{1},'-none-'))
                    [dType, dTypeNr] = this.visObj.FLIMItem2TypeAndID(cMVs.y{1});
                    this.cwY = getHistParams(this.visObj.getStatsParams(),curChNr,dType{1},dTypeNr);
                    %add whitespace to distinguish between all FLIM items
                    dType{1} = sprintf('%s ',dType{1});
                    %show only targets with same dType
                    idx = idx | ~strncmpi(dType,allObjs,length(dType{1}));
                    for i=1:length(cMVs.y)
                        idx(strcmpi(cMVs.y{i},allObjs)) = 1;
                    end
                    set(this.visHandles.lblHeadingY,'String',sprintf('y-axis\n(Used classwidth: %d)',this.cwY));
                else
                    set(this.visHandles.lblHeadingY,'String',sprintf('y-axis\n(Used classwidth: -)'));
                end
                allObjs = allObjs(~idx);
                %set ROI controls
                if(cMVs.ROI.ROIType == 0)
                    this.visHandles.popupROIType.Value = cMVs.ROI.ROIType+1;
                else
                    pStr = this.visHandles.popupROIType.String;
                    if(ischar(pStr))
                        pStr = {pStr};
                    end
                    newStr = ROICtrl.ROIType2ROIItem(cMVs.ROI.ROIType);
                    idx = find(strcmp(pStr,newStr),1,'first');
                    if(~isempty(idx))
                        this.visHandles.popupROIType.Value = idx;
                    else
                        %ROI Type not in popup menu
                        %todo: add ROI Type to popup? It is not yet in the study!
                        this.visHandles.popupROIType.Value = 1;
                    end
                end
                if(cMVs.ROI.ROIType > 1000 && cMVs.ROI.ROIType < 2000)
                    visFlag = 'on';
                else
                    visFlag = 'off';
                end
                set(this.visHandles.popupROISubType,'Value',cMVs.ROI.ROISubType,'Visible',visFlag);
                set(this.visHandles.popupROIVicinity,'Value',cMVs.ROI.ROIVicinity,'Visible',visFlag);
            end
            if(isempty(allObjs))
                set(this.lLB,'String','','Value',1);
            else
                set(this.lLB,'String',allObjs,'Value',min(get(this.lLB,'Value'),length(allObjs)));
            end
            set(this.xLB,'String',cMVs.x,'Value',min(get(this.xLB,'Value'),length(cMVs.x)));
            set(this.yLB,'String',cMVs.y,'Value',min(get(this.yLB,'Value'),length(cMVs.y)));
            %             if(this.cwX ~= this.cwY)
            %                 %show warning message
            %                 warndlg('The classwidths of the selected targets do not match. Results may be corrupted.','Classwidths do not match');
            %             end
        end
        
        function updateGUI(this)
            %update GUI function
            %update MVGroup list
            allMVGroupStr = this.visObj.fdt.getMVGroupNames(this.curStudyName,0);
            idx = strncmp('MVGroup_',allMVGroupStr,8);
            if(~isempty(idx))
                allMVGroupStr = allMVGroupStr(idx);
            end
            if(isempty(allMVGroupStr))
                set(this.visHandles.popupMVGroups,'String',cellstr('-none-'));
                set(this.visHandles.popupMVGroups,'Value',1);
                this.curMVGroupName = '';
            else
                set(this.visHandles.popupMVGroups,'String',allMVGroupStr);
                set(this.visHandles.popupMVGroups,'Value',min(get(this.visHandles.popupMVGroups,'Value'),length(allMVGroupStr)));
                MVGroupStr = get(this.visHandles.popupMVGroups,'String');
                this.curMVGroupName = MVGroupStr{get(this.visHandles.popupMVGroups,'Value')};
            end
            %enable / disable UI controls
            if(isempty(this.curMVGroupName))
                set(this.visHandles.buttonDeselect,'Enable','Off');
                set(this.lLB,'Enable','Off');
                set(this.xLB,'Enable','Off');
                set(this.yLB,'Enable','Off');
            else
                set(this.visHandles.buttonDeselect,'Enable','On');
                set(this.lLB,'Enable','On');
                set(this.xLB,'Enable','On');
                set(this.yLB,'Enable','On');
            end
            %update target selection controls
            this.updateCtrls();
            this.updateGlobalCtrls();
        end
        
        function updateGlobalCtrls(this)
            %update UI controls for global MVGroup selection
            %enable / disable UI controls
            if(isempty(this.curMVGroupName))
                set(this.visHandles.tableStudyViews,'Data',[],'Enable','Off');
                set(this.visHandles.tableSelectedViews,'Data',[],'Enable','Off');
                set(this.visHandles.buttonSelectView,'Enable','Off');
                set(this.visHandles.buttonDeselectView,'Enable','Off');
                set(this.visHandles.textGlobalClusterViews,'String','Selected Conditions:');
                return
            end
            set(this.visHandles.tableStudyViews,'Enable','On');
            selectedConditions = this.visObj.fdt.getGlobalMVGroupTargets(this.curMVGroupName);
            set(this.visHandles.tableSelectedViews,'Data',selectedConditions,'Enable','On');
            studyStr = this.visObj.fdt.getAllStudyNames();
            tableData = cell(0,2);
            if(~isempty(selectedConditions))
                %show name of global MVGroup
                set(this.visHandles.textGlobalClusterViews,'String',sprintf('Selected Conditions (%s):',this.curMVGroupName));
                %show conditions of all studies
                for i = 1:length(studyStr)
                    studyConditions = this.visObj.fdt.getStudyConditionsStr(studyStr{i});
                    for j = 1:length(studyConditions)
                        tableData(end+1,1) = studyStr(i);
                        tableData(end,2) = studyConditions(j);
                    end
                end
            else
                %show only conditions of currently selected study (initial case)
                set(this.visHandles.textGlobalClusterViews,'String','Selected Conditions:');
                studyNr = get(this.visHandles.popupStudies,'Value');
                studyConditions = this.visObj.fdt.getStudyConditionsStr(studyStr{studyNr});
                for j = 1:length(studyConditions)
                    tableData(end+1,1) = studyStr(studyNr);
                    tableData(end,2) = studyConditions(j);
                end
            end
            idx = false(size(tableData,1),1);
            if(~isempty(selectedConditions))
                %do not show already selected conditions
                %                 for i = 1:size(tableData,2)
                %                     [tf, loc] = ismember(tableData(i,2),selectedViews(:,1));
                %                     if(any(tf))
                %                         if(ismember(tableData(i,1),selectedViews(loc,2)))
                %                             idx(i) = true;
                %                         end
                %                     end
                %                 end
                tf1 = ismember(tableData(:,1),selectedConditions(:,1));
                tf2 = ismember(tableData(:,2),selectedConditions(:,2));
                idx = tf1 & tf2;
                set(this.visHandles.buttonDeselectView,'Enable','On');
            else
                set(this.visHandles.buttonDeselectView,'Enable','Off');
            end
            %show selectable study conditions
            tableData = tableData(~idx,:);
            set(this.visHandles.tableStudyViews,'Data',tableData,'Enable','On');
            if(~isempty(studyConditions))
                set(this.visHandles.buttonSelectView,'Enable','On');
            else
                set(this.visHandles.buttonSelectView,'Enable','Off');
            end
        end
        
        function ROI = getROIInfo(this)
            %get ROI type, subtype and invert flag from GUI
            str = this.visHandles.popupROIType.String;
            nr = this.visHandles.popupROIType.Value;
            if(iscell(str))
                str = str{nr};
            elseif(ischar(str))
                %nothing to do
            else
                %should not happen
            end
            ROI.ROIType = ROICtrl.ROIItem2ROIType(str);
            %ROI.ROIType = get(this.visHandles.popupROIType,'Value')-1;
            ROI.ROISubType = get(this.visHandles.popupROISubType,'Value');
            ROI.ROIVicinity = get(this.visHandles.popupROIVicinity,'Value');            
        end
        
        %% GUI callbacks
        function GUI_popupStudiesCallback(this,hObject,eventdata)
            %select study
            studyStr = get(hObject,'String');
            this.curStudyName = studyStr{get(hObject,'Value')};
            %ROI
            ds1 = this.visObj.fdt.getAllSubjectNames(this.curStudyName,FDTree.defaultConditionName);
            if(~isempty(ds1))
                allROT = this.visObj.fdt.getResultROICoordinates(this.curStudyName,ds1{1},[]);
                if(isempty(allROT))
                    allROT = ROICtrl.getDefaultROIStruct();
                end
                allROIStr = arrayfun(@ROICtrl.ROIType2ROIItem,[0;allROT(:,1,1)],'UniformOutput',false);
            else
                allROIStr = {ROICtrl.ROIType2ROIItem(0)};
            end            
            set(this.visHandles.popupROIType,'String',allROIStr,'Value',min(this.visHandles.popupROIType.Value,length(allROIStr)));
            this.updateGUI();
        end
        
        function GUI_ROICallback(this,hObject,eventdata)
            %change ROI info of current MVGroup
            cMVs = this.visObj.fdt.getStudyMVGroupTargets(this.curStudyName,this.curMVGroupName);
            cMVs.ROI = this.getROIInfo();
            %update MVGroups in all studies
            studies = this.visObj.fdt.getAllStudyNames();
            for i=1:length(studies)
                if(ismember(this.curMVGroupName,this.visObj.fdt.getMVGroupNames(studies{i},0)))
                    this.visObj.fdt.setStudyMVGroupTargets(studies{i},this.curMVGroupName,cMVs);
                    this.visObj.fdt.clearAllRIs(studies{i},this.curMVGroupName);
                end
            end
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
            this.updateGUI();
        end
        
        function GUI_popupMVGroupsCallback(this,hObject,eventdata)
            %select MVGroup
            this.updateGUI();
        end
        
        function selectAxisCallback(this,hObject,eventdata)
            %set current axis for target selection
            if(strcmp('listboxSelectedX',get(hObject,'Tag')))
                this.curAxis = 'x';
            else
                this.curAxis = 'y';
            end
        end
        
        function addMVCallback(this,hObject,eventdata)
            %callback function of the add (select) button
            selStr = get(this.lLB,'String');
            if(isempty(selStr))
                this.updateCtrls();
                return
            end
            selStr = selStr(get(this.lLB,'Value'));
            cMVs = this.visObj.fdt.getStudyMVGroupTargets(this.curStudyName,this.curMVGroupName);
            if(strcmp('buttonSelectX',get(hObject,'Tag')))
                %add MVGroup target to x axis
                cMVs.x(end+1) = selStr;
            else
                %add MVGroup target to y axis
                cMVs.y(end+1) = selStr;
            end
            %update MVGroups in all studies
            studies = this.visObj.fdt.getAllStudyNames();
            for i=1:length(studies)
                if(ismember(this.curMVGroupName,this.visObj.fdt.getMVGroupNames(studies{i},0)))
                    this.visObj.fdt.setStudyMVGroupTargets(studies{i},this.curMVGroupName,cMVs);
                    this.visObj.fdt.clearAllRIs(studies{i},this.curMVGroupName);
                end
            end
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
            this.updateCtrls();
        end
        
        function removeMVCallback(this,hObject,eventdata)
            %callback function from the remove (deselect) button
            selStr = get(this.(sprintf('%sLB',this.curAxis)),'String');
            selStr = selStr(get(this.(sprintf('%sLB',this.curAxis)),'Value'));
            cMVs = this.visObj.fdt.getStudyMVGroupTargets(this.curStudyName,this.curMVGroupName);
            if(strcmp('x',this.curAxis))
                %remove all targets
                idx = strcmpi(selStr,cMVs.x);
                cMVs.x = cMVs.x(~idx);
                cMVs.y = cell(0,0);
            else
                idx = strcmpi(selStr,cMVs.y);
                cMVs.y = cMVs.y(~idx);
            end
            %update MVGroups in all studies
            studies = this.visObj.fdt.getAllStudyNames();
            for i=1:length(studies)
                if(ismember(this.curMVGroupName,this.visObj.fdt.getMVGroupNames(studies{i},0)))
                    this.visObj.fdt.setStudyMVGroupTargets(studies{i},this.curMVGroupName,cMVs);
                    this.visObj.fdt.clearAllRIs(studies{i},this.curMVGroupName);
                end
            end
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
            this.updateCtrls();
        end
        
        function GUI_addMVGroupCallback(this,hObject,eventdata)
            %add a new MVGroup
            options.Resize='on';
            options.WindowStyle='modal';
            options.Interpreter='none';
            while(true)
                gn=inputdlg('Enter new multivariate group name:','MVGroup Name',1,{'newGroup'},options);
                if(isempty(gn))
                    return
                end
                %remove any '\' a might have entered
                gn = char(gn{1,1});
                idx = strfind(gn,filesep);
                if(~isempty(idx))
                    gn(idx) = '';
                end
                %remove white spaces
                gn(isstrprop(gn,'wspace')) = [];
                %check if name is available
                if(any(strcmp(['MVGroup_' gn],this.visObj.fdt.getMVGroupNames(this.curStudyName,0))))
                    choice = questdlg(sprintf('This multivariate group %s exists already. Please choose another name.',gn),...
                        'Error creating MVGroup','Choose new Name','Cancel','Choose new Name');
                    % Handle response
                    switch choice
                        case 'Cancel'
                            return
                    end
                    continue;
                else
                    %we have a unique name
                    break;
                end
            end
            gn = ['MVGroup_' gn];
            %initialize targets
            cMVs.x = cell(0,0);
            cMVs.y = cell(0,0);
            cMVs.ROI = this.getROIInfo();
            this.visObj.fdt.setStudyMVGroupTargets(this.curStudyName,gn,cMVs);
            newMVg = this.visObj.fdt.getMVGroupNames(this.curStudyName,0);
            set(this.visHandles.popupMVGroups,'String',newMVg);
            idx = find(strcmp(gn,newMVg));
            if(isempty(idx))
                idx = 1;
            end
            set(this.visHandles.popupMVGroups,'Value',idx);
            this.updateGUI();
        end
        
        function GUI_deleteMVGroupCallback(this,hObject,eventdata)
            %delete selected MVGroup
            if(isempty(this.curMVGroupName))
                return
            end
            this.visObj.fdt.removeMVGroup(this.curStudyName,this.curMVGroupName);
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
            this.updateGUI();
        end
        
        function GUI_renameMVGroupCallback(this,hObject,eventdata)
            %rename selected MVGroup
            gn = this.curMVGroupName;
            if(length(gn) < 9)
                return
            end
            gn = gn(9:end);
            options.Resize='on';
            options.WindowStyle='modal';
            options.Interpreter='none';
            while(true)
                gn=inputdlg('Enter new multivariate group name:','MVGroup Name',1,{gn},options);
                if(isempty(gn))
                    return
                end
                %remove any '\' a might have entered
                gn = char(gn{1,1});
                idx = strfind(gn,filesep);
                if(~isempty(idx))
                    gn(idx) = '';
                end
                %remove white spaces
                gn(isstrprop(gn,'wspace')) = [];
                %check if name is available
                if(any(strcmp(['MVGroup_' gn],this.visObj.fdt.getMVGroupNames(this.curStudyName,0))))
                    choice = questdlg(sprintf('This multivariate group %s exists already. Please choose another name.',gn),...
                        'Error creating MVGroup','Choose new Name','Cancel','Choose new Name');
                    % Handle response
                    switch choice
                        case 'Cancel'
                            return
                    end
                    continue;
                else
                    %we have a unique name
                    break;
                end
            end
            gn = ['MVGroup_' gn];
            this.visObj.fdt.setMVGroupName(this.curStudyName,this.curMVGroupName,gn);
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
            this.updateGUI();
        end
        
        function addConditionCallback(this,hObject,eventdata)
            %add study condition to global MVGroup selection
            if(isempty(this.studyConditionTableIdx))
                return
            end
            studyConditions = get(this.visHandles.tableStudyViews,'Data'); %study views and corresponding studies
            %check if MVGroup is available yet in selected study
            MVGroupStr = this.visObj.fdt.getMVGroupNames(studyConditions{this.studyConditionTableIdx,1},0);
            if(isempty(MVGroupStr) || ~ismember(this.curMVGroupName,MVGroupStr))
                choice = questdlg(sprintf('%s is not available in %s. Add the selected MVGroup to this study?',...
                    this.curMVGroupName,studyConditions{this.studyConditionTableIdx,1}),'MVGroup not available','Yes','No','Yes');
                switch choice
                    case 'No'
                        return
                end                
                %add current MVGroup to study
                cMVs = this.visObj.fdt.getStudyMVGroupTargets(this.curStudyName,this.curMVGroupName);
                this.visObj.fdt.setStudyMVGroupTargets(studyConditions{this.studyConditionTableIdx,1},this.curMVGroupName,cMVs);
            end
            selectedConditions = this.visObj.fdt.getGlobalMVGroupTargets(this.curMVGroupName);
            if(isempty(selectedConditions))
                selectedConditions = cell(0,2);
            end
            selectedConditions(end+1,:) = cell(1,2);
            selectedConditions(end,:) = studyConditions(this.studyConditionTableIdx,:);
            this.visObj.fdt.setGlobalMVGroupTargets(this.curMVGroupName,selectedConditions);
            this.updateGlobalCtrls();
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
        end
        
        function removeConditionCallback(this,hObject,eventdata)
            %remove study condition from global MVGroup selection
            if(~isempty(this.conditionSelectionTableIdx))
                selectedConditions = this.visObj.fdt.getGlobalMVGroupTargets(this.curMVGroupName);
                selectedConditions(this.conditionSelectionTableIdx,:) = [];
                this.visObj.fdt.setGlobalMVGroupTargets(this.curMVGroupName,selectedConditions);
            end
            this.updateGlobalCtrls();
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
        end
        
        function tableSelectedConditionsCallback(this,hObject,eventdata)
            %set current indices of study condition in selection table
            this.conditionSelectionTableIdx = eventdata.Indices(:,1);
        end
        
        function tableStudyConditionsCallback(this,hObject,eventdata)
            %set current indices of selectable study conditions
            this.studyConditionTableIdx = eventdata.Indices(:,1);
        end
        
        function closeCallback(this,hObject,eventdata)
            % close MVGroupMgr GUI
            if(~isempty(this.visHandles) && ishandle(this.visHandles.StatsMVGroupMgrFigure))
                delete(this.visHandles.StatsMVGroupMgrFigure);
            end
        end
        
        function setCurStudy(this,val)
            %set current study
            if(this.isOpenVisWnd())
                studies = get(this.visHandles.popupStudies,'String');
                idx = find(strcmp(val,studies),1);
                if(~isempty(idx))
                    set(this.visHandles.popupStudies,'Value',idx);
                end
                this.GUI_popupStudiesCallback(this.visHandles.popupStudies,[]);
            end
        end
    end %methods
    
    methods(Access = protected)
        %internal methods
        function setUIHandles(this)
            %builds the uicontrol handles for the target selection
            this.lLB = this.visHandles.listboxRemaining;
            this.xLB = this.visHandles.listboxSelectedX;
            this.yLB = this.visHandles.listboxSelectedY;
            this.xButton = this.visHandles.buttonSelectX;
            this.yButton = this.visHandles.buttonSelectY;
            this.dButton = this.visHandles.buttonDeselect;
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.StatsMVGroupMgrFigure) || ~strcmp(get(this.visHandles.StatsMVGroupMgrFigure,'Tag'),'StatsMVGroupMgrFigure'));
        end
    end %methods protected
end %classdef
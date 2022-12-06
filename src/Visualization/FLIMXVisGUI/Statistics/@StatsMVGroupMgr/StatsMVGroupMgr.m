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
        MMSSelectedTableIdx = []; %current selection in condition table
        MMSAvailableTableIdx = [];     %current selection in study condition table
        MISAvailableTableIdx = [];  %current selection in MIS available table
        MISSelectedTableIdx = [];  %current selection in MIS selected table
        lLB = [];
        xLB = [];
        yLB = [];
        xButton = [];
        yButton = [];
        dButton = [];
    end
    properties (Dependent = true)
        allROITypes
        curMVGroup
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
            %radio buttons
            this.visHandles.radioFLIMItem.Callback = @this.GUI_switchMVGroupGeneration;
            this.visHandles.radioMIS.Callback = @this.GUI_switchMVGroupGeneration;
            this.visHandles.radioMMS.Callback = @this.GUI_switchMVGroupGeneration;
            %buttons
            set(this.visHandles.buttonAddMVGroup,'Callback',@this.GUI_addMVGroupCallback);
            set(this.visHandles.buttonDeleteMVGroup,'Callback',@this.GUI_deleteMVGroupCallback);
            set(this.visHandles.buttonRenameMVGroup,'Callback',@this.GUI_renameMVGroupCallback);
            %set(this.visHandles.buttonClose,'Callback',@this.closeCallback);
            set(this.visHandles.buttonSelectX,'Callback',@this.addMVCallback);
            set(this.visHandles.buttonSelectY,'Callback',@this.addMVCallback);
            set(this.visHandles.buttonDeselectFLIMItem,'Callback',@this.removeMVCallback);
            set(this.visHandles.buttonSelectMIS,'Callback',@this.addMISCallback);
            set(this.visHandles.buttonDeselectMIS,'Callback',@this.removeMISCallback);
            set(this.visHandles.buttonSelectMMS,'Callback',@this.addMMSCallback);
            set(this.visHandles.buttonDeselectMMS,'Callback',@this.removeMMSCallback);
            %popups
            set(this.visHandles.popupStudySel,'Callback',@this.GUI_popupStudySelCallback,'String', this.visObj.fdt.getAllStudyNames(),'Value',1);
            set(this.visHandles.popupMVGroups,'Callback',@this.GUI_popupMVGroupsCallback);
            %listbox            
            set(this.visHandles.listboxSelectedX,'Callback',@this.selectAxisCallback);
            set(this.visHandles.listboxSelectedY,'Callback',@this.selectAxisCallback);
            %table
            set(this.visHandles.tableMVGroupsSelectedMIS,'CellSelectionCallback',@this.tableSelectedMISCallback);
            set(this.visHandles.tableMVGroupsAvailableMIS,'CellSelectionCallback',@this.tableAvailableMISCallback);
            set(this.visHandles.tableMVGroupsSelectedMMS,'CellSelectionCallback',@this.tableSelectedMMSCallback);
            set(this.visHandles.tableMVGroupsAvailableMMS,'CellSelectionCallback',@this.tableAvailableMMSCallback);
            %ROI handling
            set(this.visHandles.popupROIType,'Callback',@this.GUI_ROICallback);
            set(this.visHandles.popupROISubType,'Callback',@this.GUI_ROICallback);
            set(this.visHandles.popupROIVicinity,'Callback',@this.GUI_ROICallback);
            %initialize other values
            this.curAxis = 'x';
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
        
        function updateFICtrls(this)
            %updates controls to current values
            %pick first subject and first channel if current subject is empty (e.g. not loaded from disk)
            curSubName = this.visObj.fdt.getAllSubjectNames(this.curStudyName,FDTree.defaultConditionName());
            if(isempty(curSubName) && iscell(curSubName))
                curSubName = '';
            else
                curSubName = curSubName{1};
            end
%             [~, curChNr] = this.visObj.fdt.getChStr(this.curStudyName,curSubName);
%             if(~isempty(curChNr))
%                 curChNr = curChNr(1);
%             end
            curChNr = this.visObj.getChannel('l');
            cMV = this.curMVGroup;
            allMVG = this.visHandles.popupMVGroups.String;
            if(~isempty(cMV.x) && isempty(cMV.y) && all(ismember(cMV.x,allMVG)))
                %current MV group is a MIS MV group
                this.enDisAblePanels('off','','');
%                 cMV.x = cellstr('-none-');
%                 cMV.y = cellstr('-none-');
                allObjs = [];
            else                
                allObjs = this.visObj.fdt.getChObjStr(this.curStudyName,curSubName,curChNr);
            end
            %remove all current targets from allObjs
            if(isempty(allObjs))
                allObjs = cellstr('-none-');
                cMV.x = cellstr('-none-');
                cMV.y = cellstr('none-');
                idx = false(1,1);
            else
                if(isempty(cMV.x))
                    cMV.x = cellstr('-none-');
                end
                if(isempty(cMV.y))
                    cMV.y = cellstr('-none-');
                end
                idx = false(length(allObjs),1);
                if(~strcmp(cMV.x{1},'-none-'))
                    %remove reference target (x-axis)
                    idx = idx | strcmpi(cMV.x{1}, allObjs);
                    %get corresponding class width
                    [dType, dTypeNr] = this.visObj.FLIMItem2TypeAndID(cMV.x{1});
                    this.cwX = getHistParams(this.visObj.getStatsParams(),curChNr,dType{1},dTypeNr);
                    set(this.visHandles.lblHeadingX,'String',sprintf('x-axis\n(Used classwidth: %d)',this.cwX));
                    set(this.visHandles.buttonSelectX,'Enable','Off');
                    set(this.visHandles.buttonSelectY,'Enable','On');
                    set(this.visHandles.buttonDeselectFLIMItem,'Enable','On');
                else
                    set(this.visHandles.buttonSelectX,'Enable','On');
                    set(this.visHandles.buttonSelectY,'Enable','Off');
                    set(this.visHandles.buttonDeselectFLIMItem,'Enable','Off');
                    set(this.visHandles.lblHeadingX,'String',sprintf('x-axis\n(Used classwidth: -)'));
                end
            end
            if(~strcmp(cMV.y{1},'-none-'))
                [dType, dTypeNr] = this.visObj.FLIMItem2TypeAndID(cMV.y{1});
                this.cwY = getHistParams(this.visObj.getStatsParams(),curChNr,dType{1},dTypeNr);
                %add whitespace to distinguish between all FLIM items
                dType{1} = sprintf('%s ',dType{1});
                %show only targets with same dType
                idx = idx | ~strncmpi(dType,allObjs,length(dType{1}));
                for i=1:length(cMV.y)
                    idx(strcmpi(cMV.y{i},allObjs)) = 1;
                end
                set(this.visHandles.lblHeadingY,'String',sprintf('y-axis\n(Used classwidth: %d)',this.cwY));
            else
                set(this.visHandles.lblHeadingY,'String',sprintf('y-axis\n(Used classwidth: -)'));
            end
            allObjs = allObjs(~idx);
            if(isempty(allObjs))
                set(this.visHandles.listboxRemaining,'String','','Value',1);
            else
                set(this.visHandles.listboxRemaining,'String',allObjs,'Value',max(1,min(get(this.visHandles.listboxRemaining,'Value'),length(allObjs))));
            end
            set(this.visHandles.listboxSelectedX,'String',cMV.x,'Value',min(get(this.visHandles.listboxSelectedX,'Value'),length(cMV.x)));
            set(this.visHandles.listboxSelectedY,'String',cMV.y,'Value',min(get(this.visHandles.listboxSelectedY,'Value'),length(cMV.y)));
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
            cMVs = this.curMVGroup;
            %set ROI controls
            if(cMVs.ROI.ROIType == 0)
                this.visHandles.popupROIType.Value = cMVs.ROI.ROIType+1;
                this.visHandles.popupROIVicinity.Visible = 'off'; 
            else
                set(this.visHandles.popupROIVicinity,'Value',cMVs.ROI.ROIVicinity,'Visible','on');
                pStr = this.visHandles.popupROIType.String;
                if(ischar(pStr))
                    pStr = {pStr};
                end
                if(cMVs.ROI.ROIType < 0)
                    %ROI group
                    grps = this.visObj.fdt.getResultROIGroup(this.curStudyName,[]);
                    if(size(grps,1) >= abs(cMVs.ROI.ROIType))
                        newStr = ['Group: ' grps{abs(cMVs.ROI.ROIType),1}];
                    else
                        newStr = '-none-';
                    end
                else
                    %regular ROI
                    newStr = ROICtrl.ROIType2ROIItem(cMVs.ROI.ROIType);
                end
                idx = find(strcmp(pStr,newStr),1,'first');
                if(~isempty(idx))
                    this.visHandles.popupROIType.Value = idx;
                else
                    %ROI Type not in popup menu
                    %todo: add ROI Type to popup? It is not yet in the study!
                    this.visHandles.popupROIType.Value = 1;
                end
            end
            if(cMVs.ROI.ROIType > FDTStudy.roiBaseETDRS && cMVs.ROI.ROIType < FDTStudy.roiBaseRectangle)
                visFlag = 'on';
            else
                visFlag = 'off';
            end
            set(this.visHandles.popupROISubType,'Value',cMVs.ROI.ROISubType,'Visible',visFlag);                        
                
            if(this.visHandles.radioFLIMItem.Value) %FI
                this.visHandles.radioMIS.Value = 0; 
                this.visHandles.radioMMS.Value = 0;
                this.enDisAblePanels('on','off','off');
                this.updateFICtrls();
                %enable / disable UI controls
                if(isempty(this.curMVGroupName))
                    set(this.visHandles.buttonDeselectFLIMItem,'Enable','Off');
                    set(this.visHandles.listboxRemaining,'Enable','Off');
                    set(this.visHandles.listboxSelectedX,'Enable','Off');
                    set(this.visHandles.listboxSelectedY,'Enable','Off');
                else
                    set(this.visHandles.buttonDeselectFLIMItem,'Enable','On');
                    set(this.visHandles.listboxRemaining,'Enable','On');
                    set(this.visHandles.listboxSelectedX,'Enable','On');
                    set(this.visHandles.listboxSelectedY,'Enable','On');
                end
                %clear MIS
                set(this.visHandles.tableMVGroupsAvailableMIS,'Data',[],'Enable','Off');
                set(this.visHandles.tableMVGroupsSelectedMIS,'Data',[],'Enable','Off');
                %clear MMS
                set(this.visHandles.tableMVGroupsAvailableMMS,'Data',[],'Enable','Off');
                set(this.visHandles.tableMVGroupsSelectedMMS,'Data',[],'Enable','Off');
            elseif(this.visHandles.radioMIS.Value) %MIS
                this.visHandles.radioFLIMItem.Value = 0;
                this.visHandles.radioMMS.Value = 0;
                this.enDisAblePanels('off','on','off');
                this.updateMISCtrls();
                %clear FI
                this.visHandles.listboxRemaining.String = '';
                this.visHandles.listboxSelectedX.String = '';
                this.visHandles.listboxSelectedY.String = '';
                %clear MMS
                set(this.visHandles.tableMVGroupsAvailableMMS,'Data',[],'Enable','Off');
                set(this.visHandles.tableMVGroupsSelectedMMS,'Data',[],'Enable','Off');
            else %MMS
                this.visHandles.radioFLIMItem.Value = 0;
                this.visHandles.radioMIS.Value = 0;
                this.enDisAblePanels('off','off','on');
                this.updateMMSCtrls();
                %clear FI
                this.visHandles.listboxRemaining.String = '';
                this.visHandles.listboxSelectedX.String = '';
                this.visHandles.listboxSelectedY.String = '';
                %clear MIS
                set(this.visHandles.tableMVGroupsAvailableMIS,'Data',[],'Enable','Off');
                set(this.visHandles.tableMVGroupsSelectedMIS,'Data',[],'Enable','Off');
            end
        end
        
        function enDisAblePanels(this,FIFlag,MISFlag,MMSFlag)
            %
            validFlags = {'on','off'};
            if(ismember(FIFlag,validFlags))
                this.visHandles.listboxRemaining.Enable = FIFlag;
                this.visHandles.buttonSelectX.Enable = FIFlag;
                this.visHandles.buttonSelectY.Enable = FIFlag;
                this.visHandles.buttonDeselectFLIMItem.Enable = FIFlag;
                this.visHandles.listboxSelectedX.Enable = FIFlag;
                this.visHandles.listboxSelectedY.Enable = FIFlag;
            end            
            if(ismember(MISFlag,validFlags))
                this.visHandles.textMISleft.Enable = MISFlag;
                this.visHandles.tableMVGroupsAvailableMIS.Enable = MISFlag;
                this.visHandles.textMISright.Enable = MISFlag;
                this.visHandles.tableMVGroupsSelectedMIS.Enable = MISFlag;
                this.visHandles.buttonSelectMIS.Enable = MISFlag;
                this.visHandles.buttonDeselectMIS.Enable = MISFlag;
            end
            if(ismember(MISFlag,validFlags))
                this.visHandles.textMMSWarning.Enable = MMSFlag;
                this.visHandles.textMMSleft.Enable = MMSFlag;
                this.visHandles.tableMVGroupsAvailableMMS.Enable = MMSFlag;
                this.visHandles.tableMVGroupsSelectedMMS.Enable = MMSFlag;
                this.visHandles.textGlobalMVGroups.Enable = MMSFlag;
                this.visHandles.buttonSelectMMS.Enable = MMSFlag;
                this.visHandles.buttonDeselectMMS.Enable = MMSFlag;
            end
        end
        
        function updateMISCtrls(this)
            %update UI controls for merged MV groups inside a study
            allMVG = this.visHandles.popupMVGroups.String;
            idx = strcmp(allMVG,this.curMVGroupName);
            allMVG = allMVG(~idx);
            cMV = this.curMVGroup;
            if(isempty(allMVG) || ~isempty(cMV.y) && ~isempty(cMV.x))
                %this is an FLIM item MV group -> nothing to do here
                set(this.visHandles.tableMVGroupsAvailableMIS,'Data',[],'Enable','Off');
                set(this.visHandles.tableMVGroupsSelectedMIS,'Data',[],'Enable','Off');
            else
                %check if current MV group consists of other MV groups                
                if(~isempty(cMV.x) && isempty(cMV.y) && all(ismember(cMV.x,allMVG)))
                    %this is a valid MIS MV group
                    set(this.visHandles.tableMVGroupsSelectedMIS,'Data',cMV.x,'Enable','On');
                    idx = ~ismember(allMVG,cMV.x);
                elseif(isempty(cMV.y) && isempty(cMV.x))
                    %current MV group is empty and may become and MIS MV group
                    set(this.visHandles.tableMVGroupsSelectedMIS,'Data',[],'Enable','On');
                    idx = true(length(allMVG),1);
                end                
                %remove empty MV groups and MV groups which are merged from other MV groups
                for i = 1:length(allMVG)                    
                    cMVs = this.visObj.fdt.getStudyMVGroupTargets(this.curStudyName,allMVG{i});
                    if(isempty(cMVs) || isempty(cMVs.x) && isempty(cMVs.y) || any(ismember(cMVs.x,allMVG)) && any(ismember(cMVs.y,allMVG)))
                        idx(i) = false;
                    end
                end
                allMVG = allMVG(idx);
                set(this.visHandles.tableMVGroupsAvailableMIS,'Data',allMVG,'Enable','On');                
            end            
        end
        
        function updateMMSCtrls(this)
            %update UI controls for global MVGroup selection
            %enable / disable UI controls
            if(isempty(this.curMVGroupName))
                set(this.visHandles.tableMVGroupsAvailableMMS,'Data',[],'Enable','Off');
                set(this.visHandles.tableMVGroupsSelectedMMS,'Data',[],'Enable','Off');
                set(this.visHandles.buttonSelectMMS,'Enable','Off');
                set(this.visHandles.buttonDeselectMMS,'Enable','Off');
                set(this.visHandles.textGlobalMVGroups,'String','Selected Conditions:');
                return
            end
            set(this.visHandles.tableMVGroupsAvailableMMS,'Enable','On');
            selectedConditions = this.visObj.fdt.getGlobalMVGroupTargets(this.curMVGroupName);
            set(this.visHandles.tableMVGroupsSelectedMMS,'Data',selectedConditions,'Enable','On');
            studyStr = this.visObj.fdt.getAllStudyNames();
            tableData = cell(0,2);
            if(~isempty(selectedConditions))
                %show name of global MVGroup
                set(this.visHandles.textGlobalMVGroups,'String',sprintf('Selected Conditions (%s):',this.curMVGroupName));
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
                set(this.visHandles.textGlobalMVGroups,'String','Selected Conditions:');
                studyNr = get(this.visHandles.popupStudySel,'Value');
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
                set(this.visHandles.buttonDeselectMMS,'Enable','On');
            else
                set(this.visHandles.buttonDeselectMMS,'Enable','Off');
            end
            %show selectable study conditions
            tableData = tableData(~idx,:);
            set(this.visHandles.tableMVGroupsAvailableMMS,'Data',tableData,'Enable','On');
            if(~isempty(studyConditions))
                set(this.visHandles.buttonSelectMMS,'Enable','On');
            else
                set(this.visHandles.buttonSelectMMS,'Enable','Off');
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
            if(strncmp(str,'Group: ',7))
                %this is a group
                idx = strncmp(this.visHandles.popupROIType.String,'Group: ',7);
                grps = this.visHandles.popupROIType.String(idx);
                ROI.ROIType = -1*find(strcmp(grps,str),1,'first');
            else
                ROI.ROIType = ROICtrl.ROIItem2ROIType(str);
            end
            %ROI.ROIType = get(this.visHandles.popupROIType,'Value')-1;
            ROI.ROISubType = get(this.visHandles.popupROISubType,'Value');
            ROI.ROIVicinity = get(this.visHandles.popupROIVicinity,'Value');            
        end
        
        function allROT = get.allROITypes(this)
            ds1 = this.visObj.fdt.getAllSubjectNames(this.curStudyName,FDTree.defaultConditionName);
            if(~isempty(ds1))
                allROT = this.visObj.fdt.getResultROICoordinates(this.curStudyName,ds1{1},[],[]);
                if(isempty(allROT))
                    allROT = ROICtrl.getDefaultROIStruct();
                end
                allROT = [0;allROT(:,1,1)];
            else
                allROT = 0;
            end
        end
        
        function out = get.curMVGroup(this)
            %return definition (struct) of current MVGroup
            if(~isempty(this.curMVGroupName))
                out = this.visObj.fdt.getStudyMVGroupTargets(this.curStudyName,this.curMVGroupName);
            else
                out.x = [];
                out.y = [];
                out.ROI.ROIType = 0;
                out.ROI.ROISubType = 1;
                out.ROI.ROIVicinity = 1;
            end
        end
        
        
        %% GUI callbacks
        function GUI_popupStudySelCallback(this,hObject,eventdata)
            %select study
            studyStr = get(hObject,'String');
            this.curStudyName = studyStr{get(hObject,'Value')};
            %ROI
            ds1 = this.visObj.fdt.getAllSubjectNames(this.curStudyName,FDTree.defaultConditionName);
            if(~isempty(ds1))
                allROT = this.visObj.fdt.getResultROICoordinates(this.curStudyName,ds1{1},[],[]);
                if(isempty(allROT))
                    allROT = ROICtrl.getDefaultROIStruct();
                end
                allROIStr = arrayfun(@ROICtrl.ROIType2ROIItem,this.allROITypes,'UniformOutput',false);
                %allROIStr = arrayfun(@ROICtrl.ROIType2ROIItem,[0;allROT(:,1,1)],'UniformOutput',false);
                grps = this.visObj.fdt.getResultROIGroup(this.curStudyName,[]);
                if(~isempty(grps) && ~isempty(grps{1,1}))
                    allROIStr = [allROIStr; sprintfc('Group: %s',string(grps(:,1)))];
                end
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
                    %this.visObj.fdt.clearAllRIs(studies{i},this.curMVGroupName);
                    this.visObj.fdt.clearAllMVGroupIs();
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
        
        function GUI_switchMVGroupGeneration(this,hObject,eventdata)
            %change the way MVGroup are created
            switch hObject.Tag
                case 'radioFLIMItem'
                    this.visHandles.radioFLIMItem.Value = 1;
                    this.visHandles.radioMIS.Value = 0;
                    this.visHandles.radioMMS.Value = 0;
                case 'radioMIS'
                    this.visHandles.radioFLIMItem.Value = 0;
                    this.visHandles.radioMIS.Value = 1;
                    this.visHandles.radioMMS.Value = 0;
                case 'radioMMS'
                    this.visHandles.radioFLIMItem.Value = 0;
                    this.visHandles.radioMIS.Value = 0;
                    this.visHandles.radioMMS.Value = 1;
            end
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
            selStr = get(this.visHandles.listboxRemaining,'String');
            if(isempty(selStr))
                this.updateFICtrls();
                return
            end
            selStr = selStr(get(this.visHandles.listboxRemaining,'Value'));
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
                    %this.visObj.fdt.clearAllRIs(studies{i},this.curMVGroupName);
                    this.visObj.fdt.clearAllMVGroupIs();
                end
            end
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
            this.updateFICtrls();
        end
        
        function removeMVCallback(this,hObject,eventdata)
            %callback function from the remove (deselect) button
            selStr = get(this.visHandles.(sprintf('listboxSelected%s',upper(this.curAxis))),'String');
            selStr = selStr(get(this.visHandles.(sprintf('listboxSelected%s',upper(this.curAxis))),'Value'));
            if(any(strcmp(selStr,'-none-')))
                return
            end
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
                    %this.visObj.fdt.clearAllRIs(studies{i},this.curMVGroupName);
                    this.visObj.fdt.clearAllMVGroupIs();
                end
            end
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
            this.updateFICtrls();
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
        
        function addMISCallback(this,hObject,eventdata)
            %
            if(isempty(this.MISAvailableTableIdx))
                return
            end
            MVs = get(this.visHandles.tableMVGroupsAvailableMIS,'Data');
            cMV = this.visObj.fdt.getStudyMVGroupTargets(this.curStudyName,this.curMVGroupName);
            new = MVs(this.MISAvailableTableIdx,1);
            cMV.x(end+1:end+length(new),1) = new;
            cMV.x = sort(cMV.x);
            %update MVGroups in all studies
            studies = this.visObj.fdt.getAllStudyNames();
            for i=1:length(studies)
                if(ismember(this.curMVGroupName,this.visObj.fdt.getMVGroupNames(studies{i},0)))
                    this.visObj.fdt.setStudyMVGroupTargets(studies{i},this.curMVGroupName,cMV);
                    %this.visObj.fdt.clearAllRIs(studies{i},this.curMVGroupName);
                    this.visObj.fdt.clearAllMVGroupIs();
                end
            end
            this.updateMISCtrls();
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);         
        end
        
        function removeMISCallback(this,hObject,eventdata)
            %remove MV group from merged MV group
            cMV = this.visObj.fdt.getStudyMVGroupTargets(this.curStudyName,this.curMVGroupName);
            if(isempty(this.MISSelectedTableIdx) || isempty(cMV) || length(this.MISSelectedTableIdx) ~= length(cMV))
                return
            end
            if(length(cMV.x) == 1)
                cMV.x = cell(0,0);
            else
                cMV.x(this.MISSelectedTableIdx) = [];
            end
            %update MVGroups in all studies
            studies = this.visObj.fdt.getAllStudyNames();
            for i=1:length(studies)
                if(ismember(this.curMVGroupName,this.visObj.fdt.getMVGroupNames(studies{i},0)))
                    this.visObj.fdt.setStudyMVGroupTargets(studies{i},this.curMVGroupName,cMV);
                    %this.visObj.fdt.clearAllRIs(studies{i},this.curMVGroupName);
                    this.visObj.fdt.clearAllMVGroupIs();
                end
            end
            this.updateMISCtrls();
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
        end
        
        function addMMSCallback(this,hObject,eventdata)
            %add study condition to global MVGroup selection
            if(isempty(this.MMSAvailableTableIdx))
                return
            end
            studyConditions = get(this.visHandles.tableMVGroupsAvailableMMS,'Data'); %study views and corresponding studies
            %check if MVGroup is available yet in selected study
            MVGroupStr = this.visObj.fdt.getMVGroupNames(studyConditions{this.MMSAvailableTableIdx,1},0);
            if(isempty(MVGroupStr) || ~ismember(this.curMVGroupName,MVGroupStr))
                choice = questdlg(sprintf('%s is not available in %s. Add the selected MVGroup to this study?',...
                    this.curMVGroupName,studyConditions{this.MMSAvailableTableIdx,1}),'MVGroup not available','Yes','No','Yes');
                switch choice
                    case 'No'
                        return
                end                
                %add current MVGroup to study
                cMVs = this.visObj.fdt.getStudyMVGroupTargets(this.curStudyName,this.curMVGroupName);
                this.visObj.fdt.setStudyMVGroupTargets(studyConditions{this.MMSAvailableTableIdx,1},this.curMVGroupName,cMVs);
            end
            selectedConditions = this.visObj.fdt.getGlobalMVGroupTargets(this.curMVGroupName);
            if(isempty(selectedConditions))
                selectedConditions = cell(0,2);
            end
            selectedConditions(end+1,:) = cell(1,2);
            selectedConditions(end,:) = studyConditions(this.MMSAvailableTableIdx,:);
            this.visObj.fdt.setGlobalMVGroupTargets(this.curMVGroupName,selectedConditions);
            this.updateMMSCtrls();
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
        end
        
        function removeMMSCallback(this,hObject,eventdata)
            %remove study condition from global MVGroup selection
            if(~isempty(this.MMSSelectedTableIdx))
                selectedConditions = this.visObj.fdt.getGlobalMVGroupTargets(this.curMVGroupName);
                selectedConditions(this.MMSSelectedTableIdx,:) = [];
                this.visObj.fdt.setGlobalMVGroupTargets(this.curMVGroupName,selectedConditions);
            end
            this.updateMMSCtrls();
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
        end
        function tableSelectedMISCallback(this,hObject,eventdata)
            %set current indices of in MIS selection table
            this.MISSelectedTableIdx = eventdata.Indices(:,1);
        end
        
        function tableAvailableMISCallback(this,hObject,eventdata)
            %set current indices of selectable MIS MV groups
            this.MISAvailableTableIdx = eventdata.Indices(:,1);
        end
        
        function tableSelectedMMSCallback(this,hObject,eventdata)
            %set current indices of study condition in selection table
            this.MMSSelectedTableIdx = eventdata.Indices(:,1);
        end
        
        function tableAvailableMMSCallback(this,hObject,eventdata)
            %set current indices of selectable study conditions
            this.MMSAvailableTableIdx = eventdata.Indices(:,1);
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
                studies = get(this.visHandles.popupStudySel,'String');
                idx = find(strcmp(val,studies),1);
                if(~isempty(idx))
                    set(this.visHandles.popupStudySel,'Value',idx);
                end
                this.GUI_popupStudySelCallback(this.visHandles.popupStudySel,[]);
            end
        end
    end %methods
    
    methods(Access = protected)
        %internal methods        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.StatsMVGroupMgrFigure) || ~strcmp(get(this.visHandles.StatsMVGroupMgrFigure,'Tag'),'StatsMVGroupMgrFigure'));
        end
    end %methods protected
end %classdef
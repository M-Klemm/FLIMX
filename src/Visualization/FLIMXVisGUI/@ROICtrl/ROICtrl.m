classdef ROICtrl < handle
    %=============================================================================================================
    %
    % @file     ROICtrl.m
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
    % @brief    A class to handle UI controls for ROI selection / definition in FLIMXVisGUI
    %
    properties(SetAccess = protected,GetAccess = public)
        
    end
    properties(SetAccess = protected,GetAccess = protected)
        visObj = [];
        mySide = [];
        myFDisplayL = [];
        myFDisplayR = [];
        
        roi_apply_button = [];
        roi_add_button = [];
        roi_del_button = [];
        
        roi_type_popup = [];
        roi_subtype_popup = []
        roi_vicinity_popup = [];
        roi_table = [];
        roi_table_clearLast_button = [];
        roi_table_clearAll_button = [];
        
        x_check = [];
        x_lo_dec_button = [];
        x_lo_inc_button = [];
        x_lo_edit = [];
        x_u_dec_button = [];
        x_u_inc_button = [];
        x_u_edit = [];
        x_text = [];
        x_sz_text = [];
        x_sz_edit = [];
        x_szMM_text = [];
        x_szPX_text = [];
        x_szMM_edit = [];
        
        y_check = [];
        y_lo_dec_button = [];
        y_lo_inc_button = [];
        y_lo_edit = [];
        y_u_dec_button = [];
        y_u_inc_button = [];
        y_u_edit = [];
        y_text = [];
        y_sz_text = [];
        y_sz_edit = [];
        y_szMM_text = [];
        y_szPX_text = [];
        y_szMM_edit = [];
    end
    
    properties (Dependent = true)
        myHFD = [];
        editXlo = 0;
        editYlo = 0;
        editXu = 0;
        editYu = 0;
        ROIType = 0;
        ROISubType = 0;
        ROIVicinity = 0;
    end
    
    methods
        function this = ROICtrl(visObj,s,FDisplayL,FDisplayR)
            % Constructor for Scale.
            this.visObj = visObj;
            this.mySide = s;
            this.myFDisplayL = FDisplayL;
            this.myFDisplayR = FDisplayR;
            this.setUIHandles();
            this.setupGUI();
        end
        
        function out = get.myHFD(this)
            %get handle to FData object
            out = this.(sprintf('myFDisplay%s',upper(this.mySide))).gethfd();
            out = out{1};
        end
        
        function out = get.editXlo(this)
            %get value of exit field x lower
            out = str2double(get(this.x_lo_edit,'String'));
        end
        
        function out = get.editYlo(this)
            %get value of exit field y lower
            out = str2double(get(this.y_lo_edit,'String'));
        end
        
        function out = get.editXu(this)
            %get value of exit field x upper
            out = str2double(get(this.x_u_edit,'String'));
        end
        
        function out = get.editYu(this)
            %get value of exit field y upper
            out = str2double(get(this.y_u_edit,'String'));
        end
        
        function out = get.ROIType(this)
            %get current ROI type
            str = this.roi_type_popup.String;
            nr = this.roi_type_popup.Value;
            if(iscell(str))
                str = str{nr};
            elseif(ischar(str))
                %nothing to do
            else
                %should not happen
            end
            if(strncmp(str,'Group: ',7))
                %this is a group
                idx = strncmp(this.roi_type_popup.String,'Group: ',7);
                grps = this.roi_type_popup.String(idx);
                out = -1*find(strcmp(grps,str),1,'first');
            else
                out = ROICtrl.ROIItem2ROIType(str);
            end
        end
        
        function set.ROIType(this,val)
            %set current ROI type
            str = this.roi_type_popup.String;
            if(ischar(str))
                str = {str};
            end
            [newStr,~,ROITypeFine] = ROICtrl.ROIType2ROIItem(val);
            idx = find(strcmp(str,newStr),1,'first');
            if(isempty(idx))
                %add new item to popup
                ROIStr = strsplit(newStr,'#');
                idx = find(strncmp(str,ROIStr{1},length(ROIStr{1})));
                oldTypes = [];
                for i = idx(:)'
                    oldTypes = [oldTypes ROICtrl.ROIItem2ROIType(str{i})];
                end
                d = val - max(oldTypes) -1;
                oldPStr = [];
                if(idx(end) < length(str))
                    oldPStr = str(idx(end)+1:end,1);
                end
                for i = d:-1:0
                    str{idx(1)+ROITypeFine-1-i,1} = sprintf('%s#%d',ROIStr{1},ROITypeFine-i);
                end
                if(~isempty(oldPStr))
                    %append remaining old ROI items
                    pos = idx(end)+d+2;
                    str(pos:pos+length(oldPStr)-1) = oldPStr;
                end
                %now find the index of the newly added item
                idx = find(strcmp(str,newStr),1,'first');
                if(isempty(idx))
                    %should not happen
                    return
                end
                this.roi_type_popup.String = str;
            end
            this.roi_type_popup.Value = idx;
            %this.roi_type_popup.Value = max(1,min(length(this.roi_type_popup.String),val+1));
        end
        
        function out = get.ROISubType(this)
            %get current ROI subtype
            out = this.roi_subtype_popup.Value;
        end
        
        function out = get.ROIVicinity(this)
            %get current state of ROI invert flag
            out = get(this.roi_vicinity_popup,'Value');
        end
        
        function enDisAble(this,argEn,argVis)
            %enable/ disable manual scaling controls for dimension dim
            if(~ischar(argEn))
                if(argEn)
                    argEn = 'on';
                else
                    argEn = 'off';
                end
            end
            if(~ischar(argVis))
                if(argVis)
                    argVis = 'on';
                else
                    argVis = 'off';
                end
            end
            dim =['x','y'];
            for i = 1:2
                set(this.(sprintf('%s_check',dim(i))),'Visible',argVis);
                set(this.(sprintf('%s_lo_dec_button',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_lo_edit',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_lo_inc_button',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_text',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_u_dec_button',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_u_edit',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_u_inc_button',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_sz_text',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_sz_edit',dim(i))),'Enable','off','Visible',argVis);
                set(this.(sprintf('%s_szMM_text',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_szPX_text',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_szMM_edit',dim(i))),'Enable','off','Visible',argVis);
            end
        end
                
        function editCallback(this,dim,bnd)
            %callback function of the edit field
            current = str2double(get(this.(sprintf('%s_%s_edit',dim,bnd)),'String'));
            %check for validity
            rt = this.ROIType;
            if(rt > FDTStudy.roiBaseRectangle && rt < FDTStudy.roiBaseCircle)
                %rectangles
                current = this.checkBnds(dim,bnd,current);
            end
            set(this.(sprintf('%s_%s_edit',dim,bnd)),'String',current);
            this.save();
            this.updateGUI([]);
        end
        
        function buttonCallback(this,dim,thisBnd,target)
            %callback function of an increase/decrease (=target) button
            hfd = this.myHFD;
            if(isempty(hfd))
                return
            end
            %get current value from edit field
            switch thisBnd
                case 'lo'
                    thisEdit = 'Min';
                    otherEdit = 'Max';
                    otherBnd = 'u';
                case 'u'
                    thisEdit = 'Max';
                    otherEdit = 'Min';
                    otherBnd = 'lo';
            end
            other = [];
            rt = this.ROIType;
            ROICoord = hfd.getROICoordinates(rt);
            if(isempty(ROICoord) || ~any(ROICoord(:)) && rt < FDTStudy.roiBasePolygon)
                %ETDRS grid, rectangles, circles
                ROICoord = [hfd.rawImgYSz; hfd.rawImgXSz];
                this.updateGUI(ROICoord);
                this.save();
                return
            end
            if(rt > FDTStudy.roiBaseETDRS && rt < FDTStudy.roiBaseRectangle)
                %ETDRS grid
                switch target
                    case 'inc'
                        d = 1;
                    case 'dec'
                        d = -1;
                end
                switch dim
                    case 'x'
                        current = min(max(1,this.editXlo+d),hfd.rawImgXSz(2));
                    case 'y'
                        current = min(max(1,this.editYlo+d),hfd.rawImgXSz(2));
                end
            elseif(rt > FDTStudy.roiBaseRectangle && rt < FDTStudy.roiBaseCircle)
                %rectangles
                current = this.(sprintf('%s%s',target,thisEdit))(dim);
                %increase/decrease and check for validity
                current = this.checkBnds(dim,thisBnd,current);
            elseif(rt > FDTStudy.roiBaseCircle && rt < FDTStudy.roiBasePolygon)
                %circles
                current = this.(sprintf('%s%s',target,thisEdit))(dim);
                if(strcmp(thisBnd,'lo'))
                    other = this.(sprintf('%s%s',target,otherEdit))(dim);
                end
            end
            this.(sprintf('%s_%s_edit',dim,thisBnd)).String = current;
            if(~isempty(other))
                this.(sprintf('%s_%s_edit',dim,otherBnd)).String = other;
            end
            this.save();
            this.updateGUI([]);
        end
        
        function tableEditCallback(this,eventdata)
            %callback function to edit node of current polygon
            this.save();
            this.updateGUI([]);
        end
        
        function buttonClearLastCallback(this)
            %callback function to clear last node of current polygon
            data = get(this.roi_table,'Data');
            rt = this.ROIType;
            if(~isempty(data) && rt > FDTStudy.roiBasePolygon && rt < FDTStudy.roiBaseStop)
%                 [~,~,ROITypeFine] = ROICtrl.ROIType2ROIItem(this.ROIType);
%                 choice = questdlg(sprintf('Delete last node (y=%d, x=%d) of Polygon #%d ROI in subject %s?',data{1,end},data{2,end},ROITypeFine,this.myHFD.subjectName),'Clear last Polygon ROI node?','Yes','No','No');
%                 switch choice
%                     case 'Yes'
                        data(:,end) = [];
                        set(this.roi_table,'Data',data);
                        this.save();
%                 end
            end
        end
        
        function buttonClearAllCallback(this)
            %callback function to clear all nodes of current polygon
            rt = this.ROIType;
            [ROIStr,~,ROITypeFine] = ROICtrl.ROIType2ROIItem(this.ROIType);
            if(rt > FDTStudy.roiBaseETDRS && rt < FDTStudy.roiBasePolygon)
                choice = questdlg(sprintf('Clear ROI %s in subject %s?',ROIStr,this.myHFD.subjectName),'Clear ROI?','Yes','No','No');
                switch choice
                    case 'Yes'
                        this.resetROI();
                end
            elseif(rt > FDTStudy.roiBasePolygon && rt < FDTStudy.roiBaseStop)
                choice = questdlg(sprintf('Delete all nodes of Polygon #%d ROI in subject %s?',ROITypeFine,this.myHFD.subjectName),'Clear all Polygon ROI nodes?','Yes','No','No');
                switch choice
                    case 'Yes'
                        set(this.roi_table,'Data',cell(2,1));
                        this.save();
                end
            end
        end
        
        function addNewROI(this)
            %add another ROI of the current type
            rt = this.ROIType;
%             hfd = this.myHFD;
            if(rt == 0) %isempty(hfd) || 
                return
            end
            pStr = this.roi_type_popup.String;
            if(ischar(pStr))
                pStr = {pStr};
            end
            allROT = cellfun(@ROICtrl.ROIItem2ROIType,pStr);
            [str,c,f] = ROICtrl.ROIType2ROIItem(rt);
            idx = allROT > c*1000 & allROT < (c+1)*1000;
            this.ROIType = max(allROT(idx))+1;
            this.updateGUI([]);
            this.save();
        end

        function deleteROI(this)
            %delete current ROI
            rt = this.ROIType;
            if(rt > 1001 && rt < FDTStudy.roiBaseRectangle || rt > 2002 && rt < FDTStudy.roiBaseCircle || rt > 3002 && rt < FDTStudy.roiBasePolygon || rt > 4002 && rt < FDTStudy.roiBaseStop)
                hfd = this.myHFD;
                if(isempty(hfd))
                    return
                end
%                 ROIInfo = this.getCurROIInfo();
%                 if(strncmp('ConditionMVGroup',hfd.dType,16))
%                     tmp = hfd.dType;
%                     this.visObj.fdt.clearMVGroups(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),sprintf('GlobalMVGroup%s',tmp(12:end)),[]);
%                     hfd.setROICoordinates(this.ROIType,ROIInfo);
%                 elseif(strncmp('GlobalMVGroup',hfd.dType,13))
%                     hfd.setROICoordinates(this.ROIType,ROIInfo);
%                 else
                    this.visObj.fdt.removeResultROIType(this.visObj.getStudy(this.mySide),rt);
%                 end
                this.ROIType = rt-1;
                this.setupGUI();
                this.updateGUI([]);
            end
        end
        
        function resetROI(this)
            %reset current ROI
            rt = this.ROIType;
            if(rt == 0)
                return
            end
            ROIInfo = zeros(2,3,'int16');
            this.updateGUI(ROIInfo(:,2:end));
            this.save();
        end
                
        function popupCallback(this,type)
            %callback function of popup to change ROI type / subtype
            this.setupGUI();
            this.updateGUI([]);
        end
        
        function setStartPoint(this,coord)
            %set coordinates(y,x) of ROI start point
            %coord must be matrix position
            if(this.ROIType < FDTStudy.roiBasePolygon)
                ROICoord = this.getCurROIInfo();
                ROICoord = ROICoord(:,2:end);
                if(isempty(coord))
                    coord = [0,0];
                end
                ROICoord(:,1) = coord;
                this.updateGUI(ROICoord);
            end
        end
        
        function setEndPoint(this,coord,saveFlag)
            %set coordinates(y,x) of ROI end point
            %coord must be matrix position
            ROICoord = this.getCurROIInfo();
            ROICoord = ROICoord(:,2:end);
            rt = this.ROIType;
            coord = int16(coord);
            if(rt < FDTStudy.roiBasePolygon)
                if(isempty(coord))
                    coord = [0,0];
                end
                ROICoord(:,2) = coord;
                if(rt > FDTStudy.roiBaseETDRS && rt < FDTStudy.roiBaseRectangle) %ETDRS
                    ROICoord(:,1) = coord;
                end
            else
                %polygon
                %add only unique pixels
                idx = all(~bsxfun(@minus,ROICoord,coord),1);
                if(~any(idx))
                    ROICoord(:,end+1) = coord;
                end
            end
            if(saveFlag)
                if(rt > FDTStudy.roiBaseRectangle && rt < FDTStudy.roiBaseCircle) %rectangle
                    ROICoord = sort(ROICoord,2);
                end
                this.updateGUI(ROICoord);
                this.save();
            else
                this.updateGUI(ROICoord);
            end
        end
        
        function moveROI(this,d,saveFlag)
            %move ROI to new start point but keep its shape
            if(isempty(d) || (~any(d) && ~saveFlag))
                return
            end
            ROICoord = this.getCurROIInfo();
            ROICoord = ROICoord(:,2:end);
            ROICoord = bsxfun(@minus,ROICoord,int16(d));
            rt = this.ROIType;
            if(saveFlag)
                if(rt > FDTStudy.roiBaseRectangle && rt < FDTStudy.roiBaseCircle) %rectangle
                    ROICoord = sort(ROICoord,2);
                end
                this.updateGUI(ROICoord);
                this.save();
            else
                this.updateGUI(ROICoord);
            end
        end
        
        function setupGUI(this)
            %setup GUI controls for current ROI Type
            hfd = this.myHFD;
            if(isempty(hfd))
                allROIStr = {ROICtrl.ROIType2ROIItem(0)};
            else
                allROT = hfd.getROICoordinates([]);
                if(isempty(allROT))
                    allROT = ROICtrl.getDefaultROIStruct();
                end
                allROIStr = arrayfun(@ROICtrl.ROIType2ROIItem,[0;allROT(:,1,1)],'UniformOutput',false);
                grps = hfd.getROIGroup([]);
                if(~isempty(grps) && ~isempty(grps{1,1}))
                    allROIStr = [allROIStr; sprintfc('Group: %s',string(grps(:,1)))];
                end
            end
            set(this.roi_type_popup,'String',allROIStr,'Value',min(this.roi_type_popup.Value,length(allROIStr)));
            rt = this.ROIType;
            if(rt > FDTStudy.roiBaseETDRS && rt < FDTStudy.roiBaseMaculaGrid)
                %ETDRS grid
                %this.roi_subtype_popup.Value = 1;
                this.roi_subtype_popup.String = this.getROISubtypeString('ETDRS');
                set(this.roi_apply_button,'Visible','on');
                set(this.roi_add_button,'Visible','on');
                set(this.roi_del_button,'Visible','on');
                set(this.roi_vicinity_popup,'Visible','on');
                set(this.roi_subtype_popup,'Visible','on');
                this.enDisAble('off','off');
                set(this.x_check,'Visible','on');
                set(this.y_check,'Visible','on');
                set(this.x_lo_edit,'Visible','on','Enable','on');
                set(this.y_lo_edit,'Visible','on','Enable','on');
                set(this.x_lo_dec_button,'Enable','on','Visible','on');
                set(this.x_lo_inc_button,'Enable','on','Visible','on');
                set(this.y_lo_dec_button,'Enable','on','Visible','on');
                set(this.y_lo_inc_button,'Enable','on','Visible','on');
                set(this.roi_table,'Visible','off');
                set(this.roi_table_clearLast_button,'Visible','off');
                set(this.roi_table_clearAll_button,'Visible','on','String','Clear');
            elseif(rt > FDTStudy.roiBaseMaculaGrid && rt < FDTStudy.roiBaseRectangle)
                %macula grid
                this.roi_subtype_popup.Value = min(6,this.roi_subtype_popup.Value);
                this.roi_subtype_popup.String = this.getROISubtypeString('Macula Grid');
                set(this.roi_apply_button,'Visible','on');
                set(this.roi_add_button,'Visible','on');
                set(this.roi_del_button,'Visible','on');
                set(this.roi_vicinity_popup,'Visible','on');
                set(this.roi_subtype_popup,'Visible','on');
                this.enDisAble('off','off');
                set(this.x_check,'Visible','on');
                set(this.y_check,'Visible','on');
                set(this.x_lo_edit,'Visible','on','Enable','on');
                set(this.y_lo_edit,'Visible','on','Enable','on');
                set(this.x_lo_dec_button,'Enable','on','Visible','on');
                set(this.x_lo_inc_button,'Enable','on','Visible','on');
                set(this.y_lo_dec_button,'Enable','on','Visible','on');
                set(this.y_lo_inc_button,'Enable','on','Visible','on');
                set(this.roi_table,'Visible','off');
                set(this.roi_table_clearLast_button,'Visible','off');
                set(this.roi_table_clearAll_button,'Visible','on','String','Clear');
            elseif(rt > FDTStudy.roiBaseRectangle && rt < FDTStudy.roiBaseCircle)
                %rectangle
                set(this.roi_apply_button,'Visible','on');
                set(this.roi_add_button,'Visible','on');
                set(this.roi_del_button,'Visible','on');
                set(this.roi_vicinity_popup,'Visible','on');
                set(this.roi_subtype_popup,'Visible','off');
                this.enDisAble('on','on');
                set(this.roi_table,'Visible','off');
                set(this.roi_table_clearLast_button,'Visible','off');
                set(this.roi_table_clearAll_button,'Visible','on','String','Clear');
            elseif(rt > FDTStudy.roiBaseCircle && rt < FDTStudy.roiBasePolygon)
                %circle
                set(this.roi_apply_button,'Visible','on');
                set(this.roi_add_button,'Visible','on');
                set(this.roi_del_button,'Visible','on');
                set(this.roi_vicinity_popup,'Visible','on');
                set(this.roi_subtype_popup,'Visible','off');
                this.enDisAble('on','on');
                set(this.y_sz_text','Enable','off','Visible','off');
                set(this.y_sz_edit,'Enable','off','Visible','off');
                set(this.y_szMM_text','Enable','off','Visible','off');
                set(this.y_szPX_text','Enable','off','Visible','off');
                set(this.y_szMM_edit,'Enable','off','Visible','off');
                set(this.roi_table,'Visible','off');
                set(this.roi_table_clearLast_button,'Visible','off');
                set(this.roi_table_clearAll_button,'Visible','on','String','Clear');
            elseif(rt > FDTStudy.roiBasePolygon && rt < FDTStudy.roiBaseStop)
                %polygon
                set(this.roi_apply_button,'Visible','on');
                set(this.roi_add_button,'Visible','on');
                set(this.roi_del_button,'Visible','on');
                set(this.roi_vicinity_popup,'Visible','on');
                set(this.roi_subtype_popup,'Visible','off');
                set(this.roi_table,'Visible','on');
                set(this.roi_table_clearLast_button,'Visible','on');
                set(this.roi_table_clearAll_button,'Visible','on','String','Clear all');
                this.enDisAble('off','off');
            elseif(rt < 0)
                %ROI group
                set(this.roi_apply_button,'Visible','off');
                set(this.roi_add_button,'Visible','off');
                set(this.roi_del_button,'Visible','off');
                set(this.roi_vicinity_popup,'Visible','on');
                if(abs(rt) <= size(grps,1) && any(grps{abs(rt),2} < FDTStudy.roiBaseRectangle))
                    %current ROI groups contains an ETDRS grid
                    set(this.roi_subtype_popup,'Visible','on');
                else
                    set(this.roi_subtype_popup,'Visible','off');
                end
                this.enDisAble('off','off');
                set(this.roi_table,'Visible','off');
                set(this.roi_table_clearLast_button,'Visible','off');
                set(this.roi_table_clearAll_button,'Visible','off');
            else
                %switch to 'none'
                set(this.roi_apply_button,'Visible','off');
                set(this.roi_add_button,'Visible','off');
                set(this.roi_del_button,'Visible','off');
                set(this.roi_vicinity_popup,'Visible','off');
                set(this.roi_subtype_popup,'Visible','off');
                this.enDisAble('off','off');
                set(this.roi_table,'Visible','off');
                set(this.roi_table_clearLast_button,'Visible','off');
                set(this.roi_table_clearAll_button,'Visible','off');
            end
        end
        
        function updateGUI(this,ROICoord)
            %set GUI items to values from FDTree / FData object
            %ROICoord must be matrix position
            hfd = this.myHFD;
            if(isempty(hfd))
                return
            end
            rt = this.ROIType;
            if(isempty(ROICoord))
                ROICoord = hfd.getROICoordinates(rt);
            end
%             if(isempty(ROICoord) || ~any(ROICoord(:)))
%                 if(rt < FDTStudy.roiBasePolygon)
%                     %ETDRS grid, rectangles, circles
%                     ROICoord = [hfd.rawImgYSz; hfd.rawImgXSz];
%                 else
%                     ROICoord = [];
%                 end
%             end
            if(rt > FDTStudy.roiBasePolygon && rt < FDTStudy.roiBaseStop && ~all(all(ROICoord,1)))
                %polygons
                ROICoord = ROICoord(:,all(ROICoord,1));
            end
            fi = hfd.getFileInfoStruct();
            if(~isempty(fi))
                res = fi.pixelResolution/1000;
            else
                res = 0;%58.66666666666/1000;
                %todo: warning/error message
            end
            if((isempty(ROICoord) || ~any(ROICoord(:))) && rt < FDTStudy.roiBasePolygon)
                this.y_lo_edit.String = '';
                this.x_lo_edit.String = '';
                this.y_u_edit.String = '';
                this.x_u_edit.String = '';
                this.y_sz_edit.String = '';
                this.y_szMM_edit.String = '';
                this.x_sz_edit.String = '';
                this.x_szMM_edit.String = '';
%                 this.ROIType = 0;
%                 this.popupCallback('');
            else
                if(~isempty(ROICoord))
                    ROICoord(1,:) = hfd.yPos2Lbl(ROICoord(1,:));
                    ROICoord(2,:) = hfd.xPos2Lbl(ROICoord(2,:));
                end
                if(rt > FDTStudy.roiBaseETDRS && rt < FDTStudy.roiBaseRectangle)
                    %ETDRS grid
                    set(this.y_lo_edit,'String',num2str(ROICoord(1,1)));
                    set(this.x_lo_edit,'String',num2str(ROICoord(2,1)));
                elseif(rt == 0 || rt > FDTStudy.roiBaseRectangle && rt < FDTStudy.roiBaseCircle)
                    %rectangle
                    set(this.y_lo_edit,'String',num2str(ROICoord(1,1)));
                    set(this.x_lo_edit,'String',num2str(ROICoord(2,1)));
                    set(this.y_u_edit,'String',num2str(ROICoord(1,2)));
                    set(this.x_u_edit,'String',num2str(ROICoord(2,2)));
                    d = abs(ROICoord(1,2)-ROICoord(1,1))+1;
                    set(this.y_sz_edit,'String',num2str(d));
                    set(this.y_szMM_edit,'String',FLIMXFitGUI.num4disp(res*double(d)));
                    d = abs(ROICoord(2,2)-ROICoord(2,1))+1;
                    set(this.x_sz_edit,'String',num2str(d));
                    set(this.x_szMM_edit,'String',FLIMXFitGUI.num4disp(res*double(d)));
                elseif(rt > FDTStudy.roiBaseCircle && rt < FDTStudy.roiBasePolygon)
                    %circle
                    set(this.y_lo_edit,'String',num2str(ROICoord(1,1)));
                    set(this.x_lo_edit,'String',num2str(ROICoord(2,1)));
                    set(this.y_u_edit,'String',num2str(ROICoord(1,2)));
                    set(this.x_u_edit,'String',num2str(ROICoord(2,2)));
                    d = 2*sqrt(sum((ROICoord(:,1)-ROICoord(:,2)).^2));
                    set(this.x_sz_edit,'String',FLIMXFitGUI.num4disp(d));
                    set(this.x_szMM_edit,'String',FLIMXFitGUI.num4disp(res*d));
                elseif(rt > FDTStudy.roiBasePolygon && rt < FDTStudy.roiBaseStop)
                    %polygon
                    set(this.roi_table,'Data',num2cell(ROICoord))
                    if(~isempty(ROICoord))
                        set(this.roi_table,'ColumnWidth',num2cell(25*ones(1,size(ROICoord,2))));
                    end
                end
            end
        end
        
        function out = getCurROIInfo(this,outputAsLabel)
            %get coordinates of current ROI
            %out = [invert,x1,x2]
            %      [enable,y1,y2]
            %default: out is in matrix positions, not labels
            if(nargin < 2)
                outputAsLabel = false;
            else
                outputAsLabel = logical(outputAsLabel);
            end
            out = zeros(2,3,'int16');
            hfd = this.myHFD;
            if(isempty(hfd))
                return
            end
            rt = this.ROIType;
            if(rt < 0)
                out = [];
                return
            end
            out(1,1) = rt;
            out(2,1) = this.ROIVicinity;
            if(rt == 0)
                if(~isempty(hfd.rawImgYSz))
                    out(2,2:3) = hfd.rawImgYSz;
                end
                if(~isempty(hfd.rawImgXSz))
                    out(1,2:3) = hfd.rawImgXSz;
                end
                if(outputAsLabel)
                    out(1,2:end) = hfd.yPos2Lbl(out(1,2:end));
                    out(2,2:end) = hfd.xPos2Lbl(out(2,2:end));
                end
                return
            end
            if((isempty(this.y_lo_edit.String) && this.y_lo_edit.Visible) || (isempty(this.x_lo_edit.String) && this.x_lo_edit.Visible)  ||...
                    (isempty(this.y_u_edit.String) && this.y_u_edit.Visible) || (isempty(this.x_u_edit.String) && this.x_u_edit.Visible) )
                return
            end
            if(rt > FDTStudy.roiBaseETDRS && rt < FDTStudy.roiBasePolygon)
                %ETDRS, rectangles, circles
                out(1,2) = hfd.yLbl2Pos(sscanf(this.y_lo_edit.String,'%i',1)); %sscanf(s,'%f',1);
                out(2,2) = hfd.xLbl2Pos(sscanf(this.x_lo_edit.String,'%i',1));
            end
            if(rt > FDTStudy.roiBaseETDRS && rt < FDTStudy.roiBaseRectangle)
                %ETDRS
                out(:,3) = out(:,2);
            elseif(rt > FDTStudy.roiBasePolygon && rt < FDTStudy.roiBaseStop)
                %polygons
                out = int16([[1;this.ROIVicinity], cell2mat(get(this.roi_table,'Data'))]);
                out(1,2:end) = hfd.yLbl2Pos(out(1,2:end));
                out(2,2:end) = hfd.xLbl2Pos(out(2,2:end));
%                 if(size(tmp,2) < size(out,2))
%                     out(:,1:size(tmp,2)) = tmp;
%                 end
            else
                %rectangles, circles
                out(1,3) = hfd.yLbl2Pos(sscanf(this.y_u_edit.String,'%i',1));
                out(2,3) = hfd.xLbl2Pos(sscanf(this.x_u_edit.String,'%i',1));
            end
            if(outputAsLabel)
                out(1,2:end) = hfd.yPos2Lbl(out(1,2:end));
                out(2,2:end) = hfd.xPos2Lbl(out(2,2:end));
            end
        end
        
    end %methods
    
    methods(Access = protected)
        %internal methods
        function out = incMin(this,dim)
            %manual scaling: increase lower bound
            [cMin, ~, step, gMin, gMax] = this.getValuesFromGUI(dim,false);
            if(gMax < 1)
                %B&H amplitudes
                out = cMin+(gMax-gMin)*0.05;
            else
                out = cMin+1;
                %                 if(isempty(step))
                %                     out = cMin+ceil((gMax-gMin)*0.05);
                %                 else
                %                     out = cMin+step*ceil((gMax-gMin)/step*0.05);
                %                 end
            end
        end
        
        function out = decMin(this,dim)
            %manual scaling: decrease lower bound
            [cMin, ~, step, gMin, gMax] = this.getValuesFromGUI(dim,false);
            if(gMax < 1)
                %B&H amplitudes
                out = cMin-(gMax-gMin)*0.05;
            else
                out = cMin-1;
                %                 if(isempty(step))
                %                     out = cMin-ceil((gMax-gMin+1)/20);
                %                 else
                %                     out = cMin-step*ceil((gMax-gMin+1)/step/20);
                %                 end
            end
        end
        
        function out = incMax(this,dim)
            %manual scaling: increase lower bound
            [~, cMax, step, gMin, gMax] = this.getValuesFromGUI(dim,false);
            if(gMax < 1)
                %B&H amplitudes
                out = cMax+(gMax-gMin)*0.05;
            else
                out = cMax+1;
                %                 if(isempty(step))
                %                     out = cMax+ceil((gMax-gMin)*0.05);
                %                 else
                %                     out = cMax+step*ceil((gMax-gMin)/step*0.05);
                %                 end
            end
        end
        
        function out = decMax(this,dim)
            %manual scaling: decrease lower bound
            [~, cMax, step, gMin, gMax] = this.getValuesFromGUI(dim,false);
            if(gMax < 1)
                %B&H amplitudes
                out = cMax-(gMax-gMin)*0.05;
            else
                out = cMax-1;
                %                 if(isempty(step))
                %                     out = cMax-ceil((gMax-gMin+1)/20);
                %                 else
                %                     out = cMax-step*ceil((gMax-gMin+1)/step/20);
                %                 end
            end
        end
        
        function [cMin, cMax, step, gMin, gMax, flag] = getValuesFromGUI(this,dim,isMatrixPos)
            %get current ROI values, output is lin or per
            cMin=0; cMax=0; step = 1; gMin=0; gMax=0; flag=0;
            hfd = this.myHFD;
            if(isempty(hfd))%|| isempty(hfd.rawImage)
                return
            end
            %get current values
            [cMin, cMax, step] = hfd.getROIParameters(this.ROIType,dim,isMatrixPos);
            %[flag, cMin, cMax, step] = hfd.(sprintf('getMS%s',upper(dim)))(isMatrixPos);
            tmp = hfd.(sprintf('rawImg%sSz',upper(dim)));
            if(isempty(tmp))
                return
            end
            gMin = tmp(1);
            gMax = tmp(2);
            if(strcmp(dim,'z') && hfd.sType == 2)
                %scale log data back to linear
                cMin = 10^cMin;
                cMax = 10^cMax;
                gMin = 10^gMin;
                gMax = 10^gMax;
            end
            if((strcmp(dim,'x') || strcmp(dim,'y')) && ~isMatrixPos)
                gMin = hfd.xPos2Lbl(gMin);
                gMax = hfd.xPos2Lbl(gMax);
            end
        end
        
        function  val = checkBnds(this,dim,bnd,val)
            %check & correct new value of lower bound for over-/ underflows; update
            [cMin, cMax, step, gMin, gMax] = this.getValuesFromGUI(dim,false);
            if(isnan(val))
                val = 1;
            end
            switch bnd
                case 'lo'
                    if(val > cMax) %overflow
                        if(isempty(step))
                            val = cMax-(gMax-gMin)*0.05;
                        else
                            val = cMax-ceil((gMax-gMin)*0.05)*step;
                        end
                    end
                case 'u'
                    if(val < cMin) %underflow
                        if(isempty(step))
                            val = cMin+(gMax-gMin)*0.05;
                        else
                            val = cMax+ceil((gMax-gMin)*0.05)*step;
                        end
                    end
            end
        end
        
        function save(this)
            %update FData objects
            hfd = this.myHFD;
            if(isempty(hfd))
                return
            end
            ROIInfo = this.getCurROIInfo();
            if(strncmp('ConditionMVGroup',hfd.dType,16))
                tmp = hfd.dType;
                this.visObj.fdt.clearMVGroups(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),sprintf('GlobalMVGroup%s',tmp(12:end)),[]);
                hfd.setROICoordinates(this.ROIType,ROIInfo);
            elseif(strncmp('GlobalMVGroup',hfd.dType,13))
                hfd.setROICoordinates(this.ROIType,ROIInfo);
            else
                this.visObj.fdt.setResultROICoordinates(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),hfd.dType,hfd.id,this.ROIType,ROIInfo);
            end
        end
        
        function setUIHandles(this)
            %builds the uicontrol handles for the ROICtrl object for axis ax
            s = this.mySide;
            this.roi_apply_button = this.visObj.visHandles.(sprintf('roi_apply_%s_button',s));
            this.roi_add_button = this.visObj.visHandles.(sprintf('roi_add_%s_button',s));
            this.roi_del_button = this.visObj.visHandles.(sprintf('roi_delete_%s_button',s));
            dims =['x','y','z'];
            this.roi_type_popup = this.visObj.visHandles.(sprintf('roi_type_%s_popup',s));
            this.roi_subtype_popup = this.visObj.visHandles.(sprintf('roi_subtype_%s_popup',s));
            this.roi_vicinity_popup = this.visObj.visHandles.(sprintf('roi_vicinity_%s_popup',s));
            this.roi_table = this.visObj.visHandles.(sprintf('roi_%s_table',s));
            this.roi_table_clearLast_button = this.visObj.visHandles.(sprintf('roi_table_clearLast_%s_button',s));
            this.roi_table_clearAll_button = this.visObj.visHandles.(sprintf('roi_table_clearAll_%s_button',s));
            for i=1:2
                dim = dims(i);
                this.(sprintf('%s_lo_dec_button',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_lo_dec_button',s,dim));
                this.(sprintf('%s_lo_inc_button',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_lo_inc_button',s,dim));
                this.(sprintf('%s_lo_edit',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_lo_edit',s,dim));
                this.(sprintf('%s_u_dec_button',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_u_dec_button',s,dim));
                this.(sprintf('%s_u_inc_button',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_u_inc_button',s,dim));
                this.(sprintf('%s_u_edit',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_u_edit',s,dim));
                this.(sprintf('%s_text',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_text',s,dim));
                this.(sprintf('%s_sz_text',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_sz_text',s,dim));
                this.(sprintf('%s_sz_edit',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_sz_edit',s,dim));
                this.(sprintf('%s_szMM_text',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_szMM_text',s,dim));
                this.(sprintf('%s_szPX_text',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_szPX_text',s,dim));
                this.(sprintf('%s_szMM_edit',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_szMM_edit',s,dim));
            end
        end
    end %methods protected
    
    methods(Static)
        function out = ROIItem2ROIType(str)
            %convert ROIItem (from ROI popup) to numeric ROIType
            str = deblank(str);
            if(strcmp(str,'-none-'))
                out = 0;
            elseif(strncmp(str,'ETDRS Grid #',12))
                out = FDTStudy.roiBaseETDRS + str2double(str(13:end));
            elseif(strncmp(str,'Macula Grid #',13))
                out = FDTStudy.roiBaseMaculaGrid + str2double(str(14:end));
            elseif(strncmp(str,'Rectangle #',11))
                out = FDTStudy.roiBaseRectangle + str2double(str(12:end));
            elseif(strncmp(str,'Circle #',8))
                out = FDTStudy.roiBaseCircle + str2double(str(9:end));
            elseif(strncmp(str,'Polygon #',9))
                out = FDTStudy.roiBasePolygon + str2double(str(10:end));
            else
                out = 0;
            end
        end
        
        function [str,ROIMajor,ROIMinor] = ROIType2ROIItem(ROIType)
            %convert numeric ROIType to ROIItem (for ROI popup) 
            [ROIMajor, ROIMinor] = ROICtrl.decodeROIType(ROIType);
            switch ROIMajor
                case 1
                    str = sprintf('ETDRS Grid #%d',ROIMinor);
                case 2
                    str = sprintf('Macula Grid #%d',ROIMinor);
                case 3
                    str = sprintf('Rectangle #%d',ROIMinor);
                case 4
                    str = sprintf('Circle #%d',ROIMinor);
                case 5
                    str = sprintf('Polygon #%d',ROIMinor);
                otherwise
                    str = '-none-';
            end
        end
        
        function [ROIMajor, ROIMinor] = decodeROIType(ROIType)
            %decode ROIType into major ROI type (1-4) and its running number
            ROIMajor = floor(ROIType / 1000);
            ROIMinor = ROIType - ROIMajor*1000;
            idx = ROIMinor == 0 & ROIMajor > 0;
            ROIMajor(idx) = [];
            ROIMinor(idx) = [];
        end
        
        function flag = mouseInsideROI(cp,ROIType,ROICoord)
            %check if coordinates of current point (cp) are inside an ROI (including the border), return true, otherwise return false
            flag = false;
            if(isempty(cp) || isempty(ROICoord))
                return
            end            
            if(ROIType > FDTStudy.roiBaseRectangle && ROIType < FDTStudy.roiBaseCircle)
                %rectangle
                if(cp(1) >= ROICoord(2,1) && cp(1) <= ROICoord(2,2) && cp(2) >= ROICoord(1,1) && cp(2) <= ROICoord(1,2))
                    flag = true;
                end
            elseif(ROIType > FDTStudy.roiBaseCircle && ROIType < FDTStudy.roiBasePolygon)
                %circle
                radius = sqrt(sum((ROICoord(:,1)-ROICoord(:,2)).^2));
                center = double(ROICoord(:,1));
                current = center - flipud(cp);
                [~,rho] = cart2pol(current(2),current(1));
                if(rho <= radius)
                    flag = true;
                end
            elseif(ROIType > FDTStudy.roiBasePolygon && ROIType < FDTStudy.roiBaseStop)
                %polygon
                ROICoord = double(ROICoord);
                mask = poly2mask(ROICoord(2,:),ROICoord(1,:),max([ROICoord(1,:),cp(2)]),max([ROICoord(2,:),cp(1)]));
                flag = mask(cp(2),cp(1));
            end
        end
        
        function [out, numIdent] = mouseOverROIBorder(cp,ROIType,ROICoord,pixelMargin)
            %check if coordinates of current point (cp) are over the border of an ROI, return the mouse pointer type, otherwise return 'cross'
            out = 'cross'; numIdent = 0;
            if(ROIType > FDTStudy.roiBaseRectangle && ROIType < FDTStudy.roiBaseCircle)
                %rectangle
                if(abs(ROICoord(2,2)-cp(1)) <= pixelMargin && abs(ROICoord(1,2)-cp(2)) <= pixelMargin)
                    out = 'topr';
                    numIdent = 2;
                elseif(abs(ROICoord(2,1)-cp(1)) <= pixelMargin && abs(ROICoord(1,2)-cp(2)) <= pixelMargin)
                    out = 'topl';
                    numIdent = 4;
                elseif(abs(ROICoord(2,1)-cp(1)) <= pixelMargin && abs(ROICoord(1,1)-cp(2)) <= pixelMargin)
                    out = 'botl';
                    numIdent = 6;
                elseif(abs(ROICoord(2,2)-cp(1)) <= pixelMargin && abs(ROICoord(1,1)-cp(2)) <= pixelMargin)
                    out = 'botr';
                    numIdent = 8;
                elseif(abs(ROICoord(2,1)-cp(1)) <= pixelMargin  && cp(2) >= ROICoord(1,1) && cp(2) <= ROICoord(1,2))
                    out = 'left';
                    numIdent = 5;
                elseif(abs(ROICoord(2,2)-cp(1)) <= pixelMargin  && cp(2) >= ROICoord(1,1) && cp(2) <= ROICoord(1,2))
                    out = 'right';
                    numIdent = 1;
                elseif(abs(ROICoord(1,2)-cp(2)) <= pixelMargin  && cp(1) >= ROICoord(2,1) && cp(1) <= ROICoord(2,2))
                    out = 'top';
                    numIdent = 3;
                elseif(abs(ROICoord(1,1)-cp(2)) <= pixelMargin && cp(1) >= ROICoord(2,1) && cp(1) <= ROICoord(2,2))
                    out = 'bottom';
                    numIdent = 7;
                end
            elseif(ROIType > FDTStudy.roiBaseCircle && ROIType < FDTStudy.roiBasePolygon)
                %circle
                radius = sqrt(sum((ROICoord(:,1)-ROICoord(:,2)).^2));
                center = double(ROICoord(:,1));
                angle = -pi/8:2*pi/360:pi/8;
                pointerTypes = FLIMXVisGUI.getROIBorderPointerTypes;
                for i = 1:8
                    aTmp = angle + (i-1)*pi/4;
                    pTmp = round(radius.*[sin(aTmp); cos(aTmp)]+center); %pixel coordinates
                    idxTmp = abs(cp(2) - pTmp(1,:)) <= pixelMargin;
                    hitTmp = abs(cp(1) - pTmp(2,idxTmp)) <= pixelMargin;
                    if(~isempty(hitTmp) && any(hitTmp))
                        out = pointerTypes{i};
                        numIdent = i;
                        return
                    end
                end
            elseif(ROIType > FDTStudy.roiBasePolygon && ROIType < FDTStudy.roiBaseStop)
                %polygon
                if(size(ROICoord,2) >= 1)
                    idx = abs(cp(2) - ROICoord(1,1:end)) <= pixelMargin;
                    if(any(idx) && any(abs(cp(1) - ROICoord(2,idx)) <= pixelMargin))
                        out = 'crosshair';
                        numIdent = 9;
                    end
                end
            end
        end
        
        function out = getDefaultROIStruct()
            %return default ROI struct for 1 ETDRS grid, 1 macula grid, 2 rectangles, 2 circles and 2 polygons
            out = zeros(8,3,2,'int16');
            out(:,1,1) = [1001,2001,3001,3002,4001,4002,5001,5002];
        end

        function out = getROISubtypeString(type)
            %return strings for sub ROIs
            switch upper(type)
                case 'ETDRS'
                    out = {'Central';                        
                        'Inner Superior';
                        'Inner Nasal';
                        'Inner Inferior';
                        'Inner Temporal';
                        'Outer Superior';
                        'Outer Nasal';
                        'Outer Inferior';
                        'Outer Temporal';
                        'Inner Ring';
                        'Outer Ring';
                        'Full Circle';
                        'Center + Inner Ring';
                        'Center + Outer Ring';
                        'Inner + Outer Ring';};
                case 'MACULA GRID'
                    out = {'Central Bouquet';
                        'Central';
                        'Inner Ring';
                        'Outer Ring';
                        'Slope Rod Ring';
                        'Crest Rod Ring';};
                otherwise
                    out = {''};
            end
        end
        
    end
    
end %classdef
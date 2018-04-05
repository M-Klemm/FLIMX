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
        
        roi_type_popup = [];
        roi_subtype_popup = []
        roi_invert_check = [];
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
        ROIInvertFlag = 0;
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
            out = get(this.roi_type_popup,'Value')-1;
        end
        
        function out = get.ROISubType(this)
            %get current ROI subtype
            out = get(this.roi_subtype_popup,'Value');
        end
        
        function out = get.ROIInvertFlag(this)
            %get current state of ROI invert flag
            out = get(this.roi_invert_check,'Value');
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
            switch this.ROIType
                case {2,3} %rectangles
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
            switch this.ROIType
                case 1 %ETDRS grid
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
                case {2,3} %rectangles
                    current = this.(sprintf('%s%s',target,thisEdit))(dim);
                    %increase/decrease and check for validity
                    current = this.checkBnds(dim,thisBnd,current);
                case {4,5} %circles
                    current = this.(sprintf('%s%s',target,thisEdit))(dim);
                    if(strcmp(thisBnd,'lo'))
                        other = this.(sprintf('%s%s',target,otherEdit))(dim);
                    end
            end
            set(this.(sprintf('%s_%s_edit',dim,thisBnd)),'String',current);
            if(~isempty(other))
                set(this.(sprintf('%s_%s_edit',dim,otherBnd)),'String',other);
            end
            this.save();
            this.updateGUI([]);
        end
        
        function tableEditCallback(this,eventdata)
            %callback function to edit node of current polygon
        end
        
        function buttonClearLastCallback(this)
            %callback function to clear last node of current polygon
            data = get(this.roi_table,'Data');
            if(~isempty(data) && this.ROIType >= 6 && this.ROIType <= 7)
                choice = questdlg(sprintf('Delete last node (y=%d, x=%d) of Polygon #%d ROI in subject %s?',data{1,end},data{2,end},this.ROIType-5,this.myHFD.subjectName),'Clear last Polygon ROI node?','Yes','No','No');
                switch choice
                    case 'Yes'
                        data(:,end) = [];
                        set(this.roi_table,'Data',data);
                        this.save();
                end
            end
        end
        
        function buttonClearAllCallback(this)
            %callback function to clear all nodes of current polygon
            if(this.ROIType >= 6 && this.ROIType <= 7)
                choice = questdlg(sprintf('Delete all nodes of Polygon #%d ROI in subject %s?',this.ROIType-5,this.myHFD.subjectName),'Clear all Polygon ROI nodes?','Yes','No','No');
                switch choice
                    case 'Yes'
                        set(this.roi_table,'Data',cell(2,1));
                        this.save();
                end
            end
        end
        
        function popupCallback(this,type)
            %callback function of popup to change ROI type / subtype
            this.setupGUI();
            this.updateGUI([]);
        end
        
        function setStartPoint(this,coord)
            %set coordinates(y,x) of ROI start point
            if(this.ROIType < 6)
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
            ROICoord = this.getCurROIInfo();
            ROICoord = ROICoord(:,2:end);
            if(this.ROIType < 6)
                if(isempty(coord))
                    coord = [0,0];
                end
                ROICoord(:,2) = coord;
                if(this.ROIType == 1)
                    ROICoord(:,1) = coord;
                end
            else
                ROICoord(:,end+1) = coord;
            end
            if(saveFlag)
                if(this.ROIType == 2 || this.ROIType == 3)
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
            if(saveFlag)
                if(this.ROIType == 2 || this.ROIType == 3)
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
            switch this.ROIType
                case 1 %ETDRS grid
                    set(this.roi_invert_check,'Visible','off');
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
                    set(this.roi_table_clearAll_button,'Visible','off');
                case {2,3} %rectangle
                    % set(this.roi_invert_check,'Visible','on');
                    set(this.roi_subtype_popup,'Visible','off');
                    this.enDisAble('on','on');
                    set(this.roi_table,'Visible','off');
                    set(this.roi_table_clearLast_button,'Visible','off');
                    set(this.roi_table_clearAll_button,'Visible','off');
                case {4,5} %circle
                    % set(this.roi_invert_check,'Visible','on');
                    set(this.roi_subtype_popup,'Visible','off');
                    this.enDisAble('on','on');
                    set(this.y_sz_text','Enable','off','Visible','off');
                    set(this.y_sz_edit,'Enable','off','Visible','off');
                    set(this.y_szMM_text','Enable','off','Visible','off');
                    set(this.y_szPX_text','Enable','off','Visible','off');
                    set(this.y_szMM_edit,'Enable','off','Visible','off');
                    set(this.roi_table,'Visible','off');
                    set(this.roi_table_clearLast_button,'Visible','off');
                    set(this.roi_table_clearAll_button,'Visible','off');
                case {6,7} %polygon
                    % set(this.roi_invert_check,'Visible','on');
                    set(this.roi_subtype_popup,'Visible','off');
                    set(this.roi_table,'Visible','on');
                    set(this.roi_table_clearLast_button,'Visible','on');
                    set(this.roi_table_clearAll_button,'Visible','on');
                    this.enDisAble('off','off');
                otherwise %switch to 'none'
                    set(this.roi_invert_check,'Visible','off');
                    set(this.roi_subtype_popup,'Visible','off');
                    this.enDisAble('off','off');
                    set(this.roi_table,'Visible','off');
                    set(this.roi_table_clearLast_button,'Visible','off');
                    set(this.roi_table_clearAll_button,'Visible','off');
            end
        end
        
        function updateGUI(this,ROICoord)
            %set GUI items to values from FDTree / FData object
            hfd = this.myHFD;
            if(isempty(hfd))
                return
            end
            if(isempty(ROICoord))
                ROICoord = hfd.getROICoordinates(this.ROIType);
                if(isempty(ROICoord) || ~any(ROICoord(:)))
                    if(this.ROIType < 6)
                        %ETDRS grid, rectangles, circles
                        ROICoord = [hfd.rawImgYSz; hfd.rawImgXSz];
                    else
                        ROICoord = [];
                    end
                end
                if(this.ROIType >= 6 && ~all(all(ROICoord,1)))
                    %polygons
                    ROICoord = ROICoord(:,all(ROICoord,1));
                end
            end
            fi = hfd.getFileInfoStruct();
            if(~isempty(fi))
                res = fi.pixelResolution/1000;
            else
                res = 0;%58.66666666666/1000;
                %todo: warning/error message
            end
            switch this.ROIType
                case 1 %ETDRS grid
                    set(this.y_lo_edit,'String',num2str(ROICoord(1,1)));
                    set(this.x_lo_edit,'String',num2str(ROICoord(2,1)));
                case {0,2,3} %rectangle
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
                case {4,5} %circle
                    set(this.y_lo_edit,'String',num2str(ROICoord(1,1)));
                    set(this.x_lo_edit,'String',num2str(ROICoord(2,1)));
                    set(this.y_u_edit,'String',num2str(ROICoord(1,2)));
                    set(this.x_u_edit,'String',num2str(ROICoord(2,2)));
                    d = 2*sqrt(sum((ROICoord(:,1)-ROICoord(:,2)).^2));
                    set(this.x_sz_edit,'String',FLIMXFitGUI.num4disp(d));
                    set(this.x_szMM_edit,'String',FLIMXFitGUI.num4disp(res*d));
                case {6,7} %polygon
                    set(this.roi_table,'Data',num2cell(ROICoord))
                    if(~isempty(ROICoord))
                        set(this.roi_table,'ColumnWidth',num2cell(25*ones(1,size(ROICoord,2))));
                    end
                otherwise
                    
            end
        end
        
        function out = getCurROIInfo(this)
            %get coordinates of current ROI
            %out = [invert,x1,x2]
            %      [enable,y1,y2]
            out = zeros(2,3,'int16');
            hfd = this.myHFD;
            out(1,1) = 1;
            out(2,1) = this.ROIInvertFlag;
            out(1,2) = hfd.yLbl2Pos(sscanf(get(this.y_lo_edit,'String'),'%i',1)); %sscanf(s,'%f',1);
            out(2,2) = hfd.xLbl2Pos(sscanf(get(this.x_lo_edit,'String'),'%i',1));
            if(this.ROIType == 1)
                out(:,3) = out(:,2);
            elseif(this.ROIType == 6 || this.ROIType == 7)
                out = int16([[1;this.ROIInvertFlag], cell2mat(get(this.roi_table,'Data'))]);
%                 if(size(tmp,2) < size(out,2))
%                     out(:,1:size(tmp,2)) = tmp;
%                 end
            else
                out(1,3) = hfd.yLbl2Pos(sscanf(get(this.y_u_edit,'String'),'%i',1));
                out(2,3) = hfd.xLbl2Pos(sscanf(get(this.x_u_edit,'String'),'%i',1));
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
                this.visObj.fdt.clearClusters(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),sprintf('GlobalMVGroup%s',tmp(12:end)),[]);
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
            dims =['x','y','z'];
            this.roi_type_popup = this.visObj.visHandles.(sprintf('roi_type_%s_popup',s));
            this.roi_subtype_popup = this.visObj.visHandles.(sprintf('roi_subtype_%s_popup',s));
            this.roi_invert_check = this.visObj.visHandles.(sprintf('roi_invert_%s_check',s));
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
    
end %classdef
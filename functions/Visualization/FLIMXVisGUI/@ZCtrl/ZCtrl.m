classdef ZCtrl < handle
    %=============================================================================================================
    %
    % @file     ZCtrl.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  1.0
    % @date     September, 2015
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
    % @brief    A class to handle UI controls for z-scaling in FLIMXVisGUI
    %
    properties(SetAccess = protected,GetAccess = public)
        
    end
    properties(SetAccess = protected,GetAccess = protected)
        visObj = [];
        mySide = [];
        myFDisplayL = [];
        myFDisplayR = [];
        
        z_lo_dec_button = [];
        z_lo_inc_button = [];
        z_lo_edit = [];
        z_u_dec_button = [];
        z_u_inc_button = [];
        z_u_edit = [];
        z_check = [];
        z_text = [];
        z_sz_text = [];
        z_sz_edit = [];
    end
    
    properties (Dependent = true)
        myHFD = [];
        editZlo = 0;
        editZu = 0;
        checkZ = 0;
    end
    
    methods
        function this = ZCtrl(visObj,s,FDisplayL,FDisplayR)
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
        
        function out = get.editZlo(this)
            %get value of edit field z lower
            out = str2double(get(this.z_lo_edit,'String'));
        end
        
        function out = get.editZu(this)
            %get value of edit field z upper
            out = str2double(get(this.z_u_edit,'String'));
        end
        
        function out = get.checkZ(this)
            %get value of check box 
            out = get(this.z_check,'Value');
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
            dim ='z';
            for i = 1:1
                %set(this.(sprintf('%s_check',dim(i))),'Visible',argVis);
                set(this.(sprintf('%s_lo_dec_button',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_lo_edit',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_lo_inc_button',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_text',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_u_dec_button',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_u_edit',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_u_inc_button',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_sz_text',dim(i))),'Enable',argEn,'Visible',argVis);
                set(this.(sprintf('%s_sz_edit',dim(i))),'Enable','off','Visible',argVis);
            end
        end
        
        function checkCallback(this,dim)
            %callback function of the check control
            current = get(this.(sprintf('%s_check',dim)),'Value');
            if(current)
                flag = 'on';
            else
                flag = 'off';
            end
            this.enDisAble(flag,'on');
            this.save();
            this.updateGUI([]);
        end
        
        function editCallback(this,dim,bnd)
            %callback function of the edit field
            current = str2double(get(this.(sprintf('%s_%s_edit',dim,bnd)),'String'));
            %check for validity
            current = this.checkBnds(dim,bnd,current);
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
%             switch this.ROIType
%                 case 1 %ETDRS grid
%                     switch target
%                         case 'inc'
%                             d = 1;
%                         case 'dec'
%                             d = -1;
%                     end
%                     switch dim
%                         case 'x'
%                             current = min(max(1,this.editXlo+d),hfd.rawImgXSz(2));
%                         case 'y'
%                             current = min(max(1,this.editYlo+d),hfd.rawImgXSz(2));
%                     end
%                 case {2,3} %rectangles
                    current = this.(sprintf('%s%s',target,thisEdit))(dim);
                    %increase/decrease and check for validity
                    current = this.checkBnds(dim,thisBnd,current);
            set(this.(sprintf('%s_%s_edit',dim,thisBnd)),'String',current);
            if(~isempty(other))
                set(this.(sprintf('%s_%s_edit',dim,otherBnd)),'String',other);
            end
            this.save();
            this.updateGUI([]);
        end
                                
        function setupGUI(this)
            %setup GUI controls for current ROI Type
            if(this.checkZ)
                this.enDisAble('on','on');
            else
                this.enDisAble('off','on');
            end
        end
        
        function updateGUI(this,data)
            %set GUI items to values from FDTree / FData object
            if(isempty(data))
                hfd = this.myHFD;
                if(isempty(hfd))
                    return
                end
                data = hfd.getZScaling();
                if(isempty(data) || length(data) ~= 3 || ~any(data(:)))
                    data = [0 hfd.rawImgZSz];
                end
            end            
            %[cMin, cMax, ~, ~, gMax, flag] = this.getValuesFromGUI(dim,false);
            if(data(1))
                flag = 'on';
            else
                flag = 'off';
            end
            this.enDisAble(flag,'on');
            %set edit field values
            set(this.z_check,'Value',data(1));
            set(this.z_lo_edit,'String',FLIMXFitGUI.num4disp(data(2)));
            set(this.z_u_edit,'String',FLIMXFitGUI.num4disp(data(3)));
            set(this.z_sz_edit,'String',FLIMXFitGUI.num4disp(data(3)-data(2)));
            
%             if(~data(1))
%                 %only change button behavior if ms is activated
%                 return;
%             end
%             %disable buttons if currently at min/ max
%             if(cMin == 1)
%                 %     set(o.l_dec_button,'Enable','off');
%             else
%                 set(this.(sprintf('%s_lo_dec_button',dim)),'Enable','on');
%             end
%             if(gMax == cMax)
%                 %     set(o.u_inc_button,'Enable','off');
%             else
%                 set(this.(sprintf('%s_u_inc_button',dim)),'Enable','on');
%             end
%             if(cMax == cMin)
%                 set(this.(sprintf('%s_u_inc_button',dim)),'Enable','off');
%                 set(this.(sprintf('%s_lo_dec_button',dim)),'Enable','off');
%             else
%                 set(this.(sprintf('%s_u_inc_button',dim)),'Enable','on');
%                 set(this.(sprintf('%s_lo_dec_button',dim)),'Enable','on');
%             end
        end
        
        
%         function updateCtrls(this)
%             %update manual scaling controls of all dimensions to current values
%             hfd = this.myHFD;
%             if(isempty(hfd))%|| isempty(hfd.rawImage)
%                 return
%             end
%             dim =['x','y','z'];
%             set(this.roi_type_popup,'Value',hfd.ROIType);
%             switch hfd.ROIType
%                 case 2 %AREDS grid ROI
%                     set(this.roi_subtype_popup,'Visible','on','Value',hfd.ROISubType);
%                     for i = 1:2
%                         set(this.(sprintf('%s_check',dim(i))),'Visible','on','Enable','off','Value',0);
%                         this.enDisAble(dim(i),'off','off');
%                         set(this.(sprintf('%s_lo_edit',dim(i))),'Visible','on','Enable','on');
%                         set(this.x_lo_dec_button,'Enable','on','Visible','on');
%                         set(this.x_lo_inc_button,'Enable','on','Visible','on');
%                         set(this.y_lo_dec_button,'Enable','on','Visible','on');
%                         set(this.y_lo_inc_button,'Enable','on','Visible','on');
%                     end
%                     set(this.(sprintf('%s_check',dim(3))),'Visible','on','Enable','on');
%                     this.updateCtrl(dim(3));
%                     this.setROIAnchor(hfd.ROISubTypeAnchor,false);
%                 case {3,4} %custom ROI
%                     set(this.roi_subtype_popup,'Visible','off');
%                     for i = 1:3
%                         set(this.(sprintf('%s_check',dim(i))),'Visible','on','Enable','on');
%                         this.enDisAble(dim(i),'on','on');
%                         this.updateCtrl(dim(i));
%                     end
%                 otherwise
%                     for i = 1:3
%                         
%                     end
%             end
%         end
        
%         function updateCtrl(this,dim)
%             %update manual scaling controls to current values
%             hfd = this.myHFD;
%             if(isempty(hfd))
%                 return
%             end
% %             if(hfd.ROIType == 1) %custom ROI
%                 [cMin, cMax, ~, ~, gMax, flag] = this.getValuesFromGUI(dim,false);
%                 this.enDisAble(dim,flag,'on');
%                 %set edit field values
%                 set(this.(sprintf('%s_lo_edit',dim)),'String',num2str(cMin));
%                 set(this.(sprintf('%s_u_edit',dim)),'String',num2str(cMax));
%                 set(this.(sprintf('%s_sz_edit',dim)),'String',num2str(cMax-cMin+1));
%                 %set(this.(sprintf('%s_check',dim)),'Value',flag);
%                 if(~flag)
%                     %only change button behavior if ms is activated
%                     return;
%                 end
%                 %disable buttons if currently at min/ max
%                 if(cMin == 1)
%                     %     set(o.l_dec_button,'Enable','off');
%                 else
%                     set(this.(sprintf('%s_lo_dec_button',dim)),'Enable','on');
%                 end
%                 if(gMax == cMax)
%                     %     set(o.u_inc_button,'Enable','off');
%                 else
%                     set(this.(sprintf('%s_u_inc_button',dim)),'Enable','on');
%                 end
%                 if(cMax == cMin)
%                     set(this.(sprintf('%s_u_inc_button',dim)),'Enable','off');
%                     set(this.(sprintf('%s_lo_dec_button',dim)),'Enable','off');
%                 else
%                     set(this.(sprintf('%s_u_inc_button',dim)),'Enable','on');
%                     set(this.(sprintf('%s_lo_dec_button',dim)),'Enable','on');
%                 end
% %             else
% %                 
% %             end
%         end
        
%         function out = getCurROIInfo(this)
%             %get coordinates of current ROI
%             %out = [invert,x1,x2]
%             %      [enable,y1,y2]
%             out = zeros(2,3,'int16');
%             hfd = this.myHFD;
%             out(1,1) = 1;
%             out(2,1) = this.ROIInvertFlag;
%             out(1,2) = hfd.yLbl2Pos(sscanf(get(this.y_lo_edit,'String'),'%i',1)); %sscanf(s,'%f',1);
%             out(2,2) = hfd.xLbl2Pos(sscanf(get(this.x_lo_edit,'String'),'%i',1));
%             if(this.ROIType == 1)
%                 out(:,3) = out(:,2);
%             else
%                 out(1,3) = hfd.yLbl2Pos(sscanf(get(this.y_u_edit,'String'),'%i',1));
%                 out(2,3) = hfd.xLbl2Pos(sscanf(get(this.x_u_edit,'String'),'%i',1));                
%             end
%         end
        
    end %methods
    
    methods(Access = protected)
        %internal methods
        function out = incMin(this,dim)
            %manual scaling: increase lower bound
            [cMin, ~, step, gMin, gMax] = this.getValuesFromGUI(dim);
            if(gMax < 1)
                %B&H amplitudes
                out = cMin+(gMax-gMin)*0.05;
            else
                %out = cMin+1;
                if(isempty(step))
                    out = cMin+ceil((gMax-gMin)*0.05);                    
                else
                    out = cMin+step*ceil((gMax-gMin)/step*0.05);
                end
            end
        end
        
        function out = decMin(this,dim)
            %manual scaling: decrease lower bound
            [cMin, ~, step, gMin, gMax] = this.getValuesFromGUI(dim);
            if(gMax < 1)
                %B&H amplitudes
                out = cMin-(gMax-gMin)*0.05;
            else
                %out = cMin-1;
                if(isempty(step))
                    out = cMin-ceil((gMax-gMin+1)/20);                    
                else
                    out = cMin-step*ceil((gMax-gMin+1)/step/20);
                end
            end
        end
        
        function out = incMax(this,dim)
            %manual scaling: increase lower bound
            [~, cMax, step, gMin, gMax] = this.getValuesFromGUI(dim);
            if(gMax < 1)
                %B&H amplitudes
                out = cMax+(gMax-gMin)*0.05;
            else
                %out = cMax+1;
                if(isempty(step))
                    out = cMax+ceil((gMax-gMin)*0.05);                    
                else
                    out = cMax+step*ceil((gMax-gMin)/step*0.05);
                end
            end
        end
        
        function out = decMax(this,dim)
            %manual scaling: decrease lower bound
            [~, cMax, step, gMin, gMax] = this.getValuesFromGUI(dim);
            if(gMax < 1)
                %B&H amplitudes
                out = cMax-(gMax-gMin)*0.05;
            else
                %out = cMax-1;
                if(isempty(step))
                    out = cMax-ceil((gMax-gMin+1)/20);                    
                else
                    out = cMax-step*ceil((gMax-gMin+1)/step/20);
                end
            end
        end        
        
        function [cMin, cMax, step, gMin, gMax, flag] = getValuesFromGUI(this,dim)
            %get current ROI values, output is lin or per
            cMin=0; cMax=0; step = 1; gMin=0; gMax=0; flag=0;
            hfd = this.myHFD;
            if(isempty(hfd))%|| isempty(hfd.rawImage)
                return
            end
            %get current values
            %[cMin, cMax, step] = hfd.getROIParameters(this.ROIType,dim,isMatrixPos);
%             zData = hfd.getZScaling();
%             flag = zData(1);
%             cMin = zData(2);
%             cMax = zData(3);            
            flag = this.checkZ;
            cMin = this.editZlo;
            cMax = this.editZu;
            tmp = hfd.rawImgZSz;
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
%             if((strcmp(dim,'x') || strcmp(dim,'y')) && ~isMatrixPos)
%                 gMin = hfd.xPos2Lbl(gMin);
%                 gMax = hfd.xPos2Lbl(gMax);
%             end
        end
        
        function  val = checkBnds(this,dim,bnd,val)
            %check & correct new value of lower bound for over-/ underflows; update
            [cMin, cMax, step, gMin, gMax] = this.getValuesFromGUI(dim);
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
            hfd = this.myHFD;%(sprintf('myFDisplay%s',upper(this.mySide))).gethfd();
            if(isempty(hfd))
                return
            end
            
%             ROIInfo = this.getCurROIInfo();
%             if(strncmp('ConditionMVGroup',hfd.dType,16))
%                 tmp = hfd.dType;
%                 this.visObj.fdt.clearClusters(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),sprintf('GlobalMVGroup%s',tmp(12:end)),[]);
%                 hfd.setROICoordinates(this.ROIType,ROIInfo);
%             elseif(strncmp('GlobalMVGroup',hfd.dType,13))
%                 hfd.setROICoordinates(this.ROIType,ROIInfo);
%             else
%                 this.visObj.fdt.setResultROICoordinates(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),hfd.dType,hfd.id,this.ROIType,ROIInfo);
%             end
%             if(ROIType == 1) %custom ROI
%                 if(~isempty(dim))
%                     minVal = hfd.(sprintf('%sLbl2Pos',dim))(str2double(get(this.(sprintf('%s_lo_edit',dim)),'String')));
%                     maxVal = hfd.(sprintf('%sLbl2Pos',dim))(str2double(get(this.(sprintf('%s_u_edit',dim)),'String')));
%                     check = get(this.(sprintf('%s_check',dim)),'Value');
%                 end
%                 if(strcmp(dim,'z'))
                    this.visObj.fdt.clearClusters(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),hfd.dType,hfd.id);
                    hfd.setZScaling([this.checkZ this.editZlo this.editZu]);
%                 elseif(strncmp('ConditionMVGroup',hfd.dType,16))
%                     tmp = hfd.dType;
%                     this.visObj.fdt.clearClusters(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),sprintf('GlobalMVGroup%s',tmp(12:end)),[]);
%                     hfd.setResultROICoordinates(dim,[check minVal maxVal]);
%                 elseif(strncmp('GlobalMVGroup',hfd.dType,13))
%                     hfd.setResultROICoordinates(dim,[check minVal maxVal]);
%                 elseif(hfd.globalScale && isempty(dim))
%                     
%                 elseif(hfd.globalScale && ~isempty(dim))
%                     this.visObj.fdt.setResultROICoordinates(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),hfd.dType,hfd.id,dim,[check minVal maxVal]);
%                 else
%                     hfd.setROIVec(dim,[check minVal maxVal]);
%                 end                
%             end
        end
        
        function setUIHandles(this)
            %builds the uicontrol handles for the ROICtrl object for axis ax
            s = this.mySide;
            dims ='z';
            for i=1:1
                dim = dims(i);
                this.(sprintf('%s_lo_dec_button',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_lo_dec_button',s,dim));
                this.(sprintf('%s_lo_inc_button',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_lo_inc_button',s,dim));
                this.(sprintf('%s_lo_edit',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_lo_edit',s,dim));
                this.(sprintf('%s_u_dec_button',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_u_dec_button',s,dim));
                this.(sprintf('%s_u_inc_button',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_u_inc_button',s,dim));
                this.(sprintf('%s_u_edit',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_u_edit',s,dim));
                this.(sprintf('%s_check',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_check',s,dim));
                this.(sprintf('%s_text',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_text',s,dim));
                this.(sprintf('%s_sz_text',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_sz_text',s,dim));
                this.(sprintf('%s_sz_edit',dim)) = this.visObj.visHandles.(sprintf('ms_%s_%s_sz_edit',s,dim));
            end
        end
    end %methods protected
    
end %classdef
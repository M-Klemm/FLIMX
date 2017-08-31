classdef ColorCtrl < handle
    %=============================================================================================================
    %
    % @file     ColorCtrl.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  1.0
    % @date     May, 2017
    %
    % @section  LICENSE
    %
    % Copyright (C) 2017, Matthias Klemm. All rights reserved.
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
    % @brief    A class to handle UI controls for color-scaling in FLIMXVisGUI
    %
    properties(SetAccess = protected,GetAccess = public)
        
    end
    properties(SetAccess = protected,GetAccess = protected)
        visObj = [];
        mySide = [];
        myFDisplay = [];
        
        auto_check = [];
        zoom_in_button = [];
        zoom_out_button = [];
        low_edit = [];
        high_edit = [];
    end
    
    properties (Dependent = true)
        myHFD = [];
        editLow = 0;
        editHigh = 0;
        check = 0;
        curHistCenters = [];
    end
    
    methods
        function this = ColorCtrl(visObj,s,myFDisplay)
            % Constructor for Scale.
            this.visObj = visObj;
            this.mySide = s;
            this.myFDisplay = myFDisplay;
            this.setUIHandles();
            this.setupGUI();
        end
        
        function out = get.myHFD(this)
            %get handle to FData object
            out = this.myFDisplay.gethfd();
            out = out{1};
        end
        
        function out = get.editLow(this)
            %get value of edit field lower
            out = str2double(get(this.low_edit,'String'));
        end
        
        function out = get.editHigh(this)
            %get value of edit field upper
            out = str2double(get(this.high_edit,'String'));
        end
        
        function out = get.check(this)
            %get value of check box 
            out = get(this.auto_check,'Value');
        end
        
        function centers = get.curHistCenters(this)
            %get current histogram centers
            hfd = this.myHFD;
            if(isempty(hfd))
                centers = [];
                return
            end
            rc = this.myFDisplay.ROICoordinates;
            rt = this.myFDisplay.ROIType;
            rs = this.myFDisplay.ROISubType;
            ri = this.myFDisplay.ROIInvertFlag;
            [~, centers] = hfd.getCIHist(rc,rt,rs,ri);
        end
        
        function enDisAble(this,argEn,argVis)
            %enable/ disable color scaling controls
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
            set(this.low_edit,'Enable',argEn,'Visible',argVis);
            set(this.high_edit,'Enable',argEn,'Visible',argVis);
            set(this.zoom_in_button,'Enable',argEn,'Visible',argVis);
            set(this.zoom_out_button,'Enable',argEn,'Visible',argVis);
        end
        
        function checkCallback(this)
            %callback function of the check control
            if(this.check)
                this.updateGUI(this.getAutoScale());
            else
                this.enDisAble('on','on');
            end
            this.save();
        end
        
        function editCallback(this)
            %callback function of the edit field
            this.setColorScale(this.getCurCSInfo(),false);
        end
        
        function forceAutoScale(this)
            %switch on auto scale
            set(this.auto_check,'Value',1);
            this.checkCallback();
        end
        
        function setLowerBorder(this,val,isHistClassNr)
            %set lower border
            if(isHistClassNr)
                centers = this.curHistCenters;
                val = centers(max(1,min(length(centers),val)));
            end
            set(this.low_edit,'String',FLIMXFitGUI.num4disp(val));
            this.editCallback();
        end
        
        function setColorScale(this,cs,isHistClassNr)
            %set color scaling to new value and update GUI
            cs = single(cs);
            if(isHistClassNr)
                centers = single(this.curHistCenters);
                cs(2) = centers(max(1,min(length(centers),cs(2))));
                cs(3) = centers(max(1,min(length(centers),cs(3))));
            end
            cs(2:3) = sort(cs(2:3));
            this.updateGUI(cs);
            this.save();
        end
        
        function buttonCallback(this,target)
            %callback function of an zoom in/zoom out (=target) button
            hfd = this.myHFD;
            if(isempty(hfd))
                return
            end
            cs = this.getCurCSInfo();
            range = (cs(3)-cs(2))/2;
            center = cs(2) + range;
            histCenters = this.curHistCenters();            
            if(strcmpi(target,'in'))
                %range = range*0.8;
            else
                range = range*5/4;
                cs(2) = center-range;
                cs(3) = center+range;                                
            end
            [~,startClass] = min(abs(histCenters-cs(2)));
            [~,endClass] = min(abs(histCenters-cs(3)));
            this.myFDisplay.setSuppXScale(startClass,endClass);
            %this.updateGUI(cs);
            %this.save();
        end
        
        function out = getCurCSInfo(this)
            %get color scaling info from GUI
            %out = [auto,low,high]
            out = zeros(1,3,'single');
            out(1,1) = single(this.check);
            out(1,2) = single(this.editLow);
            out(1,3) = single(this.editHigh);
        end
                                
        function setupGUI(this)
            %setup GUI controls
            if(this.myFDisplay.sDispMode == 2)
                if(~this.check)
                    this.enDisAble('on','on');
                else
                    this.enDisAble('off','on');
                end
            else
                this.enDisAble('off','off');
            end
        end
        
        function updateGUI(this,data)
            %update GUI with values from data - if empty use data from FDTree
            %persistent inFunction          
            %if(~isempty(inFunction)), return; end
            if(~isMultipleCall())
                %inFunction = 1;
                if(isempty(data))
                    %set GUI items to values from FDTree / FData object
                    hfd = this.myHFD;
                    if(isempty(hfd))
                        inFunction = [];
                        return
                    end
                    data = hfd.getColorScaling();
                    if(isempty(data) || length(data) ~= 3 || ~any(data(:)))
                        data = this.getAutoScale();
                    end
                end
                if(data(1))
                    flag = 'off';
                else
                    flag = 'on';
                end
                this.enDisAble(flag,'on');
                %set edit field values
                set(this.auto_check,'Value',data(1));
                set(this.low_edit,'String',FLIMXFitGUI.num4disp(data(2)));
                set(this.high_edit,'String',FLIMXFitGUI.num4disp(data(3)));
                this.myFDisplay.updatePlots();
            end
            %inFunction = [];
        end
        
        function out = getAutoScale(this)
            %compute border for auto scale color
            hfd = this.myHFD;
            out = ones(1,3);
            if(isempty(hfd))                
                return
            end
            rc = this.myFDisplay.ROICoordinates;
            rt = this.myFDisplay.ROIType;
            rs = this.myFDisplay.ROISubType;
            ri = this.myFDisplay.ROIInvertFlag;
            data = hfd.getROIImage(rc,rt,rs,ri);
            if(strcmp(hfd.dType,'Intensity'))
                out(2) = prctile(data(:),this.visObj.generalParams.cmIntensityPercentileLB);
                out(3) = prctile(data(:),this.visObj.generalParams.cmIntensityPercentileUB);
            else
                out(2) = prctile(data(:),this.visObj.generalParams.cmPercentileLB);
                out(3) = prctile(data(:),this.visObj.generalParams.cmPercentileUB);
            end
        end
        
    end %methods
    
    methods(Access = protected)
        %internal methods
        function out = incMin(this,dim)
            %manual scaling: increase lower bound
            [cMin, ~, step, gMin, gMax] = this.getCurCSInfo(dim);
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
            [cMin, ~, step, gMin, gMax] = this.getCurCSInfo(dim);
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
            [~, cMax, step, gMin, gMax] = this.getCurCSInfo(dim);
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
            [~, cMax, step, gMin, gMax] = this.getCurCSInfo(dim);
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
                
        function  val = checkBnds(this,val)
            %check & correct new value of lower bound for over-/ underflows; update
            guiVals = this.getCurCSInfo();
            if(isnan(val))
                val = 1;
            end
%             switch bnd
%                 case 'lo'
%                     if(val > high) %overflow
%                         if(isempty(step))
%                             val = high-(gMax-gMin)*0.05;
%                         else
%                             val = high-ceil((gMax-gMin)*0.05)*step;
%                         end
%                     end
%                 case 'u'
%                     if(val < low) %underflow
%                         if(isempty(step))
%                             val = low+(gMax-gMin)*0.05;
%                         else
%                             val = high+ceil((gMax-gMin)*0.05)*step;
%                         end
%                     end
%             end
        end
        
        function save(this)
            %update FData objects
            hfd = this.myHFD;
            if(isempty(hfd))
                return
            end
            if(strncmp('ConditionMVGroup',hfd.dType,16))
                %tmp = hfd.dType;
                %this.visObj.fdt.clearClusters(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),sprintf('GlobalMVGroup%s',tmp(12:end)),[]);
                hfd.setResultColorScaling(this.getCurCSInfo());
            elseif(strncmp('GlobalMVGroup',hfd.dType,13))
                hfd.setResultColorScaling(this.getCurCSInfo());
            else
                this.visObj.fdt.setResultColorScaling(this.visObj.getStudy(this.mySide),this.visObj.getSubject(this.mySide),this.visObj.getChannel(this.mySide),hfd.dType,hfd.id,this.getCurCSInfo());
                %hfd.clearFilteredImage();
            end
        end
        
        function setUIHandles(this)
            %builds the uicontrol handles for the ROICtrl object for axis ax
            s = this.mySide;
            this.auto_check = this.visObj.visHandles.(sprintf('colormap_auto_%s_check',s));
            this.low_edit = this.visObj.visHandles.(sprintf('colormap_low_%s_edit',s));
            this.high_edit = this.visObj.visHandles.(sprintf('colormap_high_%s_edit',s));            
            this.zoom_in_button = this.visObj.visHandles.(sprintf('colormap_zoom_in_%s_button',s));
            this.zoom_out_button = this.visObj.visHandles.(sprintf('colormap_zoom_out_%s_button',s));
        end
    end %methods protected
    
end %classdef
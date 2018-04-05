classdef CutCtrl < handle
    %=============================================================================================================
    %
    % @file     CutCtrl.m
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
    % @brief    A class to handle UI controls to set cross-sections in FLIMXVisGUI
    %
    properties(SetAccess = protected,GetAccess = public)
        
    end
    properties(SetAccess = protected,GetAccess = protected)
        visObj = [];
        myAxis = [];
        myFDisplayL = [];
        myFDisplayR = [];
        check = [];
        slider = [];
        edit = [];
        inv = [];
        minText = [];
        maxText = [];
        infoText = [];
    end
    
    properties (Dependent = true)
        ROICoordinates = [];
        ROIType = 0;
        ROISubType = 0;
        ROIInvertFlag = 0;
    end

    methods
        function this = CutCtrl(visObj,axis,FDisplayL,FDisplayR)
            % Constructor for Scale.
            this.visObj = visObj;
            this.myAxis = axis;
            this.myFDisplayL = FDisplayL;
            this.myFDisplayR = FDisplayR;
            this.setUIHandles();
        end
        
        function enDisAble(this,arg)
            %enable/ disable manual scaling controls for dimension dim
            if(~ischar(arg))
                if(arg)
                    arg = 'on';
                else
                    arg = 'off';
                end
            end
            set(this.slider,'Visible',arg);
            set(this.edit,'Visible',arg);
            set(this.inv,'Visible',arg);
            set(this.minText,'Visible',arg);
            set(this.maxText,'Visible',arg);
            set(this.infoText,'Visible',arg);
        end
        
        function checkCallback(this)
            %callback function of the check control
            this.updateFD();
            this.updateCtrls();
        end
        
        function editCallback(this)
            %callback function of the edit field
            %check for validity
            current = round(str2double(get(this.edit,'String')));
            [~, minVal, maxVal] = this.getCurValMaxInv();
            current = max(min(current,maxVal),minVal); 
            set(this.edit,'String',num2str(current));
            set(this.slider,'Value',current);
            this.updateFD(); 
        end
        
        function sliderCallback(this)
            %callback function from the slider
            set(this.edit,'String',num2str(round(get(this.slider,'Value'))));
            this.updateFD();
            this.updateCtrls();
        end
        
        function updateCtrls(this)
            %updates cuts controls to current values
            [cur minVal maxVal step iFlag eFlag] = this.getCurValMaxInv();
            set(this.slider,'Min',minVal,'Max',maxVal,'Value',cur,'Sliderstep',[step/(maxVal-minVal) 0.1]); %step/(maxVal-minVal+1)
            set(this.minText,'String',num2str(minVal));
            set(this.maxText,'String',num2str(maxVal));
            set(this.edit,'String',num2str(cur));
            set(this.check,'Value',eFlag);
            set(this.inv,'Value',iFlag);
            this.enDisAble(eFlag);
        end
        
        function [cur minVal maxVal step iFlag eFlag] = getCurValMaxInv(this)
            %get max allowed value for cuts
            cur = 0; iFlag = 0; minVal = 0; maxVal = 1; step = 1; eFlag = 0;
            hfd = this.myFDisplayL.gethfd();
            hfd = hfd{1};
            if(isempty(hfd) || isempty(hfd.rawImage))
                return
            end
            if(this.visObj.getROIDisplayMode('l') == 1)
                tmp = hfd.(sprintf('rawImg%sSz',upper(this.myAxis)));
                minVal = tmp(1);
                maxVal = tmp(2);
            else
                [minVal, maxVal] = hfd.(sprintf('getCrossSection%sBorders',upper(this.myAxis)))(this.ROICoordinates,this.ROIType,this.ROISubType,this.ROIInvertFlag);
            end
            minVal = double(minVal);
            maxVal = double(maxVal);
            step = hfd.(sprintf('get%sLblTick',upper(this.myAxis)));
            eFlag = hfd.(sprintf('getCrossSection%s',upper(this.myAxis)));
            iFlag = hfd.(sprintf('getCrossSection%sInv',upper(this.myAxis)));
            cur = hfd.(sprintf('getCrossSection%sVal',upper(this.myAxis)))(false,false,this.ROICoordinates,this.ROIType,this.ROISubType,this.ROIInvertFlag);
            %check borders
            cur = max(min(cur,maxVal),minVal);
        end
        
        function out = get.ROICoordinates(this)
            %get current ROI type
            out = this.visObj.getROICoordinates('l');
        end          
        
        function out = get.ROIType(this)
            %get current ROI type
            out = this.visObj.getROIType('l');
        end        
        
        function out = get.ROISubType(this)
            %get current ROI subtype
            out = this.visObj.getROISubType('l');
        end
        
        function out = get.ROIInvertFlag(this)
            %get current state of ROI invert flag
            out = this.visObj.getROIInvertFlag('l');
        end
        
    end %methods 
            
    methods(Access = protected)
        %internal methods
        function updateFD(this)
            %update FData objects
            hfd = this.myFDisplayL.gethfd();
            hfd = hfd{1}; 
            if(isempty(hfd) || isempty(hfd.rawImage))
                return
            end            
            %make sure cut value is a matrix position
            val = hfd.(sprintf('%sLbl2Pos',this.myAxis))(round(get(this.slider,'Value')));
            if(hfd.globalScale)
                this.visObj.fdt.setResultCrossSection(this.visObj.getStudy('l'),this.visObj.getSubject('l'),this.myAxis,[get(this.check,'Value') val get(this.inv,'Value')]);
            else
                hfd.setResultCrossSection(this.myAxis,[get(this.check,'Value') val get(this.inv,'Value')]);
                end
            end
                
        function setUIHandles(this)
            %builds the uicontrol handles for the CutCtrl object for axis ax
            ax = this.myAxis;
            this.slider = this.visObj.visHandles.(sprintf('cut_%s_l_slider',ax));
            this.check = this.visObj.visHandles.(sprintf('cut_%s_l_check',ax));
            this.edit = this.visObj.visHandles.(sprintf('cut_%s_l_edit',ax));
            this.inv = this.visObj.visHandles.(sprintf('cut_%s_inv_check',ax)); 
            this.minText = this.visObj.visHandles.(sprintf('cut_%s_min_l_text',ax));
            this.maxText = this.visObj.visHandles.(sprintf('cut_%s_max_l_text',ax));
            this.infoText = this.visObj.visHandles.(sprintf('cut_%s_l_text',ax));
        end
    end %methods protected
    
end %classdef
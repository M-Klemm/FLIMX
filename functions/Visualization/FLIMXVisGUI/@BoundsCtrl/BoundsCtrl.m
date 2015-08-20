classdef BoundsCtrl < handle
    %=============================================================================================================
    %
    % @file     BoundsCtrl.m
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
    % @brief    A class to handle UI controls for parameter bounds in FLIMXVisGUI's statistics options GUI
    %
    properties(SetAccess = protected,GetAccess = public)
        myParent = [];
        myTarget = [];
        myQuantization = 0; %0: no quantization
        myBoundsValues = [0; 100];
        myBoundsInitial = [0; 100]; %typical (soft) or hard bounds
        myBoundsFlags = [0; 0]; %1: hard bound, 0: soft bound
        myBoundsStatus = [0]; %bounds enabled or disabled
        currentChannel = 1;        
        isInitialized = false; %true if handles are set
        lo_dec_button = [];
        lo_inc_button = [];
        lo_edit = [];
        hi_dec_button = [];
        hi_inc_button = [];
        hi_edit = [];
        check = [];
        text = []; 
    end
    properties(SetAccess = protected,GetAccess = protected)
               
    end

    methods        
        function this = BoundsCtrl(parent,target)
            %constructor for BoundsCtrl
            this.myParent = parent;
            this.myTarget = target;
        end
        
        function setCurrentChannel(this,val)
            %set current channel (no checks of value yet)
            this.currentChannel = max(1,abs(val));
            set(this.lo_edit,'String',num2str(this.myBoundsValues(1,val)));
            set(this.hi_edit,'String',num2str(this.myBoundsValues(2,val)));
            set(this.check,'Value',this.myBoundsStatus(val));
            this.updateCtrls();
        end
        
        function this = setBounds(this,values)
            %set bounds
            if(size(values,1) ~= 2)
                return
            end
            this.myBoundsInitial = values;
            this.myBoundsValues = values;
            set(this.lo_edit,'String',num2str(values(1,this.currentChannel)));
            set(this.hi_edit,'String',num2str(values(2,this.currentChannel)));
            this.updateCtrls();
        end
        
        function setStatus(this,flag)
            %set on/off status
            this.myBoundsStatus = flag;
            if(flag(this.currentChannel))
                set(this.check,'Value',1)
            else
                set(this.check,'Value',0)
            end
            this.enDisAble(flag(this.currentChannel));
        end
        
        function setQuantization(this,quant)
            %set quantization
            if(length(quant) ~= size(this.myBoundsInitial,2))
                quant = repmat(quant,1,size(this.myBoundsInitial,2));
            end
            this.myQuantization = quant;
            this.updateCtrls();
        end
        
        function check_Callback(this,hObject,eventdata)
            %callback function of the check control
            this.myBoundsStatus(this.currentChannel) = get(hObject,'Value');
            this.enDisAble(get(hObject,'Value'));
            this.updateCtrls();
        end
        
        function editLo_Callback(this,hObject,eventdata)
            %callback function of the lower edit field            
            %check for validity
            current = this.checkBnds('lo',str2double(get(hObject,'String')));
            set(hObject,'String',num2str(current));
            this.myBoundsValues(1,this.currentChannel) = current;
            this.updateCtrls();
        end
        
        function editHi_Callback(this,hObject,eventdata)
            %callback function of the lower edit field            
            %check for validity
            current = this.checkBnds('hi',str2double(get(hObject,'String')));
            set(hObject,'String',num2str(current));
            this.myBoundsValues(2,this.currentChannel) = current;
            this.updateCtrls();
        end
        
        function buttonLoDec_Callback(this,hObject,eventdata)
            %callback function of an increase/decrease button
            %check for validity
            current = this.checkBnds('lo',this.decMin());
            set(this.lo_edit,'String',num2str(current));
            this.myBoundsValues(1,this.currentChannel) = current;
            this.updateCtrls();
        end
        
        function buttonLoInc_Callback(this,hObject,eventdata)
            %callback function of an increase/decrease button
            %check for validity
            current = this.checkBnds('lo',this.incMin());
            set(this.lo_edit,'String',num2str(current));
            this.myBoundsValues(1,this.currentChannel) = current;
            this.updateCtrls();
        end
        
        function buttonHiDec_Callback(this,hObject,eventdata)
            %callback function of an increase/decrease button
            %check for validity
            current = this.checkBnds('hi',this.decMax());
            set(this.hi_edit,'String',num2str(current));
            this.myBoundsValues(2,this.currentChannel) = current;
            this.updateCtrls();
        end
        
        function buttonHiInc_Callback(this,hObject,eventdata)
            %callback function of an increase/decrease button
            %check for validity
            current = this.checkBnds('hi',this.incMax());
            set(this.hi_edit,'String',num2str(current));
            this.myBoundsValues(2,this.currentChannel) = current;
            this.updateCtrls();
        end
        
        function updateCtrls(this)
            %update manual scaling controls to current values
            [cMin, cMax, gMin, gMax, flag] = this.getCurVals();
            
            this.enDisAble(flag);
            %set edit field values
            set(this.lo_edit,'String',num2str(this.checkBnds('lo',cMin)));
            set(this.hi_edit,'String',num2str(this.checkBnds('hi',cMax)));
            set(this.check,'Value',flag); 
            if(~flag)
                %only change button behavier if ms is activated
                return;
            end
            %disable buttons if currently at min/ max 
            if(cMin == gMin && this.myBoundsFlags(1))
                set(this.l_dec_button,'Enable','off');
            else
                set(this.lo_dec_button,'Enable','on');
            end
            if(gMax == cMax && this.myBoundsFlags(2))
                set(this.hi_inc_button,'Enable','off');
            else
                set(this.hi_inc_button,'Enable','on');
            end
            if(cMax == cMin)
                set(this.hi_dec_button,'Enable','off');
                set(this.lo_inc_button,'Enable','off');
            else
                set(this.hi_dec_button,'Enable','on');
                set(this.lo_inc_button,'Enable','on');
            end
        end
        
        function [cMin, cMax, gMin, gMax, flag] = getCurVals(this)
            %get current values
            flag = get(this.check,'Value');
            cMin = str2double(get(this.lo_edit,'String'));
            cMax = str2double(get(this.hi_edit,'String'));
            gMin = this.myBoundsInitial(1,this.currentChannel);
            gMax = this.myBoundsInitial(2,this.currentChannel);               
        end
        
        function enDisAble(this,arg)
            %enable/ disable manual scaling controls
            if(isnumeric(arg))
                if(arg == 1)
                    arg = 'on';
                else
                    arg = 'off';
                end
            end
            set(this.lo_dec_button,'Enable',arg);
            set(this.lo_edit,'Enable',arg);
            set(this.lo_inc_button,'Enable',arg);
            set(this.text,'Enable',arg);
            set(this.hi_dec_button,'Enable',arg);
            set(this.hi_edit,'Enable',arg);
            set(this.hi_inc_button,'Enable',arg);
        end 
        
        function setUIHandles(this)
            %builds the uicontrol handles
            this.lo_dec_button = this.myParent.visHandles.(sprintf('%s_lo_dec_button',this.myTarget));
            set(this.myParent.visHandles.(sprintf('%s_lo_dec_button',this.myTarget)),'Callback',@this.buttonLoDec_Callback);
            this.lo_inc_button = this.myParent.visHandles.(sprintf('%s_lo_inc_button',this.myTarget));
            set(this.myParent.visHandles.(sprintf('%s_lo_inc_button',this.myTarget)),'Callback',@this.buttonLoInc_Callback);
            this.lo_edit = this.myParent.visHandles.(sprintf('%s_lo_edit',this.myTarget));
            set(this.myParent.visHandles.(sprintf('%s_lo_edit',this.myTarget)),'Callback',@this.editLo_Callback);
            this.hi_dec_button = this.myParent.visHandles.(sprintf('%s_hi_dec_button',this.myTarget));
            set(this.myParent.visHandles.(sprintf('%s_hi_dec_button',this.myTarget)),'Callback',@this.buttonHiDec_Callback);
            this.hi_inc_button = this.myParent.visHandles.(sprintf('%s_hi_inc_button',this.myTarget));
            set(this.myParent.visHandles.(sprintf('%s_hi_inc_button',this.myTarget)),'Callback',@this.buttonHiInc_Callback);
            this.hi_edit = this.myParent.visHandles.(sprintf('%s_hi_edit',this.myTarget));
            set(this.myParent.visHandles.(sprintf('%s_hi_edit',this.myTarget)),'Callback',@this.editHi_Callback);
            this.check = this.myParent.visHandles.(sprintf('%s_check',this.myTarget));
            set(this.myParent.visHandles.(sprintf('%s_check',this.myTarget)),'Callback',@this.check_Callback);
            this.text = this.myParent.visHandles.(sprintf('%s_text',this.myTarget));
            this.isInitialized = true;
        end
             
    end %methods
    
    methods(Access = protected)
        %internal methods
        function out = incMin(this)
            %increase lower bound
            [cMin, ~, gMin, gMax] = this.getCurVals();
            if(this.myQuantization(this.currentChannel))
                out = cMin+this.myQuantization(this.currentChannel);
            else
                if(gMax < 1)
                    %B&H amplitudes
                    out = cMin+(gMax-gMin)*0.05;
                else
                    out = cMin+ceil((gMax-gMin)*0.05);
                end
            end
        end
        
        function out = decMin(this)
            %decrease lower bound
            [cMin, ~, gMin, gMax] = this.getCurVals();
            if(this.myQuantization(this.currentChannel))
                out = cMin-this.myQuantization(this.currentChannel);
            else
                if(gMax < 1)
                    %B&H amplitudes
                    out = cMin-(gMax-gMin)*0.05;
                else
                    out = cMin-ceil((gMax-gMin)*0.05);
                end
            end
        end
        
        function out = incMax(this)
            %increase lower bound
            [~, cMax, gMin, gMax] = this.getCurVals();
            if(this.myQuantization(this.currentChannel))
                out = cMax+this.myQuantization(this.currentChannel);
            else
                if(gMax < 1)
                    %B&H amplitudes
                    out = cMax+(gMax-gMin)*0.05;
                else
                    out = cMax+ceil((gMax-gMin)*0.05);
                end
            end
        end
        
        function out = decMax(this)
            %decrease lower bound
            [~, cMax, gMin, gMax] = this.getCurVals();
            if(this.myQuantization(this.currentChannel))
                out = cMax-this.myQuantization(this.currentChannel);
            else
                if(gMax < 1)
                    %B&H amplitudes
                    out = cMax-(gMax-gMin)*0.05;
                else
                    out = cMax-ceil((gMax-gMin)*0.05);
                end
            end
        end   
        
        function  val = checkBnds(this,bnd,val)
            %check & correct new value of lower bound for over-/ underflows; update
            [cMin, cMax, gMin, gMax] = this.getCurVals();
            if(isnan(val))
                val = 1;
            end
            switch bnd
                case 'lo'                    
                    if(val >= cMax) %overflow
                        val = cMax-(gMax-gMin)*0.05;
                    end
                    if(this.myBoundsFlags(1) && val > gMin)
                        val = gMin;
                    end
                    %if(this.myQuantization)
%                         val = checkQuantization(val,this.myQuantization,gMin);
                    %end
                case 'hi'                    
                    if(val <= cMin) %underflow
                        val = cMin+(gMax-gMin)*0.05;
                    end
                    if(this.myBoundsFlags(2) && val > gMax)
                        val = gMax;
                    end
                    if(this.myQuantization(this.currentChannel))
                        val = checkQuantization(val,this.myQuantization(this.currentChannel),cMin);
                    end
            end
        end
    end %methods protected
    
end %classdef
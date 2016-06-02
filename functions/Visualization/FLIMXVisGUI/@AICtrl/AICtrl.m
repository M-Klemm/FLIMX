classdef AICtrl < handle
    %=============================================================================================================
    %
    % @file     AICtrl.m
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
    % @brief    A class to handle UI controls for arithmetic images FLIMXVisGUI
    %
    properties(SetAccess = protected,GetAccess = public)
        
    end
    properties(SetAccess = protected,GetAccess = protected)
        visObj = [];
        FLIMItemA = [];
        FLIMItemB = [];
        normalizeA = [];
        normalizeB = [];
        combi = [];
        combiText = [];
        chA = [];
        chB = [];
        opA = [];
        opB = [];
        opBText = [];
        valA = [];
        valAText = [];
        valB = [];
        valBText = [];
        valRadio = [];
        FLIMItemRadio = [];
        aiSel = [];
        newButton = [];
        delButton = [];
    end
    
    properties (Dependent = true)
        curStudy = '',
        curAIName = '';
    end
    
    methods
        function this = AICtrl(visObj,axis,FDisplayL,FDisplayR)
            % Constructor for AICtrl.
            this.visObj = visObj;
            this.setUIHandles();
            oStr = {'+','-','.*','./','<','>','<=','>=','==','!=','AND','OR','!AND','!OR','XOR'};
            cStr = {'-','AND','OR','!AND','!OR','XOR'};
            set(this.opA,'String',oStr,'Value',1);
            set(this.opB,'String',oStr(1:10),'Value',1);
            set(this.combi,'String',cStr,'Value',1);
        end
        
        function inVisible(this,param)
            %show / hide controls
            if(~ischar(param))
                if(param)
                    param = 'on';
                else
                    param = 'off';
                end
            end
            set(this.FLIMItemA,'Visible',param);
            set(this.FLIMItemB,'Visible',param);
            set(this.normalizeA,'Visible',param);
            set(this.normalizeB,'Visible',param);
            set(this.combi,'Visible',param);
            set(this.chA,'Visible',param);
            set(this.chB,'Visible',param);
            set(this.opA,'Visible',param);
            set(this.opB,'Visible',param);
            set(this.valA,'Visible',param);
            set(this.valB,'Visible',param);
            set(this.valRadio,'Visible',param);
            set(this.FLIMItemRadio,'Visible',param);
            set(this.delButton,'Visible',param);
        end
        
        function new_Callback(this,hObject,eventdata)
            %user wants a new arithmetic image
            %get arithmetic images for current study
            oldNames = this.visObj.fdt.getArithmeticImage(this.curStudy);
            while(true)
                [settings, button] = settingsdlg(...
                    'Description', 'Enter a unique for the arithmetic image.',...
                    'title'      , 'Arithmetic Image Name',...
                    'Name', 'arithmImg');
                if(strcmp(button,'cancel'))
                    return
                end
                if(isempty(find(strcmp(settings.Name,oldNames), 1)))
                    break
                end
            end
            %we got a new name, update all GUI controls
            this.visObj.fdt.setArithmeticImage(this.curStudy,settings.Name,this.getDefStruct);
            this.updateCtrls();
            set(this.aiSel,'Value',length(oldNames)+1);%new ai is at the end
            this.updateCtrls();
            this.visObj.setupGUI();
        end
        
        function edit_Callback(this,hObject,eventdata)
            %rename arithmetic image
            
        end
        
        function del_Callback(this,hObject,eventdata)
            %delete arithmetic image
            this.visObj.fdt.removeArithmeticImage(this.curStudy,this.curAIName);
            this.updateCtrls();
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
        end
        
        function ui_Callback(this,hObject,eventdata)
            %user changed a parameter of the current arithmetic image
            if(hObject == this.valA || hObject == this.valB)
                set(hObject,'String',str2double(get(hObject,'String')));
            end
            if(hObject ~= this.visObj.visHandles.ai_sel_pop)
                this.visObj.fdt.setArithmeticImage(this.curStudy,this.curAIName,this.getCurAIParams());
            end
            this.updateCtrls();
            this.visObj.updateGUI([]);
        end
        
        function updateCtrls(this)
            %updates controls to current values
            %get arithmetic images for current study
            [aiStr, aiParam] = this.visObj.fdt.getArithmeticImage(this.curStudy);
            idx = min(length(aiStr),get(this.aiSel,'Value'));
            if(length(aiStr) < idx || isempty(aiStr{idx}))
                %hide controls
                set(this.aiSel,'String','-none-','Value',1);
                this.inVisible('off');
                return
            end            
            set(this.aiSel,'String',aiStr,'Value',idx);
            this.inVisible('on');
            subject = this.visObj.getSubject('l');
            chStr = [{'all Ch'}; this.visObj.fdt.getChStr(this.curStudy,subject)];
            %find saved channel
            if(aiParam{idx}.chA == 0)
                chNr = 0;
            else
                chNr = find(strcmp(sprintf('Ch %d',aiParam{idx}.chA),chStr))-1;
            end
            if(isempty(chNr))
                %Houston we've got a problem
                %make warning dialog to switch subject?!
                return
            end
            set(this.chA,'String',chStr,'Value',chNr+1);
            chObj = this.visObj.fdt.getChObjStr(this.curStudy,subject,max(1,chNr));
            %remove current arithmetic image from channel objects
            chObj = chObj(~strcmp(chObj,this.curAIName));
            %second flim item channel
            if(aiParam{idx}.chB == 0)
                chNr = 0;
            else
                chNr = find(strcmp(sprintf('Ch %d',aiParam{idx}.chB+1),chStr))-1;
            end
            if(isempty(chNr))
                %Houston we've got a problem
                %make warning dialog to switch subject?!
                return
            end
            set(this.chB,'String',chStr,'Value',chNr+1);            
            %find saved FLIM item
            fiNr = find(strcmp(aiParam{idx}.FLIMItemA,chObj));
            if(isempty(fiNr))
                %Houston we've got a problem
                %make warning dialog to switch subject?!
                fiNr = 1;
            end
            set(this.FLIMItemA,'String',chObj,'Value',fiNr);
            %second flim item channel
            chObj = this.visObj.fdt.getChObjStr(this.curStudy,subject,max(1,chNr));
            %remove current arithmetic image from channel objects
            chObj = chObj(~strcmp(chObj,this.curAIName));
            fiNr = find(strcmp(aiParam{idx}.FLIMItemB,chObj));
            if(isempty(fiNr))
                %Houston we've got a problem
                %make warning dialog to switch subject?!
                fiNr = 1;
            end
            
            set(this.FLIMItemB,'String',chObj,'Value',fiNr);
            opNr = find(strcmp(aiParam{idx}.opA,get(this.opA,'String')));
            if(isempty(opNr))                
                %Houston we've got a problem
                %make warning dialog?!
                opNr = 1;
            end
            set(this.opA,'Value',opNr);
            set(this.normalizeA,'Value',aiParam{idx}.normalizeA);
            set(this.normalizeB,'Value',aiParam{idx}.normalizeB);
            switch aiParam{idx}.compAgainst
                case 'val'
                    set(this.valRadio,'Value',1);
                    set(this.FLIMItemRadio,'Value',0);
                    set(this.FLIMItemB,'Enable','off');
                    set(this.chB,'Enable','off');
                    set(this.valA,'Enable','on','String',aiParam{idx}.valA);
                    set(this.valAText,'Visible','on');
                    combiNr = find(strcmp(aiParam{idx}.valCombi,get(this.combi,'String')));
                    if(isempty(combiNr))
                        %Houston we've got a problem
                        %make warning dialog?!
                        combiNr = 1;
                    end                    
                    set(this.combi,'Enable','on','Value',combiNr);
                    set(this.combiText,'Visible','on');
                    if(strcmp(aiParam{idx}.valCombi,'-'))
                        set(this.opB,'Enable','off');
                        set(this.valB,'Enable','off');
                    else
                        opNr = find(strcmp(aiParam{idx}.opB,get(this.opB,'String')));
                        if(isempty(opNr))
                            %Houston we've got a problem
                            %make warning dialog?!
                            opNr = 1;
                        end
                        set(this.opB,'Enable','on','Value',opNr);
                        set(this.valB,'Enable','on','String',aiParam{idx}.valB);
                    end
                    set(this.opBText,'Visible','on');
                    set(this.valBText,'Visible','on');
                case 'FLIMItem'
                    set(this.valRadio,'Value',0);
                    set(this.FLIMItemRadio,'Value',1);
                    set(this.valA,'Enable','off');
                    set(this.combi,'Enable','off','Value',1);
                    set(this.opB,'Enable','off','Value',1);
                    set(this.valB,'Enable','off');
                    set(this.FLIMItemB,'Enable','on');
                    set(this.normalizeB,'Enable','on');
                    set(this.chB,'Enable','on');
                    set(this.valAText,'Visible','off');
                    set(this.combiText,'Visible','off');
                    set(this.opBText,'Visible','off');
                    set(this.valBText,'Visible','off');
            end
        end
        
        function aiParams = getCurAIParams(this)
            %returns AIParams struct
            str = get(this.FLIMItemA,'String');
            aiParams.FLIMItemA = str{get(this.FLIMItemA,'Value')};
            str = get(this.FLIMItemB,'String');
            aiParams.FLIMItemB = str{get(this.FLIMItemB,'Value')};
            aiParams.normalizeA = get(this.normalizeA,'Value');
            aiParams.normalizeB = get(this.normalizeB,'Value');
            str = get(this.chA,'String');
            vCh = get(this.chA,'Value');
            if(vCh == 1)
                aiParams.chA = 0;
            else
                tmp = str{get(this.chA,'Value')};
                aiParams.chA = str2double(tmp(isstrprop(tmp,'digit')));
            end
            vCh = get(this.chB,'Value');
            if(vCh == 1)
                aiParams.chB = 0;
            else
                tmp = str{get(this.chB,'Value')};
                aiParams.chB = str2double(tmp(isstrprop(tmp,'digit')));
            end
            str = get(this.opA,'String');
            aiParams.opA = str{get(this.opA,'Value')};
            aiParams.opB = str{get(this.opB,'Value')};
            if(get(this.valRadio,'Value') == 1)
                aiParams.compAgainst = 'val';
            else
                aiParams.compAgainst = 'FLIMItem';
            end
            str = get(this.combi,'String');
            aiParams.valCombi = str{get(this.combi,'Value')};
            aiParams.valA = str2double(get(this.valA,'String'));
            aiParams.valB = str2double(get(this.valB,'String'));
        end
        
        function out = get.curStudy(this)
            %get name of current study (left side)
            out = this.visObj.getStudy('l');
        end
        
        function out = get.curAIName(this)
            %get name of current arithmetic image
            str = get(this.aiSel,'String');
            nr = get(this.aiSel,'Value');
            out = str{nr};
            if(strcmp(out,'-none-'))
                out = '';
            end
        end
    end %methods
    
    
    methods(Access = protected)
        %internal methods
        
        function setUIHandles(this)
            %builds the uicontrol handles for the AICtrl object for axis ax
            this.FLIMItemA = this.visObj.visHandles.ai_flimitem_a_pop;
            set(this.FLIMItemA,'Callback',@this.ui_Callback);
            this.FLIMItemB = this.visObj.visHandles.ai_flimitem_b_pop;
            set(this.FLIMItemB,'Callback',@this.ui_Callback);
            this.combi = this.visObj.visHandles.ai_combi_pop;
            set(this.combi,'Callback',@this.ui_Callback);
            this.combiText = this.visObj.visHandles.ai_combi_text;
            this.chA = this.visObj.visHandles.ai_ch_a_pop;
            set(this.chA,'Callback',@this.ui_Callback);
            this.chB = this.visObj.visHandles.ai_ch_b_pop;
            set(this.chB,'Callback',@this.ui_Callback);
            this.opA = this.visObj.visHandles.ai_op_a_pop;
            set(this.opA,'Callback',@this.ui_Callback);
            this.opB = this.visObj.visHandles.ai_op_b_pop;
            set(this.opB,'Callback',@this.ui_Callback);
            this.opBText = this.visObj.visHandles.ai_op_b_text;
            this.valA = this.visObj.visHandles.ai_val_a_edit;            
            set(this.valA,'Callback',@this.ui_Callback);
            this.valAText = this.visObj.visHandles.ai_val_a_text;  
            this.valB = this.visObj.visHandles.ai_val_b_edit;
            set(this.valB,'Callback',@this.ui_Callback);
            this.valBText = this.visObj.visHandles.ai_val_b_text;  
            this.valRadio = this.visObj.visHandles.ai_val_radio;
            set(this.valRadio,'Callback',@this.ui_Callback);
            this.FLIMItemRadio = this.visObj.visHandles.ai_flimitem_radio;
            set(this.FLIMItemRadio,'Callback',@this.ui_Callback);
            this.aiSel = this.visObj.visHandles.ai_sel_pop;
            set(this.aiSel,'Callback',@this.ui_Callback);
            this.newButton = this.visObj.visHandles.ai_new_button;
            set(this.newButton,'Callback',@this.new_Callback);
            this.delButton = this.visObj.visHandles.ai_del_button;
            set(this.delButton,'Callback',@this.del_Callback);
            this.normalizeA = this.visObj.visHandles.ai_normalize_a_check;
            set(this.normalizeA,'Callback',@this.ui_Callback);
            this.normalizeB = this.visObj.visHandles.ai_normalize_b_check;
            set(this.normalizeB,'Callback',@this.ui_Callback);
        end
    end %methods protected
    
    methods(Static)
        function aiParams = getDefStruct()
            %default values for aiParams struct
            aiParams.FLIMItemA = 'Amplitude 1';
            aiParams.FLIMItemB = 'Tau 1';
            aiParams.normalizeA = 0;
            aiParams.normalizeB = 0;
            aiParams.chA = 0;
            aiParams.chB = 0;
            aiParams.opA = '<';
            aiParams.opB = '>';
            aiParams.compAgainst = 'val';
            aiParams.valCombi = '-';
            aiParams.valA = 1000;
            aiParams.valB = 1000;
        end
        
    end
    
end %classdef
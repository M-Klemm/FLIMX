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
        FLIMItemC = [];
        ROIB = [];
        ROIC = [];
        ROIVicinityB = [];
        ROIVicinityC = [];
        normalizeA = [];
        normalizeB = [];
        normalizeC = [];        
        targetSelB = [];
        targetSelC = [];
        chA = [];
        chB = [];
        chC = [];
        opA = [];
        opB = [];
        valB = [];
        valC = [];
        aiSel = [];
        newButton = [];
        delButton = [];
    end
    
    properties (Dependent = true)
        curStudy = '',
        curSubjectName = '';
        curAIName = '';
    end
    
    methods
        function this = AICtrl(visObj,axis,FDisplayL,FDisplayR)
            % Constructor for AICtrl.
            this.visObj = visObj;
            this.setUIHandles();
            oStr = AICtrl.getDefOpString();
            cStr = [{'-no op-'},oStr];
            set(this.opA,'String',oStr,'Value',1);
            set(this.opB,'String',cStr,'Value',1);
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
            set(this.FLIMItemC,'Visible',param);
            set(this.ROIB,'Visible',param);
            set(this.ROIC,'Visible',param);
            set(this.ROIVicinityB,'Visible',param);
            set(this.ROIVicinityC,'Visible',param);
            set(this.normalizeA,'Visible',param);
            set(this.normalizeB,'Visible',param);
            set(this.normalizeC,'Visible',param);
            set(this.opB,'Visible',param);
            set(this.targetSelB,'Visible',param);
            set(this.targetSelC,'Visible',param);
            set(this.chA,'Visible',param);
            set(this.chB,'Visible',param);
            set(this.chC,'Visible',param);
            set(this.opA,'Visible',param);
            set(this.valB,'Visible',param);
            set(this.valC,'Visible',param);
            set(this.delButton,'Visible',param);
        end
        
        function new_Callback(this,hObject,eventdata)
            %user wants a new arithmetic image
            %get arithmetic images for current study
            oldNames = this.visObj.fdt.getArithmeticImageDefinition(this.curStudy);
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
            this.visObj.fdt.setArithmeticImageDefinition(this.curStudy,settings.Name,this.getDefStruct);
            this.updateCtrls();
            this.curAIName = settings.Name;
            this.visObj.setupGUI();
        end
        
        function edit_Callback(this,hObject,eventdata)
            %rename arithmetic image
            
        end
        
        function del_Callback(this,hObject,eventdata)
            %delete arithmetic image
            choice = questdlg(sprintf('Delete arithmetic image ''%s''?',this.curAIName),'Delete Arith. Image?','Yes','No','No');
            switch choice
                case 'No'
                    return
            end
            this.visObj.fdt.removeArithmeticImageDefinition(this.curStudy,this.curAIName);
            this.updateCtrls();
            this.visObj.setupGUI();
            this.visObj.updateGUI([]);
        end
        
        function ui_Callback(this,hObject,eventdata)
            %user changed a parameter of the current arithmetic image
            if(hObject == this.valB || hObject == this.valC)
                set(hObject,'String',str2double(get(hObject,'String')));
            end
            if(hObject ~= this.visObj.visHandles.ai_sel_pop)
                if(strcmp(hObject.Tag,'ai_targetSel_b_pop'))
                    this.updateItemPopup(this.chB.Value-1,AICtrl.targetTypeID2Str(hObject.Value),'B',[]);                    
                elseif(strcmp(hObject.Tag,'ai_targetSel_c_pop'))
                    this.updateItemPopup(this.chC.Value-1,AICtrl.targetTypeID2Str(hObject.Value),'C',[]); 
                end
                this.visObj.fdt.setArithmeticImageDefinition(this.curStudy,this.curAIName,this.getCurAIParams());
            end
            this.updateCtrls();
            this.visObj.updateGUI([]);
        end        
        
        function updateCtrls(this)
            %updates controls to current values
            %get arithmetic images for current study
            [aiStr, aiParam] = this.visObj.fdt.getArithmeticImageDefinition(this.curStudy);
            idx = find(strcmp(aiStr,this.curAIName));
            if(isempty(idx))
                idx = min(length(aiStr),this.aiSel.Value);
            end
            if(length(aiStr) < idx || isempty(aiStr{idx}))
                %hide controls
                set(this.aiSel,'String','-none-','Value',1);
                this.inVisible('off');
                return
            end            
            set(this.aiSel,'String',aiStr,'Value',idx);
            this.inVisible('on');
            chNr = this.AIParam2GUIChannelNr(aiParam{idx},'A');
            chStr = [{'all Ch'}; this.visObj.fdt.getChStr(this.curStudy,this.curSubjectName)];
            if(isempty(chNr))
                %Houston we've got a problem
                %make warning dialog to switch subject?!
                return
            end
            set(this.chA,'String',chStr,'Value',chNr+1);
            %second flim item channel
            chNr = this.AIParam2GUIChannelNr(aiParam{idx},'B');
            if(isempty(chNr))
                %Houston we've got a problem
                %make warning dialog to switch subject?!
                return
            end
            set(this.chB,'String',chStr,'Value',chNr+1);
            %third flim item channel
            chNr = this.AIParam2GUIChannelNr(aiParam{idx},'C');
            if(isempty(chNr))
                %Houston we've got a problem
                %make warning dialog to switch subject?!
                return
            end
            set(this.chC,'String',chStr,'Value',chNr+1);            
            %find saved FLIM item
            this.updateItemPopup(this.chA.Value-1,'FLIMItem','A',aiParam{idx});                               
            %op for base flim item
            opNr = find(strcmp(aiParam{idx}.opA,get(this.opA,'String')));
            if(isempty(opNr))                
                %Houston we've got a problem
                %make warning dialog?!
                opNr = 1;
            end
            this.opA.Value = opNr;
            this.normalizeA.Value = aiParam{idx}.normalizeA;
            if(opNr >= 16)
                %dilate,erode,open,close,fill
                this.targetSelB.Enable = 'Off';
                this.opB.Visible = 'Off';
            else
                this.targetSelB.Enable = 'On';
                this.opB.Visible = 'On';
                this.normalizeB.Value = aiParam{idx}.normalizeB;
                this.normalizeC.Value = aiParam{idx}.normalizeC;
                this.updateItemPopup(this.chB.Value-1,'FLIMItem','B',aiParam{idx});
                this.updateItemPopup(this.chB.Value-1,'ROI','B',aiParam{idx});
                this.ROIVicinityB.Value = aiParam{idx}.ROIVicinityB;
                this.updateItemPopup(this.chC.Value-1,'FLIMItem','C',aiParam{idx});
                this.updateItemPopup(this.chC.Value-1,'ROI','C',aiParam{idx});
                this.ROIVicinityC.Value = aiParam{idx}.ROIVicinityC;
            end
            %first calculation target
            switch aiParam{idx}.compAgainstB
                case 'val'
                    this.targetSelB.Value = 3;
                    set(this.FLIMItemB,'Enable','off','Visible','off');
                    set(this.ROIB,'Enable','off','Visible','off');
                    set(this.ROIVicinityB,'Enable','off','Visible','off');
                    set(this.chB,'Enable','off','Visible','off');
                    set(this.valB,'Enable','on','Visible','on','String',aiParam{idx}.valB);
                    set(this.normalizeB,'Enable','off','Visible','off');
                    %this.updateItemPopup(this.chB.Value-1,'FLIMItem','B',[]); %for a valid popup string
                case 'FLIMItem'
                    this.targetSelB.Value = 1;
                    %second flim item
                    set(this.FLIMItemB,'Enable','on','Visible','on');
                    set(this.ROIB,'Enable','off','Visible','off');
                    set(this.ROIVicinityB,'Enable','off','Visible','off');
                    set(this.valB,'Enable','off','Visible','off');
                    set(this.normalizeB,'Enable','on','Visible','on');
                    set(this.chB,'Enable','on','Visible','on');
                case 'ROI'
                    this.targetSelB.Value = 2;                    
                    set(this.FLIMItemB,'Enable','off','Visible','off');
                    set(this.ROIB,'Enable','on','Visible','on');
                    set(this.ROIVicinityB,'Enable','on','Visible','on');
                    set(this.valB,'Enable','off','Visible','off');
                    set(this.normalizeB,'Enable','off','Visible','off');
                    set(this.chB,'Enable','on','Visible','on');
            end
            if(opNr == 20)
                %fill operation
                this.valB.Visible = 'off';
                this.targetSelB.Visible = 'off';
            else
                this.targetSelB.Visible = 'on';
            end
%             this.updateItemPopup(this.chB.Value-1,aiParam{idx}.compAgainstB,'B',aiParam{idx});
            %op for third value / parameter
            opNr = find(strcmp(aiParam{idx}.opB,this.opB.String));
            if(isempty(opNr))
                %Houston we've got a problem
                %make warning dialog?!
                opNr = 1;
            end
            this.opB.Value = opNr;
            if(strcmp(aiParam{idx}.opB,'-no op-'))
                set(this.valC,'Enable','off','Visible','off');
                set(this.FLIMItemC,'Enable','off','Visible','off');
                set(this.ROIC,'Enable','off','Visible','off');
                set(this.ROIVicinityC,'Enable','off','Visible','off');
                set(this.normalizeC,'Enable','off','Visible','off');
                set(this.chC,'Enable','off','Visible','off');
                set(this.targetSelC,'Visible','off');
            else
                this.targetSelC.Visible = 'on';
                %second calculation target
                switch aiParam{idx}.compAgainstC
                    case 'val'
                        this.targetSelC.Value = 3;
                        set(this.FLIMItemC,'Enable','off','Visible','off');
                        set(this.ROIC,'Enable','off','Visible','off');
                        set(this.ROIVicinityC,'Enable','off','Visible','off');
                        set(this.chC,'Enable','off','Visible','off');
                        set(this.valC,'Enable','on','Visible','on','String',aiParam{idx}.valC);
                        set(this.normalizeC,'Enable','off','Visible','off');                        
                    case 'FLIMItem'
                        this.targetSelC.Value = 1;
                        %third flim item
                        set(this.FLIMItemC,'Enable','on','Visible','on');
                        set(this.ROIC,'Enable','off','Visible','off');
                        set(this.ROIVicinityC,'Enable','off','Visible','off');
                        set(this.valC,'Enable','off','Visible','off');
                        set(this.normalizeC,'Enable','on','Visible','on');
                        set(this.chC,'Enable','on','Visible','on');
                    case 'ROI'
                        this.targetSelC.Value = 2;
                        set(this.FLIMItemC,'Enable','off','Visible','off');
                        set(this.ROIC,'Enable','on','Visible','on');
                        set(this.ROIVicinityC,'Enable','on','Visible','on');
                        set(this.valC,'Enable','off','Visible','off');
                        set(this.normalizeC,'Enable','off','Visible','off');
                        set(this.chC,'Enable','on','Visible','on');
                end
            end
        end
        
        function aiParams = getCurAIParams(this)
            %returns AIParams struct
            aiParams = AICtrl.getDefStruct();
            str = this.FLIMItemA.String;
            aiParams.FLIMItemA = str{this.FLIMItemA.Value}; 
            aiParams.normalizeA = this.normalizeA.Value;
            aiParams.normalizeB = this.normalizeB.Value;
            aiParams.normalizeC = this.normalizeC.Value;
            str = this.chA.String;
            vCh = this.chA.Value;
            if(vCh == 1)
                aiParams.chA = 0;
            else
                tmp = str{this.chA.Value};
                aiParams.chA = str2double(tmp(isstrprop(tmp,'digit')));
            end
            vCh = this.chB.Value;
            if(vCh == 1)
                aiParams.chB = 0;
            else
                tmp = str{this.chB.Value};
                aiParams.chB = str2double(tmp(isstrprop(tmp,'digit')));
            end
            vCh = this.chC.Value;
            if(vCh == 1)
                aiParams.chC = 0;
            else
                tmp = str{this.chC.Value};
                aiParams.chC = str2double(tmp(isstrprop(tmp,'digit')));
            end
            str = this.opA.String;
            aiParams.opA = str{this.opA.Value};
            if(this.opA.Value >= 16)
                %dilate, erode, open, close
                this.targetSelB.Value = 3;
                this.opB.Value = 1;
            end
            str = this.FLIMItemB.String;
            aiParams.FLIMItemB = str{this.FLIMItemB.Value};
            str = this.ROIB.String;
            aiParams.ROIB = str{this.ROIB.Value};
            aiParams.ROIVicinityB = this.ROIVicinityB.Value;
            switch this.targetSelB.Value
                case 1
                    aiParams.compAgainstB = 'FLIMItem';
                case 2
                    aiParams.compAgainstB = 'ROI';
                case 3
                    aiParams.compAgainstB = 'val';
            end
            str = this.FLIMItemC.String;
            aiParams.FLIMItemC = str{this.FLIMItemC.Value};
            str = this.ROIC.String;
            aiParams.ROIC = str{this.ROIC.Value};
            aiParams.ROIVicinityC = this.ROIVicinityC.Value;
            switch this.targetSelC.Value
                case 1
                    aiParams.compAgainstC = 'FLIMItem';
                case 2
                    aiParams.compAgainstC = 'ROI';
                case 3
                    aiParams.compAgainstC = 'val';
            end
            str = this.opB.String;
            aiParams.opB = str{this.opB.Value};
            aiParams.valB = str2double(this.valB.String);
            aiParams.valC = str2double(this.valC.String);
        end
        
        function out = get.curStudy(this)
            %get name of current study (left side)
            out = this.visObj.getStudy('l');
        end
        
        function out = get.curSubjectName(this)
            %get name of current subject (left side)
            out = this.visObj.getSubject('l');
        end
        
        function out = get.curAIName(this)
            %get name of current arithmetic image
            str = get(this.aiSel,'String');
            nr = get(this.aiSel,'Value');
            if(iscell(str))
                out = str{nr};
            else
                out = str;
            end
            if(strcmp(out,'-none-'))
                out = '';
            end
        end
        
        function set.curAIName(this,val)
            %set current arithmetic image            
            aiStr = get(this.aiSel,'String');
            idx = find(strcmp(aiStr,val));
            if(isempty(idx))
                idx = min(length(aiStr),this.aiSel.Value);
            end
            if(isempty(idx))
                return
            end            
            set(this.aiSel,'Value',idx);
        end
    end %methods
    
    
    methods(Access = protected)
        %internal methods        
        function setUIHandles(this)
            %builds the uicontrol handles for the AICtrl object for axis ax
            this.FLIMItemA = this.visObj.visHandles.ai_flimitem_a_pop;
            set(this.FLIMItemA,'Callback',@this.ui_Callback,'TooltipString','Select FLIM parameter');
            this.FLIMItemB = this.visObj.visHandles.ai_flimitem_b_pop;
            set(this.FLIMItemB,'Callback',@this.ui_Callback,'TooltipString','Select FLIM parameter');
            this.FLIMItemC = this.visObj.visHandles.ai_flimitem_c_pop;
            set(this.FLIMItemC,'Callback',@this.ui_Callback,'TooltipString','Select FLIM parameter');
            this.ROIB = this.visObj.visHandles.ai_roi_b_pop;
            set(this.ROIB,'Callback',@this.ui_Callback,'TooltipString','Select Region of Interest (ROI), its mean value will be used for the arithmetic image calculation');
            this.ROIC = this.visObj.visHandles.ai_roi_c_pop;
            set(this.ROIC,'Callback',@this.ui_Callback,'TooltipString','Select Region of Interest (ROI), its mean value will be used for the arithmetic image calculation');
            this.ROIVicinityB = this.visObj.visHandles.ai_roi_vic_b_pop;
            set(this.ROIVicinityB,'Callback',@this.ui_Callback,'TooltipString','Select ''inside'' for the area inside the ROI coordinates, ''invert'' to exclude the ROI area from further analysis or ''vicinity'' to use the area surrounding the ROI');
            this.ROIVicinityC = this.visObj.visHandles.ai_roi_vic_c_pop;
            set(this.ROIVicinityC,'Callback',@this.ui_Callback,'TooltipString','Select ''inside'' for the area inside the ROI coordinates, ''invert'' to exclude the ROI area from further analysis or ''vicinity'' to use the area surrounding the ROI');
            this.targetSelB = this.visObj.visHandles.ai_targetSel_b_pop;
            set(this.targetSelB,'Callback',@this.ui_Callback,'TooltipString','Select target for arithmetic operation: FLIM parameter (e.g. Tau1), mean value of region of interest (ROI) or a numeric value (e.g. for comparison with a threshold)');
            this.targetSelC = this.visObj.visHandles.ai_targetSel_c_pop;
            set(this.targetSelC,'Callback',@this.ui_Callback,'TooltipString','Select target for arithmetic operation: FLIM parameter (e.g. Tau1), mean value of region of interest (ROI) or a numeric value (e.g. for comparison with a threshold)');
            this.opB = this.visObj.visHandles.ai_op_b_pop;
            set(this.opB,'Callback',@this.ui_Callback,'TooltipString','Select logical or arithmetic operator. THIS OPERATION WILL BE CALCULATED FIRST!');
            this.chA = this.visObj.visHandles.ai_ch_a_pop;
            set(this.chA,'Callback',@this.ui_Callback,'TooltipString','Select spectral channel; ''all Ch'' will compute the arithmetic image for all channels separately');
            this.chB = this.visObj.visHandles.ai_ch_b_pop;
            set(this.chB,'Callback',@this.ui_Callback,'TooltipString','Select spectral channel; ''all Ch'' will compute the arithmetic image for all channels separately');
            this.chC = this.visObj.visHandles.ai_ch_c_pop;
            set(this.chC,'Callback',@this.ui_Callback,'TooltipString','Select spectral channel; ''all Ch'' will compute the arithmetic image for all channels separately');
            this.opA = this.visObj.visHandles.ai_op_a_pop;
            set(this.opA,'Callback',@this.ui_Callback,'TooltipString','Select logical or arithmetic operator');
            this.valB = this.visObj.visHandles.ai_val_b_edit;            
            set(this.valB,'Callback',@this.ui_Callback,'TooltipString','Enter numeric value');
            this.valC = this.visObj.visHandles.ai_val_c_edit;
            set(this.valC,'Callback',@this.ui_Callback,'TooltipString','Enter numeric value'); 
            this.aiSel = this.visObj.visHandles.ai_sel_pop;
            set(this.aiSel,'Callback',@this.ui_Callback,'TooltipString','Select existing arithmetic image');
            this.newButton = this.visObj.visHandles.ai_new_button;
            set(this.newButton,'Callback',@this.new_Callback,'TooltipString','Create new arithmetic image, which is computed for each subject of the current study');
            this.delButton = this.visObj.visHandles.ai_del_button;
            set(this.delButton,'Callback',@this.del_Callback,'TooltipString','Delete selected arithmetic image');
            this.normalizeA = this.visObj.visHandles.ai_normalize_a_check;
            set(this.normalizeA,'Callback',@this.ui_Callback,'TooltipString','Normalize FLIM parameter');
            this.normalizeB = this.visObj.visHandles.ai_normalize_b_check;
            set(this.normalizeB,'Callback',@this.ui_Callback,'TooltipString','Normalize FLIM parameter');
            this.normalizeC = this.visObj.visHandles.ai_normalize_c_check;
            set(this.normalizeC,'Callback',@this.ui_Callback,'TooltipString','Normalize FLIM parameter');
        end
        
        function objStr = updateItemPopup(this,chNr,targetType,layer,aiParam)
            %build popup string with either FLIM items or ROIs
            layer = upper(layer);
            if(~any(strcmp({'A','B','C'},layer)))
                return
            end
            objStr = '';
            if(strcmp(targetType,'FLIMItem'))
                objStr = this.visObj.fdt.getChObjStr(this.curStudy,this.curSubjectName,max(1,chNr));
                subjectInfoColumns = this.visObj.fdt.getDataFromStudyInfo(this.curStudy,'subjectInfoRegularNumericColumnNames');
                for i = 1:length(subjectInfoColumns)
                    subjectInfoColumns{i} = sprintf('subjectInfo->%s',subjectInfoColumns{i});
                end
                if(any(strcmp(subjectInfoColumns,'subjectInfo->Age')))
                    subjectInfoColumns{end+1,1} = 'subjectInfo->Tau1_EstimatedByAge';
                    subjectInfoColumns{end+1,1} = 'subjectInfo->Tau2_EstimatedByAge';
                    subjectInfoColumns{end+1,1} = 'subjectInfo->Tau3_EstimatedByAge';
                    subjectInfoColumns{end+1,1} = 'subjectInfo->TauMean_EstimatedByAge';
                end
                objStr = [objStr; subjectInfoColumns];
                %remove current arithmetic image from channel objects
                objStr = objStr(~strcmp(objStr,this.curAIName));
                popupHandleStr = sprintf('FLIMItem%s',layer);
            elseif(strcmp(targetType,'ROI'))
                objStr = AICtrl.getDefROIString(); 
                popupHandleStr = sprintf('ROI%s',layer);
            end
            if(~isempty(objStr))
                if(isempty(aiParam))
                    set(this.(popupHandleStr),'String',objStr,'Value',min(length(objStr),this.(popupHandleStr).Value));
                else
                    fiNr = find(strcmp(aiParam.(popupHandleStr),objStr));
                    if(isempty(fiNr))
                        %FLIMItem defined, which current subject does not (yet) have
                        objStr{end+1,1} = aiParam.(popupHandleStr);
                        fiNr = size(objStr,1);
                        set(this.(popupHandleStr),'String',objStr,'Value',fiNr);
                    end
                    set(this.(popupHandleStr),'String',objStr,'Value',fiNr);
                end
            end
        end
        
        function out = AIParam2GUIChannelNr(this,aiParam,layer)
            %return currently selected channel or zero for 'all channels'
            chStr = [{'all Ch'}; this.visObj.fdt.getChStr(this.curStudy,this.curSubjectName)];
            out = [];
            layer = upper(layer);
            if(~any(strcmp({'A','B','C'},layer)))
                return
            end            
            %find saved channel
            if(aiParam.(sprintf('ch%s',layer)) == 0)
                out = 0;
            else
                out = find(strcmp(sprintf('Ch %d',aiParam.(sprintf('ch%s',layer))),chStr))-1;
            end                
        end
    end %methods protected
    
    methods(Static)
        function aiParams = getDefStruct()
            %default values for aiParams struct
            aiParams.FLIMItemA = 'Amplitude 1';
            aiParams.FLIMItemB = 'Tau 1';
            aiParams.FLIMItemC = 'Tau 1';
            aiParams.ROIB = 'Rectangle #1';
            aiParams.ROIVicinityB = 1;
            aiParams.ROIC = 'Circle #1';
            aiParams.ROIVicinityC = 1;
            aiParams.normalizeA = 0;
            aiParams.normalizeB = 0;
            aiParams.normalizeC = 0;
            aiParams.chA = 0;
            aiParams.chB = 0;
            aiParams.chC = 0;
            aiParams.opA = '<';
            aiParams.opB = '-no op-';
            aiParams.compAgainstB = 'val';
            aiParams.compAgainstC = 'val';            
            aiParams.valB = 1000;
            aiParams.valC = 1000;
        end
        
        function out = getDefOpString()
            %return string with possible numeric and logical operations
            out = {'+','-','.*','./','<','>','<=','>=','==','!=','AND','OR','!AND','!OR','XOR','dilate','erode','open','close','fill'};
        end
        
        function out = getDefROIString()
            %return string with possible ROIs
            out = {'ETDRS->central';
                'ETDRS->inner superior';
                'ETDRS->inner nasal';
                'ETDRS->inner inferior';
                'ETDRS->inner temporal';
                'ETDRS->outer superior';
                'ETDRS->outer nasal';
                'ETDRS->outer inferior';
                'ETDRS->outer temporal';
                'ETDRS->inner ring';
                'ETDRS->outer ring';
                'ETDRS->full circle';
                'ETDRS->center + inner ring';
                'ETDRS->center + outer ring';
                'ETDRS->inner + outer ring';
                'Rectangle #1';
                'Rectangle #2';
                'Circle #1';
                'Circle #2';
                'Polygon #1';
                'Polygon #2'};
        end
        
        function out = targetTypeID2Str(tID)
            %convert target type to id
            switch tID
                case 1
                    out = 'FLIMItem';
                case 2
                    out = 'ROI';
                otherwise
                    out = 'val';
            end
        end
        
        function out = targetTypeStr2ID(tStr)
            %convert target type to id
            switch tStr
                case 'FLIMItem'
                    out = 1;
                case 'ROI'
                    out = 2;
                otherwise %'val'
                    out = 3;
            end
        end
        
    end
    
end %classdef
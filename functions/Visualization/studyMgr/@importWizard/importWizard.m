classdef importWizard < handle
    %=============================================================================================================
    %
    % @file     importWizard.m
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
    % @brief    A class to handle the GUI to import of time resolved fluorescence data
    %
    properties(GetAccess = protected, SetAccess = private)
        FLIMXObj = [];
        visHandles = [];
        buttonDown = false; %flags if mouse button is pressed
        finalROIVec = [];
        measurementObj = [];
        axesMgr = [];
        mouseOverlay = [];
        isDirty = false(1,5); %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
    end
    
    properties (Dependent = true)
        lastImportPath = '';
        currentChannel = 1;
        currentROIVec = [];
        currentStudy = '';
        currentSubject = '';
        editFieldROIVec = [];
        roiMode = 1;
        myMeasurement = [];
        isNewMeasurement = false;
        resolution = 0;
        position = 'OD';
    end
    
    methods
        function this = importWizard(flimX)
            %constructor
            if(isempty(flimX))               
                error('Handle to FLIMX object required!');
            end
            this.FLIMXObj = flimX;
        end
        
        function closeCallback(this)
            %executed when figure should be closed
            if(this.isOpenVisWnd())
                delete(this.visHandles.importWizardFigure);
            end
        end
        
        function openFileByGUI(this,study,subject)
            %reads a fluorescence (measurement) file from disk
            path = this.lastImportPath;
            if(this.openFileByStr(importWizard.loadFile({'*.sdt','Becker & Hickl file (*.sdt)';'*.txt;*.dat;*.asc','Single Decay (ASCII) file (*.txt,*.dat,*.asc)'},'Load Fluorescence Decay Data',path)))
                this.checkVisWnd();
                if(isempty(subject))
                    %set default subject name
                    pathstr = this.measurementObj.sourcePath;
                    if(strcmp(pathstr(end),filesep))
                        pathstr(end) = '';
                    end
                    idx = strfind(pathstr,filesep);
                    if(isempty(idx))
                        subject = 'subject01';
                    else
                        subject = pathstr(idx(end)+1:end);
                    end
                end
                this.setSubject(study,subject);
                this.setupGUI();
            end
        end
                
        function success = openFileByStr(this,fn)
            %reads a fluorescence (measurement) file from disk
            success = false;
            if(isempty(fn))
                return;
            end
            this.measurementObj = measurementReadRawData(this.FLIMXObj.paramMgr);
            this.measurementObj.setSourceFile(fn);
            if(this.isOpenVisWnd())
                ch = this.currentChannel;
            else
                ch = 1;
            end
            if(ch <= this.measurementObj.nrSpectralChannels)
                %get full roi
                ROIVec = [1 this.myMeasurement.getRawXSz() 1 this.myMeasurement.getRawYSz()];
                %ROIVec = importWizard.getAutoROI(this.measurementObj.getRawDataFlat(ch),this.measurementObj.roiStaticBinningFactor);
                if(ROIVec(1) > 5 || ROIVec(3) > 5 || ROIVec(2) < this.myMeasurement.rawXSz-5 || ROIVec(4) < this.myMeasurement.rawYSz-5)
                    this.finalROIVec = ROIVec;
                end
                this.isDirty(1) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
                this.myMeasurement.setROICoord(this.finalROIVec);
                x = this.myMeasurement.rawXSz;
                if(x < 256)
                    x = 150;
                end
                this.myMeasurement.pixelResolution = 1000*8.8/x;
            end
            %guess position of the eye            
            this.myMeasurement.guessEyePosition();
            success = true;
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.importWizardFigure) || ~strcmp(get(this.visHandles.importWizardFigure,'Tag'),'importWizardFigure'));
        end
        
        function checkVisWnd(this)
            %if not reopen
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.setupGUI();
            this.updateGUI();
            figure(this.visHandles.importWizardFigure);
        end
        
        %% input methods
        
        
        %% dependent properties
        function out = get.isNewMeasurement(this)
            %flag if we import a new measurement or edit an existing one
            out = ~isempty(this.measurementObj);
        end
        
        function out = get.myMeasurement(this)
            %get measurement or subject object
            out = this.measurementObj;
            if(isempty(out))
                out = this.FLIMXObj.curSubject.myMeasurement;
            end                
        end
        
        function pn = get.lastImportPath(this)
            %get the folder which was last used for fluo file import
            pn = fileparts(this.myMeasurement.getSourceFile());
            if(isempty(pn))
                pn = this.FLIMXObj.getWorkingDir();
            end
        end
        
        function out = get.currentChannel(this)
            %return current channel nr
            out = get(this.visHandles.popupChannel,'Value');
        end
        
        function out = get.resolution(this)
            %get value for pixel resolution
            out = abs(str2double(get(this.visHandles.editResolution,'String')));
        end
        
        function out = get.position(this)
            %get value for position
            out = get(this.visHandles.popupPosition,'String');
            out = out{get(this.visHandles.popupPosition,'Value')};
        end
        
        function set.resolution(this,val)
            %set value for pixel resolution
            if(this.isNewMeasurement)
                this.myMeasurement.pixelResolution = val;
            end
            set(this.visHandles.editResolution,'String',val);
        end
                
        function out = get.roiMode(this)
            %return number of selected roi mode (1: whole dataset, 2: auto, 3: custom)
            if(get(this.visHandles.radioAuto,'Value'))
                out = 2;
            elseif(get(this.visHandles.radioCustom,'Value'))
                out = 3;
            else
                out = 1;
            end
        end
        
        function set.roiMode(this,val)
            %set number of selected roi mode (1: whole dataset, 2: auto, 3: custom)
            switch val
                case 2
                    set(this.visHandles.radioDefault,'Value',0);
                    set(this.visHandles.radioAuto,'Value',1);
                    set(this.visHandles.radioCustom,'Value',0);
                    flag = 'off';
                case 3
                    set(this.visHandles.radioDefault,'Value',0);
                    set(this.visHandles.radioAuto,'Value',0);
                    set(this.visHandles.radioCustom,'Value',1);
                    flag = 'on';
                otherwise
                    set(this.visHandles.radioDefault,'Value',1);
                    set(this.visHandles.radioAuto,'Value',0);
                    set(this.visHandles.radioCustom,'Value',0);
                    flag = 'off';
            end
            set(this.visHandles.textXL,'Enable',flag);
            set(this.visHandles.textXH,'Enable',flag);
            set(this.visHandles.textYL,'Enable',flag);
            set(this.visHandles.textYH,'Enable',flag);
        end
        
        function out = get.editFieldROIVec(this)
            %make roi vector from 
            x = this.myMeasurement.getRawXSz();
            y = this.myMeasurement.getRawYSz();
            cXl = max(1,str2double(get(this.visHandles.textXL,'String')));
            cXu = min(x,str2double(get(this.visHandles.textXH,'String')));
            cXl = max(1,min(cXl,cXu-1));
            cXu = min(x,max(cXu,cXl+1));
            cYl = max(1,str2double(get(this.visHandles.textYL,'String')));
            cYu = min(y,str2double(get(this.visHandles.textYH,'String')));
            cYl = max(1,min(cYl,cYu-1));
            cYu = min(y,max(cYu,cYl+1));
            out = [cXl, cXu, cYl, cYu];
%             out = [str2double(get(this.visHandles.textXL,'String')) str2double(get(this.visHandles.textXH,'String')), ...
%             str2double(get(this.visHandles.textYL,'String')), str2double(get(this.visHandles.textYH,'String'))];
        end
        
        function set.editFieldROIVec(this,val)
            %set roi points in GUI from roi vec (apply limits)
            if(length(val) == 4)
                set(this.visHandles.textXL,'String',max(1,val(1)))
                set(this.visHandles.textXH,'String',min(this.myMeasurement.getRawXSz(),val(2)));
                set(this.visHandles.textYL,'String', max(1,val(3)))
                set(this.visHandles.textYH,'String',min(this.myMeasurement.getRawYSz(),val(4)));
            end
        end
        
        function out = get.currentROIVec(this)
            %make ROI vector based on current GUI settings
            switch this.roiMode
                case 1
                    out = [1 this.myMeasurement.getRawXSz() 1 this.myMeasurement.getRawYSz()];
                case 2
                    out = importWizard.getAutoROI(this.myMeasurement.getRawDataFlat(this.currentChannel),2);
                case 3
                    out = this.editFieldROIVec;
            end
        end
        
        function out = get.currentStudy(this)
            %get name of current study
            out = '';
            if(this.isOpenVisWnd())
                if(get(this.visHandles.radioExistingStudy,'Value'))
                    str = get(this.visHandles.popupStudySel,'String');
                    if(~isempty(str) && iscell(str))
                        out = str{get(this.visHandles.popupStudySel,'Value')};
                    elseif(ischar(str))
                        out = str;
                    end
                else
                    out = get(this.visHandles.editStudyName,'String');
                end
            else
                %we don't have a GUI yet, use FLIMXFitGUI
                out = this.FLIMXObj.FLIMFitGUI.currentStudy;
            end
        end
        
        function out = get.currentSubject(this)
            %get name of current subject
            out = '';
            if(~this.isOpenVisWnd())
                return
            end
            if(get(this.visHandles.radioExistingSubject,'Value'))
                str = get(this.visHandles.popupSubjectSel,'String');
                if(~isempty(str) && iscell(str))
                    out = str{get(this.visHandles.popupSubjectSel,'Value')};
                elseif(ischar(str))
                    out = str;
                end
            else
                out = get(this.visHandles.editSubjectName,'String');
            end
        end
        
        function set.currentSubject(this,val)
            %set name of current subject
            valOrg = val;
            i = 1;
            while(any(strcmp(val,this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,FDTree.defaultConditionName()))))
                val = sprintf('%s%02d',valOrg,i);
                i=i+1;
            end
            set(this.visHandles.editSubjectName,'String',val);
        end
        
    end %methods
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            %make a window for visualization of current fit
            this.visHandles = importWizardFigure();
            figure(this.visHandles.importWizardFigure);
            %set callbacks
            %buttons
            set(this.visHandles.buttonImport,'Callback',@this.GUI_buttonImport_Callback);
            set(this.visHandles.buttonOK,'Callback',@this.GUI_buttonOK_Callback);
            set(this.visHandles.buttonCancel,'Callback',@this.GUI_buttonCancel_Callback);
            %popups
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback);
            set(this.visHandles.popupStudySel,'Callback',@this.GUI_popupStudySel_Callback);
            set(this.visHandles.popupSubjectSel,'Callback',@this.GUI_popupSubjectSel_Callback);
            set(this.visHandles.popupPosition,'Callback',@this.GUI_popupPosition_Callback);
            %radio buttons
            set(this.visHandles.radioDefault,'Callback',@this.GUI_radioROI_Callback);
            set(this.visHandles.radioAuto,'Callback',@this.GUI_radioROI_Callback);
            set(this.visHandles.radioCustom,'Callback',@this.GUI_radioROI_Callback);
            set(this.visHandles.radioExistingStudy,'Callback',@this.GUI_radioStudy_Callback);
            set(this.visHandles.radioNewStudy,'Callback',@this.GUI_radioStudy_Callback,'enable','off');
            set(this.visHandles.radioExistingSubject,'Callback',@this.GUI_radioSubject_Callback);
            set(this.visHandles.radioNewSubject,'Callback',@this.GUI_radioSubject_Callback,'enable','off');
            %edit fields
            set(this.visHandles.editFile,'Callback',@this.GUI_editFile_Callback);
            set(this.visHandles.editResolution,'Callback',@this.GUI_editResolution_Callback);
            set(this.visHandles.textXL,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.textXH,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.textYL,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.textYH,'Callback',@this.GUI_editROI_Callback);
            set(this.visHandles.editStudyName,'Callback',@this.GUI_editStudyName_Callback);
            set(this.visHandles.editSubjectName,'Callback',@this.GUI_editDSName_Callback);
            %mouse
            set(this.visHandles.importWizardFigure,'WindowButtonDownFcn',@this.GUI_mouseButtonDown_Callback);
            set(this.visHandles.importWizardFigure,'WindowButtonUpFcn',@this.GUI_mouseButtonUp_Callback);
            set(this.visHandles.importWizardFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback);
            
            %set initial values from param object
            pPParam = this.FLIMXObj.paramMgr.getParamSection('pre_processing');
            switch pPParam.roiMode
                case 2
                    set(this.visHandles.radioAuto,'Value',1);
                case 3
                    set(this.visHandles.radioCustom,'Value',1);
                otherwise
                    set(this.visHandles.radioDefault,'Value',1);
            end
            if(isempty(this.myMeasurement.ROICoordinates))
                %propose full roi
                this.editFieldROIVec = [1 this.myMeasurement.getRawXSz() 1 this.myMeasurement.getRawYSz()];
                %this.editFieldROIVec = importWizard.getAutoROI(this.myMeasurement.getRawDataFlat(this.currentChannel),pPParam.roiBinning);                
                this.isDirty(1) = 1;
            else
                this.editFieldROIVec = this.myMeasurement.ROICoordinates;
                if(all(this.editFieldROIVec == [1 this.myMeasurement.getRawXSz() 1 this.myMeasurement.getRawYSz()]))
                    this.roiMode = 1;
                else
                    this.roiMode = 3; %we have a roi defined, assume this to be custom made
                end
            end
            %set initial study
            this.setSubject('','');            
            this.finalROIVec = this.editFieldROIVec;
            this.buttonDown = false;
            %create axes object
            cm = this.FLIMXObj.FLIMFitGUI.dynVisParams.cmIntensity;
            if(isempty(cm))
                cm = gray(256);
            end
            this.axesMgr = axesWithROI(this.visHandles.axesROI,this.visHandles.axesCb,this.visHandles.textCbBottom,this.visHandles.textCbTop,[],cm);
            this.axesMgr.setColorMapPercentiles(this.FLIMXObj.FLIMFitGUI.generalParams.cmIntensityPercentileLB,this.FLIMXObj.FLIMFitGUI.generalParams.cmIntensityPercentileUB);
            this.mouseOverlay = mouseOverlayBox(this.visHandles.axesROI);
        end
        
        function setSubject(this,study,subject)
            %set study and subject, does not update plots!
            if(isempty(study))
                study = this.FLIMXObj.FLIMFitGUI.currentStudy;
                if(isempty(study))
                    study = 'Default';
                end
            end
            studies = this.FLIMXObj.fdt.getStudyNames();
            idx = find(strcmp(study,studies));
            if(~isempty(studies))
                set(this.visHandles.editStudyName,'String',study);
            end
            if(~isempty(idx))
                set(this.visHandles.popupStudySel,'String',studies,'Value',idx);
            end
            %set subject name 
            if(isempty(subject))
                subject = this.FLIMXObj.curSubject.getDatasetName();
            end
            %try to find subject in study
            if(any(strcmp(subject,this.FLIMXObj.fdt.getSubjectsNames(study,FDTree.defaultConditionName()))))
                %this is not a new file, we repick e.g. the ROI
                set(this.visHandles.radioExistingSubject,'Value',1);
                set(this.visHandles.editSubjectName,'String',this.FLIMXObj.curSubject.getDatasetName());
                subjects = this.FLIMXObj.fdt.getSubjectsNames(study,FDTree.defaultConditionName());
                idx = find(strcmp(subject,subjects));
                if(~isempty(idx))
                    set(this.visHandles.popupSubjectSel,'String',subjects,'Value',idx);
                end
            else
                this.currentSubject = subject;
            end
        end
        
        function setupGUI(this)
            %setup GUI controls
            if(this.isNewMeasurement)
                flag = 'on';
            else    
                flag = 'off';
            end            
            set(this.visHandles.radioNewStudy,'enable',flag);
            set(this.visHandles.radioNewSubject,'enable',flag);
            set(this.visHandles.popupSubjectSel,'enable',flag);
            set(this.visHandles.popupStudySel,'enable',flag);
            set(this.visHandles.editFile,'enable',flag);
            set(this.visHandles.buttonImport,'enable',flag);
            %channel popup
            cStr = sprintfc('Ch %d',1:this.myMeasurement.nrSpectralChannels);
            set(this.visHandles.popupChannel,'String',cStr,'Value',min(this.myMeasurement.nrSpectralChannels,this.currentChannel));
            %fileInfo
            set(this.visHandles.editTACRange,'String',this.myMeasurement.tacRange);
            set(this.visHandles.editNrTimeCh,'String',this.myMeasurement.nrTimeChannels);            
            fi = this.myMeasurement.getFileInfoStruct(this.currentChannel);
            this.resolution = fi.pixelResolution;
            if(strcmp(fi.position,'OD'))
                set(this.visHandles.popupPosition,'Value',1);
            else
                set(this.visHandles.popupPosition,'Value',2);
            end
            %study selection
            set(this.visHandles.popupStudySel,'String',this.FLIMXObj.fdt.getStudyNames());
            if(get(this.visHandles.radioExistingStudy,'Value'))
                set(this.visHandles.popupStudySel,'Visible','on');
                set(this.visHandles.editStudyName,'Visible','off');
            else
                set(this.visHandles.popupStudySel,'Visible','off');
                set(this.visHandles.editStudyName,'Visible','on');
                str = get(this.visHandles.popupStudySel,'String');
                if(~isempty(str) && iscell(str))
                    set(this.visHandles.editStudyName,'String',str{get(this.visHandles.popupStudySel,'Value')});
                end
            end
            %subject selection
            str = this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,FDTree.defaultConditionName());
            if(isempty(str))
                set(this.visHandles.radioExistingSubject,'Value',0,'Enable','off');
                set(this.visHandles.radioNewSubject,'Value',1);
                set(this.visHandles.popupSubjectSel,'String','-none-','Value',1,'Enable','off');
            else
                set(this.visHandles.popupSubjectSel,'String',str,'Value',min(length(str),get(this.visHandles.popupSubjectSel,'Value')));
                set(this.visHandles.radioExistingSubject,'Enable','on');
            end
            if(get(this.visHandles.radioExistingSubject,'Value'))
                set(this.visHandles.popupSubjectSel,'Visible','on');
                set(this.visHandles.editSubjectName,'Visible','off');
                %set subject popup to current subject
                idx = find(strcmp(str,this.currentSubject));
                if(~isempty(idx))
                    set(this.visHandles.popupSubjectSel,'Value',idx);
                end
            else
                set(this.visHandles.popupSubjectSel,'Visible','off');
                set(this.visHandles.editSubjectName,'Visible','on');
            end
            set(this.visHandles.editFile,'String',this.myMeasurement.getSourceFile());
            this.axesMgr.setReverseYDirFlag(this.FLIMXObj.paramMgr.getParamSection('general').reverseYDir);
        end
        
        function updateGUI(this)
            %update GUI            
            this.axesMgr.setMainData(this.myMeasurement.getRawDataFlat(this.currentChannel));
            this.updateROIControls([]);
        end
        
        function updateROIControls(this,roi)
            %apply limits to roi points and update roi display in GUI
            if(isempty(roi))
                roi = this.editFieldROIVec;
            end
            if(roi(4) <= this.myMeasurement.getRawYSz() && roi(2) <= this.myMeasurement.getRawXSz())
                data = this.myMeasurement.getRawDataFlat(this.currentChannel);
                if(~isempty(data))
                    data = data(roi(3):roi(4),roi(1):roi(2));
                end
            else
                data = [];
            end
            total = sum(data(:));
            set(this.visHandles.editTotalPh,'String',sprintf('%.2f million',total/1000000));
            set(this.visHandles.editAvgPh,'String',num2str(total/numel(data),'%.2f'));
            %this.FLIMXObj.FLIMFitGUI.plotRawDataROI(this.visHandles.axesROI,
            this.axesMgr.drawROIBox(roi);
            set(this.visHandles.textXWidth,'String',num2str(1+abs(roi(1)-roi(2))));
            set(this.visHandles.textYWidth,'String',num2str(1+abs(roi(3)-roi(4))));
        end
        
        
        %% GUI control callbacks
        function GUI_buttonImport_Callback(this,hObject, eventdata)
            %
            this.openFileByGUI();
        end
        
        function GUI_buttonOK_Callback(this,hObject, eventdata)
            %
            try
                set(hObject,'String',sprintf('<html><img src="file:/%s"/> OK</html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            m = this.myMeasurement;
            if(this.isDirty(1)) %1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
                %roi parameters were changed -> recompute
                if(~this.isNewMeasurement)
                    m.myParent.setMeasurementROICoord(this.finalROIVec);
                    %update all channels
                    for ch = 1:m.nrSpectralChannels
                        m.myParent.updateSubjectChannel(ch,'measurement');
                        this.FLIMXObj.FLIMFitGUI.updateProgressShort(0.50+0.5*ch/m.nrSpectralChannels,[],sprintf('%2.0f%% - Updating File Info',(0.50+0.5*ch/m.nrSpectralChannels)*100));
                    end
                else
                    %make sure we read all channels from the measurement file
                    for ch = 1:m.nrSpectralChannels
                        m.getRawDataFlat(ch);
                    end
                    this.myMeasurement.setROICoord(this.finalROIVec);
                end
            end
            if(this.isDirty(5)) %1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo                
                m.position = this.position;
                m.pixelResolution = this.resolution;
                if(~this.isNewMeasurement)
                    %update all channels
                    for ch = 1:m.nrSpectralChannels
                        m.myParent.updateSubjectChannel(ch,'measurement');
                        this.FLIMXObj.FLIMFitGUI.updateProgressShort(0.50+0.5*ch/m.nrSpectralChannels,[],sprintf('%2.0f%% - Updating File Info',(0.50+0.5*ch/m.nrSpectralChannels)*100));
                    end
                    this.FLIMXObj.FLIMFitGUI.updateProgressShort(0,[],'');
                end
            end
            if(this.isNewMeasurement)
                subject = this.FLIMXObj.fdt.getSubject4Import(this.currentStudy,this.currentSubject);
                if(~isempty(subject) && any(subject.myMeasurement.filesOnHDD))
                    button = questdlg(sprintf('Subject ''%s'' already exists in study ''%s''!\n\n\nDelete results and replace subject with current measurement?\n',this.currentSubject,this.currentStudy),...
                        'Overwrite subject?','Continue','Cancel','Cancel');
                    switch button
                        case 'Cancel'
                            return;
                    end
                end
                subject.importMeasurementObj(this.measurementObj);
                this.measurementObj = [];
                this.FLIMXObj.FLIMFitGUI.setupGUI();
                this.FLIMXObj.studyMgrGUI.updateGUI();
            else                
                if(this.FLIMXObj.FLIMFitGUI.isOpenVisWnd())
                    this.FLIMXObj.FLIMFitGUI.checkVisWnd();
                end
            end
            if(strcmp(this.currentStudy,this.FLIMXObj.FLIMFitGUI.currentStudy) && strcmp(this.currentSubject,this.FLIMXObj.FLIMFitGUI.currentSubject))
                this.FLIMXObj.setCurrentSubject(this.currentStudy,FDTree.defaultConditionName(),'');
                this.FLIMXObj.setCurrentSubject(this.currentStudy,FDTree.defaultConditionName(),this.currentSubject);
                this.FLIMXObj.FLIMFitGUI.currentChannel = this.currentChannel;
                this.FLIMXObj.FLIMVisGUI.updateGUI('');
            end
%             %check if we have enough photons per pixel
%             curROI = subject.getROIData(this.currentChannel,[],[],[]);
%             if(isa(curROI,'uint16') && max(curROI(:)) == intmax('uint16'))
%                 button = questdlg(sprintf('ROI-generation hit the maximum of specified integer type. As a result data may be distorted!\n\n\nDo you want to continue with the current ROI?\n\nDo you want to re-generate the ROI with a larger datatype (more RAM is required!)?\n'),...
%                     'Error generating ROI','Continue (corrupt Data)','re-Generate (more RAM)','re-Generate (more RAM)');
%                 switch button
%                     case 're-Generate (more RAM)'
%                         subject.setROIDataType('uint32');
%                 end
%             end
%             curROI = subject.getROIDataFlat(this.currentChannel,false);
%             mask = curROI < 10000;
%             px = numel(curROI);
%             per = sum(mask(:))/px;
%             if(per > 0.1)
%                 curROI = round(curROI./max(curROI(:))*63+1);
%                 curROI = ind2rgb(curROI,jet()); %fixed jet colormap for now
%                 markROI = zeros(size(curROI));
%                 mask = repmat(mask,[1 1 3]);
%                 curROI(mask) = markROI(mask); %mark problematic pixels in white
%                 image(curROI,'Parent',this.visHandles.axesROI);
%                 set(this.visHandles.axesROI,'YDir','normal');
%                 button = questdlg(sprintf('Warning! %.1f%% of the Pixels in the ROI have less than 10,000 Photons (marked in black in the current ROI plot). This may result in bad fitting results!\nIncreasing the Binning increases the Photons per Pixel.\n\nHow do you want to proceed?',per*100),'Too few Photons per Pixel! !','Change ROI Parameters','Continue with current ROI','Change ROI Parameters');
%                 switch button
%                     case 'Change ROI Parameters'
%                         %this.setupGUI();
%                         this.updateGUI();
%                         return
%                 end
%             end 
            
            %update all channels
%             for ch = 1:subject.nrSpectralChannels
%                 subject.myParent.updateSubjectChannel(subject,ch,'measurement');
%             end

            this.closeCallback();
        end
        
        function GUI_buttonCancel_Callback(this, hObject, eventdata)
            %
            this.closeCallback();
        end
        
        %popups
        function GUI_popupChannel_Callback(this,hObject, eventdata)
            %
            this.updateGUI();
        end
                
        function GUI_popupStudySel_Callback(this,hObject, eventdata)
            %user changed existing study
            this.setupGUI();
        end
        
        function GUI_popupSubjectSel_Callback(this,hObject, eventdata)
            %user changed existing subject
            this.setupGUI();
        end
        
        function GUI_popupPosition_Callback(this,hObject, eventdata)
            %user changed existing subject
            this.isDirty(5) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo            
        end
        
        %radio buttons
        function GUI_radioROI_Callback(this,hObject, eventdata)
            %
            switch get(hObject,'Tag')
                case 'radioAuto'
                    this.roiMode = 2;
                case 'radioCustom'
                    this.roiMode = 3;
                otherwise
                    %should not happen, we assume default = whole dataset
                    this.roiMode = 1;
            end
            this.isDirty(4) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
            this.isDirty(1) = true;
            roi = this.currentROIVec;
            this.editFieldROIVec = roi;
            this.finalROIVec = roi;
            this.updateGUI();
        end
        
        function GUI_radioStudy_Callback(this,hObject, eventdata)
            %user changed study source
            this.setupGUI();
        end
        
        function GUI_radioSubject_Callback(this,hObject, eventdata)
            %user changed subject name source
            this.setupGUI();
        end
                
        %edit fields
        function GUI_editFile_Callback(this,hObject, eventdata)
            %user enters file name manually
            fn = get(hObject,'String');
            if(exist(fn,'file') && this.openFileByStr(fn))
                this.setupGUI();
                this.updateGUI();
            end
        end
        
        function GUI_editResolution_Callback(this,hObject, eventdata)
            %
            set(hObject,'String',max(1,abs(str2double(get(hObject,'String')))));
            this.isDirty(5) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
            this.resolution = this.resolution;
        end
        
        function GUI_editROI_Callback(this,hObject, eventdata)
            %
            this.isDirty(1) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
            this.finalROIVec = this.editFieldROIVec;
            this.updateROIControls([]);
        end
                
        function GUI_editStudyName_Callback(this,hObject, eventdata)
            %user enters name for a new study
            newOrg = get(hObject,'String');
            i = 1;
            new = newOrg;
            while(any(strcmp(new,this.FLIMXObj.fdt.getStudyNames())))
                new = sprintf('%s%d',newOrg,i);
                i=i+1;
            end
            set(hObject,'String',new);
        end
        
        function GUI_editDSName_Callback(this,hObject, eventdata)
            %user enters name of new subject
            this.currentSubject = get(hObject,'String');
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %mouse callbacks
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function GUI_mouseButtonDown_Callback(this, hObject, eventdata)
            %executes on click in window
            if(this.roiMode ~= 3)
                return;
            end
            cp = get(this.visHandles.axesROI,'CurrentPoint');
            cp = cp(logical([1 1 0; 0 0 0]));
            if(any(cp(:) < 0))
                return;
            end
            set(this.visHandles.textXL,'String',round(abs(cp(1))));
            set(this.visHandles.textYL,'String',round(abs(cp(2))));
            this.buttonDown = true;
        end
        
        function GUI_mouseMotion_Callback(this, hObject, eventdata)
            %executes on mouse move in window
            cp = get(this.visHandles.axesROI,'CurrentPoint');
            cp = round(cp(logical([1 1 0; 0 0 0])));
            if(cp(1) >= 1 && cp(1) <= this.myMeasurement.getRawYSz() && cp(2) >= 1 && cp(2) <= this.myMeasurement.getRawXSz())
                %inside axes
                set(this.visHandles.importWizardFigure,'Pointer','cross');
                if(this.buttonDown)
                    set(this.visHandles.textXH,'String',round(abs(cp(1))));
                    set(this.visHandles.textYH,'String',round(abs(cp(2))));
                    roi = [str2double(get(this.visHandles.textXL,'String')), cp(1),...
                        str2double(get(this.visHandles.textYL,'String')), cp(2)];
                    this.updateROIControls(roi);
                else
                    set(this.visHandles.textXL,'String',round(abs(cp(1))));
                    set(this.visHandles.textYL,'String',round(abs(cp(2))));
                end
                %update current point field
                raw = this.myMeasurement.getRawDataFlat(this.currentChannel);
                if(~isempty(raw))
                    str = FLIMXFitGUI.num4disp(raw(min(size(raw,1),cp(2)),min(size(raw,2),cp(1))));
                    this.mouseOverlay.draw(cp,[sprintf('x:%d y:%d',cp(1),cp(2));str]);
                    this.mouseOverlay.displayBoxOnTop();
                end
            else
                set(this.visHandles.importWizardFigure,'Pointer','arrow');
                this.editFieldROIVec = this.finalROIVec;
                this.updateROIControls([]);
                this.mouseOverlay.clear();
            end
        end
        
        function GUI_mouseButtonUp_Callback(this, hObject, eventdata)
            %executes on click in window
            if(this.roiMode ~= 3)
                return;
            end
            cp = get(this.visHandles.axesROI,'CurrentPoint');
            cp = cp(logical([1 1 0; 0 0 0]));
            if(any(cp(:) < 0))
                return;
            end
            this.buttonDown = false;
            cXl = str2double(get(this.visHandles.textXL,'String'));
            cXu = round(abs(cp(1)));
            cYl = str2double(get(this.visHandles.textYL,'String'));
            cYu = round(abs(cp(2)));
            this.editFieldROIVec = [min(cXl,cXu), max(cXl,cXu), min(cYl,cYu), max(cYl,cYu)];
            this.finalROIVec = this.editFieldROIVec;
            this.isDirty(1) = true; %flags which part was changed, 1-roi, 2-irf, 3-binning, 4-roi mode, 5-fileInfo
            this.updateROIControls([]);
        end
    end
    
    methods(Static)
        function roi = getAutoROI(imgFlat,roiBinning)
            %try to determine a reasonable ROI
            if(isempty(imgFlat))
                roi = [];
                return
            end
            th = sum(imgFlat(:) / numel(imgFlat));
            bin = imgFlat >= th*0.5; %fitParams.roi_autoThreshold;
            bin =  imerode(bin,strel('square', max(1,roiBinning)));
            xl = find(any(bin,1),1,'first');
            xh = find(any(bin,1),1,'last');
            yl = find(any(bin,2),1,'first');
            yh = find(any(bin,2),1,'last');
            bin = bin(yl:yh,xl:xh);
            %finetune a bit
            rows = sum(bin,2) > size(bin,1)/10;
            cols = sum(bin,1) > size(bin,2)/10;
            xl_old = xl;
            yl_old = yl;
            xl = xl_old-1+find(cols,1,'first');
            xh = xl_old-1+find(cols,1,'last');
            yl = yl_old-1+find(rows,1,'first');
            yh = yl_old-1+find(rows,1,'last');
            roi = [xl xh yl yh];
        end
        
        function [fn, fi] = loadFile(filetype,menu_text,start_path,multi_select)
            %load file(s) and return filenames and filterindex
            if(nargin < 4)
                multi_select = 'off';
            end
            fn = [];
            [file,path,fi] = uigetfile(filetype,menu_text,start_path,'MultiSelect', multi_select);
            if(ischar(file))
                fn = fullfile(path,file);
            elseif(iscell(file))
                fn = cell(length(file),1);
                for i = 1:length(file)
                    fn{i} = fullfile(path,file{i});
                end
            else
                return
            end
        end        
    end %methods(Static)
end
classdef simFLIM < handle
    %=============================================================================================================
    %
    % @file     simFLIM.m
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
    % @brief    A class to represent the simulation tool
    %
    properties(GetAccess = public, SetAccess = private)
        FLIMXObj = [];          %handle to FLIMX object
        visHandles = [];        %structure to handles in GUI
        mySimSubject = [];       %handle to simulation subject object
        mySelection = [];       %names of selected parameter set in table
        stop = false;        
    end
    
    properties (Dependent = true)
        currentApObj = [];
        exportAsSDT = false;
        addBatchJob = false;
        currentStudy = '';
        currentChannel = 1;
        currentIRF = [];
        currentSynthDataCh = [];
        currentSynthDataDef = [];
        currentSynthDataName = '';
        currentSource = [];
        fileInfo = [];
        pixelFitParams = [];
        volatilePixelParams = [];
        preProcessParams = [];
        basicParams = [];
        FLIMXvolatilePixelParams = [];
        computationParams = [];
        fluoDecayFitVisParams = [];
        autoPreview = false;
        paramMgrObj = [];
    end
    
    methods
        function this = simFLIM(flimX)
            %constructor for paraSetMgrGUI
            this.FLIMXObj = flimX;
            %get current config
            this.newSimSubject([]);
        end
        
        function newSimSubject(this,sdc)
            %update mySimSubject based on sdc
            this.mySimSubject = this.getSimSubject(sdc);            
        end
        
        function out = getSimSubject(this,sdc)
            %create a new simSubject based on sdc
            out = subject4Sim(this.currentStudy,sdc,this.FLIMXObj.paramMgr,this.FLIMXObj.irfMgr);
            out.update();
            out.updatebasicParams(sdc);            
            out.preProcessParams.roiBinning = 0;
            out.preProcessParams.roiAdaptiveBinEnable = 0;
        end
        
        %%dependent properties
        function out = get.paramMgrObj(this)
            out = this.mySimSubject.myParamMgr;
        end
        
        function out = get.currentApObj(this)
            %make parameter structure needed for approximation
%             allIRFs{this.currentChannel} = this.currentIRF;
%             fileInfo(this.currentChannel) = this.fileInfo;
%             params.volatilePixel = this.volatilePixelParams;
%             params.volatileChannel = this.paramMgrObj.getParamSection('volatileChannel');
%             params.basicFit = this.basicParams;
%             params.preProcessing = [];
%             params.computation = this.computationParams;
%             params.bounds = [];
%             params.pixelFit = this.pixelFitParams;
%             out = fluoPixelModel(allIRFs,fileInfo,params);
%             out.setCurrentChannel(this.currentChannel);
            out = this.mySimSubject.getApproxObj(this.currentChannel,1,1);
        end
        
        function out = get.exportAsSDT(this)
            %returns boolean flag if user wants sdt files
            if(this.isOpenVisWnd())
                out = get(this.visHandles.checkSDT,'Value');
            else
                out = false;
            end
        end
        
        function out = get.addBatchJob(this)
            %returns boolean flag if user wants to generate batch jobs
            if(this.isOpenVisWnd())
                out = get(this.visHandles.checkBatchJob,'Value');
            else
                out = false;
            end
        end
        
        function out = get.autoPreview(this)
            %returns boolean flag to signalize auto preview
            if(this.isOpenVisWnd())
                out = get(this.visHandles.checkAutoPreview,'Value');
            else
                out = true;
            end
        end
        
        function out = get.currentStudy(this)
            %returns current study
            out = '';
            if(this.isOpenVisWnd())
                str = get(this.visHandles.popupStudy,'String');
                if(~isempty(str) && iscell(str))
                    out = str{get(this.visHandles.popupStudy,'Value')};
                elseif(ischar(str))
                    out = str;
                end
            end
        end
        
        function out = get.currentChannel(this)
            %returns current spectral channel
            out = [];
            if(this.isOpenVisWnd())
                out = get(this.visHandles.popupChannel,'Value');
            end
            if(isempty(out))
                out = 1; %just some default value
            end
        end
                
        function out = get.currentSynthDataCh(this)
            %returns the current simulation parameter channel
            out = this.getSynthDataCh(this.currentSynthDataName,this.currentChannel);
        end
        
        function out = get.currentSynthDataDef(this)
            %returns the current synthetic data definition (consists ofchannels)
            out = this.getSynthDataDef(this.currentSynthDataName);
        end
        
        function out = get.currentSynthDataName(this)
            %returns the name of current synthetic data set
            out = [];
            if(~isempty(this.mySelection))
                out = this.mySelection{1};
            end
        end
        
        function out = get.currentSource(this)
            %returns the number of current source selection
            out = [];
            if(this.isOpenVisWnd())
                if(get(this.visHandles.radioSourceUser,'Value'))
                    out = 1;
                    return
                end
                if(get(this.visHandles.radioSourceLastResult,'Value'))
                    out = 2;
                    return
                end
                out = 3;
            end
        end
                
        function params = get.fileInfo(this)
            %get file info struct of simulation file
            if(isempty(this.mySimSubject))
                params = [];
            else
                params = this.mySimSubject.getFileInfoStruct(this.currentChannel);
            end
        end
                
        function params = get.FLIMXvolatilePixelParams(this)
            %get basic fit parameters
            params = this.FLIMXObj.paramMgr.getParamSection('volatile');
        end
        
        function params = get.fluoDecayFitVisParams(this)
            %get current FLIMXFitGUI visualization parameters
            params = this.FLIMXObj.paramMgr.getParamSection('fluo_decay_fit_gui');
        end
        
        function set.currentChannel(this,new)
            %set current spectral channel
            if(this.isOpenVisWnd())
                set(this.visHandles.popupChannel,'Value',min(new,length(get(this.visHandles.popupChannel,'String'))));
                this.setupGUI();
                this.updateGUI();
            end
        end
        
        %% output methods
        function [szX, szY, szTime, nExp, photons, offset, sdt, xVec, tci] = getSimParams(this,id,ch)
            %get simulation parameters for selected parameter set
            sdc = this.getSynthDataCh(id,ch);
            if(~isempty(sdc))
                %user generated data
                szX = sdc.sizeX;
                szY = sdc.sizeY;
                szTime = sdc.nrTimeChannels;
                nExp = sdc.nrExponentials;
                photons = sdc.nrPhotons;
                sdt = 0; %this.exportAsSDT;
                offset = sdc.offset;
                xVec = sdc.xVec;
                if(~isempty(xVec))
                    as = sum([xVec(1:nExp); offset]);
                    offset = offset./as;
                    xVec(1:nExp) = xVec(1:nExp)./as;
                end
                tci = sdc.tciVec;
            else
                szX = str2double(get(this.visHandles.editSizeX,'String'));
                szY = str2double(get(this.visHandles.editSizeX,'String'));
                switch get(this.visHandles.popupTime,'Value')
                    case 1
                        szTime = 1024;
                    case 2
                        szTime = 4096;
                end
                nExp = str2double(get(this.visHandles.editExponentials,'String'));
                photons = str2double(get(this.visHandles.editPhotons,'String'));
                offset = str2double(get(this.visHandles.editOffsetPhotons,'String'));
                sdt = this.exportAsSDT;
                %                 switch this.sourceSel
                %                     case 2
                %                         %last result
                %                         data = get(this.visHandles.tableParams,'data');
                %                         data(:,3) = -1.*round(data(:,3)./this.fileInfo.timeChannelWidth).*this.fileInfo.timeChannelWidth;
                %                         xVec = zeros(3*nExp+3,1);
                %                         xVec(1:nExp) = data(:,1)./100;
                %                         xVec(nExp+1:2*nExp) = data(:,2);
                %                         tci = abs(data(:,3));
                %                         if(nExp > 1)
                %                             xVec(2*nExp+1:3*nExp) = tci;
                %                         end
                %                         xVec(end-2) = 1;    %vShift;
                %                         xVec(end-1) = 1;    %hShift;
                %                         xVec(end) = offset/100; %offset
                %                     case 3
                %                         %last data
                %                 end
            end
        end
        
        function out = getSynthDataCh(this,name,ch)
            %get simultation parameter set by name and channel
            out = this.FLIMXObj.sDDMgr.getSDDChannel(name,ch);
        end
        
        function out = getSynthDataDef(this,name)
            %get simultation parameter set by name
            out = this.FLIMXObj.sDDMgr.getSDD(name);
        end
        
        function exportParaSet(this,paraSetName,batchJobFlag)
            %export simulation data to FDTree and optional to batch job manager
%             %check if we have one of the subjects currently loaded in FLIMXFitGUI
%             if(strcmp(this.currentStudy,this.FLIMXObj.FLIMFitGUI.currentStudy) && any(strcmp(paraSetName,this.FLIMXObj.FLIMFitGUI.currentSubject)) && any(this.FLIMXObj.curSubject.isDirty)) 
%                     button = questdlg(sprintf('Subject %s of study %s is currently loaded in FLIMXFitGUI and contains unsaved results.\n\n'),'Approximation Result Changed','Yes','No','Yes');
%                     switch button
%                         case 'Yes'
%                             this.saveCurResultInFDT();
%                     end
%             end            
            %check if we have subjects already in FDTree
            subjects = this.FLIMXObj.fdt.getSubjectsNames(this.currentStudy,FDTree.defaultConditionName());
            if(any(strcmp(paraSetName,subjects)))
                %synthetic data (subject) already in study
                choice = questdlg(sprintf('Study "%s" already contains a subject called "%s". Do you want to overwrite?',this.currentStudy,paraSetName),...
                        'Overwrite subject?','Yes','No','No');
                    switch choice
                        case 'No'
                        return
                    end
            end
            %make synthetic data
            sdd = this.getSynthDataDef(paraSetName);
            [~,mask] = sdd.nonEmptyChannelStr();
            chNrs = find(mask)';
            for ch = chNrs
                sdc = sdd.getChannel(ch);
                if(isempty(sdc))
                    continue
                end
                %reset simulation data
                this.mySimSubject.updatebasicParams(sdc); %todo: really needed?
                raw = this.makeSimMExpDec(sdc.sizeX,sdc.sizeY,sdc);
                params = this.FLIMXObj.paramMgr.getParamSection('batchJob');
                params.pre_processing.roiBinning = 0;
                
                if(ch == chNrs(1))
                    %first non-empty channel
                    this.newSimSubject(sdc);
                    this.mySimSubject.setSubjectName(paraSetName);
                end
                this.mySimSubject.setMeasurementData(ch,raw);
                this.mySimSubject.getROIData(ch,1,1);                
%                 if(~any(this.FLIMXvolatilePixelParams.globalFitMask))
%                     %non global fit job
%                     
%                     jobID = sprintf('%s ch%02d',jname,ch);    %workaround to avoid overwriting of batch job with first channel
%                     this.FLIMXObj.batchMgrObj.newJob(jobID,params,this.mySimSubject.getFileInfoStruct(ch),raw);
%                     this.FLIMXObj.batchJobMgrGUI.updateGUI();
%                 else
%                     this.mySimSubject.setRawData(ch,raw);
%                     this.mySimSubject.getROIData(ch,[]);
%                 end
            end
            %add to fdtree
            this.mySimSubject.setStudy(this.currentStudy);
            this.mySimSubject.setSubjectName(paraSetName);
%             this.FLIMXObj.fdt.removeSubjectResult(this.currentStudy,paraSetName
            this.FLIMXObj.fdt.importSubject(this.mySimSubject);
            if(strcmp(this.currentStudy,this.FLIMXObj.FLIMFitGUI.currentStudy) && any(strcmp(paraSetName,this.FLIMXObj.FLIMFitGUI.currentSubject)) && any(this.FLIMXObj.curSubject.isDirty))
                %we have one of the subjects currently loaded in FLIMXFitGUI
                %flush the result and reload the subject
%                 this.FLIMXObj.curSubject.setDirty(find(this.FLIMXObj.curSubject.isDirty),false(this.FLIMXObj.curSubject.isDirty,1));
                this.FLIMXObj.setCurrentSubject(this.currentStudy,FDTree.defaultConditionName(),paraSetName);
            end
            %add to batchjob manager
            if(batchJobFlag)
                jname = sprintf('simData %s',paraSetName);
                jobs = this.FLIMXObj.batchJobMgr.getAllJobsInfo();
                if(any(strncmp(jname,jobs(:,1),length(jname))))
                    %parameter set already assigned to batch job manager
                    choice = questdlg(sprintf('Parameter set "%s" is already assigned to batch job manager. Do you want to overwrite?',jname),...
                        'Overwrite parameter set?','Yes','No','No');
                    switch choice
                        case 'Yes'
                            %delete old job(s)
                            for i=1:size(jobs,1)
                                if(strncmp(jname,jobs(i,1),length(jname)))
                                    this.FLIMXObj.batchJobMgr.deleteJob(jobs{i,1});
                                end
                            end
                        case 'No'
                            return
                    end
                end
%                 if(any(this.FLIMXvolatilePixelParams.globalFitMask))
%                     %add global fit job
                    this.FLIMXObj.batchJobMgr.newJob(jname,params,this.mySimSubject,[]);
                this.FLIMXObj.batchJobMgrGUI.updateGUI();
            end
        end
        
        function [raw, model] = makeSimMExpDec(this,szX,szY,sdc)
            %generate synthetic FLIM data
            if(~isempty(sdc.xVec) && length(sdc.xVec) >= 2*sdc.nrExponentials && any(sdc.xVec(1:sdc.nrExponentials)))
                %we got a set of parameters
%                 irf = this.FLIMXObj.irfMgr.getIRF(sdc.IRFName,sdc.channelNr,sdc.nrTimeChannels);
                if(isempty(this.mySimSubject))
                    this.newSimSubject(sdc);
                end
                xVec = sdc.xVec;
                xVec(1:sdc.nrExponentials) = xVec(1:sdc.nrExponentials)./sum(xVec(1:sdc.nrExponentials));
                oset = xVec(end);
                %xVec(end) = 0;
                %build approximation object
%                 allIRFs{sdc.channelNr} = irf;
%                 fileInfo(sdc.channelNr) = this.fileInfo;
%                 params.volatilePixel = this.volatilePixelParams;
%                 params.volatileChannel = this.paramMgrObj.getParamSection('volatileChannel');
%                 params.basicFit = this.basicParams;
%                 params.preProcessing = [];
%                 params.computation = this.computationParams;
%                 params.bounds = [];
%                 params.pixelFit = this.pixelFitParams;
%                 apObj = fluoPixelModel(allIRFs,fileInfo,params);
                apObj = this.mySimSubject.getApproxObj(sdc.channelNr,1,1);
                %apObj.setCurrentChannel(sdc.channelNr);
                %make model vector
                model = zeros([1 1 sdc.nrTimeChannels]);
                model(1,1,:) = apObj.getModel(sdc.channelNr,apObj.getNonConstantXVec(sdc.channelNr,xVec)); %fixme
            elseif(~isempty(sdc.modelData))
                %we got a data vector
                model = sdc.modelData;
                oset = 0;
            else
                raw = [];
                model = [];
                return
            end
            %offset is given in photons, amplitudes are relative -> handle offset seperately
            model = model - oset;
            %oset is average value for offset photons in all time channels -> calculate total nr of offset photons
            osetPhotons = round(oset * sdc.nrTimeChannels);
            %photons for exponentials are the remaining photons
            expPhotons = max(0,round(sdc.nrPhotons - osetPhotons));
            mmax = max(model,[],3);
            model = repmat(model,[szY szX 1]);
            %generate the random photon distributions for exponentials
            raw = simFLIM.sampleMExpDec(reshape(model,[],sdc.nrTimeChannels),expPhotons);
            %generate the random photon distributions for offset
            osetRaw = simFLIM.sampleMExpDec(ones(size(raw)),osetPhotons);
            %reshape to desired height and width
            raw = reshape(raw,szY, szX,sdc.nrTimeChannels);
            osetRaw = reshape(osetRaw,szY, szX,sdc.nrTimeChannels);
            if(nargout == 2)
                %scale model function to data
                rmax = max(raw,[],3);
                model = bsxfun(@times,model,rmax./mmax);
                model = model + oset;
            end
            raw = raw + osetRaw;            
        end
        
        function sdc = updateSynthDataDef(this,oldParams)
            %update simulation parameters to current revision
            if(~isfield(oldParams,'revision'))
                %create revision field
                oldParams.revision = 1;
                try
                    oldParams = rmfield(oldParams,{'rangeParameterID','rangeStart','rangeStep','rangeEnd'});
                catch
                    %
                end
                this.setDirty();
            end
            
            if(oldParams.revision < 2)
                oldParams.fixedQ = 0;
                oldParams.revision = 2;
                this.setDirty();
            end
            
            if(oldParams.revision < 3)
                oldParams.tacRange = 12.5084; %just some default value
                oldParams.channel = 1; %just some default value
                oldParams.revision = 3;
                this.setDirty();
            end
            
            if(oldParams.revision < 4)
                oldParams.arrayParentSDD = [];  %name of parent parameter set (for parameter set arrays)
                oldParams.arrayParamName = 0; %ID of array parameter
                this.setDirty();
            end
            
            if(oldParams.revision < 5)
                if(isempty(oldParams.raw))
                    [oldParams.raw, oldParams.model] = this.makeSimMExpDec(1,1,oldParams);
                end
                this.setDirty();
            end
            
            if(oldParams.revision < 6)
                %revision 6 introduces simulation parameter sets with multiple channels
                new.channels = cell(2,1);  %cell array to store two spectral channels
                oldParams.nrSpectralChannels = 1;
                new.channels{1} = oldParams;
                oldParams = new;
                oldParams.revision = 6;
                this.setDirty();
            end
            
            if(oldParams.revision < 7)
                for ch = 1:length(oldParams.channels)
                    if(~isempty(oldParams.channels{ch}))
                        oldParams.channels{ch}.dataSourceType = 1; %1: user defined parameters, 2: result parameters, 3: data
                        oldParams.channels{ch}.dataSourceDatasetName = '';
                        oldParams.channels{ch}.dataSourcePos = [];
                    end
                end
                oldParams.revision = 7;
                this.setDirty();
            end
            sdc = oldParams;
        end
        
        %% computation and other functions
        function createVisWnd(this)
            %make new window for parameter set manager
            this.visHandles = GUI_simFLIM();
            set(this.visHandles.simFLIMFigure,'CloseRequestFcn',@this.GUI_buttonClose_Callback);
            %set callbacks
            %buttons            
            set(this.visHandles.buttonClose,'Callback',@this.GUI_buttonClose_Callback);
            set(this.visHandles.buttonSave,'Callback',@this.GUI_buttonSave_Callback);
            set(this.visHandles.buttonExportSel,'Callback',@this.GUI_buttonExportSel_Callback);
            set(this.visHandles.buttonExportAll,'Callback',@this.GUI_buttonExportAll_Callback);
            set(this.visHandles.buttonAddSet,'Callback',@this.GUI_buttonAddSet_Callback);
            set(this.visHandles.buttonRemoveSet,'Callback',@this.GUI_buttonRemoveSet_Callback);
            set(this.visHandles.buttonRemoveAllSets,'Callback',@this.GUI_buttonRemoveAllSets_Callback);
            set(this.visHandles.buttonDuplicateSet,'Callback',@this.GUI_buttonDuplicateSet_Callback);
            set(this.visHandles.buttonDecExp,'Callback',@this.GUI_buttonChangeExp_Callback);
            set(this.visHandles.buttonIncExp,'Callback',@this.GUI_buttonChangeExp_Callback);
            set(this.visHandles.buttonShowInFluo,'Callback',@this.GUI_buttonShowInFluo_Callback);
            set(this.visHandles.buttonRename,'Callback',@this.GUI_buttonRename_Callback);
            set(this.visHandles.buttonCreateParaSetArray,'Callback',@this.GUI_buttonCreateParaSetArray_Callback);
            set(this.visHandles.buttonNewStudy,'Callback',@this.GUI_buttonNewStudy_Callback);
            set(this.visHandles.buttonStop,'Callback',@this.GUI_buttonStop_Callback);
            %edits
            set(this.visHandles.editSizeX,'Callback',@this.GUI_editSizeX_Callback);
            set(this.visHandles.editSizeY,'Callback',@this.GUI_editSizeY_Callback);
            set(this.visHandles.editExponentials,'Callback',@this.GUI_editExponentials_Callback);
            set(this.visHandles.editPhotons,'Callback',@this.GUI_editPhotons_Callback);
            set(this.visHandles.editShift,'Callback',@this.GUI_editShift_Callback);
            set(this.visHandles.editOffsetPhotons,'Callback',@this.GUI_editOffsetPhotons_Callback);
            set(this.visHandles.editArrayStart,'Callback',@this.GUI_editArray_Callback);
            set(this.visHandles.editArrayStep,'Callback',@this.GUI_editArray_Callback);
            set(this.visHandles.editArrayEnd,'Callback',@this.GUI_editArray_Callback);
            %popups
            set(this.visHandles.popupTime,'Callback',@this.GUI_popupTime_Callback);
            set(this.visHandles.popupIRF,'Callback',@this.GUI_popupIRF_Callback);
            set(this.visHandles.popupArrayParameter,'Callback',@this.GUI_popupArrayParameter_Callback);
            set(this.visHandles.popupChannel,'Callback',@this.GUI_popupChannel_Callback);
            %tables
            set(this.visHandles.tableParameterSets,'CellSelectionCallback',@this.GUI_tableParameterSets_CellSelectionCallback);
            set(this.visHandles.tableParameterSets,'CellEditCallback',@this.GUI_tableParameterSets_CellEditCallback);
            %checkboxes
            set(this.visHandles.checkSDT,'Callback',@this.GUI_checkSDT_Callback);
            set(this.visHandles.checkAutoPreview,'Callback',@this.GUI_checkAutoPreview_Callback,'Value',1);
            set(this.visHandles.checkFixedQ,'Callback',@this.GUI_checkFixedQ_Callback);
            set(this.visHandles.checkAllChannels,'Callback',@this.GUI_checkAllChannels_Callback);
            %table
            set(this.visHandles.tableParams,'CellEditCallback',@this.GUI_tableParaSetsEdit_Callback);
            %radio buttons
            set(this.visHandles.radioSourceUser,'Callback',@this.GUI_radioSource_Callback);
            set(this.visHandles.radioSourceLastResult,'Callback',@this.GUI_radioSource_Callback);
            set(this.visHandles.radioSourceData,'Callback',@this.GUI_radioSource_Callback);
            %axes
            set(this.visHandles.axesProgress,'XLim',[0 100],...
                'YLim',[0 1],...
                'Box','on', ...
                'FontSize', get(0,'FactoryAxesFontSize'),...
                'XTickMode','manual',...
                'YTickMode','manual',...
                'XTick',[],...
                'YTick',[],...
                'XTickLabelMode','manual',...
                'XTickLabel',[],...
                'YTickLabelMode','manual',...
                'YTickLabel',[]);
            xpatch = [0 0 0 0];
            ypatch = [0 0 1 1];
            this.visHandles.patchWait = patch(xpatch,ypatch,'r','EdgeColor','r','Parent',this.visHandles.axesProgress);%,'EraseMode','normal'
            this.visHandles.textWait = text(1,0,'','Parent',this.visHandles.axesProgress);
            this.FLIMXObj.sDDMgr.scanForSDDs();
            allNames = this.FLIMXObj.sDDMgr.getAllSDDNames();
            if(~isempty(allNames))
                this.mySelection = allNames(1);
                sdd = this.currentSynthDataDef;
                [~, mask] = sdd.nonEmptyChannelStr();
                ch = find(mask,1);
                sdc = sdd.getChannel(ch);
                if(~isempty(ch))
                    set(this.visHandles.popupChannel,'Value',ch);
                end
                this.newSimSubject(sdc);
            else
                this.newSimSubject([]);
            end            
        end
        
        function checkVisWnd(this)
            %check if window is open
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.setupGUI();
            this.updateGUI();
            figure(this.visHandles.simFLIMFigure);
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.simFLIMFigure) || ~strcmp(get(this.visHandles.simFLIMFigure,'Tag'),'simFLIMFigure'));
        end
        
        function setupGUI(this)
            %setup GUI controls
            if(~this.isOpenVisWnd())
                return
            end
            studies = this.FLIMXObj.fdt.getStudyNames();
            set(this.visHandles.popupStudy,'String',studies,'Value',min(get(this.visHandles.popupStudy,'Value'),length(studies)));
            [names, chStr] = this.FLIMXObj.sDDMgr.getAllSDDNames();
            set(this.visHandles.tableParameterSets,'Data',[names chStr]);
            %init sim tool
            if(this.FLIMXObj.curSubject.isPixelResult(this.currentChannel))
                set(this.visHandles.radioSourceLastResult,'Enable','on');
                set(this.visHandles.textSourceLastResult,'Enable','on');
            else
                set(this.visHandles.radioSourceLastResult,'Enable','off');
                set(this.visHandles.textSourceLastResult,'Enable','off');
            end
            if(isempty(this.FLIMXObj.FLIMFitGUI.currentDecayData))
                set(this.visHandles.radioSourceData,'Enable','off');
                set(this.visHandles.textSourceData,'Enable','off');
            else
                set(this.visHandles.radioSourceData,'Enable','on');
                set(this.visHandles.textSourceData,'Enable','on');
            end
            %if(get(this.visHandles.checkSDT,'Value'))
            if(this.exportAsSDT)
                set(this.visHandles.editSizeY,'Enable','Off');
            else
                set(this.visHandles.editSizeY,'Enable','On');
            end
            sdc = this.currentSynthDataCh;
            %update parameter set array controls
            apStr = {'Photons'};
            apID = 1;
            if(~isempty(sdc) && sdc.dataSourceType ~= 3)
                apStr(2) = {'Offset'};
                apStr(end+1:end+3*sdc.nrExponentials) = cell(3*sdc.nrExponentials,1);
                for i = 1:sdc.nrExponentials
                    apStr(i+2) = {sprintf('Amplitude %d',i)};
                    apStr(i+2+sdc.nrExponentials) = {sprintf('Tau %d',i)};
                    apStr(i+2+2*sdc.nrExponentials) = {sprintf('tc %d',i)};
                end
                if(~isempty(sdc.arrayParamName))
                    apID = find(strcmp(apStr,sdc.arrayParamName),1);
                    if(isempty(apID))
                        %we didn't find our arrayParameter name
                        apStr(end+1) = sdc.arrayParamName;
                        apID = length(apStr);
                    end
                end
            end
            set(this.visHandles.popupArrayParameter,'String',apStr,'Value',apID);
            %sdc = sdd.getChannel(newCh);
            if(isempty(sdc))
                set(this.visHandles.buttonCreateParaSetArray,'Enable','Off');
                set(this.visHandles.buttonDecExp,'Enable','Off');
                set(this.visHandles.buttonIncExp,'Enable','Off');
                set(this.visHandles.editSizeX,'Enable','Off');
                set(this.visHandles.editSizeY,'Enable','Off');
                set(this.visHandles.editExponentials,'Enable','Off');
                set(this.visHandles.editPhotons,'Enable','Off');
                set(this.visHandles.popupTime,'Enable','Off');
                set(this.visHandles.popupIRF,'Enable','Off');
                set(this.visHandles.tableParams,'Enable','Off');
                set(this.visHandles.editShift,'Enable','off');
                set(this.visHandles.editOffsetPhotons,'Enable','off');
                %enable edit fields for parameter set array
                set(this.visHandles.editArrayStart,'Enable','Off','String','');
                set(this.visHandles.editArrayStep,'Enable','Off','String','');
                set(this.visHandles.editArrayEnd,'Enable','Off','String','');
                set(this.visHandles.editArrayNrSets,'Enable','Off','String','');
                return
            end
            %enable edit fields for parameter set array
            set(this.visHandles.buttonCreateParaSetArray,'Enable','On');
            set(this.visHandles.editArrayStart,'Enable','On','String',num2str(sdc.arrayParamStart));
            set(this.visHandles.editArrayStep,'Enable','On','String',num2str(sdc.arrayParamStep));
            set(this.visHandles.editArrayEnd,'Enable','On','String',num2str(sdc.arrayParamEnd));
            %channels
            sdd = this.currentSynthDataDef;
            val = 0;
            if(~isempty(sdd))
                [~,mask] = sdd.nonEmptyChannelStr();
                val = all(mask) && length(mask) > 1;
            end
            set(this.visHandles.checkAllChannels,'Enable','On','Value',val);
            set(this.visHandles.popupChannel,'Value',sdc.channelNr,'Enable','on');
            %size
            set(this.visHandles.editSizeX,'String',num2str(sdc.sizeX),'Enable','On');
            set(this.visHandles.editSizeY,'String',num2str(sdc.sizeY),'Enable','On');
            if(sdc.dataSourceType == 1)
                %user defined (table)
                set(this.visHandles.radioSourceUser,'Value',1);
                set(this.visHandles.radioSourceLastResult,'Value',0);
                set(this.visHandles.radioSourceData,'Value',0);
                if(~isempty(this.FLIMXObj.sDDMgr.getAllSDDNames()))
                    set(this.visHandles.buttonExportSel,'Enable','On');
                    set(this.visHandles.buttonExportAll,'Enable','On');
                else
                    set(this.visHandles.tableParameterSets,'Data',[]);
                    set(this.visHandles.buttonExportSel,'Enable','Off');
                    set(this.visHandles.buttonExportAll,'Enable','Off');
                end
                set(this.visHandles.tableParams,'Enable','On');
                %photons
                set(this.visHandles.editPhotons,'String',num2str(sdc.nrPhotons),'Enable','On');
                %IRF
                IRFnames = this.FLIMXObj.irfMgr.getIRFNames(sdc.nrTimeChannels);
                set(this.visHandles.popupIRF,'String',IRFnames);
                [tf pos] = ismember(sdc.IRFName,IRFnames);
                if(tf)
                    set(this.visHandles.popupIRF,'Value',pos,'Enable','On');
                else
                    set(this.visHandles.popupIRF,'Value',1,'Enable','On');
                end
                %time resolution
                switch(sdc.nrTimeChannels)
                    case 1024
                        set(this.visHandles.popupTime,'Value',1,'Enable','On');
                    case 4096
                        set(this.visHandles.popupTime,'Value',2,'Enable','On')
                end
                set(this.visHandles.editExponentials,'Enable','On');
                set(this.visHandles.buttonIncExp,'Enable','On');
                set(this.visHandles.buttonDecExp,'Enable','On');
                set(this.visHandles.editShift,'Enable','On');
                set(this.visHandles.editOffsetPhotons,'Enable','On');
                set(this.visHandles.checkFixedQ,'Enable','on','Value',sdc.fixedQ);
            else
                %result/data
                set(this.visHandles.radioSourceUser,'Value',0);
                set(this.visHandles.popupTime,'Enable','Off');
                set(this.visHandles.popupIRF,'Enable','Off');
                set(this.visHandles.tableParams,'Enable','off');
                set(this.visHandles.editExponentials,'Enable','off');
                set(this.visHandles.buttonIncExp,'Enable','off');
                set(this.visHandles.buttonDecExp,'Enable','off');                
                set(this.visHandles.editShift,'Enable','off');
                set(this.visHandles.editOffsetPhotons,'Enable','off');
                set(this.visHandles.checkFixedQ,'Enable','off','Value',0);
                %                 if(strcmp(sdc.dataSourceDatasetName,this.FLIMXObj.curFluoFile.getDatasetName()))
                %                     set(this.visHandles.checkAllChannels,'Enable','On');
                %                     set(this.visHandles.popupChannel,'Enable','on');
                %                 else
                %                     set(this.visHandles.checkAllChannels,'Enable','Off');
                %                     set(this.visHandles.popupChannel,'Enable','off');
                %                 end
            end
            if(sdc.dataSourceType == 2)
                %result
                set(this.visHandles.radioSourceLastResult,'Value',1);
                set(this.visHandles.radioSourceData,'Value',0);
                set(this.visHandles.editPhotons,'String',num2str(sdc.nrPhotons),'Enable','off');
            elseif(sdc.dataSourceType == 3)
                %data
                set(this.visHandles.radioSourceLastResult,'Value',0);
                set(this.visHandles.radioSourceData,'Value',1);
                set(this.visHandles.editPhotons,'String',num2str(sdc.nrPhotons),'Enable','on');
                set(this.visHandles.popupIRF,'String','-');
                set(this.visHandles.tableParams,'data',[]);
                set(this.visHandles.editShift,'String','');
                set(this.visHandles.editOffsetPhotons,'String','');
            end
        end
        
        function updateGUI(this)
            %update GUI controls
            if(~this.isOpenVisWnd())
                return
            end
            %update source independent GUI controls
            sdc = this.currentSynthDataCh;
            if(isempty(sdc))
                set(this.visHandles.checkAllChannels,'Value',0);
                set(this.visHandles.editSizeX,'String','');
                set(this.visHandles.editSizeY,'String','');
                set(this.visHandles.editPhotons,'String','');
                cla(this.visHandles.axesPreview);
                return
            end
            set(this.visHandles.editArrayNrSets,'String',num2str(floor((sdc.arrayParamEnd-sdc.arrayParamStart)/sdc.arrayParamStep+1)));
            if(this.autoPreview)
                %automatic preview enabled
                this.updatePreviewPlot();
                if(~isempty(sdc.rawData) && ~isempty(sdc.modelData))
                    sdc = this.currentSynthDataCh;
                end
            else
                %automatic preview disabled
                cla(this.visHandles.axesPreview);
            end
            %update source dependent GUI controls
            if(sdc.dataSourceType < 3)
                %update edits
                set(this.visHandles.editExponentials,'String',num2str(sdc.nrExponentials));
                set(this.visHandles.editShift,'String',num2str(sdc.shift));
                set(this.visHandles.editOffsetPhotons,'String',num2str(sdc.offset));
                data(:,1) = sdc.xVec(1:sdc.nrExponentials).*100;
                data(:,2) = sdc.xVec(sdc.nrExponentials+1:sdc.nrExponentials*2);
                data(:,3) = sdc.xVec(sdc.nrExponentials*2+1:sdc.nrExponentials*3);
                data(:,4) = simFLIM.computeQs(data(:,1),data(:,2));
            else
                data = [];
            end
            set(this.visHandles.tableParams,'Data',data);
        end
        
        function updatePreviewPlot(this)
            %update plot
            cla(this.visHandles.axesPreview);
            set(this.visHandles.axesPreview,'YLimMode','auto');
            set(this.visHandles.axesPreview,'Yscale','log');
            lStr = cell(0,0);
            sdc = this.currentSynthDataCh;
            [szX, szY, szTime, nExp, photons, offset, sdt, xVec, tci] = this.getSimParams(this.currentSynthDataName,this.currentChannel);
            xAxis = this.mySimSubject.timeVector(1:szTime);
            dynVisParams.timeScalingAuto = true;
            if(~isempty(sdc.rawData))
                raw = squeeze(sdc.rawData(1,1,:));
                lStr = FLIMXFitGUI.makeModelPlot(this.visHandles.axesPreview,raw,xAxis,'Data',dynVisParams,this.fluoDecayFitVisParams,'Data',lStr);
            end
            if(sdc.dataSourceType < 3 && ~isempty(sdc.rawData) && ~isempty(sdc.modelData))
                model = squeeze(sdc.modelData(1,1,:));
                %plot exponentials if we don't use data as reference
                lStr = FLIMXFitGUI.makeModelPlot(this.visHandles.axesPreview,model,xAxis,'ExpSum',dynVisParams,this.fluoDecayFitVisParams,'Model',lStr);
                %scale xvec to max(data)
                dMax = max(raw(:));
                %                 xVec(end) = xVec(end) * dMax;
                xVec(1:sdc.nrExponentials) = xVec(1:sdc.nrExponentials).* dMax;
%                 this.updatebasicParams(sdc);
                this.mySimSubject.setMeasurementData(this.currentChannel,raw);
                apObj = this.currentApObj;                
                lStr = FLIMXFitGUI.makeExponentialsPlot(this.visHandles.axesPreview,xAxis,apObj,apObj.getNonConstantXVec(this.currentChannel,xVec),lStr,dynVisParams,this.fluoDecayFitVisParams);
            elseif(~isempty(sdc.modelData))
                model = squeeze(sdc.modelData(1,1,:));
                lStr = FLIMXFitGUI.makeModelPlot(this.visHandles.axesPreview,model,xAxis,'ExpSum',dynVisParams,this.fluoDecayFitVisParams,'RefData',lStr);
            end
            FLIMXFitGUI.makeLegend(this.visHandles.axesPreview,lStr);
        end
        
        function updateProgressbar(this,x,text)
            %update progress bar, progress x: 0..1, varargin{1}: title (currently unused), varargin{2}: text on progressbar
            if(this.isOpenVisWnd)
                x = max(0,min(100*x,100));
                xpatch = [0 x x 0];
                set(this.visHandles.patchWait,'XData',xpatch,'Parent',this.visHandles.axesProgress);
                yl = ylim(this.visHandles.axesProgress);
                set(this.visHandles.textWait,'Position',[1,yl(2)/2,0],'String',text,'Parent',this.visHandles.axesProgress);
                drawnow;
            end
        end
        
        
        %% GUI callbacks
        function GUI_buttonClose_Callback(this,hObject,eventdata)
            %close parameter set manager
            if(this.FLIMXObj.sDDMgr.anyDirtySDDs())
                choice = questdlg('Save changes to simulation parameter sets?','Save Parameter Sets?','Yes','No','Cancel','Yes');
                switch choice
                    case 'Yes'
                        this.FLIMXObj.sDDMgr.saveAll();
                    case 'No'
                        %load unmodified parameter sets
                        this.FLIMXObj.sDDMgr.scanForSDDs();
                    case 'Cancel'
                        return
                end
            end
            if(~isempty(this.visHandles) && ishandle(this.visHandles.simFLIMFigure))
                delete(this.visHandles.simFLIMFigure);
            end
        end
        
        function GUI_buttonSave_Callback(this,hObject,eventdata)
            %save parameter sets
            this.FLIMXObj.sDDMgr.saveAll();
        end
        
        function GUI_buttonAddSet_Callback(this,hObject,eventdata)
            %add new parameter set to parameter set manager
            %get standard values
            %get unique name
            oldNames = this.FLIMXObj.sDDMgr.getAllSDDNames();
            options.Resize='on';
            options.WindowStyle='modal';
            options.Interpreter='none';
            while(true)
                newName=inputdlg('Enter new parameter set name:','Parameter Set Name',1,{'set01'},options);
                if(isempty(newName))
                    return
                end
                %remove any '\' a might have entered
                newName = char(newName{1,1});
                idx = strfind(newName,filesep);
                if(~isempty(idx))
                    newName(idx) = '';
                end
                %check if study name is available
                if(ismember(newName,oldNames))
                    choice = questdlg(sprintf('The Parameter Set "%s" is already existent! Please choose another name.',newName),...
                        'Error adding Parameter Set','Choose new Name','Cancel','Choose new Name');
                    % Handle response
                    switch choice
                        case 'Cancel'
                            return
                    end
                else
                    %we have a unique name
                    break;
                end
            end
            sdc = this.FLIMXObj.sDDMgr.newSDD(newName,this.currentChannel);
            IRFstr = this.FLIMXObj.irfMgr.getIRFNames(sdc.nrTimeChannels);
            sdc.IRFName = IRFstr{1};
            this.newSimSubject(sdc);
            %make raw data and model
            [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
            %select current parameter set in table
            this.mySelection = {newName};
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_buttonRename_Callback(this,hObject,eventdata)
            %rename selected parameter set
            %get unique name
            if(isempty(this.FLIMXObj.sDDMgr.getAllSDDNames()))
                return
            end
            oldName = this.currentSynthDataCh;
            for i = 1:length(this.mySelection)
                sdc = this.getSynthDataCh(this.mySelection{i},this.currentChannel);
                oldName = sdc.UID;
                options.Resize='on';
                options.WindowStyle='modal';
                options.Interpreter='none';
                while(true)
                    newName=inputdlg('Enter new parameter set name:','Parameter Set Name',1,{oldName},options);
                    if(isempty(newName))
                        return
                    end
                    %remove any '\' a might have entered
                    newName = char(newName{1,1});
                    idx = strfind(newName,filesep);
                    if(~isempty(idx))
                        newName(idx) = '';
                    end
                    %check if study name is available
                    if(ismember(newName,this.FLIMXObj.sDDMgr.getAllSDDNames()))
                        choice = questdlg(sprintf('The Parameter Set "%s" is already existent! Please choose another name.',newName),...
                            'Error adding Parameter Set','Choose new Name','Cancel','Stop','Choose new Name');
                        % Handle response
                        switch choice
                            case 'Cancel'
                                continue
                            case 'Stop'
                                break
                        end
                    else
                        %we have a unique name
                        break;
                    end
                end
                this.FLIMXObj.sDDMgr.renameSDD(oldName,newName);
            end
            if(isempty(newName))
                newName = oldName;
            end
            this.mySelection = {newName};
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_buttonRemoveSet_Callback(this,hObject,eventdata)
            %remove selected parameter set
            if(isempty(this.FLIMXObj.sDDMgr.getAllSDDNames()))
                return
            end
            askFlag = true;
            for i = 1:length(this.mySelection)
                if(askFlag)
                    choice = questdlg(sprintf('Delete simulation parameter set %s?',this.mySelection{i}),'Delete parameter set?','Yes','All','No','No');
                    switch choice
                        case 'All'
                            askFlag = false;
                        case 'No'
                            return
                    end
                end
                this.FLIMXObj.sDDMgr.deleteSDD(this.mySelection{i});
            end
            newNames = this.FLIMXObj.sDDMgr.getAllSDDNames();
            if(isempty(newNames))
                this.mySelection = [];
            else
                this.mySelection = newNames(1);
            end
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_buttonRemoveAllSets_Callback(this,hObject,eventdata)
            %remove all parameter sets
            if(isempty(this.FLIMXObj.sDDMgr.getAllSDDNames()))
                return
            end
            choice = questdlg('Delete all simulation parameter sets?','Delete all parameter sets?','Yes','No','No');
            switch choice
                case 'No'
                    return
            end
            this.FLIMXObj.sDDMgr.deleteAllSDDs();
            this.mySelection = [];
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_buttonExportSel_Callback(this,hObject,eventdata)
            %export selected parameter sets to batchjob manager
            if(isempty(this.FLIMXObj.sDDMgr.getAllSDDNames()))
                return
            end
            batchFlag = false;
            if(this.addBatchJob)
                choice = questdlg(...
                    'The current settings for pre-processing, approximation, bounds and optimizers will be used. Settings of exported datasets cannot be changed subsequently. Do you want to continue?',...
                    'Export datasets to batch job manager?','Yes','No','Cancel','Yes');
                switch choice
                    case 'Yes'
                        batchFlag = true;
                    case 'Cancel'
                        return
                end
            end
            
            this.stop = false;
            for i = 1:length(this.mySelection)
                this.updateProgressbar(1/length(this.mySelection)*(i-1) + 0.5/length(this.mySelection),...
                    sprintf('Exporting ''%s'' - generating synthetic data...',this.mySelection{i}));
                this.exportParaSet(this.mySelection{i},batchFlag);
                if(this.stop)
                    this.updateProgressbar(0,'');
                    this.stop = false;
                    return
                end
            end
            this.updateProgressbar(0,'');
            this.FLIMXObj.FLIMFitGUI.checkVisWnd();
            figure(this.visHandles.simFLIMFigure);
        end
        
        function GUI_buttonExportAll_Callback(this,hObject,eventdata)
            %export all parameter sets to batchjob manager
            allNames = this.FLIMXObj.sDDMgr.getAllSDDNames();
            if(isempty(allNames))
                return
            end
            batchFlag = false;
            if(this.addBatchJob)
                choice = questdlg(...
                    'The current settings for pre-processing, approximation, bounds and optimizers will be used. Settings of exported datasets cannot be changed subsequently. Do you want to continue?',...
                    'Export datasets to batch job manager?','Yes','No','Cancel','Yes');
                switch choice
                    case 'Yes'
                        batchFlag = true;
                    case 'Cancel'
                        return
                end
            end           
            this.stop = false;
            for i = 1:length(allNames)
                this.updateProgressbar(1/length(allNames)*i,...
                    sprintf('Exporting %s...',allNames{i}));
                this.exportParaSet(allNames{i},batchFlag);
                if(this.stop)
                    this.updateProgressbar(0,'');
                    this.stop = false;
                    return
                end
            end
            this.updateProgressbar(0,'');
            this.FLIMXObj.FLIMFitGUI.checkVisWnd();
            figure(this.visHandles.simFLIMFigure);
        end
        
%         function GUI_buttonMoveSet_Callback(this,hObject,eventdata)
%             %move selected parameter set left or right
%             if(isempty(this.parameterSetNames))
%                 return
%             end
%             direction = 'Up';
%             tag = get(hObject,'Tag');
%             if(~isempty(strfind(tag,'Down')))
%                 direction = 'Down';
%             end
%             paraSetName = this.parameterSetNames{this.mySelection(1)};
%             if(isempty(paraSetName))
%                 return
%             end
%             oldPos = this.mySelection(1);
%             switch direction
%                 case 'Up'
%                     newPos = max(1,oldPos-1);
%                 otherwise
%                     newPos = min(this.myParameterSets.queue,oldPos+1);
%             end
%             %switch positions in parameter set list
%             tmp = this.parameterSetNames(newPos);
%             this.parameterSetNames(newPos) = {paraSetName};
%             this.parameterSetNames(oldPos) = tmp;
%             this.mySelection = newPos;
%             
%             this.setupGUI();
%             this.updateGUI();
%         end
        
        function GUI_buttonDuplicateSet_Callback(this,hObject,eventdata)
            %duplicate selected set
            allNames = this.FLIMXObj.sDDMgr.getAllSDDNames();
            if(isempty(allNames))
                return
            end
            for i = 1:length(this.mySelection)
                sdd = this.getSynthDataDef(this.mySelection{i});                
                %get unique name
                options.Resize='on';
                options.WindowStyle='modal';
                options.Interpreter='none';
                while(true)
                    newName=inputdlg('Enter new parameter set name:','Parameter Set Name',1,...
                        {sprintf('%s copy',this.mySelection{i})},options);
                    if(isempty(newName))
                        return
                    end
                    %remove any '\' a might have entered
                    newName = char(newName{1,1});
                    ids = strfind(newName,filesep);
                    if(~isempty(ids))
                        newName(ids) = '';
                    end
                    %check if study name is available
                    if(ismember(newName,allNames))
                        choice = questdlg(sprintf('The Parameter Set "%s" is already existent! Please choose another name.',newName),...
                            'Error adding Parameter Set','Choose new Name','Cancel','Choose new Name');                        
                        % Handle response
                        switch choice
                            case 'Cancel'
                                return
                        end
                    else
                        %we have a unique name
                        break;
                    end
                end
                this.FLIMXObj.sDDMgr.duplicateSDD(this.mySelection{i},newName);
            end
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_buttonChangeExp_Callback(this,hObject,eventdata)
            %callback to decrease or increase number of exponentials
            
            if(strcmp(get(hObject,'Tag'),'buttonDecExp'))
                set(this.visHandles.editExponentials,'String',...
                    num2str(str2double(get(this.visHandles.editExponentials,'String'))-1));
            else
                set(this.visHandles.editExponentials,'String',...
                    num2str(str2double(get(this.visHandles.editExponentials,'String'))+1));
            end
            this.GUI_editExponentials_Callback(this.visHandles.editExponentials,[]);
        end
        
        function GUI_editSizeX_Callback(this,hObject,eventdata)
            %change size of x
            newX = round(abs(str2double(get(hObject,'String'))));
            %user generated parameter set
            sdc = this.currentSynthDataCh;
            if(isnan(newX))
                %get old value
                set(hObject,'String',num2str(sdc.sizeX));
                return
            end
            switch this.exportAsSDT
                case 1
                    newX = max(30,newX);
                    sdc.sizeY = newX;
                case 0
                    newX = max(1,newX);
            end
            sdc.sizeX = newX;
            this.updateGUI();
        end
        
        function GUI_editSizeY_Callback(this,hObject,eventdata)
            %change size of y
            newY = max(1,round(abs(str2double(get(hObject,'String')))));
            sdc = this.currentSynthDataCh;
            if(isnan(newY))
                set(hObject,'String',num2str(sdc.sizeY));
                return
            else
                sdc.sizeY = newY;
            end
            this.updateGUI();
        end
        
        function GUI_editExponentials_Callback(this,hObject,eventdata)
            %change number of exponentials
            sdc = this.currentSynthDataCh;
            nExp = str2double(get(hObject,'String'));
            if(isnan(nExp) || nExp < 1)
                set(hObject,'String',num2str(sdc.nrExponentials));
            else
                sdc.nrExponentials = nExp;
                data = get(this.visHandles.tableParams,'Data');
                tSz = size(data,1);
                if(tSz < nExp)
                    data(tSz+1:nExp,:) = zeros(nExp-tSz,4);
                    data(tSz+1:nExp,2) = ones(nExp-tSz,1);
                else
                    data = data(1:nExp,:);
                end
                xVec = zeros(3*nExp+2,1);
                xVec(1:nExp) = data(:,1)./100;
                xVec(nExp+1:2*nExp) = data(:,2);
                xVec(2*nExp+1:3*nExp) = data(:,3);
                %xVec(end-2) = 1;    %vShift;
                xVec(end-1) = str2double(get(this.visHandles.editShift,'String'));    %hShift;
                xVec(end) = str2double(get(this.visHandles.editOffsetPhotons,'String'));
                sdc.xVec = xVec;
                %reset simulation data
                this.mySimSubject.updatebasicParams(sdc);%todo: really needed?
                [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
                this.setupGUI();
                this.updateGUI();
            end
        end
        
        function GUI_editPhotons_Callback(this,hObject,eventdata)
            %change number of photons
            sdc = this.currentSynthDataCh;
            if(isempty(sdc))
                return
            end
            photons = max(1000,round(abs(str2double(get(hObject,'String')))));
            if(isnan(photons))
                set(hObject,'String',num2str(sdc.nrPhotons));
            else
                sdc.nrPhotons = photons;
                %reset simulation data
                [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
            end
            this.updateGUI();
        end
        
        function GUI_editShift_Callback(this, hObject,eventdata)
            %change shift
            sdc = this.currentSynthDataCh;
            if(isempty(sdc))
                return
            end
            shift = str2double(get(hObject,'String'));
            if(isnan(shift))
                set(hObject,'String',num2str(sdc.offset));
            else
                sdc.shift = shift;
                %reset simulation data
                [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
            end
            this.updateGUI();
        end
        
        function GUI_editOffsetPhotons_Callback(this, hObject,eventdata)
            %change offset
            sdc = this.currentSynthDataCh;
            if(isempty(sdc))
                return
            end
            offset = abs(str2double(get(hObject,'String')));
            if(isnan(offset))
                set(hObject,'String',num2str(sdc.offset));
            else
                sdc.offset = offset;
                this.mySimSubject.updatebasicParams(sdc);
                %reset simulation data
                [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
            end
            this.updateGUI();
        end
        
        function GUI_popupTime_Callback(this,hObject,eventdata)
            %select time resolution
            switch get(hObject,'Value');
                case 1
                    szTime = 1024;
                case 2
                    szTime = 4096;
            end
            sdc = this.currentSynthDataCh;
            if(isempty(sdc))
                return
            end
            if(sdc.nrTimeChannels ~= szTime)
                sdc.nrTimeChannels = szTime;
%                 this.mySimSubject.setNrTimeChannels(szTime);
                this.newSimSubject(sdc); 
                %this.mySimSubject.setNrSpectralChannels(sdc.nrSpectralChannels); %this resets fluo file object
                %reset simulation data
                %check if currently selected IRF is still available
                IRFstr = this.FLIMXObj.irfMgr.getIRFNames(sdc.nrTimeChannels);
                idx = find(strcmp(sdc.IRFName,IRFstr),1);
                if(isempty(idx))
                    idx = 1;
                end
                sdc.IRFName = IRFstr{idx};
                this.mySimSubject.basicParams.curIRFID = sdc.IRFName;
                this.mySimSubject.updateAuxiliaryData();
                [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
                this.setupGUI();
                this.updateGUI();
            end
        end
        
        function GUI_popupIRF_Callback(this,hObject,eventdata)
            %select IRF
            sdc = this.currentSynthDataCh;
            if(isempty(sdc))
                return
            end
            if(sdc.dataSourceType == 1)
                [str, mask] = this.FLIMXObj.irfMgr.getIRFNames(sdc.nrTimeChannels);
                sdc.IRFName = str{min(get(hObject,'Value'),length(str))};
                this.mySimSubject.basicParams.curIRFID = sdc.IRFName;
                this.mySimSubject.updateAuxiliaryData(1:sdc.nrSpectralChannels);
                %reset simulation data
                [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
            end
            this.updateGUI();
        end
        
        function GUI_tableParameterSets_CellSelectionCallback(this,hObject,eventdata)
            %select parameter set
            names = this.FLIMXObj.sDDMgr.getAllSDDNames();
            if(isempty(eventdata.Indices) || isempty(names))
                return
            end
            this.mySelection = names(eventdata.Indices(:,1));
            %update channel if not available in selected set
            data = get(this.visHandles.tableParameterSets,'Data');
            ch = str2num(data{eventdata.Indices(1,1),2});
            if(~ismember(this.currentChannel,ch))
                set(this.visHandles.popupChannel,'Value',ch);
            end
            %update basic fit paramters and fluoFile
            sdc = this.currentSynthDataCh;
            this.newSimSubject(sdc);
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_tableParameterSets_CellEditCallback(this,hObject,eventdata)
            %callback to edit parameter set name and corresponding channels
            sdd = this.currentSynthDataDef;
            idx = eventdata.Indices(1,1);
            data = get(hObject,'Data');
            %set channels
            newCh = str2num(data{idx,2});
            if(~isempty(newCh) && ~isempty(sdd))
                %validate input
                newCh(newCh > 2) = [];            %limit channel numbers to 2
                newCh = sort(unique(newCh));      %sort channel numbers
                [~,mask] = sdd.nonEmptyChannelStr();
                oldCh = find(mask);
                switch length(newCh)
                    case 1
                        if(length(oldCh) == 2)
                            %remove other channel
                            oldCh(oldCh~=newCh) = [];
                            sdd.deleteChannel(oldCh);
                            set(this.visHandles.popupChannel,'Value',newCh);
                        elseif(~(newCh==oldCh))
                            %only channel number changed, hence switch channels
                            sdd.moveChannel(oldCh,newCh);
                            sdc = sdd.getChannel(newCh);
                            [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
                        end
                    case 2
                        if(~(length(oldCh)==2))
                            %add new channel
                            sdd.newChannel(newCh);
                            sdc = sdd.getChannel(newCh);
                            [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
                        end
                end
            end
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_checkSDT_Callback(this,hObject,eventdata)
            %callback of checkbox, check if SDT export is enabled            
            switch(this.exportAsSDT)
                case 1
                    %SDT export, restrict to square matrix size >= 30x30
                    this.GUI_editSizeX_Callback(this.visHandles.editSizeX,eventdata);
                case 0
                    %no restriction
                    this.updateGUI();
            end
        end
        
        function GUI_checkAutoPreview_Callback(this,hObject,eventdata)
            %enable / disable automatic preview
            this.updateGUI();
        end
        
        function GUI_checkFixedQ_Callback(this,hObject,eventdata)
            %enable / disable fixed Q for current parameter set
            sdc = this.currentSynthDataCh;
            if(isempty(sdc))
                return
            end
            sdc.fixedQ = get(hObject,'Value');
        end
        
        function GUI_checkAllChannels_Callback(this,hObject,eventdata)
            %enable/disable all spectral channels in parameter set
            sdd = this.currentSynthDataDef;
            if(isempty(sdd))
                return
            end
            [~,mask] = sdd.nonEmptyChannelStr();
            ch = this.currentChannel;
            if(get(hObject,'Value'))
                %add additional spectral channel
                if(length(mask) > 1)
                    newCh = find(~mask,1);
                else
                    newCh = 2;
                end
                this.currentChannel = newCh;
                sdd.newChannel(newCh);
                sdc = this.currentSynthDataCh;
                sdc.dataSourceType = this.currentSource;
                this.newSimSubject(sdc);
                this.updateCurrentChannel();
            else
                %disable multiple spectral channels
                %remove other channel
                otherCh = find(mask);
                otherCh = otherCh(otherCh~=ch);
                sdd.deleteChannel(otherCh);
                this.newSimSubject(this.currentSynthDataCh);
            end
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_tableParaSetsEdit_Callback(this,hObject,eventdata)
            %edit xVec parameter
            sdc = this.currentSynthDataCh;
            if(isempty(sdc))
                return
            end
            nExp = sdc.nrExponentials;
            data = get(hObject,'data');
            if(get(this.visHandles.checkFixedQ,'Value') && length(eventdata.Indices) == 2 && eventdata.Indices(2) < 3)
                %find out which parameter was changed
                if(eventdata.Indices(2) == 1)
                    %amplitude changed -> calculate tau
                    taus = simFLIM.computeTausFromQs(data(:,1),data(:,2),data(:,4),eventdata.Indices(1));
                    if(length(taus) == size(data,1))
                        data(:,2) = taus;
                    end
                else
                    %tau changed -> calculate amplitudes
                    amps = simFLIM.computeAmpsFromQs(data(:,1),data(:,2),data(:,4),eventdata.Indices(1));
                    if(length(amps) == size(data,1))
                        data(:,1) = amps;
                    end
                end
            end
            if(eventdata.Indices(2) == 4)
                %q changed
                if(eventdata.NewData >= 100)
                    data(:,4) = 0;
                    data(eventdata.Indices(1),4) = 100;
                elseif(eventdata.Indices(1) == nExp)
                    %last q was changed
                    data(end,4) = 100-sum(data(1:end-1,4));
                else
                    tmp = data(1:eventdata.Indices(1),4);
                    if(sum(tmp(:)) > 100)
                        %overflow, remaining qs are set to zero
                        tmp(end) = 100-sum(tmp(1:end-1));
                        data(:,4) = 0;
                        data(1:length(tmp)) = tmp;
                    else
                        rem = data(eventdata.Indices(1)+1:end,4);
                        rem = rem./sum(rem(:));
                        rem = rem.* (100-sum(tmp(:)));
                        data(eventdata.Indices(1)+1:end,4) = rem;
                    end
                end
                for i = 1:nExp
                    amps = simFLIM.computeAmpsFromQs(data(:,1),data(:,2),data(:,4),i);
                    if(length(amps) == size(data,1))
                        data(:,1) = amps;
                    end
                end
            end
            xVec = zeros(3*nExp+2,1);
            xVec(1:nExp) = data(:,1)./100;
            xVec(nExp+1:2*nExp) = data(:,2);
            tci = -1*abs(data(:,3));
            if(nExp > 1)
                xVec(2*nExp+1:3*nExp) = tci;
            end
            %xVec(end-2) = 1;    %vShift;
            xVec(end-1) = str2double(get(this.visHandles.editShift,'String'));    %hShift;
            xVec(end) = str2double(get(this.visHandles.editOffsetPhotons,'String')); %offset
            sdc.xVec = xVec;
            sdc.tciVec = tci;
            %reset simulation data
            [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
            this.updateGUI();
        end
        
        function GUI_popupChannel_Callback(this,hObject,eventdata)
            %select spectral channel
            if(get(this.visHandles.checkAllChannels,'Value') ~= 1)
                sdd = this.currentSynthDataDef;
                newCh = this.currentChannel;
                if(newCh == 1)
                    oldCh = 2;
                else
                    oldCh = 1;
                end
                if(~isempty(sdd) && ~isempty(sdd.getChannel(oldCh)))
                    sdd.moveChannel(oldCh,newCh);
                    sdc = sdd.getChannel(newCh);
                    %reset simulation data
                    this.newSimSubject(sdc);
                    [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
                end
            end
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_popupArrayParameter_Callback(this,hObject,eventdata)
            %change parameter set array type
            parent = this.currentSynthDataCh;
            if(isempty(parent))
                return
            end
            apStr = get(this.visHandles.popupArrayParameter,'String');
            apStr = apStr{get(this.visHandles.popupArrayParameter,'Value')};
            if(strncmp('tc',apStr,2))
                set(this.visHandles.editArrayStart,'String',-abs(str2double(get(this.visHandles.editArrayStart,'String'))));
                set(this.visHandles.editArrayEnd,'String',-abs(str2double(get(this.visHandles.editArrayEnd,'String'))));                
            else
                set(this.visHandles.editArrayStart,'String',abs(str2double(get(this.visHandles.editArrayStart,'String'))));
                set(this.visHandles.editArrayEnd,'String',abs(str2double(get(this.visHandles.editArrayEnd,'String'))));
            end
        end
        
        function GUI_buttonCreateParaSetArray_Callback(this,hObject,eventdata)
            % create parameter sets according to defined range
            % create parameter set array based on currently selected set
            parent = this.currentSynthDataCh;
            if(isempty(parent))
                return
            end
            oldStr = get(hObject,'String');
            try
                set(hObject,'String',sprintf('<html><img src="file:/%s"/>Creating...</html>',FLIMX.getAnimationPath()));
                drawnow;
            end
            apStr = get(this.visHandles.popupArrayParameter,'String');
            parent.arrayParamNr = get(this.visHandles.popupArrayParameter,'Value');
            parent.arrayParamName = apStr{parent.arrayParamNr};
            parent.arrayParamStart = str2double(get(this.visHandles.editArrayStart,'String'));            
            parent.arrayParamStep = abs(str2double(get(this.visHandles.editArrayStep,'String')));            
            parent.arrayParamEnd = str2double(get(this.visHandles.editArrayEnd,'String'));
            if(strncmp('tc',parent.arrayParamName,2))
                %make sure tc is negative
                parent.arrayParamStart = -abs(parent.arrayParamStart);
                parent.arrayParamStep = -abs(parent.arrayParamStep);
                parent.arrayParamEnd = -abs(parent.arrayParamEnd);
            end
            %create fluo file and set correct fit parameters
            this.newSimSubject(parent);
            this.FLIMXObj.sDDMgr.makeArrayParamSet(parent.UID,@this.makeSimMExpDec);
            this.updateProgressbar(0,'');
            set(hObject,'String',oldStr);
            %select current parameter set
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_editArray_Callback(this,hObject,eventdata)
            %callback to change range of parameter set array
            sdc = this.currentSynthDataCh;
            if(isempty(sdc))
                return
            end
            choice = 'Start';
            tag = get(hObject,'Tag');
            if(~isempty(strfind(tag,'Step')))
                choice = 'Step';
            elseif(~isempty(strfind(tag,'End')))
                choice = 'End';
            end
            val = abs(str2double(get(hObject,'String')));
            tcMode = strncmp('tc',sdc.arrayParamName,2);
            if(tcMode)
                %make sure tc is negative
                val = -abs(val);
            end
            switch choice
                case 'Start'                    
                    if(val > sdc.arrayParamEnd && ~tcMode)
                        sdc.arrayParamStart = sdc.arrayParamEnd;
                    else
                        sdc.arrayParamStart = val;
                    end
                case 'Step'
                    sdc.arrayParamStep = val;
                case 'End'
                    if(val < sdc.arrayParamStart && ~tcMode)
                        sdc.arrayParamEnd = sdc.arrayParamStart;
                    else
                        sdc.arrayParamEnd = val;
                    end
            end
            this.updateGUI();
        end
        
        function GUI_radioSource_Callback(this,hObject,eventdata)
            %in simulation tool defined parameters
            sdc = this.currentSynthDataCh;
            if(isempty(sdc))
                sdd = this.currentSynthDataDef;
                if(isempty(sdd))
                    return
                end
                sdd.newChannel(this.currentChannel);
                sdc = this.currentSynthDataCh;
            end
            switch get(hObject,'Tag')
                case 'radioSourceLastResult'
                    sdc.dataSourceType = 2;
                case 'radioSourceData'
                    sdc.dataSourceType = 3;
                otherwise %radioSourceUser
                    sdc.dataSourceType = 1;
            end
            this.updateCurrentChannel();
            this.setupGUI();
            this.updateGUI();
        end
        
        function updateCurrentChannel(this)
            %get measurement data from fluoDecayFit and store it into current sythetic data definition's current channel
            sdc = this.currentSynthDataCh;
            switch sdc.dataSourceType
                case 1 %user defined
                    if(isempty(sdc.xVec))
                        sdc = this.currentSynthDataCh;
                        sdc.dataSourceDatasetName = '';
                        sdc.dataSourcePos = [];
                    end
                    if(isempty(sdc.rawData) || isempty(sdc.modelData))
                        %reset simulation data
                        this.mySimSubject.updatebasicParams(sdc); %todo: really needed?
                        [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
                        return
                    end
                case 2 %result
                    currentName = this.FLIMXObj.curFluoFile.getDatasetName();
                    if(~isempty(currentName) && ~strcmp(sdc.dataSourceDatasetName, currentName))
                        button = questdlg(sprintf('There is data in this channel present from dataset ''%s''.\n\nOverwrite?',sdc.dataSourceDatasetName),'Overwrite data','Yes','No','No');
                        switch button
                            case 'no'
                                return;
                        end
                    end
                    %todo: check datasetname of other channel
                    if(this.FLIMXObj.FLIMFitGUI.currentChannel ~= this.currentChannel)
                        %try to load selected channel in simulation tool
                        this.FLIMXObj.FLIMFitGUI.currentChannel = this.currentChannel;
                    end
                    if(this.FLIMXObj.FLIMFitGUI.currentChannel ~= this.currentChannel)
                        %not sucessful
                        return
                    end
                    sdc.channelNr = this.FLIMXObj.FLIMFitGUI.currentChannel;
                    [apObj, xVec, ~, ~, ~, ~, sdc.nrPhotons] = this.FLIMXObj.FLIMFitGUI.getVisParams(sdc.channelNr,this.FLIMXObj.FLIMFitGUI.currentY,this.FLIMXObj.FLIMFitGUI.currentX);
                    sdc.nrExponentials = apObj.basicParams.nExp;
                    sdc.xVec = xVec;
                    sdc.nrSpectralChannels = apObj.fileInfo.nrSpectralChannels;
                    sdc.nrTimeChannels = apObj.fileInfo.nrTimeChannels;
                    %[~,sdc.IRFName] = this.FLIMXObj.irfMgr.getIRF(sdc.nrTimeChannels,apObj.basicParams.curIRFID,sdc.tacRange,sdc.channelNr);
                    sdc.IRFName = apObj.basicParams.curIRFID;
                    sdc.arrayParentSDD = '';
                    sdc.arrayParamName = '';
                    sdc.arrayParamNr = 0;
                    sdc.fixedQ = 0;
                    sdc.modelData = [];
                    sdc.dataSourceDatasetName = currentName;
                    sdc.dataSourcePos = [this.FLIMXObj.FLIMFitGUI.currentY,this.FLIMXObj.FLIMFitGUI.currentX];
                    [sdc.rawData, sdc.modelData] = this.makeSimMExpDec(1,1,sdc);
                case 3 %measurement data
                    currentName = this.FLIMXObj.curFluoFile.getDatasetName();
                    if(~isempty(sdc.dataSourceDatasetName))
                        %check dataset name                        
                        if(~isempty(currentName) && ~strcmp(sdc.dataSourceDatasetName, currentName))
                            button = questdlg(sprintf('There is data in this channel present from dataset ''%s''.\n\nOverwrite?',sdc.dataSourceDatasetName),'Overwrite data','Yes','No','No');
                            switch button
                                case 'no'
                                    return;
                            end
                        end
                        %todo: check datasetname of other channel
                    end
                    if(this.FLIMXObj.FLIMFitGUI.currentChannel ~= this.currentChannel)
                        %try to load selected channel in simulation tool
                        this.FLIMXObj.FLIMFitGUI.currentChannel = this.currentChannel;
                    end
                    if(this.FLIMXObj.FLIMFitGUI.currentChannel ~= this.currentChannel)
                        %not sucessful
                        uiwait(warndlg(sprintf('Current fluoDecayFit dataset does not have channel %d! Aborting...',this.currentChannel),'Channel not available','modal'));
                        return
                    end
                    sdc.xVec = [];
                    modelData(1,1,:) = this.FLIMXObj.FLIMFitGUI.currentDecayData;
                    sdc.channelNr = this.currentChannel;
                    sdc.nrSpectralChannels = this.FLIMXObj.curFluoFile.nrSpectralChannels;
                    sdc.nrTimeChannels = this.FLIMXObj.curFluoFile.nrTimeChannels;
                    sdc.nrPhotons = sum(modelData(:));
                    sdc.modelData = modelData;
                    sdc.arrayParentSDD = '';
                    sdc.arrayParamName = '';
                    sdc.arrayParamNr = 0;
                    sdc.fixedQ = 0;
                    sdc.dataSourceDatasetName = currentName;
                    sdc.dataSourcePos = [this.FLIMXObj.FLIMFitGUI.currentY,this.FLIMXObj.FLIMFitGUI.currentX];
                    sdc.rawData = this.makeSimMExpDec(1,1,sdc);
            end
        end
        
        function GUI_buttonShowInFluo_Callback(this, hObject, eventdata)
            %
            button = questdlg(sprintf('This will clear the current dataset and its results in FluoDecayFit!\n\nContinue?'),'Clear data and results?','Yes','No','Yes');
            if(strcmp(button,'No'))
                return
            end
            this.exportParaSet(this.currentSynthDataName,false);
%             sdc = this.currentSynthDataCh;
            this.updateProgressbar(0.2,'Create synthetic data');
            %save as sdt file?
            %             sdt = false;
            %             if(sdt)
            %                 writeSDT(raw,this.mySimSubject.tacRange);
            %             end
            this.updateProgressbar(0.5,'Compute ROI');
            this.updateProgressbar(1,'Finished');
            %set binning to zero
            this.FLIMXObj.paramMgr.readConfig();
            preProcess = this.FLIMXObj.FLIMFit.preProcessParams;
            preProcess.roiBinning = 0;
            this.FLIMXObj.paramMgr.setParamSection('pre_processing',preProcess,true);
            %setup
            this.FLIMXObj.setCurrentSubject(this.currentStudy,FDTree.defaultConditionName(),this.currentSynthDataName);
            %check irf
            if(isempty(this.FLIMXObj.irfMgr.getCurIRF(this.currentChannel)))
                [irfStr,IRFmask] = this.FLIMXObj.irfMgr.getIRFNames(this.mySimSubject.nrTimeChannels);
                [settings button] = settingsdlg(...
                    'Description', 'The currently selected IRF is not valid for parameter approximation. Please choose a valid IRF from the list below.',...
                    'title' , 'IRF Selection',...
                    {'IRF name';'IRFid'}, irfStr);
                %check user inputs
                if(~strcmpi(button, 'ok') || isempty(settings.IRFid))
                    %user pressed cancel or has entered rubbish -> abort
                    return
                end
                basicFit = this.FLIMXObj.paramMgr.getParamSection('basic_fit');
                basicFit.curIRFID = IRFmask(strcmp(settings.IRFid,irfStr));
                this.FLIMXObj.paramMgr.setParamSection('basic_fit',basicFit,true);
            end
            this.FLIMXObj.FLIMFitGUI.currentChannel = this.currentChannel;
            this.FLIMXObj.FLIMFitGUI.checkVisWnd();
            this.updateProgressbar(0,'');
        end
        
        function GUI_buttonNewStudy_Callback(this, hObject, eventdata)
            %add a new study to fdtree
            oldStudies = this.FLIMXObj.fdt.getStudyNames();
            %we use study manager for this
            this.FLIMXObj.studyMgrGUI.menuNewStudy_Callback();
            newStudies = this.FLIMXObj.fdt.getStudyNames();
            [~,idxNew] = setdiff(newStudies,oldStudies);
            if(~isempty(idxNew))
                set(this.visHandles.popupStudy,'String',newStudies,'Value',idxNew);
            end
        end
        
        function GUI_buttonStop_Callback(this, hObject, eventdata)
            %set stop flag
            this.stop = true;
        end
    end
    
    methods(Static)
        function out = computeQs(amps,taus)
            %compute relative contribution of exponentials
            if(numel(amps) ~= numel(taus))
                out = [];
                return
            end
            %Q1= a1*T1*100/(a1*T1+a2*T2+a3*T3)
            out = amps.*taus;
            out = out./sum(out(:))*100;
        end
        
        function amps = computeAmpsFromQs(amps,taus,qs,idx)
            %compute amplitude idx for gives qs with taus fixes
            if(numel(qs) ~= numel(amps) || numel(qs) ~= numel(taus))
                return
            end
            if(length(qs) == 1  || qs(idx) >= 100)
                amps(idx) = 100;
                return
            end
            varnames = sprintf('syms q%d',idx);
            formula = sprintf('q%d = 100*a%d*t%d/(',idx,idx,idx);
            for i = 1:length(qs)
                varnames = [varnames sprintf(' a%d t%d',i,i)];
                formula = [formula sprintf('a%d*t%d',i,i)];
                if(i ~= length(qs))
                    formula = [formula '+'];
                else
                    formula = [formula ')'];
                end
            end
            eval(varnames);
            res = solve(formula,sprintf('a%d',idx));
            %fill variables
            eval(sprintf('q%d = qs(%d);',idx,idx));
            for i = 1:length(qs)
                eval(sprintf('a%d = amps(i);',i));
                eval(sprintf('t%d = taus(i);',i));
            end
            eval(['amps(idx) = ' char(res) ';']);
            %             amps = amps./sum(amps(:))*100;
        end
        
        function taus = computeTausFromQs(amps,taus,qs,idx)
            %compute tau idx for gives qs with amplitudes fixes
            if(numel(qs) ~= numel(amps) || numel(qs) ~= numel(taus))
                return
            end
            if(length(qs) == 1 || qs(idx) >= 100)
                taus(idx) = 100; %some default value?
                return
            end
            varnames = sprintf('syms q%d',idx);
            formula = sprintf('q%d = 100*a%d*t%d/(',idx,idx,idx);
            for i = 1:length(qs)
                varnames = [varnames sprintf(' a%d t%d',i,i)];
                formula = [formula sprintf('a%d*t%d',i,i)];
                if(i ~= length(qs))
                    formula = [formula '+'];
                else
                    formula = [formula ')'];
                end
            end
            eval(varnames);
            res = solve(formula,sprintf('t%d',idx));
            %fill variables
            eval(sprintf('q%d = qs(%d);',idx,idx));
            for i = 1:length(qs)
                eval(sprintf('a%d = amps(i);',i));
                eval(sprintf('t%d = taus(i);',i));
            end
            eval(['taus(idx) = ' char(res) ';']);
        end
        
        function out = sampleMExpDec(inHist,ph)
            %make synthetic multi exponential decay
            nBins = size(inHist,2);
            out = zeros(size(inHist));
            if(ph == 0)
                return
            end
            parfor pixel = 1:size(out,1)
                dfIdx = 1;
                temp = zeros(nBins,1);
                df = cumsum(inHist(pixel,:)); %compute commulative distribution function
                rn = sort(rand(round(ph),1).*df(end),1); %make random numbers
                for i = 1:size(rn,1)
                    if(rn(i) < df(dfIdx))
                        %random number fits into current class of distribution function
                        temp(dfIdx) = temp(dfIdx)+1;
                    else
                        while(rn(i) >= df(dfIdx) && dfIdx < length(df))
                            %current random number is bigger than current class of distribution function -> move to next class
                            dfIdx = dfIdx+1;
                        end
                        %random number fits into current class of distribution function
                        temp(dfIdx) = temp(dfIdx)+1;
                    end
                end
                out(pixel,:) = temp;
            end
        end
    end %methods(Static)
end
classdef FluoDecayFit < handle
    %=============================================================================================================
    %
    % @file     fluoDecayFit.m
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
    % @brief    A class to approximate fluoresence decays.
    %
    properties(GetAccess = public, SetAccess = private)
        parameters = []; %struct to store parameters
        resultObj = []; %struct to store results
        FLIMXObj = []; %handle to visualization object
        progressShortCb = cell(0,0); %callback function handles for progress bars
        progressLongCb = cell(0,0); %callback function handles for progress bars
    end
    properties (Dependent = true)
        aboutInfo = [];
        computationParams = [];
        cleanupFitParams = [];
        preProcessParams = [];
        basicParams = [];
        visualizationParams = [];
        initFitParams = [];
        pixelFitParams = [];
        boundsParams = [];
        optimizationParams = [];
        volatilePixelParams = [];
    end
    
    methods
        function this = FluoDecayFit(flimX)
            %Constructs a FDecFitTci object.
            this.FLIMXObj = flimX;
            %this.parameters.tStart = 0; %start time of fit
            this.parameters.stopOptimization = 0; %stop optimization
            this.parameters.lastResultFile = []; %path to last saved result file
            this.parameters.initFitOnly = false; %flag to fit only merged ROI
            %this.parameters.initVec = []; %init vector for roi fit (optional)
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % input methods
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function setProgressShortCallback(this,cb)
            %set callback function for short progress bar
            this.progressShortCb(end+1) = {cb};
        end
        
        function setProgressLongCallback(this,cb)
            %set callback function for short progress bar
            this.progressLongCb(end+1) = {cb};
        end
        
        function setInitFitOnly(this,flag)
            %enable/disable ROIOnly fit
            this.parameters.initFitOnly = flag;
        end
        
%         function setInitVec(this,init)
%             %set init vector for fitting process
%             this.parameters.initVec = init;
%         end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % output methods
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        function [parameterCell, idx] = getApproxParamCell(this,ch,pixelPool,fitDim,initFit)
            %put all data needed for approximation in a cell array (corresponds to makePixelFit interface)
            if(initFit)
                %initialization fit                
                if(any(pixelPool > this.initFitParams.gridSize^2))
                    parameterCell = [];
                    idx = [];
                    return
                end
                apObjs = this.FLIMXObj.curSubject.getInitApproxObjs(ch);
                apObjs = apObjs(pixelPool);
                idx = zeros(length(pixelPool),2);
                [idx(:,1), idx(:,2)] = ind2sub([this.initFitParams.gridSize this.initFitParams.gridSize],pixelPool);
                %nPixel = this.initFitParams.gridSize^2;
            else
                %ROIData = this.FLIMXObj.curSubject.getROIData(ch,[],[],[]);
                y = this.FLIMXObj.curSubject.getROIYSz();
                x = this.FLIMXObj.curSubject.getROIXSz();
                if(length(pixelPool) < 1) %we are at the end of the file
                    parameterCell = [];
                    idx = [];
                    return
                end
                nPixel = length(pixelPool);
                %% get pixel indices and data
                idx = zeros(nPixel,2);
                parameterCell = cell(1,3);
                apObjs = cell(nPixel,1);
                if(fitDim == 2) %x
                    [idx(:,2), idx(:,1)] = ind2sub([x y],pixelPool);
                else %y
                    [idx(:,1), idx(:,2)] = ind2sub([y x],pixelPool);
                end
                subject = this.FLIMXObj.curSubject;
                for i = 1:nPixel %loop over roi pixel
                    apObjs{i} = getApproxObj(subject,ch,idx(i,1),idx(i,2));
                end
            end
%             %% build init vector
%             if(isvector(initVec) && nPixel > 1)
%                 initVec = repmat(initVec,1,nPixel);
%             elseif((~isvector(initVec) && nPixel ~= size(initVec,2)) || isempty(initVec))
%                 %we have more than one initVec but not one for each pixel
%                 initVec = zeros(this.volatilePixelParams.nApproxParamsAllCh,nPixel);
%             end
            %% assemble cell
            parameterCell(1) = {apObjs};
            parameterCell(2) = {this.optimizationParams};
            parameterCell(3) = {this.aboutInfo};
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % computation methods
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function updateProgressShort(this,prog,text)
            %either update short progress bar of visObj or plot to command line
            for i = length(this.progressShortCb):-1:1
                try
                    this.progressShortCb{i}(prog,text);
                catch
                    this.progressShortCb{i} = [];
                end
            end
        end
        
        function updateProgressLong(this,prog,text)
            %either update long progress bar of visObj or plot to command line
            for i = length(this.progressLongCb):-1:1
                try
                    this.progressLongCb{i}(prog,text);
                catch
                    this.progressLongCb{i} = [];
                end
            end
        end
        
        function stopOptimization(this,flag)
            %stop/resume optimization
            this.parameters.stopOptimization = logical(flag);
        end
        
        function iterPostProcess(this,iter,maxIter,tStart)
            %function to update the waitbar after each iteration
            persistent lastUpdate
            if(isempty(lastUpdate) || etime(clock, lastUpdate) > 1)
                [hours, minutes, secs] = secs2hms(etime(clock,tStart)/iter*(maxIter-iter)); %mean cputime for finished runs * cycles left
                this.updateProgressShort(iter/maxIter,sprintf('%02.1f%% - Time left: %02.0fh %02.0fm %02.0fs',iter/maxIter*100,hours,minutes,secs));
                lastUpdate = clock;
            end
        end
        
        function goOn = mcPostProcess(this,mcStruct,myParams)
            %function to do post processing a multicore result
            persistent lastUpdate
            rLen = length(mcStruct.resultIndices);
            for i = 1:rLen
                resultStruct = mcStruct.resultCell{mcStruct.resultIndices(i)};
                if(this.parameters.stopOptimization)
                    %user wants to stop
                    resultStruct = 'User Request';
                end
                if(ischar(resultStruct))
                    warndlg(sprintf('Multicore stopped due to:\n\n%s',resultStruct),'Multicore stopped','modal');
                    goOn = false;
                    return
                end
                idx = myParams.idxCell{mcStruct.resultIndices(i)};
                if(myParams.initFit)
                    this.FLIMXObj.curSubject.addInitResult(myParams.ch,idx,resultStruct);
                else
                    this.FLIMXObj.curSubject.addMultipleResults(myParams.ch,idx,resultStruct);
                end
            end            
            done = mcStruct.nrOfFilesMaster + mcStruct.nrOfFilesSlaves;
            this.updateProgressShort(done/mcStruct.nrOfFiles,sprintf('%02.1f%%',done/mcStruct.nrOfFiles*100)); %- Time left: %02.0fh %02.0fm %02.0fs ,hours,minutes,secs
            idx = idx(end,:);
            if((isempty(lastUpdate) || etime(clock, lastUpdate) > 1) && ~myParams.initFit)
                this.FLIMXObj.FLIMFitGUI.setCurrentPos(idx(1),idx(2)); %todo: move this call to a callback function similar to this.updateProgressShort                
                lastUpdate = clock;
            end
            goOn = true;
        end
        
        function makePreProcessing(this,ch)
            %pre-process data (results from this method are not used by approximation methods, they do pre-processing themselves)
            persistent lastUpdate
            this.FLIMXObj.FLIMFitGUI.setButtonStopSpinning(true);
            %% for merged roi
            [pCell, idx] = this.getApproxParamCell(ch,1:this.initFitParams.gridSize^2,[],true); %,ch,pixelPool,fitDim,initFit
            apObjs = pCell{1};
            nrPixels = length(apObjs);
            parfor p = 1:nrPixels
                tmp(p,:) = apObjs{p}.makeDataPreProcessing([]);
            end
            %rebuild results structure
            for i = 1:nrPixels
                for chIdx = 1:length(apObjs{1}.nonEmptyChannelList)
                    fn = fieldnames(tmp(i,chIdx));
                    fn = fn(~strcmpi(fn,'ROI_merge_result'));
                    %fn = fn(~strcmpi(fn,'Message'));
                    for j = 1:length(fn)
                        result(chIdx).(fn{j})(i,:) = tmp(i,chIdx).(fn{j});
                    end
                end
            end
            this.FLIMXObj.curSubject.addInitResult(ch,idx,result);
            %% for each pixel
            y = this.FLIMXObj.curSubject.getROIYSz();
            x = this.FLIMXObj.curSubject.getROIXSz();
            totalPixel = x * y;
            pixelPool = 1:1:totalPixel;
            tStart = clock;
            %loop over columns
            for row = 1:y                
                pCell = this.getApproxParamCell(ch,pixelPool((row-1)*x+1:min(totalPixel,row*x)),2,false);
                %this.FLIMXObj.curSubject.addResultRow(ch,i,makeDataPreProcessing(pCell{1},pCell{4},pCell{6},pCell{7},pCell{5}));
                parfor col = 1:x                    
                    %apObjs = pCell{1};
                    tmp(col,:) = pCell{1}{col}.makeDataPreProcessing([]);
                end
                %rebuild results structure
                for i = 1:x
                    for chIdx = 1:length(apObjs{1}.nonEmptyChannelList)
                        fn = fieldnames(tmp(i,chIdx));
                        fn = fn(~strcmpi(fn,'ROI_merge_result'));
                        %fn = fn(~strcmpi(fn,'Message'));
                        for j = 1:length(fn)
                            result(chIdx).(fn{j})(i,:) = tmp(i,chIdx).(fn{j});
                        end
                    end
                end
                this.FLIMXObj.curSubject.addResultRow(ch,row,result);
                %                 for col = 1:x
                %                     this.FLIMXObj.curSubject.addSingleResult(ch,row,col,apObj.makeDataPreProcessing(pCell{3}));
                %                 end
                [hours, minutes, secs] = secs2hms(etime(clock,tStart)/row*(y-row)); %mean cputime for finished runs * cycles left
                this.updateProgressShort(row/y,sprintf('%02.1f%% - Time left: %02.0fh %02.0fm %02.0fs',row/y*100,hours,minutes,secs));
                if(isempty(lastUpdate) || etime(clock, lastUpdate) > 5)
                    %                     [idx(1,2) idx(1,1)] = ind2sub([x y],i);
                    this.FLIMXObj.FLIMFitGUI.setCurrentPos(row,1);
                    lastUpdate = clock;
                    if(this.parameters.stopOptimization)
                        this.parameters.stopOptimization = false;
                        break
                    end
                end
            end
            this.parameters.lastResultFile = [];
            this.updateProgressShort(0,'');
            this.FLIMXObj.FLIMFitGUI.setButtonStopSpinning(false);
        end
        
        function stratStr = startFitProcess(this,ch,yPos,xPos)
            %actual fitting process
            stratStr = '';
            if(nargin < 3)
                xPos = [];
                yPos = [];
            end
            if(~isempty(xPos) && ~isempty(yPos) && (xPos > this.FLIMXObj.curSubject.getROIXSz() || yPos > this.FLIMXObj.curSubject.getROIYSz()))
                %coordinates out of range
                return
            end
            %% prepare first
            while(true)
                folderGUI = false;
                if(this.computationParams.useDistComp && ~isdir(this.computationParams.mcShare))
                    folderGUI = true;
                    warndlg(sprintf('Could not find multicore-path:\n %s\n\nPlease choose valid mulitcore share folder.',this.computationParams.mcShare),...
                        'Multicore share Path not found!','modal');
                end
                if(folderGUI)
                    new = GUI_compOptions(this.computationParams);
                    if(~isempty(new)) %we possibly have a new folder - check in next iteration
                        this.FLIMXObj.paramMgr.setParamSection('computation',new.computation);
                        continue
                    else %user pressed cancel
                        return
                    end
                end
                break
            end
            this.parameters.stopOptimization = false;
            if(isempty(ch))
                %fit all channels
                if(this.FLIMXObj.curSubject.basicParams.approximationTarget == 2 && this.FLIMXObj.curSubject.basicFit.anisotropyR0Method == 2)
                    %in case of anisotropy compute channel 3 (sum of ch1 and ch2) first
                    chList = [3,1,2,4];
                else
                    chList = 1:this.FLIMXObj.curSubject.nrSpectralChannels;
                end
                for ch = 1:length(chList)
                    this.FLIMXObj.FLIMFitGUI.currentChannel = chList(ch); %switch GUI to current channel
                    msg = this.startFitProcess(chList(ch),[],[]); %do the computation
                    if(isempty(msg) || this.parameters.stopOptimization)
                        %fit was aborted
                        break
                    end
                end
                return
            end            
            tStart = clock;            
            %% initialization fit
            if((this.basicParams.optimizerInitStrategy == 2 || ~isempty(this.basicParams.fix2InitTargets)) && ~this.FLIMXObj.curSubject.isInitResult(ch))                
                this.updateProgressLong(0.01,'Approximate Initialization...');
                stratStr = this.computeMultipleFits(ch,1:this.initFitParams.gridSize^2,true);
                this.updateProgressLong(0.25,'Cleanup Initialization Approximation...');
                this.makeCleanUpFit(ch,true);
                if(~isempty(xPos) && ~isempty(yPos) && xPos == 0 && yPos == 0)
                    %init (merged ROI) fit only
                    this.updateProgressShort(0,'');
                    this.updateProgressLong(0,'');
                    return
                end
            end
            %user may have pressed stop while init fit was running
            if(this.parameters.stopOptimization)
                this.parameters.stopOptimization = false;
                fprintf('Fitting process aborted after initialization fit!\n');
                button = questdlg(sprintf('Fitting process aborted.\n\nDo you want to save the incomplete results?'),'Fitting process aborted!','Yes','No','No');
                switch button
                    case 'Yes'
                        studyName = this.FLIMXObj.curSubject.getStudyName();
                        subjectName = this.FLIMXObj.curSubject.getDatasetName();
%                         if(this.FLIMXObj.fdt.isMember(studyName,subjectName,ch,[]))
                            this.FLIMXObj.fdt.removeChannel(studyName,subjectName,ch);
%                         end
                        this.FLIMXObj.curSubject.updateSubjectChannel(ch,'result');%,removeNonVisItems(fieldnames(rs.results.pixel)));
                        this.FLIMXObj.fdt.saveStudy(studyName);
                        %this.FLIMXObj.curSubject.setResultDirty(ch,false);
                end
                this.updateProgressShort(0,'');
                this.updateProgressLong(0,'');
                return
            end
            %% we've got all we need to fit a single pixel or the current channel
            if(~(isempty(xPos) && isempty(yPos)))
                %single pixel
                this.FLIMXObj.curSubject.addSingleResult(ch,yPos,xPos,this.makeSingleCurveFit(ch,yPos,xPos,[]));
                this.updateProgressShort(0,'');
                this.updateProgressLong(0,'');
                return
            end            
            %fit current channel
            totalPixelIDs = this.FLIMXObj.curSubject.getApproximationPixelIDs(ch); %this.FLIMXObj.curSubject.getROIXSz() * this.FLIMXObj.curSubject.getROIYSz();
            %make ROI first
            this.FLIMXObj.curSubject.getROIData(ch,[],[]);
            this.updateProgressLong(0.5,'Approximate Pixels...');
            stratStr = this.computeMultipleFits(ch,totalPixelIDs,false); %user aborted if stratStr is empty            
            %clean up stage
            if(~isempty(stratStr) && this.cleanupFitParams.enable > 0)
                %update FLIMXFitGUI
                this.FLIMXObj.FLIMFitGUI.setCurrentPos(1,1);
                this.updateProgressLong(0.75,'Cleanup Pixel Approximation...');
                stratStr = this.makeCleanUpFit(ch,false);
            end
            t = etime(clock,tStart);
            this.FLIMXObj.curSubject.setEffectiveTime(ch,t);
            this.updateProgressShort(0,'');
            this.updateProgressLong(0,'');
            if(~isempty(stratStr))
                %if channels exists delete old result
                studyName = this.FLIMXObj.curSubject.getStudyName();
                if(any(this.volatilePixelParams.globalFitMask))
                    for ch = 1:this.FLIMXObj.curSubject.nrSpectralChannels
                        this.FLIMXObj.curSubject.updateSubjectChannel(ch,'result');
                    end
                else
                    this.FLIMXObj.curSubject.updateSubjectChannel(ch,'result');
                end
                this.FLIMXObj.fdt.saveStudy(studyName);
                [hours, minutes, secs] = secs2hms(t);
                fprintf('Fitting process finished after %02.0fh %02.0fmin %02.0fsec!\n',hours, minutes, round(secs));
            else
                [hours, minutes, secs] = secs2hms(t);
                fprintf('Fitting process aborted after %02.0fh %02.0fmin %02.0fsec!\n',hours, minutes, round(secs));
            end
        end
        
        function goOn = computeMultipleFits(this,ch,pixelPool,initFit)
            %compute approximations of multiple pixels
            persistent lastUpdate            
            totalPixels = length(pixelPool);
            goOn = 'yes'; %todo
            if(totalPixels <1)
                %nothing to do
                goOn = '';
                return
            end
            nWorkers = 1;
            if(this.computationParams.useMatlabDistComp)
                pool = gcp('nocreate');
                if(~isempty(pool))
                    nWorkers = pool.NumWorkers;
                end
            end
            %fit dimension
            if(initFit)
                y = this.initFitParams.gridSize;
                x = y;
                fitDim = 3;
            else
                y = this.FLIMXObj.curSubject.getROIYSz();
                x = this.FLIMXObj.curSubject.getROIXSz();
                if(this.pixelFitParams.fitDimension == 1) %auto
                    %decide which dimension is better suited for multicore
                    if(y < x) % create as many work units as possible
                        fitDim = 2;
                    else
                        fitDim = 3;
                    end
                else %2-x, 3-y
                    %user defined with dimension to use
                    fitDim = this.pixelFitParams.fitDimension;
                end
            end
            tStart = clock;
            this.updateProgressShort(0.001,'0.0% - Time left: n/a');
            %check if all non linear parameters are fixed
            if(~initFit)
                parameterCell = this.getApproxParamCell(ch,1,1,false);
                if(~isempty(parameterCell))
                    apObj = parameterCell{1}{1};
                    vcp = apObj.getVolatileChannelParams(ch);
                    noNonLinOpt = vcp.nApproxParamsPerCh == 0;
                else
                    noNonLinOpt = false;
                end
                if(noNonLinOpt)
                    tStart = clock;
                    measData = this.FLIMXObj.curSubject.getROIData(ch,[],[]);
                    dataYSz = size(measData,1);
                    dataXSz = size(measData,2);
                    dataZSz = size(measData,3);
                    measData = reshape(measData,dataYSz*dataXSz,dataZSz)';
                    %generate reference exponetial models
                        %                     apObj.makeDataPreProcessing([]);
                        %                     bounds = apObj.getLinearBounds();
                    bp = apObj.basicParams;
                    bp.incompleteDecayFactor = 2;
                    nParams = bp.nExp;                    
                    fi = apObj.getFileInfoStruct(ch);
                    t = double(linspace(0,(fi.nrTimeChannels-1)*fi.timeChannelWidth,bp.incompleteDecayFactor*fi.nrTimeChannels)'); 
                    nTimeCh = size(t,1);
                    expModels = [];
                    oset = [];
                    multiModelsFlag = this.FLIMXObj.curSubject.initFitParams.gridSize > 1;
                    if(multiModelsFlag)
                        tauOut = zeros(dataYSz,dataXSz,nParams,'single');
                        for i = 1:nParams
                            tauOut(:,:,i) = single(this.FLIMXObj.curSubject.getPixelFLIMItem(ch,sprintf('TauInit%d',i)));
                        end
                        tauOut = reshape(permute(tauOut,[3,2,1]),nParams,dataYSz*dataXSz);
                        shiftOut = reshape(single(this.FLIMXObj.curSubject.getPixelFLIMItem(ch,'hShiftInit')),1,dataYSz*dataXSz);                      
                        %apObj.basicParams.hybridFit = 0;
                        %remove taus and shift from fixed parameters
                        vcp.cMask(nParams+1:2*nParams) = 0;
                        vcp.cVec(nParams+1:2*nParams) = [];
                        vcp.cMask(end-1) = 0;
                        vcp.cVec(end-1) = [];
                        apObj.setVolatileChannelParams(ch,vcp);
                        nrTiles = 256;                        
                        %[amps, taus, tcis, betas, scAmps, scShifts, scHShiftsFine, scOset, hShift, oset, tciHShiftFine, nVecs] = apObj.getXVecComponents([tauOut(:,idxTiles(i)+1:idxTiles(i+1)); shiftOut(:,idxTiles(i)+1:idxTiles(i+1))],true,ch);
                                                
                    else
                        %set amplitudes to fixed value (1)
                        vcp.cMask(1:nParams) = 1;
                        vcp.cVec(1:nParams) = 1;
                        [amps, taus, tcis, betas, scAmps, scShifts, scOset, hShift, oset] = apObj.getXVecComponents([],true,ch);
                        shiftOut = ones(1,dataYSz*dataXSz).* hShift;
                        tauOut = ones(apObj.basicParams.nExp,dataYSz*dataXSz).*taus;
                        apObj.setVolatileChannelParams(ch,vcp);
                        expModels = single(apObj.getExponentials(ch,[]));
                        nrTiles = nWorkers;
                    end
                                       
                    %create mask where data is not zero
                    dataNonZeroMask = measData ~= 0;                    
                    dataNonZeroMask(1:fi.StartPosition-1,:) = false;
                    dataNonZeroMask(fi.EndPosition+1:end,:) = false;
                    if(isempty(fi.reflectionMask))
                        dataNonZeroMask = dataNonZeroMask & repmat(fi.reflectionMask,1,size(dataNonZeroMask,2));
                    end
                    bounds = zeros(nParams,2);
                    bounds(:,2) = inf;                    
                    %create tiles                    
                    idxTiles = floor(linspace(0,dataYSz*dataXSz,nrTiles+1));
                    tic
                    dataSlices = cell(nrTiles,1);
                    dataNZMaskSlices = cell(nrTiles,1);                    
                    for i = 1:nrTiles
                        dataSlices{i} = measData(:,idxTiles(i)+1:idxTiles(i+1));
                        dataNZMaskSlices{i} = dataNonZeroMask(:,idxTiles(i)+1:idxTiles(i+1));
                    end                   
                    res = cell(nrTiles,3);
                    if(bp.reconvoluteWithIRF)
                        irffft = apObj.myChannels{ch}.getIRFFFT(nTimeCh);
                    else
                        irffft = [];
                    end                    
                    nExp = uint16(bp.nExp);
                    incompleteDecayFactor = uint16(bp.incompleteDecayFactor);
                    scatterEnable = logical(bp.scatterEnable);
                    scatterIRF = logical(bp.scatterIRF);
                    stretchedExpMask = logical(bp.stretchedExpMask);
                    parfor i = 1:nrTiles
                        tmp = cell(1,3);
                        md = single(dataSlices{i});
                        dnzm = dataNZMaskSlices{i};
                        aTmp = [];
                        oTmp = [];
                        mTmp = [];
                        expMTmp = [];
                        if(multiModelsFlag)
                            %different model for each pixel
                            %[mTmp, aTmp, ~, oTmp] = apObj.myChannels{ch}.compModel([tauOut(:,idxTiles(i)+1:idxTiles(i+1)); shiftOut(1,idxTiles(i)+1:idxTiles(i+1));]);
                            [amps, taus, tcis, betas, scAmps, scShifts, scHShiftsFine, scOset, hShift, offset, tciHShiftFine, nVecsTmp] = apObj.getXVecComponents([tauOut(:,idxTiles(i)+1:idxTiles(i+1)); shiftOut(:,idxTiles(i)+1:idxTiles(i+1))],true,ch);
                            myT = repmat(t(:,1),1,double(nExp)*nVecsTmp);                            
                            expMTmp = computeExponentials(nExp,incompleteDecayFactor,scatterEnable,scatterIRF,stretchedExpMask,...
                                myT,apObj.myChannels{ch}.iMaxPos,irffft,[],amps, taus, tcis, betas, scAmps, scShifts, [], scOset, hShift, offset, tciHShiftFine,false);
                            [ao,aTmp,oTmp] = computeAmplitudes(expMTmp,md,dnzm,offset,vcp.cMask(end)<0);
                            expMTmp(:,:,1:nVecsTmp) = bsxfun(@times,expMTmp(:,:,1:nVecsTmp),ao);
                            mTmp = squeeze(sum(expMTmp(:,:,1:nVecsTmp),2));
                        else
                            %same model for all pixels
                            [~,aTmp,oTmp] = computeAmplitudes(expModels,md,dnzm,oset,false);
                            mTmp = expModels * [aTmp; oTmp];
                            %expMTmp = bsxfun(@times,expModels,ao);
                            %mTmp = squeeze(sum(expMTmp(:,:,1:nVecsTmp),2));
                        end
                        %compute chi²
                        tmp{1,1} = computeFigureOfMerit(mTmp,md,dnzm,nParams,bp)';
                        tmp{1,2} = aTmp';
                        tmp{1,3} = oTmp';
                        res(i,:) = tmp;
                    end
                    %[chi2, ampsOut, osetOut] = computeTile(expModels,t,measDataTile,dataNonZeroMask,oset,bounds(:,1),bounds(:,2));
                    %collect results
                    chi2 = cell2mat(res(:,1));
                    ampsOut = cell2mat(res(:,2));
                    osetOut = cell2mat(res(:,3));
                    toc
                    chi2 = reshape(chi2,dataYSz,dataXSz);
                    ampsOut = reshape(ampsOut,dataYSz,dataXSz,nParams);
                    tauOut = reshape(permute(tauOut,[2,1]),dataYSz,dataXSz,nParams);
                    shiftOut = reshape(shiftOut,dataYSz,dataXSz);
                    osetOut = reshape(osetOut,dataYSz,dataXSz);
                    xVec = zeros(size(chi2,1),size(chi2,2),length(vcp.cMask));
                    xVec(:,:,1:apObj.basicParams.nExp) = ampsOut;
                    xVec(:,:,apObj.basicParams.nExp+1:2*apObj.basicParams.nExp) = tauOut;
                    xVec(:,:,end-1) = shiftOut;
                    xVec(:,:,end) = osetOut;
                    %store results
                    this.FLIMXObj.curSubject.setPixelFLIMItem(ch,'chi2',chi2);                    
                    for i = 1:apObj.basicParams.nExp
                        this.FLIMXObj.curSubject.setPixelFLIMItem(ch,sprintf('Amplitude%d',i),squeeze(ampsOut(:,:,i)));
                        this.FLIMXObj.curSubject.setPixelFLIMItem(ch,sprintf('Tau%d',i),squeeze(tauOut(:,:,i)));
                    end
                    this.FLIMXObj.curSubject.setPixelFLIMItem(ch,'x_vec',xVec);
                    this.FLIMXObj.curSubject.setPixelFLIMItem(ch,'hShift',xVec(:,:,end-1));
                    this.FLIMXObj.curSubject.setPixelFLIMItem(ch,'Offset',xVec(:,:,end));
                    this.FLIMXObj.curSubject.setEffectiveTime(ch,etime(clock,tStart));
                    this.updateProgressShort(0,'');
                    return
                end
            end
            
            
            %check if we should run the computation locally or distributed
            if(this.computationParams.useDistComp == 1 && length(pixelPool) > nWorkers)
                %use multicore package
                %prep multicore
                mcSettings.multicoreDir      = this.computationParams.mcShare;
                mcSettings.masterIsWorker    = this.computationParams.mcWorkLocal;
                mcSettings.nrOfEvalsAtOnce   = 1;
                %mcSettings.maxEvalTimeSingle = this.optimizationParams.options_de.maxiter*this.optimizationParams.options_de.NP*this.volatilePixelParams.nModelParamsPerCh*0.5;
                mcSettings.useWaitbar        = 1;
                mcSettings.computeJobHash    = this.computationParams.mcComputeJobHash;
                %                 if(this.computationParams.useDistComp == 2 || this.computationParams.useMatlabDistComp)
                %use parfor or run on LSF (and use parfor anyway)
                if(totalPixels <= 5*this.computationParams.mcTargetPixelPerWU) %at least 5 WUs
                    atOncePixel = 8; %max(1,floor(totalPixel/4)); %make 4 workunits
                    %                 elseif(totalPixel > 32 && totalPixel <= 64)
                    %                     atOncePixel = max(1,floor(totalPixel/8)); %make 8 workunits
                else % > 4*24 = 96 pixel, = 24/48/96/... pixel/wu -> >= 8 wu
                    atOncePixel = this.computationParams.mcTargetPixelPerWU*ceil(max(1,round(totalPixels/this.computationParams.mcTargetNrWUs))/this.computationParams.mcTargetPixelPerWU);                    
                end
                mcSettings.maxEvalTimeSingle = atOncePixel*2/8; %= guess 2s per pixel, running on 8 cores in parallel; todo
                iter = ceil(totalPixels/atOncePixel);
                parameterCell = cell(1,iter);
                idxCell = cell(1,iter);
                iter = 0;
                %sub = copy(this.FLIMXObj.curSubject);
                for i = 1:atOncePixel:totalPixels
                    iter = iter+1;
                    subPool = pixelPool(i:min(totalPixels,i+atOncePixel-1));
                    nPixel = length(subPool);
                    parameterCell{iter} = {@this.getApproxParamCell,ch,subPool,fitDim,initFit};
                    %parameterCell{iter} = {@sub.getApproxParamCell,ch,subPool,fitDim,initFit,this.optimizationParams,this.aboutInfo};
                    idx = zeros(nPixel,2);
                    if(fitDim == 2) %x
                        [idx(:,2), idx(:,1)] = ind2sub([x y],subPool);
                    else %y
                        [idx(:,1), idx(:,2)] = ind2sub([y x],subPool);
                    end
                    idxCell(iter) = {idx};
                end
                postProcessParams.idxCell = idxCell;
                postProcessParams.ch = ch;
                postProcessParams.dataSize = [y x];
                postProcessParams.initFit = initFit;
                mcSettings.postProcessParams = postProcessParams;
                mcSettings.postProcessHandle = @this.mcPostProcess;
                %distribute work
                if(this.computationParams.useDistComp == 1) %multicore
                    resultCell = startmulticoremaster(@makePixelFit, parameterCell, mcSettings);
                else %LSF                    
                end
                if(isempty(resultCell) || length(resultCell) ~= iter || isempty(resultCell{1}) || ischar(resultCell{1}))
                    %something went wrong
                    %todo: error message, cleanup
                    this.parameters.stopOptimization = true;
                    warning('FluoDecayFit:computeMultipleFits','Approximation process yielded empty or corrupt results - aborting...');
                    goOn = '';                    
                end
            else
                %compute locally
                if(this.computationParams.useMatlabDistComp > 0)
                    %run on all cores locally, get number of cores
                    atOncePixel = nWorkers;
                    if(any(ismember([1 4 6 7],this.pixelFitParams.optimizer)))
                        %we have a stochastic optimizer
                        atOncePixel = 2*max(atOncePixel,1); %make sure nPixel is at least 1 if something went wrong
                    else
                        %simplex or levenberg-marquardt
                        atOncePixel = 16*max(atOncePixel,1); %make sure nPixel is at least 1 if something went wrong
                    end
                else
                    %oldstyle singlethreaded
                    atOncePixel = 1;
                end
                for i = 1:atOncePixel:totalPixels
                    if(this.parameters.stopOptimization)
                        %user wants to stop
                        this.parameters.stopOptimization = false;
                        goOn = '';
                        break;
                    end
                    [parameterCell, idx] = this.getApproxParamCell(ch,pixelPool(i:min(totalPixels,i+atOncePixel-1)),fitDim,initFit);
                    if(isempty(parameterCell) || isempty(idx))
                        goOn = '';
                        break
                    end
                    resultStruct = makePixelFit(parameterCell{:});
                    if(~isstruct(resultStruct))
                        %something went wrong
                        %todo: error message, cleanup
                        this.parameters.stopOptimization = true;
                        warning('FluoDecayFit:makeLocalFit','Approximation process yielded empty results - aborting...');
                        goOn = '';
                        break
                    end
                    %store results
                    if(initFit)
                        this.FLIMXObj.curSubject.addInitResult(ch,idx,resultStruct);
                        %update waitbar
                        this.updateProgressShort(i/totalPixels,sprintf('Initialization: %02.1f%%',i/totalPixels*100));
                    else
                        this.FLIMXObj.curSubject.addMultipleResults(ch,idx,resultStruct);
                        %display results
                        if(isempty(lastUpdate) || etime(clock, lastUpdate) > 5)
                            this.FLIMXObj.FLIMFitGUI.setCurrentPos(idx(end,1),idx(end,2));
                            lastUpdate = clock;
                        end
                        %update waitbar
                        [hours, minutes, secs] = secs2hms(etime(clock,tStart)/i*(totalPixels-i)); %mean cputime for finished runs * cycles left
                        this.updateProgressShort(i/totalPixels,sprintf('%02.1f%% - Time left: %02.0fh %02.0fm %02.0fs',i/totalPixels*100,hours,minutes,secs));
                    end
                end %for i = 1:atOncePixel:totalPixel
            end            
            this.updateProgressShort(0,'');
        end
        
        %         matlabpool('addfiledependencies',{'differentialevolution.m','MSimplexBnd.m','multiExpModel.m','makePixelFit.m',...
        %         'runOpt.m','defWrapper.m','combineXVec.m','splitXVec','sliceXVec.m','getOptParams.m','sWnd1DAvg.m','fastGrad.m','checkQuantization.m','getBounds.m',...
        %         'checkBounds.m','makeOffsetGuess.m','mergeXVec.m','gethostname.m','getEndPos.m',...
        %         'getdefaultparams.m','catstruct.m'});
        %,[cd '\config\FitConfig.ini']
        
        %matlabpool('updatefiledependencies')
        
        function result = makeSingleCurveFit(this,ch,yPos,xPos,mcSettings)
            %make single curve fit
            if(yPos == 0 && xPos == 0)
                %initalization fit
                parameterCell = this.getApproxParamCell(ch,0,3,true);
            else
                pixelPool = sub2ind([this.FLIMXObj.curSubject.getROIYSz() this.FLIMXObj.curSubject.getROIXSz()],yPos,xPos);
                parameterCell = this.getApproxParamCell(ch,pixelPool,3,false);
            end
            if(~isempty(mcSettings))
                parameterCell = repmat(parameterCell,1,this.initFitParams.mcInitNrCopies);
                resultCell = startmulticoremaster(@makePixelFit, parameterCell, mcSettings);
                if(isempty(resultCell))
                    return;
                end
                res = cell2mat(resultCell);
                [~, idx] = min([res(1,:).chi2]);
                result = res(1,idx);
            else
                parameterCell{2}.options_de.iterPostProcess = @this.iterPostProcess;
                result = feval(@makePixelFit, parameterCell{:});
            end
            this.updateProgressShort(0,'');
        end
                
        function goOn = makeCleanUpFit(this,ch,initFit)
            %find outliers in current result and try to improve them
            if(~this.cleanupFitParams.enable || (initFit && ~this.FLIMXObj.curSubject.isInitResult(ch)) || (~initFit && ~this.FLIMXObj.curSubject.isPixelResult(ch)) || isempty(this.cleanupFitParams.target))
                goOn = 'nothingToDo';
                return
            end
            this.parameters.stopOptimization = false;
            goOn = 'normal';
            %[dStr, stratStr] = this.getOutlierSearchStr();
            if(any(this.volatilePixelParams.globalFitMask))
                ch = 1:this.FLIMXObj.curSubject.nrSpectralChannels;
            end
            chi2 = [];
            for ci = 1:this.cleanupFitParams.iterations
                for chIdx = ch
                    for i = 1:length(this.cleanupFitParams.target)
                        dStr = this.cleanupFitParams.target{i};
                        dStr(isstrprop(dStr,'wspace')) = '';
                        if(initFit)
                            data{i,chIdx} = this.FLIMXObj.curSubject.getInitFLIMItem(chIdx,dStr);
                        else
                            data{i,chIdx} = this.FLIMXObj.curSubject.getPixelFLIMItem(chIdx,dStr);
                        end
                    end
                    if(initFit)
                        chi2Tmp =  this.FLIMXObj.curSubject.getInitFLIMItem(chIdx,'chi2');
                        xVec{chIdx} = this.FLIMXObj.curSubject.getInitFLIMItem(chIdx,'x_vec');
                    else
                        chi2Tmp =  this.FLIMXObj.curSubject.getPixelFLIMItem(chIdx,'chi2');
                        xVec{chIdx} = this.FLIMXObj.curSubject.getPixelFLIMItem(chIdx,'x_vec');
                    end
                    if(isempty(chi2))
                        chi2 = chi2Tmp.^2;
                    else
                        chi2 = chi2 + chi2Tmp.^2;
                    end
                end
                if(initFit)
                    apObj = this.FLIMXObj.curSubject.getInitApproxObjs(ch(1));
                    apObj = apObj{1,1};
                else
                    apObj = this.FLIMXObj.curSubject.getApproxObj(ch(1),1,1);
                end
                secStageParams = this.prepareSecondStage(apObj,data,chi2,xVec,ch);
                %secStageParams.stratStr = stratStr;
                %build combined hit mask
                hit = false(size(chi2));
                hit(secStageParams.pixelPool) = true;
                %save hit mask in result
                for chIdx = ch                    
                    if(initFit)
                        iVec = this.FLIMXObj.curSubject.getInitFLIMItem(chIdx,'iVec');
                    else
                        iVec = this.FLIMXObj.curSubject.getPixelFLIMItem(chIdx,'iVec');
                    end
                    [y, x, z] = size(iVec);
                    for i = 1:length(secStageParams.pixelPool)
                        [yi, xi] = ind2sub([y x],secStageParams.pixelPool(i));
                        iVec(yi,xi,:) = apObj.getFullXVec(chIdx,secStageParams.iVec(:,i));
                    end
                    if(initFit)
                        this.FLIMXObj.curSubject.setInitFLIMItem(chIdx,'iVec',iVec);
                        this.FLIMXObj.curSubject.setInitFLIMItem(chIdx,'CleanupHitMask',hit);
                    else
                        this.FLIMXObj.curSubject.setPixelFLIMItem(chIdx,'CleanupHitMask',hit);
                        this.FLIMXObj.curSubject.setPixelFLIMItem(chIdx,'iVec',iVec);
                    end
                end
                this.computeMultipleFits(chIdx,secStageParams.pixelPool,initFit);
            end
        end
                        
        function secStageParams = prepareSecondStage(this,apObj,data,chi2,xVec,chList)
            %make parameters structure for second approximation stage            
            secStageParams.pixelPool = [];  
            kernel = @median;
            if(this.cleanupFitParams.filterType == 1)
                kernel = @mean;
            end            
            fs = this.cleanupFitParams.filterSize;
            for chIdx = chList
                for i = 1:size(data,1)
                    th = this.cleanupFitParams.threshold(i);
                    if(~isempty(data))
                        rawImg = abs(data{i,chIdx});
                        medImg = sffilt(kernel,rawImg,[fs fs]);
                        hit = medImg ~= 0 & (rawImg >= medImg*(1+th) | rawImg <= medImg*(1-th));
                        secStageParams.pixelPool = [secStageParams.pixelPool; find(hit)];
                    end
                end
            end
            secStageParams.pixelPool = unique(secStageParams.pixelPool);
            %initialzation
            secStageParams.iVec = zeros(apObj.getVolatileChannelParams(chList(1)).nApproxParamsPerCh,length(secStageParams.pixelPool),length(chList));
            xArray = zeros(apObj.volatilePixelParams.nModelParamsPerCh,length(chList));%apObj.volatilePixelParams.nApproxParamsAllCh %apObj.getVolatileChannelParams(chList(1)).nApproxParamsPerCh
            for px = length(secStageParams.pixelPool):-1:1
                %8 neighbors
                [idx(1), idx(2)] = ind2sub(size(chi2),secStageParams.pixelPool(px));
                chiVec = measurementFile.get3DNbs(chi2,idx(1),idx(2),2);
                chiVec = chiVec(chiVec ~= 0);
                if(isempty(chiVec))
                    secStageParams.pixelPool(px) = [];
                    secStageParams.iVec(:,px) = [];
                else
                    %choose only the best solution in the surrounding
                    [~, cIdx] = min(chiVec(:));
                    if(length(chList) == 1)
                        tmpVec = measurementFile.get3DNbs(xVec{chIdx},idx(1),idx(2),2);
                        xArray = tmpVec(:,cIdx);
                        secStageParams.iVec(:,px) = apObj.getNonConstantXVec(chList,xArray);
                    else
                        for chIdx = chList
                            tmpVec = measurementFile.get3DNbs(xVec{chIdx},idx(1),idx(2),2);
                            xArray(:,chIdx) = tmpVec(:,cIdx);
                            secStageParams.iVec(:,px,chIdx) = apObj.getNonConstantXVec(chList,xArray(:,chIdx));
                        end
                    end
                end
            end
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % dependend properties
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function params = get.aboutInfo(this)
            %get about info
            params = this.FLIMXObj.paramMgr.getParamSection('about');
        end
        
        function params = get.computationParams(this)
            %get pre processing parameters
            params = this.FLIMXObj.paramMgr.getParamSection('computation');
        end
        
        function params = get.cleanupFitParams(this)
            %get cleanup fit parameters
            params = this.FLIMXObj.paramMgr.getParamSection('cleanup_fit');
        end
        
        function params = get.preProcessParams(this)
            %get pre processing parameters
            params = this.FLIMXObj.curSubject.preProcessParams;
        end
        
        function params = get.basicParams(this)
            %get basic fit parameters
            params = this.FLIMXObj.curSubject.basicParams;
        end
        
        function out = get.initFitParams(this)
            %make fitParams struct
            out = this.FLIMXObj.curSubject.initFitParams;
        end
        
        function out = get.pixelFitParams(this)
            %make fitParams struct
            out = this.FLIMXObj.curSubject.pixelFitParams;
        end
        
        function params = get.visualizationParams(this)
            %get visualization parameters
            params = this.FLIMXObj.paramMgr.getParamSection('fluo_decay_fit_gui');
        end
        
        function params = get.optimizationParams(this)
            %get optimization parameters
            params = this.FLIMXObj.curSubject.optimizationParams;
        end
        
        function params = get.boundsParams(this)
            %get bounds
            params = this.FLIMXObj.curSubject.boundsParams;
        end
        
        function params = get.volatilePixelParams(this)
            %get bounds
            params = this.FLIMXObj.curSubject.volatilePixelParams;
        end
    end % methods
    
    methods(Access = protected)
        %internal methods
        
    end %methods(private)
    methods(Static)
        
    end %methods(static)
end % classdef
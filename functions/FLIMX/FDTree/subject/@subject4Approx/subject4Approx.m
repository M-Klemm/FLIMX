classdef subject4Approx < fluoSubject %& matlab.mixin.Copyable
    %=============================================================================================================
    %
    % @file     subject4Approx.m
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
    % @brief    A class to represent a subject used for approximation
    %
    properties(GetAccess = public, SetAccess = private)
    end
    
    properties (Dependent = true) 
    end
    
    methods
        function this = subject4Approx(study,name)
            %constructor
            %this.FLIMXObj = hFLIMX;
            this = this@fluoSubject(study,name);            
        end
        
        %% input methods
        function init(this)
            %init measurement and result objects
            this.myMeasurement = measurement4Approx(this);
            this.myMeasurement.setProgressCallback(@this.updateProgress);
            this.myResult = result4Approx(this);
        end
        
        function setResultDirty(this,ch,flag)
            %set dirty flag 
            this.myResult.setDirty(ch,flag);
        end
        
        function setEffectiveTime(this,ch,t)
            %set the effective run time for the approximation of ch
            this.myResult.setEffectiveTime(ch,t);
        end
        
        function setPixelFLIMItem(this,ch,pStr,val)
            %set FLIMItem pStr to value val or add new FLIMItem
            this.myResult.setPixelFLIMItem(ch,pStr,val);
        end
        
        function setInitFLIMItem(this,ch,pStr,val)
            %set FLIMItem pStr to value val or add new FLIMItem
            this.myResult.setInitFLIMItem(ch,pStr,val);
        end
        
        function addInitResult(this,ch,indices,resultStruct)
            %add single results to our inner results structure
            this.myResult.addInitResult(ch,indices,resultStruct);
        end
        
        function addSingleResult(this,ch,row,col,resultStruct)
            %add single results to our inner results structure
            this.myResult.addSingleResult(ch,row,col,resultStruct);
        end
        
        function addMultipleResults(this,ch,indices,resultStruct)
            %add mupltiple results according to their indices
            this.myResult.addMultipleResults(ch,indices,resultStruct);
        end
        
        function addResultColumn(this,ch,col,resultStruct)
            %add complete results column from a cell array to our inner results structure
            this.myResult.addResultColumn(ch,col,resultStruct);
        end
        
        function addResultRow(this,ch,row,resultStruct)
            %add complete results row from a cell array to our inner results structure
            this.myResult.addResultRow(ch,row,resultStruct);
        end
        
        
        %% output
        function [parameterCell, idx] = getApproxParamCell(this,ch,pixelPool,fitDim,initFit,optimizationParams,aboutInfo)
            %put all data needed for approximation in a cell array (corresponds to makePixelFit interface)
            if(initFit)
                %initialization fit                
                if(any(pixelPool > this.initFitParams.gridSize^2))
                    parameterCell = [];
                    idx = [];
                    return
                end
                apObjs = this.getInitApproxObjs(ch);
                apObjs = apObjs(pixelPool);
                idx = zeros(length(pixelPool),2);
                [idx(:,1), idx(:,2)] = ind2sub([this.initFitParams.gridSize this.initFitParams.gridSize],pixelPool);
                %nPixel = this.initFitParams.gridSize^2;
            else
                %ROIData = this.FLIMXObj.curSubject.getROIData(ch,[],[],[]);
                y = this.getROIYSz();
                x = this.getROIXSz();
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
                %subject = this.FLIMXObj.curSubject;
                for i = 1:nPixel %loop over roi pixel
                    apObjs{i} = getApproxObj(this,ch,idx(i,1),idx(i,2));
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
            parameterCell(2) = {optimizationParams};
%             if(initFit)
%                 parameterCell(3) = {initVec};
%             else
%                 parameterCell(3) = {initVec(:,1:length(pixelPool))};
%             end
            parameterCell(3) = {aboutInfo};
        end
        
        
%         function success = checkFileInfoLoaded(this)
%             %check if a measurement channel is loaded, if not, load any channel if available
%             if(~this.myMeasurement.fileInfoLoaded && ~isempty(this.myMeasurement.nonEmptyChannelList))
%                 this.myMeasurement.getRawData(this.myMeasurement.nonEmptyChannelList(1));                
%             end
%             success = this.myMeasurement.fileInfoLoaded;
%         end
%         
%         function out = getFileInfoStruct(this,ch)
%             %return fileinfo struct
%             out = this.myResult.getFileInfoStruct(ch);            
%             if(isempty(out) && this.checkFileInfoLoaded())
%                 %result doesn't have fileInfo, try to get it from measurement
%                 if(isempty(ch) && ~isempty(this.myMeasurement.nonEmptyChannelList))
%                     %pick first available channel
%                     ch = this.myMeasurement.nonEmptyChannelList(1);
%                 end
%                 out = this.myMeasurement.getFileInfoStruct(ch);
%             end
%         end
%         
%         %% output methods measurement
%         function out = get.tacRange(this)
%             %get tac range
%             fi = this.getFileInfoStruct([]);
%             out = [];
%             if(~isempty(fi))
%                 out = fi.tacRange;
%             end
%         end
%         
%         function out = get.nrTimeChannels(this)
%             %get nr of time channels
%             fi = this.getFileInfoStruct([]);
%             out = [];
%             if(~isempty(fi))
%                 out = fi.nrTimeChannels;
%             end
%         end
%         
%         function out = get.timeChannelWidth(this)
%             %get time channel width
%             fi = this.getFileInfoStruct([]);
%             out = [];
%             if(~isempty(fi))
%                 out = fi.tacRange / fi.nrTimeChannels * 1000;
%             end
%         end
%         
%         function out = get.nrSpectralChannels(this)
%             %get number of spectral channels
%             fi = this.getFileInfoStruct([]);
%             out = [];
%             if(~isempty(fi))
%                 out = fi.nrSpectralChannels;
%             end
%         end
%         
%         function out = get.timeVector(this)
%             %get a vector of time points for each "time" class
%             fi = this.getFileInfoStruct([]);
%             out = [];
%             if(~isempty(fi))
%                 out = linspace(0,fi.tacRange,fi.nrTimeChannels)';
%             end
%         end
%         
%         function out = getReflectionMask(this,channel)
%             %get reflection mask of channel
%             fi = this.getFileInfoStruct(channel);
%             out = [];
%             if(~isempty(fi))
%                 out = fi.reflectionMask{channel};
%             end
%         end
%         
%         function out = getStartPosition(this,channel)
%             %get start position of channel
%             fi = this.getFileInfoStruct(channel);
%             out = [];
%             if(~isempty(fi))
%                 out = this.fileInfo.StartPosition{channel};
%             end
%         end
%         
%         function out = getEndPosition(this,channel)
%             %get end position of channel
%             fi = this.getFileInfoStruct(channel);
%             out = [];
%             if(~isempty(fi))
%                 out = fi.EndPosition{channel};
%             end
%         end
%         
%         function out = get.ROICoordinates(this)
%             %returns the coordinates of the ROI            
%             if(this.checkFileInfoLoaded())
%                 out = this.myMeasurement.ROICoordinates;
%             else
%                 out = zeros(1,4);
%             end
%         end
%         
%         function out = getROIXSz(this)
%             %return ROI width of x axis
%             out = 0;
%             coord = this.myMeasurement.ROICoordinates;
%             if(~isempty(coord))
%                 out = coord(2) - coord(1) +1;
%             end
%         end
%         
%         function out = getROIYSz(this)
%             %return ROI width of y axis
%             out = 0;
%             coord = this.myMeasurement.ROICoordinates;
%             if(~isempty(coord))
%                 out = coord(4) - coord(3) +1;
%             end
%         end
%         
%         function out = getRawXSz(this)
%             %return raw width of x axis
%             this.checkFileInfoLoaded();
%             out = this.myMeasurement.rawXSz;
%         end
%         
%         function out = getRawYSz(this)
%             %return raw width of x axis
%             this.checkFileInfoLoaded();
%             out = this.myMeasurement.rawYSz;
%         end
%         
%         function out = getStudyName(this)
%             %get study name
%             out = this.studyName;
%         end
%         
%         function out = getDatasetName(this)
%             %get subject name
%             out = this.name;
%         end
%         
%         function out = getRawDataFlat(this,channel)
%             %get intensity image of (raw) measurement data
%             out = this.myMeasurement.getRawDataFlat(channel);
%         end
%         
%         function out = getROIDataFlat(this,channel,bin)
%             %get intensity of roi for channel
%             out = this.myMeasurement.getROIDataFlat(channel,bin);
%         end
%         
%         function out = getROIData(this,channel,bin,y,x)
%             %get roi data for channel
%             out = this.myMeasurement.getROIData(channel,bin,y,x);
%         end
%         
%          function out = getROIMerged(this,channel)
%             %get the ROI merged to a single decay
%             out = this.myMeasurement.getROIMerged(channel);
%          end
%         
%         function out = getInitData(this,ch,target)
%             %returns data for initialization fit of the corners of the ROI, each corner has >= target photons
%             out = this.myMeasurement.getInitData(ch,target);
%         end
%         
%         %% output result
%         function out = get.resultIsDirty(this)
%             %return flag if result is dirty
%             out = this.myResult.isDirty;
%         end
%         
%         function out = getResultNames(this,ch,isInitResult)
%             %get the names of the result structure
%             out = this.myResult.getResultNames(ch,isInitResult);
%         end
%         
%         function out = isInitResult(this,ch)
%             %true if init result was set
%             out = this.myResult.isInitResult(ch);
%         end
%         
%         function out = isPixelResult(this,ch,y,x,initFit)
%             %true if pixel result was set
%             if(nargin == 2)
%                 out = this.myResult.isPixelResult(ch);
%             else
%                 out = this.myResult.isPixelResult(ch,y,x,initFit);
%             end
%         end
%         
%         function out = getInitFLIMItem(this,ch,pStr)
%             %return specific init result, e.g. tau 1
%             out = this.myResult.getInitFLIMItem(ch,pStr);
%         end        
%         
%         function out = getPixelFLIMItem(this,ch,pStr,y,x)
%             %return specific pixel result, e.g. tau 1, optional pixel coordinates
%             if(nargin == 5) %toDo: fix this ugly construct
%                 out = this.myResult.getPixelFLIMItem(ch,pStr,y,x);
%             else
%                 out = this.myResult.getPixelFLIMItem(ch,pStr);
%             end
%         end
%         
%         function [apObj, xVec, hShift, oset, chi2, chi2Tail, TotalPhotons, iterations, time, slopeStart, iVec] = getVisParams(this,ch,y,x,initFit)
%             %get parameters for visualization of current fit in channel ch
%             if(initFit)
%                 apObjs = this.getInitApproxObjs(ch);                
%                 apObj = apObjs{sub2ind([this.initFitParams.gridSize this.initFitParams.gridSize],y,x)};
%             else
%                 apObj = this.getApproxObj(ch,y,x);
%             end
%             [apObj, xVec, hShift, oset, chi2, chi2Tail, TotalPhotons, iterations, time, slopeStart, iVec] = this.myResult.getVisParams(apObj,ch,y,x,initFit);
%         end
%         
%         function out = getInitApproxObjs(this,ch)
%             %make parameter structure needed for approximation of initialization
%             params.volatilePixel = this.volatilePixelParams;
%             params.volatileChannel = this.getVolatileChannelParams(0);
%             params.basicFit = this.basicParams;
%             params.preProcessing = this.preProcessParams;
%             params.computation = this.computationParams;
%             params.bounds = this.boundsParams;
%             params.pixelFit = this.initFitParams;
%             %set optimizerInitStrategy for init fits to 1 (use guess values)
%             params.basicFit.optimizerInitStrategy = 1;
%             ad = this.myResult.getAuxiliaryData(ch);
%             if(any(this.volatilePixelParams.globalFitMask))
%                 allIRFs = cell(1,this.fileInfo.nrSpectralChannels);
%                 for ch = 1:this.fileInfo.nrSpectralChannels
%                     fileInfo(ch) = ad.fileInfo;
%                     allIRFs{ch} = ad.IRF.vector;
%                 end                
%                 data = zeros(params.pixelFit.gridSize,params.pixelFit.gridSize,fileInfo(ch).nrTimeChannels,fileInfo(ch).nrSpectralChannels,fileInfo(ch).ROIDataType);
%                 scatterData = zeros(fileInfo(ch).nrTimeChannels,params.volatilePixel.nScatter,fileInfo(ch).nrSpectralChannels,fileInfo(ch).ROIDataType);
%                 for ch = 1:fileInfo(ch).nrSpectralChannels
%                     data(:,ch) = this.myMeasurement.getInitData(this,ch,params.pixelFit.gridPhotons);
%                     %scatter data %[nrTimeCh nrScatter nrSpectralCh] = size(scatter);
%                     scatterData(:,:,ch) = ad.scatter;                    
%                 end
%             else
%                 fileInfo(ch) = ad.fileInfo;
%                 allIRFs{ch} = ad.IRF.vector;
%                 data = this.myMeasurement.getInitData(ch,params.pixelFit.gridPhotons);
%                 %scatter data %[nrTimeCh nrScatter nrSpectralCh] = size(scatter);
%                 scatterData = ad.scatter;
%             end
%             for i = 1:params.pixelFit.gridSize^2
%                 [r, c] = ind2sub([params.pixelFit.gridSize params.pixelFit.gridSize],i);
%                 tmp = fluoPixelModel(allIRFs,fileInfo,params);
%                 tmp.setCurrentChannel(ch);
%                 tmp.setMeasurementData(squeeze(data(r,c,:)));
%                 if(~isempty(scatterData))
%                     tmp.setScatterData(scatterData);
%                 end
%                 out{i} = tmp;
%             end            
%         end
%         
%         %% output parameters
%         function out = get.computationParams(this)
%             %get computation parameters
%             out = this.myParamMgr.getParamSection('computation');
%         end
%         
%         function set.computationParams(this,val)
%             %set computation parameters
%             this.myParamMgr.setParamSection('computation',val);
%         end
%         
%         function out = get.folderParams(this)
%             %get folder parameters
%             out = this.myParamMgr.getParamSection('folders');
%         end
%         
%         function out = get.preProcessParams(this)
%             %get pre processing parameters
%             out = this.myParamMgr.getParamSection('pre_processing');            
%         end
%         
%         function out = get.basicParams(this)
%             %get basic fit parameters
%             out = this.myParamMgr.getParamSection('basic_fit');             
%         end
%         
%         function set.basicParams(this,val)
%             %set basic fit parameters
%             this.myParamMgr.setParamSection('basic_fit',val);             
%         end
%         
%         function out = get.initFitParams(this)
%             %get init fit parameters
%             out = this.myParamMgr.getParamSection('init_fit'); 
%         end
%         
%         function out = get.pixelFitParams(this)
%             %get per pixel fit parameters
%             out = this.myParamMgr.getParamSection('pixel_fit'); 
%         end
%         
%         function out = get.boundsParams(this)
%             %get bounds
%             out = this.myParamMgr.getParamSection('bounds'); 
%         end
%         
%         function out = get.optimizationParams(this)
%             %get optimizer parameters
%             out = this.myParamMgr.getParamSection('optimization'); 
%         end
%         
%         function out = get.volatilePixelParams(this)
%             %get volatile fit parameters for all pixels
%             out = this.myParamMgr.getParamSection('volatilePixel'); 
%         end
%         
%         function out = getVolatileChannelParams(this,ch)
%             %get volatile fit parameters for specific channel (ch = empty returns cell with all channels)
%             out = this.myParamMgr.getVolatileChannelParams(ch);
%         end
%         
%         function out = getApproxObj(this,ch,y,x)
%             %make parameter structure needed for approximation
%             params.volatilePixel = this.volatilePixelParams;
%             params.volatileChannel = this.getVolatileChannelParams(0);
%             params.basicFit = this.basicParams;
%             params.preProcessing = this.preProcessParams;
%             params.computation = this.computationParams;
%             params.bounds = this.boundsParams;
%             params.pixelFit = this.pixelFitParams;
%             if(params.basicFit.fixHShift2Init)
%                 sStr = params.basicFit.(sprintf('constMaskSaveStrCh%d',ch));
%                 idx = find(strcmp('h-Shift (tc)',sStr),1);
%                 if(isempty(idx))
%                     idx = length(sStr)+1;
%                 end 
%                 sStr{idx} = 'h-Shift (tc)';
%                 params.basicFit.(sprintf('constMaskSaveStrCh%d',ch)) = sStr;
%                 val = this.myResult.getPixelFLIMItem(ch,'hShift',y,x);
%                 if(isempty(val))
%                     %value not found in result
%                     val = 0;
%                 end               
%                 params.basicFit.(sprintf('constMaskSaveValCh%d',ch))(idx) = val;
%                 [params.volatilePixel, params.volatileChannel] = paramMgr.makeVolatileParams(params.basicFit,this.myMeasurement.nrSpectralChannels);
%             end
%             ad = this.myResult.getAuxiliaryData(ch);
%             if(any(this.volatilePixelParams.globalFitMask))
%                 allIRFs = cell(1,this.myMeasurement.nrSpectralChannels);
%                 for ch = 1:this.myMeasurement.nrSpectralChannels
%                     fileInfo(ch) = ad.fileInfo;
%                     allIRFs{ch} = ad.IRF.vector;
%                 end                
%                 data = zeros(params.pixelFit.gridSize,params.pixelFit.gridSize,fileInfo(ch).nrTimeChannels,fileInfo(ch).nrSpectralChannels,fileInfo(ch).ROIDataType);
%                 scatterData = zeros(fileInfo(ch).nrTimeChannels,params.volatilePixel.nScatter,fileInfo(ch).nrSpectralChannels,fileInfo(ch).ROIDataType);
%                 for ch = 1:fileInfo(ch).nrSpectralChannels
%                     data(:,ch) = this.myMeasurement.getROIData(ch,[],y,x);
%                     %scatter data %[nrTimeCh nrScatter nrSpectralCh] = size(scatter);
%                     scatterData(:,:,ch) = ad.scatter;                    
%                 end
%             else
%                 fileInfo(ch) = ad.fileInfo;
%                 allIRFs{ch} = ad.IRF.vector;
%                 data = this.myMeasurement.getROIData(ch,[],y,x);
%                 %scatter data %[nrTimeCh nrScatter nrSpectralCh] = size(scatter);
%                 scatterData = ad.scatter;
%             end
%             out = fluoPixelModel(allIRFs,fileInfo,params);
%             out.setCurrentChannel(ch);
%             %load measurement data into the object
%             if(~isempty(data))
%                 out.setMeasurementData(data);
%             end
%             %load scatter data into the object
%             if(~isempty(scatterData))
%                 out.setScatterData(scatterData);
%             end
%             %load neighbors
%             if(params.basicFit.neighborFit)
%                 if(any(params.volatilePixel.globalFitMask))
%                     nbs = this.myMeasurement.getNeigborData(1:fileInfo(ch).nrSpectralChannels,[],y,x,params.basicFit.neighborFit);
%                 else
%                     nbs = this.myMeasurement.getNeigborData(ch,[],y,x,params.basicFit.neighborFit);
%                 end
%                 out.setNeighborData(nbs);
%             end
%             %load init data into the object
%             if(this.basicParams.optimizerInitStrategy == 2 || this.basicParams.fixHShift2Init)
%                 out.setInitializationData(ch,out.getNonConstantXVec(ch,this.getPixelFLIMItem(ch,'iVec',y,x)));
%             end
%         end
%         
%         function save2Disk(this,ch,expDir,addStr)
%             %write results to disk
%             if(nargin < 2)
%                 expDir = this.folderParams.export;
%                 addStr = '';
%             end
%             if(~isdir(expDir))
%                 warndlg(sprintf('Could not find Export-Path:\n %s\n\nInstead results will be saved to:\n %s',expDir,cd),...
%                     'Export Path not found!','modal');
%                 expDir = cd;
%             end
%             if(strcmp(expDir(end),filesep)) %remove possible tailing '\'
%                 expDir = expDir(1:end-1);
%             end
%             expStr = fullfile(expDir,this.name,sprintf('%dexp_%dtci_%s_%s',...
%                 this.basicParams.nExp,sum(this.basicParams.tciMask),addStr,datestr(now,'dd.mmm.yyyy_HH.MM.SS')));
%             mkdir(expStr);
%             if(any(this.volatilePixelParams.globalFitMask))
%                 %global fit: save all channels
%                 for ch = 1:this.nrSpectralChannels
%                     this.myResult.saveMatFile2Disk(ch);
%                     %save measurement data as well
%                     this.myMeasurement.saveMatFile2Disk(ch,expStr);
%                 end
%             else
%                 this.myResult.saveMatFile2Disk(ch);
%                 %save measurement data as well
%                 this.myMeasurement.saveMatFile2Disk(ch,expStr);
%             end
%         end
%                 
%         
%         %% compute methods
%         function updateProgress(this,prog,text)
%             %update progress bar for all handles we've got
%             for i = length(this.progressCb):-1:1
%                 try
%                     this.progressCb{i}(prog,text);
%                 catch
%                     this.progressCb{i} = [];
%                 end
%             end
%         end

        function makeMeasurementROIData(this,channel,binFactor)
            %force building roi from raw data in measurement
            if(isempty(binFactor))
                binFactor = this.myMeasurement.roiBinning;
            end
            this.myMeasurement.makeROIData(channel,binFactor);
        end       
        
        
    end
    methods(Access = protected)
        % Override copyElement method:
        function cpObj = copyElement(this)            
            %make sure we create the approx. obects for all channels            
            for ch = 1:this.nrSpectralChannels
                this.getApproxObj(ch,1,1);
            end
            % Make a shallow copy of all properties
            cpObj = copyElement@matlab.mixin.Copyable(this);
            % Make a deep copy of the DeepCp object
            cpObj.myParent = []; 
            cpObj.progressCb = cell(0,0);
        end
    end
    
end
classdef fluoChannelModel < matlab.mixin.Copyable
    %=============================================================================================================
    %
    % @file     fluoChannelModel.m
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
    % @brief    A class which models a multi exponential decay.
    %
    properties(SetAccess = protected)
        myParent = [];
        myChannelNr = 0;
        dataStorage = [];      
        %model = []; %vector of modelpoints
        dLen = 0; %length of data vector
        iLen = 0; %length of irf vector
        tLen = []; %length of t vector
        neighborRez = []; %reziproke of neighbors
        neighborMaxPosCorrectRez = []; %reziproke of maximum position corrected neighbors
        chi_weights = []; %weights for chi2 computation with neighbors
        irfFFT = []; %fft transform of irf
        irfFFTGPU = []; %irf on GPU (for GPU computation)
        dMaxVal = 0; %max of data
        dMaxPos = 0; %position of data max (index)
        dFWHMPos = 0; %position of full width at half maximum (index)
%         mMaxVal = 0; %max of model
%         mMaxPos = 0; %position of model max (index)
        iMaxVal = 0; %max of irf
        iMaxPos = 0; %position of irf max (index)
        myStartPos = 1;
        myEndPos = 1024;
        %idxLookUp = [];
        linLB = []; %lower bounds for linear optimized parameters
        linUB = []; %upper bounds for linear optimized parameters
    end
    
    properties (Dependent = true)
        time = []; %vector of timepoints
        nScatter = 0;
        basicParams = 0;
        volatilePixelParams = [];
        volatileChannelParams = [];
        fileInfo = 0;
        useGPU = false; %flag to use Matlab GPU processing features
        useMex = false; %flag to use optimized mex file for linear optimizer
    end
    
    methods
        function this = fluoChannelModel(hPixel,irf,ch)
            %Constructs a channel model object.
            this.myParent = hPixel;
            this.myChannelNr = ch; 
            if(this.basicParams.incompleteDecay) %incomplete decay
                ds = 2;
            else %no incomplete decay
                ds = 1;
            end
            this.tLen = this.fileInfo.nrTimeChannels*ds;
            [val, this.iMaxPos] = max(irf(:));
            this.iMaxVal = double(val);
            this.dataStorage.irf.raw = irf;
            this.dataStorage.measurement.raw = []; %vector of datapoints
            this.dataStorage.measurement.rez = []; %reziproke of datapoints          
            this.dataStorage.measurement.nonZeroMask = false; %data non-zero indices
            this.dataStorage.measurement.nonZeroMaskTail = false; %data non-zero indices max to end            
            this.dataStorage.neighbor.raw = []; %matrix with data of surrounding pixels used for chi² computation
            this.dataStorage.neighbor.rez = []; %matrix with reziproke of data of surrounding pixels used for chi² computation
            this.dataStorage.neighbor.nonZeroMask = false; %neighbor non-zero indices
            this.dataStorage.neighbor.nonZeroMaskTail = false; %neighbor non-zero indices max to end
            this.dataStorage.scatter.raw = []; %matrix with scatter light vector(s)
            this.dataStorage.scatter.normalized = [];
            this.dataStorage.chiWeights.raw = []; %vector of weights for chi² computation
            this.dataStorage.chiWeights.rez = []; %reziporoke of chi² weights
            this.dataStorage.initialization = []; %initialization for non-linear optimizer
            this.iLen = length(irf);
            %this.idxLookUp = repmat((0:int16(this.tLen)-1)',1,1);
            if(length(this.basicParams.tciMask) > this.basicParams.nExp)
                error('Number of tci too high! %d set, %d allowed (%d exponentials)',length(this.basicParams.tciMask),this.basicParams.nExp,this.basicParams.nExp);
            end            
        end
        
        function setParent(this,hParent)
            %set handle to parent object (fluoPixelModel)
            if(isa(hParent,'fluoPixelModel'))
                this.myParent = hParent;
            end
        end
        
        function out = get.basicParams(this)
            %return basicParams struct
            out = this.myParent.basicParams;
        end
                
        function out = get.fileInfo(this)
            %return fileInfo struct for my channel
            out = this.myParent.getFileInfo(this.myChannelNr);
        end        
        function out = get.volatilePixelParams(this)
            %return volatilePixelParams struct for my channel
            out = this.myParent.volatilePixelParams;
        end
        
        function out = get.volatileChannelParams(this)
            %return volatileChannelParams struct for my channel
            out = this.myParent.getVolatileChannelParams(this.myChannelNr);
        end
        
        function out = get.useGPU(this)
            %return useGPU flag
            out = this.myParent.useGPU;
        end
        
        function out = get.useMex(this)
            %return useMex flag
            out = this.myParent.useMex;
        end
        
        function out = get.time(this)
            %get time vector
            out = double(linspace(0,(this.tLen-1)*this.fileInfo.timeChannelWidth,this.tLen)');
        end
        
        function out = getIRF(this)
            %get irf
            out = double(this.dataStorage.irf.raw)./this.iMaxVal;
        end
        
        function out = getMeasurementData(this)
            %get measurement data
            out = single(this.dataStorage.measurement.raw);
        end
        
        function out = getMeasurementDataRez(this)
            %get reziproke of data
            if(isempty(this.dataStorage.measurement.rez))
                this.dataStorage.measurement.rez = 1./this.getMeasurementData();
            end
            out = this.dataStorage.measurement.rez;
        end
        
        function out = getChiWeightData(this)
            %get chi weights
            out = double(this.dataStorage.chiWeights.raw);
            if(isempty(out))
                %we don't have weights, return data
                out = double(max(this.getMeasurementData(),1));
                %out = ones(this.dLen,1);
            end
        end
        
        function out = getChiWeightDataRez(this)
            %get reziproke of chi weights
            if(isempty(this.dataStorage.chiWeights.rez))
                this.dataStorage.chiWeights.rez = 1./this.getChiWeightData();
            end
            out = this.dataStorage.chiWeights.rez;
        end        
        
        function out = getDataNonZeroMask(this)
            %return mask where measurement data is not zero
            out = this.dataStorage.measurement.nonZeroMask;
        end        
        
        function out = getNeighborData(this)
            %get data
            out = double(this.dataStorage.neighbor.raw);
        end        
        
        function out = getNeighborDataRez(this)
            %get reziproke of data
            if(isempty(this.dataStorage.neighbor.rez))
                this.dataStorage.neighbor.rez = 1./this.getNeighborData();
            end
            out = this.dataStorage.neighbor.rez;
        end
        
        function out = getScatterData(this)
            %get scatter data
            if(isempty(this.dataStorage.scatter.normalized) && ~isempty(this.dataStorage.scatter.raw)) 
                %make normalized scatter data
                %normalize  
                data = double(this.dataStorage.scatter.raw);
                [nTime, nScatter] = size(data);
                smoothData = zeros(nTime,nScatter);                
                for i = 1:nScatter
                    smoothData(:,i) = fastsmooth(data(:,i),3,3,0);
                end
                %remove offset from scatter data
                data = bsxfun(@minus,data,min(smoothData(50:end-50,:),[],1));
                %fill zero gaps
                data(data < 0) = 0;
                data = bsxfun(@times,data,1./max(data,[],1));                
                nonZero = data ~= 0;                
                rot = floor(nTime/2);
                for i = 1:nScatter
                    smoothData(:,i) = circshift(fastsmooth(data(:,i),3,3,0),rot);
                    %remove 10 points from the borders
                    nonZero(1:find(nonZero,1,'first')+5,i) = false;
                    nonZero(find(nonZero,1,'last')-5:end,i) = false;
                    nonZero(:,i) = circshift(nonZero(:,i), rot);
                    smoothData(:,i) = interp1(find(nonZero(:,i)),smoothData(nonZero(:,i),i),1:nTime)';
                    smoothData(:,i) = circshift(smoothData(:,i), -rot);
                    nonZero(:,i) = circshift(nonZero(:,i), -rot);
                end
                data(~nonZero) = smoothData(~nonZero);
                this.dataStorage.scatter.normalized = data;
            end
            out = this.dataStorage.scatter.normalized;
        end
        
        function out = getInitializationData(this)
            %set initialization data for nonlinear optimization
            out = this.dataStorage.initialization;
            if(isempty(out))
                out = zeros(this.volatileChannelParams.nApproxParamsPerCh,1);
            end
        end
        
        function setLinearBounds(this,linBounds)
            %set linear bounds
            nrLinParam = sum(this.volatileChannelParams.cMask < 0);
            if(~isempty(linBounds) && numel(linBounds.lb) == nrLinParam)
                this.linLB = single(linBounds.lb(:));
            else
                this.linLB =  single(-inf(nrLinParam,1));
            end
            if(~isempty(linBounds) && numel(linBounds.ub) == nrLinParam)
                this.linUB =  single(linBounds.ub(:));
            else
                this.linUB =  single(inf(nrLinParam,1));
            end
        end
        
        function setMeasurementData(this,pixelData)
            %set measurement data for this pixel
            fi = this.fileInfo;
            this.myStartPos = fi.StartPosition;
            this.myEndPos = fi.EndPosition;         
            %             if(~this.basicParams.useGPU)
            %pixelData = pixelData + 50;
            %use cpu
            this.dataStorage.measurement.raw = pixelData;
            [maxVal, this.dMaxPos] = max(pixelData(:,1));
            if(this.basicParams.fitModel ~=1)
                this.myStartPos = this.dMaxPos;
            end
            this.dMaxVal = double(maxVal);
            [~,this.dFWHMPos] = max(bsxfun(@gt,pixelData,maxVal/2),[],1);
            this.dLen = length(pixelData);
            this.chi_weights = ones(1,size(pixelData,2));            
            %                 if(~isempty(neighborData))
            %                     this.chi_weights(1,2:end) = double(fitParams.neighbor_weight/(size(neighborData,1)));
            %                 end
            %% get postions where data is zero
            if(~isempty(pixelData))
                this.dataStorage.measurement.nonZeroMask = pixelData > 0; %~= 0;
                this.dataStorage.measurement.nonZeroMask(1:fi.StartPosition-1,:) = false;
                %this.dataStorage.measurement.nonZeroMask(fitParams.EndPosition+1:end,:) = 0;
                if(isempty(fi.reflectionMask))
                    fi.reflectionMask = true(size(this.dataStorage.measurement.nonZeroMask));
                end
                this.dataStorage.measurement.nonZeroMask = this.dataStorage.measurement.nonZeroMask & fi.reflectionMask;
                this.dataStorage.measurement.nonZeroMaskTail = this.dataStorage.measurement.nonZeroMask;
                this.dataStorage.measurement.nonZeroMaskTail(1:this.dMaxPos-1,:) = false;
            else
                this.dataStorage.measurement.nonZeroMask = false;
                this.dataStorage.measurement.nonZeroMaskTail = false;
            end
            
            %             else
            %                 %use gpu
            %                 %get data onto the gpu
            %                 %                 this.data = data;
            %                 %                 this.updateDMax();
            %                 %                 this.dataGPU = gsingle(data);
            %                 %                 this.dataRez = 1./this.data;
            %                 %                 this.chi_weights = ones(1,size(data,2));
            %                 %                 if(size(data,2) > 1)
            %                 %                     this.chi_weights(1,2:end) = gsingle(fitParams.neighbor_weight/(size(data,2)-1));
            %                 %                 end
            %                 %                 this.dLen = gsingle(size(data,1));
            %                 %                 this.time = gsingle(linspace(0,(ds*this.dLen-1)*this.fileInfo.timeChannelWidth,ds*this.dLen)');
            %                 %                 this.tLen = this.dLen*ds;
            %                 %                 %% get postions where data is zero
            %                 %                 this.dataStorage.measurement.nonZeroMask = data ~= 0;
            %                 %                 this.dataStorage.measurement.nonZeroMask(1:fitParams.StartPosition-1,:) = 0;
            %                 %                 this.dataStorage.measurement.nonZeroMaskTail = this.dataStorage.measurement.nonZeroMask;
            %                 %                 this.dataStorage.measurement.nonZeroMaskTail(1:this.dMaxPos,:) = 0;
            %                 %                 this.dataStorage.measurement.nonZeroMask = gsingle(find(this.dataStorage.measurement.nonZeroMask));
            %                 %                 this.dataStorage.measurement.nonZeroMaskTail = gsingle(find(this.dataStorage.measurement.nonZeroMaskTail));
            %                 %                 this.irf = gsingle(irf);
            %                 this.data = double(data);
            %                 this.dataRez = 1./this.data;
            %                 this.chi_weights = ones(1,size(data,2));
            %                 if(size(data,2) > 1)
            %                     this.chi_weights(1,2:end) = double(fitParams.neighbor_weight/(size(data,2)-1));
            %                 end
            %                 this.dLen = double(size(data,1));
            %                 this.time = double(linspace(0,(ds*this.dLen-1)*this.fileInfo.timeChannelWidth,ds*this.dLen)');
            %                 this.tLen = this.dLen*ds;
            %                 %% get postions where data is zero
            %                 if(~isempty(data))
            %                     this.dataStorage.measurement.nonZeroMask = data ~= 0;
            %                     this.dataStorage.measurement.nonZeroMask(1:fitParams.StartPosition-1,:) = false;
            %                     %this.dataStorage.measurement.nonZeroMask(fitParams.EndPosition+1:end,:) = 0;
            %                     if(isempty(fitParams.reflectionMask))
            %                         fitParams.reflectionMask = true(size(this.dataStorage.measurement.nonZeroMask));
            %                     end
            %                     this.dataStorage.measurement.nonZeroMask = this.dataStorage.measurement.nonZeroMask & fitParams.reflectionMask;
            %                 else
            %                     this.dataStorage.measurement.nonZeroMask = [];
            %                 end
            %                 this.irf = double(irf);
            %                 this.updateDMax();
            %                 this.dataStorage.measurement.nonZeroMaskTail = this.dataStorage.measurement.nonZeroMask;
            %                 this.dataStorage.measurement.nonZeroMaskTail(1:this.dMaxPos,:) = 0;
            %             end
            
        end
        
        function setChiWeightData(this,weightData)
            %set chi weights data
            this.dataStorage.chiWeights.raw = weightData;
            this.dataStorage.chiWeights.rez = [];            
        end
        
        function setNeighborData(this,neighborData)
            %set neighbor data
            this.dataStorage.neighbor.raw = neighborData;
            if(~isempty(neighborData))
                this.dataStorage.neighbor.nonZeroMask = this.dataStorage.neighbor.raw ~= 0;
                this.dataStorage.neighbor.nonZeroMask(1:this.fileInfo.StartPosition-1,:) = false;
                %this.dataStorage.measurement.nonZeroMask(fitParams.EndPosition+1:end,:) = 0;
                this.dataStorage.neighbor.nonZeroMask = bsxfun(@and,this.dataStorage.neighbor.nonZeroMask,this.fileInfo.reflectionMask);
                this.dataStorage.neighbor.nonZeroMaskTail = this.dataStorage.neighbor.nonZeroMask;
                this.dataStorage.neighbor.nonZeroMaskTail(1:this.dMaxPos,:) = 0;
            else
                this.dataStorage.neighbor.nonZeroMask = false;
                this.dataStorage.neighbor.nonZeroMaskTail = false;
            end            
            
            %             if(params.basicParams.neighborFit)
            %                 nr_nbs = size(neighbors,2);
            %                 %set start positions for neighbors
            %                 params.preProcessing.StartPosition = repmat(params.preProcessing.StartPosition,1,nr_nbs+1,nrChannels);
            %                 %set end positions for neighbors and check if automated end position is not 'smaller' than pre-set end position (we don't want zeros at the end!)
            %                 EndPosition = zeros(1,nr_nbs+1,nrChannels);
            %                 EndPosition(1) = params.preProcessing.EndPosition;
            %                 for j = 1:nr_nbs
            %                     for ch = 1:nrChannels
            %                         %get start/end positions for neighbors
            %                         EndPosition(j+1,ch) = getEndPos(squeeze(neighbors(:,j,ch)));
            %                     end
            %                 end
            %                 EndPosition(EndPosition > params.preProcessing.EndPosition) = params.preProcessing.EndPosition;
            %                 params.preProcessing.EndPosition = EndPosition;
            %             end
        end
        
        function setScatterData(this,scatterData)
            %set scatter data            
            this.dataStorage.scatter.raw = scatterData;
            this.dataStorage.scatter.normalized = [];
        end
        
        function setInitializationData(this,data)
            %set initialization data for nonlinear optimization (optional)
            this.dataStorage.initialization = data;
        end
        
%         function updateMMax(this)
%             %get max value & position from model vector
%             [this.mMaxVal, this.mMaxPos] = max(this.model,[],1);
%         end
        
        function [model, ampsOut, scAmpsOut, osetOut, exponentialsOut] = compModel(this,x)
            % compute model for parameters x and reconvolute
            % inputs:   x       - parameterset, e.g. [a1; a2; a3; t1; t2; t3; tc2; tc3; scA1 scS1 vShift hShift oset;]
            %lsqlinOpts = optimset('TolFun',0.01,'TolX',0.001,'LargeScale','on','Display','off');
            %             if(this.basicParams.useGPU)
            %                 x=gsingle(x);
            %             else
            %                 x=double(x);
            %             end
            persistent t tSingle exponentialsLong exponentialsShort exponentialsOffset
            [amps, taus, tcis, betas, scAmps, scShifts, scHShiftsFine, scOset, hShift, oset, tciHShiftFine, nVecs] = getXVecComponents(this.myParent,x,true,this.myChannelNr);
            bp = this.basicParams;
            nTimeCh = this.tLen;            
            if(bp.incompleteDecay)
                nTimeCh = nTimeCh ./ 2;
            end
            vpp = this.volatilePixelParams;
            vcp = this.volatileChannelParams;
            nExp = bp.nExp;
            taus = 1./taus;
            if(isempty(t) || size(t,1) ~= this.tLen || size(t,2) < nVecs)
                t = repmat(this.time(:,1),1,nVecs);
                tSingle = single(t(:,1));
            end     
            if(vpp.nScatter > 0)
                %shiftAndLinearOpt function will move all components by hShift -> compensate scatter shifts here
                tcis = [tcis; bsxfun(@minus,scShifts,hShift)];                
            end
            tciHShiftFine = [tciHShiftFine; scHShiftsFine];
            %% allocate memory for temporary vatiables
            if(isempty(exponentialsLong) || size(exponentialsLong,1) ~= size(t,1) || size(exponentialsLong,3) < nVecs || size(exponentialsLong,2) ~= nExp || size(exponentialsShort,2) ~= nExp+vpp.nScatter)
                exponentialsLong = ones(size(t,1),nExp,nVecs);
                exponentialsShort = ones(nTimeCh,nExp+vpp.nScatter,nVecs);
                exponentialsOffset = ones(nTimeCh,nExp+vpp.nScatter+1,nVecs,'single');                
            end
            if(~isempty(this.dataStorage.scatter.raw))
                scVec = repmat(this.getScatterData(),[1,1,nVecs]);
            else
                scVec = zeros(size(exponentialsShort,1),vpp.nScatter,nVecs);
            end
            
            %% get approximation for current parameters
            data = this.getMeasurementData();
            %% prepare scatter
            for i = 1:vpp.nScatter
                scVec(:,i,:) = bsxfun(@plus,squeeze(scVec(:,i,:)),scOset(i,:));
%                 scVec(:,i,:) = circShiftArray(bsxfun(@times, squeeze(scVec(:,i,:)),scAmps(i,:)).*this.dMaxVal,scShifts(i,:));
            end
%                 this.myStartPos = max(this.fileInfo.StartPosition + min(scShifts(:)), this.fileInfo.StartPosition);
%                 this.myEndPos = min([this.fileInfo.EndPosition + min(scShifts(:)), this.fileInfo.EndPosition, nTimeCh]);
            %% make exponentials
            if(any(vcp.cMask < 0))
                %hybrid fit
                %stretched exponentials
                for i = find(bp.stretchedExpMask)                    
                    exponentialsLong(:,i,1:nVecs) = exp(-bsxfun(@power,bsxfun(@times, t(:,1:nVecs), taus(i,:)), betas(i,:)));
                end
                %'normal' exponentials
                for i = find(~bp.stretchedExpMask)
                    exponentialsLong(:,i,1:nVecs) = exp(-bsxfun(@times, t(:,1:nVecs), taus(i,:)));
                end                
            else
                %no hybrid fit
                %stretched exponentials
                for i = find(bp.stretchedExpMask)
                    exponentialsLong(:,i,1:nVecs) = bsxfun(@times, exp(-bsxfun(@power,bsxfun(@times, t(:,1:nVecs), taus(i,:)), betas(i,:))), amps(i,:));
                end
                %'normal' exponentials
                for i = find(~bp.stretchedExpMask)
                    exponentialsLong(:,i,1:nVecs) = bsxfun(@times, exp(-bsxfun(@times, t(:,1:nVecs), taus(i,:))), amps(i,:));
                end
                %scatter
                for i = 1:vpp.nScatter
                    exponentialsShort(:,nExp+i,1:nVecs) = bsxfun(@times, squeeze(scVec(:,i,1:nVecs)),scAmps(i,:));
                end
            end            
            %% reconvolute
            if(bp.fitModel ~= 2)
                %determine reconv model length
                [~, p] = log2(size(exponentialsLong,1)-1); %+ this.iLen -1
                len_model_2 = pow2(p);    % smallest power of 2 > len_model
                if(this.useGPU && nVecs > 1) %uses matlab gpu support, on a gtx295 by a factor of ~2 slower than core i7 @ 3,9 GHz
                    if(isempty(this.irfFFTGPU) || nExp ~= size(this.irfFFTGPU,2) || nVecs ~= size(this.irfFFTGPU,3))
                        irfPad = zeros(size(exponentialsLong,1),1);
                        irfPad(1:this.iLen) = this.irf;
                        this.irfFFTGPU = fft(gpuArray(repmat(irfPad,[1,nExp,nVecs])));
                    end
                    exponentialsLong(:,1:nExp,1:nVecs) = gather(real(ifft(fft(gpuArray(exponentialsLong(:,1:nExp,1:nVecs))) .* this.irfFFTGPU)));
                else
                    if(isempty(this.irfFFT) || length(this.irfFFT) == len_model_2)
                        this.irfFFT = fft(this.getIRF(), len_model_2);
                    end
                    exponentialsLong(:,1:nExp,1:nVecs) = real(ifft(bsxfun(@times, fft(exponentialsLong(:,1:nExp,1:nVecs), len_model_2, 1), this.irfFFT), len_model_2, 1));
                end
            end
            %% incomplete decay
            if(bp.incompleteDecay)
                exponentialsShort(1:nTimeCh,1:nExp,1:nVecs) = exponentialsLong(1:nTimeCh,:,1:nVecs) + exponentialsLong(nTimeCh+1:end,:,1:nVecs);
            else
                exponentialsShort(1:nTimeCh,1:nExp,1:nVecs) = exponentialsLong(1:nTimeCh,:,1:nVecs);
            end
            %% normalize model to max=1
            exponentialsShort(:,1:nExp,1:nVecs) = bsxfun(@times,exponentialsShort(:,1:nExp,1:nVecs),1./max(exponentialsShort(:,1:nExp,1:nVecs),[],1));
            
            if(vpp.nScatter > 0)
                exponentialsShort(:,nExp+1:nExp+vpp.nScatter,1:nVecs) = scVec(:,:,1:nVecs);
            end
            %% move to position of data maximum + hShift - tci
            if(this.useMex && this.dLen == 1024 && size(exponentialsShort,2) <= 16 && nVecs <= 256) %&& strcmp(bp.timeInterpMethod,'linear')
                %[exponentialsOffset(:,1:nExp+vpp.nScatter,1:nVecs), ao] = shiftAndLinearOpt_mex(exponentialsShort(1:nTimeCh,:,1:nVecs),t(1:nTimeCh,1),data,this.dataStorage.measurement.nonZeroMask,hShift,tcis,tciHShiftFine,oset,this.linLB,this.linUB,bp.timeInterpMethod);
                [exponentialsOffset(:,1:nExp+vpp.nScatter,1:nVecs), ao] = shiftAndLinearOpt_mex(single(exponentialsShort(1:nTimeCh,:,1:nVecs)),tSingle(1:nTimeCh,1),data,this.dataStorage.measurement.nonZeroMask,...
                    single(hShift),single(tcis),single(tciHShiftFine),single(oset),this.linLB,this.linUB,true);
            elseif(this.useMex && this.dLen > 1024 && this.dLen <= 4096 && size(exponentialsShort,2) <= 16 && nVecs <= 256)
                [exponentialsOffset(:,1:nExp+vpp.nScatter,1:nVecs), ao] = shiftAndLinearOpt4096_mex(single(exponentialsShort(1:nTimeCh,:,1:nVecs)),tSingle(1:nTimeCh,1),data,this.dataStorage.measurement.nonZeroMask,...
                    single(hShift),single(tcis),single(tciHShiftFine),single(oset),this.linLB,this.linUB,true);
            else
                [exponentialsOffset(:,1:nExp+vpp.nScatter,1:nVecs), ao] = shiftAndLinearOpt(single(exponentialsShort(1:nTimeCh,:,1:nVecs)),tSingle(1:nTimeCh,1),data,this.dataStorage.measurement.nonZeroMask,...
                    single(hShift),single(tcis),single(tciHShiftFine),single(oset),this.linLB,this.linUB,false);                              
            end
            if(~any(vcp.cMask < 0))
                ao(1,:,:) = [amps; scAmps; oset];
            end
            exponentialsOffset(:,end,1:nVecs) = ones(nTimeCh,nVecs,1,'single');            
            ampsOut = double(squeeze(ao(1,1:nExp,:)));
            osetOut = double(squeeze(ao(1,end,:)));
            if(vpp.nScatter > 0)
                scAmpsOut = double(squeeze(ao(1,nExp+1:nExp+vpp.nScatter,:)));
            else
                scAmpsOut = zeros(0,nVecs);
            end
            exponentialsOffset(isnan(exponentialsOffset)) = 0;
            exponentialsOffset(:,:,1:nVecs) = bsxfun(@times,exponentialsOffset(:,:,1:nVecs),ao);
            model = squeeze(sum(exponentialsOffset(:,:,1:nVecs),2));
            if(bp.heightMode == 2)
                %force model to maximum of data
                model = bsxfun(@times,model, 1./max(model,[],1)).*this.dMaxVal;
            end
            %this.model = model;
            %this.updateMMax();
            if(nargout == 5)
                exponentialsOut = exponentialsOffset(:,:,1:nVecs);
            end
        end %compModelTci
        
        function [chi, chiD, chiVec] = compFigureOfMerit(this,model,tailFlag,errorMode,chiWeightingMode)
            %compute the figure of merit (goodness of fit)            
            if(nargin < 5)
                chiWeightingMode = this.basicParams.chiWeightingMode;
            end            
            if(nargin < 4)
                errorMode = this.basicParams.errorMode;
            end 
            persistent e_lsq_NB
            nrM = size(model,2);
            if(this.basicParams.neighborFit)
                nrNB = size(this.dataStorage.neighbor.raw,2);
            else
                nrNB = 0;
            end                
            if(errorMode < 5)
                %% get errors & least squares                
                e_lsq = bsxfun(@minus,model,this.getMeasurementData()).^2;
                if(nrNB)
                    if(isempty(e_lsq_NB) || size(e_lsq_NB,1) ~= this.fileInfo.nrTimeChannels || size(e_lsq_NB,2) < nrM*nrNB)
                        e_lsq_NB = zeros(this.fileInfo.nrTimeChannels,nrM*nrNB);
                    end
                    NBs = this.getNeighborData();
                    NBsRez = this.getNeighborDataRez();
                    for i = 1:nrNB
                        e_lsq_NB(:,(i-1)*nrM+1 : i*nrM) = bsxfun(@minus,model,NBs(:,i)).^2;
                    end
                end
                
                %% compute error measure
                %             if(this.basicParams.useGPU)
                %                 e_lsq = e_lsq - repmat(this.dataRez,1,nrM);
                %                 idx = 1:size(model,1);
                %                 idx(this.dataStorage.measurement.nonZeroMask) = 0;
                %                 idx(1:this.myStartPos-1) = 0;
                %                 idx(this.myEndPos:end) = 0;
                %                 idx = repmat(logical(idx),1,nrM);
                %                 e_lsq(idx) = 0;
                %                 chiVec = sum(e_lsq,1) .* repmat(this.chi_weights,1,nrM) ./ (sum(this.dataStorage.measurement.nonZeroMask,1)-this.volatileChannelParams.nApproxParamsPerCh);  %(numel(this.dataStorage.measurement.nonZeroMask)-this.volatileChannelParams.nApproxParamsPerCh);
                %                 chi = sum(chiVec(:));
                %                 chiD = chiVec(1);
                %             else
            end
            switch chiWeightingMode
                case 2
                    m_nz_idx = model > 0;
                    m_nz_idx(1:this.fileInfo.StartPosition-1,:) = false;
                    m_nz_idx(this.fileInfo.EndPosition+1:end,:) = false;
                    if(isempty(this.fileInfo.reflectionMask))
                        reflectionMask = true(size(this.dataStorage.measurement.nonZeroMask));
                    else
                        reflectionMask = this.fileInfo.reflectionMask;
                    end
                    m_nz_idx = m_nz_idx & repmat(reflectionMask,1,nrM);
                    m_rez = 1./model(m_nz_idx);
                    e_lsq(m_nz_idx) = e_lsq(m_nz_idx) .* m_rez;
                    e_lsq(~m_nz_idx) = 0;
                case 3
                    e_lsq = bsxfun(@times,e_lsq,this.getChiWeightDataRez()); 
                case 4
                    e_lsq = bsxfun(@times,e_lsq,this.getChiWeightDataRez().*1./(this.dMaxVal*min(this.getChiWeightDataRez()))); %normalize weight vector to data maximum
                otherwise
                    e_lsq = bsxfun(@times,e_lsq,this.getMeasurementDataRez());
            end
            %use only residuum of non-zero values in measurement data
            if(tailFlag)
                e_lsq(repmat(~this.dataStorage.measurement.nonZeroMaskTail,1,nrM)) = 0;
            else
                e_lsq(repmat(~this.dataStorage.measurement.nonZeroMask,1,nrM)) = 0;
            end
                    
            switch errorMode  
                case 1 %regular chi²
                    if(tailFlag)
                        chiVec = sum(e_lsq,1) ./ (sum(this.dataStorage.measurement.nonZeroMaskTail,1)-this.volatileChannelParams.nApproxParamsPerCh);
                    else
                        chiVec = sum(e_lsq,1) ./ (sum(this.dataStorage.measurement.nonZeroMask,1)-this.volatileChannelParams.nApproxParamsPerCh);%(numel(this.dataStorage.measurement.nonZeroMask)-this.volatileChannelParams.nApproxParamsPerCh);
                    end
                    if(nrNB)
                        %goodness of fit measure for neighbor pixels
                        for i = 1:nrNB
                            e_lsq_NB(:,(i-1)*nrM+1 : i*nrM) = bsxfun(@times,e_lsq_NB(:,(i-1)*nrM+1 : i*nrM),NBsRez(:,i));
                            if(tailFlag)
                                e_lsq_NB(~this.dataStorage.neighbor.nonZeroMaskTail(:,i),(i-1)*nrM+1 : i*nrM) = 0;
                            else
                                e_lsq_NB(~this.dataStorage.neighbor.nonZeroMask(:,i),(i-1)*nrM+1 : i*nrM) = 0;
                            end
                        end
                        nbSum = sum(e_lsq_NB,1);
                        if(tailFlag)
                            chiVecNB = bsxfun(@times,nbSum(1:nrM*nrNB),this.basicParams.neighborWeight) ./ repmat(sum(this.dataStorage.neighbor.nonZeroMaskTail,1)-this.volatileChannelParams.nApproxParamsPerCh,1,nrM);  %(numel(this.dataStorage.measurement.nonZeroMask)-this.volatileChannelParams.nApproxParamsPerCh);
                        else
                            chiVecNB = bsxfun(@times,nbSum(1:nrM*nrNB),this.basicParams.neighborWeight) ./ repmat(sum(this.dataStorage.neighbor.nonZeroMask,1)-this.volatileChannelParams.nApproxParamsPerCh,1,nrM);  %(numel(this.dataStorage.measurement.nonZeroMask)-this.volatileChannelParams.nApproxParamsPerCh);
                        end
                        chiVec = chiVec.^2 + sum(reshape(chiVecNB./nrNB,nrM,nrNB),2).^2';
                    end
                    
                case 2 %boost chi2 around the 'peak'
                    idx = false(size(e_lsq));
                    idx(1:min(this.basicParams.ErrorMP2+this.basicParams.ErrorMP3+1,this.myEndPos),:) = true;
                    idx = circShiftArray(idx,repmat(max(this.dMaxPos-this.basicParams.ErrorMP2-1,0),1,nrM));
                    roi = e_lsq(idx);
                    %boost error only if model is too high
                    roi(roi > 0) = (roi(roi > 0).*this.basicParams.ErrorMP1).^2;%boost
                    e_lsq(idx) = roi;
                    if(tailFlag)
                        chiVec = sum(e_lsq,1) ./ (sum(this.dataStorage.measurement.nonZeroMaskTail,1)-this.volatileChannelParams.nApproxParamsPerCh);
                    else
                        chiVec = sum(e_lsq,1) ./ (sum(this.dataStorage.measurement.nonZeroMask,1)-this.volatileChannelParams.nApproxParamsPerCh);  %(numel(this.dataStorage.measurement.nonZeroMask)-this.volatileChannelParams.nApproxParamsPerCh);
                    end
                    if(nrNB)
                        %goodness of fit measure for neighbor pixels
                        for i = 1:nrNB
                            e_lsq_NB(:,(i-1)*nrM+1 : i*nrM) = bsxfun(@times,e_lsq_NB(:,(i-1)*nrM+1 : i*nrM),this.dataStorage.neighbor.rez(:,i));
                            if(tailFlag)
                                e_lsq_NB(~this.dataStorage.neighbor.nonZeroMaskTail(:,i),(i-1)*nrM+1 : i*nrM) = 0;
                            else
                                e_lsq_NB(~this.dataStorage.neighbor.nonZeroMask(:,i),(i-1)*nrM+1 : i*nrM) = 0;
                            end
                            tmp = e_lsq_NB(:,(i-1)*nrM+1 : i*nrM);
                            roi = tmp(idx);
                            %boost error only if model is too high
                            roi(roi > 0) = roi(roi > 0).*this.basicParams.ErrorMP1;%boost
                            tmp(idx) = roi;
                            e_lsq_NB(:,(i-1)*nrM+1 : i*nrM) = tmp;
                        end
                        nbSum = sum(e_lsq_NB,1);
                        if(tailFlag)
                                chiVecNB = bsxfun(@times,nbSum(1:nrM*nrNB),this.basicParams.neighborWeight) ./ repmat(sum(this.dataStorage.neighbor.nonZeroMaskTail,1)-this.volatileChannelParams.nApproxParamsPerCh,1,nrM);  %(numel(this.dataStorage.measurement.nonZeroMask)-this.volatileChannelParams.nApproxParamsPerCh);                        
                        else
                            chiVecNB = bsxfun(@times,nbSum(1:nrM*nrNB),this.basicParams.neighborWeight) ./ repmat(sum(this.dataStorage.neighbor.nonZeroMask,1)-this.volatileChannelParams.nApproxParamsPerCh,1,nrM);  %(numel(this.dataStorage.measurement.nonZeroMask)-this.volatileChannelParams.nApproxParamsPerCh);
                        end
                        chiVec = chiVec.^2 + sum(reshape(chiVecNB./nrNB,nrM,nrNB),2).^2';
                    end                 
%                 case 7 %maximum likelihood
%                     tmp = bsxfun(@minus,model,this.getMeasurementData());
%                     nz = repmat(this.dataStorage.measurement.nonZeroMask,1,nrM);
%                     tmp(~nz) = 0;
%                     t1 = sum(tmp,1)*2;
%                     tmp = log(bsxfun(@times,model,this.getMeasurementDataRez())).*model;
%                     tmp(~nz) = 0;
%                     t2 = sum(tmp,1)*2;
%                     chiVec = t1 + t2;
            end                                
            %chiVec = abs(1-chiVec);
            chiVec(chiVec == 0) = inf;
            chi = sum(chiVec(:));
            chiD = chiVec(1);
        end
        
        function out = compModelMask(this,model,mVec,invFlag)
            %compute a 'mask' of logicals for the model which corresponds to tci shifts
            %each element in sVec
            persistent idxLookUp
            [r, c] = size(model);
            if(any([r c] > size(idxLookUp)))
                %update if necessary
                idxLookUp = this.makeIdxLookUp(r,c);
            end
            mVec = int16(mVec(:));
            if(c ~= length(mVec))
                error('length of mVec=%d is not equal to number of columns in "model" array (size "model" =%dx%d)',length(mVec),r,c);
            end
            out = false(r,c);
            if(c == 1)
                idx = int16(0:r-1)-mVec+1;
            else
                idx = bsxfun(@minus,this.idxLookUp(1:r,1:c),mVec')+1;
            end
            if(invFlag)
                out(idx <= 0) = true;
            else
                out(idx > 0) = true;
            end
            %out(:,flagVec < 0) = false;
        end %compModelMask             
        
        function data = compShift(this,data,iLen,o_len,shift)
            %perform data shift
            % data - the data vector
            % iLen - length input vec
            % o_len - length output vec
            % shift - number of points to shift
            
            if(any(shift)) %if all elements in shift are zero: nothing to do
                data = circShiftArray(data,shift);
            end
            if(iLen >= o_len)
                data = data(1:o_len,:,:);
            else %iLen < o_len
                %padd with zeros
                data(iLen+1:o_len,:,:) = 0;
            end
        end %compShift
        
        function out = makeIdxLookUp(this,r,c)
            %make index lookup table
            out = repmat((0:int32(max(this.tLen,r))-1)',1,c);%max(size(this.idxLookUp,2),c));
        end
        
    end %methods
end % classdef
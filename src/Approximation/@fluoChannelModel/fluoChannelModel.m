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
        myStartPos = 1; %start position on the time axes used for figure of merit computation
        myEndPos = 1024; %end position on the time axes used for figure of merit computation
        iMaxVal = 0; %max of irf
        iMaxPos = 0; %position of irf max (index)
    end
    
    properties(GetAccess = protected, SetAccess = protected)
        myParent = [];
        dataStorage = []; %store measurement and related data
        myChannelNr = 0;
        dLen = 0; %length of data vector
        iLen = 0; %length of irf vector
        tLen = []; %length of t vector
        neighborRez = []; %reziproke of neighbors
        neighborMaxPosCorrectRez = []; %reziproke of maximum position corrected neighbors
        chi_weights = []; %weights for chi2 computation with neighbors
        irfFFT = []; %fft transform of irf
        irfFFTGPU = []; %irf on GPU (for GPU computation)
                
        linLB = []; %lower bounds for linear optimized parameters
        linUB = []; %upper bounds for linear optimized parameters        
    end
        
    properties (Dependent = true)
        dMaxVal = 1; %max of data
        dMaxPos = 0; %position of data max (index)
        dFWHMPos = 0; %position of full width at half maximum (index)
        dRisingIDs = []; %positions of data rising edge between 5% and 85%
        slopeStartPos = []; %positions of data rising edge
        offsetGuess = []; %educated guess of the offset in the data
        dRealStartPos = []; %actual time channel where data beginns (> 0)
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
            this.dataStorage.measurement.nonZeroMask = []; %data non-zero indices
            this.dataStorage.measurement.nonZeroMaskTail = []; %data non-zero indices max to end
            this.dataStorage.measurement.maxPos = [];      
            this.dataStorage.measurement.maxVal = [];
            this.dataStorage.measurement.FWHMPos = [];
            this.dataStorage.measurement.offsetGuess = [];
            this.dataStorage.measurement.slopeStartPos = [];
            this.dataStorage.measurement.realStartPos = [];
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
            this.setLinearBounds([]); %initialize linear bounds
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
            out = this.myParent.getFileInfoStruct(this.myChannelNr);
        end
        function out = get.volatilePixelParams(this)
            %return volatilePixelParams struct for my channel
            out = this.myParent.volatilePixelParams;
        end
        
        function out = get.volatileChannelParams(this)
            %return volatileChannelParams struct for my channel
            out = this.myParent.getVolatileChannelParams(this.myChannelNr);
        end
        
%         function out = get.useGPU(this)
%             %return useGPU flag
%             out = this.myParent.useGPU;
%         end
        
        function out = get.useMex(this)
            %return useMex flag
            out = this.myParent.useMex;
        end
        
        function out = get.time(this)
            %get time vector
            out = double(linspace(0,(this.tLen-1)*this.fileInfo.timeChannelWidth,this.tLen)');
        end
        
        function out = get.dMaxVal(this)
            %get data max
            if(isempty(this.dataStorage.measurement.maxVal))
                this.compSmoothedMaxValues();
            end
            out = this.dataStorage.measurement.maxVal;
        end
        
        function out = get.dMaxPos(this)
            %get data max
            if(isempty(this.dataStorage.measurement.maxPos))
                this.compSmoothedMaxValues();
            end
            out = this.dataStorage.measurement.maxPos;
        end
        
        function out = get.dFWHMPos(this)
            %get data max
            if(isempty(this.dataStorage.measurement.FWHMPos))
                this.compSmoothedMaxValues();
            end
            out = this.dataStorage.measurement.FWHMPos;
        end
        
        function out = get.dRisingIDs(this)
            %get positions of rising edge between 20% and 80% of data max
            if(isempty(this.dataStorage.measurement.FWHMPos))
                this.compSmoothedMaxValues();
            end
            out = this.dataStorage.measurement.risingIDs;
        end
        
        function out = get.slopeStartPos(this)
            %get positions of rising edge
            if(isempty(this.dataStorage.measurement.slopeStartPos))
                this.compOffsetGuess();
            end
            out = this.dataStorage.measurement.slopeStartPos;
        end
        
        function out = get.offsetGuess(this)
            %get educated guess of the offset in the data
            if(isempty(this.dataStorage.measurement.offsetGuess))
                this.compOffsetGuess();
            end
            out = this.dataStorage.measurement.offsetGuess;
        end
        
        function out = get.dRealStartPos(this)
            %get the actual start position of the data (in time channels)
            if(isempty(this.dataStorage.measurement.realStartPos))
                this.compOffsetGuess();
            end
            out = this.dataStorage.measurement.realStartPos;
        end
        
        function out = getIRF(this)
            %get irf
            out = double(this.dataStorage.irf.raw)./this.iMaxVal;
        end
        
        function out = getIRFFFT(this,len)
            %get FFT of irf
            if(isempty(this.irfFFT) || length(this.irfFFT) ~= len)
                this.irfFFT = fft(this.getIRF(), len);
            end
            out = this.irfFFT;
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
            if(isempty(this.dataStorage.measurement.nonZeroMask))
                this.compMeasurementZeroMask()
            end
            out = this.dataStorage.measurement.nonZeroMask;
        end
        
        function out = getDataNonZeroMaskTail(this)
            %return mask where measurement data is not zero
            if(isempty(this.dataStorage.measurement.nonZeroMaskTail))
                this.compMeasurementZeroMask()
            end
            out = this.dataStorage.measurement.nonZeroMaskTail;
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
                %                 data = bsxfun(@minus,data,min(smoothData(50:end-50,:),[],1));
                %fill zero gaps
                data(data < 0) = 0;
                data = bsxfun(@times,data,1./max(data,[],1));
                nonZero = data ~= 0;
                rot = floor(nTime/2);
                for i = 1:nScatter
                    smoothData(:,i) = circshift(fastsmooth(data(:,i),3,3,0),rot);
                    %remove 10 points from the borders
                    if(sum(nonZero > nTime/2))
                        nonZero(1:find(nonZero,1,'first')+5,i) = false;
                        nonZero(find(nonZero,1,'last')-5:end,i) = false;
                    end
                    nonZero(:,i) = circshift(nonZero(:,i), rot);
                    smoothData(:,i) = interp1(find(nonZero(:,i)),smoothData(nonZero(:,i),i),1:nTime)';
                    smoothData(:,i) = circshift(smoothData(:,i), -rot);
                    nonZero(:,i) = circshift(nonZero(:,i), -rot);
                end
                data(~nonZero) = smoothData(~nonZero);
                data(isnan(data)) = 0;
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
        
        function out = getLinearBounds(this)
            %return linear bounds used for approximation
            out = [this.linLB this.linUB];
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
            if(fi.EndPosition <= fi.StartPosition)
                fi.EndPosition = length(pixelData);
            end
            this.myEndPos = fi.EndPosition;
            this.dataStorage.measurement.raw = pixelData;
            this.dataStorage.measurement.nonZeroMask = [];
            this.dataStorage.measurement.nonZeroMaskTail = [];
            this.dataStorage.measurement.maxPos = [];
            this.dataStorage.measurement.maxVal = [];
            this.dataStorage.measurement.FWHMPos = [];
            this.dLen = length(pixelData);
            this.chi_weights = ones(1,size(pixelData,2));
%             if(~isempty(neighborData))
%                 this.chi_weights(1,2:end) = double(fitParams.neighbor_weight/(size(neighborData,1)));                
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
                this.dataStorage.neighbor.nonZeroMask(1:this.myStartPos-1,:) = false;
                this.dataStorage.neighbor.nonZeroMask(this.myEndPos+1:end,:) = false;
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
        
        function [model, ampsOut, scAmpsOut, osetOut, expModelOut] = compModel2(this,x)
            % compute model for parameters x
            persistent t exponentialsLong expModels
            scAmpsOut = [];
            [amps, taus, tcis, betas, scAmps, scShifts, scHShiftsFine, scOset, hShift, oset, tciHShiftFine, nVecs] = getXVecComponents(this.myParent,x,true,this.myChannelNr);
            bp = this.basicParams;
            bp.incompleteDecayFactor = 2;
            incompleteDecayFactor = max(1,bp.incompleteDecayFactor*bp.incompleteDecay);
            vpp = this.volatilePixelParams;
            nTimeCh = this.tLen;
            nTimeChNoID = nTimeCh / incompleteDecayFactor;
            if(isempty(t) || size(t,1) ~= this.tLen || size(t,2) < bp.nExp*nVecs)
                t = repmat(this.time(:,1),1,bp.nExp*nVecs);
            end
            if(isempty(exponentialsLong) || size(exponentialsLong,1) ~= size(t,1) || size(exponentialsLong,3) < nVecs || size(exponentialsLong,2) ~= bp.nExp || size(expModels,2) ~= bp.nExp+vpp.nScatter)
                exponentialsLong = ones(size(t,1),bp.nExp,nVecs);
                expModels = ones(nTimeChNoID,bp.nExp+vpp.nScatter+1,nVecs);
            end
            vcp = this.volatileChannelParams;            
            if(bp.reconvoluteWithIRF)
                irffft = this.getIRFFFT(nTimeCh);
            else
                irffft = [];
            end
            if(~isempty(this.dataStorage.scatter.raw))
                scVec = repmat(this.getScatterData(),[1,1,nVecs]);
            else
                scVec = zeros(nTimeChNoID,vpp.nScatter-bp.scatterIRF,nVecs);
            end
            expModels(1:nTimeChNoID,1:bp.nExp+vpp.nScatter+1,1:nVecs) = computeExponentials(uint16(bp.nExp),uint16(incompleteDecayFactor),logical(bp.scatterEnable),logical(bp.scatterIRF),...
                logical(bp.stretchedExpMask),t,int32(this.iMaxPos),irffft,scVec, taus, tcis, betas, scAmps, scShifts, scHShiftsFine, scOset, hShift, tciHShiftFine,false,exponentialsLong(1:nTimeCh,1:bp.nExp,1:nVecs),expModels(1:nTimeChNoID,1:bp.nExp+vpp.nScatter+1,1:nVecs));            
            if(~any(vcp.cMask < 0))
                ao(1,:,:) = [amps; scAmps; oset];
                ampsOut = double(squeeze(ao(1,1:bp.nExp,:)));
                osetOut = double(squeeze(ao(1,end,:)));
            else
                [ao,ampsOut,osetOut] = computeAmplitudes(expModels(1:nTimeChNoID,1:bp.nExp+vpp.nScatter+1,1:nVecs),this.getMeasurementData(),this.getDataNonZeroMask(),oset,vcp.cMask(end)<0,this.linLB,this.linUB);
                if(vpp.nScatter > 0)
                    scAmpsOut = ampsOut(bp.nExp+1:end,:);
                    ampsOut(bp.nExp+1:end,:) = [];
                end
            end
            expModels(1:nTimeChNoID,1:bp.nExp+vpp.nScatter+1,1:nVecs) = bsxfun(@times,expModels(1:nTimeChNoID,1:bp.nExp+vpp.nScatter+1,1:nVecs),ao);
            model = squeeze(sum(expModels(1:nTimeChNoID,1:bp.nExp+vpp.nScatter+1,1:nVecs),2));
            expModelOut = expModels(1:nTimeChNoID,1:bp.nExp+vpp.nScatter+1,1:nVecs);
        end
                
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
            if((vpp.nScatter-(bp.scatterEnable && bp.scatterIRF)) > 0)
                %shiftAndLinearOpt function will move all components by hShift -> compensate scatter shifts here
                tcis = [tcis; bsxfun(@minus,scShifts,hShift)];
                tciHShiftFine = [tciHShiftFine; scHShiftsFine];
            end
            %% allocate memory for temporary vatiables
            if(isempty(exponentialsLong) || size(exponentialsLong,1) ~= size(t,1) || size(exponentialsLong,3) < nVecs || size(exponentialsLong,2) ~= nExp || size(exponentialsShort,2) ~= nExp+vpp.nScatter)
                exponentialsLong = ones(size(t,1),nExp+(bp.scatterEnable && bp.scatterIRF),nVecs);
                exponentialsShort = ones(nTimeCh,nExp+vpp.nScatter,nVecs);
                exponentialsOffset = ones(nTimeCh,nExp+vpp.nScatter+1,nVecs,'single');
            end
            if(~isempty(this.dataStorage.scatter.raw))
                scVec = repmat(this.getScatterData(),[1,1,nVecs]);
            else
                scVec = zeros(size(exponentialsShort,1),vpp.nScatter-bp.scatterIRF,nVecs);
            end
            
            %% get approximation for current parameters
            data = this.getMeasurementData();
            %% prepare scatter
%             for i = 1:vpp.nScatter
%                 scVec(:,i,:) = bsxfun(@plus,squeeze(scVec(:,i,:)),scOset(i,:));
% %                 scVec(:,i,:) = circShiftArray(bsxfun(@times, squeeze(scVec(:,i,:)),scAmps(i,:)).*this.dMaxVal,scShifts(i,:));
%             end
%                 this.myStartPos = max(this.fileInfo.StartPosition + min(scShifts(:)), this.fileInfo.StartPosition);
%                 this.myEndPos = min([this.fileInfo.EndPosition + min(scShifts(:)), this.fileInfo.EndPosition, nTimeCh]);
            %% make exponentials
            %stretched exponentials
            for i = find(bp.stretchedExpMask)
                exponentialsLong(:,i,1:nVecs) = exp(-bsxfun(@power,bsxfun(@times, t(:,1:nVecs), taus(i,:)), betas(i,:)));
            end
            %'normal' exponentials
            for i = find(~bp.stretchedExpMask)
                exponentialsLong(:,i,1:nVecs) = exp(-bsxfun(@times, t(:,1:nVecs), taus(i,:)));
            end
            if(bp.scatterEnable && bp.scatterIRF)
                nExp = nExp+1;
                exponentialsLong(:,nExp,1:nVecs) = zeros(size(t,1),1,nVecs);
                exponentialsLong(1,nExp,1:nVecs) = 1;
            end
            %% reconvolute
            if(bp.reconvoluteWithIRF)
                %determine reconv model length
                [~, p] = log2(size(exponentialsLong,1)-1);
                len_model_2 = pow2(p);    % smallest power of 2 > len_model
%                 if(this.useGPU && nVecs > 1) %uses matlab gpu support
%                     if(isempty(this.irfFFTGPU) || length(this.irfFFTGPU) ~= len_model_2)
%                         this.irfFFTGPU = fft(gpuArray(this.getIRF()),len_model_2);
%                     end
%                     exponentialsLong(:,1:nExp,1:nVecs) = gather(real(ifft(bsxfun(@times, fft(exponentialsLong(:,1:nExp,1:nVecs), len_model_2, 1), this.irfFFTGPU), len_model_2, 1)));
%                 else
                    if(isempty(this.irfFFT) || length(this.irfFFT) ~= len_model_2)
                        this.irfFFT = fft(this.getIRF(), len_model_2);
                    end
                    exponentialsLong(:,1:nExp,1:nVecs) = real(ifft(bsxfun(@times, fft(exponentialsLong(:,1:nExp,1:nVecs), len_model_2, 1), this.irfFFT), len_model_2, 1));
%                 end
                if(bp.approximationTarget == 2 && this.myChannelNr <= 2) %only in anisotropy mode
                    %correct for shift caused by reconvolution
                    dtci = zeros(size(tcis));
                    [~,dtci(:,:)] = max(exponentialsShort(:,:,1:nVecs),[],1);
                    tcis = tcis - bsxfun(@minus,dtci,dtci(1,:));
                end
            else
                for i = 1:size(exponentialsLong,2)
                    exponentialsLong(:,i,1:nVecs) = circShiftArrayNoLUT(squeeze(exponentialsLong(:,i,1:nVecs)),repmat(this.iMaxPos,nVecs,1));
                end
            end
            %% incomplete decay
            if(bp.incompleteDecay)
                exponentialsShort(1:nTimeCh,1:nExp,1:nVecs) = exponentialsLong(1:nTimeCh,:,1:nVecs) + exponentialsLong(nTimeCh+1:2*nTimeCh,:,1:nVecs) + exponentialsLong(2*nTimeCh+1:3*nTimeCh,:,1:nVecs) + exponentialsLong(3*nTimeCh+1:end,:,1:nVecs);
            else
                exponentialsShort(1:nTimeCh,1:nExp,1:nVecs) = exponentialsLong(1:nTimeCh,:,1:nVecs);
            end
            %% add scatter
            if((vpp.nScatter-(bp.scatterEnable && bp.scatterIRF)) > 0)
                exponentialsShort(:,nExp+1:nExp+vpp.nScatter,1:nVecs) = scVec(:,:,1:nVecs);
            end
            %% move to position of data maximum + hShift - tci
            if(this.useMex && this.dLen <= 4096 && size(exponentialsShort,2) <= 16 && nVecs <= 256) %&& strcmp(bp.timeInterpMethod,'linear')
                [exponentialsOffset(:,1:nExp+(vpp.nScatter-(bp.scatterEnable && bp.scatterIRF)),1:nVecs), ao] = shiftAndLinearOpt_mex(single(exponentialsShort(1:nTimeCh,:,1:nVecs)),tSingle(1:nTimeCh,1),data,this.getDataNonZeroMask(),...
                    single(hShift),single(tcis),single(tciHShiftFine),single(oset),this.linLB,this.linUB,vcp.cMask(end)<0,true);
            else
                [exponentialsOffset(:,1:nExp+(vpp.nScatter-(bp.scatterEnable && bp.scatterIRF)),1:nVecs), ao] = shiftAndLinearOpt(single(exponentialsShort(1:nTimeCh,:,1:nVecs)),tSingle(1:nTimeCh,1),data,this.getDataNonZeroMask(),...
                    single(hShift),single(tcis),single(tciHShiftFine),single(oset),this.linLB,this.linUB,vcp.cMask(end)<0,false);
            end
            exponentialsOffset(:,end,1:nVecs) = ones(nTimeCh,nVecs,1,'single');
            if(bp.approximationTarget == 2 && bp.anisotropyR0Method == 3 && this.myChannelNr == 4)
                %%heikal
                z = zeros(nTimeCh,nVecs);
                n = zeros(nTimeCh,nVecs);
                for i = 1:2:nExp
                    z = z + bsxfun(@times,squeeze(exponentialsOffset(:,i,1:nVecs)),amps(i,:)) .* bsxfun(@times,squeeze(exponentialsOffset(:,i+1,1:nVecs)),amps(i+1,:));
                    n = n + bsxfun(@times,squeeze(exponentialsOffset(:,i,1:nVecs)),amps(i,:));
                end
                model = (z./n + bsxfun(@times,squeeze(exponentialsOffset(:,end,1:nVecs)),oset));% .* this.dMaxVal;
                model(isnan(model)) = 0;
                ampsOut = double(amps);
                osetOut = double(oset);
                scAmpsOut = zeros(0,nVecs);
            else
                if(~any(vcp.cMask < 0))
                    ao(1,:,:) = [amps; scAmps; oset];
                end
                if(vpp.nScatter > 0)
                    scAmpsOut = double(squeeze(ao(1,bp.nExp+1:bp.nExp+vpp.nScatter,:)));
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
                ampsOut = double(squeeze(ao(1,1:bp.nExp,:)));
                osetOut = double(squeeze(ao(1,end,:)));
            end
            if(nargout == 5)
                exponentialsOut = exponentialsOffset(:,:,1:nVecs);
            end
        end %compModelTci
        
        function chiVec = compFigureOfMerit2(this,model,tailFlag,figureOfMerit,chiWeightingMode,fomModifier)
           
            if(nargin < 6)
                fomModifier = this.basicParams.figureOfMeritModifier;
            end
            if(nargin < 5)
                chiWeightingMode = this.basicParams.chiWeightingMode;
            end
            if(nargin < 4)
                figureOfMerit = this.basicParams.figureOfMerit;
            end
            if(tailFlag)
                dnzMask = this.getDataNonZeroMaskTail();
            else
                dnzMask = this.getDataNonZeroMask();
            end
            chiVec = computeFigureOfMerit(model,this.getMeasurementData(),dnzMask,this.volatileChannelParams.nApproxParamsPerCh,...
                this.basicParams,figureOfMerit,chiWeightingMode,fomModifier);
            
        end
        
        function chiVec = compFigureOfMerit(this,model,tailFlag,figureOfMerit,chiWeightingMode,fomModifier)
            %compute the figure of merit (goodness of fit)
            if(nargin < 6)
                fomModifier = this.basicParams.figureOfMeritModifier;
            end
            if(nargin < 5)
                chiWeightingMode = this.basicParams.chiWeightingMode;
            end
            if(nargin < 4)
                figureOfMerit = this.basicParams.figureOfMerit;
            end
            persistent e_lsq_NB
            nrM = size(model,2);
            if(this.basicParams.neighborFit)
                nrNB = size(this.dataStorage.neighbor.raw,2);
            else
                nrNB = 0;
            end
            %% get errors & least squares
            e_lsq = bsxfun(@minus,model,this.getMeasurementData()).^2;
            e_lsq(isnan(e_lsq)) = 0;
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
            if(figureOfMerit == 2)
                %least squares
                chiVec = sum(e_lsq);
                chiVec(chiVec <= eps(chiVec)) = inf;
%                 chi = sum(chiVec(:));
%                 chiD = chiVec(1);
                return
            end
            %                 elseif(figureOfMerit == 3) %maximum likelihood
            %                     tmp = bsxfun(@minus,model,this.getMeasurementData());
            %                     nz = repmat(this.dataStorage.measurement.nonZeroMask,1,nrM);
            %                     tmp(~nz) = 0;
            %                     t1 = sum(tmp,1)*2;
            %                     tmp = log(bsxfun(@times,model,this.getMeasurementDataRez())).*model;
            %                     tmp(~nz) = 0;
            %                     t2 = sum(tmp,1)*2;
            %                     chiVec = t1 + t2;
            switch chiWeightingMode
                case 2
                    m_nz_idx = model > 0;
                    m_nz_idx(1:this.fileInfo.StartPosition-1,:) = false;
                    m_nz_idx(this.fileInfo.EndPosition+1:end,:) = false;
                    if(isempty(this.fileInfo.reflectionMask))
                        reflectionMask = true(size(this.getDataNonZeroMask()));
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
                e_lsq(repmat(~this.getDataNonZeroMaskTail(),1,nrM)) = 0;
            else
                e_lsq(repmat(~this.getDataNonZeroMask(),1,nrM)) = 0;
            end
            
            switch fomModifier
                case 1 %regular chi²
                    if(tailFlag)
                        chiVec = sum(e_lsq,1) ./ (sum(this.getDataNonZeroMaskTail(),1)-this.volatileChannelParams.nApproxParamsPerCh);
                    else
                        chiVec = sum(e_lsq,1) ./ (sum(this.getDataNonZeroMask(),1)-this.volatileChannelParams.nApproxParamsPerCh);%(numel(this.dataStorage.measurement.nonZeroMask)-this.volatileChannelParams.nApproxParamsPerCh);
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
                        chiVec = sum(e_lsq,1) ./ (sum(this.getDataNonZeroMaskTail(),1)-this.volatileChannelParams.nApproxParamsPerCh);
                    else
                        chiVec = sum(e_lsq,1) ./ (sum(this.getDataNonZeroMask(),1)-this.volatileChannelParams.nApproxParamsPerCh);  %(numel(this.dataStorage.measurement.nonZeroMask)-this.volatileChannelParams.nApproxParamsPerCh);
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
            end
            %chiVec = abs(1-chiVec);
            chiVec(chiVec == 0) = inf;
%             chi = sum(chiVec(:));
%             chiD = chiVec(1);
        end
    end %methods
    
    methods(Access = protected)
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
        
        function compSmoothedMaxValues(this)
            %compute position and value of data maximum (smoothed data) and full width half maximum position
            dSmooth = this.dataStorage.measurement.raw;
            dSmooth(isnan(dSmooth)) = 0;
            dSmooth = fastsmooth(dSmooth,5,2,0);
            dSmooth = flipud(fastsmooth(flipud(dSmooth),5,2,0));
            [dMaxValTmp, dMaxPosTmp] = max(dSmooth(min(this.dLen,max(1,this.myStartPos)):min(floor(this.dLen/2),this.myEndPos),1));
            %look for maximum in real data around the max of the smoothed data
            dMaxPosTmp = dMaxPosTmp + this.myStartPos-1;
            %[maxVal, dMaxPosTmp2] = max(this.dataStorage.measurement.raw(min(this.dLen,max(1,dMaxPosTmp-5)):min(this.dLen,dMaxPosTmp+5),1));
            %this.dataStorage.measurement.maxPos = dMaxPosTmp-5+dMaxPosTmp2-1;
            this.dataStorage.measurement.maxPos = dMaxPosTmp;
            this.dataStorage.measurement.maxVal = double(dMaxValTmp);
            if(this.basicParams.fitModel ~=1)
                this.myStartPos = max(1,this.dataStorage.measurement.maxPos-this.basicParams.tailFitPreMaxSteps-1);
            end            
            this.dataStorage.measurement.FWHMPos = find(bsxfun(@lt,this.dataStorage.measurement.raw(1:this.dataStorage.measurement.maxPos),dMaxValTmp*0.6),1,'last');
            ids = (5:10:85)./100;
            this.dataStorage.measurement.risingIDs = zeros(size(ids));
            minVal = min(this.dataStorage.measurement.raw(this.dRealStartPos:this.dataStorage.measurement.maxPos));
            dataRange = dMaxValTmp-minVal;
            for i = 1:length(ids)
                if(ids(i) > 0.5)
                    this.dataStorage.measurement.risingIDs(i) = find(this.dataStorage.measurement.raw(1:this.dataStorage.measurement.maxPos) >= double(minVal)+double(dataRange)*ids(i),1,'first');
                else
                    this.dataStorage.measurement.risingIDs(i) = find(this.dataStorage.measurement.raw(1:this.dataStorage.measurement.maxPos) <= double(minVal)+double(dataRange)*ids(i),1,'last');
                end
            end
        end
        
        function compMeasurementZeroMask(this)
            %compute masks which data points are used for figure of merit computation
            fi = this.fileInfo;
            if(~isempty(this.dataStorage.measurement.raw))
                this.dataStorage.measurement.nonZeroMask = this.dataStorage.measurement.raw ~= 0;
                this.dataStorage.measurement.nonZeroMask(1:this.myStartPos-1,:) = false;
                this.dataStorage.measurement.nonZeroMask(this.myEndPos+1:end,:) = false;
                if(isempty(fi.reflectionMask))
                    fi.reflectionMask = true(size(this.dataStorage.measurement.nonZeroMask));
                end
                this.dataStorage.measurement.nonZeroMask = this.dataStorage.measurement.nonZeroMask & fi.reflectionMask;
                this.dataStorage.measurement.nonZeroMaskTail = this.dataStorage.measurement.nonZeroMask;
                this.dataStorage.measurement.nonZeroMaskTail(1:max(1,this.dMaxPos-this.basicParams.tailFitPreMaxSteps-1),:) = false;
            else
                this.dataStorage.measurement.nonZeroMask = false;
                this.dataStorage.measurement.nonZeroMaskTail = false;
            end
        end
        
        
        function compOffsetGuess(this)
            %make an educated guess for the current offset
            if(~isempty(this.dataStorage.measurement.raw))
                this.dataStorage.measurement.realStartPos = find(this.dataStorage.measurement.raw > 0 & ~isnan(this.dataStorage.measurement.raw),1);
                this.dataStorage.measurement.slopeStartPos = fluoPixelModel.getStartPos(this.dataStorage.measurement.raw);
                oGuess = this.dataStorage.measurement.raw(this.dataStorage.measurement.realStartPos:max(this.dataStorage.measurement.realStartPos+1,this.dataStorage.measurement.slopeStartPos));
                oGuess = oGuess(~isnan(oGuess));
                % if(length(oGuess) < 10)
                %     %we have too few datapoints for a reliable estimate, try to get more
                %     oGuess = data(min(offsetStartPos,SlopeStartPosition):SlopeStartPosition);
                % end
                oGuess = mean(oGuess(oGuess ~= 0));
                if(isempty(oGuess))
                    oGuess = 0;
                end
                %scale magnitude if needed
                if(this.basicParams.heightMode == 2)
                    oGuess = oGuess/this.dMaxVal;
                end
                this.dataStorage.measurement.offsetGuess = oGuess;
            else
                this.dataStorage.measurement.offsetGuess = [];
                this.dataStorage.measurement.slopeStartPos = [];
            end                        
        end
    end
end % classdef
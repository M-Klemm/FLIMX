classdef fluoPixelModel < matlab.mixin.Copyable
    %=============================================================================================================
    %
    % @file     fluoPixelModel.m
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
    % @brief    A class to model a pixel.
    %
    properties(SetAccess = protected)
        fileInfo = [];        
        currentChannel = 0;
        params = [];
        myChannels = cell(0,0);
        useGPU = false; %flag to use Matlab GPU processing features
        useMex = false; %flag to use optimized mex file for linear optimizer
        SlopeStartPosition = 0; %todo: remove that here
    end
    properties(Dependent = true)
        nrChannels = 0;
        nonEmptyChannelList = [];
        preProcessParams = [];
        boundsParams = [];
        basicParams = [];
        pixelFitParams = [];
        computationParams = [];
        volatilePixelParams = [];
    end
    methods
        function this = fluoPixelModel(allIRF,fileInfo,params,currentChannel)
            %Constructs a fluoPixelModel object.
            this.currentChannel = currentChannel;
            if(size(allIRF,2) == length(fileInfo))
                this.fileInfo = fileInfo;
            else
                error('Number of channels of IRF (%d) and fileInfo struct (%d) does not match!',size(allIRF,2),length(fileInfo));
            end
            this.myChannels = cell(this.nrChannels,1);            
            this.preProcessParams = params.preProcessing;
            this.boundsParams = params.bounds;
            this.pixelFitParams = params.pixelFit;
            this.computationParams = params.computation;
            %this.volatilePixelParams = params.volatilePixel;
            this.basicParams = params.basicFit; %this rebuilds volatile pixel params            
            neChs = find(~cellfun('isempty',allIRF));%length(fileInfo);%
            %call channel class Constructor
            for ch = neChs
                %                 if(this.basicParams.neighborFit)
                %                     nb = squeeze(neighborData(:,:,ch));
                %                     nb = nb(:,sum(nb,1) > this.basicParams.photonThreshold);
                %                 else
                %                     nb = [];
                %                 end
                this.myChannels{ch} = 'dummy';
                this.myChannels{ch} = fluoChannelModel(this,allIRF{:,ch},ch);
            end
            this.basicParams = params.basicFit; %ugly: rebuilds volatile channel params  
        end
        
%         function out = getCopy(this)
%             %copy myself
%             s.fileInfo = this.fileInfo;
%             s.pixelData = this.pixelData;
%             s.nbData = this.nbData;
%             s.nrChannels = this.nrChannels;
%             s.currentChannel = this.currentChannel;
%             s.params = this.params;
%             s.myChannels = this.myChannels;
%             s.useGPU = this.useGPU;
%             s.useMex = this.useMex;
%             for ch = 1:this.nrChannels
%                 allIRF{ch} = this.myChannels{ch}.irf;
%             end
%             out = fluoPixelModel(allIRF,this.fileInfo,this.params.basicParams,this.params.pixelFitParams,this.params.computationParams,this.params.volatilePixelParams,this.params.volatileChannel);
%             out.importContent(s);
%         end
%         
%         function importContent(this,val)
%             %import my contents
%             this.fileInfo = val.fileInfo;
%             this.pixelData = val.pixelData;
%             this.nbData = val.nbData;
%             this.nrChannels = val.nrChannels;
%             this.currentChannel = val.currentChannel;
%             this.params = val.params;
%             this.myChannels = val.myChannels;
%             this.useGPU = val.useGPU;
%             this.useMex = val.useMex;
%         end
        
        %%input methods
        function setMeasurementData(this,pixel)
            %set measurement data for this pixel
            chList = this.nonEmptyChannelList;
            if(isempty(chList))
                error('FLIMX:fluoPixelModel:setMeasurementData','chList is empty!');
            end
            if(isempty(this.getFileInfo(chList(1))))
                error('FLIMX:fluoPixelModel:setMeasurementData','File info empty!');
            end
            %check data
            [nrTimeCh, nrSpectralCh] = size(pixel);
            if(nrTimeCh ~= this.getFileInfo(chList(1)).nrTimeChannels || nrSpectralCh ~= length(chList))
                error('FLIMX:fluoPixelModel:setMeasurementData','Pixel data not as expected');
            end
            %save data
            for chIdx = 1:length(chList)
                p = pixel(:,chIdx);
                this.myChannels{chList(chIdx)}.setMeasurementData(p);
            end
        end
        
        function setChiWeightData(this,weights)
            %set chi weights for this pixel
            chList = this.nonEmptyChannelList;
            %check data
            [nrTimeCh, nrSpectralCh] = size(weights);
            if(nrTimeCh ~= this.getFileInfo(chList(1)).nrTimeChannels || nrSpectralCh ~= length(chList))
                error('FLIMX:fluoPixelModel:setMeasurementData','Chi weights data not as expected');
            end
            %save data
            for chIdx = 1:length(chList)
                w = [];
                if(~isempty(weights))
                    w = weights(:,chIdx);
                    if(sum(w(:)) == 0)
                        w = [];
                    end
                end
                this.myChannels{chList(chIdx)}.setChiWeightData(w);
            end
        end
        
        function setNeighborData(this,neighbors)
            %set neighbor data for this pixel
            chList = this.nonEmptyChannelList;
            %check data
            if(~isempty(neighbors))
                [nrTimeCh, nrNeighbors, nrSpectralCh] = size(neighbors);
                if(nrTimeCh ~= this.getFileInfo(chList(1)).nrTimeChannels || nrSpectralCh ~= length(chList))
                    error('Neighbor data not as expected');
                end
            end
            %save data
            for chIdx = 1:length(chList)
                n = [];
                if(~isempty(neighbors))
                    n = neighbors(:,:,chIdx);
                end
                this.myChannels{chList(chIdx)}.setNeighborData(n);
            end            
        end
        
        function setScatterData(this,scatter)
            %set scatter data for this pixel
            chList = this.nonEmptyChannelList;
            %check data
            [nrTimeCh, nrScatter, nrSpectralCh] = size(scatter);
                if(nrTimeCh ~= this.getFileInfo(chList(1)).nrTimeChannels || nrSpectralCh ~= length(chList))
                    error('Scatter data not as expected');
                end
            %save data
            for chIdx = 1:length(chList)
                s = [];
                if(~isempty(scatter))
                    s = scatter(:,:,chIdx);
                end
                this.myChannels{chList(chIdx)}.setScatterData(s);
            end            
        end
        
        function setInitializationData(this,ch,data)
            %set initialization data for nonlinear optimization for channel ch (optional)
            if(any(ch == this.nonEmptyChannelList))
                this.myChannels{ch}.setInitializationData(data);                
            end
        end
        
        function setCurrentChannel(this,ch)
            %set the current channel for approximation
            if(any(ch == this.nonEmptyChannelList))
                this.currentChannel = ch;
            end
        end
                
        function setVolatileChannelParams(this,ch,val)
            %set volatile channel parameters
            if(any(ch == this.nonEmptyChannelList) && ~isempty(val))
                this.params.volatileChannel{ch} = val;
                this.myChannels{ch}.setLinearBounds([]);
            end
        end
        
        function out = get.nrChannels(this)
            %get total number of channels
            if(~isempty(this.fileInfo) && length(this.fileInfo) >= this.currentChannel)
                out = this.fileInfo(this.currentChannel).nrSpectralChannels;
            else
                out = 0;
            end
        end
        
        function out = get.nonEmptyChannelList(this)
            %return a list of channel numbers "with data"
            out = find(~cellfun('isempty',this.myChannels))';
        end
        
        function out = get.preProcessParams(this)
            %get pre processing parameters
            out = this.params.preProcessing;
        end
        
        function out = get.basicParams(this)
            %get basic fit parameters
            out = this.params.basicFit;
        end
                
        function out = get.pixelFitParams(this)
            %make pixelFitParams struct
            out = this.params.pixelFit;
        end
        
        function out = get.boundsParams(this)
            %make bounds struct
            out = this.params.bounds;
        end
        
        function out = get.computationParams(this)
            %make computationParams struct
            out = this.params.computation;
        end
        
        function out = get.volatilePixelParams(this)
            %get volatilePixelParams parameters
            out = this.params.volatilePixel;
        end
        
        function set.basicParams(this,val)
            %set basic fit parameters
            if(isempty(this.params) || ~isfield(this.params,'basicFit'))
                old = [];
            else
                old = this.params.basicFit;
            end
            this.params.basicFit = val;
            if(isempty(old) || all(cellfun('isempty',this.params.volatileChannel)) || old.hybridFit ~= val.hybridFit || val.hybridFit && (old.nExp ~= val.nExp || old.nonLinOffsetFit ~= val.nonLinOffsetFit)...
                    || ~all(strcmp(old.(sprintf('constMaskSaveStrCh%d',this.currentChannel)),val.(sprintf('constMaskSaveStrCh%d',this.currentChannel))))...
                    || any(old.(sprintf('constMaskSaveValCh%d',this.currentChannel)) ~= val.(sprintf('constMaskSaveValCh%d',this.currentChannel))))
                [this.params.volatilePixel, vcp] = paramMgr.makeVolatileParams(val,this.nrChannels);
                this.params.volatileChannel = cell(0,0);
                for ch = this.nonEmptyChannelList
                    if(~isempty(vcp(ch,1)))
                        this.setVolatileChannelParams(ch,vcp{ch});
                    end
                    %this.myChannels{ch}.setLinearBounds([]);
                end
            end
        end
                
        function  set.pixelFitParams(this,val)
            %make pixelFitParams struct
            this.params.pixelFit = val;
        end
        
        function set.computationParams(this,val)
            %make computationParams struct
            this.params.computation = val;
        end
        
        function set.volatilePixelParams(this,val)
            %get volatilePixelParams parameters
            this.params.volatilePixel = val;
        end
        
        function set.preProcessParams(this,val)
            %get pre processing parameters
            this.params.preProcessing = val;
        end
        
        function set.boundsParams(this,val)
            %make bounds struct
            this.params.bounds = val;
        end
        
        %%output methods
        function out = getFileInfo(this,ch)
            %get fileInfo struct for channel ch
            out = [];
            if(length(this.fileInfo) >= ch)%any(ch == this.nonEmptyChannelList))
                out = this.fileInfo(ch);
            end
        end
        
        function out = getVolatileChannelParams(this,ch)
            %get getVolatileChannelParams for channel ch
            out = [];
            if(length(this.params.volatileChannel) >= ch && ~isempty(this.params.volatileChannel{ch}))
                out = this.params.volatileChannel{ch};
            else
                %make volatile channel parameters
                [this.params.volatilePixel, vcp] = paramMgr.makeVolatileParams(this.params.basicFit,this.nrChannels);
                this.params.volatileChannel = cell(0,0);
                if(isempty(this.nonEmptyChannelList))
                    chList = this.nrChannels;
                else
                    chList = this.nonEmptyChannelList;
                end
                for ch = chList
                    if(~isempty(vcp(ch,1)))
                        this.setVolatileChannelParams(ch,vcp{ch});
                    end
                    %this.myChannels{ch}.setLinearBounds([]);
                end                
                if(length(this.params.volatileChannel) >= ch)
                    out = this.params.volatileChannel{ch};
                end
            end
        end
        
        function out = getIRF(this,ch)
            %return irf for channel ch
            out = [];
            if(any(ch == this.nonEmptyChannelList))
                out = this.myChannels{ch}.getIRF();
            end
        end
        
        function out = getMeasurementData(this,ch)
            %return measurement data for channel ch
            out = [];
            if(any(ch == this.nonEmptyChannelList))
                out = this.myChannels{ch}.getMeasurementData();
            end
        end
        
        function out = getScatterData(this,ch)
            %return scatter data for channel ch
            out = [];
            if(any(ch == this.nonEmptyChannelList))
                out = this.myChannels{ch}.getScatterData();
            end
        end
        
        function out = getInitializationData(this,ch)
            %set initialization data for nonlinear optimization for channel ch
            out = [];
            if(any(ch == this.nonEmptyChannelList))
                out = this.myChannels{ch}.getInitializationData();
            end
        end
        
        function out = getModel(this,ch,xVec)
            %compute model for xVec in channel ch
            out = [];
            if(any(ch == this.nonEmptyChannelList))
                out = double(this.myChannels{ch}.compModel(xVec));
                %out = this.myChannels{ch}.model;
            end
        end
        
        function out = getExponentials(this,ch,xVec)
        %compute exponentials for xVec in channel ch
            out = [];
            if(any(ch == this.nonEmptyChannelList)) 
                [~,~,~,~,out] = this.myChannels{ch}.compModel(xVec);
                out = double(out);
            end
        end
        
        function out = getDataNonZeroMask(this,ch)
        %compute dataNonZeroMask for channel ch
            out = [];
            if(any(ch == this.nonEmptyChannelList))
                out = this.myChannels{ch}.getDataNonZeroMask();
            end
        end
        
        function [sp, ep] = getStartEndPos(this,ch)
        %compute start and end positions for channel ch
            sp = []; ep = [];
            if(any(ch == this.nonEmptyChannelList))
                sp = this.myChannels{ch}.myStartPos;
                ep = this.myChannels{ch}.myEndPos;
            end
        end
        
        %%computation methods
        function [chi2, amps, scAmps, oset, chi2tail] = costFcn(this,xVec)
            %compute model and get chi²
            if(any(this.volatilePixelParams.globalFitMask))
                if(isvector(xVec))
                    xVec = xVec(:);
                end
                nModels = size(xVec,2);
                chi2 = zeros(1,nModels);
                amps = zeros(this.basicParams.nExp*this.nrChannels,nModels);
                scAmps = zeros(this.volatilePixelParams.nScatter*this.nrChannels,nModels);
                oset = zeros(this.nrChannels,nModels);
                chi2tail = zeros(1,nModels);
                xArray = this.divideGlobalFitXVec(xVec,true);
                switch nargout
                    case 5
                        for j = 1:this.nrChannels
                            [chi2(j,:), amps((j-1)*this.basicParams.nExp+1:(j)*this.basicParams.nExp,:), scAmps((j-1)*this.volatilePixelParams.nScatter+1:(j)*this.volatilePixelParams.nScatter,:), oset(j,:), chi2tail(j,:)] = this.computeChannel(j,squeeze(xArray(:,j,:)));
%                             if(any(isinf(chi2(j,:))))
%                                 break
%                             end
                        end
                        chi2tail = sum(chi2tail,1);
                    otherwise
                        for j = 1:this.nrChannels
                            [chi2(j,:), amps((j-1)*this.basicParams.nExp+1:(j)*this.basicParams.nExp,:), scAmps((j-1)*this.volatilePixelParams.nScatter+1:(j)*this.volatilePixelParams.nScatter,:), oset(j,:)] = this.computeChannel(j,squeeze(xArray(:,j,:)));
%                             if(any(isinf(chi2(j,:))))
%                                 break
%                             end
                        end
                end
                chi2 = sum(chi2.^2,1);
            else
                if(this.currentChannel == 0)
                    error('Current channel not set!');
                end
                switch nargout
                    case 1
                        chi2 = this.computeChannel(this.currentChannel,xVec);
                    case 2
                        [chi2, amps] = this.computeChannel(this.currentChannel,xVec);
                    case 3
                        [chi2, amps, scAmps] = this.computeChannel(this.currentChannel,xVec);
                    case 4
                        [chi2, amps, scAmps, oset] = this.computeChannel(this.currentChannel,xVec);
                    case 5
                        [chi2, amps, scAmps, oset, chi2tail] = this.computeChannel(this.currentChannel,xVec);
                end
            end
        end
        
        function [chi2, amps, scAmps, oset, chi2tail] = computeChannel(this,ch,xVec)
            %compute model and get chi² of a single channel
            %% check for correct parameters
            xVecCheck = this.getFullXVec(ch,xVec);
            %idxIgnored = false(size(xVec,2),1);
            bp = this.basicParams;
            chi2 = zeros(1,size(xVec,2));
            if(~(bp.approximationTarget == 2 && ch == 2))
                %ensure tau ordering
                %exclude stretched exponentials
                mask = find(~bp.stretchedExpMask)+bp.nExp;
                for i = 1:length(mask)-1 %bp.nExp+1 : 2*bp.nExp-1
                    %idxIgnored(xVecCheck(mask(i),:).*bp.lifetimeGap > xVecCheck(mask(i+1),:)) = true;
                    tmp = floor(xVecCheck(mask(i+1),:) - xVecCheck(mask(i),:).*bp.lifetimeGap).*-1000;
                    idx = tmp > 0;
                    chi2(idx) = chi2(idx) + tmp(idx);
                end
                %ensure tci ordering
                for i = 2*bp.nExp+1 : 2*bp.nExp+sum(bp.tciMask ~= 0)-1
                    %idxIgnored(xVecCheck(i,:) > xVecCheck(i+1,:)) = true;
                    tmp = floor(xVecCheck(i+1,:) - xVecCheck(i,:)) .*-1000;
                    idx = tmp > 0;
                    chi2(idx) = chi2(idx) + tmp(idx);
                end
            end
            amps = zeros(bp.nExp,size(xVec,2));
            scAmps = zeros(this.volatilePixelParams.nScatter,size(xVec,2));
            oset = zeros(1,size(xVec,2));            
            %chi2(idxIgnored) = inf;
            idxIgnored = logical(chi2)';
            if(all(idxIgnored == true))
                chi2tail = chi2;
                return
            end
            %compute model function
            model = zeros(this.getFileInfo(ch).nrTimeChannels,length(idxIgnored));
            [model(:,~idxIgnored), amps(:,~idxIgnored), scAmps(:,~idxIgnored), oset(~idxIgnored), exponentials(:,:,~idxIgnored)] = this.myChannels{ch}.compModel(xVec(:,~idxIgnored));
            %compute chi²
            switch bp.fitModel
                case {0,2} %tail fit
                    [~, ~, chi2(~idxIgnored)] = this.myChannels{ch}.compFigureOfMerit(model(:,~idxIgnored),true);
                case 1 %tci fit
                    [~, ~, chi2(~idxIgnored)] = this.myChannels{ch}.compFigureOfMerit(model(:,~idxIgnored),false);
            end
            %ensure amplitude ordering
            if(bp.amplitudeOrder > 0 && bp.nExp > 1)
                if(bp.amplitudeOrder == 1)
                    n = 1;
                else
                    n = size(amps,1)-1;
                end
                for i = 1:n
                    tmp = amps(i+1,:) - amps(i,:);
                    idx = tmp > 0;%-0.05*amps(i,:);
                    chi2(idx) = chi2(idx) + i*100 + abs(tmp(idx))*10;
                    idxIgnored(idx) = true;
                end
            end
            exponentials(:,:,idxIgnored) = 0;
            %help optimizer to get shift right, if we are too far off             
            %[~, chi2, idxIgnored, ~] = fluoPixelModel.timeShiftCheck(true,chi2,idxIgnored,tmp,[false; ~idxIgnored],this.SlopeStartPosition,this.myChannels{ch}.dMaxPos);
            if(ch < 4) %only for fluorescence lifetime %bp.approximationTarget == 1 || 
                %compute model FWHM positions
                [~,fwhmPos] = max(bsxfun(@gt,model(:,~idxIgnored),max(model(:,~idxIgnored),[],1)*0.8),[],1);
                d = abs(bsxfun(@minus,fwhmPos,this.myChannels{ch}.dFWHMPos));
                idxHit = d > bp.risingEdgeErrorMargin;
                if(any(idxHit))
                    idxNum = find(~idxIgnored);
                    idxNum = idxNum(idxHit);
                    idxIgnored(idxNum) = true;
                    chi2(idxNum) = max(chi2(idxNum)+d(idxHit).*10000,(d(idxHit)/10+1)*10.*chi2(idxNum));
                end
                if(all(idxIgnored == true))
                    chi2tail = chi2;
                    return
                end
            end
            %ensure tci components are earlier on the time axis compared to the other components
            vcp = this.getVolatileChannelParams(ch);
            loopCnt = 0;
            %idxRemain = true(1,sum(~idx),1);
            for i = find(bp.tciMask)
                loopCnt = loopCnt + 1;
                if(~vcp.cMask(2*bp.nExp+loopCnt))
                    tcIdx = false(1,bp.nExp);
                    tcIdx(i) = true;
                    %for multiple tci: remove other tci-components from comparison
                    cIdx = ~bp.tciMask | tcIdx;
                    tcIdx(~tcIdx & ~cIdx) = [];
                    [~, chi2, idxIgnored, ~] = fluoPixelModel.timeShiftCheck(true,chi2,idxIgnored,exponentials(:,cIdx,~idxIgnored),tcIdx,this.SlopeStartPosition,this.myChannels{ch}.dMaxPos);
                end
            end
            %ensure that lens fluorescence is earlier on the time axis compared to the other components          
            if((this.volatilePixelParams.nScatter - bp.scatterIRF) > 0 && any(any(scAmps(1,~idxIgnored))))
                %get slope position of scatter data and exponentials
                tcIdx = false(bp.nExp+size(scAmps,1),1);
                tcIdx(bp.nExp+1) = true;
                nzAmpsIdx = scAmps(1,:)' > 0 & ~idxIgnored;
                [~, chi2New, idxNew] = fluoPixelModel.timeShiftCheck(true,chi2,~nzAmpsIdx,exponentials(:,1:end-1,nzAmpsIdx),tcIdx,this.SlopeStartPosition,this.myChannels{ch}.dMaxPos);
                idxIgnored(nzAmpsIdx) = idxIgnored(nzAmpsIdx) | idxNew(nzAmpsIdx);
                chi2(nzAmpsIdx) = chi2New(nzAmpsIdx);
            end
            if(bp.scatterIRF && isempty(idxIgnored) && any(any(scAmps(end,~idxIgnored))))
                %get slope position of scatter data and exponentials
                tcIdx = false(bp.nExp+size(scAmps,1),1);
                tcIdx(end) = true;
                nzAmpsIdx = scAmps(end,:)' > 0 & ~idxIgnored;
                [~, chi2New, idxNew] = fluoPixelModel.timeShiftCheck(false,chi2,~nzAmpsIdx,exponentials(:,1:end-1,nzAmpsIdx),tcIdx,this.myChannels{ch}.dMaxPos,this.myChannels{ch}.dMaxPos);
                idxIgnored(nzAmpsIdx) = idxIgnored(nzAmpsIdx) | idxNew(nzAmpsIdx);
                chi2(nzAmpsIdx) = chi2New(nzAmpsIdx);
            end
            chi2tail = chi2;
            if(all(idxIgnored == true))                
                return
            elseif(isempty(idxIgnored))
                idxIgnored = false(size(xVec,2),1);
            end
            model = model(:,~idxIgnored);
            %do computation
%             switch bp.fitModel
%                 case {0,2} %tail fit
%                     [~, ~, chi2(~idxIgnored)] = this.myChannels{ch}.compFigureOfMerit(model,true);
%                 case 1 %tci fit
%                     [~, ~, chi2(~idxIgnored)] = this.myChannels{ch}.compFigureOfMerit(model,false);
%             end
%             dr = model(this.myChannels{ch}.dMaxPos,:) ./ this.myChannels{ch}.dMaxVal;
%             drIdx = abs(1-dr(:)) > 0.05;
%             chi2Tmp = chi2(~idxIgnored);            
%             chi2Tmp(drIdx) = chi2Tmp(drIdx)*10;
%             chi2(~idxIgnored) = chi2Tmp;
            if(nargout == 5 && bp.fitModel == 1)
                [~, ~, chi2tail(~idxIgnored)] = this.myChannels{ch}.compFigureOfMerit(model,true);
            elseif(nargout == 5 && bp.fitModel ~= 1)
                chi2tail(~idxIgnored) = chi2(~idxIgnored);
            end
        end
        
        function [rs, nonLinBounds, iVec] = makeDataPreProcessing(this,allInitVec)
            %determine maxima positions, guesses for lifetimes and offset,...            
            globalIVec = true;
            if(size(allInitVec,1) ~= this.volatilePixelParams.nApproxParamsAllCh || sum(allInitVec(:)) == 0)
                allInitVec = zeros(this.volatilePixelParams.nApproxParamsAllCh,1);
                globalIVec = false;
            end
            chList = this.nonEmptyChannelList;
            allBounds = repmat(this.boundsParams,length(chList),1);
            for chIdx = 1:length(chList)
                dataTmp = double(this.myChannels{chList(chIdx)}.getMeasurementData());
                rs(chIdx) = this.makePreProcessResultStruct();
                if(any(dataTmp))
                    %guess mean lifetime, offset, shift
                    [rs(chIdx).MaximumPhotons, rs(chIdx).MaximumPosition] = max(dataTmp(:));%max(fastsmooth(dataTmp(:),10,3));                    
                    rs(chIdx).TauMeanGuess = fluoPixelModel.makeLifetimeGuess(dataTmp(:),this.getIRF(chList(chIdx)),rs(chIdx).MaximumPosition,this.getFileInfo(chList(chIdx)));                    
                    [rs(chIdx).OffsetGuess, rs(chIdx).SlopeStartPosition] = fluoPixelModel.makeOffsetGuess(dataTmp(:),rs(chIdx).MaximumPhotons,...
                        this.preProcessParams.offsetStartPos,this.getFileInfo(chList(chIdx)).StartPosition,this.basicParams.heightMode);
                    rs(chIdx).StartPosition = this.getFileInfo(chList(chIdx)).StartPosition;
                    rs(chIdx).EndPosition = max(2,min(this.getFileInfo(chList(chIdx)).EndPosition,fluoPixelModel.getEndPos(dataTmp)));
                    tmp = dataTmp(rs(chIdx).StartPosition:rs(chIdx).EndPosition);
                    rs(chIdx).TotalPhotons = sum(tmp(~isnan(tmp)));
                    irfTmp = this.getIRF(chList(chIdx));
                    [~,fwhmDPos] = max(bsxfun(@gt,dataTmp,max(dataTmp(:),[],1)*0.75),[],1);
                    [~,fwhmIPos] = max(bsxfun(@gt,irfTmp,max(irfTmp(:),[],1)*0.75),[],1);
                    rs(chIdx).hShiftGuess = (fwhmDPos-fwhmIPos-3).*this.getFileInfo(chList(chIdx)).timeChannelWidth;
                    this.SlopeStartPosition = rs(chIdx).SlopeStartPosition;
                    %TODO: check that initial values are within bounds!
                end
                %make bounds                
                allBounds(chIdx,1).bounds_tci.ub = min(allBounds(chIdx,1).bounds_tci.ub,(rs(chIdx).MaximumPosition - rs(chIdx).StartPosition-1)*this.getFileInfo(chList(chIdx)).timeChannelWidth);
                [nonLinBoundsCh(chIdx), tmp] = fluoPixelModel.getBoundsPerChannel(rs(chIdx).MaximumPhotons,rs(chIdx).OffsetGuess,this.basicParams,this.volatilePixelParams.nScatter,this.getVolatileChannelParams(chList(chIdx)).cMask,allBounds(chIdx,1));
                if(~isempty(tmp))
                    linBounds(chIdx,1) = tmp;
                else
                    linBounds = [];
                end
                if(globalIVec && any(allInitVec(:,1)) && this.pixelFitParams.pixelJitter > 0)
                    iArray = this.divideGlobalFitXVec(allInitVec(:,1),true);
                    %outer loops runs over channels
                    if(chIdx <= size(iArray,2))
                        [amps, taus, tcis, betas, scAmps, scShifts, scOset, hShift, oset] = this.getXVecComponents(iArray(:,chIdx),true,chList(chIdx));
                        %oset = oset * rs(chIdx).MaximumPhotons;
                        amps = amps * rs(chIdx).MaximumPhotons;
                        iArray(:,chIdx) = this.getNonConstantXVec(chList(chIdx),amps,taus,tcis,betas,scAmps,scShifts,scOset,hShift,oset);
                        %make sure iVec is valid
                        iArray(:,chIdx) = checkBounds(iArray(:,chIdx),nonLinBoundsCh(chIdx).lb,nonLinBoundsCh(chIdx).ub);
                        [amps, taus, tcis, betas, scAmps, scShifts, scOset, hShift, oset] = this.getXVecComponents(iArray(:,chIdx),true,chList(chIdx));
                        %leave shifts free
                        %lower bounds
                        [ampsLB, tausLB, tcisLB, betasLB, scAmpsLB, scShiftsLB, scOsetLB, hShiftLB, osetLB] = this.getXVecComponents(nonLinBoundsCh(chIdx).lb,true,chList(chIdx));
                        ampsLB = max(ampsLB,amps - abs(amps).*(this.pixelFitParams.pixelJitter/100));
                        tausLB = max(tausLB,taus - abs(taus).*(this.pixelFitParams.pixelJitter/100));
                        tcisLB = max(tcisLB,tcis - abs(tcis).*(this.pixelFitParams.pixelJitter/100));
                        betasLB = max(betasLB,betas - abs(betas).*(this.pixelFitParams.pixelJitter/100));
                        osetLB = max(osetLB,oset - abs(oset).*(this.pixelFitParams.pixelJitter/100));
                        nonLinBoundsCh(chIdx).lb = this.getNonConstantXVec(chList(chIdx),ampsLB,tausLB,tcisLB,betasLB,scAmpsLB,scShiftsLB,scOsetLB,hShiftLB,osetLB);
                        %upper bounds
                        [ampsUB, tausUB, tcisUB, betasUB, scAmpsUB, scShiftsUB, scOsetUB, hShiftUB, osetUB] = this.getXVecComponents(nonLinBoundsCh(chIdx).ub,true,chList(chIdx));
                        ampsUB = min(ampsUB,amps + abs(amps).*(this.pixelFitParams.pixelJitter/100));
                        tausUB = min(tausUB,taus + abs(taus).*(this.pixelFitParams.pixelJitter/100));
                        tcisUB = min(tcisUB,tcis + abs(tcis).*(this.pixelFitParams.pixelJitter/100));
                        betasUB = min(betasUB,betas + abs(betas).*(this.pixelFitParams.pixelJitter/100));
                        osetUB = min(osetUB,oset + abs(oset).*(this.pixelFitParams.pixelJitter/100));
                        nonLinBoundsCh(chIdx).ub = this.getNonConstantXVec(chList(chIdx),ampsUB,tausUB,tcisUB,betasUB,scAmpsUB,scShiftsUB,scOsetUB,hShiftUB,osetUB);
                    end
                end
                if(~isempty(linBounds))
                    this.myChannels{chList(chIdx)}.setLinearBounds(linBounds(chIdx,1));
                else
                    this.myChannels{chList(chIdx)}.setLinearBounds([]);
                end
            end
            if(length(chList) > 1)
                nonLinBounds = nonLinBoundsCh(1);
                fn = fieldnames(nonLinBoundsCh);                              
                for fnIdx = 1:length(fn)
                    tmp = zeros(this.volatilePixelParams.nModelParamsPerCh,length(chList));  
                    for chIdx = 1:length(chList)
                        tmp(:,chIdx) = this.getFullXVec(chList(chIdx),nonLinBoundsCh(chList(chIdx)).(fn{fnIdx}));
                    end
                    nonLinBounds.(fn{fnIdx}) = this.joinGlobalFitXVec(tmp,false);
                end
            else
                nonLinBounds = nonLinBoundsCh;
            end
            %make optimizer init vector
            iArray = this.divideGlobalFitXVec(nonLinBounds.init(:),true);
            lbArray = this.divideGlobalFitXVec(nonLinBounds.lb(:),true);
            ubArray = this.divideGlobalFitXVec(nonLinBounds.ub(:),true);
            igfArray = this.getFullXVec(this.currentChannel,this.divideGlobalFitXVec(nonLinBounds.initGuessFactor,true));
            for chIdx = 1:length(chList)
                [amps, ~, ~, ~, scAmps, scShifts, scOset, ~, oset] = this.getXVecComponents(iArray(:,chIdx),true,chList(chIdx));
                switch this.basicParams.nExp
                    case 1
                        taus = rs(chIdx).TauMeanGuess*igfArray(this.basicParams.nExp+1,chIdx);
                    case 2
                        taus = [rs(chIdx).TauMeanGuess*igfArray(this.basicParams.nExp+1,chIdx);...
                            rs(chIdx).TauMeanGuess*igfArray(this.basicParams.nExp+2,chIdx);];
                    case 3
                        taus = [rs(chIdx).TauMeanGuess*igfArray(this.basicParams.nExp+1,chIdx);...
                            rs(chIdx).TauMeanGuess*igfArray(this.basicParams.nExp+2,chIdx);...
                            rs(chIdx).TauMeanGuess*igfArray(this.basicParams.nExp+3,chIdx);];
                    otherwise
                        taus = [rs(chIdx).TauMeanGuess*igfArray(this.basicParams.nExp+1,chIdx);...
                            rs(chIdx).TauMeanGuess*igfArray(this.basicParams.nExp+2,chIdx);...
                            rs(chIdx).TauMeanGuess*igfArray(this.basicParams.nExp+3,chIdx);];
                        for idx=4:this.basicParams.nExp
                            taus = [taus; rs(chIdx).TauMeanGuess*(igfArray(this.basicParams.nExp,chIdx)+idx-3);];
                        end
                end
                for idx = 1:this.basicParams.nExp
                    tg = sprintf('TauGuess%d',idx);
                    rs(chIdx).(tg) = taus(idx);
                end
                %tci
                tciGuess = -(rs(chIdx).MaximumPosition - rs(chIdx).SlopeStartPosition)*this.getFileInfo(chList(chIdx)).timeChannelWidth/3;
                nTci = sum(this.basicParams.tciMask);
                switch nTci
                    case 0
                        tcis = [];
                    case 1
                        tcis = tciGuess;
                    case 2
                        tcis = [tciGuess/2; tciGuess;];
                    otherwise
                        tcis = zeros(nTci,1);
                        for j=1:nTci
                            tcis(j) = tciGuess*j/nTci;
                        end
                end
                %stretched exponentials
                nSE = sum(this.basicParams.stretchedExpMask);
                switch nSE
                    case 0
                        betas = [];
                    otherwise
                        betas = ones(nSE,1)*0.5;
                end
                %         %amps,offset,hShift
                [ampsLB, tausLB, tcisLB, betasLB, scAmpsLB, scShiftsLB, scOsetLB, hShiftLB, osetLB] = this.getXVecComponents(lbArray(:,chIdx),true,chList(chIdx));
                [ampsUB, tausUB, tcisUB, betasUB, scAmpsUB, scShiftsUB, scOsetUB, hShiftUB, osetUB] = this.getXVecComponents(ubArray(:,chIdx),true,chList(chIdx));
                hShift = rs(chIdx).hShiftGuess;
                %if(hShift < 0)
                    hShiftUB = hShift + 10*this.getFileInfo(chList(chIdx)).timeChannelWidth;%-2*tciGuess; %hShift;
                    hShiftLB = hShift - 10*this.getFileInfo(chList(chIdx)).timeChannelWidth;
                    %hShiftLB = min([hShiftLB,hShift-10*this.getFileInfo(chList(chIdx)).timeChannelWidth],[],2);%(scShifts-scShiftsUB)*2],[],2);
%                 else
%                     hShiftLB = hShift - 10*this.getFileInfo(chList(chIdx)).timeChannelWidth;%+ 2*tciGuess; %hShift;
%                     hShiftUB = max([hShiftUB,hShift+10*this.getFileInfo(chList(chIdx)).timeChannelWidth],[],2);%(scShifts-scShiftsLB)*2],[],2);
%                 end
                scData = this.getScatterData(chList(chIdx));
                if(this.basicParams.scatterEnable && ~isempty(scData) &&~any(isnan(scData(:))))
                    %scShift                    
                    nScatter = size(scData,2);
                    scSmooth = zeros(size(scData));
                    idxSc = zeros(nScatter,1);
                    for i = 1:nScatter
                        scSmooth(:,i) = fastsmooth(scData(:,i),3,3,0);
                        [scMaxVal(i), scMaxPos(i)] = max(scSmooth(:,i),[],1);
                        %get slope position of scatter data and measurement data
                        idxSc(i) = find(scData(1:scMaxPos(i),i) <= scMaxVal(i)/10,1,'last');
                    end
                    %idxData = find(dataTmp(1:rs(chIdx).MaximumPosition) < rs(chIdx).MaximumPhotons/15,1,'last'); % look at 1/15th of data as riding edge
%                     nBins = ceil(rs(chIdx).MaximumPhotons/10);
%                     cw = rs(chIdx).MaximumPhotons/nBins;
%                     dHist = dataTmp(1:rs(chIdx).MaximumPosition-5);                    
%                     dHist = dHist(dHist > 0);
%                     dHist = hist(dHist,nBins);
%                     dHist = dHist ./ max(dHist);
%                     dDiff = diff(dHit);
                    dHit = [];% 2+find(dHist(3:end) == 0,1,'first');%0.66*max(dHist));
%                     [v,p] = max(dDiff);
                    if(~isempty(dHit))                        
%                         if(p == 1)
%                             p = length(dDiff);
%                         end
                        th = dHit*cw;%(dHit(p-1)+ceil(dDiff(p)/2))*cw;
                        idxData = find(dataTmp(1:rs(chIdx).MaximumPosition) >= th,1,'first');
                    else
                        th = rs(chIdx).MaximumPhotons/15; % look at 1/15th of data as riding edge
                        idxData = find(dataTmp(1:rs(chIdx).MaximumPosition) < th,1,'last');
                    end                    
                    if(isempty(idxData))
                        idxData = idxSc(1);
                    end
                    if(~isempty(this.basicParams.scatterStudy)) 
                        if(~isempty(idxSc))
                            scShifts(1) = (idxData - idxSc(1))*this.getFileInfo(chList(chIdx)).timeChannelWidth; %+hShift
                        end
                    end
%                     if(this.basicParams.scatterIRF)
%                         %move IRF to same position as model
%                         [~, dMaxPos] = max(fastsmooth(dataTmp(:),5,3,0),[],1);
%                         scShifts(end) = (dMaxPos-scMaxPos(end))*this.getFileInfo(chList(chIdx)).timeChannelWidth;%hShift;  
%                         scShiftsLB = scShifts(end);
%                         scShiftsUB = scShifts(end);
%                         nScatter = nScatter-1;
%                     end
                    %todo: take care of global fit!
                    if(nScatter > 0)
                        %adapt bounds                        
                        %move scatter data at least to IRF position
                        if(~isempty(this.basicParams.scatterStudy))
                            scShiftsUB = scShifts(1) + 10*this.getFileInfo(chList(chIdx)).timeChannelWidth;
                            scShiftsLB = scShifts(1) - 10*this.getFileInfo(chList(chIdx)).timeChannelWidth;
%                             if(scShifts(1) < 0)
%                                 scShiftsUB = scShifts(1) + 10*this.getFileInfo(chList(chIdx)).timeChannelWidth;%-2*tciGuess; %hShift;
%                                 scShiftsLB = min([scShiftsLB,scShifts(1)-10*this.getFileInfo(chList(chIdx)).timeChannelWidth],[],2);%(scShifts-scShiftsUB)*2],[],2);
%                             else
%                                 scShiftsLB = scShifts(1) - 10*this.getFileInfo(chList(chIdx)).timeChannelWidth;%+ 2*tciGuess; %hShift;
%                                 scShiftsUB = max([scShiftsUB,scShifts(1)+10*this.getFileInfo(chList(chIdx)).timeChannelWidth],[],2);%(scShifts-scShiftsLB)*2],[],2);
%                             end
                            %todo: borders for IRF shift
                        end
                        %scShiftsLB = 1*-(rs(chIdx).MaximumPosition - rs(chIdx).hShiftGuess - scMaxPos)*this.getFileInfo(chList(chIdx)).timeChannelWidth;
                        %                     scShiftsLB(end) = -10;                        
                        %                     scShiftsUB(end) = 10;%(idxSc-idxData).*this.getFileInfo(chList(chIdx)).timeChannelWidth;                        
                    end
                    lbArray(:,chIdx) = this.getNonConstantXVec(chList(chIdx),ampsLB,tausLB,tcisLB,betasLB,scAmpsLB,scShiftsLB,scOsetLB,hShiftLB,osetLB);
                    ubArray(:,chIdx) = this.getNonConstantXVec(chList(chIdx),ampsUB,tausUB,tcisUB,betasUB,scAmpsUB,scShiftsUB,scOsetUB,hShiftUB,osetUB);
                end
                % %         if(this.basicParams.heightMode == 2)
                %             oset = rs(chIdx).OffsetGuess;
                % %         else
                % %             oset = rs(chIdx).OffsetGuess/rs(chIdx).MaximumPhotons;
                % %         end
                % %         if(~this.basicParams.hybridFit && this.basicParams.fitModel == 0)
                %             tmpFitParams = params;
                %             %we compute amps and offset with the help of hybrid fit
                %             tmpFitthis.basicParams.hybridFit = 1;
                %             tmpFitthis.basicParams.heightMode = 1;
                %             tmpFitParams.computation.useGPU = false;
                % %             if(tmpFitthis.basicParams.nonLinOffsetFit == 2)
                % %                 tmpFitthis.basicParams.nonLinOffsetFit = 1;
                % %             end
                %             [tmpFitParams.volatile.cMask tmpFitParams.volatile.cVec] = paramMgr.makeCMaskCVec(tmpFitthis.basicParams,tmpFitParams.volatile);
                %             dataTmp = double(squeeze(allData(:,pixelID,chIdx)));
                %             m = multiExpModel(dataTmp,[],[],allIRF(:,chIdx),fileInfo(chIdx),tmpFitthis.basicParams,tmpFitthis.pixelFitParams,tmpFitParams.computation,tmpFitParams.volatile,linBounds(chIdx,1).lb,linBounds(chIdx,1).ub);
                %             %o = defWrapper(data,[],[],allIrf,fileInfo,tmpFitthis.basicParams,tmpFitthis.pixelFitParams,tmpFitParams.computation,tmpFitParams.volatile,squeeze(linBounds(:,1)));
                %             %     %                         tmpOptParams = getOptParams(2,tmpFitParams,params.optimization,getBounds(rs(chIdx).MaximumPhotons,rs(chIdx).OffsetGuess,tmpFitParams,allBounds));
                %             %     %                         tmpOptParams.maxIter = 10;
                %             %     %                         tmpOptParams.initNodes = 1;
                %             %     %iVec = MSimplexBnd(@o.costFcn, splitXVec(mergeXVec(amps,taus,tcis,betas,scAmps,scShifts,scOset,vShift,hShift,oset,tmpFitParams),tmpFitParams.cMask),tmpOptParams);
                %             %     %compute amps and offset
                %             %     %[amps oset] = o.compModel(iVec);%
                %             [amps oset] = m.compModel(splitXVec(mergeXVec(amps,taus,tcis,betas,scAmps,scShifts,scOset,vShift,hShift,oset,this.basicParams.tciMask,fileInfo(chIdx).timeChannelWidth),params.volatile.cMask));
                %             for idx = 1:this.basicParams.nExp
                %                 ag = sprintf('AmplitudeGuess%d',idx);
                %                 rs(chIdx).(ag) = amps(idx);
                %             end
                %             if(tmpFitthis.basicParams.nonLinOffsetFit == 1)
                %                 rs(chIdx).OffsetGuess = oset;
                %             end
                %             if(this.basicParams.heightMode == 2)
                %                 %scale amps and offset to relative values
                %                 amps = amps./rs(chIdx).MaximumPhotons;
                % %                 oset = oset./rs(chIdx).MaximumPhotons;
                % %                 s = sum([amps;oset;]);
                %                 amps = amps./sum(amps);
                % %                 oset = oset./s;
                %             end
                % %         end
                iArray(:,chIdx) = this.getNonConstantXVec(chList(chIdx),amps,taus,tcis,betas,scAmps,scShifts,scOset,hShift,oset);
                if(this.basicParams.optimizerInitStrategy == 1)
                    rs(chIdx).iVec(:) = this.getFullXVec(chList(chIdx),iArray(:,chIdx));
                    %this.setInitializationData(chList(chIdx),this.getNonConstantXVec(chList(chIdx),rs(chIdx).iVec(:)));
                    this.setInitializationData(chList(chIdx),iArray(:,chIdx));
                else
                    id = this.getInitializationData(chList(chIdx));
                    if(~isempty(id) && ~any(strcmp('hShift',this.basicParams.fix2InitTargets)))
                        %set shifts 
                        [ampsI, tausI, tcisI, betasI, scAmpsI, scShiftsI, scOsetI, hi, osetI] = this.getXVecComponents(id,true,chList(chIdx));
                        id = this.getNonConstantXVec(chList(chIdx),ampsI,tausI,tcisI,betasI,scAmpsI,scShiftsI,scOsetI,hi,osetI);
                    end
                    if(length(id) == size(iArray,1))
                        id = [id, iArray(:,chIdx)];
                        this.setInitializationData(chList(chIdx),id);
                    end
                end
            end
            lbArray = this.getFullXVec(this.currentChannel,lbArray);
            ubArray = this.getFullXVec(this.currentChannel,ubArray);
            nonLinBounds.lb(:) = this.joinGlobalFitXVec(this.getNonConstantXVec(this.currentChannel,lbArray),true);
            nonLinBounds.ub(:) = this.joinGlobalFitXVec(this.getNonConstantXVec(this.currentChannel,ubArray),true);
            if(nargout == 3)
                iArray = this.getFullXVec(this.currentChannel,iArray);
                iArray(this.volatilePixelParams.globalFitMask,1) = mean(iArray(this.volatilePixelParams.globalFitMask,:),2);
                iVec(:,1) = this.joinGlobalFitXVec(this.getNonConstantXVec(this.currentChannel,iArray),true);
                if(globalIVec)
                    %overwrite guess init values with given global init values
                    iVec = allInitVec;
                end
            end
        end
        
        function rs = makePreProcessResultStruct(this)
            %alloc preprocessing result structure
            rs.MaximumPhotons = zeros(1,1);
            rs.MaximumPosition = zeros(1,1);
            rs.TotalPhotons = zeros(1,1);
            rs.TauMeanGuess = zeros(1,1);
            rs.OffsetGuess = zeros(1,1);
            rs.hShiftGuess = zeros(1,1);
            rs.SlopeStartPosition = zeros(1,1);
            rs.StartPosition = ones(1,1);
            rs.EndPosition = 2.*ones(1,1);
            for i = 1:this.basicParams.nExp
                ag = sprintf('AmplitudeGuess%d',i);
                tg = sprintf('TauGuess%d',i);
                r = sprintf('RAUC%d',i);
                rs.(ag) = zeros(1,1);
                rs.(tg) = zeros(1,1);
                rs.(r) = zeros(1,1);
            end
            for i = 1:(this.basicParams.nExp + this.volatilePixelParams.nScatter)
                r = sprintf('RAUCIS%d',i);
                rs.(r) = zeros(1,1);
            end
            rs.iVec = zeros(1,this.volatilePixelParams.nModelParamsPerCh);
            rs.x_vec = zeros(1,this.volatilePixelParams.nModelParamsPerCh);
            rs.Iterations = 0;
            rs.FunctionEvaluations = 0;
            rs.Time = 0;
            rs.chi2 = 0;
            rs.chi2Tail = 0;
        end
        
        function checkGPU(this)
            %check for available GPUs
            if(this.computationParams.useGPU && ~isempty(this.volatilePixelParams.compatibleGPUs))
                %try to distribute parfor worker to the existing GPUs
                idx = min(length(this.volatilePixelParams.compatibleGPUs),ceil(get(getCurrentTask,'ID')/length(this.volatilePixelParams.compatibleGPUs)));
                if(isempty(idx))
                    idx = 1;
                end
                gpuDevice(this.volatilePixelParams.compatibleGPUs(idx));
                this.useGPU = true;
            else
                this.useGPU = false;
            end
        end
        
        function checkMexFiles(this)
            %check if mex files are available
            if(exist('shiftAndLinearOpt_mex','file'))
                [this.useMex, msg] = this.testShiftLinOpt1024();
                if(~isempty(msg))
                    warning('FLIMX:fluoPixelModel',msg);
                end
            else
                this.useMex = false;
            end
        end
        
        function varargout = getXVecComponents(this,xVec,isOnlyNonConstant,ch)
            %[amps taus tcis tcisFine scAmps scShifts scShiftsFine scOset hShift hShiftFine oset tciHShiftFine nVecs]
            %old: sliceXVec, reversal function: mergeXVec
            if(isOnlyNonConstant)
                xVec = this.getFullXVec(ch,xVec);
            end 
            %cache
            bp = this.basicParams;
            vpp = this.volatilePixelParams;
            %get actual parameters from xVec
            if(isvector(xVec))
                xVec = xVec(:);
            end
            varargout = cell(nargout,1);
            varargout{1} = xVec(1:bp.nExp,:); %amps
            varargout{2} = xVec(1+bp.nExp:2*bp.nExp,:); %taus
            nTci = sum(bp.tciMask);
            nSE = sum(bp.stretchedExpMask);
            pos = 2*bp.nExp;
            if(nargout > 9)
                nVecs = size(xVec,2);
                varargout{9} = round(xVec(end-1,:)./this.fileInfo(ch).timeChannelWidth); %hShift
                %% take care of tci
                varargout{3} = zeros(bp.nExp+(bp.scatterEnable && bp.scatterIRF),nVecs); %tcis 
                %combine hShift and tci
                tciMask = logical(bp.tciMask);
                tci_tmp = bsxfun(@times,ones(bp.nExp+(bp.scatterEnable && bp.scatterIRF),nVecs),xVec(end-1,:)./this.fileInfo(ch).timeChannelWidth); %hShift
                tci_tmp(tciMask,:) = tci_tmp(tciMask,:)+xVec(pos+1 : pos+nTci,:)./this.fileInfo(ch).timeChannelWidth; %hShift and tci
                tci_tmp = bsxfun(@minus,tci_tmp,varargout{9}); %substract rounded shift -> fine shift (and tcis) remain
                varargout{3}(tciMask,:) = round(tci_tmp(tciMask,:)); %rounded tcis
                varargout{11} = -(tci_tmp - round(tci_tmp));%tcisFine + shift fine
                pos = pos + nTci;
                %% stretched exponentials / beta
                varargout{4} = ones(bp.nExp,nVecs); %betas
                if(any(bp.stretchedExpMask))
                    varargout{4}(logical(bp.stretchedExpMask),:) = xVec(pos+1 : pos+nSE,:);
                end
                pos = pos + nSE;
                %% scatter parameters
                varargout{5} = xVec((1:3:vpp.nScatter*3)+pos,:); %scAmps
                pos = pos + 1;
                %combine hShift and scShift
                scMask = true(vpp.nScatter,1);
                sc_tmp = zeros(vpp.nScatter,nVecs);%bsxfun(@times,zeros(vpp.nScatter,nVecs),xVec(end-1,:)); %hShift
                sc_tmp(scMask,:) = (sc_tmp(scMask,:)+xVec((1:3:vpp.nScatter*3)+pos,:))./this.fileInfo(ch).timeChannelWidth; %hShift and scShifts
                %sc_tmp = bsxfun(@minus,sc_tmp,varargout{9}); %substract rounded shift -> fine shift (and tcis) remain
                varargout{6}(scMask,:) = round(sc_tmp(scMask,:)); %rounded tcis
                varargout{7} = -(sc_tmp - round(sc_tmp));%tcisFine + shift fine
                pos = pos + 1;
                varargout{8} = xVec((1:3:vpp.nScatter*3)+pos,:); %scOset
                %pos = pos + vpp.nScatter;
                %% take care of offset & shifts
%                 varargout{9} = xVec(end-2,:); %vShift
%                 varargout{11} = abs(xVec(end-1,:)-varargout{10}); %hShiftFine
                varargout{10} = xVec(end,:); %oset
                
                varargout{12} = nVecs; %nVecs
            else
                %no converted/fine tci & shifts
                varargout{3} = xVec(pos+1 : pos+nTci,:); %tcis
                pos = pos + nTci;
                varargout{4} = xVec(pos+1 : pos+nSE,:); %beta
                pos = pos + nSE;
                varargout{5} = xVec((1:3:vpp.nScatter*3)+pos,:); %scAmps
                pos = pos + 1;
                varargout{6} = xVec((1:3:vpp.nScatter*3)+pos,:); %scShifts
                pos = pos + 1;
                varargout{7} = xVec((1:3:vpp.nScatter*3)+pos,:); %scOset
%                 varargout{8} = xVec(end-2,:); %vShift
                varargout{8} = xVec(end-1,:); %hShift
                varargout{9} = xVec(end,:); %oset
            end
        end
        
        function x = getFullXVec(this,ch,varargin)
            %build x-vector (or matrix) from dynamic (xVec) and constant (cVec) parts according to cMask
            %old: combineXVec, reversal function: splitXVec
            x = [];
            vcp = this.getVolatileChannelParams(ch);
            if(length(varargin) == 1)
                xVec = varargin{1};
            else
                x = this.mergeXVecComponents(ch,varargin{:});
                return
            end
            if(isempty(vcp) || isempty(xVec))
                return
            end
            cMask = logical(vcp.cMask);
            cVec = vcp.cVec;
            if(isempty(cVec))
                if(isvector(xVec))
                    x = xVec(:);
                else
                    x = xVec;
                end
            else
                %     if(isvector(xVec))
                %         xVec = xVec(:);
                %     end
                if((size(xVec,1) + length(cVec)) ~= length(cMask))
                    error('Combined length of xVec (%d) and cVec (%d) does not match cMask (%d)!',size(xVec,1),length(cVec),length(cMask));
                end
                if(size(xVec,1) ~= sum(~cMask))
                    error('Length of xVec (%d) does not match non-constant cMask items (%d)!',size(xVec,1),sum(~cMask));
                end
                if(length(cVec) ~= sum(cMask))
                    error('Length of cVec (%d) does not match constant cMask items (%d)!',length(cVec),sum(cMask));
                end
                nrVecs = size(xVec,2);
                x = zeros(length(cMask),nrVecs);
                x(~cMask,:) = xVec;
                if(nrVecs == 1)
                    x(cMask,:) = cVec; 
                else
                    x(cMask,:) = repmat(cVec,1,nrVecs);
                end
            end
        end
        
        function [xVec, cVec] = getNonConstantXVec(this,ch,varargin)
            %build 'constant'-vector (or matrix) and dynamic (xNew) part from mixed (xVec) according to cMask
            %old: splitXVec, reversal function: combineXVec
            if(length(varargin) == 1)
                xVec = varargin{1};
            else
                xVec = this.mergeXVecComponents(ch,varargin{:});
            end
            vcp = this.getVolatileChannelParams(ch);
            if(~any(vcp.cMask(:)))
                cVec = [];
            else
                if(isvector(xVec))
                    xVec = xVec(:);
                end
                if(size(xVec,1) ~= length(vcp.cMask))
                    error('Length of xVec (%d) does not match cMask (%d)!',size(xVec,1),length(vcp.cMask));
                end
                cMask = logical(vcp.cMask);
                cVec = xVec(cMask,:);
                xVec = xVec(~cMask,:);
            end            
        end
        
        function xVec = joinGlobalFitXVec(this,xArray,isOnlyNonConstant)
            %joint xVecs into one xVec (including the globally fitted parameters) for each channel into a single global fit xVec
            %reversal function: divideGlobalFitXVec
            if(isvector(xArray))
                xArray = xArray(:);
            end
            if(length(this.nonEmptyChannelList) == 1)
                xVec = xArray;
                return
            end
            vcp = this.getVolatileChannelParams(1);
            if(size(xArray,1) ~= vcp.nApproxParamsPerCh && isOnlyNonConstant)
                error('Length of xVec (%d) is not equal to the total number of approximation parameters per channel (%d).',size(xArray,1),vcp.nApproxParamsPerCh);
            elseif(size(xArray,1) ~= this.volatilePixelParams.nModelParamsPerCh && ~isOnlyNonConstant)
                error('Length of xVec (%d) is not equal to the total number of model parameters per channel (%d).',size(xArray,1),this.volatilePixelParams.nModelParamsPerCh);
            end
            xVec = xArray(:,1);
            % if(~onlyNonConstantOutput)
            %     xVec = splitXVec(xVec,fitParams.cMask);
            % end
            % if(size(xArray,2) == 1)
            %     return
            % end
            % if(size(xArray,1) ~= fitParams.nModelParamsPerCh)
            %     error('Size of rest (%d) is not equal to the total number of parameters per channel (%d).',size(rest,2),fitParams.nModelParamsPerCh);
            % end
            mask = ~(this.volatilePixelParams.globalFitMask & ~vcp.cMask);
            if(isOnlyNonConstant)
                mask2 = mask(~vcp.cMask);
                mask1 = true(size(mask2));
            else
                mask2 = mask;
                mask2(logical(vcp.cMask)) = false;
                mask1 = ~vcp.cMask;
            end
            for i = 2:size(xArray,2)
                xVec = [xVec(mask1); xArray(mask2,i);];
            end
        end
        
        function xArray = divideGlobalFitXVec(this,xVec,isOnlyNonConstant)
            %split a global fit xVec into one xVec for each channel including the globally fitted parameters
            %reversal function: joinGlobalFitXVec
            nrCh = length(this.nonEmptyChannelList);
            if(nrCh == 1)
                xArray = xVec;
                return
            end
            [xLen, nModels] = size(xVec);
            vcp = this.getVolatileChannelParams(1);
            if(xLen < sum(~vcp.cMask))%this.volatilePixelParams.nApproxParamsPerCh)
                error('Length of xVec is too short: %d. It should be >= %d (= number of parameters).',xLen,vcp.nApproxParamsPerCh);
            end
            %nrRestParams = vcp.nApproxParamsPerCh - vcp.nGFApproxParamsPerCh;
            % if(any(fitParams.globalFitMask)) % && fitParams.nApproxParamsAllCh ~= fitParams.nApproxParamsPerCh
            %nrCh = max(1,ceil(fitParams.nApproxParamsAllCh / fitParams.nApproxParamsPerCh));
            %nrCh = 1+(this.volatilePixelParams.nApproxParamsAllCh - vcp.nApproxParamsPerCh) / (vcp.nApproxParamsPerCh - vcp.nGFApproxParamsPerCh);
            % else
            %     nrCh = 1;
            % end
            % if(nrCh - fix(nrCh) > 0)
            %     error('Length of xVec (%d) not consitent with total number of parameters (%d).',xLen,sum(fitParams.nApproxParamsPerCh));
            % end
            xArray = zeros(this.volatilePixelParams.nModelParamsPerCh,nrCh,nModels);
            if(isOnlyNonConstant)
                xArray(~vcp.cMask,1,:) = xVec(1:vcp.nApproxParamsPerCh,:);
                xVec(1:vcp.nApproxParamsPerCh,:) = [];
            else
                xArray(:,1,:) = xVec;
            end
            for ch = 2 : nrCh
                vcp = this.getVolatileChannelParams(ch);
                nrRestParams = vcp.nApproxParamsPerCh - vcp.nGFApproxParamsPerCh;
                if(isOnlyNonConstant)
                    try
                        xArray(~vcp.cMask & ~this.volatilePixelParams.globalFitMask,ch,:)  = xVec((ch-2)*nrRestParams+1 : (ch-1)*nrRestParams,:);
                    catch
                        a = 0;
                    end
                else
                    xArray(:,ch,:)  = xVec((ch-1)*nrRestParams : ch*nrRestParams,:);
                end
                xArray(this.volatilePixelParams.globalFitMask,ch,:) = xArray(this.volatilePixelParams.globalFitMask,1,:);
            end
            if(isOnlyNonConstant)
                %remove constant stuff from output
                if(nModels == 1)
                    xArray = this.getNonConstantXVec(1,xArray);
                else
                    xArrayOut = zeros(vcp.nApproxParamsPerCh, nrCh, nModels);
                    for ch = 1:nrCh
                        xArrayOut(:,ch,:) = this.getNonConstantXVec(ch,squeeze(xArray(:,ch,:)));
                    end
                    xArray = xArrayOut;
                end
            end
        end
        
        function xVec = mergeXVecComponents(this,ch,varargin)
            %amps,taus,tcis,tcisFine,betas,scAmps,scShifts,scShiftsFine,scOset,vShift,hShift,hShiftFine,oset,fitParams
            %reversal function: sliceXVec
            %re-combine sliced xVec
            if(numel(varargin) == 9) %amps,taus,tcis,scAmps,scShifts,scOset,hShift,oset
                if(length(varargin{5}) > 1)
                    scatter = [];
                    for i = 1:length(varargin{5})
                        scatter = [scatter; varargin{5}(i); varargin{6}(i); varargin{7}(i);];                    
                    end
                    xVec = [varargin{1}; varargin{2}; varargin{3}; varargin{4}; scatter; varargin{8}; varargin{9};];
                else
                    xVec = [varargin{1}; varargin{2}; varargin{3}; varargin{4}; varargin{5}; varargin{6}; varargin{7}; varargin{8}; varargin{9};];
                end
            elseif(numel(varargin) == 12) %amps,taus,tcis,tcisFine,betas,scAmps,scShifts,scShiftsFine,scOset,hShift,hShiftFine,oset
                if(length(varargin{5}) > 1)
                    scatter = [];
                    for i = 1:length(varargin{6})
                        scatter = [scatter; varargin{6}(i); (varargin{7}(i)+varargin{8}(i)); varargin{9}(i);];                    
                    end
                    xVec = [varargin{1}; varargin{2}; (varargin{3}(logical(tciMask)).*this.getFileInfo(ch).timeChannelWidth+varargin{4}(logical(this.volatilePixelParams.tciMask)));...
                    varargin{5}; scatter; (varargin{10}+varargin{11}); varargin{12};];
                else
                xVec = [varargin{1}; varargin{2}; (varargin{3}(logical(tciMask)).*this.getFileInfo(ch).timeChannelWidth+varargin{4}(logical(this.volatilePixelParams.tciMask)));...
                    varargin{5}; varargin{6}; (varargin{7}+varargin{8}); varargin{9}; (varargin{10}+varargin{11}); varargin{12};];
                end
            else
                xVec = [];
            end
        end
    end %methods 
    methods(Access = protected)
        % Override copyElement method:
        function cpObj = copyElement(this)
            % Make a shallow copy of all properties
            cpObj = copyElement@matlab.mixin.Copyable(this);
            % Make a deep copy of the DeepCp object
            for ch = 1:length(this.myChannels)
                if(~isempty(this.myChannels{ch}))
                    cpObj.myChannels{ch} = copy(this.myChannels{ch});
                    cpObj.myChannels{ch}.setParent(cpObj);
                end
            end
        end
    end
    
    methods(Static)
        function [model, chi2, idx, idxRemain] = timeShiftCheck(force2Edge,chi2,idx,exponentials,tcIdx,lowerBound,upperBounds)
            %check if exponential at tcIdx lies between slopeStartPos and the other exponentials, if not remove them from models, compute a chi2 and save it in index idx
            %find position of rising edge at half maximum
            model = [];
            exponentials = bsxfun(@minus,exponentials,min(exponentials,[],1));
            if(force2Edge)
                [~,fwhmPos] = max(bsxfun(@gt,exponentials,max(exponentials(:,tcIdx,:),[],1)/8),[],1);
            else
                [~,fwhmPos] = max(bsxfun(@gt,exponentials,max(exponentials,[],1)/8),[],1);                
            end
            fwhmPos = squeeze(fwhmPos);
            if(isvector(fwhmPos))
                fwhmPos = fwhmPos(:);
            end
            %compare "normal" component against shifted (by tci) components
            if(force2Edge)
                d = min(bsxfun(@minus,fwhmPos(~tcIdx,:),fwhmPos(tcIdx,:)),[],1);
            else
                d = inf;
            end
            %check shifted components against rising edge position
            d = min(d,(fwhmPos(tcIdx,:) - lowerBound));
            %check shifted components against data maximum
            d = min(d,upperBounds - fwhmPos(tcIdx,:));
            %idxHit = d < -5;
            idxHit = d < 0;
            if(any(idxHit))
                idxNum = find(~idx);
                idxNum = idxNum(idxHit);
                idx(idxNum) = true;
                chi2(idxNum) = chi2(idxNum)+d(idxHit).*-10000;
                %model(:,idxHit) = [];
                idxRemain = ~idxHit;
            else
                idxRemain = true(1,size(exponentials,3));
            end            
        end
        
        function [out, msg] = testShiftLinOpt1024()
            %returns true is a mex file can be used for shift and linear optimization computation with up to 1024 time channels
            try
                z = zeros(1,1,'single');
                shiftAndLinearOpt_mex(zeros(1024,0,0,'single'),ones(1024,1,'single'),single([]),false,z,z,z,z,z,z,true,true); %test computation
                out = true;
                msg = '';
            catch ME
                msg = sprintf('Using shiftAndLinearOpt_mex failed. Mex file was found but failed to run: %s',ME.message);
                out = false;
            end
        end
        
        function [nonLinBounds, linBounds] = getBoundsPerChannel(d_max,offset,basicFitParams,nScatter,cMask,allBounds)
            %get lower & upper bounds, initialization, quantization_inits, tolerances for optimization
            if(basicFitParams.nExp < 4)
                str = sprintf('bounds_%d_exp',basicFitParams.nExp);
                nonLinBounds.(str) = allBounds.(str);
            else
                str = sprintf('bounds_%d_exp',basicFitParams.nExp);
                b3e = allBounds.('bounds_3_exp');
                bne = allBounds.('bounds_nExp');
                n = basicFitParams.nExp - 3;
                fn_bounds = fieldnames(b3e);
                for i = 1:length(fn_bounds)
                    nonLinBounds.(str).(fn_bounds{i}) = [ b3e.(fn_bounds{i})(1:3) repmat(bne.(fn_bounds{i})(1),1,n) b3e.(fn_bounds{i})(4:6) repmat(bne.(fn_bounds{i})(2),1,n)];
                end
            end
            %scale to data max
            for i = 1:basicFitParams.nExp
                nonLinBounds.(str).lb(i) = nonLinBounds.(str).lb(i)*d_max;
                nonLinBounds.(str).ub(i) = nonLinBounds.(str).ub(i)*d_max;
                nonLinBounds.(str).deQuantization(i) = nonLinBounds.(str).deQuantization(i)*d_max;
                %nonLinBounds.(str).simplexInit(i) = nonLinBounds.(str).simplexInit(i)*d_max;
                nonLinBounds.(str).init(i) = nonLinBounds.(str).init(i)*d_max;
                nonLinBounds.(str).tol(i) = nonLinBounds.(str).tol(i)*d_max;
            end
            %tci
            nonLinBounds = nonLinBounds.(str);
            tcis = find(basicFitParams.tciMask);
            str = 'bounds_tci';
            fn_bounds = fieldnames(allBounds.(str));
            for j = tcis
                for i = 1:length(fn_bounds)
                    nonLinBounds.(fn_bounds{i}) = [ nonLinBounds.(fn_bounds{i}) allBounds.(str).(fn_bounds{i}) ];
                end
            end
            %stretched exp.
            nSExp = sum(basicFitParams.stretchedExpMask);
            if(nSExp ~= 0)
                str = 'bounds_s_exp';
                fn_bounds = fieldnames(allBounds.(str));
                for i = 1:length(fn_bounds)
                    nonLinBounds.(fn_bounds{i}) = [ nonLinBounds.(fn_bounds{i}) repmat(allBounds.(str).(fn_bounds{i}),1,nSExp) ];
                end
            end
            %scatter
            if(nScatter ~= 0)
                str = 'bounds_scatter';
                fn_bounds = fieldnames(allBounds.(str));
                for i = 1:length(fn_bounds)
                    switch fn_bounds{i}
                        case {'lb','ub','deQuantization','init','tol'}
                            %scale to data max
                            allBounds.(str).(fn_bounds{i})(1) = allBounds.(str).(fn_bounds{i})(1)*d_max;
                    end
                    %nonLinBounds.(fn_bounds{i}) = [ nonLinBounds.(fn_bounds{i}) repmat(allBounds.(str).(fn_bounds{i})(1),1,nScatter) repmat(allBounds.(str).(fn_bounds{i})(2),1,nScatter) repmat(allBounds.(str).(fn_bounds{i})(3),1,nScatter)];
                    nonLinBounds.(fn_bounds{i}) = [ nonLinBounds.(fn_bounds{i}) repmat(allBounds.(str).(fn_bounds{i}),1,nScatter)];
                end
            end
            %horizontal shift
            str = 'bounds_h_shift';
            fn_bounds = fieldnames(allBounds.(str));
            for i = 1:length(fn_bounds)
                nonLinBounds.(fn_bounds{i}) = [ nonLinBounds.(fn_bounds{i}) allBounds.(str).(fn_bounds{i}) ];
            end
            %offset
            str = 'bounds_offset';
            fn_bounds = fieldnames(allBounds.(str));
            for i = 1:length(fn_bounds)
                nonLinBounds.(fn_bounds{i}) = [ nonLinBounds.(fn_bounds{i}) allBounds.(str).(fn_bounds{i}) ];
            end
            %make bounds column vetors
            for i = 1:length(fn_bounds)
                nonLinBounds.(fn_bounds{i}) = nonLinBounds.(fn_bounds{i})(:);
            end
            %take care of constant parts
            linBounds = [];
            if(~isempty(cMask) && any(cMask(:)))
                linBounds = nonLinBounds;
                for i = 1:length(fn_bounds)
                    linBounds.(fn_bounds{i}) = linBounds.(fn_bounds{i})(cMask < 0);
                    nonLinBounds.(fn_bounds{i}) = nonLinBounds.(fn_bounds{i})(~cMask);
                end
            end
        end
        
        function tauMean = makeLifetimeGuess(data,irf,dPos,fitParams)
            %get mean lifetime (ps) for decay in data using the "centroid shift" method
            data = data(:);
            irf = irf(:);
            dLen = length(data);
            tVec = double(linspace(0,(dLen-1)*fitParams.timeChannelWidth,dLen))';
            [~, iPos] = max(irf(:));
            len = min(dLen-dPos,length(irf)-iPos);
            dataT = data(dPos:dPos+len).*tVec(2:len+2);
            dataT = dataT(~isnan(dataT));
            irfT = irf(iPos:iPos+len).*tVec(2:len+2); %iPos:iPos+len
            data = data(dPos:dPos+len);
            data = data(~isnan(data));
            mD = sum(dataT)/sum(data);
            mI = sum(irfT)/sum(irf(iPos:iPos+len));
            tauMean = abs(mD - mI);
        end
        
        function [oGuess, SlopeStartPosition, d_max] = makeOffsetGuess(data,d_max,offsetStartPos,fitStartPos,heightMode)
            %make an educated guess for the current offset
            dataStartPos = find(data > 0 & ~isnan(data),1);
            SlopeStartPosition = fluoPixelModel.getStartPos(data);
            oGuess = data(dataStartPos:max(dataStartPos+1,SlopeStartPosition));
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
            if(heightMode == 2)
                oGuess = oGuess/d_max*1;
                d_max = 1;
            end
        end
        
        function start_pos = getStartPos(data_vec)
            % find slope starting point using sliding average (fastsmooth function) and gradient
            if(isempty(data_vec) || ~any(data_vec))
                start_pos = 1;
                return
            end
            %get max & offset
            data_vec(isnan(data_vec)) = 0;
            [~, d1_pos] = max(data_vec(:));
            avg = fastsmooth(data_vec(1:d1_pos+5),3,3,0);
            %avg = sWnd1DAvg(data_vec(1:d1_pos+5),3); %use 5 points after max as well (smoother max), sliding window: 3x2+1=7
            %look for the rising egde only before the signal rose to 1/8th of the maximum
            fwemAPos = find(bsxfun(@lt,avg(1:end-5),max(avg(:),[],1)/6),1,'last')+1;
            p1 = find(avg,1);
            if(p1 >= fwemAPos)
                start_pos = 1;
            else
                start_pos = find(fastGrad(avg(p1:fwemAPos)) <= 0,1, 'last')+p1; %start 5 points prior to max
            end
            if(isempty(start_pos))
                start_pos = 1;
            end
        end
        
        function end_pos = getEndPos(data_vec)
            % find starting point for chi² computation using sliding average
            % cut zeros at the end of data vector
            if(isempty(data_vec))
                end_pos = 1;
                return
            end
            non_zero = find(data_vec);
            end_pos = non_zero(end);
        end
    end %methods(Static)
end % classdef
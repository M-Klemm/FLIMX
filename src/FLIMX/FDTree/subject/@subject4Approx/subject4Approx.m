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
            chList = find(any(this.myMeasurement.dirtyFlags,2));
            if(~isempty(chList))
                %something was changed when loading the measurement (e.g. reflection mask was recalculated), save it for later use
                for i = 1:length(chList)
                    this.myMeasurement.saveMatFile2Disk(chList(i));
                end
            end
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
        
        function setResultType(this,val)
            %set the result type string; only 'FluoDecayFit' (default) and 'ASCII' are valid
            this.myResult.setResultType(val);
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
            if(isempty(this.myResult.getPixelFLIMItem(ch,'Intensity')))
                this.setPixelFLIMItem(ch,'Intensity',this.getROIDataFlat(ch,false));
            end
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
        
        function clearROA(this)
            %clears measurement data and results of current region of approximation
            this.myMeasurement.clearROAData();
            this.clearROAResults();
        end
        
        function clearROAResults(this)
            %clear the results of current region of approximation
            %this.myMeasurement.clearROAData();
            roa = this.ROICoordinates;
            this.myResult.allocResults(1:this.nrSpectralChannels,roa(4)-roa(3)+1,roa(2)-roa(1)+1);
        end
        
        %% output
        function out = getApproximationPixelIDs(this,ch)
            %return indices of all pixels in channel ch which have the min. required number of photons
            out = find(this.getROIDataFlat(ch,false) >= this.basicParams.photonThreshold);            
        end
        
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
                for i = 1:nPixel %loop over roi pixel
                    apObjs{i} = getApproxObj(this,ch,idx(i,1),idx(i,2));
                end
            end
            %% assemble cell
            parameterCell(1) = {apObjs};
            parameterCell(2) = {optimizationParams};
            parameterCell(3) = {aboutInfo};
        end

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
%         function cpObj = copyElement(this)            
%             %make sure we create the approx. obects for all channels            
%             for ch = 1:this.nrSpectralChannels
%                 this.getApproxObj(ch,1,1);
%             end
%             % Make a shallow copy of all properties
%             cpObj = copyElement@matlab.mixin.Copyable(this);
%             % Make a deep copy of the DeepCp object
%             cpObj.myParent = []; 
%             cpObj.progressCb = cell(0,0);
%         end
    end
    
end
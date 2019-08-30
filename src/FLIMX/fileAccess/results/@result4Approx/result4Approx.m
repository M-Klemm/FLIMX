classdef result4Approx < resultFile
    %=============================================================================================================
    %
    % @file     result4Approx.m
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
    % @brief    A class to represent a result object used during approximation
    %
    properties(GetAccess = public, SetAccess = private)
    end
    
    properties (Dependent = true)
    end
    
    methods
        function this = result4Approx(hSubject)
            %constructor
            this = this@resultFile(hSubject);            
            %this.checkMyFiles();
        end
        
        function setResultType(this,val)
            %set the result type string; only 'FluoDecayFit' (default) and 'ASCII' are valid
            if(strcmp(val,'ASCII') || strcmp(val,'FluoDecayFit') && ~strcmp(val,this.resultType))
                this.resultType = val;
                this.setDirty(1:length(this.results.pixel),true);
            end
        end
        
        function setEffectiveTime(this,ch,t)
            %set the effective time the approximation of ch took
            if(ch <= length(this.results.pixel))
                this.results.pixel{ch,1}.EffectiveTime = t;
                this.setDirty(ch,true);
            end            
        end
        
        function importResultStruct(this,rs,ch,position,scaling)
            %import a result struct into this object, the result struct must have the same format as a result file
            %make sure version is correct
            rs = resultFile.updateFitResultsStruct(rs,this.paramMgrObj.getDefaults().about);
            rs.auxiliaryData.fileInfo.position = position;
            rs.auxiliaryData.fileInfo.pixelResolution = scaling;
            this.loadResult(rs);
            this.setDirty(ch,true);
            %update fileInfo of other channels
            if(ch > 1)
                for i = 1:ch-1
                    if(this.auxiliaryData{i}.fileInfo.nrSpectralChannels ~= rs.auxiliaryData.fileInfo.nrSpectralChannels)
                        this.auxiliaryData{i}.fileInfo.nrSpectralChannels = rs.auxiliaryData.fileInfo.nrSpectralChannels;
                        this.setDirty(i,true);
                    end
                end
            end
        end
        
        function addFLIMItems(this,ch,itemsStruct)
            %add FLIM items to our inner results structure, here: FLIM items do not need to be allocated previously!
            %todo: check overwrite?!
            %todo: restrict FLIM item names (e.g. tauMean is reserved)
            tmp = this.getPixelResult(ch);
            fn = fieldnames(itemsStruct);
            for l = 1:length(fn)
                if(all(size(itemsStruct.(fn{l})) == this.resultSize))
                    tmp.(fn{l}) = itemsStruct.(fn{l});
                end
            end
            this.results.pixel{ch,1} = tmp;
            this.pixelApproximated(ch) = true;
            this.setDirty(ch,true);
            this.loadedChannels(ch,1) = true;
        end
        
%         function addFLIMItems(this,ch,resultStruct)
%             %add FLIM items to our inner results structure, FLIM items must have been allocated previously!
%             if(isempty(resultStruct))
%                 return
%             end
%             tmp = this.getPixelResult(ch);
%             pn = fieldnames(tmp);
%             fn = fieldnames(resultStruct);
%             for l = 1:length(fn)
%                 idx = strncmpi(pn,fn{l},length(fn{l}));
%                 if(any(idx(:)))
%                     if(all(size(resultStruct.(fn{l})) == size(tmp.(pn{idx}))))
%                         tmp.(fn{l}) = resultStruct.(fn{l});
%                     end
%                 end
%             end
%             this.results.pixel{ch,1} = tmp;
%             this.pixelApproximated(ch) = true;
%             this.loadedChannels(ch,1) = true;
%             this.setDirty(ch,true);
%         end
        
        function addResultRow(this,ch,row,resultStruct)
            %add complete results row from a cell array to our inner results structure
            if(length(resultStruct) > 1)
                for ch = 1:length(resultStruct)
                    this.addResultRow(ch,row,resultStruct(ch));
                end
                return
            end
            if(~isstruct(resultStruct) || row < 1 || row > this.resultSize(1))
                return
            end
            fn = fieldnames(resultStruct);
            if(this.resultSize(1) ~= length(resultStruct.(fn{1})))
                %dimension mismatch -> post error message
                return
            end            
            tmp = this.getPixelResult(ch);
            %add only new results
            newIdx = 1:this.resultSize(1);
            if(any(strcmpi(fn,'chi2')))
                for i = length(newIdx) : -1 : 1
                    if(tmp.chi2(row,i) > 0 && tmp.chi2(row,i) < resultStruct.chi2(i,1))
                        newIdx(i) = [];
                    end
                end
            end
            if(isempty(newIdx))
                return
            end
            fn = fn(~strcmpi(fn,'ROI_merge_result'));
            fn = fn(~strcmpi(fn,'Message'));
            fn = fn(~strcmpi(fn,'reflectionMask'));
            fn = fn(~strcmpi(fn,'cVec'));
            fn = fn(~strcmpi(fn,'cMask'));
            idx = strcmpi(fn,'xVec');
            if(any(idx(:)))
                fn = fn(~idx);
                lenThis = size(tmp.x_vec,2);
                nPThis = size(tmp.x_vec,3);
                lenIn = size(resultStruct.xVec,2);
                nPIn = size(resultStruct.xVec,1);
                if(lenThis == lenIn && nPThis == nPIn)
                    tmp.x_vec(row,newIdx,:) = resultStruct.xVec(:,newIdx);
                else
                    %something went wrong - save what we can even though it is wrong
%                     lenMin = min(lenThis,lenIn);
%                     nPMin = min(nPThis,nPIn);
%                     tmp.x_vec(row,1:lenMin,1:nPMin) = resultStruct.xVec(1:nPMin,1:lenMin);
                    warning('FluoDecayFit:addResultColumn','Length of Columns did not match: expected %d, got %d!',lenThis,lenIn);
                end
            end
            idx = strcmpi(fn,'iVec');
            if(any(idx(:)))
                fn = fn(~idx);
                lenThis = size(tmp.iVec,2);
                nPThis = size(tmp.iVec,3);
                lenIn = size(resultStruct.iVec,1);
                nPIn = size(resultStruct.iVec,2);
                if(lenThis == lenIn && nPThis == nPIn)
                    tmpIdx = newIdx(any(resultStruct.iVec(:,newIdx)));
                    tmp.iVec(row,tmpIdx,:) = resultStruct.iVec(:,tmpIdx);
                else
                    %something went wrong - save what we can even though it is wrong
%                     lenMin = min(lenThis,lenIn);
%                     nPMin = min(nPThis,nPIn);
%                     tmp.iVec(row,1:lenMin,1:nPMin) = resultStruct.iVec(1:lenMin,1:nPMin);
                    warning('FluoDecayFit:addResultColumn','Length of Columns did not match: expected %d, got %d!',lenThis,lenIn);
                end
            end
            for l = 1:length(fn)
                lenThis = size(tmp.(fn{l}),2);
                lenIn = length(resultStruct.(fn{l}));
                if(lenThis == lenIn)
                    tmp.(fn{l})(row,newIdx) = resultStruct.(fn{l})(newIdx);
                else
                    %something went wrong - save what we can even though it is wrong
                    %                         lenMin = min(lenThis,lenIn);
                    %                         tmp.(fn{l})(row,1:lenMin) = resultStruct.(fn{l})(1:lenMin);
                    warning('FluoDecayFit:addResultRow','Length of Row did not match: expected %d, got %d!',lenThis,lenIn);
                end
            end
            this.results.pixel{ch,1} = tmp;
            this.pixelApproximated(ch) = true;
            this.loadedChannels(ch,1) = true;
            this.setDirty(ch,true);
        end
         
        function addResultColumn(this,ch,col,resultStruct)
            %add complete results column from a cell array to our inner results structure
            if(length(resultStruct) > 1)
                for ch = 1:length(resultStruct)
                    this.addResultColumn(ch,col,resultStruct(ch));
                end
                return
            end
            if(~isstruct(resultStruct) || col < 1 || col > this.resultSize(2))
                return
            end
            fn = fieldnames(resultStruct);
            if(this.resultSize(2) ~= length(resultStruct.(fn{1})))
                %dimension mismatch -> post error message
                return
            end
            tmp = this.getPixelResult(ch);
            %add only new results
            newIdx = 1:this.resultSize(2);
            if(any(strcmpi(fn,'chi2')))
                for i = length(newIdx) : -1 : 1
                    if(tmp.chi2(i,col) > 0 && tmp.chi2(i,col) < resultStruct.chi2(i,1))
                        newIdx(i) = [];
                    end
                end
            end
            if(isempty(newIdx))
                return
            end
            fn = fieldnames(resultStruct);
            fn = fn(~strcmpi(fn,'ROI_merge_result'));
            fn = fn(~strcmpi(fn,'Message'));
            fn = fn(~strcmpi(fn,'reflectionMask'));
            fn = fn(~strcmpi(fn,'cVec'));
            fn = fn(~strcmpi(fn,'cMask'));
            tmp = this.getPixelResult(ch);
            idx = strcmpi(fn,'xVec');
            if(any(idx(:)))
                fn = fn(~idx);
                lenThis = size(tmp.x_vec,1);
                nPThis = size(tmp.x_vec,3);
                lenIn = size(resultStruct.xVec,2);
                nPIn = size(resultStruct.xVec,1);
                if(lenThis == lenIn && nPThis == nPIn)
                    tmp.x_vec(newIdx,col,:) = resultStruct.xVec(:,newIdx);
                else
                    %something went wrong - save what we can even though it is wrong
                    %                         lenMin = min(lenThis,lenIn);
                    %                         nPMin = min(nPThis,nPIn);
                    %                         tmp.x_vec(1:lenMin,col,1:nPMin) = resultStruct.xVec(1:nPMin,1:lenMin);
                    warning('FluoDecayFit:addResultColumn','Length of Columns did not match: expected %d, got %d!',lenThis,lenIn);
                end
            end
            idx = strcmpi(fn,'iVec');
            if(any(idx(:)))
                fn = fn(~idx);
                lenThis = size(tmp.iVec,1);
                nPThis = size(tmp.iVec,3);
                lenIn = size(resultStruct.iVec,1);
                nPIn = size(resultStruct.iVec,3);
                if(lenThis == lenIn && nPThis == nPIn)
                    tmpIdx = newIdx(any(resultStruct.iVec(:,newIdx)));
                    tmp.iVec(tmpIdx,col,:) = resultStruct.iVec(:,tmpIdx);
                else
                    %something went wrong - save what we can even though it is wrong
                    %                         lenMin = min(lenThis,lenIn);
                    %                         nPMin = min(nPThis,nPIn);
                    %                         tmp.iVec(1:lenMin,col,1:nPMin) = resultStruct.iVec(1:lenMin,1:nPMin);
                    warning('FluoDecayFit:addResultColumn','Length of Columns did not match: expected %d, got %d!',lenThis,lenIn);
                end
            end
            for l = 1:length(fn)
                lenThis = size(tmp.(fn{l}),1);
                lenIn = length(resultStruct.(fn{l}));
                if(lenThis == lenIn)
                    tmp.(fn{l})(newIdx,col) = resultStruct.(fn{l})(newIdx);
                else
                    %something went wrong - save what we can even though it is wrong
                    %                         lenMin = min(lenThis,lenIn);
                    %                         tmp.(fn{l})(1:lenMin,col) = resultStruct.(fn{l})(1:lenMin);
                    warning('FluoDecayFit:addResultColumn','Length of Columns did not match: expected %d, got %d!',lenThis,lenIn);
                end
            end
            this.results.pixel{ch,1} = tmp;
            this.pixelApproximated(ch) = true;
            this.loadedChannels(ch,1) = true;
            this.setDirty(ch,true);
        end
        
        function addMultipleResults(this,ch,indices,resultStruct)
            %add mupltiple results according to their indices
            if(isempty(resultStruct) || ~isstruct(resultStruct))
                return
            end
            if(any(this.volatilePixelParams.globalFitMask) && length(resultStruct) > 1)
                for ch = 1:length(resultStruct)
                    this.addMultipleResults(ch,indices,resultStruct(ch));
                end
                return
            end
            fn = fieldnames(resultStruct);
            if(size(indices,1) ~= length(resultStruct.(fn{1})))
                %dimension mismatch -> post error message
                return
            end
            if(length(this.results.pixel) >= ch && ~isempty(this.results.pixel{ch,1}))
                tmp = this.results.pixel{ch,1};
            else
                this.allocPixelResult(ch);
                tmp = this.results.pixel{ch,1};
            end
            %add only new results
            newIdx = 1:size(indices,1)';
            if(any(strcmpi(fn,'chi2')))
                ri = sub2ind(this.resultSize,indices(:,1),indices(:,2));
                newIdx(tmp.chi2(ri) > 0 & tmp.chi2(ri) < resultStruct.chi2(:)) = [];
%                 for i = size(indices,1) : -1 : 1
%                     if(tmp.chi2(indices(i,1),indices(i,2)) > 0 && tmp.chi2(indices(i,1),indices(i,2)) < resultStruct.chi2(i,1))
%                         newIdx(i) = [];
%                     end
%                 end
            end
            if(isempty(newIdx))
                return
            end
            fn = fn(~strcmpi(fn,'ROI_merge_result'));
            fn = fn(~strcmpi(fn,'Message'));
            fn = fn(~strcmpi(fn,'reflectionMask'));
            fn = fn(~strcmpi(fn,'cVec'));
            fn = fn(~strcmpi(fn,'cMask'));
            cleanUpResult = logical(sum(tmp.x_vec(:)));
            %special treatment for xVec
            idx = strcmpi(fn,'xVec');
            if(any(idx(:)))
                fn = fn(~idx);
                nPThis = size(tmp.x_vec,3);
                nPIn = size(resultStruct.xVec,1);
                if(nPThis == nPIn)
                    %todo: check if indices are out of bounds...
                    for i = 1:length(newIdx)
                        tmp.x_vec(indices(newIdx(i),1),indices(newIdx(i),2),:) = resultStruct.xVec(:,newIdx(i));
                    end
                else
                    %something went wrong - save what we can even though it is wrong
                    warning('FluoDecayFit:addMultipleResults','Length of parameters did not match: expected %d, got %d!',nPThis,nPIn);
                end
            end
            %special treatment for iVec
            idx = strcmpi(fn,'iVec');
            if(any(idx(:)))
                fn = fn(~idx);
                nPThis = size(tmp.iVec,3);
                nPIn = size(resultStruct.iVec,1);
                if(nPThis == nPIn)
                    %todo: check if indices are out of bounds...
                    for i = 1:length(newIdx)
                        if(any(resultStruct.iVec(:,newIdx(i))))
                            tmp.iVec(indices(newIdx(i),1),indices(newIdx(i),2),:) = resultStruct.iVec(:,newIdx(i));
                        end
                    end
                else
                    %something went wrong - save what we can even though it is wrong
                    warning('FluoDecayFit:addMultipleResults','Length of parameters did not match: expected %d, got %d!',nPThis,nPIn);
                end
            end
            idx = sub2ind([this.resultSize(1) this.resultSize(2)],indices(newIdx,1),indices(newIdx,2));
            %if we "clean up" a result: special treatment for function evaluations, iterations, time
            if(cleanUpResult)
                targets = {'FunctionEvaluations','Iterations','Time'};
                for i = 1:length(targets)
                    item = strcmpi(fn,targets{i});                    
                    tmp.(fn{item})(idx) = tmp.(fn{item})(idx) + resultStruct.(fn{item})(newIdx)';
                    fn = fn(~item);
                end
            end
            %copy remaining results
            for l = 1:length(fn)
                %todo: check if indices are out of bounds...
                try
                    tmp.(fn{l})(idx) = resultStruct.(fn{l})(newIdx);
                catch ME
                    a=0;
                end
            end
            this.results.pixel{ch,1} = tmp;
            this.pixelApproximated(ch) = true;
            this.loadedChannels(ch,1) = true;
            this.setDirty(ch,true);
        end
        
        function addSingleResult(this,ch,row,col,resultStruct)
            %add single results to our inner results structure
            if(isempty(resultStruct) || ~isstruct(resultStruct))
                return
            end
            if(length(resultStruct) > 1)
                for ch = 1:length(resultStruct)
                    this.addSingleResult(ch,row,col,resultStruct(ch));
                end
                return
            end
            fn = fieldnames(resultStruct);
            if(length(this.results.pixel) >= ch && ~isempty(this.results.pixel{ch,1}))
                tmp = this.results.pixel{ch,1};
            else
                this.allocPixelResult(ch);
                tmp = this.results.pixel{ch,1};
            end
            %add only new results
            if(any(strcmpi(fn,'chi2')) && tmp.chi2(row,col) > 0 && tmp.chi2(row,col) < resultStruct.chi2)
                return
            end
            fn = fn(~strcmpi(fn,'ROI_merge_result'));
            fn = fn(~strcmpi(fn,'Message'));
            fn = fn(~strcmpi(fn,'reflectionMask'));
            fn = fn(~strcmpi(fn,'cVec'));
            fn = fn(~strcmpi(fn,'cMask'));
            idx = strcmpi(fn,'xVec');
            if(any(idx(:)))
                fn = fn(~idx);
                tmp.x_vec(row,col,:) = resultStruct.xVec;
            end
            idx = strcmpi(fn,'iVec');
            if(any(idx(:)))
                fn = fn(~idx);
                if(any(resultStruct.iVec))
                    tmp.iVec(row,col,:) = resultStruct.iVec;
                end
            end            
            for l = 1:length(fn)
                tmp.(fn{l})(row,col) = resultStruct.(fn{l});
            end
            this.results.pixel{ch,1} = tmp;
            this.pixelApproximated(ch) = true;
            this.loadedChannels(ch,1) = true;
            this.setDirty(ch,true);
        end
        
        function postProcessInitialization(this,ch)
            %compute fixed parameters for pixel approximation from init
            if(~this.initApproximated(ch))
                return
            end            
            this.pixelApproximated(ch,1) = false;
            ip = this.initFitParams;
            bp = this.basicParams;
            vp = this.volatilePixelParams;            
            XSz = this.resultSize(2);
            YSz = this.resultSize(1);
            roiX = round(linspace(1,XSz,ip.gridSize));% 1:floor((XSz-1)/(ip.gridSize-1)):XSz;
            roiY = round(linspace(1,YSz,ip.gridSize));% 1:floor((YSz-1)/(ip.gridSize-1)):YSz;
            [X,Y] = meshgrid(roiX,roiY);
            [XI,YI] = meshgrid(1:XSz,1:YSz);
            %re-allocate pixel results for channel
            this.allocPixelResult(ch);
            %this.results.pixel(ch) = {this.makeResultStructs(YSz,XSz)};
            %interpolate global initialization for all pixels
            if(this.basicParams.optimizerInitStrategy == 2)
                for i = 1:length(vp.modelParamsString)
                    [dTypeStr, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(vp.modelParamsString{i});
                    if(dTypeNr == 0)
                        dTypeNrStr = '';
                    else
                        dTypeNrStr = num2str(dTypeNr);
                    end
                    iData = this.getInitFLIMItem(ch,(sprintf('%s%s',dTypeStr{1},dTypeNrStr)));                    
                    if(ip.gridSize == 1)
                        pData = repmat(iData,YSz,XSz);
                    else
                        pData = interp2(X,Y,iData,XI,YI,'linear');
                    end  
                    if(bp.fix2InitSmoothing && any(strcmp(vp.modelParamsString{i},bp.fix2InitTargets)))
                        pData = sffilt(@mean,pData,[3 3]);
                    end
                    this.results.pixel{ch,1}.(sprintf('%sInit%s',dTypeStr{1},dTypeNrStr)) = pData;
                end
                %iVec as a whole
                iData = this.getInitFLIMItem(ch,'x_vec');
                iTmp = zeros(YSz,XSz,size(iData,3));
                if(ip.gridSize == 1)
                    this.results.pixel{ch,1}.iVec = repmat(iData,[YSz,XSz,1]);
                else
                    for i = 1:size(iData,3)
                        iTmp(:,:,i) = interp2(X,Y,iData(:,:,i),XI,YI,'linear');
                    end
                    this.results.pixel{ch,1}.iVec = iTmp;
                end  
            end
%                 %taus
%                 for i = 1:bp.nExp
%                     if(ip.gridSize == 1)
%                         this.results.pixel{ch,1}.(sprintf('TauInit%d',i)) = repmat(this.getInitFLIMItem(ch,(sprintf('Tau%d',i))),YSz,XSz);
%                     else
%                         this.results.pixel{ch,1}.(sprintf('TauInit%d',i)) = interp2(X,Y,this.getInitFLIMItem(ch,(sprintf('Tau%d',i))),XI,YI,'linear');
%                     end
%                 end
%                 %tci
%                 idx = find(strncmp('tc',fn,2));
%                 for i = 1:length(idx)
%                     tmpStr = fn{idx(i)};
%                     if(ip.gridSize == 1)
%                         this.results.pixel{ch,1}.(sprintf('tcInit%s',tmpStr(3))) = repmat(tmp.(tmpStr),YSz,XSz);
%                     else
%                         this.results.pixel{ch,1}.(sprintf('tcInit%s',tmpStr(3))) = interp2(X,Y,tmp.(tmpStr),XI,YI,'linear');
%                     end
%                 end
%                 %beta
%                 idx = find(strncmp('Beta',fn,4));
%                 for i = 1:length(idx)
%                     tmpStr = fn{idx(i)};
%                     if(ip.gridSize == 1)
%                         this.results.pixel{ch,1}.(sprintf('BetaInit%s',tmpStr(5))) = repmat(tmp.(tmpStr),YSz,XSz);
%                     else
%                         this.results.pixel{ch,1}.(sprintf('BetaInit%s',tmpStr(5))) = interp2(X,Y,tmp.(tmpStr),XI,YI,'linear');
%                     end
%                 end
%                 %offset
%                 if(ip.gridSize == 1)
%                     this.results.pixel{ch,1}.OffsetInit = repmat(tmp.Offset,XSz,XSz);
%                 else
%                     this.results.pixel{ch,1}.OffsetInit = interp2(X,Y,tmp.Offset,XI,YI,'linear');
%                 end
%                 %iVec as a whole
%                 iTmp = zeros(YSz,XSz,size(tmp.iVec,3));
%                 if(ip.gridSize == 1)
%                     this.results.pixel{ch,1}.iVec = repmat(tmp.x_vec,[YSz,XSz,1]);
%                 else
%                     for i = 1:size(tmp.iVec,3)
%                         iTmp(:,:,i) = interp2(X,Y,tmp.x_vec(:,:,i),XI,YI,'linear');
%                     end
%                     this.results.pixel{ch,1}.iVec = iTmp;
%                 end                
%             end
            sStr = bp.(sprintf('constMaskSaveStrCh%d',ch));
            sVals = double(bp.(sprintf('constMaskSaveValCh%d',ch)));
            for i = 1:length(bp.fix2InitTargets)
                %set constant parameter names for pixel fit
                fStr = bp.fix2InitTargets{i};
                idx = find(strcmp(fStr,sStr),1);
                if(isempty(idx))
                    idx = length(sStr)+1;
                    %bp.(sprintf('constMaskSaveValCh%d',ch)) = double(bp.(sprintf('constMaskSaveValCh%d',ch)));
                end
                sStr{idx} = fStr;
                sVals(idx) = 0;
            end
            bp.(sprintf('constMaskSaveStrCh%d',ch)) = sStr;
            bp.(sprintf('constMaskSaveValCh%d',ch)) = sVals;

%                 sStr = bp.(sprintf('constMaskSaveStrCh%d',ch));
%                 idx = find(strcmp('hShift',sStr),1);
%                 if(isempty(idx))
%                     idx = length(sStr)+1;
%                     bp.(sprintf('constMaskSaveValCh%d',ch)) = double(bp.(sprintf('constMaskSaveValCh%d',ch)));
%                 end
%                 sStr{idx} = 'hShift';
%                 bp.(sprintf('constMaskSaveStrCh%d',ch)) = sStr;
%                 bp.(sprintf('constMaskSaveValCh%d',ch))(idx) = 0;
%                 if(isfield(tmp,'ShiftScatter1'))
%                     sStr = bp.(sprintf('constMaskSaveStrCh%d',ch));
%                     idx = find(strcmp('Scatter Shift 1',sStr),1);
%                     if(isempty(idx))
%                         idx = length(sStr)+1;
%                         bp.(sprintf('constMaskSaveValCh%d',ch)) = double(bp.(sprintf('constMaskSaveValCh%d',ch)));
%                     end
%                     sStr{idx} = 'ShiftScatter1';
%                     bp.(sprintf('constMaskSaveStrCh%d',ch)) = sStr;
%                     bp.(sprintf('constMaskSaveValCh%d',ch))(idx) = 0;
%                 end                 
%             end
            this.paramMgrObj.setParamSection('basic_fit',bp,false);
        end
        
        function addInitResult(this,ch,indices,resultStruct)
            %add single results to our inner results structure
            if(any(this.volatilePixelParams.globalFitMask) && length(resultStruct) > 1)
                for ch = 1:length(resultStruct)
                    this.addInitResult(ch,indices,resultStruct(ch));
                end
                return
            end
            ip = this.initFitParams;
            fn = fieldnames(resultStruct);
            if(size(indices,1) ~= length(resultStruct.(fn{1})) || any(indices(:) > ip.gridSize))
                %dimension mismatch -> post error message
                return
            end
            if(length(this.results.init) >= ch && ~isempty(this.results.init{ch,1}))
                tmp = this.results.init{ch,1};
            else
                this.allocInitResult(ch);
                tmp = this.results.init{ch,1};
            end
%             if(isempty(tmp))
%                 %should not happen
%                 tmp = this.makeResultStructs(this.initFitParams.gridSize,this.initFitParams.gridSize);
%             end
            newIdx = 1:size(indices,1);
            if(any(strcmpi(fn,'chi2')))
                for i = size(indices,1) : -1 : 1
                    if(tmp.chi2(indices(i,1),indices(i,2)) > 0 && tmp.chi2(indices(i,1),indices(i,2)) < resultStruct.chi2(i,1))
                        newIdx(i) = [];
                    end
                end
            end
            if(isempty(newIdx))
                return
            end
            fn = fn(~strcmpi(fn,'ROI_merge_result'));
            fn = fn(~strcmpi(fn,'Message'));
            fn = fn(~strcmpi(fn,'reflectionMask'));
            fn = fn(~strcmpi(fn,'cVec'));
            fn = fn(~strcmpi(fn,'cMask'));
            idx = strcmpi(fn,'xVec');
            if(any(idx(:)))
                fn = fn(~idx);
                nPThis = size(tmp.x_vec,3);
                nPIn = size(resultStruct.xVec,1);
                if(nPThis == nPIn)
                    %todo: check if indices are out of bounds...
                    for i = 1:length(newIdx)
                        tmp.x_vec(indices(newIdx(i),1),indices(newIdx(i),2),:) = resultStruct.xVec(:,newIdx(i));
                    end
                else
                    %something went wrong - save what we can even though it is wrong
                    warning('FluoDecayFit:addMultipleResults','Length of parameters did not match: expected %d, got %d!',nPThis,nPIn);
                end
            end
            idx = strcmpi(fn,'iVec');
            if(any(idx(:)))
                fn = fn(~idx);
                nPThis = size(tmp.iVec,3);
                nPIn = size(resultStruct.iVec,1);
                if(nPThis == nPIn)
                    %todo: check if indices are out of bounds...
                    for i = 1:length(newIdx)
                        tmp.iVec(indices(newIdx(i),1),indices(newIdx(i),2),:) = resultStruct.iVec(:,newIdx(i));
                    end
                else
                    %something went wrong - save what we can even though it is wrong
                    warning('FluoDecayFit:addMultipleResults','Length of parameters did not match: expected %d, got %d!',nPThis,nPIn);
                end
            end
            idx = sub2ind([ip.gridSize ip.gridSize],indices(newIdx,1),indices(newIdx,2));
            for l = 1:length(fn)
                %todo: check if indices are out of bounds...
                tmp.(fn{l})(idx) = resultStruct.(fn{l})(newIdx);
            end
            this.results.init{ch,1} = tmp;
            this.setDirty(ch,true);
            %compute interpolation grid
            if(~all(tmp.Tau1(:)))
                %init result is not complete yet
                return
            end
            this.initApproximated(ch) = true;
            this.loadedChannels(ch,1) = true;
            this.postProcessInitialization(ch);
        end
        
        %% output
%         function result = makeExportStruct(this,ch)
%             %build the structure with results for export
% %             [~, fileName, ext] = fileparts(this.myParent.getSourceFile());
% %             roi = this.myParent.ROICoordinates;
% %             int = this.myParent.getRawDataFlat(ch);
% %             if(length(roi) == 4 && ~isempty(int) && size(int,1) >= roi(4) && size(int,2) >= roi(2))
% %                 int = int(roi(3):roi(4),roi(1):roi(2));
% %             else
% %                 int = [];
% %             end
%             result = makeExportStruct@resultFile(this,ch);%,this.myParent.getDatasetName(),[fileName ext],roi,int,this.myParent.getReflectionMask(ch));
%         end        
        
%         function exportMatFile(this,ch,folder)
%              %save results to specific folder
%              fn = this.getResultFileName(ch,folder);
%              exportMatFile@resultFile(this,ch,fn);
%         end
        
    end
    
    
end
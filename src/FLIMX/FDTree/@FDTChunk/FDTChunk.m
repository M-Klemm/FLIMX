classdef FDTChunk < FDTreeNode
    %=============================================================================================================
    %
    % @file     FDTChunk.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  2.0
    % @date     January, 2019
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
    % @brief    A class to represent data types (fluorescence lifetime parameter) in a channel, e.g. amplitudes, taus, ...
    %
    properties(SetAccess = protected,GetAccess = public)
        dType = [];
        defaultSizeFlag = true;
        resultROICoordinates = []; %only used, if defaultSizeFlag is false
    end
    properties(SetAccess = protected,GetAccess = protected)        
    end
    properties (Dependent = true)
        FLIMXParamMgrObj
        isSubjectDefaultSize
    end

    methods
        function this = FDTChunk(parent,dType,defaultSizeFlag)
            % Constructor for FDTChunk
            this = this@FDTreeNode(parent,dType);
            this.dType = dType;
            this.defaultSizeFlag = logical(defaultSizeFlag);            
        end
        
%         function out = getSize(this)
%             %determine memory size of the chunk
%             out = 0;
%             for i = 1:this.nrChildren
%                 slice = this.getChildAtPos(i);
%                 if(~isempty(slice))
%                     out = out + slice.getSize();
%                 end
%             end
%             %fprintf(1, 'Chunk size %d bytes\n', out);
%         end
        
        function addObj(this,data)            
            %add an object to FDTree and generate id (running number) automatically
            this.addChildAtEnd(FDataNormal(this,this.nrChildren+1,data));            
        end
        
        function addObjID(this,id,data)            
            %add an object to FDTree with specific id (running number)
            h = this.getFDataObj(id,1);
            if(isempty(h))
                %add FData object
                this.addChildByName(FDataNormal(this,id,data),num2str(id)); %true); %with overwrite flag
            else
                %update FData object
                h.setRawData(data);
            end
        end
        
        function addObjMergeID(this,id,data)            
            %insert with specific ID
            h = this.getFDataObj(id,1);
            if(isempty(h))
                %add merged FData object
                this.addChildByName(FDataMerge(this,id,data),num2str(id)); % ,id,true); %with overwrite flag
            else
                %update merged FData object
                h.setRawData(data);
                h.updateCIStats([],0,1,0); %todo
                %h.getCIHistStrict();
                h.clearRawImage();
            end
        end        
        
        function removeObj(this,id)
            %remove FData object
            this.deleteChildByName(id);
        end
        
        %% input functions 
        function setdType(this,val)
            %set data type (dType)
            this.dType = val;
        end
        
        function setResultCrossSection(this,dim,csDef)
            %set the cross section for dimension dim
            for i = 1:this.nrChildren
                this.getChildAtPos(i).setResultCrossSection(dim,csDef);
            end
        end
        
        function clearAllCIs(this,~)
            %clear all current images
            for i = 1:this.nrChildren
                this.getChildAtPos(i).clearCachedImage();
            end
        end
        
        function clearAllFIs(this,~)
            %clear filtered raw images in all subjects
            for i = 1:this.nrChildren
                this.getChildAtPos(i).clearFilteredImage();
            end
        end 
        
        function clearAllRIs(this,~)
            %clear raw images of datatype dType in all subjectss
            for i = 1:this.nrChildren
                this.getChildAtPos(i).clearRawImage();
                this.getChildAtPos(i).clearFilteredImage();
            end
        end
        
        function clearAllMVGroupIs(this)
            %clear data of all MVGroups
            if(strncmp(this.dType,'MVGroup',7) || strncmp(this.dType,'ConditionMVGroup',16) || strncmp(this.dType,'GlobalMVGroup',13))
                this.clearAllRIs();
            end
        end
        
        %% output functions
        function h = getFDataObj(this,id,sType)
            %get FData object with scaling sType                        
            h = this.getChild(num2str(id)); 
            if(strncmp(this.dType,'MVGroup',7))
                %check if MVGroup has to be computed
                if(isempty(h))
                    [cimg, lblx, lbly, cw, binNrs, colors, logColors] = this.myParent.makeMVGroupObj(this.dType);
                    this.addChildByName(FDataNormal(this,id,cimg),num2str(id)); %,id,true);  %with overwrite flag
                    h = this.getChild(num2str(id));
                    %set labels for condition MVGroup computation
                    h.setupXLbl(lblx,cw);
                    h.setupYLbl(lbly,cw);
                    h.setSupplementalData(binNrs);
                    if(~isempty(colors) && ~isempty(logColors))
                        %set combined colors
                        h.setColor_data(colors,logColors);
                    end
                else
                    if(isempty(h.getFullImage()))
                        [cimg, lblx, lbly, cw, binNrs, colors, logColors] = this.myParent.makeMVGroupObj(this.dType);
                        h.setRawData(cimg);
                        %set labels for condition MVGroup computation
                        h.setupXLbl(lblx,cw);
                        h.setupYLbl(lbly,cw);
                        h.setSupplementalData(binNrs);
                        if(~isempty(colors) && ~isempty(logColors))
                            %set combined colors
                            h.setColor_data(colors,logColors);
                        end
                    end
                end                
            end
            if(strncmp(this.dType,'ConditionMVGroup',16))
                %check if condition MVGroup has to be computed
                MVGroupID = this.dType(10:end);
                if(isempty(h))
                    [cimg, lblx, lbly, cw] = this.myParent.makeConditionMVGroupObj(MVGroupID);
                    this.addChildByName(FDataScatterPlot(this,id,cimg),num2str(id)); %,id,true);  %with overwrite flag
                    h = this.getChild(num2str(id));
                    %set labels
                    h.setupXLbl(lblx,cw);
                    h.setupYLbl(lbly,cw);
                else
                    if(isempty(h.getFullImage()))
                        [cimg, lblx, lbly, cw] = this.myParent.makeConditionMVGroupObj(MVGroupID);
                        h.setRawData(cimg);
                        %set labels
                        h.setupXLbl(lblx,cw);
                        h.setupYLbl(lbly,cw);
                    end
                end
            end
            if(strncmp(this.dType,'GlobalMVGroup',13))
                %check if global MVGroup has to be computed
                MVGroupID = this.dType(7:end);
                if(isempty(h))
                    [cimg, lblx, lbly, cw, colors, logColors] = this.myParent.makeGlobalMVGroupObj(MVGroupID);
                    this.addChildByName(FDataScatterPlot(this,id,cimg),num2str(id)); %,id,true);  %with overwrite flag
                    h = this.getChild(num2str(id));
                    %set labels
                    h.setupXLbl(lblx,cw);
                    h.setupYLbl(lbly,cw);
                    %set combined colors
                    h.setColor_data(colors,logColors);
                else
                    if(isempty(h.getFullImage()))
                        [cimg, lblx, lbly, cw, colors, logColors] = this.myParent.makeGlobalMVGroupObj(MVGroupID);
                        h.setRawData(cimg);
                        %set labels
                        h.setupXLbl(lblx,cw);
                        h.setupYLbl(lbly,cw);
                        %set combined colors
                        h.setColor_data(colors,logColors);
                    end
                end
            end            
            if(isempty(h))
                return
            end
            %set Scale Flag depending on selected scale
            if sType == 1
                h.setSType(1);
            else
                h.setSType(2);
            end
        end
        
        function out = getDType(this)
            %get current data type
            out = this.dType;
        end
        
        function nr = getNrElements(this)
            %get number of slices in this chunk
            nr = this.nrChildren;
        end  
        
        function nr = getMySubjectName(this)
            %return the current subject name
            nr = this.myParent.getMySubjectName();
        end
        
        function nr = getMyChannelNr(this)
            %return the current channel number
            nr = this.myParent.getMyChannelNr();
        end
        
        function ids = getMyIDs(this)
            %return a list of all ids in this chunk
            %ids = cellfun(@str2double,this.getNamesOfAllChildren());
            ids = cell2mat(this.getIDsOfAllChildren());
        end
        
        function id = getMyID(this,caller)
            %return the current id (running number)
            id = this.getChildName(caller);
        end
        
        function str = getChObjStr(this)
            %get a string of all objects in this chunk
            ids = this.getMyIDs();
            if(length(ids) == 1 && ids(1) == 0)
                str = {this.dType};
            else
                str = cell(this.nrChildren,1);
                for i = 1:length(ids)
                    str{i,1} = sprintf('%s %d',this.dType,ids(i));
                end
            end
        end
        
        function out = getROIGroup(this,grpName)
            %get the ROI group names and members
            out = this.myParent.getROIGroup(grpName);
        end
        
        function out = getROICoordinates(this,ROIType)
            %get coordinates of ROI
            out = this.myParent.getROICoordinates(this.dType,ROIType);
        end
        
        function out = getZScaling(this,dTypeNr)
            %get z scaling
            out = this.myParent.getZScaling(this.dType,dTypeNr);
        end
        
        function out = getColorScaling(this,dTypeNr)
            %get color scaling
            out = this.myParent.getColorScaling(this.dType,dTypeNr);
        end
        
        function out = getStatsParams(this)
            %get statistics parameters
            out = this.myParent.getStatsParams();
        end
        
        function out = getFileInfoStruct(this)
            %get fileinfo struct
            out = this.myParent.getFileInfoStruct();
        end
        
        function out = getVicinityInfo(this)
            %get vicinity info
            out = this.myParent.getVicinityInfo();
        end
        
        function [alg, params] = getDataSmoothFilter(this)
            %get filtering method to smooth data
            [alg, params] = this.myParent.getDataSmoothFilter();
        end                
        
        function out = isArithmeticImage(this)
            %return true, if dType is an arithmetic image
            out = this.myParent.isArithmeticImage(this.dType);
        end
        
        function out = getIgnoredPixelsMask(this)
            %get mask of ignored pixels
            if(this.defaultSizeFlag)
                %only for data of subject default size
                out = this.myParent.ignoredPixelsMask;
            else
                out = [];
            end
        end
        
        function out = get.FLIMXParamMgrObj(this)
            %get handle to parameter manager object
            out = this.myParent.FLIMXParamMgrObj;
        end
        
        function out = get.isSubjectDefaultSize(this)
            %return true, if this item has the subject default size
            out = this.defaultSizeFlag;
        end
    end
    
    methods(Static)
        function ROICoordinates = extractROICoordinates(ROICoordinates,ROIType)
            %return ROI coordinates for a specific ROI type
            ROICoordinates = double(ROICoordinates);
            if(~isempty(ROICoordinates) && ~isempty(ROIType) && isscalar(ROIType) && ROIType > 1000)
                idx = find(abs(ROICoordinates(:,1,1) - ROIType) < eps,1,'first');
                if(~isempty(idx))
                    ROICoordinates = squeeze(ROICoordinates(idx,:,:))';
                    ROICoordinates = ROICoordinates(1:2,2:end);
                    if(ROIType < 4000)
                        ROICoordinates = ROICoordinates(1:2,1:2);
                    elseif(ROIType > 4000 && ROIType < 5000)
                        %remove potential trailing zeros
                        idx = any(ROICoordinates,1);
                        idx(1:3) = true;
                        ROICoordinates(:,find(idx,1,'last')+1:end) = [];
                    end
                else
                    ROICoordinates = [];
                end
            elseif(isempty(ROIType))
                %return all ROI coordinates
            else
                ROICoordinates = [];
            end
        end
    end %methods(static)
end %classdef
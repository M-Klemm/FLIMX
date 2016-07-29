classdef Chunk < handle
    %=============================================================================================================
    %
    % @file     Chunk.m
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
    % @brief    A class to represent data types (fluorescence lifetime parameter) in a channel, e.g. amplitudes, taus, ...
    %
    properties(SetAccess = protected,GetAccess = public)
        dType = [];
        globalScale = [];
        myParent = [];
        mySlices = [];
    end
    properties(SetAccess = protected,GetAccess = protected)
        
    end
    properties (Dependent = true)
        FLIMXParamMgrObj = [];
    end

    methods
        function this = Chunk(parent,dType,globalScale)
            % Constructor for Chunk.
            this.myParent = parent;
            this.mySlices = LinkedList();   %LinkedList of FData objects
            this.dType = dType;
            this.globalScale = logical(globalScale);
        end
        
        function addObj(this,data)            
            %just add at the end
            this.mySlices.insertEnd(FDataNormal(this,this.mySlices.queueLen+1,data));            
        end
        
        function addObjID(this,id,data)            
            %insert with specific ID
            h = this.getFDataObj(id,1);
            if(isempty(h))
                %add FData object
                this.mySlices.insertID(FDataNormal(this,id,data),id,true);
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
                this.mySlices.insertID(FDataMerge(this,id,data),id,true);
            else
                %update merged FData object
                h.setRawData(data);
                h.updateCIStats([],0,1,0); %todo
                %h.getCIHistStrict();
                h.clearRawImage();
            end
        end        
        
        function removeObj(this,id)
            %remove object
            this.mySlices.removeID(id);
        end
        
        %% input functions 
        function setdType(this,val)
            %set dType
            this.dType = val;
        end
        
        function setResultROICoordinates(this,ROIType,ROICoord)
            %set the ROI vector for dimension dim
            for i = 1:this.mySlices.queueLen
                this.mySlices.getDataByPos(i).setResultROICoordinates(ROIType,ROICoord);
            end
        end
        
        function setCutVec(this,dim,cutVec)
            %set the cut vector for dimension dim
            for i = 1:this.mySlices.queueLen
                this.mySlices.getDataByPos(i).setCutVec(dim,cutVec);
            end
        end
        
        function clearAllCIs(this)
            %clear all current images
            for i = 1:this.mySlices.queueLen
                this.mySlices.getDataByPos(i).clearCachedImage();
            end
        end
        
        function clearAllFIs(this)
            %clear filtered raw images of datatype dType in all subjectss
            for i = 1:this.mySlices.queueLen
                this.mySlices.getDataByPos(i).clearFilteredImage();
            end
        end 
        
        function clearAllRIs(this)
            %clear raw images of datatype dType in all subjectss
            for i = 1:this.mySlices.queueLen
                this.mySlices.getDataByPos(i).clearRawImage();
                this.mySlices.getDataByPos(i).clearFilteredImage();
            end
        end                
        
        %% output functions
        function h = getFDataObj(this,id,sType)
            %get FData object with scaling sType                        
            h = this.mySlices.getDataByID(id);            
            
            if(strncmp(this.dType,'MVGroup',7))
                %check if cluster has to be computed                
                if(isempty(h))
                    [cimg, lblx, lbly, cw] = this.myParent.makeCluster(this.dType);
                    this.mySlices.insertID(FDataNormal(this,id,cimg),id,true);
                    h = this.mySlices.getDataByID(id);  
                    %set labels for view cluster computation
                    h.setupXLbl(lblx,cw);
                    h.setupYLbl(lbly,cw);
                else
                    if(isempty(h.getFullImage()))
                        [cimg, lblx, lbly, cw] = this.myParent.makeCluster(this.dType);
                        h.setRawData(cimg);
                        %set labels for view cluster computation
                        h.setupXLbl(lblx,cw);
                        h.setupYLbl(lbly,cw);
                    end
                end
            end                        
            
            if(strncmp(this.dType,'ConditionMVGroup',16))
                %check if view cluster has to be computed
                clusterID = this.dType(10:end);
                if(isempty(h))                                        
                    [cimg, lblx, lbly, cw] = this.myParent.makeViewCluster(clusterID);
                    this.mySlices.insertID(FDataScatterPlot(this,id,cimg),id,true);
                    h = this.mySlices.getDataByID(id);
                    %set labels
                    h.setupXLbl(lblx,cw);
                    h.setupYLbl(lbly,cw);
                else
                    if(isempty(h.getFullImage()))
                        [cimg, lblx, lbly, cw] = this.myParent.makeViewCluster(clusterID);
                        h.setRawData(cimg);
                        %set labels
                        h.setupXLbl(lblx,cw);
                        h.setupYLbl(lbly,cw);
                    end
                end
            end
            
            if(strncmp(this.dType,'GlobalMVGroup',13))
                %check if global cluster has to be computed
                clusterID = this.dType(7:end);
                if(isempty(h))                                        
                    [cimg, lblx, lbly, cw, colors, logColors] = this.myParent.makeGlobalCluster(clusterID);
                    this.mySlices.insertID(FDataScatterPlot(this,id,cimg),id,true);
                    h = this.mySlices.getDataByID(id);
                    %set labels
                    h.setupXLbl(lblx,cw);
                    h.setupYLbl(lbly,cw);
                    %set combined colors
                    h.setColor_data(colors,logColors);                    
                else
                    if(isempty(h.getFullImage()))
                        [cimg, lblx, lbly, cw, colors, logColors] = this.myParent.makeGlobalCluster(clusterID);
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
        
        function out = getGlobalScale(this)
            %get global scaling flag
            out = this.globalScale;
        end
        
        function nr = getNrElements(this)
            %get number of slices in this chunk
            nr = this.mySlices.queueLen;
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
            ids = zeros(this.mySlices.queueLen,1);
            for i = 1:this.mySlices.queueLen
                ids(i) = this.mySlices.getIDByPos(i);
            end
        end
        
        function id = getMyID(this,caller)
            %return the current id (running number)
            id = this.mySlices.getIDByData(caller);
        end
        
        function str = getChObjStr(this)
            %get a string of all objects in this chunk
            str = cell(this.mySlices.queueLen,1);
            for i=1:this.mySlices.queueLen
                id = this.mySlices.getIDByPos(i);
                if(id == 0)
                    str(i,1) = {this.dType};
                else
                    str(i,1) = {sprintf('%s %d',this.dType,id)};
                end
            end
        end
        
        function out = getROICoordinates(this,ROIType)
            %get coordinates of ROI
            out = this.myParent.getROICoordinates(ROIType);
        end
        
        function out = getZScaling(this,dTypeNr)
            %get z scaling
            out = this.myParent.getZScaling(this.dType,dTypeNr);
        end
        
        function out = getStatsParams(this)
            %get statistics parameters
            out = this.myParent.getStatsParams();
        end
        
        function out = getFileInfoStruct(this)
            %get fileinfo struct
            out = this.myParent.getFileInfoStruct();
        end        
        
        function out = getSaveMaxMemFlag(this)
            %get saveMaxMem flag from parent
            out = this.myParent.getSaveMaxMemFlag();
        end
        
        function [alg, params] = getDataSmoothFilter(this)
            %get filtering method to smooth data
            [alg, params] = this.myParent.getDataSmoothFilter();
        end
        
        function [MSX, MSXMin, MSXMax] = getMSX(this)
            %get manual scaling parameters for x
            MSX = [];
            MSXMin = [];
            MSXMax = [];
            for i = 1:this.mySlices.queueLen
                [MSX, MSXMin, MSXMax] = this.mySlices.getDataByPos(i).getMSX();
                if(~isempty(MSX))
                    return
                end
            end 
        end
        
        function [MSY, MSYMin, MSYMax] = getMSY(this)
            %get manual scaling parameters for y
            MSY = [];
            MSYMin = [];
            MSYMax = [];
            for i = 1:this.mySlices.queueLen
                [MSY, MSYMin, MSYMax] = this.mySlices.getDataByPos(i).getMSY();
                if(~isempty(MSY))
                    return
                end
            end
        end
        
        function out = get.FLIMXParamMgrObj(this)
            %get handle to parameter manager object
            out = this.myParent.FLIMXParamMgrObj;
        end
        
        %% compute functions  
        function [data, ids] = getPerData(this)
            %pa1 = a1*100/(a1+a2+a3)            
            %compute denominator
            lower = 0;
            ids = this.getMyIDs();
            for i = 1:length(ids)
                lower = lower + this.getFDataObj(ids(i),1).rawImage;
            end
            %now make percentage for each element
            [y, x] = size(lower);
            data = zeros(i,y,x);
            for i = 1:length(ids)
                data(i,:,:) = this.getFDataObj(ids(i),1).rawImage./lower*100;
            end
        end               
    end
    
    methods(Static)
        
    end %methods(static)
end %classdef
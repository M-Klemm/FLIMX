classdef Channel < handle
    %=============================================================================================================
    %
    % @file     Channel.m
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
    % @brief    A class to represent a (spectral) channel.
    %
    properties(SetAccess = private,GetAccess = public)
%         items = [];
%         isLoaded = false;
    end
    properties(SetAccess = protected,GetAccess = protected)
        myParent = [];
        myChunks = [];
    end
    properties (Dependent = true)
        FLIMXParamMgrObj = [];
    end
    
    methods
        function this = Channel(parent)
            % Constructor for Channel.
            this.myParent = parent;
            this.myChunks = LinkedList();
        end
        
        function addObj(this,dType,gScale,data)
            %
            chunk = this.getChunk(dType);
            if(isempty(chunk))
                chunk = this.addChunk(dType,gScale);
            end
            chunk.addObj(data);
        end
        
        function addObjID(this,nr,dType,gScale,data)
            %
            chunk = this.getChunk(dType);
            if(isempty(chunk))
                chunk = this.addChunk(dType,gScale);
            end
            chunk.addObjID(nr,data);
        end
        
        function addObjMergeID(this,nr,dType,gScale,data)
            %
            chunk = this.getChunk(dType);
            if(isempty(chunk))
                chunk = this.addChunk(dType,gScale);
            end
            chunk.addObjMergeID(nr,data);
        end
                       
        function chunk = addChunk(this,dType,gScale)
            %add a new chunk
            chunk = this.getChunk(dType);
            if(isempty(chunk))
                chunk = Chunk(this,dType,gScale);
                this.myChunks.insertEnd(chunk,dType);
            end
        end
        
        function removeObj(this,dType,id)
            %remove object
            [chunk, chuckPos] = this.getChunk(dType);
            if(isempty(chunk))
                return
            end
            if(~isempty(chunk))
                chunk.removeObj(id);
                if(chunk.getNrElements == 0)
                    %nothing in there anymore -> remove it from channel
                    this.myChunks.removePos(chuckPos);
                end
            end
        end
                
        %% input functions
        function setdType(this,dType,val)
            %set dType (name of chunk)
            chunk = this.getChunk(dType);
            if(isempty(chunk))
                return
            end
            chunk.setdType(val);
            %change ID in linked list
            this.myChunks.changeID(dType,val);
        end        
        
        function setResultROICoordinates(this,dType,ROIType,ROICoord)
            %set the ROI vector for dimension dim
            chunk = this.getChunk(dType);
            if(isempty(chunk))
                return
            end
            if(chunk.getGlobalScale())
                %set ROI vec for all global scaled chunks
                for i = 1:this.myChunks.queueLen
                    if(this.myChunks.getDataByPos(i).globalScale)
                        this.myChunks.getDataByPos(i).setResultROICoordinates(ROIType,ROICoord);
                    end
                end
            else
                %set ROI vec only for specific chunk
                chunk.setResultROICoordinates(ROIType,ROICoord);
            end
        end
        
        function setCutVec(this,dim,cutVec)
            %set the cut vector for dimension dim
            for i = 1:this.myChunks.queueLen
                if(this.myChunks.getDataByPos(i).globalScale)
                    this.myChunks.getDataByPos(i).setCutVec(dim,cutVec);
                end
            end
        end
                
%         function setChannelItems(this,items)
%             %get the selected items of a resultfile
%             this.items = items;
%             this.setIsLoaded();
%         end   
        
        function clearAllCIs(this,dType)
            %clear current immages of datatype dType in all subjects
            if(isempty(dType))
                %clear all
                for i = 1:this.myChunks.queueLen
                    this.myChunks.getDataByPos(i).clearAllCIs();
                end
            elseif(iscell(dType))
                for i = 1:length(dType)
                    this.clearAllCIs(dType{i})
                end                
            elseif(ischar(dType))
                chunk = this.getChunk(dType);
                if(isempty(chunk))
                    return
                end
                %clear specific datatype
                chunk.clearAllCIs();
            end
        end
        
        function clearAllFIs(this,dType)
            %clear filtered raw immages of datatype dType in all subjects
            if(isempty(dType))
                %clear all
                for i = 1:this.myChunks.queueLen
                    this.myChunks.getDataByPos(i).clearAllFIs();
                end
            elseif(iscell(dType))
                for i = 1:length(dType)
                    this.clearAllFIs(dType{i})
                end                
            elseif(ischar(dType))
                chunk = this.getChunk(dType);
                if(isempty(chunk))
                    return
                end
                %clear specific datatype
                chunk.clearAllFIs();
            end
        end        
        
        function clearAllRIs(this,dType)
            %clear raw images of datatype dType in all subjects
            if(isempty(dType))
                %clear all
                for i = 1:this.myChunks.queueLen
                    this.myChunks.getDataByPos(i).clearAllRIs();
                end
            elseif(iscell(dType))
                for i = 1:length(dType)
                    this.clearAllRIs(dType{i})
                end                
            elseif(ischar(dType))
                chunk = this.getChunk(dType);
                if(isempty(chunk))
                    return
                end
                %clear specific datatype
                chunk.clearAllRIs();
            end
        end                
        %% output functions
        function [chunk, chuckPos] = getChunk(this,dType)
            %check if dType is available and return chuck object
            [chunk, chuckPos] = this.myChunks.getDataByID(dType);
        end
        
        function h = getFDataObj(this,dType,nr,sType)
            %get FData object
            chunk = this.getChunk(dType);
            if(isempty(chunk))
                if(strncmp(dType,'MVGroup',7) || strncmp(dType,'ConditionMVGroup',16)...
                        || strncmp(dType,'MVGroupGlobal',13))
                    %add (condition) cluster chunk
                    chunk = this.addChunk(dType,nr);
                    h = chunk.getFDataObj(nr,sType);                    
                else
                    h = [];                    
                end
                return
            end                        
            h = chunk.getFDataObj(nr,sType);
        end
        
        function out = getROICoordinates(this,ROIType)
            %get coordinates of ROI
            out = this.myParent.getROICoordinates(ROIType);
        end
        
        function out = getZScaling(this,dType,dTypeNr)
            %get z scaling
            out = this.myParent.getZScaling(dType,this.getMyChannelNr(),dTypeNr);
        end
        
        function out = getColorScaling(this,dType,dTypeNr)
            %get color scaling
            out = this.myParent.getColorScaling(dType,this.getMyChannelNr(),dTypeNr);
        end
        
        function out = getStatsParams(this)
            %get statistics parameters
            out = this.FLIMXParamMgrObj.getParamSection('statistics');
        end       
        
        function out = getFileInfoStruct(this)
            %get fileinfo struct
            out = this.myParent.getFileInfoStruct(this.getMyChannelNr());
        end
        
        function nr = getMySubjectName(this)
            %return the current subject name
            nr = this.myParent.getSubjectName();
        end
        
        function nr = getMyChannelNr(this)
            %return the current channel number
            nr = this.myParent.getMyChannelNr(this);
        end
        
        function nr = getNrElements(this)
            %get number of channels in subject
            nr = this.myChunks.queueLen;
        end 
        
        function str = getChObjStr(this)
            %get a string of all objects in this channel
            str = cell(0,0);
            for i=1:this.myChunks.queueLen
                if(strncmp('MVGroup',this.myChunks.getDataByPos(i).getDType,7))
                    %skip cluster objects
                    continue
                end                    
                tmp = this.myChunks.getDataByPos(i).getChObjStr;
                for j=1:length(tmp)
                    str(end+1,1) = tmp(j,:);
                end
            end
            %str = sort(str); %will be sorted by FStudy
        end
        
        function str = getChClusterObjStr(this)
            %get a string of all non-empty cluster objects in this channel            
            str = cell(0,0);
            for i=1:this.myChunks.queueLen
                chunk = this.myChunks.getDataByPos(i);
                if(~strcmp('MVGroup',chunk.getDType))
                    %get only cluster objects
                    continue
                end                    
                ids = chunk.getMyIDs();
                for j=1:length(ids)
                    hfd = chunk.getFDataObj(ids(j),1);
                    %get only non-empty cluster objects
                    if(~isempty(hfd.rawImage))
                        str(end+1,1) = {sprintf('Cluster %d',ids(j))};
                    end
                end
            end            
        end                
        
        function out = getSaveMaxMemFlag(this)
            %get saveMaxMem flag from parent
            out = this.myParent.getSaveMaxMemFlag();
        end
        
        function [alg, params] = getDataSmoothFilter(this)
            %get filtering method to smooth data
            [alg, params] = this.myParent.getDataSmoothFilter();
        end        
        
%         function items = getChannelItems(this)
%             %get the selected items of a resultfile
%             items = this.items;
%         end
        
        function [MSX, MSXMin, MSXMax] = getMSX(this)
            %get manual scaling parameters for x
            MSX = [];
            MSXMin = [];
            MSXMax = [];
            for i = 1:this.myChunks.queueLen
                [MSX, MSXMin, MSXMax] = this.myChunks.getDataByPos(i).getMSX();
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
            for i = 1:this.myChunks.queueLen
                [MSY, MSYMin, MSYMax] = this.myChunks.getDataByPos(i).getMSY();
                if(~isempty(MSY))
                    return
                end
            end
        end
        
        function out = channelResultIsLoaded(this)
            %get isLoaded flag
            tmp = this.getChObjStr();
            out = ~isempty(tmp) && ~all(strcmp('Intensity',tmp));
        end
        
        function out = isMember(this,dType)
            %function checks combination of channel and datatype
            out = true;
            if(~isempty(dType) && isempty(this.getChunk(dType)))
                out = false;
            end
        end
        
        function out = getGlobalScale(this,dType)
            %return global scale flag for dType
            chunk = this.getChunk(dType);
            if(isempty(chunk))
                out = false;
            else
                out = chunk.getGlobalScale();
            end
        end
        
        function out = get.FLIMXParamMgrObj(this)
            %get handle to parameter manager object
            out = this.myParent.FLIMXParamMgrObj;
        end
        
        %% compute functions                
        function [cimg, lblx, lbly, cw] = makeCluster(this,clusterID)
            % make and update cluster for spectral channel using cMVs                
            cimg = []; lblx = []; lbly = []; cw = [];
            cMVs = this.myParent.getClusterTargets(clusterID);
            CImaxs = zeros(length(cMVs.y)+1,1);
            CImins = zeros(length(cMVs.y)+1,1);
            %get ROI coordinates for current subject
            ROICoordinates = this.myParent.getROICoordinates(cMVs.ROI.ROIType);
            if(~any(ROICoordinates(:)))
                cMVs.ROI.ROIType = 0; %no ROI set -> use whole image
            end
            %get FLIM item for x-axis (reference)
            if(~isempty(cMVs.x))
                [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(cMVs.x{1});
                hfd = this.getFDataObj(dType{1},dTypeNr(1),1); %only linear data
                if(isempty(hfd))
                    return
                end
                ci = hfd.getROIImage(ROICoordinates,cMVs.ROI.ROIType,cMVs.ROI.ROISubType,cMVs.ROI.ROIInvertFlag);
%                 if(hfd.checkClasswidth(ci))
%                     return
%                 end
                temp(1,:) = ci(~isnan(ci(:)));
                CImaxs(1) = hfd.getCImax(ROICoordinates,cMVs.ROI.ROIType,cMVs.ROI.ROISubType,cMVs.ROI.ROIInvertFlag);
                CImins(1) = hfd.getCImin(ROICoordinates,cMVs.ROI.ROIType,cMVs.ROI.ROISubType,cMVs.ROI.ROIInvertFlag);
                %get reference classwidth
                cw = getHistParams(this.getStatsParams(),this.getMyChannelNr(),dType{1},dTypeNr(1));
            end
            %get FLIM items for y-axis
            if(~isempty(cMVs.y))
                for yTargets=1:length(cMVs.y)
                    [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(cMVs.y{yTargets});
                    hfd = this.getFDataObj(dType{1},dTypeNr(1),1);
                    if(isempty(hfd))
                        return
                    end
                    ci = hfd.getROIImage(ROICoordinates,cMVs.ROI.ROIType,cMVs.ROI.ROISubType,cMVs.ROI.ROIInvertFlag);
%                     if(hfd.checkClasswidth(ci))
%                         return
%                     end
                    temp(yTargets+1,:) = ci(~isnan(ci(:)));
                    CImaxs(yTargets+1) = hfd.getCImax(ROICoordinates,cMVs.ROI.ROIType,cMVs.ROI.ROISubType,cMVs.ROI.ROIInvertFlag);
                    CImins(yTargets+1) = hfd.getCImin(ROICoordinates,cMVs.ROI.ROIType,cMVs.ROI.ROISubType,cMVs.ROI.ROIInvertFlag);
                end
                %define reference (i.e. x axis)
                ref = reshape(temp(1,:,:),1,[])';
                for j = 1:yTargets
                    xtemp = floor(CImins(1)/cw)*cw:cw:ceil(CImaxs(1)/cw)*cw;
                    ytemp = floor(CImins(j+1)/cw)*cw:cw:ceil(CImaxs(j+1)/cw)*cw;
                    ctemp = hist3([reshape(temp(j+1,:,:),1,[])' ref],'Edges',{ytemp xtemp});
                    [cimg, lblx, lbly] = mergeScatterPlotData(cimg,lblx,lbly,ctemp,xtemp,ytemp,cw);
                end
            end
        end       
        
        function [cimg, lblx, lbly, cw] = makeConditionCluster(this,clusterID)
            %make condition cluster for current channel
            [cimg, lblx, lbly, cw] = this.myParent.makeConditionCluster(this.getMyChannelNr,clusterID);
        end        
        
        function [cimg, lblx, lbly, cw, colors, logColors] = makeGlobalCluster(this,clusterID)
            %make global cluster for current channel
            [cimg, lblx, lbly, cw, colors, logColors] = this.myParent.makeGlobalCluster(this.getMyChannelNr,clusterID);
        end        
        
%         function setIsLoaded(this)
%             %set isLoaded flag of his channel
%             this.isLoaded = true;
%         end
        
    end %methods
    
    methods(Access = protected)        
    end %methods(Access = protected)
    
    methods(Static)
        
    end %methods(static)
end %classdef
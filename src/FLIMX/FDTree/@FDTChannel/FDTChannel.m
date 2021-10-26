classdef FDTChannel < FDTreeNode
    %=============================================================================================================
    %
    % @file     FDTChannel.m
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
    % @brief    A class to represent a (spectral) channel in FDTree.
    %
    properties(SetAccess = private,GetAccess = public)
        ignoredPixelsMask = []
    end
    properties(SetAccess = protected,GetAccess = protected)
    end
    properties (Dependent = true)
        FLIMXParamMgrObj
    end
    
    methods
        function this = FDTChannel(parent,ch)
            % Constructor for FDTChannel
            this = this@FDTreeNode(parent,num2str(ch));
        end
        
%         function out = getSize(this)
%             %determine memory size of the channel
%             out = 0;
%             for i = 1:this.nrChildren
%                 chunk = this.getChildAtPos(i);
%                 if(~isempty(chunk))
%                     out = out + chunk.getSize();
%                 end
%             end
%             %fprintf(1, 'Channel size %d bytes\n', out);
%         end
        
        function addObj(this,dType,gScale,data)
            %add an object to FDTree and generate id (running number) automatically
            chunk = this.getChild(dType);
            if(isempty(chunk))
                chunk = this.addChunk(dType,gScale);
            end
            chunk.addObj(data);
        end
        
        function addObjID(this,nr,dType,gScale,data)
            %add an object to FDTree with specific id (running number)
            chunk = this.getChild(dType);
            if(isempty(chunk))
                chunk = this.addChunk(dType,gScale);
            end
            chunk.addObjID(nr,data);
        end
        
        function addObjMergeID(this,nr,dType,gScale,data)
            %
            chunk = this.getChild(dType);
            if(isempty(chunk))
                chunk = this.addChunk(dType,gScale);
            end
            chunk.addObjMergeID(nr,data);
        end
        
        function setIgnoredPixelsMask(this,mask)
            %set mask for pixels which are ignored
            %check if size of current data matches subject size
            [y, x, z] = size(mask);
            if(~isempty(this.myParent.XSz) && (this.myParent.YSz ~= y))
                %todo: remove this error message here
                error('FDTree:FDTChannel:setIgnoredPixelsMask','Size of ignored pixel mask (%dx%d) does not match subject size (%dx%d)!',x,y,this.myParent.XSz,this.myParent.YSz);
            end
            this.ignoredPixelsMask = mask;
        end
                               
        function chunk = addChunk(this,dType,gScale)
            %add a new chunk
            chunk = this.getChild(dType);
            if(isempty(chunk))
                chunk = FDTChunk(this,dType,gScale);
                this.addChildAtEnd(chunk);
            end
        end
        
        function removeObj(this,dType,id)
            %remove object
            [chunk, chuckPos] = this.getChild(dType);
            if(isempty(chunk))
                return
            end
            if(~isempty(chunk))
                chunk.removeObj(id);
                if(chunk.getNrElements == 0)
                    %nothing in there anymore -> remove it from channel
                    this.deleteChildByPos(chuckPos);
                end
            end
        end
                
        %% input functions
        function setdType(this,dType,val)
            %set dType (name of chunk)
            chunk = this.getChild(dType);
            if(isempty(chunk))
                return
            end
            chunk.setdType(val);
            %change ID in linked list
            this.renameChild(dType,val);
        end        
        
        function setResultCrossSection(this,dim,csDef)
            %set the cross section for dimension dim
            for i = 1:this.nrChildren
                if(this.getChildAtPos(i).isSubjectDefaultSize)
                    this.getChildAtPos(i).setResultCrossSection(dim,csDef);
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
                clearAllCIs@FDTreeNode(this);
            elseif(iscell(dType))
                for i = 1:length(dType)
                    this.clearAllCIs(dType{i})
                end                
            elseif(ischar(dType))
                chunk = this.getChild(dType);
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
                clearAllFIs@FDTreeNode(this);
            elseif(iscell(dType))
                for i = 1:length(dType)
                    this.clearAllFIs(dType{i})
                end                
            elseif(ischar(dType))
                chunk = this.getChild(dType);
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
                clearAllRIs@FDTreeNode(this);
            elseif(iscell(dType))
                for i = 1:length(dType)
                    this.clearAllRIs(dType{i})
                end                
            elseif(ischar(dType))
                chunk = this.getChild(dType);
                if(isempty(chunk))
                    return
                end
                %clear specific datatype
                chunk.clearAllRIs();
            end
        end                
        %% output functions        
        function h = getFDataObj(this,dType,nr,sType)
            %get FData object
            chunk = this.getChild(dType);
            if(isempty(chunk))
                if(strncmp(dType,'MVGroup',7) || strncmp(dType,'ConditionMVGroup',16)...
                        || strncmp(dType,'MVGroupGlobal',13))
                    %add (condition) MVGroup chunk
                    chunk = this.addChunk(dType,0);
                    h = chunk.getFDataObj(1,sType);                    
                else
                    h = [];                    
                end
                return
            end                        
            h = chunk.getFDataObj(nr,sType);
        end
        
        function out = getROIGroup(this,grpName)
            %get the ROI group names and members
            out = this.myParent.getROIGroup(grpName);
        end
        
        function out = getROICoordinates(this,dType,ROIType)
            %get coordinates of ROI
            out = this.myParent.getROICoordinates(dType,ROIType);
        end
        
        function out = getZScaling(this,dType,dTypeNr)
            %get z scaling
            out = this.myParent.getZScaling(double(this.getMyIDInParent()),dType,dTypeNr);
        end
        
        function out = getColorScaling(this,dType,dTypeNr)
            %get color scaling
            out = this.myParent.getColorScaling(double(this.getMyIDInParent()),dType,dTypeNr);
        end
        
        function out = getStatsParams(this)
            %get statistics parameters
            out = this.FLIMXParamMgrObj.getParamSection('statistics');
        end
        
        function out = getColorMap(this)
            %get color map from FLIMXVisGUI
            %out = this.myParent.FLIMVisGUIObj.dynParams.cm;
            gp = this.FLIMXParamMgrObj.generalParams;            
            try
                out = eval(sprintf('%s(256)',lower(gp.cmType)));
            catch
                out = jet(256);
            end
        end
        
        function out = getFileInfoStruct(this)
            %get fileinfo struct
            out = this.myParent.getFileInfoStruct(double(this.getMyIDInParent()));
        end
        
        function out = getVicinityInfo(this)
            %get vicinity info
            out = this.myParent.getVicinityInfo();
        end
        
        function out = getMySubjectName(this)
            %return the current subject name
            out = this.myParent.name;
        end
        
        function nr = getMyChannelNr(this)
            %return the current channel number
            nr = str2double(this.name);%this.getChildName(this);
        end
        
        function nr = getNrElements(this)
            %get number of channels in subject
            nr = this.nrChildren;
        end 
        
        function str = getChObjStr(this)
            %get a string of all objects in this channel
            str = cell(0,0);
            for i=1:this.nrChildren
                if(strncmp('MVGroup',this.getChildAtPos(i).getDType,7))
                    %skip MVGroup objects
                    continue
                end                    
                tmp = this.getChildAtPos(i).getChObjStr;
                for j=1:length(tmp)
                    str(end+1,1) = tmp(j,:);
                end
            end
            %str = sort(str); %will be sorted by FDTSubject
        end
        
        function out = getMVGroupNames(this,mode)
            %get list of MVGroups in study
            %mode 0 - get all subject MVGroups
            %mode 1 - get only calculable MVGroups
            out = this.myParent.getMVGroupNames(mode);
        end
        
%         function str = getMVGroupNames(this)
%             %get a string of all non-empty MVGroup objects in this channel            
%             str = cell(0,0);
%             for i=1:this.nrChildren
%                 chunk = this.getChildAtPos(i);
%                 if(~strcmp('MVGroup',chunk.getDType))
%                     %get only MVGroup objects
%                     continue
%                 end                    
%                 ids = chunk.getMyIDs();
%                 for j=1:length(ids)
%                     hfd = chunk.getFDataObj(ids(j),1);
%                     %get only non-empty MVGroup objects
%                     if(~isempty(hfd.rawImage))
%                         str(end+1,1) = {sprintf('MVGroup %d',ids(j))};
%                     end
%                 end
%             end            
%         end                
                
        function [alg, params] = getDataSmoothFilter(this)
            %get filtering method to smooth data
            [alg, params] = this.myParent.getDataSmoothFilter();
        end        
        
%         function items = getChannelItems(this)
%             %get the selected items of a resultfile
%             items = this.items;
%         end        
        
        function out = isMember(this,dType)
            %function checks combination of channel and datatype
            out = true;
            if(~isempty(dType) && isempty(this.getChild(dType)))
                out = false;
            end
        end
        
        function out = isArithmeticImage(this,dType)
            %return true, if dType is an arithmetic image
            out = this.myParent.isArithmeticImage(dType);
        end
        
        function out = getDefaultSizeFlag(this,dType)
            %return true, if FLIM item (of dType) has the subject's default size
            chunk = this.getChild(dType);
            if(isempty(chunk))
                out = false;
            else
                out = chunk.isSubjectDefaultSize;
            end
        end
        
        function out = getMVGroupTargets(this,MVGroupNr)
            %get multivariate targets
            gMVs = this.myParent.getMVGroupTargets(MVGroupNr);
            myObjs = this.myParent.getChObjStr(str2double(this.name));
            out.x = cell(0,0);
            out.y = cell(0,0);
            if(~isstruct(gMVs) || isstruct(gMVs) && ~all(isfield(gMVs,{'x','y','ROI'})))
                %we did not get MVGroup targets
                warning('FDTChannel:getMVGroupTargets','Could not get MVGroup targets for subject ''%s'' in study ''%s''',this.myParent.name,this.myParent.myParent.name);
                return
            end
            
            allMVG = this.getMVGroupNames(0);
            if(isempty(gMVs.y) && all(ismember(gMVs.x,allMVG)))
                %MV group made of MV groups
                out = gMVs;
            else
                %regular MV group
                out.ROI = gMVs.ROI;
                %check if targets are valid channel objects
                for i = 1:length(gMVs.x)
                    idx = strcmpi(gMVs.x{i}, myObjs);
                    if(any(idx))
                        out.x(end+1) = gMVs.x(i);
                    end
                end
                for i = 1:length(gMVs.y)
                    idx = strcmpi(gMVs.y{i}, myObjs);
                    if(any(idx))
                        out.y(end+1) = gMVs.y(i);
                    end
                end
            end
        end
        
        function out = get.FLIMXParamMgrObj(this)
            %get handle to parameter manager object
            out = this.myParent.FLIMXParamMgrObj;
        end
        
        %% compute functions                
        function [cimg, lblx, lbly, cw, binNrs, colorMVGroup, logColorMVGroup] = makeMVGroupObj(this,MVGroupID)
            %make and update MVGroup for spectral channel using cMVs                
            cimg = []; lblx = []; lbly = []; cw = []; binNrs = []; colorMVGroup = []; logColorMVGroup = [];
            allMVG = this.getMVGroupNames(0);
            cMVs = this.getMVGroupTargets(MVGroupID);
            if(isempty(cMVs.y) && all(ismember(cMVs.x,allMVG)))
                %special case: (MIS) MV Group made by merging other MV Groups
                %this.updateLongProgress(0.01,'Scatter Plot...');
                %MVGroupObjs = this.getStudyObjs(cName,str2double(this.name),MVGroupID,0,1);
                %cMVs = this.getMVGroupTargets(MVGroupID);
                %get reference classwidth
                [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(cMVs.x{1});
                cw = getHistParams(this.getStatsParams(),str2double(this.name),dType{1},dTypeNr(1));
                %get  MVGroups from subject
                for i=1:length(cMVs.x)
                    [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(cMVs.x{i});
                    hfd = this.myParent.getFDataObj(str2double(this.name),dType{1},dTypeNr(1),1);
                    if(isempty(hfd))
                        return
                    end                    
                    %use whole image for scatter plots, ignore any ROIs
                    if(~isempty(hfd.getROIImage([],0,1,0)))
                        [cimg, lblx, lbly] = mergeScatterPlotData(cimg,lblx,lbly,hfd.getROIImage([],0,1,0),hfd.getCIXLbl([],0,1,0),hfd.getCIYLbl([],0,1,0),cw);
                    end
                    %this.updateLongProgress(i/length(MVGroupObjs),sprintf('Scatter Plot: %0.1f%%',100*i/length(MVGroupObjs)));
                end
                if(isempty(cimg))
                    return
                end
                %create colored MVGroup
                colorMVGroup = zeros(size(cimg,1),size(cimg,2),3);
                logColorMVGroup = zeros(size(cimg,1),size(cimg,2),3);
                cimgDummy = zeros(size(cimg));
                for i = 1:length(cMVs.x)
                    [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(cMVs.x{i});
                    hfd = this.myParent.getFDataObj(str2double(this.name),dType{1},dTypeNr(1),1);
                    curImg = mergeScatterPlotData(cimgDummy,lblx,lbly,hfd.getROIImage([],0,1,0),hfd.getCIXLbl([],0,1,0),hfd.getCIYLbl([],0,1,0),cw);
                    curImg = curImg/(max(curImg(:))-min(curImg(:)))*(size(this.getColorMap(),1)-1)+1;
                    if(~any(curImg(:)))
                        %all zero
                        continue
                    end
                    %prepare MVGroup coloring
                    %color = this.getMVGroupColor(cMVs.x{i});
                    color = lines(i);
                    color = color(i,:);
                    cm = repmat([0:1/(size(this.getColorMap(),1)-1):1]',1,3);
                    cm = [cm(:,1).*color(1) cm(:,2).*color(2) cm(:,3).*color(3)];
                    %get merged colors
                    colors = cm(round(reshape(curImg,[],1)),:);
                    colors = reshape(colors,[size(curImg) 3]);
                    if(sum(colorMVGroup(:)) > 0)
                        colorMVGroup = imfuse(colors,colorMVGroup,'blend');
                    else
                        colorMVGroup = colors;
                    end
                    %                 idx = repmat(sum(colors,3) ~= 0 & sum(colorMVGroup,3) ~= 0, [1 1 3]);
                    %                 colorMVGroup = colorMVGroup + colors;
                    %                 colorMVGroup(idx) = colorMVGroup(idx)./2;
                    %create log10 color MVGroup
                    curImgLog = log10(curImg);
                    tmp = curImgLog(curImgLog ~= -inf);
                    tmp = min(tmp(:));
                    curImgLog(curImgLog == -inf) = tmp;
                    curImgLog = (curImgLog-tmp)/(max(curImgLog(:))-tmp)*(size(this.getColorMap(),1)-1)+1;
                    colorsLog = cm(round(reshape(curImgLog,[],1)),:);
                    colorsLog = reshape(colorsLog,[size(curImgLog) 3]);
                    logColorMVGroup = logColorMVGroup + colorsLog;
                    idxLog = repmat(sum(colorsLog,3) ~= 0 & sum(logColorMVGroup,3) ~= 0, [1 1 3]);
                    logColorMVGroup(idxLog) = logColorMVGroup(idxLog)./2;
                    %this.updateLongProgress(0.5+0.5*i/length(MVGroupTargets),sprintf('Scatter Plot: %0.1f%%',50+50*i/length(MVGroupTargets)));
                end
                %set brightness to max
                %linear scaling
                t = rgb2hsv(colorMVGroup);
                t2 = t(:,:,3);
                idx = logical(sum(colorMVGroup,3));
                %t2(idx) = t2(idx) + 1-max(t2(:));
                t2(idx) = 1;
                t(:,:,3) = t2;
                colorMVGroup = hsv2rgb(t);
                %log scaling
                t = rgb2hsv(logColorMVGroup);
                t2 = t(:,:,3);
                idx = logical(sum(logColorMVGroup,3));
                %t2(idx) = t2(idx) + 1-max(t2(:));
                t2(idx) = 1;
                t(:,:,3) = t2;
                logColorMVGroup = hsv2rgb(t);
                %this.updateLongProgress(0,'');
                return
            end
            if(isempty(cMVs.x) || isempty(cMVs.y))
                %nothing to do
                return
            end
            CImaxs = zeros(length(cMVs.y)+1,1);
            CImins = zeros(length(cMVs.y)+1,1);
            %get FLIM item for x-axis (reference)
            [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(cMVs.x{1});
            %get ROI coordinates for current subject
            if(cMVs.ROI.ROIType > 0)
                ROICoordinates = this.myParent.getROICoordinates(dType{1},cMVs.ROI.ROIType);
                if(~any(ROICoordinates(:)))
                    cMVs.ROI.ROIType = 0; %no ROI set -> use whole image
                end
            else
                %ROI group
                ROICoordinates = [];
            end
            hfd = this.myParent.getFDataObj(str2double(this.name),dType{1},dTypeNr(1),1); %only linear data
            if(isempty(hfd))
                return
            end
            ci = hfd.getROIImage(ROICoordinates,cMVs.ROI.ROIType,cMVs.ROI.ROISubType,cMVs.ROI.ROIVicinity);
            temp(:,1) = ci(:); %ci(~isnan(ci(:)));
            CImaxs(1) = hfd.getCImax(ROICoordinates,cMVs.ROI.ROIType,cMVs.ROI.ROISubType,cMVs.ROI.ROIVicinity);
            CImins(1) = hfd.getCImin(ROICoordinates,cMVs.ROI.ROIType,cMVs.ROI.ROISubType,cMVs.ROI.ROIVicinity);
            %get reference classwidth
            cw = getHistParams(this.getStatsParams(),double(this.getMyIDInParent()),dType{1},dTypeNr(1));            
            %define reference (i.e. x axis)
            %ref = reshape(temp(:,1),1,[])';
            xEdges = floor(CImins(1)/cw)*cw:cw:ceil(CImaxs(1)/cw)*cw;
            binNrs = zeros(size(temp,1),1+length(cMVs.y),'uint16');
            [~,binNrs(:,1)] = histc(temp(:,1),xEdges,1);
            binNrs(:,1) = min(binNrs(:,1),length(xEdges));
            %get FLIM items for y-axis
            for yTargetNr = 1:length(cMVs.y)
                [dType, dTypeNr] = FLIMXVisGUI.FLIMItem2TypeAndID(cMVs.y{yTargetNr});
                hfd = this.myParent.getFDataObj(str2double(this.name),dType{1},dTypeNr(1),1);
                if(isempty(hfd))
                    return
                end
                ci = hfd.getROIImage(ROICoordinates,cMVs.ROI.ROIType,cMVs.ROI.ROISubType,cMVs.ROI.ROIVicinity);
                temp(:,yTargetNr+1) = ci(:); %ci(~isnan(ci(:)));
                CImaxs(yTargetNr+1) = hfd.getCImax(ROICoordinates,cMVs.ROI.ROIType,cMVs.ROI.ROISubType,cMVs.ROI.ROIVicinity);
                CImins(yTargetNr+1) = hfd.getCImin(ROICoordinates,cMVs.ROI.ROIType,cMVs.ROI.ROISubType,cMVs.ROI.ROIVicinity);                
                %for j = 1:yTargets                    
                    yEdges = floor(CImins(yTargetNr+1)/cw)*cw:cw:ceil(CImaxs(yTargetNr+1)/cw)*cw;
                    matSize = length(xEdges) .* length(yEdges) *8 / 1024^3;
                    if(matSize > 1)
                        %expected MVGroup array is > 1GB -> abort
                        warning('FLIMX:FDTChannel:makeMVGroupObj','Requested 2D histogram size %dx%d (%.2f GB) is too large. Aborted computation for subject %s.',length(yEdges),length(xEdges),matSize,this.myParent.name);
                        cimg = []; lblx = []; lbly = []; cw = [];
                        return
                    end
                    [~,binNrs(:,1+yTargetNr)] = histc(temp(:,yTargetNr+1),yEdges,1);
                    binNrs(:,1+yTargetNr) = min(binNrs(:,1+yTargetNr),length(yEdges));
                    binNrs = binNrs(all(binNrs>0,2),:);
                    % Combine the two vectors of 1D bin counts into a grid of 2D bin
                    % counts.
                    ctemp = accumarray([binNrs(:,yTargetNr+1) binNrs(:,1)],1,[length(yEdges) length(xEdges)]);
                    %ctemp = hist3([reshape(temp(j+1,:,:),1,[])' ref],'Edges',{yEdges xEdges});
                    [cimg, lblx, lbly] = mergeScatterPlotData(cimg,lblx,lbly,ctemp,xEdges,yEdges,cw);
                %end
            end
        end       
        
        function [cimg, lblx, lbly, cw] = makeConditionMVGroupObj(this,MVGroupID)
            %make condition MVGroup for current channel
            [cimg, lblx, lbly, cw] = this.myParent.makeConditionMVGroupObj(double(this.getMyIDInParent()),MVGroupID);
        end        
        
        function [cimg, lblx, lbly, cw, colors, logColors] = makeGlobalMVGroupObj(this,MVGroupID)
            %make global MVGroup for current channel
            [cimg, lblx, lbly, cw, colors, logColors] = this.myParent.makeGlobalMVGroupObj(double(this.getMyIDInParent()),MVGroupID);
        end        
        
    end %methods
    
    methods(Access = protected)        
    end %methods(Access = protected)
    
    methods(Static)        
    end %methods(static)
end %classdef
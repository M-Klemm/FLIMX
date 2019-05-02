classdef measurementInSubject < measurementInFDTree
    %class to represent the fluoSyntheticFile class
    properties(GetAccess = public, SetAccess = private)
        mySubject = [];        
    end
    
    properties (Dependent = true)
    end
    
    methods
        function this = measurementInSubject(hSubject)
            %constructor
            this = this@measurementInFDTree(hSubject.myParamMgr,@hSubject.getWorkingDirectory);
            this.mySubject = hSubject;
        end
        %% input methods        
        
%         function setROIData(this,channel,data)
%             %set roi data for channel
%             if(channel <= this.nrSpectralChannels && ndims(data) == 3)
%                 %todo: clear raw data??
%                 this.roiFluoData{channel} = data;
%                 this.roiMerged{channel} = [];
%             end
%         end
        
% for simulation file only
%         function setNrSpectralChannels(this,val)
%             %set nr of spectral channels
%             if(this.fileInfo.nrSpectralChannels > val)
%                 this.rawFluoData = this.rawFluoData(1:val,1);
%                 this.rawFluoDataFlat = this.rawFluoDataFlat(1:val,1);
%                 this.roiFluoData = this.roiFluoData(1:val,1);
%                 this.roiFluoDataFlat = this.roiFluoDataFlat(1:val,1);
%                 this.roiMerged = this.roiMerged(1:val,1);
%                 this.fileInfo.reflectionMask = this.fileInfo.reflectionMask(1:val,1);
%                 this.fileInfo.StartPosition = this.fileInfo.StartPosition(1:val,1);
%                 this.fileInfo.EndPosition = this.fileInfo.EndPosition(1:val,1);
%             elseif(this.fileInfo.nrSpectralChannels < val)
%                 diff = val - this.fileInfo.nrSpectralChannels;
%                 this.rawFluoData(end+1:end+diff,1) = cell(diff,1);
%                 this.roiFluoData(end+1:end+diff,1) = cell(diff,1);
%                 this.rawFluoDataFlat(end+1:end+diff,1) = cell(diff,1);
%                 this.roiFluoDataFlat(end+1:end+diff,1) = cell(diff,1);
%                 this.roiMerged(end+1:end+diff,1) = cell(diff,1);
%                 this.fileInfo.reflectionMask(end+1:end+diff,1) = cell(diff,1);
%                 this.fileInfo.StartPosition(end+1:end+diff,1) = cell(diff,1);
%                 this.fileInfo.EndPosition(end+1:end+diff,1) = cell(diff,1);
%             else
%                 %new = old
%                 return
%             end
%             this.fileInfo.nrSpectralChannels = val;
%             if(isempty(this.paramMgrObj))
%                 this.paramMgrObj.makeVolatileParams();
%             end
%         end
        
        %%output methods
%         function raw = getRawData(this,channel)
%             %get raw data for channel
%             raw = [];
%             if(channel <= this.nrSpectralChannels && length(this.rawFluoData) >= channel)
%                 raw = this.rawFluoData{channel};
                %[szY szX szZ] = size(raw);
                %make very smooth image of raw data
%                 roi = ones(4,1);
%                 roi(2) = szX;
%                 roi(4) = szY;
%                 %bin raw data
% %                 computationParams = this.paramMgrObj.getParamSection('computation');
% %                 genrealParams = this.paramMgrObj.getParamSection('general');
%                 bin = 5;
%                 hwb = waitbar(0,'RAW preparation');
%                 ps = matlabpool('size');
%                 dx = roi(2)-roi(1);
%                 dy = roi(4)-roi(3);
%                 idx = zeros(ps,2);
%                 if(isinteger(raw))
%                     dType = this.ROIDataType;
%                 else
%                     dType = class(raw);
%                 end
%                 out = zeros(dy+1,dx+1,szZ,dType);
%                 idx(:,2) = floor(linspace(roi(1)+floor(dx/ps),roi(2),ps));
%                 idx(1,1) = roi(1);
%                 idx(2:end,1) = idx(1:end-1,2)+1;
%                 parfor i = 1:ps
%                     tmp{i} = measurementInFDTree.sWnd3D(idx(i,1),idx(i,2),roi(3),roi(4),bin,raw,dType,[]);
%                 end
%                 waitbar(0.9, hwb,'RAW preparation: 90% done');
%                 di = cumsum(1+idx(:,2)-idx(:,1));
%                 cnt = 1;
%                 for i = 1:ps
%                     out(:,cnt:di(i),:) = tmp{i};
%                     cnt = di(i)+1;
%                 end
                %smooth data
%                 out = raw(:,:,1:110);
%                 parfor y = 1:szY
%                     for x = 1:szX
%                         out(y,x,:) = fastsmooth(squeeze(out(y,x,:)),5,3);
%                     end
%                 end
%                 
%                 %dermine maxima positions of binned raw data
%                 [~, mPos] = max(out,[],3);
%                 medPos = round(median(mPos(:)));
%                 mPos = mPos - medPos;
%                 %correct maxima positions of sourceFileal raw data
%                 parfor y = 1:szY
%                     for x = 1:szX
%                         raw(y,x,:) = circshift(squeeze(raw(y,x,:)),-mPos(y,x));
%                     end
%                 end
%                 if(~isempty(hwb))
%                     close(hwb);
%                 end
%             end
%         end
        
%         function out = getWorkingDirectory(this)
%             %get my working folder
%             out = this.mySubject.getWorkingDirectory();
%         end
        
        %% compute methods
        
                
    end %methods
    methods (Access = protected) 
        
    end
    
    methods(Static)
        
        
    end %methods(Static)
end


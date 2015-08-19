classdef FDataMerge < FData
    %=============================================================================================================
    %
    % @file     FDataMerge.m
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
    % @brief    A class to represent a data from merged fluorescence lifetime parameters
    %
    properties(SetAccess = protected,GetAccess = protected)
        histTable = [];
        ROIType = [];
        ROISubType = [];
        ROICoordinates = [];
    end    
    
    methods
        function this = FDataMerge(parent,id,data)
            %
            this = this@FData(parent,id,data);
            this.ROICoordinates = zeros(7,3,2,'int16');
            this.updateCIStats([],0,0,0);
            [this.cachedImage.statistics.histogramStrict, this.cachedImage.statistics.histogramStrictCenters] = this.makeHist(this.rawImage,true);
            %this.makeStrictHist(this.rawImage);
            this.rawImage = [];
        end
        
        function setROICoordinates(this,val)
            %set coordinates of ROI
            this.ROICoordinates = val;
            this.clearCachedImage();
        end
        
        function setROIType(this,val)
            %set type of ROI
            this.ROIType = val;
            this.clearCachedImage();
        end
        
        function setROISubType(this,val)
            %set type of roi (number corresponding to type)
            this.ROISubType = val;
            this.clearCachedImage();
        end
        
        function out = getFullImage(this)
            %get raw image with respect to linear/log scaling
            out = this.rawImage;
            scaling = this.sType;
            %scale to log
            if(scaling == 2)
                out = log10(abs(out)); %turn negative values positive
                out(isinf(out)) = 0;
            end
            %don't filter
        end
        
        function out = getROIImage(this,ROICoordinates,ROIType,ROISubType,ROIInvertFlag)
            %get cached image
            out = this.rawImage;
        end
        
        function out = getROICoordinates(this,ROIType)
            %return ROI coordinates for a certain type of ROI
            out = this.ROICoordinates;
            if(~isempty(ROIType) && isscalar(ROIType) && ROIType <= size(out,1))
                if(ROIType >= 2 && ROIType <= 5)
                    out = squeeze(out(ROIType,2:3,:))';
                else %polygons
                    out = squeeze(out(ROIType,2:end,:))';
                end
            end
        end
        
        function out = getROIType(this)
            %get type of ROI
            out = this.ROIType;
        end
        
        function out = getROISubType(this)
            %get type of grid roi (number corresponding to type)
            out = this.ROISubType;
        end
          
    end %methods
                
end %classdef
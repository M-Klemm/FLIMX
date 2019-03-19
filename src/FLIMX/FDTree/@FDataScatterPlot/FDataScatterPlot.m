classdef FDataScatterPlot < FDataNormal
    %=============================================================================================================
    %
    % @file     FDataScatterPlot.m
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
    % @brief    A class to represent data for a scatter plot.
    %
    properties(SetAccess = protected,GetAccess = protected)
        ROICoordinates = [];
        ROIType = 0;
        ROISubType = 1;
        ROIInverFlag = 0;        
        MSZ = [];
        MSZMin = [];
        MSZMax = [];
        ColorScaling = [];
    end    
    
    methods
        function this = FDataScatterPlot(parent,id,rawImage)
            %constructor of FDataScatterPlot class
            this = this@FDataNormal(parent,id,rawImage);
            this.ROICoordinates = zeros(7,3,2,'int16');            
        end
        
        function out = getROICoordinates(this,ROIType)
            %get coordinates of ROI
            if(~isempty(ROIType) && isscalar(ROIType) && ROIType <= 7 && ROIType >= 1)
                out = squeeze(this.ROICoordinates(ROIType,:,:));
                if(ROIType <= 5)
                    out = out(2:end,1:2)';
                end
            else
                out = [];
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
        
        function out = getROIVicinity(this)
            %get type of grid roi (number corresponding to type)
            out = this.ROIVicinity;
        end
        
        function out = getZScaling(this)
            %get z scaling parameters
            out = [double(this.MSZ), this.MSZMin, this.MSZMax];
        end
        
        function out = getColorScaling(this)
            %get color scaling parameters
            out = this.ColorScaling;
        end
        
        function setResultColorScaling(this,val)
            %get color scaling parameters
            if(length(val) == 3)
                this.ColorScaling = val;
            end
        end
        
        function setROICoordinates(this,ROIType,ROICoord)
            %set coordinates of ROI
            tmp = this.ROICoordinates;
            if(isempty(ROIType))
                %set all ROI coordinates at once
                if(size(ROICoord,1) == 7 && size(ROICoord,2) == 3 && size(ROICoord,3) >= 2)
                    tmp = int16(ROICoord);
                end
            else
                if(isempty(tmp) || size(tmp,1) ~= 7 || size(tmp,2) ~= 3)
                    tmp = zeros(7,3,2,'int16');
                end
                if(ROIType >= 1 && ROIType <= 7 && size(ROICoord,1) == 2 && size(ROICoord,2) == 3)
                    tmp(ROIType,:,1:2) = int16(ROICoord');
                elseif(ROIType >= 6 && ROIType <= 7 && size(ROICoord,1) == 1 && size(ROICoord,2) == 3 && size(ROICoord,3) > 2)
                    tmp(:,:,3:size(ROICoord,3)) = zeros(7,2,size(ROICoord,3)-2,'int16');
                    tmp(ROIType,:,:) = int16(ROICoord);
                end
            end
            this.ROICoordinates = tmp;
        end
        
        function setROIType(this,val)
            %set type of ROI
            this.ROIType = val;
        end
        
        function setROISubType(this,val)
            %set type of grid roi (number corresponding to type)
            this.ROISubType = val;
        end
        
        function setROIVicinity(this,val)
            %set type of grid roi (number corresponding to type)
            this.ROIVicinity = val;
        end
        
        function setZScaling(this,data)
            %set z scaling; data = [flag min max]
            this.MSZ = logical(data(1));
            if(this.sType == 2)
                %transform input to log10 space
                if(data(2) <= 0)
                    data(2) = 0;
                else
                    data(2) = log10(data(2));
                end
                if(data(3) <= 0)
                    data(3) = -Inf;
                else
                    data(3) = log10(data(3));
                end
            end
            this.MSZMin = data(2);
            this.MSZMax = data(3);
            this.clearCachedImage();
        end
        
        function out = getDefaultXLblTick(this)
            %return tick step size for x
            out = getHistParams(this.getStatsParams(),this.channel,this.dType,this.id);
        end
        
        function out = getDefaultYLblTick(this)
            %return tick step size for y
            out = getHistParams(this.getStatsParams(),this.channel,this.dType,this.id);
        end  
    end %methods
    
    methods (Access = protected)
          
    end%methods(protected)
end
classdef subject4Import < fluoSubject
    %=============================================================================================================
    %
    % @file     subject4Import.m
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
    % @brief    A class to represent a subject used to import measurements or results
    %
    properties(GetAccess = public, SetAccess = private)
    end
    
    properties (Dependent = true) 
    end
    
    methods
        function this = subject4Import(study,name)
            %constructor
            this = this@fluoSubject(study,name);
        end
        
        %% input methods
        function importMeasurementFile(this,fn)
            %import measurement file
            this.myMeasurement.setSourceFile(fn);
            this.importMeasurement2FDTree();
        end
        
        function importMeasurementObj(this,obj)
            %import a measurement object
            this.myMeasurement.importMeasurementObj(obj); %sets the source file in myMeasurement from obj
            this.importMeasurement2FDTree();
        end
        
        function importResult(this,fn,resultType,ch,position,scaling)
            %import a result from ASCII files
            ch = this.myResult.importResult(fn,resultType,ch,position,scaling);
            %this.updateSubjectChannel(ch,'result');
            idx = find(this.resultIsDirty);
            for i = 1:length(idx)
                this.updateSubjectChannel(idx(i),'result');
            end
        end
        
        function importResultStruct(this,rs,ch,position,scaling)
            %import a result from a result struct
            this.myResult.importResultStruct(rs,ch,position,scaling);
            %this.updateSubjectChannel(ch,'result');
            idx = find(this.resultIsDirty);
            for i = 1:length(idx)
                this.updateSubjectChannel(idx(i),'result');
            end
        end
        
        function init(this)
            %init measurement and result objects
            this.myMeasurement = measurement4Import(this);
            this.myMeasurement.setProgressCallback(@this.updateProgress);
            this.myResult = result4Import(this);
        end
    end %methods
    
    methods (Access = protected)
        function importMeasurement2FDTree(this)
            %import a measurement to FDTree
            ROIVec = this.myMeasurement.ROICoord; %save old ROIVec if there is one
            %this.myMeasurement.setSourceFile(fn);
            if(~isempty(ROIVec))
                this.myMeasurement.setROICoord(ROIVec);
            end
            if(~this.myMeasurement.fileInfoLoaded)
                this.myMeasurement.getFileInfoStruct([]);
            end
            %add me to my study
            this.myParent.addSubject(this.name);
            %guess position of the eye
            this.myMeasurement.guessEyePosition();
            for ch = 1:this.myMeasurement.nrSpectralChannels
                %read the actual payload
                if(ch == 1 && isempty(this.myMeasurement.ROICoord))
                    %get full roi
                    ROIVec = [1 this.myMeasurement.getRawXSz() 1 this.myMeasurement.getRawYSz()];
                    %ROIVec = importWizard.getAutoROI(this.myMeasurement.getRawDataFlat(ch),this.preProcessParams.roiBinning);
                    if(ROIVec(1) > 5 || ROIVec(3) > 5 || ROIVec(2) < this.myMeasurement.rawXSz-5 || ROIVec(4) < this.myMeasurement.rawYSz-5)
                        this.myMeasurement.setROICoord(ROIVec);
                    end
                end
                %save in fdtree
                this.updateSubjectChannel(ch,'measurement');
            end
        end
        
    end
end %classdef
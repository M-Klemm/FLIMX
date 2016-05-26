classdef subject4Sim < fluoSubject
    %=============================================================================================================
    %
    % @file     subject4Sim.m
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
    % @brief    A class to represent a simulated subject
    %    
    properties(GetAccess = public, SetAccess = private)
        studyName = '';
        parentParamMgr = [];
        IRFMgr = [];
    end
    
    properties (Dependent = true)
    end
    
    methods
        function this = subject4Sim(studyName,sdc,hParentParamMgr,hIRFMgr)
            %constructor            
            this = this@fluoSubject(hParentParamMgr,'Simulation');%,'',hParentParamMgr,hIRFMgr,about);
%             this.myParamMgr.setParamSection('pre_processing',[]);
%             this.myParamMgr.setParamSection('bounds',[]);
            this.parentParamMgr = hParentParamMgr;
            this.IRFMgr = hIRFMgr;
            this.studyName = studyName;
            %we do initialization here
            this.myParamMgr = subjectParamMgr(this,hParentParamMgr.getParamSection('about'));
            fi = measurementFile.getDefaultFileInfo();
            if(~isempty(sdc))
                fi.tacRange = sdc.tacRange;
                fi.nrTimeChannels = sdc.nrTimeChannels;
                fi.nrSpectralChannels = sdc.nrSpectralChannels;
            end
            this.myMeasurement = measurement4Sim(this,fi);
            this.myMeasurement.setProgressCallback(@this.updateProgress);
            this.myResult = result4Approx(this);
            this.loadParameters();
        end
        
        %% input methods
        function init(this)            
            %overload subject's init method to do nothing
            %we'll init our properties later            
        end
        
        function setMeasurementData(this,channel,data)
            %set raw data for measurement in channel
            if(isvector(data))
                tmp = data;
                clear data
                data(1,1,:) = tmp;
            end
            this.myMeasurement.loadRawData(channel,data);
        end
        
        function setStudy(this,study)
            %set study name
            this.studyName = study;
        end
        
        function updatebasicParams(this,sdc)
            %update basic fit parameters according to sdc
            params = this.basicParams;
            if(~isempty(sdc))
                params.nExp = sdc.nrExponentials;
            end
            params.tciMask = true(1,params.nExp);
            params.stretchedExpMask = false(1,params.nExp);
            params.hybridFit = 0;
            params.approximationTarget = 1;
            params.reconvoluteWithIRF = 1;
            params.incompleteDecay = 1;
            params.heightMode = 1;
            %params.fixHShift2Init = 0;
            params.fix2InitTargets = {};
            params.optimizerInitStrategy = 1;
            params.nonLinOffsetFit = 1;
            params.constMaskSaveStrCh1 = {};
            params.constMaskSaveStrCh2 = {};
            params.constMaskSaveValCh1 = [];
            params.constMaskSaveValCh2 = [];
            if(~isempty(sdc))
                params.(sprintf('constMaskSaveStrCh%d',sdc.channelNr)) = {'Offset'};
                params.(sprintf('constMaskSaveValCh%d',sdc.channelNr)) = sdc.offset;
            end
            params.timeInterpMethod = 'linear';
            params.scatterEnable = 0;
            params.scatterStudy = '';
            params.scatterIRF = 0;
            this.basicParams = params;
            this.myParamMgr.makeVolatileParams();
            if(~isempty(sdc))
                for ch = 1:sdc.nrSpectralChannels
                    this.myResult.allocResults(ch,this.getROIYSz(),this.getROIXSz());
                end
            end
        end
        
%         function setTacRange(this,tacRange)
%             %set tac range
%             this.myMeasurement.setTacRange(tacRange);
%         end
%         
%         function setNrTimeChannels(this,nrTimeChannels)
%             %set nr of time channels
%             this.myMeasurement.setNrTimeChannels(nrTimeChannels);
%         end
%         
%         function setNrSpectralChannels(this,nrChannels)
%             %set nr of spectral channels
%             this.myMeasurement.setNrSpectralChannels(nrChannels);
%         end
                
        %% output methods
        
        function out = getMyFolder(this)
            %return subjects working folder
            out = '';
        end
        
        function out = getStudyName(this)
            %get study name
            out = this.studyName;
        end
        
        function out = getFileInfoStruct(this,ch)
            %return fileinfo struct
            if(isempty(ch))
                for ch = 1:2
                    out = this.getFileInfoStruct(ch);
                    if(~isempty(out))
                        return
                    end
                end
            else
                out = this.myMeasurement.getFileInfoStruct(ch);
            end            
        end
    end
    
    methods(Access = protected)
        function out = getParentParamMgr(this)
            %return parameter manager from study (parent)
            out = this.parentParamMgr;
        end
        
        function out = getMyIRFMgr(this)
            %helper method for get.myIRFMgr() to allow overloading
            out = this.IRFMgr;
        end
    end
    
end
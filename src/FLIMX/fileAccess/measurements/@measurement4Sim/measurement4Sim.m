classdef measurement4Sim < measurementInFDTree
    %=============================================================================================================
    %
    % @file     measurement4Sim.m
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
    % @brief    A class to represent the measurement4Sim class
    %
    properties(GetAccess = public, SetAccess = private)
    end
    
    properties (Dependent = true)
    end
    
    methods
        function this = measurement4Sim(hSubject,fi)
            %constructor
            this = this@measurementInFDTree(@hSubject.myParamMgr,@hSubject.getWorkingDirectory,hSubject);
            this.setFileInfoStruct(fi);
            this.setDirtyFlags([],1:4,true);
        end
        
        %% input methods
        function setSyntheticData(this,channel,data)
            %set synthetic data for channel
            this.setRawData(channel,data);
            this.clearROAData();
        end
        function out = getNonEmptyChannelList(this)
            %return list of channel with measurement data
            out = find(~cellfun('isempty',this.rawFluoData));
        end
        
        function fileInfo = getFileInfoStruct(this,ch)
            %get file info struct            
            fileInfo = getFileInfoStruct@measurementFile(this,ch);
        end
        
    end %methods
    
    methods  (Access = protected)
        
    end % (Access = protected)
end
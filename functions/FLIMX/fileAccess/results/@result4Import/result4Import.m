classdef result4Import < resultFile
    %=============================================================================================================
    %
    % @file     result4Import.m
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
    % @brief    A class to represent a result object used to import results
    %
    properties(GetAccess = public, SetAccess = private)
    end
    
    properties (Dependent = true)
    end
    
    methods
        function this = result4Import(hSubject)
            %constructor
            this = this@resultFile(hSubject);
%             this.mySubject = hSubject;
        end
        
        %% input
        
        function ch = importResult(this,fn,fi,chFlag,position,scaling)
            %load result from disk, if chFlag = true load all channels;
            %in case of ascii import chFlag = channel number of imported data
            ch = 0;
            switch fi
                case 3 %FLIMXFit result
                    if(iscell(fn))
                        fn = fn{1};
                    end
                    [path,fileName] = fileparts(fn);
                    chIdx = strfind(fileName,'ch');
                    if(~isempty(chIdx) && chFlag)
                        %look for all files (channels) with similar file name
                        files = rdir(sprintf('%s%s%s*.mat',path,filesep,fileName(1:chIdx)));
                        for i = 1:length(files)
                            ch = this.openChannel(files(i,1).name);
                        end
                    else
                        ch = this.openChannel(fn);
                    end
                case {1,2} %B&H result file#
                    ch = chFlag;
                    if(nargin < 6)
                        fi = measurementFile.getDefaultFileInfo();
                        position = fi.position;
                        scaling = fi.pixelResolution;
                    end
                    %read ASCII files
                    file = cell(1,length(fn));
                    for i = 1:length(fn)
                        [path, name, ext] = fileparts(fn{i});
                        file(i) = {[name,ext]};
                    end
                    try
                        rs = FLIMXVisGUI.ASCII2ResultStruct(file,path,this.mySubject.name,fi,ch);
                    catch ME
                        uiwait(errordlg(sprintf('%s\n\nImport aborted.',ME.message),'Error loading B&H results','modal'));
                        return
                    end
                    if(~isfield(rs,'results'))
                        return
                    end
                    fields = fieldnames(rs.results.pixel);
                    if(isempty(fields))
                        return
                    end
                    %extract only amplitudes, taus, offset and chi
                    nA = sum(strncmp('Amplitude',fields,9));
                    nT = sum(strncmp('Tau',fields,3));
                    %check number of paramters
                    if(nA ~= nT)
                        uiwait(errordlg(sprintf('Number of Amplitudes (%d) and Taus (%d) does not match!\n\nImport aborted.',nA,nT),'Error loading B&H results','modal'));
                        return
                    end
                    %check size of channel
                    if(~isempty(this.filesOnHDD) && ~isempty(this.loadedChannelList) && ~all(this.resultSize == size(rs.results.pixel.Amplitude1)))
                        uiwait(errordlg(sprintf('Size of channel %d result (%dx%d) does not match subject result size (%dx%d)!\n\nImport aborted.',ch,size(rs.results.pixel.Amplitude1,1),size(rs.results.pixel.Amplitude1,2),this.resultSize(1),this.resultSize(2)),'Error loading B&H results','modal'));
                        return
                    end
                    rs = resultFile.updateFitResultsStruct(rs,this.paramMgrObj.getDefaults().about);
                    rs.auxiliaryData.fileInfo.position = position;
                    rs.auxiliaryData.fileInfo.pixelResolution = scaling;
                    this.loadResult(rs);
                    %update fileInfo of other channels
                    if(ch > 1)
                        for i = 1:ch-1
                            this.auxiliaryData{i}.fileInfo.nrSpectralChannels = rs.auxiliaryData.fileInfo.nrSpectralChannels;
                            this.setDirty(i,true);
                        end
                    end
            end
        end
        
    end%methods
end%classdef
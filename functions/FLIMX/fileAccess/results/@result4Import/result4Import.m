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
        %         function [result, measurement] = readResultFromDisc(this,resFN,measFN)
%             %try to load result and measurement files
%             result = [];
%             measurement = [];
%             if(~exist(resFN,'file'))
%                 return
%             end
%             result = load(resFN);
%             %try to load measurement data                
%             if(exist(measFN,'file'))
%                 measurement = load(measFN);
%             else
%                 measurement = [];
%             end
%             result = this.updateFitResultsStruct(result,measurement,this.parameterDefaults.about);
%             
% %             if(~(isfield(result,'result') || isfield(result,'export')))
% %                 warndlg('Resultfile is too old. Revision is not compatible with FLIMXFitGUI','Result too old','modal');
% %                 return
% %             end
% %             if(isfield(result,'export'))
% %                 if(result.export.about.results_revision < 122)
% %                     uiwait(errordlg(sprintf('Result file is too old.\nRequired revision is: 1.30.\nFound revision is: %1.2f.',result.export.about.results_revision/100),'modal'));
% %                     return
% %                 else
% %                     [result measurement] = this.updateFitResultsStruct(result.export,this.aboutInfo);
% %                 end
% %             else
% %                 result = result.result;
% %                 %try to load measurement data                
% %                 if(exist(measFN,'file'))
% %                     measurement = load(measFN);
% %                     measurement = measurement.measurement;
% %                 else
% %                     measurement = [];
% %                 end
% %             end
% %             if(result.about.results_revision ~= this.FLIMXAboutInfo.results_revision)
% %                 button = questdlg(sprintf('Result file revision is too old and probably not compatible with current version of FLIMXFitGUI\n\nDo you still want to try loading it?'),'Result file is too old!','Yes','No','No');
% %                 switch button
% %                     case 'No'
% %                         result = [];
% %                         measurement = [];
% %                         return
% %                 end
% %             end
%         end
        
            function ch = importResult(this,fn,fi,chFlag)
            %load result from disk, if chFlag = true load all channels;
            %in case of ascii import chFlag = channel number of imported data
            ch = 0;
            switch fi
                case 3 %FLIMFit result
                    if(iscell(fn))
                        fn = fn{1};
                    end
                    [path,fileName] = fileparts(fn);
                    chIdx = strfind(fileName,'ch');
%                     this.resultParamMgrObj = []; %clear old result info
%                     if(~isempty(this.fluoFileObj))
%                         this.fluoFileObj.clearROIData();
%                     end
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
                    
%                     if(isempty(idxO))
%                         errordlg('No offset parameters found.','Error loading B&H results','modal');
%                     end
                    rs = this.updateFitResultsStruct(rs,this.paramMgrObj.getDefaults().about);
                    this.loadResult(rs);
%                     %set fitparameters
%                     export.parameters.basic = this.basicParams;
%                     export.parameters.pixel = this.volatilePixelParams.pixel;
%                     export.parameters.basic.nExp = length(idxA);
%                     export.parameters.basic.tciMask = zeros(1,export.parameters.basic.nExp);
%                     export.parameters.pixel.heightMode = 3;
%                     %open corresponding sdt file
%                     tmp = rs.results.pixel.(fields{1});
%                     uiwait(warndlg(sprintf('Becker & Hickl ASCII results have been loaded. The corresponding SDT file is needed. Choose identical channel, image borders, IRF and binning as in SPCImage!\n\nSpatial resolution of the results is:\nx: %d\ny: %d',size(tmp,2),size(tmp,1)),'SDT file for BH result','modal'));
%                     if(this.openFluoFile());
%                         %read settings from ini to overwrite old settings from loaded result
%                         this.FLIMXObj.FLIMXParamMgrObj.readConfig();
%                         ch = GUI_importWizard(this.FLIMXObj);
%                         if(ch)
%                             this.currentChannel = ch;
%                             this.FLIMXObj.FLIMFit.setBasicParams(export);
%                             this.FLIMXObj.FLIMFit.setPixelParams(export);
%                             this.FLIMXObj.FLIMFit.allocResults(); %clear old results
%                         else
%                             return
%                         end
%                     else
%                         return
%                     end
%                     %copy data
%                     export.data = this.FLIMXObj.FLIMFit.data;
%                     export.data.curIRF = export.data.curIRF./max(export.data.curIRF(:)).*15000;
%                     %copy results
%                     export.results.pixel = this.FLIMXObj.FLIMFit.results.pixel;
%                     export.results.init = this.FLIMXObj.FLIMFit.results.init;
%                     for i = 1:length(idxA)
%                         export.results.pixel.(sprintf('Amplitude%d',i)) = rs.results.pixel.(fields{idxA(i)}) ./ 100000; %amplitudes have been scaled by ASCII2ResultStruct function
%                         export.results.pixel.(sprintf('Tau%d',i)) = rs.results.pixel.(fields{idxT(i)});
%                         %rebuild x_vec
%                         export.results.pixel.x_vec(:,:,i) = export.results.pixel.(sprintf('Amplitude%d',i));
%                         export.results.pixel.x_vec(:,:,i+length(idxA)) = export.results.pixel.(sprintf('Tau%d',i));
%                     end
%                     export.results.pixel.Offset = rs.results.pixel.(fields{idxO});
%                     export.results.pixel.x_vec(:,:,end) = export.results.pixel.Offset;
%                     export.results.pixel.x_vec(:,:,end-2) = ones(size(tmp)); %vertical shift
%                     if(~isempty(idxC))
%                         export.results.pixel.chi2 = rs.results.pixel.(fields{idxC});
%                     end
%                     %set reults version
%                     export.about = this.FLIMXObj.FLIMFit.about;
%                     export.about.results_revision = 122;
%                     this.FLIMXObj.FLIMFit.loadSavedResult(export,path);
            end            
        end
        
    end%methods
end%classdef